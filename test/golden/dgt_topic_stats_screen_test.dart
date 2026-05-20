import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_prediction.dart';
import 'package:memora/features/dgt/dgt_topic_stats_screen.dart';

import '../helpers/golden_helpers.dart';

/// Golden tests para `DgtTopicStatsScreen` (issue #132).
///
/// Cubre el caso "mix realista": un tema dominado (expert >=80%), uno
/// intermedio (60-80%), uno debil (<60%) y uno "Sin tocar" (totalAnswered=0,
/// issue #117). Sirve para detectar regresiones en:
/// - Barras de accuracy / cobertura (colores por umbral).
/// - Badge "Sin tocar" + posicionamiento al final de la lista.
/// - Layout de TopicStatTile (padding, tipografias, chevron).
///
/// Regeneracion: `flutter test --update-goldens test/golden/`.
void main() {
  testWidgets('lista mix beginner/intermediate/expert + intacto',
      (tester) async {
    await useGoldenSurface(tester);

    const stats = <DgtTopicStat>[
      // Expert: 95% accuracy, alta cobertura.
      DgtTopicStat(
        topicId: 'dgt-t-01',
        topicName: 'Senales',
        totalAnswered: 18,
        correct: 17,
        accuracyPct: 94.4,
      ),
      // Intermedio: 70% accuracy.
      DgtTopicStat(
        topicId: 'dgt-t-08',
        topicName: 'Normas de circulacion',
        totalAnswered: 10,
        correct: 7,
        accuracyPct: 70.0,
      ),
      // Debil: 40% accuracy.
      DgtTopicStat(
        topicId: 'dgt-t-12',
        topicName: 'Mecanica simple',
        totalAnswered: 10,
        correct: 4,
        accuracyPct: 40.0,
      ),
      // Intacto.
      DgtTopicStat(
        topicId: 'dgt-t-15',
        topicName: 'Primeros auxilios',
        totalAnswered: 0,
        correct: 0,
        accuracyPct: 0.0,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dgtTopicStatsProvider.overrideWith((ref) async => stats),
        ],
        child: wrapForGolden(const DgtTopicStatsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DgtTopicStatsScreen),
      matchesGoldenFile('goldens/dgt_topic_stats_screen_mix.png'),
    );
  });

  testWidgets('estado empty - sin reviews registradas', (tester) async {
    await useGoldenSurface(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dgtTopicStatsProvider
              .overrideWith((ref) async => const <DgtTopicStat>[]),
        ],
        child: wrapForGolden(const DgtTopicStatsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DgtTopicStatsScreen),
      matchesGoldenFile('goldens/dgt_topic_stats_screen_empty.png'),
    );
  });
}
