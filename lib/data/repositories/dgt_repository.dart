import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../local/dgt_questions_cache.dart';
import 'dgt_local_bank.dart';

/// Bloque tematico DGT (ej "Senales", "Normas", "Mecanica").
class DgtTopic {
  final String id;
  final String name;
  final int questionCount;

  const DgtTopic({
    required this.id,
    required this.name,
    this.questionCount = 0,
  });

  factory DgtTopic.fromJson(Map<String, dynamic> j) {
    return DgtTopic(
      id: (j['id'] ?? j['slug'] ?? j['name'] ?? '').toString(),
      name: (j['name'] ?? j['title'] ?? j['id'] ?? '').toString(),
      questionCount: _asInt(j['question_count'] ?? j['count'] ?? j['total']),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

/// Pregunta DGT 2026 con video de percepcion de riesgo (issue #77).
///
/// Shape distinto a [DgtQuestion]: en lugar de `image_url` + `difficulty`,
/// expone `videoUrl` (obligatorio), `thumbnailUrl` (opcional) y `riskType`
/// (peaton_oculto / ciclista_cruce / vehiculo_tapa_vision / semaforo_ambar /
/// otro). El backend marca estos registros con `card_type='dgt_video'`.
class DgtVideoQuestion {
  final String id;
  final String statement;
  final String optionA;
  final String optionB;
  final String optionC;

  /// Letra correcta: 'a' | 'b' | 'c'.
  final String correct;
  final String explanation;
  final String videoUrl;
  final String? thumbnailUrl;
  final String topicId;
  final String riskType;

  const DgtVideoQuestion({
    required this.id,
    required this.statement,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.correct,
    required this.explanation,
    required this.videoUrl,
    required this.topicId,
    required this.riskType,
    this.thumbnailUrl,
  });

  factory DgtVideoQuestion.fromJson(Map<String, dynamic> j) {
    return DgtVideoQuestion(
      id: (j['id'] ?? '').toString(),
      statement: (j['statement'] ?? '').toString(),
      optionA: (j['option_a'] ?? '').toString(),
      optionB: (j['option_b'] ?? '').toString(),
      optionC: (j['option_c'] ?? '').toString(),
      correct: (j['correct'] ?? 'a').toString().toLowerCase(),
      explanation: (j['explanation'] ?? '').toString(),
      videoUrl: (j['video_url'] ?? '').toString(),
      thumbnailUrl: j['thumbnail_url'] as String?,
      topicId: (j['topic_id'] ?? '').toString(),
      riskType: (j['risk_type'] ?? 'otro').toString(),
    );
  }
}

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

  /// Lista los bloques DGT disponibles. Backend: GET /dgt/topics.
  /// Si el endpoint falla, deriva bloques unicos del banco local.
  Future<List<DgtTopic>> fetchTopics() async {
    try {
      final res = await _api.get('/dgt/topics');
      List<dynamic>? raw;
      if (res is List) raw = res;
      if (res is Map && res['topics'] is List) raw = res['topics'] as List;
      if (raw != null) {
        return raw
            .map((e) => DgtTopic.fromJson(e as Map<String, dynamic>))
            .where((t) => t.id.isNotEmpty)
            .toList();
      }
    } catch (_) {
      // Fallback local: agrupar por campo `topic` del banco.
    }
    return _topicsFromLocalBank();
  }

  /// Preguntas DGT 2026 con video de percepcion de riesgo (issue #77).
  ///
  /// Backend endpoint: `GET /dgt/video-questions?limit={N}` (publico, sin auth).
  /// El endpoint puede no estar disponible en backends antiguos o devolver lista
  /// vacia mientras se cargan los videos oficiales. En ambos casos devolvemos
  /// una lista vacia y el caller muestra empty state.
  ///
  /// Aditivo: no reemplaza ningun metodo existente. No usa cache local (los
  /// videos son streaming, no tiene sentido cachear el JSON pesado).
  Future<List<DgtVideoQuestion>> fetchVideoQuestions({int limit = 10}) async {
    try {
      final res = await _api.get(
        '/dgt/video-questions',
        query: {'limit': '$limit'},
      );
      if (res is List) {
        return res
            .whereType<Map>()
            .map((e) => DgtVideoQuestion.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (res is Map && res['questions'] is List) {
        return (res['questions'] as List)
            .whereType<Map>()
            .map((e) => DgtVideoQuestion.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {
      // Backend antiguo sin /dgt/video-questions, offline, o 5xx -> empty.
    }
    return const <DgtVideoQuestion>[];
  }

  List<DgtTopic> _topicsFromLocalBank() {
    final counts = <String, int>{};
    for (final q in dgtLocalBank) {
      final t = (q.topic ?? '').trim();
      if (t.isEmpty) continue;
      counts[t] = (counts[t] ?? 0) + 1;
    }
    final out = counts.entries
        .map((e) => DgtTopic(id: e.key, name: e.key, questionCount: e.value))
        .toList();
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  /// Preguntas filtradas por dificultad (issue #78). Backend:
  /// `GET /dgt/questions?difficulty={N}&limit={M}`.
  ///
  /// [difficulty]: 1 (facil), 2 (media), 3 (dificil). Si backend falla u
  /// offline, devuelve fallback del banco local mini limitado a [limit]
  /// (sin filtrar — el banco local no tiene metadato de dificultad).
  ///
  /// Aditivo: no toca cache de simulacro, no persiste, no rompe
  /// `fetchExamQuestions` ni `fetchQuestionsByTopic`.
  Future<List<DgtQuestion>> fetchQuestionsByDifficulty({
    required int difficulty,
    int limit = 10,
  }) async {
    try {
      final res = await _api.get(
        '/dgt/questions',
        query: {'difficulty': '$difficulty', 'limit': '$limit'},
      );
      final parsed = _parseQuestions(res);
      if (parsed != null && parsed.isNotEmpty) {
        return parsed;
      }
    } catch (_) {
      // Backend no soporta el filtro o esta offline.
    }
    // Fallback: muestra del banco local sin garantia de dificultad.
    return dgtLocalBank.take(limit).toList();
  }

  /// Preguntas trampa DGT 2026 (issue #74). Backend:
  /// `GET /dgt/quiz/trick-questions?limit={N}`.
  ///
  /// El endpoint devuelve preguntas con palabras clave trampa
  /// (siempre/nunca/excepto/solo) que son las que mas suspenden en el examen
  /// real. Si el backend es antiguo / offline / 5xx, devuelve fallback del
  /// banco local filtrado por presencia de las palabras trampa en el
  /// enunciado. Aditivo: no toca otros metodos.
  Future<List<DgtQuestion>> fetchTrickQuestions({int limit = 20}) async {
    try {
      final res = await _api.get(
        '/dgt/quiz/trick-questions',
        query: {'limit': '$limit'},
      );
      final parsed = _parseQuestions(res);
      if (parsed != null && parsed.isNotEmpty) {
        return parsed;
      }
    } catch (_) {
      // Backend antiguo sin endpoint, offline o 5xx -> fallback local.
    }
    final pattern = RegExp(
      r'\b(siempre|nunca|excepto|solo|s[oó]lo)\b',
      caseSensitive: false,
    );
    final filtered = dgtLocalBank
        .where((q) => pattern.hasMatch(q.statement))
        .toList();
    if (filtered.length > limit) {
      return filtered.take(limit).toList();
    }
    return filtered;
  }

  /// Preguntas filtradas por tema. Backend:
  /// GET /dgt/questions?topic_id={id}&limit={N}. Si falla, filtra el banco
  /// local por campo `topic` (case-insensitive sobre id o name).
  Future<List<DgtQuestion>> fetchQuestionsByTopic({
    required String topicId,
    int? limit,
  }) async {
    try {
      final query = <String, String>{'topic_id': topicId};
      if (limit != null) query['limit'] = '$limit';
      final res = await _api.get('/dgt/questions', query: query);
      final parsed = _parseQuestions(res);
      if (parsed != null) {
        return parsed;
      }
    } catch (_) {
      // Backend aun no soporta filtro. Cae a fallback local.
    }
    final norm = topicId.toLowerCase().trim();
    final filtered = dgtLocalBank
        .where((q) => (q.topic ?? '').toLowerCase().trim() == norm)
        .toList();
    if (limit != null && filtered.length > limit) {
      return filtered.take(limit).toList();
    }
    return filtered;
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
