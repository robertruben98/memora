import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_prediction.dart';
import 'package:memora/features/study/dgt_exam_history.dart';
import 'package:memora/features/study/widgets/dgt_section.dart';
import 'package:memora/features/study/widgets/dgt_tile.dart';
import 'package:memora/features/study/widgets/dgt_tile_spec.dart';

/// Issue #148: validar que el tile registry mantiene el orden visual previo
/// del Study Hub y que la visibilidad condicional del weakest-topic respeta
/// el contrato del backend (solo visible cuando hay datos).
///
/// Estos tests sirven como guardrail contra el patron cascade DIRTY: si
/// alguien rompe el orden o el condicional al anadir un tile nuevo, esto
/// falla.
void main() {
  group('buildDgtTileRegistry', () {
    test('contiene los 8 tiles base en el orden visual esperado', () {
      final registry = buildDgtTileRegistry();
      expect(registry.length, 8);

      final titles = registry.map((s) => s.title).toList();
      expect(titles, [
        'Simulacro DGT',
        'Atacar mi punto debil',
        'Calentar 5 min',
        'Historial de simulacros',
        'Trampas frecuentes',
        'Autotest mental',
        'Estudiar por Secciones',
        'Catalogo de senales',
      ]);
    });

    test('el primer tile es hero (Simulacro DGT) y el de Secciones es section',
        () {
      final registry = buildDgtTileRegistry();
      expect(registry.first.variant, DgtTileVariant.hero);
      final sections =
          registry.firstWhere((s) => s.title == 'Estudiar por Secciones');
      expect(sections.variant, DgtTileVariant.section);
      expect(sections.leadingGap, 14);
    });

    test('weakest focus tile declara visibleWhen y badge Adaptativo', () {
      final registry = buildDgtTileRegistry();
      final weak =
          registry.firstWhere((s) => s.title == 'Atacar mi punto debil');
      expect(weak.visibleWhen, isNotNull);
      expect(weak.badgeText, 'Adaptativo');
    });
  });

  group('DgtStudySection rendering', () {
    testWidgets('oculta weakest-focus tile cuando prediction no tiene datos',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dgtPredictionProvider.overrideWith(
              (ref) async => DgtPrediction.empty,
            ),
            dgtExamHistoryProvider.overrideWith(
              (ref) async => const <DgtExamHistoryEntry>[],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(child: DgtStudySection())),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // El tile condicional NO debe aparecer.
      expect(find.text('Atacar mi punto debil'), findsNothing);
      // Pero los incondicionales si.
      expect(find.text('Simulacro DGT'), findsOneWidget);
      expect(find.text('Calentar 5 min'), findsOneWidget);
      expect(find.text('Historial de simulacros'), findsOneWidget);
    });

    testWidgets('muestra weakest-focus tile cuando hay weakestTopic',
        (tester) async {
      const weakStat = DgtTopicStat(
        topicId: 'dgt-t-01',
        topicName: 'Senales',
        totalAnswered: 12,
        correct: 5,
        accuracyPct: 42.0,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dgtPredictionProvider.overrideWith(
              (ref) async => const DgtPrediction(
                totalReviews: 30,
                expectedScore: 0.6,
                weakestTopic: weakStat,
              ),
            ),
            dgtExamHistoryProvider.overrideWith(
              (ref) async => const <DgtExamHistoryEntry>[],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(child: DgtStudySection())),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Atacar mi punto debil'), findsOneWidget);
      expect(find.textContaining('Foco: Senales'), findsOneWidget);
    });

    testWidgets('historial subtitle indica estado vacio cuando no hay entries',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dgtPredictionProvider.overrideWith(
              (ref) async => DgtPrediction.empty,
            ),
            dgtExamHistoryProvider.overrideWith(
              (ref) async => const <DgtExamHistoryEntry>[],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(child: DgtStudySection())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Aun sin simulacros completados'), findsOneWidget);
    });
  });

  group('DgtTile (reusable)', () {
    testWidgets('renderiza title, subtitle y badge para variant standard',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DgtTile(
                spec: DgtTileSpec(
                  title: 'Demo tile',
                  subtitle: 'subtitulo demo',
                  badgeText: 'Demo',
                  icon: Icons.bolt_rounded,
                  accentColor: const Color(0xFF7C5CFF),
                  routeBuilder: (_, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Demo tile'), findsOneWidget);
      expect(find.text('subtitulo demo'), findsOneWidget);
      expect(find.text('Demo'), findsOneWidget);
    });
  });
}
