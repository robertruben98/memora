import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_session_summary_screen.dart';

/// Issue #113 (dgt-ux): tests del widget [DgtSessionSummaryScreen].
///
/// Cubre:
/// - Render basico de stats (tiempo, # preguntas, % acierto, nombre tema).
/// - Calculo de fallos > 0 muestra CTA "Repasar fallos" y tarjeta de tema
///   mas debil.
/// - 100% de acierto oculta el CTA "Repasar fallos" (no hay fallos que
///   repasar) y la tarjeta de tema mas debil.
/// - El umbral `shouldShowFor(n)` solo activa el resumen con >= 5
///   preguntas respondidas.

void main() {
  group('DgtSessionSummaryScreen - shouldShowFor', () {
    test('umbral: < 5 preguntas no muestra resumen', () {
      expect(DgtSessionSummaryScreen.shouldShowFor(0), isFalse);
      expect(DgtSessionSummaryScreen.shouldShowFor(4), isFalse);
    });

    test('umbral: >= 5 preguntas muestra resumen', () {
      expect(DgtSessionSummaryScreen.shouldShowFor(5), isTrue);
      expect(DgtSessionSummaryScreen.shouldShowFor(20), isTrue);
    });
  });

  group('DgtSessionSummaryScreen - render', () {
    testWidgets('muestra nombre tema, tiempo, # preguntas y % acierto',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DgtSessionSummaryScreen(
            topicName: 'Senales',
            answeredCount: 10,
            correctCount: 8,
            elapsed: Duration(minutes: 3, seconds: 25),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Nombre tema visible.
      expect(find.text('Senales'), findsOneWidget);
      // Tiempo formateado mm:ss.
      expect(find.text('03:25'), findsOneWidget);
      // # preguntas.
      expect(find.text('10'), findsOneWidget);
      // % acierto: 8/10 = 80%.
      expect(find.text('80%'), findsOneWidget);
    });

    testWidgets('con fallos > 0 muestra CTA "Repasar fallos" y tema debil',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DgtSessionSummaryScreen(
            topicName: 'Normas',
            answeredCount: 10,
            correctCount: 6,
            elapsed: Duration(minutes: 5),
            weakestTopic: 'Normas',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Repasar fallos'), findsOneWidget);
      expect(find.text('Tema mas debil'), findsOneWidget);
      expect(find.textContaining('Repasa "Normas"'), findsOneWidget);
      // CTA Cerrar siempre presente.
      expect(find.text('Cerrar'), findsOneWidget);
    });

    testWidgets('100% acierto oculta "Repasar fallos" y tema debil',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DgtSessionSummaryScreen(
            topicName: 'Perfecto',
            answeredCount: 5,
            correctCount: 5,
            elapsed: Duration(seconds: 90),
            weakestTopic: 'Perfecto',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sin fallos: no aparece CTA de repaso.
      expect(find.text('Repasar fallos'), findsNothing);
      // Tampoco la card de tema debil (porque _wrong == 0).
      expect(find.text('Tema mas debil'), findsNothing);
      // Pero sigue habiendo CTA Cerrar.
      expect(find.text('Cerrar'), findsOneWidget);
      // % acierto 100.
      expect(find.text('100%'), findsOneWidget);
      // Tiempo 01:30.
      expect(find.text('01:30'), findsOneWidget);
    });
  });
}
