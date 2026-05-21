import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_sprint_history_provider.dart';
import 'package:memora/features/dgt/widgets/sprint_histogram.dart';

/// Issue #152 (dgt-ux): cobertura visual minima del histograma.
/// - Empty state.
/// - Limita a [kDgtSprintHistogramWindow] barras.
/// - Semantica accesible por entrada.

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('empty state cuando no hay entradas', (tester) async {
    await tester.pumpWidget(
      _wrap(const SprintHistogram(entries: [])),
    );
    expect(
      find.textContaining('Aun no tienes sprints'),
      findsOneWidget,
    );
  });

  testWidgets('limita el numero de barras a window', (tester) async {
    final entries = <DgtSprintEntry>[];
    for (var i = 0; i < kDgtSprintHistogramWindow + 5; i++) {
      entries.add(
        DgtSprintEntry(
          timestamp: DateTime(2026, 4, 1).add(Duration(days: i)),
          total: 10,
          correct: i % 10,
          secondsUsed: 100,
        ),
      );
    }
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    await tester.pumpWidget(_wrap(SprintHistogram(entries: entries)));
    // El semantics label de cada entrada debe ser visible (limit = window).
    final labels = find.bySemanticsLabel(RegExp(r'^Sprint \d+ de 10'));
    expect(tester.widgetList(labels).length, kDgtSprintHistogramWindow);
  });
}
