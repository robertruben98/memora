import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/app_logger.dart';
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

/// Letras de respuesta validas para preguntas DGT multi-choice.
const Set<String> _kValidCorrectLetters = {'a', 'b', 'c'};

/// Normaliza y valida el campo `correct` de una pregunta DGT.
///
/// Si el valor entrante no esta en el set valido (`a`/`b`/`c`) — p.ej. `d`,
/// null, vacio o basura — registra un warning con [appLogger] y cae a un
/// fallback seguro (`a`) en lugar de cachear corrupcion silenciosa. Mantiene
/// el tipo de retorno `String` no nulo para no romper las firmas existentes.
String _normalizeCorrect(dynamic raw, {required String questionId}) {
  final normalized = (raw ?? '').toString().toLowerCase().trim();
  if (_kValidCorrectLetters.contains(normalized)) {
    return normalized;
  }
  appLogger.warn(
    'dgt',
    'Pregunta DGT con campo "correct" invalido '
        '(id=$questionId, valor="$raw"); usando fallback "a".',
  );
  return 'a';
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
    final id = (j['id'] ?? '').toString();
    return DgtVideoQuestion(
      id: id,
      statement: (j['statement'] ?? '').toString(),
      optionA: (j['option_a'] ?? '').toString(),
      optionB: (j['option_b'] ?? '').toString(),
      optionC: (j['option_c'] ?? '').toString(),
      correct: _normalizeCorrect(j['correct'], questionId: id),
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

  /// Dificultad DGT (1 facil, 2 media, 3 dificil). Opcional: schema v2
  /// (issue #156). Null en payloads/cache legacy sin la key.
  final int? difficulty;

  /// Id del subtema DGT. Opcional: schema v2 (issue #156). Null en
  /// payloads/cache legacy sin la key.
  final String? subtopicId;

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
    this.difficulty,
    this.subtopicId,
  });

  factory DgtQuestion.fromJson(Map<String, dynamic> j) {
    final id = (j['id'] ?? '').toString();
    return DgtQuestion(
      id: id,
      statement: (j['statement'] ?? '').toString(),
      imageUrl: j['image_url'] as String?,
      optionA: (j['option_a'] ?? '').toString(),
      optionB: (j['option_b'] ?? '').toString(),
      optionC: (j['option_c'] ?? '').toString(),
      correct: _normalizeCorrect(j['correct'], questionId: id),
      explanation: j['explanation'] as String?,
      topic: j['topic'] as String?,
      difficulty: (j['difficulty'] as num?)?.toInt(),
      subtopicId: j['subtopic_id'] as String?,
    );
  }
}

/// Resultado de [DgtRepository.fetchWeakFocusQuiz] (issue #134).
///
/// Encapsula el shape del endpoint `GET /dgt/quiz/weak-focus` (BE#93) mas
/// un flag [insufficientData] usado por la UI cuando el backend responde
/// 400 (historial DGT insuficiente para identificar peor tema).
class DgtWeakFocusQuizResult {
  /// Id del peor tema detectado por el backend. Vacio si [insufficientData]
  /// o si hubo error de red (preguntas vacias).
  final String worstTopicId;

  /// Accuracy actual del usuario en el peor tema (en escala 0-100). 0 si
  /// no hay datos.
  final double worstTopicAccuracyPct;

  /// Total de respuestas registradas en el peor tema en los ultimos 60
  /// dias (ventana usada por el backend BE#93). 0 si no hay datos.
  final int worstTopicTotalAnswered;

  /// Preguntas del quiz 50/50 (mitad worst_topic + mitad resto).
  final List<DgtQuestion> questions;

  /// `true` si el backend respondio 400 (historial DGT < 20 respuestas o
  /// ningun topic con minimo 5 respuestas). UX: mensaje "necesitas mas
  /// practica general" en lugar de "error". Otros fallos (offline, 5xx)
  /// dejan este flag en `false` y la UI muestra "error reintenta".
  final bool insufficientData;

  const DgtWeakFocusQuizResult({
    required this.worstTopicId,
    required this.worstTopicAccuracyPct,
    required this.worstTopicTotalAnswered,
    required this.questions,
    required this.insufficientData,
  });
}

/// Item del endpoint `GET /dgt/quiz/recurrent-failures` (BE#149, issue #154).
///
/// Extiende [DgtQuestion] con [failCount] = num veces que el usuario ha
/// fallado esta pregunta en los ultimos 60 dias. Backend ordena DESC por
/// fallos y por fecha del ultimo fallo.
class DgtRecurrentFailureItem {
  final DgtQuestion question;
  final int failCount;

  const DgtRecurrentFailureItem({
    required this.question,
    required this.failCount,
  });

