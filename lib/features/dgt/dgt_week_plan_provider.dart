import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dgt_adaptive_goal_provider.dart';
import 'dgt_preparation_provider.dart';
import 'dgt_settings.dart';

/// Issue #149 (dgt-ux): plan semanal con meta diaria y refuerzo findesemana.
///
/// Distribuye la meta adaptativa diaria entre los 7 dias de la semana actual
/// (Lunes a Domingo). Sabado y Domingo se marcan como "SIMULACRO" (30 preg).
///
/// Fuentes:
/// - `dgtAdaptiveGoalProvider` -> meta sugerida o actual.
/// - `dgtPreparationProvider`  -> answeredToday (progreso del dia actual).
/// - `DgtSettings.examDate`    -> si no hay fecha examen, devuelve unconfigured.
///
/// Para dias historicos NO tenemos un endpoint que devuelva el conteo por dia,
/// asi que solo se conoce con certeza el dia actual. Los dias pasados/futuros
/// muestran objetivo sin progreso (target/0). El widget puede deshabilitar tap
/// en dias pasados sin perder utilidad de planificacion.

/// Cuantas preguntas son un "simulacro" findesemana.
const int kDgtWeekPlanSimulacroSize = 30;

/// Plan de un dia de la semana.
class DgtDayPlan {
  /// 1=L, 2=M, ..., 7=D (segun DateTime.weekday).
  final int weekday;

  /// Meta objetivo de ese dia.
  final int target;

  /// Si el dia es simulacro completo (S/D).
  final bool isSimulacro;

  /// Si es el dia de HOY.
  final bool isToday;

  /// Si es un dia futuro.
  final bool isFuture;

  /// Si es un dia pasado.
  final bool isPast;

  /// Preguntas hechas hoy (solo para isToday; resto 0).
  final int answered;

  const DgtDayPlan({
    required this.weekday,
    required this.target,
    required this.isSimulacro,
    required this.isToday,
    required this.isFuture,
    required this.isPast,
    required this.answered,
  });

  /// Texto corto del dia (L M X J V S D). Locale-agnostic.
  String get shortLabel => switch (weekday) {
        1 => 'L',
        2 => 'M',
        3 => 'X',
        4 => 'J',
        5 => 'V',
        6 => 'S',
        7 => 'D',
        _ => '?',
      };

  /// Progreso 0..1 (solo significativo para isToday).
  double get progress {
    if (target <= 0) return 0;
    return (answered / target).clamp(0.0, 1.0);
  }
}

/// Plan semanal completo.
class DgtWeekPlan {
  /// `true` si el usuario NO ha configurado fecha de examen y por tanto el
  /// plan semanal pierde sentido (no hay meta adaptativa hacia el examen).
  final bool unconfigured;

  /// Dias de L a D (longitud 7) cuando no unconfigured.
  final List<DgtDayPlan> days;

  /// Total objetivo semana.
  final int weeklyTarget;

  /// Total respondidas hasta ahora en la semana (solo cuenta hoy fielmente).
  final int weeklyAnswered;

  const DgtWeekPlan({
    required this.unconfigured,
    required this.days,
    required this.weeklyTarget,
    required this.weeklyAnswered,
  });

  static const unconfiguredEmpty = DgtWeekPlan(
    unconfigured: true,
    days: <DgtDayPlan>[],
    weeklyTarget: 0,
    weeklyAnswered: 0,
  );

  double get weeklyProgress {
    if (weeklyTarget <= 0) return 0;
    return (weeklyAnswered / weeklyTarget).clamp(0.0, 1.0);
  }

  int get weeklyProgressPercent => (weeklyProgress * 100).round();
}

/// Calculo PURO del plan semanal.
DgtWeekPlan computeWeekPlan({
  required DgtSettings settings,
  required DgtAdaptiveGoal adaptiveGoal,
  required int answeredToday,
  required DateTime now,
  int simulacroSize = kDgtWeekPlanSimulacroSize,
}) {
  if (settings.examDate == null) {
    return DgtWeekPlan.unconfiguredEmpty;
  }
  // Meta diaria efectiva: sugerida si banner activo, sino la actual.
  final dailyGoal =
      adaptiveGoal.suggested ?? adaptiveGoal.currentGoal;
  final today = DateTime(now.year, now.month, now.day);
  // weekday: 1=L .. 7=D. Lunes de esta semana = today - (weekday-1) dias.
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final days = <DgtDayPlan>[];
  var weeklyTarget = 0;
  var weeklyAnswered = 0;
  for (var i = 0; i < 7; i++) {
    final d = monday.add(Duration(days: i));
    final weekday = d.weekday;
    final isSimulacro = weekday == DateTime.saturday ||
        weekday == DateTime.sunday;
    final target = isSimulacro ? simulacroSize : dailyGoal;
    final isToday = d == today;
    final isFuture = d.isAfter(today);
    final isPast = d.isBefore(today);
    final answered = isToday ? answeredToday : 0;
    days.add(DgtDayPlan(
      weekday: weekday,
      target: target,
      isSimulacro: isSimulacro,
      isToday: isToday,
      isFuture: isFuture,
      isPast: isPast,
      answered: answered,
    ));
    weeklyTarget += target;
    weeklyAnswered += answered;
  }
  return DgtWeekPlan(
    unconfigured: false,
    days: days,
    weeklyTarget: weeklyTarget,
    weeklyAnswered: weeklyAnswered,
  );
}

/// Provider principal. Combina settings + adaptive goal + preparation.
final dgtWeekPlanProvider = FutureProvider<DgtWeekPlan>((ref) async {
  try {
    final settings = await ref.watch(dgtSettingsProvider.future);
    if (settings.examDate == null) {
      return DgtWeekPlan.unconfiguredEmpty;
    }
    DgtAdaptiveGoal goal;
    try {
      goal = await ref.watch(dgtAdaptiveGoalProvider.future);
    } catch (_) {
      goal = DgtAdaptiveGoal(currentGoal: settings.dailyGoal);
    }
    int answeredToday = 0;
    try {
      final prep = await ref.watch(dgtPreparationProvider.future);
      answeredToday = prep.answeredToday;
    } catch (_) {
      answeredToday = 0;
    }
    return computeWeekPlan(
      settings: settings,
      adaptiveGoal: goal,
      answeredToday: answeredToday,
      now: DateTime.now(),
    );
  } catch (_) {
    return DgtWeekPlan.unconfiguredEmpty;
  }
});
