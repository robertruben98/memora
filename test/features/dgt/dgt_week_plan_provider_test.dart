import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_adaptive_goal_provider.dart';
import 'package:memora/features/dgt/dgt_settings.dart';
import 'package:memora/features/dgt/dgt_week_plan_provider.dart';

/// Issue #149: tests del calculo PURO `computeWeekPlan`.
void main() {
  DgtSettings settingsWithExam(DateTime? exam, {int dailyGoal = 20}) =>
      DgtSettings(
        licenseType: DgtLicenseType.b,
        examDate: exam,
        dailyGoal: dailyGoal,
      );

  group('computeWeekPlan', () {
    test('sin examDate -> unconfigured', () {
      final r = computeWeekPlan(
        settings: settingsWithExam(null),
        adaptiveGoal: const DgtAdaptiveGoal(currentGoal: 20),
        answeredToday: 0,
        now: DateTime(2026, 5, 21),
      );
      expect(r.unconfigured, isTrue);
      expect(r.days, isEmpty);
    });

    test('genera 7 dias L-D con orden correcto', () {
      // 2026-05-21 es jueves.
      final now = DateTime(2026, 5, 21);
      final r = computeWeekPlan(
        settings: settingsWithExam(DateTime(2026, 6, 30)),
        adaptiveGoal: const DgtAdaptiveGoal(currentGoal: 25),
        answeredToday: 10,
        now: now,
      );
      expect(r.days.length, 7);
      expect(r.days.first.weekday, DateTime.monday);
      expect(r.days.last.weekday, DateTime.sunday);
      expect(r.days.map((d) => d.shortLabel).toList(),
          ['L', 'M', 'X', 'J', 'V', 'S', 'D']);
    });

    test('sabado y domingo son simulacro con tamano fijo', () {
      final now = DateTime(2026, 5, 21); // jueves
      final r = computeWeekPlan(
        settings: settingsWithExam(DateTime(2026, 6, 30)),
        adaptiveGoal: const DgtAdaptiveGoal(currentGoal: 25),
        answeredToday: 0,
        now: now,
      );
      final sat = r.days.firstWhere((d) => d.weekday == DateTime.saturday);
      final sun = r.days.firstWhere((d) => d.weekday == DateTime.sunday);
      expect(sat.isSimulacro, isTrue);
      expect(sun.isSimulacro, isTrue);
      expect(sat.target, kDgtWeekPlanSimulacroSize);
      expect(sun.target, kDgtWeekPlanSimulacroSize);
      // Lunes no simulacro
      expect(r.days.first.isSimulacro, isFalse);
      expect(r.days.first.target, 25);
    });

    test('isToday/isPast/isFuture coherentes', () {
      final now = DateTime(2026, 5, 21); // jueves
      final r = computeWeekPlan(
        settings: settingsWithExam(DateTime(2026, 6, 30)),
        adaptiveGoal: const DgtAdaptiveGoal(currentGoal: 20),
        answeredToday: 7,
        now: now,
      );
      final today = r.days.firstWhere((d) => d.isToday);
      expect(today.weekday, DateTime.thursday);
      expect(today.answered, 7);
      expect(r.days.where((d) => d.isPast).length, 3); // L M X
      expect(r.days.where((d) => d.isFuture).length, 3); // V S D
    });

    test('weeklyTarget suma metas (con simulacros)', () {
      final now = DateTime(2026, 5, 21);
      final r = computeWeekPlan(
        settings: settingsWithExam(DateTime(2026, 6, 30)),
        adaptiveGoal: const DgtAdaptiveGoal(currentGoal: 20),
        answeredToday: 0,
        now: now,
      );
      // 5 dias * 20 + 2 simulacros * 30 = 100 + 60 = 160
      expect(r.weeklyTarget, 160);
    });

    test('usa suggested cuando banner adaptativo activo', () {
      final now = DateTime(2026, 5, 21);
      final r = computeWeekPlan(
        settings: settingsWithExam(DateTime(2026, 6, 30), dailyGoal: 20),
        adaptiveGoal: const DgtAdaptiveGoal(
          currentGoal: 20,
          suggested: 50,
          daysToExam: 40,
          mustAccelerate: true,
        ),
        answeredToday: 0,
        now: now,
      );
      final monday = r.days.first;
      expect(monday.target, 50);
    });

    test('weeklyAnswered solo cuenta el dia de hoy', () {
      final now = DateTime(2026, 5, 21);
      final r = computeWeekPlan(
        settings: settingsWithExam(DateTime(2026, 6, 30)),
        adaptiveGoal: const DgtAdaptiveGoal(currentGoal: 20),
        answeredToday: 12,
        now: now,
      );
      expect(r.weeklyAnswered, 12);
      expect(r.weeklyProgressPercent, greaterThan(0));
    });

    test('weeklyProgress 0 si target 0', () {
      const p = DgtWeekPlan(
        unconfigured: false,
        days: <DgtDayPlan>[],
        weeklyTarget: 0,
        weeklyAnswered: 0,
      );
      expect(p.weeklyProgress, 0);
      expect(p.weeklyProgressPercent, 0);
    });
  });
}
