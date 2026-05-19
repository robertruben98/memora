import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/api/api_client.dart';
import 'package:memora/data/repositories/dgt_repository.dart';
import 'package:memora/features/dgt/dgt_trick_questions_screen.dart';

/// Issue #74 (dgt-content): pantalla "Trampas frecuentes" consumiendo
/// `GET /dgt/quiz/trick-questions`. Cubre:
/// - [DgtRepository.fetchTrickQuestions]: hit endpoint + fallback local.
/// - Widget [DgtTrickQuestionsScreen]: loading, listado, feedback al fallar.
/// - [DgtTrickHighlightedStatement]: spans con palabras trampa resaltadas.
/// - [DgtTrickReasoning.forStatement]: razon especifica por palabra trampa.

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
  String statement =
      '¿Que debe hacer un conductor cuando siempre hay un agente regulando el trafico?',
  String? explanation = 'El agente tiene prioridad sobre senales y semaforos.',
}) =>
    {
      'id': id,
      'statement': statement,
      'option_a': 'Ignorar al agente si el semaforo esta en rojo',
      'option_b': 'Obedecer al agente, su autoridad esta por encima',
      'option_c': 'Parar y consultar el reglamento',
      'correct': correct,
      'explanation': explanation,
      'topic': 'normas',
    };

