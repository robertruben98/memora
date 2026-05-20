import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/repositories/dgt_repository.dart';
import 'package:memora/features/dgt/dgt_result_screen.dart';

import '../helpers/golden_helpers.dart';

/// Golden tests para `DgtResultScreen` (issue #132).
///
/// Cubre dos escenarios criticos:
/// - Aprobado (>=27/30, criterio DGT permiso B = max 3 fallos).
/// - Suspenso (<27/30) con repaso de falladas.
///
/// Stubs:
/// - Platform channels HapticFeedback / SystemChannels.platform.
/// - Confetti se renderiza pero no animamos (await pump fijo, no
///   pumpAndSettle: confetti es un loop infinito y nunca settlea).
///
/// Regeneracion: `flutter test --update-goldens test/golden/`.
void main() {
  // Tolerancia 1% para el subtle diff que introduce el ConfettiWidget
  // (animacion no se puede congelar 100% deterministicamente). Sigue
  // capturando regresiones reales (layout roto, colores invertidos,
  // overflow), solo absorbe ruido subpixel/antialias.
  final originalComparator = goldenFileComparator;
  setUpAll(() {
    final base = (originalComparator as LocalFileComparator).basedir;
    goldenFileComparator = TolerantGoldenComparator(
      Uri.parse('${base}_dummy.dart'),
      tolerance: 0.01,
    );
  });
  tearDownAll(() {
    goldenFileComparator = originalComparator;
  });

  // Stub haptic feedback platform channel para evitar MissingPluginException
  // al ejecutar `HapticFeedback.mediumImpact()` desde initState.
  setUp(() {
    TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('aprobado 29/30 - veredicto verde + 1 fallada', (tester) async {
    await useGoldenSurface(tester);

    final wrong = DgtAnswerReview(
      question: const DgtQuestion(
        id: 'q-1',
        statement: 'Cual es la velocidad maxima en autovia?',
        optionA: '100 km/h',
        optionB: '120 km/h',
        optionC: '130 km/h',
        correct: 'b',
        explanation: 'En autovia, el limite general para turismos es 120 km/h.',
        topic: 'Normas y senales',
      ),
      picked: 'c',
    );

    final result = DgtExamResult(
      total: 30,
      correct: 29,
      wrong: [wrong],
      elapsedSeconds: 1320, // 22:00
      strictMode: true,
    );

    await tester.pumpWidget(
      // TickerMode(enabled:false) congela animaciones (incluida la del
      // ConfettiWidget que es un loop infinito y generaria diff pixel
      // entre runs).
      wrapForGolden(
        TickerMode(
          enabled: false,
          child: DgtResultScreen(result: result),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(DgtResultScreen),
      matchesGoldenFile('goldens/dgt_result_screen_passed.png'),
    );
  });

  testWidgets('suspenso 22/30 - veredicto rojo + 8 falladas', (tester) async {
    await useGoldenSurface(tester);

    DgtAnswerReview makeWrong(int i) => DgtAnswerReview(
          question: DgtQuestion(
            id: 'q-$i',
            statement: 'Pregunta numero $i sobre normas DGT.',
            optionA: 'Opcion A para $i',
            optionB: 'Opcion B para $i',
            optionC: 'Opcion C para $i',
            correct: 'a',
            explanation: 'Explicacion didactica de la pregunta $i.',
            topic: i.isEven ? 'Normas y senales' : 'Mecanica',
          ),
          picked: i % 3 == 0 ? null : 'b',
        );

    final result = DgtExamResult(
      total: 30,
      correct: 22,
      wrong: List.generate(8, makeWrong),
      elapsedSeconds: 1800, // 30:00
      strictMode: false,
    );

    await tester.pumpWidget(
      wrapForGolden(
        TickerMode(
          enabled: false,
          child: DgtResultScreen(result: result, autoSubmitted: true),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(DgtResultScreen),
      matchesGoldenFile('goldens/dgt_result_screen_failed.png'),
    );
  });
}
