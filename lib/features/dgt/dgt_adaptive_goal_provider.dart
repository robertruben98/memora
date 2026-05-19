import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dgt_prediction.dart';
import 'dgt_settings.dart';

/// Issue #107 (dgt-ux): meta diaria adaptativa.
///
/// Recalcula la meta diaria sugerida en funcion de la fecha de examen
/// y el progreso real del usuario. Muestra banner cuando el desfase
/// respecto a `DgtSettings.dailyGoal` es significativo (>25% por arriba
/// o >50% por abajo). Aditivo, no sustituye `dgtSettingsProvider`.

/// Cobertura total esperada para llegar listo al examen (preguntas
/// totales practicadas a traves de todo el temario DGT B).
/// Calibrado para que con dailyGoal=20 durante ~30d ronde la meta.
const int kDgtAdaptiveTargetCoverage = 600;

/// Umbrales del banner.
/// - Si la meta sugerida supera la actual en mas de 25% -> banner "acelera".
/// - Si la meta sugerida esta por debajo del 50% de la actual -> banner "vas sobrado".
const double kDgtAdaptiveAheadThreshold = 0.25;
const double kDgtAdaptiveBehindThreshold = 0.5;

/// Limites duros para la meta sugerida (anti-burnout y anti-pereza).
const int kDgtAdaptiveMinSuggested = 5;
const int kDgtAdaptiveMaxSuggested = 100;

/// Key SharedPreferences para guardar timestamp de dismiss del banner.
const String kDgtAdaptiveBannerDismissedAtKey =
    'dgt_adaptive_banner_dismissed_at';

/// Horas de cooldown tras dismiss antes de volver a mostrar el banner.
const int kDgtAdaptiveDismissCooldownHours = 24;

/// Estado del provider de meta adaptativa.
///
/// `suggested == null` cuando NO debe mostrarse banner (sin examDate,
/// examen pasado, sin desfase relevante, sin datos suficientes).
class DgtAdaptiveGoal {
  /// Meta diaria sugerida tras recalculo. Solo presente si el banner debe
  /// mostrarse. Para el "ratio de cobertura" (info no actionable) ver `coverageRatio`.
  final int? suggested;

  /// Meta actual configurada (info para UI).
  final int currentGoal;

  /// Dias hasta examen (negativo si paso, null si no hay fecha).
  final int? daysToExam;

  /// Cobertura ya cubierta (0..1). null si sin datos.
  final double? coverageRatio;

  /// Direccion del desfase: true=hay que acelerar, false=vas sobrado.
  /// null cuando no hay banner.
  final bool? mustAccelerate;

  const DgtAdaptiveGoal({
    required this.currentGoal,
    this.suggested,
    this.daysToExam,
    this.coverageRatio,
    this.mustAccelerate,
  });

  /// Sin banner por defecto.
  static const empty = DgtAdaptiveGoal(currentGoal: 0);

  bool get shouldShowBanner => suggested != null;
}

/// Calculo PURO: dado el estado actual, devuelve la meta adaptativa.
/// Aislado para test unitario sin Flutter ni IO.
///
/// Reglas:
/// - sin examDate o examen ya pasado -> empty
/// - `daysToExam == 0` (es hoy) -> empty (no tiene sentido recalcular)
/// - meta sugerida = ceil((target - answered) / daysToExam)
/// - clamp a [kDgtAdaptiveMinSuggested..kDgtAdaptiveMaxSuggested]
/// - banner solo si suggested > current*1.25 o suggested < current*0.5
DgtAdaptiveGoal computeAdaptiveGoal({
  required DgtSettings settings,
  required int totalAnswered,
  required DateTime now,
  int targetCoverage = kDgtAdaptiveTargetCoverage,
}) {
  final examDate = settings.examDate;
  if (examDate == null) {
    return DgtAdaptiveGoal(currentGoal: settings.dailyGoal);
  }
  final today = DateTime(now.year, now.month, now.day);
  final exam = DateTime(examDate.year, examDate.month, examDate.day);
  final days = exam.difference(today).inDays;
  if (days <= 0) {
    // Examen hoy o pasado: no recalculamos meta. Banner siempre off.
    return DgtAdaptiveGoal(
      currentGoal: settings.dailyGoal,
      daysToExam: days,
    );
  }
  final coverageRatio = targetCoverage > 0
      ? (totalAnswered / targetCoverage).clamp(0.0, 1.0)
      : null;
  final remaining = targetCoverage - totalAnswered;
  if (remaining <= 0) {
    // Ya cubierto el temario: meta minima recomendada para mantener.
    final suggested = kDgtAdaptiveMinSuggested;
    final showBanner = settings.dailyGoal > suggested * 2;
    return DgtAdaptiveGoal(
      currentGoal: settings.dailyGoal,
      suggested: showBanner ? suggested : null,
      daysToExam: days,
      coverageRatio: coverageRatio,
      mustAccelerate: showBanner ? false : null,
    );
  }
  final raw = (remaining / days).ceil();
  final suggested = raw
      .clamp(kDgtAdaptiveMinSuggested, kDgtAdaptiveMaxSuggested)
      .toInt();
  final current = math.max(1, settings.dailyGoal);
  final ratio = suggested / current;
  bool? mustAccelerate;
  int? suggestedShown;
  if (ratio > 1 + kDgtAdaptiveAheadThreshold) {
    mustAccelerate = true;
    suggestedShown = suggested;
  } else if (ratio < kDgtAdaptiveBehindThreshold) {
    mustAccelerate = false;
    suggestedShown = suggested;
  }
  return DgtAdaptiveGoal(
    currentGoal: settings.dailyGoal,
    suggested: suggestedShown,
    daysToExam: days,
    coverageRatio: coverageRatio,
    mustAccelerate: mustAccelerate,
  );
}

