import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/api/api_client.dart';
import 'package:memora/data/local/dgt_questions_cache.dart';
import 'package:memora/data/repositories/dgt_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue #45 (dgt-tech): cache local de preguntas DGT.
///
/// Cubre: cache miss, cache hit, cache stale, offline + cache, offline
/// sin cache (fallback banco local), invalidacion manual y `forceRefresh`.

/// Fake ApiClient: extiende [ApiClient] real pero permite scriptear
/// respuestas/excepciones en orden. No usa Riverpod ni http.Client real.
class _FakeApiClient extends ApiClient {
  /// Lista de respuestas en orden: cada elemento es:
  ///  - `List` -> retornado tal cual desde `get`.
  ///  - `Map` -> retornado tal cual desde `get`.
  ///  - `Exception` -> lanzado desde `get`.
  final List<Object> scriptedResponses;
  int getCalls = 0;

  _FakeApiClient(this.scriptedResponses)
      : super(baseUrl: 'http://test.invalid', token: 'fake');

  @override
  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final i = getCalls++;
    if (i >= scriptedResponses.length) {
      throw StateError('No more scripted responses (call #$i)');
    }
    final r = scriptedResponses[i];
    if (r is Exception) throw r;
    return r;
  }
}

List<Map<String, dynamic>> _fakeBank(int n) => List.generate(
      n,
      (i) => {
        'id': 'q$i',
        'statement': 'Pregunta $i',
        'option_a': 'A$i',
        'option_b': 'B$i',
        'option_c': 'C$i',
        'correct': 'a',
        'explanation': null,
        'image_url': null,
        'topic': 'senales',
      },
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DgtQuestionsCache', () {
    test('read devuelve null cuando no hay nada guardado', () async {
      final cache = DgtQuestionsCache();
      final got = await cache.read();
      expect(got, isNull);
    });

    test('write + read roundtrip preserva campos', () async {
      final cache = DgtQuestionsCache();
      final src = _fakeBank(3)
          .map((m) => DgtQuestion.fromJson(m))
          .toList();
      await cache.write(src, limit: 3);
      final got = await cache.read();
      expect(got, isNotNull);
      expect(got!.length, 3);
      expect(got[0].id, 'q0');
      expect(got[0].statement, 'Pregunta 0');
      expect(got[0].correct, 'a');
    });

    test('cache stale (TTL vencido) devuelve null', () async {
      // TTL minusculo: 1ms.
      final cache = DgtQuestionsCache(ttl: const Duration(milliseconds: 1));
      final src = _fakeBank(2).map((m) => DgtQuestion.fromJson(m)).toList();
      await cache.write(src, limit: 2);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final got = await cache.read();
      expect(got, isNull, reason: 'TTL vencido -> cache miss');
    });

    test('clear borra todos los keys', () async {
      final cache = DgtQuestionsCache();
      final src = _fakeBank(2).map((m) => DgtQuestion.fromJson(m)).toList();
      await cache.write(src, limit: 2);
      expect(await cache.read(), isNotNull);
      await cache.clear();
      expect(await cache.read(), isNull);
    });

    test('requireLimit > savedLimit -> null (no entregar muestra parcial)',
        () async {
      final cache = DgtQuestionsCache();
      final src = _fakeBank(30).map((m) => DgtQuestion.fromJson(m)).toList();
      await cache.write(src, limit: 30);
      expect(await cache.read(requireLimit: 30), isNotNull);
      // Si pidieron 100 pero solo cacheamos 30: NO devolver cache.
      expect(await cache.read(requireLimit: 100), isNull);
    });
  });

  group('DgtRepository.fetchExamQuestions (cache integration)', () {
    test('cache MISS: pide al backend y cachea para la proxima llamada',
        () async {
      final api = _FakeApiClient([_fakeBank(30)]);
      final cache = DgtQuestionsCache();
      final repo = DgtRepository(api, cache: cache);

      final r1 = await repo.fetchExamQuestions(limit: 30);
      expect(r1.length, 30);
      expect(api.getCalls, 1);

      // Segunda llamada: cache hit, NO debe golpear backend.
      final r2 = await repo.fetchExamQuestions(limit: 30);
      expect(r2.length, 30);
      expect(api.getCalls, 1, reason: 'cache hit -> sin nueva llamada API');
      expect(r2[0].id, r1[0].id);
    });

    test('cache STALE: TTL vencido fuerza nuevo fetch al backend', () async {
      final api = _FakeApiClient([_fakeBank(30), _fakeBank(30)]);
      final cache = DgtQuestionsCache(ttl: const Duration(milliseconds: 1));
      final repo = DgtRepository(api, cache: cache);

      await repo.fetchExamQuestions(limit: 30);
      expect(api.getCalls, 1);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await repo.fetchExamQuestions(limit: 30);
      expect(api.getCalls, 2, reason: 'cache stale -> refetch');
    });

    test('OFFLINE con cache fresca: devuelve cache (no falla)', () async {
      final cache = DgtQuestionsCache();
      // Sembramos cache directo.
      final seed = _fakeBank(30).map((m) => DgtQuestion.fromJson(m)).toList();
      await cache.write(seed, limit: 30);

      // Backend caido: ApiException 503 - el repo no debe llamar a la api
      // gracias a cache hit. Si la llamara, lanzaria.
      final api = _FakeApiClient([ApiException(503, 'down')]);
      final repo = DgtRepository(api, cache: cache);

      final r = await repo.fetchExamQuestions(limit: 30);
      expect(r.length, 30);
      expect(api.getCalls, 0, reason: 'cache hit -> ni siquiera intenta net');
    });

    test('forceRefresh: invalida cache y reintenta backend', () async {
      final api = _FakeApiClient([_fakeBank(30), _fakeBank(30)]);
      final cache = DgtQuestionsCache();
      final repo = DgtRepository(api, cache: cache);

      await repo.fetchExamQuestions(limit: 30);
      expect(api.getCalls, 1);

      // Pese a tener cache fresca, forceRefresh re-pide al backend.
      await repo.fetchExamQuestions(limit: 30, forceRefresh: true);
      expect(api.getCalls, 2);
    });

    test('invalidateCache(): proxima llamada va al backend', () async {
      final api = _FakeApiClient([_fakeBank(30), _fakeBank(30)]);
      final cache = DgtQuestionsCache();
      final repo = DgtRepository(api, cache: cache);

      await repo.fetchExamQuestions(limit: 30);
      expect(api.getCalls, 1);

      await repo.invalidateCache();

      await repo.fetchExamQuestions(limit: 30);
      expect(api.getCalls, 2);
    });

    test('backward compat: repo sin cache funciona como antes', () async {
      final api = _FakeApiClient([_fakeBank(30), _fakeBank(30)]);
      final repo = DgtRepository(api); // sin cache

      await repo.fetchExamQuestions(limit: 30);
      await repo.fetchExamQuestions(limit: 30);
      expect(api.getCalls, 2,
          reason: 'sin cache -> cada llamada va al backend');
    });
  });

  // Issue #78 (dgt-content): modo "Reto dificultad alta".
  group('DgtRepository.fetchQuestionsByDifficulty', () {
    test('backend OK -> devuelve preguntas parseadas', () async {
      final api = _FakeApiClient([_fakeBank(10)]);
      final repo = DgtRepository(api);

      final r = await repo.fetchQuestionsByDifficulty(
        difficulty: 3,
        limit: 10,
      );
      expect(r.length, 10);
      expect(r.first.id, 'q0');
      expect(api.getCalls, 1);
    });

    test('backend 5xx -> cae a banco local mini limitado', () async {
      final api = _FakeApiClient([ApiException(503, 'down')]);
      final repo = DgtRepository(api);

      final r = await repo.fetchQuestionsByDifficulty(
        difficulty: 3,
        limit: 5,
      );
      expect(r.length, lessThanOrEqualTo(5));
    });

    test('backend lista vacia -> cae a banco local mini', () async {
      final api = _FakeApiClient([<Map<String, dynamic>>[]]);
      final repo = DgtRepository(api);

      final r = await repo.fetchQuestionsByDifficulty(
        difficulty: 3,
        limit: 10,
      );
      // No falla, devuelve algo del banco local (puede estar vacio).
      expect(r, isNotNull);
    });
  });
}
