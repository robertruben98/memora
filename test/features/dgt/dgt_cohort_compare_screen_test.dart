import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_cohort_compare_screen.dart';

/// Issue #155 (dgt-ux): tests pantalla "Comparativa cohorte".
///
/// Cubre: render con 3 items, orden por diff DESC default (estoy mas fuerte
/// primero), toggle invierte a ASC (estoy mas debil primero), topbar
/// resumen "X arriba / Y abajo", empty state cuando cohorte vacia, y
/// parseo desde JSON del endpoint /dgt/stats/benchmark.

DgtBenchmarkItem _item(
  String id,
  String name, {
  double? userPct,
  required double globalPct,
}) {
  final delta = userPct == null ? null : userPct - globalPct;
  String? status;
  if (delta != null) {
    if (delta > 5) {
      status = 'above';
    } else if (delta < -5) {
      status = 'below';
    } else {
      status = 'avg';
    }
  }
  return DgtBenchmarkItem(
    topicId: id,
    topicName: name,
    userPct: userPct,
    globalPct: globalPct,
    delta: delta,
    status: status,
  );
}

DgtBenchmark _benchmark(List<DgtBenchmarkItem> topics, {int sample = 25}) {
  return DgtBenchmark(
    userAvgAccuracyPct: 70,
    globalAvgAccuracyPct: 65,
    percentile: 60,
    sampleSize: sample,
    topics: topics,
  );
}

Widget _wrap(DgtBenchmark bench) {
  return ProviderScope(
    overrides: [
      dgtBenchmarkProvider.overrideWith((ref) async => bench),
    ],
    child: const MaterialApp(home: DgtCohortCompareScreen()),
  );
}

