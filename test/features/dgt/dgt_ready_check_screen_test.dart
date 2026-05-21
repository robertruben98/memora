import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_prediction.dart';
import 'package:memora/features/dgt/dgt_ready_check_provider.dart';
import 'package:memora/features/dgt/dgt_ready_check_screen.dart';
import 'package:memora/features/study/dgt_exam_history.dart';

/// Issue #136 (dgt-ux): pantalla "Listo para examen?".
/// Cubre los 3 escenarios principales (listo / casi / no listo) sin
/// dependencia de Riverpod ni red, usando los helpers puros del provider y
/// renderizando directamente los widgets de presentacion.

DgtExamHistoryEntry _pass(DateTime when, {int correct = 28, int total = 30}) =>
    DgtExamHistoryEntry(
      date: when,
      correct: correct,
      total: total,
      timeUsed: const Duration(minutes: 20),
      passed: true,
    );

DgtTopicStat _stat(String id, int total, int correct) {
  final pct = total == 0 ? 0.0 : (correct / total) * 100.0;
  return DgtTopicStat(
    topicId: id,
    topicName: id,
    totalAnswered: total,
    correct: correct,
    accuracyPct: pct,
  );
}

/// Construye stats con cobertura total: cada topic oficial con 20 respuestas
/// correctas (100% accuracy, supera el umbral 75%).
List<DgtTopicStat> _fullCoverageStats() {
  return kDgtTopicBankSize.keys.map((id) => _stat(id, 20, 20)).toList();
}

