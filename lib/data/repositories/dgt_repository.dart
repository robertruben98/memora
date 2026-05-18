import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../local/dgt_questions_cache.dart';
import 'dgt_local_bank.dart';

/// Pregunta DGT multi-choice (a/b/c).
class DgtQuestion {
  final String id;
  final String statement;
  final String? imageUrl;
  final String optionA;
  final String optionB;
  final String optionC;

  /// Letra correcta: 'a' | 'b' | 'c'.
  final String correct;
  final String? explanation;
  final String? topic;

  const DgtQuestion({
    required this.id,
    required this.statement,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.correct,
    this.imageUrl,
    this.explanation,
    this.topic,
  });

  factory DgtQuestion.fromJson(Map<String, dynamic> j) {
    return DgtQuestion(
      id: (j['id'] ?? '').toString(),
      statement: (j['statement'] ?? '').toString(),
      imageUrl: j['image_url'] as String?,
      optionA: (j['option_a'] ?? '').toString(),
      optionB: (j['option_b'] ?? '').toString(),
      optionC: (j['option_c'] ?? '').toString(),
      correct: (j['correct'] ?? 'a').toString().toLowerCase(),
      explanation: j['explanation'] as String?,
      topic: j['topic'] as String?,
    );
  }
}

class DgtRepository {
  final ApiClient _api;

  /// Cache local opcional (issue #45). Si es `null`, el repo opera como
  /// antes (sin cache). Inyectada por el provider de produccion; tests
  /// pueden inyectar instancias fake.
  final DgtQuestionsCache? _cache;

  DgtRepository(this._api, {DgtQuestionsCache? cache}) : _cache = cache;

  /// Intenta cache local primero, luego `GET /dgt/questions?limit=N`. Si el
  /// endpoint falla u offline, devuelve cache (si existe) o cae al banco
  /// local mini ([dgtLocalBank]).
  ///
  /// Issue #45: evita roundtrip + spinner en cada simulacro.
  ///
  /// Flujo:
  ///   1. cache fresh con suficiente size -> devuelve cache (cache hit).
  ///   2. cache stale o vacia -> fetch backend. Si OK: cachea y devuelve.
  ///   3. backend falla (offline) y hay cache (incluso stale): devuelve cache.
  ///   4. backend falla y no hay cache: fallback `dgtLocalBank`.
  ///
  /// El parametro [forceRefresh] (boton "Sincronizar banco DGT" en settings)
  /// salta el paso 1 e invalida la cache antes de fetch.
  Future<List<DgtQuestion>> fetchExamQuestions({
    int limit = 30,
    bool forceRefresh = false,
  }) async {
    final cache = _cache;

    // 1) Cache hit (si cache configurada y no se fuerza refresh).
    if (cache != null && !forceRefresh) {
      final cached = await cache.read(requireLimit: limit);
      if (cached != null && cached.length >= limit) {
        return cached.take(limit).toList();
      }
    }

    if (cache != null && forceRefresh) {
      // El usuario pidio sincronizar -> invalidamos antes de pedir al backend
      // para que un fetch fallido no resucite el blob viejo.
      await cache.clear();
    }

    // 2) Fetch backend.
    try {
      final res = await _api.get('/dgt/questions', query: {'limit': '$limit'});
      final parsed = _parseQuestions(res);
      if (parsed != null && parsed.isNotEmpty) {
        // 3) Cachea best-effort. Pedimos mas de 30 si limit es mayor para
        // soportar listados grandes desde cache en la siguiente llamada.
        if (cache != null) {
          await cache.write(parsed, limit: limit);
        }
        return parsed;
      }
    } catch (_) {
      // Backend offline / no expone /dgt/questions / 5xx.
    }

    // 4) Offline / fetch fallido: si tenemos cache (aunque stale) devolverla.
    if (cache != null) {
      final stale = await cache.read(forceFresh: false);
      if (stale != null && stale.isNotEmpty) {
        return stale.take(limit).toList();
      }
      // Cache vacia o fresh check fallido: intenta leer ignorando TTL.
      final anyStale = await cache.read(
        requireLimit: null,
        forceFresh: false,
      );
      if (anyStale != null && anyStale.isNotEmpty) {
        return anyStale.take(limit).toList();
      }
    }

    // 5) Fallback definitivo: banco local mini.
    return dgtLocalBank.take(limit).toList();
  }

  /// Invalida la cache local. Llamar desde "Sincronizar banco DGT" en
  /// settings. No-op si no hay cache configurada.
  Future<void> invalidateCache() async {
    await _cache?.clear();
  }

  /// Parser tolerante: backend puede responder lista plana o `{questions: [...]}`.
  List<DgtQuestion>? _parseQuestions(dynamic res) {
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => DgtQuestion.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (res is Map && res['questions'] is List) {
      return (res['questions'] as List)
          .whereType<Map>()
          .map((e) => DgtQuestion.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return null;
  }
}

/// Provider de la cache local (singleton). Tests pueden override.
final dgtQuestionsCacheProvider = Provider<DgtQuestionsCache>((ref) {
  return DgtQuestionsCache();
});

final dgtRepositoryProvider = Provider<DgtRepository>((ref) {
  return DgtRepository(
    ref.watch(apiClientProvider),
    cache: ref.watch(dgtQuestionsCacheProvider),
  );
});
