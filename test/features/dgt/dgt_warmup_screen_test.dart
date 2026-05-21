import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/api/api_client.dart';
import 'package:memora/features/dgt/dgt_warmup_screen.dart';

/// Issue #135 (dgt-ux): mini-sesion de calentamiento de 10 preguntas
/// variadas pre-simulacro. Cubre:
/// - Loading state al inicio (CircularProgressIndicator).
/// - Render de pregunta con 3 opciones (a/b/c) y progreso "1 de N".
/// - Feedback inmediato verde/rojo y boton siguiente habilitado al responder.
/// - Resumen final con score y CTAs ("Ahora si, simulacro real" + Salir).

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
  String statement = 'Pregunta de calentamiento',
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
  group('DgtWarmupScreen', () {
    testWidgets('muestra loading al inicio', (tester) async {
      final api = _FakeApi([_q()]);
      await tester.pumpWidget(_wrap(const DgtWarmupScreen(limit: 1), api: api));
      // Sin pump async aun: future en flight.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Drain pending timers/futures para evitar warning de pending timers.
      await tester.pumpAndSettle();
    });

    testWidgets('renderiza primera pregunta con opciones y progreso',
        (tester) async {
      final api = _FakeApi([_q(id: 'q1'), _q(id: 'q2')]);
      await tester.pumpWidget(_wrap(const DgtWarmupScreen(limit: 2), api: api));
      await tester.pumpAndSettle();

      expect(find.text('Calentamiento DGT'), findsOneWidget);
      expect(find.text('Pregunta 1 de 2'), findsOneWidget);
      expect(find.text('Opcion A correcta'), findsOneWidget);
      expect(find.text('Opcion B'), findsOneWidget);
      expect(find.text('Opcion C'), findsOneWidget);
      // Boton "Siguiente" deshabilitado antes de responder.
      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.onPressed, isNull);
    });

    testWidgets('al responder correcto habilita Siguiente con check verde',
        (tester) async {
      final api = _FakeApi([_q(id: 'q1', correct: 'a'), _q(id: 'q2')]);
      await tester.pumpWidget(_wrap(const DgtWarmupScreen(limit: 2), api: api));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Opcion A correcta'));
      await tester.pump();

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('al responder mal aparece icono rojo y check verde en correcta',
        (tester) async {
      final api = _FakeApi([_q(id: 'q1', correct: 'b')]);
      await tester.pumpWidget(_wrap(const DgtWarmupScreen(limit: 1), api: api));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Opcion A correcta'));
      await tester.pump();

      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('boton dice "Terminar" en la ultima pregunta', (tester) async {
      final api = _FakeApi([_q(correct: 'a')]);
      await tester.pumpWidget(_wrap(const DgtWarmupScreen(limit: 1), api: api));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Opcion A correcta'));
      await tester.pump();
      expect(find.text('Terminar'), findsOneWidget);
    });

    testWidgets('al terminar muestra summary con score y CTAs', (tester) async {
      final api = _FakeApi([_q(correct: 'a')]);
      await tester.pumpWidget(_wrap(const DgtWarmupScreen(limit: 1), api: api));
      await tester.pumpAndSettle();

      // Responder bien y terminar.
      await tester.tap(find.text('Opcion A correcta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminar'));
      await tester.pumpAndSettle();

      // Summary visible: aprobado (1/1 = 100%).
      expect(find.text('Estas listo'), findsOneWidget);
      expect(find.text('1 de 1 correctas (100%)'), findsOneWidget);
      expect(find.text('Ahora si, simulacro real'), findsOneWidget);
      expect(find.text('Salir'), findsOneWidget);
      // Mensaje de "no se guarda" presente.
      expect(
        find.textContaining('no se guarda'),
        findsOneWidget,
      );
    });

    testWidgets('summary muestra "Cabeza activada" si score < 70%',
        (tester) async {
      // 2 preguntas, fallamos las 2 -> 0/2 = 0%.
      final api = _FakeApi([_q(correct: 'a'), _q(correct: 'a')]);
      await tester.pumpWidget(_wrap(const DgtWarmupScreen(limit: 2), api: api));
      await tester.pumpAndSettle();

      // Q1 fallo.
      await tester.tap(find.text('Opcion B'));
      await tester.pump();
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      // Q2 fallo.
      await tester.tap(find.text('Opcion B'));
      await tester.pump();
      await tester.tap(find.text('Terminar'));
      await tester.pumpAndSettle();

      expect(find.text('Cabeza activada'), findsOneWidget);
      expect(find.text('0 de 2 correctas (0%)'), findsOneWidget);
    });

    testWidgets('una vez respondida no cambia con otro tap', (tester) async {
      final api = _FakeApi([_q(correct: 'a')]);
      await tester.pumpWidget(_wrap(const DgtWarmupScreen(limit: 1), api: api));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Opcion A correcta'));
      await tester.pump();
      // Re-tap en opcion B: no debe cambiar picked.
      await tester.tap(find.text('Opcion B'));
      await tester.pump();

      // Solo aparece 1 check verde (en la correcta) y 0 iconos rojos.
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsNothing);
    });
  });
}
