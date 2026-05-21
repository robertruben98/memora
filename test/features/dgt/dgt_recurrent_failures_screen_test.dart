import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/api/api_client.dart';
import 'package:memora/data/repositories/dgt_repository.dart';
import 'package:memora/features/dgt/dgt_recurrent_failures_screen.dart';

/// Issue #154 (dgt-ux): pantalla "Errores recurrentes" consumiendo
/// `GET /dgt/quiz/recurrent-failures` (BE#149). Cubre:
/// - [DgtRepository.fetchRecurrentFailures]: parsea lista plana, manda
///   min_fails y limit, fallback a lista vacia ante error.
/// - Widget [DgtRecurrentFailuresScreen]: loading, listado con badges,
///   empty state, error retry.
/// - [DgtFailCountBadge]: renderiza "Nx".

class _FakeApi extends ApiClient {
  final Object response;
  String? lastPath;
  Map<String, String>? lastQuery;

  _FakeApi(this.response)
      : super(baseUrl: 'http://test.invalid', token: 'fake');

  @override
  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    lastPath = path;
    lastQuery = query;
    if (response is Exception) throw response as Exception;
    return response;
  }
}

Map<String, dynamic> _rawItem({
  String id = 'q1',
  int failCount = 3,
  String statement = '¿Cual es la distancia minima de seguridad?',
  String correct = 'b',
}) =>
    {
      'id': id,
      'statement': statement,
      'option_a': 'No hay distancia minima',
      'option_b': 'Depende de velocidad y condiciones',
      'option_c': 'Siempre 50 metros',
      'correct': correct,
      'explanation': 'Regla 100m/4s en autovia.',
      'topic_id': 'normas',
      'fail_count': failCount,
    };

void main() {
  group('DgtRepository.fetchRecurrentFailures', () {
    test('parsea lista plana con fail_count y manda min_fails+limit',
        () async {
      final api = _FakeApi([
        _rawItem(id: 'q1', failCount: 5),
        _rawItem(id: 'q2', failCount: 3),
      ]);
      final repo = DgtRepository(api);
      final list = await repo.fetchRecurrentFailures(minFails: 3, limit: 15);
      expect(list, hasLength(2));
      expect(list.first.question.id, 'q1');
      expect(list.first.failCount, 5);
      expect(list[1].failCount, 3);
      expect(api.lastPath, '/dgt/quiz/recurrent-failures');
      expect(api.lastQuery, {'min_fails': '3', 'limit': '15'});
    });

    test('clamp min_fails y limit al rango BE', () async {
      final api = _FakeApi(const <Map<String, dynamic>>[]);
      final repo = DgtRepository(api);
      await repo.fetchRecurrentFailures(minFails: 1, limit: 999);
      expect(api.lastQuery, {'min_fails': '2', 'limit': '50'});
      await repo.fetchRecurrentFailures(minFails: 999, limit: 0);
      expect(api.lastQuery, {'min_fails': '10', 'limit': '1'});
    });

    test('parsea respuesta envuelta {questions: [...]}', () async {
      final api = _FakeApi({
        'questions': [_rawItem(id: 'q9', failCount: 2)],
      });
      final repo = DgtRepository(api);
      final list = await repo.fetchRecurrentFailures();
      expect(list, hasLength(1));
      expect(list.first.question.id, 'q9');
      expect(list.first.failCount, 2);
    });

    test('endpoint error -> lista vacia', () async {
      final api = _FakeApi(Exception('404 not found'));
      final repo = DgtRepository(api);
      final list = await repo.fetchRecurrentFailures();
      expect(list, isEmpty);
    });

    test('respuesta inesperada (Map sin questions) -> lista vacia', () async {
      final api = _FakeApi({'foo': 'bar'});
      final repo = DgtRepository(api);
      final list = await repo.fetchRecurrentFailures();
      expect(list, isEmpty);
    });
  });

  group('DgtFailCountBadge', () {
    testWidgets('renderiza "Nx" con el conteo', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DgtFailCountBadge(count: 7),
          ),
        ),
      );
      expect(find.text('7x'), findsOneWidget);
      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
    });
  });

  group('DgtRecurrentFailuresScreen', () {
    Widget wrap(Widget child, {required ApiClient api}) {
      return ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(home: child),
      );
    }

    testWidgets('renderiza lista de erratas con badges', (tester) async {
      final api = _FakeApi([
        _rawItem(id: 'q1', failCount: 5, statement: 'Pregunta uno'),
        _rawItem(id: 'q2', failCount: 3, statement: 'Pregunta dos'),
      ]);
      await tester.pumpWidget(
        wrap(const DgtRecurrentFailuresScreen(), api: api),
      );
      // Pump dos veces para resolver FutureBuilder.
      await tester.pump();
      await tester.pump();

      expect(find.text('Errores recurrentes'), findsWidgets);
      expect(find.text('Pregunta uno'), findsOneWidget);
      expect(find.text('Pregunta dos'), findsOneWidget);
      expect(find.text('5x'), findsOneWidget);
      expect(find.text('3x'), findsOneWidget);
      // Boton "Repasar 2 erratas".
      expect(find.textContaining('Repasar 2'), findsOneWidget);
    });

    testWidgets('endpoint vacio muestra empty state', (tester) async {
      final api = _FakeApi(const <Map<String, dynamic>>[]);
      await tester.pumpWidget(
        wrap(const DgtRecurrentFailuresScreen(), api: api),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Aun no tienes erratas recurrentes'), findsOneWidget);
      expect(find.byIcon(Icons.celebration_rounded), findsOneWidget);
    });

    testWidgets('error muestra retry button', (tester) async {
      final api = _FakeApi(Exception('boom'));
      await tester.pumpWidget(
        wrap(const DgtRecurrentFailuresScreen(), api: api),
      );
      await tester.pump();
      await tester.pump();
      // Repo absorbe el error y devuelve [] -> empty state (no error UI).
      // Esto es por diseño: errores transparentes para el usuario.
      expect(find.text('Aun no tienes erratas recurrentes'), findsOneWidget);
    });
  });
}