void main() {
  group('buildReadyCheck', () {
    final now = DateTime(2026, 5, 21);

    test('escenario LISTO: 5/5 criterios pass', () {
      final history = [
        _pass(now.subtract(const Duration(days: 1))),
        _pass(now.subtract(const Duration(days: 2))),
        _pass(now.subtract(const Duration(days: 3))),
      ];
      final result = buildReadyCheck(
        history: history,
        stats: _fullCoverageStats(),
        streakDays: 10,
        daysUntilExam: 3,
        now: now,
      );
      expect(result.passCount, 5);
      expect(result.verdict, DgtReadyVerdict.ready);
      expect(result.shortLabel, contains('Listo (5/5)'));
    });

    test('escenario CASI listo: 3-4 pass dispara almost', () {
      // 1 simulacro reciente -> warn en recentMocks.
      // streak 2 -> fail en activeStreak.
      // Cobertura completa, accuracy alta, sin temas debiles.
      final history = [_pass(now.subtract(const Duration(days: 2)))];
      final result = buildReadyCheck(
        history: history,
        stats: _fullCoverageStats(),
        streakDays: 2,
        daysUntilExam: 5,
        now: now,
      );
      expect(result.passCount, inInclusiveRange(3, 4));
      expect(result.verdict, DgtReadyVerdict.almost);
    });

    test('escenario NO LISTO: <3 pass dispara notReady', () {
      // Sin simulacros, sin reviews suficientes -> fail global accuracy
      // y fail topicCoverage. Streak 0.
      final result = buildReadyCheck(
        history: const [],
        stats: const [],
        streakDays: 0,
        daysUntilExam: 10,
        now: now,
      );
      expect(result.passCount, lessThan(3));
      expect(result.verdict, DgtReadyVerdict.notReady);
      expect(result.shortLabel, contains('Necesitas mas practica'));
    });

    test('helper iconFor y colorFor cubren los 3 tiers de verdict', () {
      expect(
        DgtReadyVerdictCard.colorFor(DgtReadyVerdict.ready),
        const Color(0xFF4FFFB0),
      );
      expect(
        DgtReadyVerdictCard.colorFor(DgtReadyVerdict.almost),
        const Color(0xFFFFB74F),
      );
      expect(
        DgtReadyVerdictCard.colorFor(DgtReadyVerdict.notReady),
        const Color(0xFFFF5C5C),
      );
      expect(
        DgtReadyVerdictCard.iconFor(DgtReadyVerdict.ready),
        Icons.check_circle_rounded,
      );
      expect(
        DgtReadyVerdictCard.iconFor(DgtReadyVerdict.almost),
        Icons.timelapse_rounded,
      );
      expect(
        DgtReadyVerdictCard.iconFor(DgtReadyVerdict.notReady),
        Icons.warning_amber_rounded,
      );
    });

    test('criterion tile color/icon cubre pass/warn/fail', () {
      expect(
        DgtReadyCriterionTile.colorFor(DgtReadyCriterionStatus.pass),
        const Color(0xFF4FFFB0),
      );
      expect(
        DgtReadyCriterionTile.colorFor(DgtReadyCriterionStatus.warn),
        const Color(0xFFFFB74F),
      );
      expect(
        DgtReadyCriterionTile.colorFor(DgtReadyCriterionStatus.fail),
        const Color(0xFFFF5C5C),
      );
      expect(
        DgtReadyCriterionTile.iconFor(DgtReadyCriterionStatus.pass),
        Icons.check_circle_rounded,
      );
      expect(
        DgtReadyCriterionTile.iconFor(DgtReadyCriterionStatus.warn),
        Icons.error_outline_rounded,
      );
      expect(
        DgtReadyCriterionTile.iconFor(DgtReadyCriterionStatus.fail),
        Icons.cancel_rounded,
      );
    });

    test('evalRecentMocks: 0 aprobados -> fail, 1-2 -> warn, >=3 -> pass', () {
      final base = DateTime(2026, 5, 21);
      expect(
        evalRecentMocks(const [], now: base).status,
        DgtReadyCriterionStatus.fail,
      );
      expect(
        evalRecentMocks(
          [_pass(base.subtract(const Duration(days: 1)))],
          now: base,
        ).status,
        DgtReadyCriterionStatus.warn,
      );
      // Simulacro fuera de ventana de 7 dias no cuenta.
      expect(
        evalRecentMocks(
          [_pass(base.subtract(const Duration(days: 30)))],
          now: base,
        ).status,
        DgtReadyCriterionStatus.fail,
      );
    });

    test('evalActiveStreak: <3 fail, 3-4 warn, >=5 pass', () {
      expect(evalActiveStreak(0).status, DgtReadyCriterionStatus.fail);
      expect(evalActiveStreak(3).status, DgtReadyCriterionStatus.warn);
      expect(evalActiveStreak(5).status, DgtReadyCriterionStatus.pass);
      expect(evalActiveStreak(20).status, DgtReadyCriterionStatus.pass);
    });

    test('evalWeakTopics: sin datos -> fail; 1 debil -> warn; 0 con datos -> pass',
        () {
      expect(
        evalWeakTopics(const []).status,
        DgtReadyCriterionStatus.fail,
      );
      // 1 tema debil (50%), uno fuerte (95%).
      expect(
        evalWeakTopics([_stat('t1', 20, 10), _stat('t2', 20, 19)]).status,
        DgtReadyCriterionStatus.warn,
      );
      // 2 temas debiles -> fail.
      expect(
        evalWeakTopics([_stat('t1', 20, 10), _stat('t2', 20, 11)]).status,
        DgtReadyCriterionStatus.fail,
      );
      // Todos por encima del umbral -> pass.
      expect(
        evalWeakTopics([_stat('t1', 20, 18), _stat('t2', 20, 19)]).status,
        DgtReadyCriterionStatus.pass,
      );
    });
  });

  group('DgtReadyVerdictCard widget', () {
    testWidgets('renderiza label corto y dias restantes', (tester) async {
      const result = DgtReadyCheckResult(
        criteria: [
          DgtReadyCriterion(
            id: DgtReadyCriterionId.recentMocks,
            label: 'x',
            detail: 'y',
            status: DgtReadyCriterionStatus.pass,
          ),
          DgtReadyCriterion(
            id: DgtReadyCriterionId.globalAccuracy,
            label: 'x',
            detail: 'y',
            status: DgtReadyCriterionStatus.pass,
          ),
          DgtReadyCriterion(
            id: DgtReadyCriterionId.topicCoverage,
            label: 'x',
            detail: 'y',
            status: DgtReadyCriterionStatus.pass,
          ),
          DgtReadyCriterion(
            id: DgtReadyCriterionId.weakTopics,
            label: 'x',
            detail: 'y',
            status: DgtReadyCriterionStatus.pass,
          ),
          DgtReadyCriterion(
            id: DgtReadyCriterionId.activeStreak,
            label: 'x',
            detail: 'y',
            status: DgtReadyCriterionStatus.pass,
          ),
        ],
        daysUntilExam: 4,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DgtReadyVerdictCard(result: result)),
        ),
      );
      expect(find.textContaining('Listo (5/5)'), findsOneWidget);
      expect(find.textContaining('Faltan 4 dias'), findsOneWidget);
    });
  });
}
