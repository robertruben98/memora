import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_prediction.dart';
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
          ],
          child: const MaterialApp(home: DgtTopicStatsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Aun no hay respuestas'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('filtra temas con totalAnswered=0', (tester) async {
      final stats = [
        _stat('dgt-t-01', 'Senales', 5, 4),
        _stat('dgt-t-08', 'Normas', 0, 0), // sin respuestas, debe filtrarse
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dgtTopicStatsProvider.overrideWith((ref) async => stats),
          ],
          child: const MaterialApp(home: DgtTopicStatsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Senales'), findsOneWidget);
      expect(find.text('Normas'), findsNothing);
    });

    testWidgets('estado loading muestra CircularProgressIndicator',
        (tester) async {
      final completer = Completer<List<DgtTopicStat>>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dgtTopicStatsProvider.overrideWith((ref) => completer.future),
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
