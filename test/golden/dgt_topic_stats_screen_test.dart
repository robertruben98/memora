import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_prediction.dart';
import 'package:memora/features/dgt/dgt_topic_stats_screen.dart';

import '../helpers/golden_helpers.dart';

/// Golden tests para `DgtTopicStatsScreen` (issue #132).
///
/// Mezcla beginner/intermediate/expert via accuracy buckets:
///  - "rojo" <60% (beginner)
///  - "ambar" 60-80% (intermediate)
///  - "verde" >=80% (expert)
/// Esto valida que los umbrales de color en `TopicStatTile.colorFor` se
/// renderizan correctamente y que el orden (peor primero) se preserva.
///
/// Para regenerar:
///   flutter test --update-goldens test/golden/dgt_topic_stats_screen_test.dart
void main() {
  setUpAll(() async {
    await loadGoldenFonts();
  });

  testWidgets('golden: mix beginner/intermediate/expert + tema intacto',
      (tester) async {
    await setGoldenViewport(tester);

    // dgt-t-01 (Senales) -> banco 19, answered 16 = ~84% cobertura, expert
    // dgt-t-08 (Normas)  -> banco 33, answered 18 = ~55% cobertura, intermediate
    // dgt-t-12 (Mecanica)-> banco 28, answered 6  = ~21% cobertura, beginner
    // dgt-t-14 (-)       -> totalAnswered=0       -> intacto al final
    final stats = [
      goldenStat(id: 'dgt-t-01', name: 'Senales', total: 16, correct: 15),
      goldenStat(id: 'dgt-t-08', name: 'Normas', total: 18, correct: 12),
      goldenStat(id: 'dgt-t-12', name: 'Mecanica', total: 6, correct: 2),
      goldenStat(id: 'dgt-t-14', name: 'Conduccion segura', total: 0, correct: 0),
    ];

    await tester.pumpWidget(
      wrapForGolden(
        const DgtTopicStatsScreen(),
        overrides: [
          dgtTopicStatsProvider.overrideWith((ref) async => stats),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DgtTopicStatsScreen),
      matchesGoldenFile('goldens/dgt_topic_stats_screen_mix.png'),
    );
  });

  testWidgets('golden: estado empty (sin respuestas registradas)',
      (tester) async {
    await setGoldenViewport(tester);

    await tester.pumpWidget(
      wrapForGolden(
        const DgtTopicStatsScreen(),
        overrides: [
          dgtTopicStatsProvider
              .overrideWith((ref) async => const <DgtTopicStat>[]),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DgtTopicStatsScreen),
      matchesGoldenFile('goldens/dgt_topic_stats_screen_empty.png'),
    );
  });

  testWidgets('cobertura: tile expert (>=80%) usa verde 0xFF4FFFB0',
      (tester) async {
    await setGoldenViewport(tester);

    final stats = [
      goldenStat(id: 'dgt-t-01', name: 'Senales', total: 10, correct: 9),
    ];

    await tester.pumpWidget(
      wrapForGolden(
        const DgtTopicStatsScreen(),
        overrides: [
          dgtTopicStatsProvider.overrideWith((ref) async => stats),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // El helper publico expone los umbrales: lo verificamos directamente
    // para que un cambio de paleta dispare este test (no solo el golden).
    expect(TopicStatTile.colorFor(90), const Color(0xFF4FFFB0));
    expect(find.text('90%'), findsOneWidget);
  });
}
