import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/api/api_client.dart';
import 'package:memora/data/repositories/dgt_repository.dart';
import 'package:memora/features/dgt/dgt_weak_focus_screen.dart';

/// Issue #134 (dgt-ux): pantalla "Atacar mi punto debil" consumiendo
/// `GET /dgt/quiz/weak-focus` (BE#93). Cubre:
/// - [DgtRepository.fetchWeakFocusQuiz]: parsing del payload, mapeo del flag
///   `insufficientData` cuando el backend responde 400, n clamp [4,50].
/// - Widget [DgtWeakFocusScreen]: empty state si insufficientData, header
///   chip con tema + accuracy, flujo de respuesta.
/// - [DgtWeakFocusHeaderChip]: colores segun threshold.

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

Map<String, dynamic> _rawQuestion({
  String id = 'q1',
  String correct = 'b',
  String statement = '¿Que indica esta senal?',
  String? explanation = 'Prioridad de paso',
}) =>
    {
      'id': id,
      'statement': statement,
      'option_a': 'Stop',
      'option_b': 'Ceda el paso',
      'option_c': 'Direccion obligatoria',
      'correct': correct,
      'explanation': explanation,
      'topic': 'normas',
    };

void main() {
  group('DgtRepository.fetchWeakFocusQuiz', () {
    test('parsea payload exitoso del backend (BE#93 shape)', () async {
      final api = _FakeApi({
        'worst_topic_id': 'dgt-t-08',
        'worst_topic_accuracy_pct': 42.5,
        'worst_topic_total_answered': 12,
        'questions': [
          _rawQuestion(id: 'q1'),
          _rawQuestion(id: 'q2'),
        ],
      });
      final repo = DgtRepository(api);
      final result = await repo.fetchWeakFocusQuiz(n: 6);
      expect(result.worstTopicId, 'dgt-t-08');
      expect(result.worstTopicAccuracyPct, closeTo(42.5, 0.001));
      expect(result.worstTopicTotalAnswered, 12);
      expect(result.questions, hasLength(2));
      expect(result.insufficientData, isFalse);
      expect(api.lastPath, '/dgt/quiz/weak-focus');
      expect(api.lastQuery, {'n': '6'});
    });

    test('clamp n al rango [4,50] al construir query', () async {
      final api = _FakeApi({
        'worst_topic_id': 'x',
        'worst_topic_accuracy_pct': 0.0,
        'worst_topic_total_answered': 0,
        'questions': <Map<String, dynamic>>[],
      });
      final repo = DgtRepository(api);
      await repo.fetchWeakFocusQuiz(n: 2);
      expect(api.lastQuery, {'n': '4'});
      await repo.fetchWeakFocusQuiz(n: 80);
      expect(api.lastQuery, {'n': '50'});
    });

    test('400 del backend -> insufficientData=true, questions vacio',
        () async {
      final api = _FakeApi(ApiException(400, 'historial insuficiente'));
      final repo = DgtRepository(api);
      final result = await repo.fetchWeakFocusQuiz();
      expect(result.insufficientData, isTrue);
      expect(result.questions, isEmpty);
      expect(result.worstTopicId, isEmpty);
    });

    test('5xx / offline -> insufficientData=false, questions vacio',
        () async {
      final api = _FakeApi(Exception('connection refused'));
      final repo = DgtRepository(api);
      final result = await repo.fetchWeakFocusQuiz();
      expect(result.insufficientData, isFalse);
      expect(result.questions, isEmpty);
    });

    test('500 ApiException -> insufficientData=false', () async {
      final api = _FakeApi(ApiException(500, 'boom'));
      final repo = DgtRepository(api);
      final result = await repo.fetchWeakFocusQuiz();
      expect(result.insufficientData, isFalse);
      expect(result.questions, isEmpty);
    });

    test('payload no-map -> insufficientData=false, vacio', () async {
      final api = _FakeApi('not-a-map');
      final repo = DgtRepository(api);
      final result = await repo.fetchWeakFocusQuiz();
      expect(result.insufficientData, isFalse);
      expect(result.questions, isEmpty);
    });
  });

  group('DgtWeakFocusHeaderChip', () {
    testWidgets('muestra topic name + accuracy formateada', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DgtWeakFocusHeaderChip(
              topicName: 'Normas de circulacion',
              accuracyPct: 42.7,
            ),
          ),
        ),
      );
      expect(find.textContaining('Normas de circulacion'), findsOneWidget);
      expect(find.textContaining('43%'), findsOneWidget);
    });

    testWidgets('accuracy >=75% pinta acento verde', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DgtWeakFocusHeaderChip(
              topicName: 'Senales',
              accuracyPct: 90.0,
            ),
          ),
        ),
      );
      // Texto presente con %.
      expect(find.textContaining('90%'), findsOneWidget);
    });
  });

  group('DgtWeakFocusScreen', () {
    Widget wrap(DgtRepository repo) {
      return ProviderScope(
        overrides: [
          dgtRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: DgtWeakFocusScreen(n: 4)),
      );
    }

    testWidgets('muestra loading inicial', (tester) async {
      final api = _FakeApi({
        'worst_topic_id': 'dgt-t-08',
        'worst_topic_accuracy_pct': 40.0,
        'worst_topic_total_answered': 10,
        'questions': [_rawQuestion(id: 'q1')],
      });
      final repo = DgtRepository(api);
      await tester.pumpWidget(wrap(repo));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('insufficientData -> empty state con copy especifico',
        (tester) async {
      final api = _FakeApi(ApiException(400, 'sin historial'));
      final repo = DgtRepository(api);
      await tester.pumpWidget(wrap(repo));
      await tester.pumpAndSettle();
      expect(find.textContaining('mas practica general'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('payload exitoso -> chip foco + pregunta 1/N',
        (tester) async {
      final api = _FakeApi({
        'worst_topic_id': 'dgt-t-08',
        'worst_topic_accuracy_pct': 40.0,
        'worst_topic_total_answered': 10,
        'questions': [
          _rawQuestion(id: 'q1'),
          _rawQuestion(id: 'q2'),
        ],
      });
      final repo = DgtRepository(api);
      await tester.pumpWidget(wrap(repo));
      await tester.pumpAndSettle();
      expect(find.textContaining('Foco:'), findsOneWidget);
      expect(find.textContaining('40%'), findsOneWidget);
      expect(find.text('Pregunta 1 / 2'), findsOneWidget);
    });

    testWidgets('tap en respuesta correcta muestra feedback', (tester) async {
      final api = _FakeApi({
        'worst_topic_id': 'dgt-t-08',
        'worst_topic_accuracy_pct': 40.0,
        'worst_topic_total_answered': 10,
        'questions': [_rawQuestion(id: 'q1', correct: 'b')],
      });
      final repo = DgtRepository(api);
      await tester.pumpWidget(wrap(repo));
      await tester.pumpAndSettle();
      // Tap en la opcion B (correcta).
      await tester.tap(find.text('Ceda el paso'));
      await tester.pump();
      expect(find.text('Correcto'), findsOneWidget);
      expect(find.textContaining('Respuesta correcta: B'), findsOneWidget);
    });
  });
}
