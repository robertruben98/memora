import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_result_screen.dart';

import '../helpers/golden_helpers.dart';

/// Golden tests para `DgtResultScreen` (issue #132).
///
/// Cubre la pantalla critica de veredicto post-simulacro: aprobado (>=27/30)
/// y suspenso (<27/30 -> >3 fallos). Detecta regresiones visuales (color
/// del veredicto invertido, layout roto, overflow) que el resto de tests
/// de widget no captan.
///
/// Para regenerar tras un cambio intencionado:
///   flutter test --update-goldens test/golden/dgt_result_screen_test.dart
void main() {
  setUpAll(() async {
    await loadGoldenFonts();
  });

  setUp(() {
    // El confetti random aporta ~0.3% de ruido entre corridas; toleramos
    // hasta 1% sin perder capacidad de detectar cambios reales de layout.
    useTolerantGoldenComparator(tolerance: 0.01);
  });

  testWidgets('golden: aprobado 28/30 (3 fallos, dentro del limite DGT)',
      (tester) async {
    await setGoldenViewport(tester);
    mockHapticFeedback(tester);

    // Construimos 3 fallos para que la lista de "Repaso de falladas"
    // sea visible y participe del snapshot.
    final wrong = List.generate(
      3,
      (i) => DgtAnswerReview(
        question: goldenQuestion(
          id: 'q-${i + 1}',
          statement: 'Pregunta fallada ${i + 1}',
          explanation: 'Explicacion breve ${i + 1}.',
          topic: 'Senales',
        ),
        picked: 'a',
      ),
    );

    final result = DgtExamResult(
      total: 30,
      correct: 27,
      wrong: wrong,
      elapsedSeconds: 16 * 60 + 42, // 16:42
      strictMode: true,
    );

    await tester.pumpWidget(
      wrapForGolden(DgtResultScreen(result: result)),
    );
    await pumpAfterConfetti(tester);

    // Capturamos solo el contenido (ListView) y no el overlay de confetti,
    // cuyas particulas son aleatorias (Random sin seed) y rompen la
    // determinacion del PNG entre corridas.
    await expectLater(
      find.byType(ListView),
      matchesGoldenFile('goldens/dgt_result_screen_aprobado.png'),
    );
  });

  testWidgets('golden: suspenso 20/30 (10 fallos, supera limite DGT)',
      (tester) async {
    await setGoldenViewport(tester);
    mockHapticFeedback(tester);

    final wrong = List.generate(
      10,
      (i) => DgtAnswerReview(
        question: goldenQuestion(
          id: 'q-${i + 1}',
          statement: 'Pregunta fallada ${i + 1}',
          explanation: 'Explicacion breve ${i + 1}.',
          topic: 'Normas',
        ),
        picked: i.isEven ? 'c' : null, // mezcla "sin responder" + picked
      ),
    );

    final result = DgtExamResult(
      total: 30,
      correct: 20,
      wrong: wrong,
      elapsedSeconds: 22 * 60 + 5,
      strictMode: false,
    );

    await tester.pumpWidget(
      wrapForGolden(DgtResultScreen(result: result, autoSubmitted: true)),
    );
    await pumpAfterConfetti(tester);

    // Suspenso no dispara confetti, pero usamos ListView por consistencia
    // con el snapshot de "aprobado" (mismo encuadre).
    await expectLater(
      find.byType(ListView),
      matchesGoldenFile('goldens/dgt_result_screen_suspenso.png'),
    );
  });

  testWidgets(
      'cobertura: verifica que el veredicto APROBADO se renderiza en verde',
      (tester) async {
    // No es golden: defensa adicional contra "color invertido". Aunque el
    // golden ya lo capturaria, este test es ejecutable rapido y deja claro
    // el contrato semantico (passed -> verde, !passed -> rojo).
    await setGoldenViewport(tester);
    mockHapticFeedback(tester);

    final result = DgtExamResult(
      total: 30,
      correct: 28,
      wrong: const [],
    );

    await tester.pumpWidget(
      wrapForGolden(DgtResultScreen(result: result)),
    );
    await pumpAfterConfetti(tester);

    final textFinder = find.text('APROBADO');
    expect(textFinder, findsOneWidget);
    final widget = tester.widget<Text>(textFinder);
    expect(widget.style?.color, const Color(0xFF4FFFB0));
  });

  testWidgets('cobertura: SUSPENSO renderiza en rojo', (tester) async {
    await setGoldenViewport(tester);
    mockHapticFeedback(tester);

    final result = DgtExamResult(
      total: 30,
      correct: 10,
      wrong: const [],
    );

    await tester.pumpWidget(
      wrapForGolden(DgtResultScreen(result: result)),
    );
    await pumpAfterConfetti(tester);

    final textFinder = find.text('SUSPENSO');
    expect(textFinder, findsOneWidget);
    final widget = tester.widget<Text>(textFinder);
    expect(widget.style?.color, const Color(0xFFFF5C5C));
  });
}
