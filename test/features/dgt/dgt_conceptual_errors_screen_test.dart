import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/api/api_client.dart';
import 'package:memora/data/repositories/dgt_repository.dart';
import 'package:memora/features/dgt/dgt_conceptual_errors_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue #195 (dgt-ux): pantalla "Errores conceptuales". Cubre:
/// - [DgtRepository.fetchConceptRelated]: parsea lista plana, manda limit,
///   fallback a lista vacia ante error.
/// - Agrupacion client-side por topic (ordenada por totalFails DESC).
/// - Widget [DgtConceptualErrorsScreen]: empty state, grupos renderizados.

class _FakeApi extends ApiClient {
  final Map<String, Object> responsesByPath;
  String? lastPath;
  Map<String, String>? lastQuery;

  _FakeApi(this.responsesByPath)
      : super(baseUrl: 'http://test.invalid', token: 'fake');

  @override
  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    lastPath = path;
    lastQuery = query;
    final resp = responsesByPath[path] ??
        responsesByPath.entries
            .firstWhere(
              (e) => path.startsWith(e.key),
              orElse: () => const MapEntry('', <dynamic>[]),
            )
            .value;
    if (resp is Exception) throw resp;
    return resp;
  }
}

Map<String, dynamic> _rawFailure({
  required String id,
  required int failCount,
  required String topic,
  String statement = 'Pregunta DGT',
}) =>
    {
      'id': id,
      'statement': statement,
      'option_a': 'A',
      'option_b': 'B',
      'option_c': 'C',
      'correct': 'a',
      'explanation': 'expl',
      'topic': topic,
      'fail_count': failCount,
    };

Map<String, dynamic> _rawQuestion({required String id}) => {
      'id': id,
      'statement': 'pregunta $id',
      'option_a': 'A',
      'option_b': 'B',
      'option_c': 'C',
      'correct': 'a',
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DgtRepository.fetchConceptRelated', () {
    test('parsea lista plana y manda limit', () async {
      final api = _FakeApi({
        '/dgt/quiz/concept-related/q1': [
          _rawQuestion(id: 'q1'),
          _rawQuestion(id: 'q2'),
        ],
      });
      final repo = DgtRepository(api);
      final list =
          await repo.fetchConceptRelated(questionId: 'q1', limit: 10);
      expect(list, hasLength(2));
      expect(list.first.id, 'q1');
      expect(api.lastPath, '/dgt/quiz/concept-related/q1');
      expect(api.lastQuery, {'limit': '10'});
    });

    test('limit clamp [1, 50]', () async {
      final api = _FakeApi({
        '/dgt/quiz/concept-related/qX': const <Map<String, dynamic>>[],
      });
      final repo = DgtRepository(api);
      await repo.fetchConceptRelated(questionId: 'qX', limit: 999);
      expect(api.lastQuery, {'limit': '50'});
      await repo.fetchConceptRelated(questionId: 'qX', limit: 0);
      expect(api.lastQuery, {'limit': '1'});
    });

    test('endpoint error -> lista vacia', () async {
      final api = _FakeApi({
        '/dgt/quiz/concept-related/q1': Exception('500'),
      });
      final repo = DgtRepository(api);
      final list = await repo.fetchConceptRelated(questionId: 'q1');
      expect(list, isEmpty);
    });
  });

  group('groupByConceptForTest', () {
    test('agrupa por topic y ordena por totalFails DESC', () {
      final items = [
        DgtRecurrentFailureItem.fromJson(
            _rawFailure(id: 'a1', failCount: 2, topic: 'Prioridad')),
        DgtRecurrentFailureItem.fromJson(
            _rawFailure(id: 'a2', failCount: 4, topic: 'Adelantamiento')),
        DgtRecurrentFailureItem.fromJson(
            _rawFailure(id: 'a3', failCount: 3, topic: 'Prioridad')),
        DgtRecurrentFailureItem.fromJson(
            _rawFailure(id: 'a4', failCount: 1, topic: '')),
      ];
      final groups = groupByConceptForTest(items);
      // Prioridad = 5, Adelantamiento = 4, Sin topic = 1
      expect(groups.map((g) => g.topic).toList(),
          ['Prioridad', 'Adelantamiento', 'Sin topic']);
      expect(groups.first.totalFails, 5);
      expect(groups.first.count, 2);
      expect(groups[1].totalFails, 4);
      expect(groups[2].topic, 'Sin topic');
    });

    test('lista vacia -> sin grupos', () {
      expect(groupByConceptForTest(const []), isEmpty);
    });
  });

  group('DgtConceptualErrorsScreen', () {
    Widget wrap(Widget child, {required ApiClient api}) {
      return ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(home: child),
      );
    }

    testWidgets('empty state cuando no hay errores recurrentes',
        (tester) async {
      final api = _FakeApi({
        '/dgt/quiz/recurrent-failures': const <Map<String, dynamic>>[],
      });
      await tester.pumpWidget(
        wrap(const DgtConceptualErrorsScreen(), api: api),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Sin errores recurrentes. Sigue asi.'),
          findsOneWidget);
    });

    testWidgets('renderiza grupos por concepto ordenados', (tester) async {
      final api = _FakeApi({
        '/dgt/quiz/recurrent-failures': [
          _rawFailure(
              id: 'q1',
              failCount: 5,
              topic: 'Prioridad de paso',
              statement: 'Quien tiene prioridad'),
          _rawFailure(
              id: 'q2',
              failCount: 2,
              topic: 'Adelantamiento',
              statement: 'Cuando puedes adelantar'),
          _rawFailure(
              id: 'q3',
              failCount: 1,
              topic: 'Prioridad de paso',
              statement: 'Stop o ceda'),
        ],
      });
      await tester.pumpWidget(
        wrap(const DgtConceptualErrorsScreen(), api: api),
      );
      // Resolver FutureBuilder + SharedPreferences future.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(find.text('Errores conceptuales'), findsWidgets);
      expect(find.text('Prioridad de paso'), findsOneWidget);
      expect(find.text('Adelantamiento'), findsOneWidget);
      // Prioridad de paso (totalFails 6) deberia ir primero. Comprobamos
      // que el badge `6` esta presente para esa fila.
      expect(find.text('6'), findsWidgets);
    });

    testWidgets('expandir grupo muestra boton Practicar similares',
        (tester) async {
      final api = _FakeApi({
        '/dgt/quiz/recurrent-failures': [
          _rawFailure(
              id: 'q1',
              failCount: 3,
              topic: 'Senales',
              statement: 'Que indica senal X'),
        ],
      });
      await tester.pumpWidget(
        wrap(const DgtConceptualErrorsScreen(), api: api),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      // Tap header to expand.
      await tester.tap(find.text('Senales'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Practicar'), findsOneWidget);
    });
  });
}
