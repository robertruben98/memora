import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/api/api_client.dart';
import 'package:memora/data/repositories/dgt_repository.dart';
import 'package:memora/features/dgt/dgt_video_questions_screen.dart';

/// Issue #77 (dgt-content): pantalla "Videos de percepcion de riesgo" DGT 2026.
///
/// Cubre:
/// - Modelo [DgtVideoQuestion.fromJson]: parser tolerante con campos crudos.
/// - [DgtRepository.fetchVideoQuestions]: respuesta lista, lista vacia y error.
/// - Widget [DgtVideoQuestionsScreen]: loading, listado, empty state.
/// - Widget [DgtVideoQuestionTile]: render + tap.
/// - Helper [DgtVideoQuestionTile.labelForRiskType] mapea risk_types comunes.

/// Fake minimalista: respuesta unica para `GET /dgt/video-questions`.
class _FakeApi extends ApiClient {
  final Object response; // List, Map o Exception.
  int calls = 0;
  String? lastPath;
  Map<String, String>? lastQuery;

  _FakeApi(this.response) : super(baseUrl: 'http://test.invalid', token: 'fake');

  @override
  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    calls++;
    lastPath = path;
    lastQuery = query;
    if (response is Exception) throw response as Exception;
    return response;
  }
}

Map<String, dynamic> _rawVideo({
  String id = 'v1',
  String correct = 'b',
  String riskType = 'peaton_oculto',
  String? thumb = 'https://cdn.example/thumb.jpg',
}) =>
    {
      'id': id,
      'statement': '¿Que harias al ver al peaton?',
      'option_a': 'Acelerar',
      'option_b': 'Frenar suavemente',
      'option_c': 'Tocar bocina',
      'correct': correct,
      'explanation': 'El peaton tiene prioridad cuando aparece oculto.',
      'video_url': 'https://cdn.example/v.mp4',
      'thumbnail_url': thumb,
      'topic_id': 'dgt-t-01',
      'risk_type': riskType,
      'created_at': 0,
      'card_type': 'dgt_video',
    };