/// Lee timestamp ISO de dismiss desde SharedPreferences.
/// Devuelve null si no existe o el formato es invalido. Best-effort.
Future<DateTime?> readDgtAdaptiveBannerDismissedAt() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kDgtAdaptiveBannerDismissedAtKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  } catch (_) {
    return null;
  }
}

/// Persiste timestamp ISO de dismiss. Best-effort, no propaga errores.
Future<void> writeDgtAdaptiveBannerDismissedAt(DateTime when) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kDgtAdaptiveBannerDismissedAtKey,
      when.toIso8601String(),
    );
  } catch (_) {
    // ignore
  }
}

/// Devuelve true si el banner esta dentro del cooldown de dismiss.
/// PURA: testable sin IO.
bool isDgtAdaptiveBannerDismissed({
  required DateTime? dismissedAt,
  required DateTime now,
  int cooldownHours = kDgtAdaptiveDismissCooldownHours,
}) {
  if (dismissedAt == null) return false;
  final diff = now.difference(dismissedAt);
  return diff.inHours < cooldownHours;
}

/// Provider del timestamp de dismiss. Se invalida tras escribir desde la UI.
final dgtAdaptiveBannerDismissedAtProvider = FutureProvider<DateTime?>((
  ref,
) async {
  return readDgtAdaptiveBannerDismissedAt();
});

/// Provider principal: meta diaria adaptativa.
///
/// Combina:
/// - `dgtSettingsProvider` (examDate + dailyGoal actual)
/// - `dgtPredictionProvider` (totalAnswered como proxy del progreso real)
/// - `dgtAdaptiveBannerDismissedAtProvider` (oculta banner durante 24h)
///
/// Devuelve `DgtAdaptiveGoal` con suggested!=null SOLO cuando el banner
/// debe mostrarse.
final dgtAdaptiveGoalProvider = FutureProvider<DgtAdaptiveGoal>((ref) async {
  final settings = await ref.watch(dgtSettingsProvider.future);
  // Sin examen no hay nada que recalcular: corto temprano para no
  // disparar prediccion innecesaria.
  if (settings.examDate == null) {
    return DgtAdaptiveGoal(currentGoal: settings.dailyGoal);
  }
  // Prediction tiene fallback a empty; capturamos por defensa.
  int totalAnswered = 0;
  try {
    final pred = await ref.watch(dgtPredictionProvider.future);
    totalAnswered = pred.totalReviews;
  } catch (_) {
    totalAnswered = 0;
  }
  final computed = computeAdaptiveGoal(
    settings: settings,
    totalAnswered: totalAnswered,
    now: DateTime.now(),
  );
  if (computed.suggested == null) return computed;
  // Aplicar cooldown de dismiss.
  final dismissedAt = await ref.watch(
    dgtAdaptiveBannerDismissedAtProvider.future,
  );
  if (isDgtAdaptiveBannerDismissed(
    dismissedAt: dismissedAt,
    now: DateTime.now(),
  )) {
    return DgtAdaptiveGoal(
      currentGoal: computed.currentGoal,
      daysToExam: computed.daysToExam,
      coverageRatio: computed.coverageRatio,
    );
  }
  return computed;
});