void main() {
  group('DgtCohortCompareScreen', () {
    testWidgets('render 3 items: muestra todos los topics', (tester) async {
      final bench = _benchmark([
        _item('dgt-t-01', 'Senales', userPct: 80, globalPct: 70),
        _item('dgt-t-08', 'Normas', userPct: 50, globalPct: 65),
        _item('dgt-t-12', 'Mecanica', userPct: 60, globalPct: 60),
      ]);
      await tester.pumpWidget(_wrap(bench));
      await tester.pumpAndSettle();

      expect(find.text('Senales'), findsOneWidget);
      expect(find.text('Normas'), findsOneWidget);
      expect(find.text('Mecanica'), findsOneWidget);
    });

    testWidgets('orden default: delta DESC (mas fuerte primero)',
        (tester) async {
      final bench = _benchmark([
        // Default sort: strong (+10) first, neutral (0), weak (-15) last.
        _item('dgt-t-weak', 'Weak', userPct: 50, globalPct: 65),
        _item('dgt-t-mid', 'Mid', userPct: 60, globalPct: 60),
        _item('dgt-t-strong', 'Strong', userPct: 80, globalPct: 70),
      ]);
      await tester.pumpWidget(_wrap(bench));
      await tester.pumpAndSettle();

      final strongPos = tester
          .getTopLeft(find.byKey(const Key('benchmarkTile-dgt-t-strong')))
          .dy;
      final midPos = tester
          .getTopLeft(find.byKey(const Key('benchmarkTile-dgt-t-mid')))
          .dy;
      final weakPos = tester
          .getTopLeft(find.byKey(const Key('benchmarkTile-dgt-t-weak')))
          .dy;
      expect(strongPos < midPos, isTrue);
      expect(midPos < weakPos, isTrue);
    });

    testWidgets('toggle invierte orden a delta ASC (mas debil primero)',
        (tester) async {
      final bench = _benchmark([
        _item('dgt-t-strong', 'Strong', userPct: 80, globalPct: 70),
        _item('dgt-t-weak', 'Weak', userPct: 50, globalPct: 65),
      ]);
      await tester.pumpWidget(_wrap(bench));
      await tester.pumpAndSettle();

      // Pre-toggle: strong primero.
      var strongPos = tester
          .getTopLeft(find.byKey(const Key('benchmarkTile-dgt-t-strong')))
          .dy;
      var weakPos = tester
          .getTopLeft(find.byKey(const Key('benchmarkTile-dgt-t-weak')))
          .dy;
      expect(strongPos < weakPos, isTrue);

      // Tap toggle.
      await tester.tap(find.text('Donde estoy mas fuerte'));
      await tester.pumpAndSettle();

      // Post-toggle: weak primero.
      strongPos = tester
          .getTopLeft(find.byKey(const Key('benchmarkTile-dgt-t-strong')))
          .dy;
      weakPos = tester
          .getTopLeft(find.byKey(const Key('benchmarkTile-dgt-t-weak')))
          .dy;
      expect(weakPos < strongPos, isTrue);
      expect(find.text('Donde estoy mas debil'), findsOneWidget);
    });

    testWidgets('topbar resumen muestra arriba/abajo counts', (tester) async {
      final bench = _benchmark([
        _item('a', 'A', userPct: 80, globalPct: 60), // arriba
        _item('b', 'B', userPct: 75, globalPct: 60), // arriba
        _item('c', 'C', userPct: 40, globalPct: 60), // abajo
      ]);
      await tester.pumpWidget(_wrap(bench));
      await tester.pumpAndSettle();

      expect(
        find.text('Estas 2 temas por encima de la media, 1 por debajo.'),
        findsOneWidget,
      );
    });

    testWidgets('empty state cuando sampleSize=0', (tester) async {
      const empty = DgtBenchmark(
        globalAvgAccuracyPct: 0,
        sampleSize: 0,
        topics: <DgtBenchmarkItem>[],
      );
      await tester.pumpWidget(_wrap(empty));
      await tester.pumpAndSettle();

      expect(
        find.text('Aun no hay datos suficientes para comparar.'),
        findsOneWidget,
      );
    });

    testWidgets('item sin user_pct muestra "Sin respuestas"', (tester) async {
      final bench = _benchmark([
        _item('a', 'Con datos', userPct: 70, globalPct: 60),
        const DgtBenchmarkItem(
          topicId: 'b',
          topicName: 'Sin tocar',
          globalPct: 50,
        ),
      ]);
      await tester.pumpWidget(_wrap(bench));
      await tester.pumpAndSettle();

      expect(find.text('Sin respuestas'), findsOneWidget);
    });
  });

  group('DgtBenchmark.fromJson', () {
    test('parsea payload tipico del endpoint BE#107', () {
      final json = {
        'user_avg_accuracy_pct': 72.5,
        'global_avg_accuracy_pct': 65.0,
        'percentile': 70,
        'sample_size': 42,
        'topics': [
          {
            'topic_id': 'dgt-t-01',
            'topic_name': 'Senales',
            'user_pct': 80.0,
            'global_pct': 70.0,
            'delta': 10.0,
            'status': 'above',
          },
          {
            'topic_id': 'dgt-t-02',
            'topic_name': null,
            'user_pct': null,
            'global_pct': 60.0,
            'delta': null,
            'status': null,
          },
        ],
      };
      final b = DgtBenchmark.fromJson(json);
      expect(b.sampleSize, 42);
      expect(b.percentile, 70);
      expect(b.topics.length, 2);
      expect(b.topics[0].delta, 10.0);
      expect(b.topics[0].status, 'above');
      expect(b.topics[1].userPct, isNull);
      expect(b.aboveCount, 1);
      expect(b.belowCount, 0);
      expect(b.isEmpty, isFalse);
    });

    test('payload con topics vacios => isEmpty true', () {
      final b = DgtBenchmark.fromJson({
        'global_avg_accuracy_pct': 0.0,
        'sample_size': 0,
        'topics': <Map<String, dynamic>>[],
      });
      expect(b.isEmpty, isTrue);
    });
  });
}
