import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dgt_failures_repository.dart';
import 'dgt_preparation_provider.dart';

/// Issue #147 (dgt-ux): calendario mensual de racha.
///
/// Agrega actividad DGT por dia del mes actual a partir de fuentes locales
/// que YA existen (no requiere endpoints nuevos). Devuelve un map
/// `day -> count` que el widget calendario consume para colorear cada celda.
///
/// Notas de scope:
/// - Solo se consideran fuentes locales (offline). El backend NO expone aun
///   un endpoint de "actividad diaria", asi que como proxy usamos:
///     * `dgt_failures` (ventana 7 dias) -> cuenta como actividad ese dia.
///     * `dailyQuest.completed` -> actividad de HOY (refleja sesion en curso).
/// - Para dias mas antiguos de la ventana de fallos, el count es 0 (gris).
///   Esto es coherente con la realidad: la app aun no persiste actividad
///   diaria mas alla de los fallos recientes.
/// - El widget mezcla este map con la meta diaria (DgtSettings.dailyGoal)
///   para decidir el color (gris/amarillo/verde).

/// Estado del calendario mensual.
class DgtStreakMonth {
  /// Anio del mes representado.
  final int year;

  /// Mes representado (1..12).
  final int month;

  /// Map dia (1..31) -> numero de preguntas respondidas ese dia.
  final Map<int, int> activityByDay;

  /// Meta diaria configurada (necesaria para clasificar dia).
  final int dailyGoal;

  /// Racha actual (dias consecutivos cumpliendo meta, incluido hoy si aplica).
  final int currentStreak;

  const DgtStreakMonth({
    required this.year,
    required this.month,
    required this.activityByDay,
    required this.dailyGoal,
    required this.currentStreak,
  });

  static const empty = DgtStreakMonth(
    year: 1970,
    month: 1,
    activityByDay: <int, int>{},
    dailyGoal: 0,
    currentStreak: 0,
  );

  /// Clasificacion visual de un dia. PURA: testable sin Flutter.
  /// - none: sin actividad.
  /// - partial: hay actividad pero menor que meta.
  /// - full: actividad >= meta.
  DgtDayStatus statusForDay(int day) {
    final count = activityByDay[day] ?? 0;
    if (count <= 0) return DgtDayStatus.none;
    if (dailyGoal <= 0) return DgtDayStatus.partial;
    return count >= dailyGoal ? DgtDayStatus.full : DgtDayStatus.partial;
  }

  /// Total respondidas en el mes (suma de activityByDay).
  int get totalAnsweredMonth =>
      activityByDay.values.fold<int>(0, (acc, v) => acc + v);
}

enum DgtDayStatus {
  /// Sin actividad. Color gris.
  none,

  /// Algo de actividad pero por debajo de la meta. Color amarillo.
  partial,

  /// Meta cumplida o superada. Color verde.
  full,
}

/// Calculo PURO: dado conjunto de fallos + completed hoy + settings + now,
/// devuelve la agregacion mensual.
///
/// `failuresByDay` se da pre-agregado para no acoplar al storage.
/// `completedToday` se suma al dia de `now`.
DgtStreakMonth computeStreakMonth({
  required Map<DateTime, int> failuresByDay,
  required int completedToday,
  required int dailyGoal,
  required DateTime now,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final activity = <int, int>{};
  failuresByDay.forEach((d, count) {
    if (d.year == today.year && d.month == today.month) {
      activity[d.day] = (activity[d.day] ?? 0) + count;
    }
  });
  if (completedToday > 0) {
    activity[today.day] = (activity[today.day] ?? 0) + completedToday;
  }
  // Racha: desde hoy hacia atras, dias consecutivos con count >= goal.
  int streak = 0;
  if (dailyGoal > 0) {
    var probe = today;
    while (true) {
      final count = probe.year == today.year && probe.month == today.month
          ? (activity[probe.day] ?? 0)
          : 0;
      if (count >= dailyGoal) {
        streak += 1;
        probe = probe.subtract(const Duration(days: 1));
        // Cortar al cambiar de mes: el provider solo tiene visibilidad
        // del mes actual; no extrapolamos al mes anterior.
        if (probe.month != today.month || probe.year != today.year) break;
      } else {
        break;
      }
    }
  }
  return DgtStreakMonth(
    year: today.year,
    month: today.month,
    activityByDay: activity,
    dailyGoal: dailyGoal,
    currentStreak: streak,
  );
}

/// Provider principal. Combina failures repo + daily quest + settings.
/// Degrada a empty si falla cualquier dependencia (Home nunca rompe).
final dgtStreakMonthProvider = FutureProvider<DgtStreakMonth>((ref) async {
  try {
    final prep = await ref.watch(dgtPreparationProvider.future);
    final failuresRepo = ref.watch(dgtFailuresRepositoryProvider);
    List<DgtFailureEntry> entries;
    try {
      entries = await failuresRepo.recentFailures();
    } catch (_) {
      entries = <DgtFailureEntry>[];
    }
    final failuresByDay = <DateTime, int>{};
    for (final e in entries) {
      final d = DateTime(
        e.failedAt.year,
        e.failedAt.month,
        e.failedAt.day,
      );
      failuresByDay[d] = (failuresByDay[d] ?? 0) + 1;
    }
    return computeStreakMonth(
      failuresByDay: failuresByDay,
      completedToday: prep.answeredToday,
      dailyGoal: prep.settings.dailyGoal,
      now: DateTime.now(),
    );
  } catch (_) {
    return DgtStreakMonth.empty;
  }
});