  factory DgtRecurrentFailureItem.fromJson(Map<String, dynamic> j) {
    final fc = j['fail_count'];
    final n = fc is int
        ? fc
        : (fc is num
            ? fc.toInt()
            : int.tryParse('${fc ?? ''}') ?? 0);
    return DgtRecurrentFailureItem(
      question: DgtQuestion.fromJson(j),
      failCount: n,
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

  /// Parser generico tolerante: backend puede responder una lista plana o un
  /// objeto `{questions: [...]}`. Aplica [factory] a cada Map del payload.
  ///
  /// Devuelve `null` si [res] no encaja en ninguna de las dos formas (ni lista
  /// ni mapa con key `questions` lista), permitiendo a los callers distinguir
  /// "shape inesperado" de "lista vacia legitima".
  static List<T>? _parseGenericQuestions<T>(
    dynamic res,
    T Function(Map<String, dynamic>) factory,
  ) {
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => factory(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (res is Map && res['questions'] is List) {
      return (res['questions'] as List)
          .whereType<Map>()
          .map((e) => factory(Map<String, dynamic>.from(e)))
          .toList();
    }
    return null;
  }

  /// Parser tolerante: backend puede responder lista plana o `{questions: [...]}`.
  List<DgtQuestion>? _parseQuestions(dynamic res) =>
      _parseGenericQuestions(res, DgtQuestion.fromJson);

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
      final parsed = _parseGenericQuestions(res, DgtVideoQuestion.fromJson);
      if (parsed != null) {
        return parsed;
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

  /// Issue #134 (dgt-ux): quiz intensivo del peor tema. Backend BE#93:
  /// `GET /dgt/quiz/weak-focus?n={N}`.
  ///
  /// Devuelve un quiz 50/50 (mitad worst_topic + mitad resto) junto con el
  /// `worst_topic_id` y su `accuracy_pct` actual. Si el backend responde 400
  /// (historial DGT insuficiente: <20 respuestas, o ningun topic con minimo
  /// 5 respuestas) devolvemos un [DgtWeakFocusQuizResult] con
  /// `insufficientData = true` y `questions` vacio: la UI muestra empty
  /// state ("necesitas mas practica general"). Otros fallos (offline, 5xx)
  /// devuelven el mismo shape vacio con `insufficientData = false` para que
  /// la UI muestre "error, reintenta". Aditivo: no toca otros endpoints.
  Future<DgtWeakFocusQuizResult> fetchWeakFocusQuiz({int n = 20}) async {
    try {
      final clamped = n.clamp(4, 50);
      final res = await _api.get(
        '/dgt/quiz/weak-focus',
        query: {'n': '$clamped'},
      );
      if (res is Map) {
        final m = Map<String, dynamic>.from(res);
        final rawQs = m['questions'];
        final questions = (rawQs is List)
            ? rawQs
                .whereType<Map>()
                .map((e) => DgtQuestion.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : <DgtQuestion>[];
        return DgtWeakFocusQuizResult(
          worstTopicId: (m['worst_topic_id'] ?? '').toString(),
          worstTopicAccuracyPct:
              (m['worst_topic_accuracy_pct'] as num?)?.toDouble() ?? 0.0,
          worstTopicTotalAnswered:
              (m['worst_topic_total_answered'] as num?)?.toInt() ?? 0,
          questions: questions,
          insufficientData: false,
        );
      }
    } on ApiException catch (e) {
      // 400 = backend dice "historial DGT insuficiente para detectar peor
      // tema". UX-wise no es error; pedimos al usuario practicar mas general.
      if (e.statusCode == 400) {
        return const DgtWeakFocusQuizResult(
          worstTopicId: '',
          worstTopicAccuracyPct: 0.0,
          worstTopicTotalAnswered: 0,
          questions: <DgtQuestion>[],
          insufficientData: true,
        );
      }
      // 401/403/5xx etc: degrada a "error reintenta" (insufficientData=false,
      // questions vacio) sin throw para que la screen pueda mostrar empty.
    } catch (_) {
      // Offline / backend no expone endpoint / parse fail.
    }
    return const DgtWeakFocusQuizResult(
      worstTopicId: '',
      worstTopicAccuracyPct: 0.0,
      worstTopicTotalAnswered: 0,
      questions: <DgtQuestion>[],
      insufficientData: false,
    );
  }

  /// Issue #129 (dgt-ux): reportar errata en una pregunta DGT. Backend BE#113:
  /// `POST /dgt/questions/{id}/report`.
  ///
  /// Body: `{reason: str, comment: str?}`. Reasons aceptadas por backend:
  /// `wrong_answer`, `ambiguous`, `bad_image`, `outdated_law`, `typo`, `other`.
  ///
  /// Devuelve `true` si el backend respondio 2xx (report creado), `false` si
  /// hubo fallo (offline, 5xx, etc). 409 (duplicado mismo user+question) se
  /// considera `true` porque el reporte original ya existe.
  Future<bool> reportQuestion({
    required String questionId,
    required String reason,
    String? comment,
  }) async {
    try {
      final body = <String, dynamic>{'reason': reason};
      if (comment != null && comment.trim().isNotEmpty) {
        body['comment'] = comment.trim();
      }
      await _api.post('/dgt/questions/$questionId/report', body);
      return true;
    } on ApiException catch (e) {
      // 409 = duplicado: el report previo existe, lo consideramos exito UX.
      if (e.statusCode == 409) return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Issue #135 (dgt-ux): calentamiento de 10 preguntas variadas pre-simulacro.
  /// Backend BE#112: `GET /dgt/exam/random-warmup?limit={N}`.
  ///
  /// Mix de temas y dificultad baja-media para "activar la cabeza" sin
  /// intimidar (3-5 minutos, feedback inmediato, no se guarda en historial).
  /// Si el backend antiguo no expone el endpoint, hace fallback a una muestra
  /// barajada del banco local mini (no garantiza la mezcla pero garantiza
  /// que el flujo de UI funcione offline).
  ///
  /// Aditivo: no toca cache de simulacro, no persiste, no rompe los demas
  /// fetchers. El resultado se consume por `DgtWarmupScreen` que descarta
  /// los aciertos/fallos (no contribuyen al historial de simulacros).
  Future<List<DgtQuestion>> fetchRandomWarmup({int limit = 10}) async {
    try {
      final res = await _api.get(
        '/dgt/exam/random-warmup',
        query: {'limit': '$limit'},
      );
      final parsed = _parseQuestions(res);
      if (parsed != null && parsed.isNotEmpty) {
        return parsed;
      }
    } catch (_) {
      // Backend antiguo / offline / 5xx -> fallback local.
    }
    // Fallback: muestra barajada del banco local mini.
    final local = List<DgtQuestion>.from(dgtLocalBank)..shuffle(Random());
    if (local.length <= limit) return local;
    return local.take(limit).toList();
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

  /// Issue #154 (dgt-ux): erratas recurrentes del usuario. Backend BE#149:
  /// `GET /dgt/quiz/recurrent-failures?min_fails={N}&limit={M}`.
  ///
  /// Devuelve preguntas DGT que el usuario ha fallado `>= min_fails` veces
  /// en los ultimos 60 dias, ordenadas por fallos DESC y luego por fecha del
  /// ultimo fallo DESC. Cada item incluye un `fail_count` adicional.
  ///
  /// Clamps: `minFails` [2, 10], `limit` [1, 50].
  ///
  /// Errores (offline / 5xx / backend antiguo / parse fail) -> lista vacia
  /// y la UI muestra empty state ("Aun no tienes erratas recurrentes").
  /// Aditivo: no toca otros endpoints ni cache de simulacro.
  Future<List<DgtRecurrentFailureItem>> fetchRecurrentFailures({
    int minFails = 2,
    int limit = 20,
  }) async {
    final mf = minFails.clamp(2, 10);
    final lim = limit.clamp(1, 50);
    try {
      final res = await _api.get(
        '/dgt/quiz/recurrent-failures',
        query: {'min_fails': '$mf', 'limit': '$lim'},
      );
      final parsed =
          _parseGenericQuestions(res, DgtRecurrentFailureItem.fromJson);
      if (parsed != null) {
        return parsed;
      }
    } catch (_) {
      // Backend antiguo sin endpoint, offline, 5xx, o parse fail -> empty.
    }
    return const <DgtRecurrentFailureItem>[];
  }

  /// Issue #195 (dgt-ux): preguntas del mismo concepto que una pregunta dada.
  /// Backend: `GET /dgt/quiz/concept-related/{question_id}?limit={M}`.
  ///
  /// Usado por la pantalla "Errores conceptuales" para lanzar un quiz dirigido
  /// de N preguntas similares (mismo topic/concepto) a partir del primer
  /// fallo de un grupo. Si el endpoint falla -> lista vacia (UI muestra
  /// SnackBar y no navega).
  Future<List<DgtQuestion>> fetchConceptRelated({
    required String questionId,
    int limit = 10,
  }) async {
    final lim = limit.clamp(1, 50);
    try {
      final res = await _api.get(
        '/dgt/quiz/concept-related/$questionId',
        query: {'limit': '$lim'},
      );
      final parsed = _parseQuestions(res);
      if (parsed != null) return parsed;
    } catch (_) {
      // Backend antiguo / offline / 5xx -> empty.
    }
    return const <DgtQuestion>[];
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