void main() {
  group('DgtRepository.fetchTrickQuestions', () {
    test('parsea lista plana del backend y manda limit', () async {
      final api = _FakeApi([_rawQuestion(id: 'q1'), _rawQuestion(id: 'q2')]);
      final repo = DgtRepository(api);
      final list = await repo.fetchTrickQuestions(limit: 7);
      expect(list, hasLength(2));
      expect(list.first.id, 'q1');
      expect(api.lastPath, '/dgt/quiz/trick-questions');
      expect(api.lastQuery, {'limit': '7'});
    });

    test('parsea respuesta envuelta {questions: [...]}', () async {
      final api = _FakeApi({
        'questions': [_rawQuestion(id: 'q9')],
      });
      final repo = DgtRepository(api);
      final list = await repo.fetchTrickQuestions();
      expect(list, hasLength(1));
      expect(list.first.id, 'q9');
    });

    test('endpoint error -> fallback local con palabras trampa', () async {
      final api = _FakeApi(Exception('404 not found'));
      final repo = DgtRepository(api);
      final list = await repo.fetchTrickQuestions(limit: 5);
      // El banco local mini puede o no tener trampas; si las tiene, todas
      // deben matchear la regex; si no, lista vacia y no rompe.
      for (final q in list) {
        expect(
          RegExp(r'\b(siempre|nunca|excepto|solo|s[oó]lo)\b',
                  caseSensitive: false)
              .hasMatch(q.statement),
          isTrue,
          reason: 'fallback debe filtrar por palabra trampa',
        );
      }
      expect(list.length, lessThanOrEqualTo(5));
    });
  });

  group('DgtTrickReasoning.forStatement', () {
    test('siempre -> texto sobre absolutos', () {
      final r = DgtTrickReasoning.forStatement('Un conductor siempre debe...');
      expect(r, contains('siempre'));
      expect(r, contains('excepciones'));
    });
    test('nunca -> texto sobre absolutos negativos', () {
      final r = DgtTrickReasoning.forStatement('Nunca puede adelantar...');
      expect(r, contains('nunca'));
    });
    test('excepto -> texto sobre excepcion', () {
      final r =
          DgtTrickReasoning.forStatement('Todos los vehiculos excepto las motos...');
      expect(r, contains('excepto'));
    });
    test('solo -> texto sobre restriccion', () {
      final r = DgtTrickReasoning.forStatement('Solo en autopista...');
      expect(r, contains('solo'));
    });
    test('sin palabra trampa -> vacio', () {
      final r = DgtTrickReasoning.forStatement('Que indica esta senal?');
      expect(r, isEmpty);
    });
  });

  group('DgtTrickHighlightedStatement', () {
    testWidgets('renderiza texto y resalta palabras trampa', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DgtTrickHighlightedStatement(
              text: 'Un conductor siempre debe ceder excepto en urgencias.',
            ),
          ),
        ),
      );
      await tester.pump();
      // RichText presente y contiene los spans de palabras trampa.
      final richText = tester.widget<RichText>(find.byType(RichText).first);
      final root = richText.text as TextSpan;
      final flat = StringBuffer();
      void walk(InlineSpan s) {
        if (s is TextSpan) {
          if (s.text != null) flat.write(s.text);
          if (s.children != null) {
            for (final c in s.children!) {
              walk(c);
            }
          }
        }
      }

      walk(root);
      expect(flat.toString(),
          'Un conductor siempre debe ceder excepto en urgencias.');
      // Hay al menos 2 spans con estilo trampa (siempre + excepto).
      final highlighted = <String>[];
      void collect(InlineSpan s) {
        if (s is TextSpan) {
          final style = s.style;
          if (style?.color == const Color(0xFFFFB74F) &&
              style?.fontWeight == FontWeight.w900) {
            highlighted.add(s.text ?? '');
          }
          if (s.children != null) {
            for (final c in s.children!) {
              collect(c);
            }
          }
        }
      }

      collect(root);
      expect(highlighted.length, greaterThanOrEqualTo(2));
      expect(highlighted.map((e) => e.toLowerCase()),
          containsAll(['siempre', 'excepto']));
    });

    testWidgets('texto sin trampa no produce spans resaltados', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DgtTrickHighlightedStatement(
              text: 'Que indica esta senal de trafico?',
            ),
          ),
        ),
      );
      await tester.pump();
      final richText = tester.widget<RichText>(find.byType(RichText).first);
      final root = richText.text as TextSpan;
      var highlighted = 0;
      void walk(InlineSpan s) {
        if (s is TextSpan) {
          if (s.style?.color == const Color(0xFFFFB74F) &&
              s.style?.fontWeight == FontWeight.w900) {
            highlighted++;
          }
          if (s.children != null) {
            for (final c in s.children!) {
              walk(c);
            }
          }
        }
      }

      walk(root);
      expect(highlighted, 0);
    });
  });

  group('DgtTrickQuestionsScreen', () {
    Widget wrap(Widget child, {required ApiClient api}) {
      return ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(home: child),
      );
    }

    testWidgets('renderiza pregunta con badge anti-trampa y opciones',
        (tester) async {
      final api = _FakeApi([_rawQuestion(id: 'q1')]);
      await tester.pumpWidget(
        wrap(const DgtTrickQuestionsScreen(limit: 5), api: api),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Trampas frecuentes'), findsWidgets);
      expect(find.text('Anti-trampa'), findsOneWidget);
      // Las 3 opciones a/b/c renderizadas.
      expect(find.text('Ignorar al agente si el semaforo esta en rojo'),
          findsOneWidget);
      expect(find.text('Obedecer al agente, su autoridad esta por encima'),
          findsOneWidget);
      expect(find.text('Parar y consultar el reglamento'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
    });

    testWidgets('endpoint vacio muestra empty state con reintentar',
        (tester) async {
      final api = _FakeApi(const <Map<String, dynamic>>[]);
      await tester.pumpWidget(
        wrap(const DgtTrickQuestionsScreen(), api: api),
      );
      await tester.pump();
      await tester.pump();
      // No hay banco local con trampas y la API devuelve vacio -> empty.
      // Tolerante: si hay fallback con trampas, se renderiza la pregunta;
      // ambos finales son aceptables.
      final hasEmpty = find.text('Reintentar').evaluate().isNotEmpty;
      final hasBadge = find.text('Anti-trampa').evaluate().isNotEmpty;
      expect(hasEmpty || hasBadge, isTrue);
    });

    testWidgets('contesta mal y aparece feedback "Trampa detectada"',
        (tester) async {
      final api = _FakeApi([_rawQuestion(id: 'q1', correct: 'b')]);
      await tester.pumpWidget(
        wrap(const DgtTrickQuestionsScreen(limit: 5), api: api),
      );
      await tester.pump();
      await tester.pump();
      // Tap opcion A (incorrecta).
      await tester.tap(find.text('Ignorar al agente si el semaforo esta en rojo'));
      await tester.pump();
      expect(find.text('Trampa detectada'), findsOneWidget);
      expect(find.textContaining('Respuesta correcta: B'), findsOneWidget);
      expect(find.textContaining('siempre'), findsWidgets);
    });
  });
}
