import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/api/api_client.dart';
import 'package:memora/features/dgt/dgt_sprint_extreme_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue #210 (dgt-ux): cobertura del Sprint extremo.
/// - Pantalla CTA pre-confirmacion antes de cargar preguntas.
/// - Tras aceptar el reto: render de primera pregunta con timers visibles.
/// - Auto-skip a los 12s avanza a la siguiente pregunta sin marcar respuesta.
/// - Respuesta tap autoavanza con score correcto al completar.
/// - Timer global descendente expone tiempo color-coded inicial 05:00.

class _FakeApi extends ApiClient {
  final Object response;
  _FakeApi(this.response)
      : super(baseUrl: 'http://test.invalid', token: 'fake');

  @override
  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    if (response is Exception) throw response as Exception;
    return response;
  }
}

Map<String, dynamic> _q({
  String id = 'q1',
  String statement = 'Pregunta extremo',
  String correct = 'a',
  String optionA = 'Opcion A correcta',
  String optionB = 'Opcion B',
  String optionC = 'Opcion C',
}) =>
    {
      'id': id,
      'statement': statement,
      'option_a': optionA,
      'option_b': optionB,
      'option_c': optionC,
      'correct': correct,
      'explanation': null,
      'image_url': null,
      'topic': 'senales',
    };

Widget _wrap(Widget child, {required ApiClient api}) {
  return ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(api)],
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DgtSprintExtremeScreen', () {
    testWidgets('muestra pantalla de pre-confirmacion con CTA',
        (tester) async {
      final api = _FakeApi([_q()]);
      await tester.pumpWidget(
        _wrap(const DgtSprintExtremeScreen(), api: api),
      );
      await tester.pump();

      expect(find.text('Sprint extremo'), findsOneWidget);
      expect(find.text('Acepto el reto'), findsOneWidget);
      expect(find.textContaining('30 preguntas. 5 minutos.'), findsOneWidget);
    });

    testWidgets(
        'tras confirmar carga preguntas y muestra timer global 05:00 + per-question 12s',
        (tester) async {
      final api = _FakeApi([_q(id: 'q1'), _q(id: 'q2')]);
      await tester.pumpWidget(
        _wrap(const DgtSprintExtremeScreen(), api: api),
      );
      await tester.pump();
      await tester.tap(find.text('Acepto el reto'));
      await tester.pump();
      await tester.tap(find.text('Empezar'));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));

      expect(find.text('Pregunta 1 de 2'), findsOneWidget);
      expect(find.text('Opcion A correcta'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dgt-sprint-extreme-global-timer')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dgt-sprint-extreme-per-question')),
        findsOneWidget,
      );
      expect(find.text('05:00'), findsOneWidget);
      expect(find.text('12s'), findsOneWidget);
    });

    testWidgets(
        'auto-skip a los 12s avanza sin marcar respuesta',
        (tester) async {
      final api = _FakeApi([
        _q(id: 'q1', statement: 'Q1', optionA: 'A1'),
        _q(id: 'q2', statement: 'Q2', optionA: 'A2'),
      ]);
      await tester.pumpWidget(
        _wrap(const DgtSprintExtremeScreen(), api: api),
      );
      await tester.pump();
      await tester.tap(find.text('Acepto el reto'));
      await tester.pump();
      await tester.tap(find.text('Empezar'));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));

      expect(find.text('Q1'), findsOneWidget);

      // Avanzar el reloj 12 segundos -> auto-skip.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(find.text('Pregunta 2 de 2'), findsOneWidget);
      expect(find.text('Q2'), findsOneWidget);
    });

    testWidgets(
        'al responder correctamente la unica pregunta muestra resumen 1/1',
        (tester) async {
      final api = _FakeApi([
        _q(id: 'q1', correct: 'a', optionA: 'A correcta'),
      ]);
      await tester.pumpWidget(
        _wrap(const DgtSprintExtremeScreen(), api: api),
      );
      await tester.pump();
      await tester.tap(find.text('Acepto el reto'));
      await tester.pump();
      await tester.tap(find.text('Empezar'));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));

      await tester.tap(find.text('A correcta'));
      // 200ms delay + frame.
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();

      final scoreFinder = find.byKey(
        const ValueKey('dgt-sprint-extreme-score'),
      );
      expect(scoreFinder, findsOneWidget);
      expect(
        tester.widget<Text>(scoreFinder).data,
        '1 / 1',
      );
      expect(find.text('Cerrar'), findsOneWidget);
    });

    testWidgets('cancelar el dialogo cierra la pantalla', (tester) async {
      final api = _FakeApi([_q()]);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProviderScope(
                        overrides: [
                          apiClientProvider.overrideWithValue(api),
                        ],
                        child: const DgtSprintExtremeScreen(),
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Acepto el reto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // Volvio a la pantalla anterior.
      expect(find.text('Open'), findsOneWidget);
    });
  });

  test('constantes del sprint extremo son las esperadas', () {
    expect(kDgtSprintExtremeDurationSeconds, 300);
    expect(kDgtSprintExtremeQuestionCount, 30);
    expect(kDgtSprintExtremeAutoSkipSeconds, 12);
  });
}
