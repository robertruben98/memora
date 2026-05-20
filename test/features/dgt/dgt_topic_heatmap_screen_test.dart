import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/data/dgt_subtopic_repository.dart';
import 'package:memora/features/dgt/dgt_topic_heatmap_screen.dart';

/// Issue #138 (dgt-ux): heatmap drill-down dentro de un tema DGT.
/// Cubre:
/// - Renderiza 3 buckets (verde/ambar/rojo) con failPct y nombre.
/// - Boton "Practicar rojos" activo si hay >=1 rojo, deshabilitado si no.
/// - Helper colorFor mapea bucket -> color correcto.

DgtSubtopicStat _stat(String id, String name, int total, int incorrect) {
  final fail = total == 0 ? 0.0 : (incorrect / total) * 100.0;
  return DgtSubtopicStat(
    subtopicId: id,
    subtopicName: name,
    totalAnswered: total,
    incorrect: incorrect,
    failPct: fail,
  );
}

void main() {
  group('bucketFor', () {
    test('umbrales: verde <20, ambar 20-50, rojo >=50', () {
      expect(bucketFor(0), DgtHeatmapBucket.green);
      expect(bucketFor(19.9), DgtHeatmapBucket.green);
      expect(bucketFor(20), DgtHeatmapBucket.amber);
      expect(bucketFor(49.9), DgtHeatmapBucket.amber);
      expect(bucketFor(50), DgtHeatmapBucket.red);
      expect(bucketFor(100), DgtHeatmapBucket.red);
    });
  });

  group('SubtopicCell.colorFor', () {
    test('verde / ambar / rojo', () {
      expect(SubtopicCell.colorFor(DgtHeatmapBucket.green),
          const Color(0xFF2F8F5C));
      expect(SubtopicCell.colorFor(DgtHeatmapBucket.amber),
          const Color(0xFFB07A1F));
      expect(SubtopicCell.colorFor(DgtHeatmapBucket.red),
          const Color(0xFFB23A3A));
    });
  });

  testWidgets('renderiza 3 buckets distintos y muestra boton activo',
      (tester) async {
    final stats = [
      _stat('s-green', 'Cluster verde', 20, 2), // 10% fail
      _stat('s-amber', 'Cluster ambar', 20, 6), // 30% fail
      _stat('s-red', 'Cluster rojo', 20, 12), // 60% fail
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subtopicBreakdownProvider('dgt-t-01')
              .overrideWith((_) async => stats),
        ],
        child: const MaterialApp(
          home: DgtTopicHeatmapScreen(
            topicId: 'dgt-t-01',
            topicName: 'Senales',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cluster verde'), findsOneWidget);
    expect(find.text('Cluster ambar'), findsOneWidget);
    expect(find.text('Cluster rojo'), findsOneWidget);
    // Tres celdas tipo SubtopicCell.
    expect(find.byType(SubtopicCell), findsNWidgets(3));

    // Boton "practicar rojos (1)" presente y habilitado. `FilledButton.icon`
    // devuelve la subclase privada `_FilledButtonWithIcon`, asi que
    // `find.byType(FilledButton)` no la matchea: usamos predicado por subtipo.
    expect(find.text('Practicar solo los rojos (1)'), findsOneWidget);
    final any = find.ancestor(
      of: find.text('Practicar solo los rojos (1)'),
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    );
    expect(any, findsOneWidget);
    final filled = tester.widget<FilledButton>(any);
    expect(filled.onPressed, isNotNull);
  });

  testWidgets('sin rojos deshabilita el boton "practicar rojos"',
      (tester) async {
    final stats = [
      _stat('s1', 'A', 20, 1), // 5% fail
      _stat('s2', 'B', 20, 4), // 20% fail (ambar)
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subtopicBreakdownProvider('dgt-t-02')
              .overrideWith((_) async => stats),
        ],
        child: const MaterialApp(
          home: DgtTopicHeatmapScreen(
            topicId: 'dgt-t-02',
            topicName: 'Normas',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin clusters rojos: vas bien'), findsOneWidget);
    final any = find.ancestor(
      of: find.text('Sin clusters rojos: vas bien'),
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    );
    expect(any, findsOneWidget);
    final filled = tester.widget<FilledButton>(any);
    expect(filled.onPressed, isNull);
  });

  testWidgets('estado vacio cuando no hay subtopics', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subtopicBreakdownProvider('dgt-t-99')
              .overrideWith((_) async => const <DgtSubtopicStat>[]),
        ],
        child: const MaterialApp(
          home: DgtTopicHeatmapScreen(
            topicId: 'dgt-t-99',
            topicName: 'Vacio',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Aun no hay datos de subtemas'),
      findsOneWidget,
    );
  });
}
