import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_streak_provider.dart';

/// Issue #147: tests del calculo PURO `computeStreakMonth`.
/// Aislado de Flutter / Riverpod / SharedPreferences.
void main() {
  group('computeStreakMonth', () {
    test('sin actividad -> empty activity, streak 0', () {
      final now = DateTime(2026, 5, 21);
      final r = computeStreakMonth(
        failuresByDay: const <DateTime, int>{},
        completedToday: 0,
        dailyGoal: 20,
        now: now,
      );
      expect(r.year, 2026);
      expect(r.month, 5);
      expect(r.activityByDay, isEmpty);
      expect(r.currentStreak, 0);
      expect(r.totalAnsweredMonth, 0);
    });

    test('completedToday se acumula en el dia actual', () {
      final now = DateTime(2026, 5, 21, 14, 30);
      final r = computeStreakMonth(
        failuresByDay: const <DateTime, int>{},
        completedToday: 15,
        dailyGoal: 20,
        now: now,
      );
      expect(r.activityByDay[21], 15);
      expect(r.statusForDay(21), DgtDayStatus.partial);
      expect(r.statusForDay(20), DgtDayStatus.none);
    });

    test('failures se filtran por mes actual', () {
      final now = DateTime(2026, 5, 21);
      final r = computeStreakMonth(
        failuresByDay: {
          DateTime(2026, 5, 18): 5,
          DateTime(2026, 5, 19): 25,
          DateTime(2026, 4, 30): 99, // fuera de mes, debe ignorarse
        },
        completedToday: 0,
        dailyGoal: 20,
        now: now,
      );
      expect(r.activityByDay[18], 5);
      expect(r.activityByDay[19], 25);
      expect(r.activityByDay.containsKey(30), isFalse);
      expect(r.statusForDay(18), DgtDayStatus.partial);
      expect(r.statusForDay(19), DgtDayStatus.full);
    });

    test('racha cuenta dias consecutivos cumpliendo meta hasta hoy', () {
      final now = DateTime(2026, 5, 21);
      final r = computeStreakMonth(
        failuresByDay: {
          DateTime(2026, 5, 19): 20,
          DateTime(2026, 5, 20): 30,
          DateTime(2026, 5, 18): 5, // rompe la racha hacia atras
        },
        completedToday: 22,
        dailyGoal: 20,
        now: now,
      );
      // hoy (21) ok, 20 ok, 19 ok, 18 no -> racha = 3
      expect(r.currentStreak, 3);
    });

    test('racha 0 si hoy no cumple meta', () {
      final now = DateTime(2026, 5, 21);
      final r = computeStreakMonth(
        failuresByDay: {
          DateTime(2026, 5, 20): 25,
        },
        completedToday: 5,
        dailyGoal: 20,
        now: now,
      );
      expect(r.currentStreak, 0);
    });

    test('dailyGoal 0 trata cualquier actividad como partial y racha 0', () {
      final now = DateTime(2026, 5, 21);
      final r = computeStreakMonth(
        failuresByDay: {DateTime(2026, 5, 20): 5},
        completedToday: 5,
        dailyGoal: 0,
        now: now,
      );
      expect(r.statusForDay(20), DgtDayStatus.partial);
      expect(r.statusForDay(21), DgtDayStatus.partial);
      expect(r.currentStreak, 0);
    });

    test('statusForDay full cuando count >= meta', () {
      final now = DateTime(2026, 5, 21);
      final r = computeStreakMonth(
        failuresByDay: {DateTime(2026, 5, 10): 20},
        completedToday: 0,
        dailyGoal: 20,
        now: now,
      );
      expect(r.statusForDay(10), DgtDayStatus.full);
    });

    test('totalAnsweredMonth suma activity', () {
      final now = DateTime(2026, 5, 21);
      final r = computeStreakMonth(
        failuresByDay: {
          DateTime(2026, 5, 1): 10,
          DateTime(2026, 5, 2): 5,
        },
        completedToday: 7,
        dailyGoal: 20,
        now: now,
      );
      expect(r.totalAnsweredMonth, 22);
    });
  });
}