void main() {
  group('DgtVideoQuestion.fromJson', () {
    test('parsea campos requeridos y opcionales', () {
      final q = DgtVideoQuestion.fromJson(_rawVideo());
      expect(q.id, 'v1');
      expect(q.statement, '¿Que harias al ver al peaton?');
      expect(q.optionA, 'Acelerar');
      expect(q.optionB, 'Frenar suavemente');
      expect(q.optionC, 'Tocar bocina');
      expect(q.correct, 'b');
      expect(q.explanation, contains('peaton'));
      expect(q.videoUrl, 'https://cdn.example/v.mp4');
      expect(q.thumbnailUrl, 'https://cdn.example/thumb.jpg');
      expect(q.topicId, 'dgt-t-01');
      expect(q.riskType, 'peaton_oculto');
    });

    test('correct se normaliza a lower-case', () {
      final q = DgtVideoQuestion.fromJson(_rawVideo(correct: 'B'));
      expect(q.correct, 'b');
    });

    test('thumbnail_url null es aceptado', () {
      final q = DgtVideoQuestion.fromJson(_rawVideo(thumb: null));
      expect(q.thumbnailUrl, isNull);
    });
  });

  group('DgtRepository.fetchVideoQuestions', () {
    test('parsea lista plana del backend', () async {
      final api = _FakeApi([_rawVideo(id: 'v1'), _rawVideo(id: 'v2')]);
      final repo = DgtRepository(api);
      final list = await repo.fetchVideoQuestions(limit: 5);
      expect(list, hasLength(2));
      expect(list.first.id, 'v1');
      expect(api.lastPath, '/dgt/video-questions');
      expect(api.lastQuery, {'limit': '5'});
    });

    test('parsea respuesta envuelta {questions: [...]}', () async {
      final api = _FakeApi({
        'questions': [_rawVideo(id: 'v9')],
      });
      final repo = DgtRepository(api);
      final list = await repo.fetchVideoQuestions();
      expect(list, hasLength(1));
      expect(list.first.id, 'v9');
    });

    test('endpoint inexistente / error devuelve lista vacia', () async {
      final api = _FakeApi(Exception('backend old, no endpoint'));
      final repo = DgtRepository(api);
      final list = await repo.fetchVideoQuestions();
      expect(list, isEmpty);
    });

    test('respuesta no-lista no-mapa devuelve lista vacia', () async {
      final api = _FakeApi(<String, dynamic>{'foo': 'bar'});
      final repo = DgtRepository(api);
      final list = await repo.fetchVideoQuestions();
      expect(list, isEmpty);
    });
  });

  group('DgtVideoQuestionTile.labelForRiskType', () {
    test('mapea risk_types conocidos', () {
      expect(
          DgtVideoQuestionTile.labelForRiskType('peaton_oculto'), 'Peaton oculto');
      expect(DgtVideoQuestionTile.labelForRiskType('ciclista_cruce'),
          'Ciclista en cruce');
      expect(DgtVideoQuestionTile.labelForRiskType('vehiculo_tapa_vision'),
          'Vehiculo tapa vision');
      expect(DgtVideoQuestionTile.labelForRiskType('semaforo_ambar'),
          'Semaforo ambar');
      expect(
          DgtVideoQuestionTile.labelForRiskType('otro'), 'Otra situacion');
    });

    test('risk_type desconocido cae al raw', () {
      expect(DgtVideoQuestionTile.labelForRiskType('xyz_nuevo'), 'xyz_nuevo');
    });
  });

  group('DgtVideoQuestionsScreen', () {
    Widget wrap(Widget child, {required ApiClient api}) {
      return ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
        ],
        child: MaterialApp(home: child),
      );
    }

    testWidgets('renderiza lista con preguntas', (tester) async {
      final api = _FakeApi([
        _rawVideo(id: 'v1'),
        _rawVideo(id: 'v2', riskType: 'ciclista_cruce', thumb: null),
      ]);
      await tester.pumpWidget(
        wrap(const DgtVideoQuestionsScreen(limit: 5), api: api),
      );
      // Resolve future + initial frame.
      await tester.pump();
      await tester.pump();

      expect(find.text('Videos de percepcion de riesgo'), findsOneWidget);
      // Hay 2 cards con badge VIDEO.
      expect(find.text('VIDEO'), findsNWidgets(2));
      // Etiquetas humanas.
      expect(find.text('Peaton oculto'), findsOneWidget);
      expect(find.text('Ciclista en cruce'), findsOneWidget);
    });

    testWidgets('muestra empty state cuando backend devuelve []',
        (tester) async {
      final api = _FakeApi(const <Map<String, dynamic>>[]);
      await tester.pumpWidget(
        wrap(const DgtVideoQuestionsScreen(), api: api),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Proximamente: videos oficiales DGT 2026'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('muestra empty state cuando endpoint no existe', (tester) async {
      // Backend antiguo sin /dgt/video-questions -> repo devuelve lista vacia
      // -> empty state.
      final api = _FakeApi(Exception('404 not found'));
      await tester.pumpWidget(
        wrap(const DgtVideoQuestionsScreen(), api: api),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Proximamente: videos oficiales DGT 2026'),
        findsOneWidget,
      );
    });
  });

  group('DgtVideoQuestionTile widget', () {
    testWidgets('tap dispara callback', (tester) async {
      final q = DgtVideoQuestion.fromJson(_rawVideo());
      var taps = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(
              ApiClient(baseUrl: 'http://test.invalid', token: 'fake'),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DgtVideoQuestionTile(
                question: q,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // statement visible.
      expect(find.textContaining('peaton'), findsOneWidget);
      await tester.tap(find.byType(InkWell));
      await tester.pump();
      expect(taps, 1);
    });
  });
}
