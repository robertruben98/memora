import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/dgt_repository.dart';

/// Constante a bumpear cuando el shape de `DgtQuestion.fromJson` agregue
/// campos nuevos populados por el backend (e.g. `difficulty`, `subtopic_id`,
/// `tags`, `image_url` poblado). Issue #156 (dgt-tech): si bump esta constante,
/// los clientes con cache antigua la invalidan automaticamente al proximo
/// `read()` sin esperar al TTL de 7 dias.
///
/// Historia:
///   * v1 -> shape original (id/statement/options/correct/explanation/topic
///     /image_url). Vigente hasta 2026-05.
///   * v2 -> aniade soporte para campos opcionales `difficulty` y
///     `subtopic_id` que algunos batches DGT 2026 ya emiten (issue #156).
const int kDgtCacheSchemaVersion = 2;

/// Cache local de preguntas DGT.
///
/// Issue #45 (dgt-tech): los simulacros hacen `GET /dgt/questions` en cada
/// arranque. Con 1000+ preguntas en backend, el roundtrip + payload (~300KB)
/// degrada UX del caso "estoy en el metro repasando".
///
/// Esta cache es ADITIVA: el repositorio sigue funcionando si la cache no
/// existe o falla. Persiste el banco completo como JSON string en
/// `SharedPreferences` (suficiente para <500KB; no se agrega Hive/sembast
/// para no inflar deps - ver discusion en PR).
///
/// Estructura persistida:
///   - `dgt.cache.questions.v1.json` -> JSON list de [DgtQuestion.toJson]
///   - `dgt.cache.questions.v1.ts_ms` -> int (timestamp unix ms al guardar)
///   - `dgt.cache.questions.v1.limit` -> int (limit con el que se fetcho)
///   - `dgt.cache.questions.schema_version` -> int (schema version persistida,
///     issue #156). Si difiere de [kDgtCacheSchemaVersion] al leer, la cache
///     se descarta como stale aunque el TTL no haya vencido.
///
/// TTL configurable por constructor (default 7 dias). Si solo cambia el
/// schema (no el storage key) basta con bumpear [kDgtCacheSchemaVersion] para
/// auto-invalidar todos los clientes. Si cambia el storage key, mantener el
/// patron `.v1` actual y crear `.v2`.
class DgtQuestionsCache {
  /// Default TTL: 7 dias.
  static const Duration defaultTtl = Duration(days: 7);

  static const String keyJson = 'dgt.cache.questions.v1.json';
  static const String keyTimestampMs = 'dgt.cache.questions.v1.ts_ms';
  static const String keyLimit = 'dgt.cache.questions.v1.limit';

  /// Key de la version del schema persistida con el blob. Issue #156:
  /// permite auto-invalidar la cache cuando el contrato de
  /// `DgtQuestion.fromJson` cambia (campos nuevos del backend).
  static const String keySchemaVersion = 'dgt.cache.questions.schema_version';

  final Duration ttl;
  final Future<SharedPreferences> Function() _prefsLoader;

  /// Constructor. [ttl] sobreescribe el default. [prefsLoader] permite
  /// inyectar un mock en tests (default usa `SharedPreferences.getInstance`).
  DgtQuestionsCache({
    Duration? ttl,
    Future<SharedPreferences> Function()? prefsLoader,
  })  : ttl = ttl ?? defaultTtl,
        _prefsLoader = prefsLoader ?? SharedPreferences.getInstance;

  /// Lee la cache. Retorna `null` si:
  /// - No hay nada guardado.
  /// - El JSON esta corrupto.
  /// - El timestamp esta fuera de TTL ([forceFresh] true reemplaza chequeo
  ///   de TTL por "siempre stale", util para forzar refetch).
  /// - La version del schema persistida difiere de [kDgtCacheSchemaVersion]
  ///   (issue #156: handshake auto-invalidate al cambiar shape backend).
  ///
  /// Si [requireLimit] se da, devuelve null si el limit guardado no
  /// coincide (p.ej. cache de 30 no sirve para limit=50). Esto evita
  /// devolver muestras incompletas para listados grandes.
  Future<List<DgtQuestion>?> read({
    int? requireLimit,
    bool forceFresh = false,
  }) async {
    try {
      final prefs = await _prefsLoader();
      final ts = prefs.getInt(keyTimestampMs);
      final raw = prefs.getString(keyJson);
      if (ts == null || raw == null) return null;
      if (forceFresh) return null;
      // Issue #156: handshake de version. Si el cliente actual espera un shape
      // distinto al persistido (incluye legacy "sin version" = 1), invalida.
      final savedVersion = prefs.getInt(keySchemaVersion) ?? 1;
      if (savedVersion != kDgtCacheSchemaVersion) return null;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > ttl.inMilliseconds) return null;
      if (requireLimit != null) {
        final savedLimit = prefs.getInt(keyLimit) ?? -1;
        if (savedLimit < requireLimit) return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map>()
          .map((m) => DgtQuestion.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Escribe la cache (best-effort: silencioso si falla). Persiste tambien
  /// la version actual del schema ([kDgtCacheSchemaVersion]) para que un
  /// futuro bump invalide automaticamente este blob.
  Future<void> write(List<DgtQuestion> questions, {required int limit}) async {
    try {
      final prefs = await _prefsLoader();
      final payload = jsonEncode(questions.map(_toJson).toList());
      await prefs.setString(keyJson, payload);
      await prefs.setInt(
        keyTimestampMs,
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setInt(keyLimit, limit);
      await prefs.setInt(keySchemaVersion, kDgtCacheSchemaVersion);
    } catch (_) {
      // Persist best-effort.
    }
  }

  /// Invalida la cache (boton "Sincronizar banco DGT" en settings).
  Future<void> clear() async {
    try {
      final prefs = await _prefsLoader();
      await prefs.remove(keyJson);
      await prefs.remove(keyTimestampMs);
      await prefs.remove(keyLimit);
      await prefs.remove(keySchemaVersion);
    } catch (_) {
      // Best-effort.
    }
  }

  /// Devuelve si hay cache valida (no stale, no corrupta). Util para UI.
  Future<bool> isFresh() async {
    final data = await read();
    return data != null && data.isNotEmpty;
  }

  static Map<String, dynamic> _toJson(DgtQuestion q) => {
        'id': q.id,
        'statement': q.statement,
        'image_url': q.imageUrl,
        'option_a': q.optionA,
        'option_b': q.optionB,
        'option_c': q.optionC,
        'correct': q.correct,
        'explanation': q.explanation,
        'topic': q.topic,
        'difficulty': q.difficulty,
        'subtopic_id': q.subtopicId,
      };
}
