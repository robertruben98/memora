import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_prediction.dart';
import 'package:memora/features/dgt/dgt_time_of_day_insight_provider.dart';
import 'package:memora/features/dgt/dgt_topic_stats_screen.dart';

/// Issue #67 (dgt-ux): pantalla "Estadisticas por tema".
/// Cubre: render con 3 stats fake, ordenacion por accuracy, tap en tile
/// dispara callback, color helper segun umbrales y estado empty.

DgtTopicStat _stat(String id, String name, int total, int correct) {
  final pct = total == 0 ? 0.0 : (correct / total) * 100.0;
  return DgtTopicStat(
    topicId: id,
    topicName: name,
    totalAnswered: total,
    correct: correct,
    accuracyPct: pct,
  );
}

void main() {
  group('TopicStatTile', () {
    testWidgets('renderiza nombre, accuracy y aciertos/total', (tester) async {
      final s = _stat('dgt-t-01', 'Senales', 10, 7);
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopicStatTile(stat: s, onTap: () => tapped++),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Senales'), findsOneWidget);
      expect(find.text('70%'), findsOneWidget);
      expect(find.text('7/10 aciertos'), findsOneWidget);
      await tester.tap(find.byType(InkWell));
      await tester.pump();
      expect(tapped, 1);
    });

    test('color helper aplica umbrales rojo<60 / ambar 60-80 / verde>=80', () {
      expect(TopicStatTile.colorFor(45), const Color(0xFFFF5C5C));
      expect(TopicStatTile.colorFor(60), const Color(0xFFFFB74F));
      expect(TopicStatTile.colorFor(79.9), const Color(0xFFFFB74F));
      expect(TopicStatTile.colorFor(80), const Color(0xFF4FFFB0));
      expect(TopicStatTile.colorFor(95), const Color(0xFF4FFFB0));
    });

    test(
        'issue #117: coverage color helper gris<30 / ambar 30-70 / verde>=70',
        () {
      expect(TopicStatTile.coverageColorFor(0), const Color(0xFF7A7A7A));
      expect(TopicStatTile.coverageColorFor(29.9), const Color(0xFF7A7A7A));
      expect(TopicStatTile.coverageColorFor(30), const Color(0xFFFFB74F));
      expect(TopicStatTile.coverageColorFor(69.9), const Color(0xFFFFB74F));
      expect(TopicStatTile.coverageColorFor(70), const Color(0xFF4FFFB0));
      expect(TopicStatTile.coverageColorFor(100), const Color(0xFF4FFFB0));
    });

    test('issue #117: DgtTopicStat.coveragePct usa kDgtTopicBankSize', () {
      // dgt-t-01 -> 19 questions. answered=19 -> 100%.
      const full = DgtTopicStat(
        topicId: 'dgt-t-01',
        totalAnswered: 19,
        correct: 19,
        accuracyPct: 100,
      );
      expect(full.bankSize, 19);
      expect(full.coveragePct, 100.0);

      // answered>bank => clamped.
      const over = DgtTopicStat(
        topicId: 'dgt-t-01',
        totalAnswered: 50,
        correct: 50,
        accuracyPct: 100,
      );
      expect(over.coveragePct, 100.0);

      // topic desconocido -> fallback kDgtDefaultBankSize.
      const unknown = DgtTopicStat(
        topicId: 'dgt-t-99',
        totalAnswered: 10,
        correct: 5,
        accuracyPct: 50,
      );
      expect(unknown.bankSize, kDgtDefaultBankSize);
      expect(unknown.coveragePct, (10 / kDgtDefaultBankSize) * 100.0);
    });

    testWidgets('cae a topicId cuando topicName es null o vacio',
        (tester) async {
      const s = DgtTopicStat(
        topicId: 'dgt-t-12',
        totalAnswered: 4,
        correct: 2,
        accuracyPct: 50.0,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopicStatTile(stat: s, onTap: () {}),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('dgt-t-12'), findsOneWidget);
    });
  });

  group('DgtTopicStatsScreen', () {
    testWidgets('lista 3 stats ordenadas peor accuracy primero',
        (tester) async {
      final stats = [
        _stat('dgt-t-01', 'Senales', 10, 9), // 90%
        _stat('dgt-t-08', 'Normas', 10, 4), // 40%
        _stat('dgt-t-12', 'Mecanica', 10, 7), // 70%
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dgtTopicStatsProvider.overrideWith((ref) async => stats),
            dgtTimeOfDayInsightProvider
                .overrideWith((ref) async => DgtTimeOfDayInsight.empty()),
          ],
          child: const MaterialApp(home: DgtTopicStatsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Las 3 tiles renderizan.
      expect(find.text('Senales'), findsOneWidget);
      expect(find.text('Normas'), findsOneWidget);
      expect(find.text('Mecanica'), findsOneWidget);

      // Orden: peor primero. Comparamos posiciones Y.
      final normasY = tester.getTopLeft(find.text('Normas')).dy;
      final mecanicaY = tester.getTopLeft(find.text('Mecanica')).dy;
      final senalesY = tester.getTopLeft(find.text('Senales')).dy;
      expect(normasY, lessThan(mecanicaY));
      expect(mecanicaY, lessThan(senalesY));
    });

    testWidgets('estado empty cuando no hay reviews', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dgtTopicStatsProvider
                .overrideWith((ref) async => const <DgtTopicStat>[]),
            dgtTimeOfDayInsightProvider
                .overrideWith((ref) async => DgtTimeOfDayInsight.empty()),
          ],
          child: const MaterialApp(home: DgtTopicStatsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Aun no hay respuestas'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets(
        'issue #117: temas con totalAnswered=0 se muestran como "Sin tocar"',
        (tester) async {
      final stats = [
        _stat('dgt-t-01', 'Senales', 5, 4),
        _stat('dgt-t-08', 'Normas', 0, 0), // intacto: visible al final
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dgtTopicStatsProvider.overrideWith((ref) async => stats),
            dgtTimeOfDayInsightProvider
                .overrideWith((ref) async => DgtTimeOfDayInsight.empty()),
          ],
          child: const MaterialApp(home: DgtTopicStatsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Senales'), findsOneWidget);
      expect(find.text('Normas'), findsOneWidget);
      expect(find.text('Sin tocar'), findsOneWidget);
      // Tema con respuestas primero, intacto despues.
      final senalesY = tester.getTopLeft(find.text('Senales')).dy;
      final normasY = tester.getTopLeft(find.text('Normas')).dy;
      expect(senalesY, lessThan(normasY));
    });

    testWidgets('issue #117: muestra barra de cobertura con denominador',
        (tester) async {
      // dgt-t-01 tiene 19 preguntas en kDgtTopicBankSize, respondidas 5 -> 5/19.
      final stats = [_stat('dgt-t-01', 'Senales', 5, 4)];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dgtTopicStatsProvider.overrideWith((ref) async => stats),
            dgtTimeOfDayInsightProvider
                .overrideWith((ref) async => DgtTimeOfDayInsight.empty()),
          ],
          child: const MaterialApp(home: DgtTopicStatsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cobertura'), findsOneWidget);
      expect(find.text('Accuracy'), findsOneWidget);
      expect(find.text('5/19'), findsOneWidget); // trailing cobertura
      expect(find.text('4/5'), findsOneWidget); // trailing accuracy
    });

    testWidgets('issue #117: tooltip de leyenda accessible desde AppBar',
        (tester) async {
      final stats = [_stat('dgt-t-01', 'Senales', 5, 4)];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dgtTopicStatsProvider.overrideWith((ref) async => stats),
            dgtTimeOfDayInsightProvider
                .overrideWith((ref) async => DgtTimeOfDayInsight.empty()),
          ],
          child: const MaterialApp(home: DgtTopicStatsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      // El boton help_outline abre dialog con texto sobre cobertura.
      await tester.tap(find.byIcon(Icons.help_outline_rounded));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cobertura'), findsWidgets);
      expect(find.text('Entendido'), findsOneWidget);
    });

    testWidgets('estado loading muestra CircularProgressIndicator',
        (tester) async {
      final completer = Completer<List<DgtTopicStat>>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dgtTopicStatsProvider.overrideWith((ref) => completer.future),
            dgtTimeOfDayInsightProvider
                .overrideWith((ref) async => DgtTimeOfDayInsight.empty()),
          ],
          child: const MaterialApp(home: DgtTopicStatsScreen()),
        ),
      );
      // No pumpAndSettle: queremos ver el loader.
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      completer.complete(const <DgtTopicStat>[]);
      await tester.pumpAndSettle();
    });
  });
}
