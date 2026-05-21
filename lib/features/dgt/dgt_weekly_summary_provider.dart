import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../quest/quest_provider.dart';
import 'dgt_failures_repository.dart';
import 'dgt_prediction.dart';
import 'dgt_settings.dart';

/// Issue #174 (dgt-ux): resumen semanal de progreso DGT.
///
/// Datos consumidos (todo LOCAL, sin endpoints nuevos):
/// - `dgt_failures_repository`: ventana 7 dias de fallos -> dias estudiados
///   + cuenta de preguntas falladas en la semana.
/// - `dailyQuestProvider`: respuestas de HOY (suma al dia actual).
/// - `dgtSettingsProvider`: examDate -> dias restantes.
/// - `dgtPredictionProvider`: weakestTopic (proxy de "tema mas debil").
///
/// Accuracy media de la semana: como no persistimos contadores diarios
/// `answered/correct`, se aproxima desde la prediccion del backend
/// (ya cacheada por `dgtPredictionProvider`). El UI lo etiqueta como
/// "estimada" para evitar ambiguedad.

/// Estado inmutable del resumen semanal.
class DgtWeeklySummary {
  /// Dias (1..7) en los que hubo alguna actividad registrada localmente.
  final int daysStudied;

  /// Total de preguntas resueltas en la semana (proxy local: fallos
  /// recientes + completed del quest de hoy). Suficiente para "te
  /// movieste X veces esta semana".
  final int questionsAnswered;

  /// Accuracy media estimada (0..100). Null si no hay datos suficientes.
  final double? accuracyPct;

  /// Tema mas debil (nombre legible). Null si no hay datos.
  final String? weakestTopicName;

  /// Dias restantes hasta el examen. Null si no hay fecha configurada.
  /// Negativo si el examen ya paso (caso edge: la app sigue siendo util).
  final int? daysToExam;

  /// True si no hubo actividad en la semana (criterio issue: mostrar
  /// copy motivacional especifico).
  bool get isEmpty => daysStudied == 0 && questionsAnswered == 0;

  const DgtWeeklySummary({
    required this.daysStudied,
    required this.questionsAnswered,
    required this.accuracyPct,
    required this.weakestTopicName,
    required this.daysToExam,
  });

  static const empty = DgtWeeklySummary(
    daysStudied: 0,
    questionsAnswered: 0,
    accuracyPct: null,
    weakestTopicName: null,
    daysToExam: null,
  );
}

/// Calculo PURO: dado el conjunto agregado de fallos por dia + completed
/// hoy + prediction + examDate + now, devuelve el resumen. Permite tests
/// sin SharedPreferences/Riverpod.
///
/// `failuresByDay` debe estar pre-filtrado a la ventana 7d por el caller
/// (asi se mantiene esta funcion totalmente determinista).
DgtWeeklySummary computeWeeklySummary({
  required Map<DateTime, int> failuresByDay,
  required int completedToday,
  required DgtPrediction prediction,
  required DateTime? examDate,
  required DateTime now,
}) {
  final today = DateTime(now.year, now.month, now.day);
  // Set de dias unicos con actividad (incluido HOY si completedToday > 0).
  final activeDays = <DateTime>{};
  var totalQuestions = 0;
  failuresByDay.forEach((d, count) {
    if (count <= 0) return;
    activeDays.add(DateTime(d.year, d.month, d.day));
    totalQuestions += count;
  });
  if (completedToday > 0) {
    activeDays.add(today);
    totalQuestions += completedToday;
  }

  double? accuracy;
  if (prediction.hasEnoughData && prediction.expectedScore != null) {
    accuracy = (prediction.expectedScore! * 100.0).clamp(0.0, 100.0);
  }

  final weakestName = prediction.weakestTopic?.topicName ??
      prediction.weakestTopic?.topicId;

  int? daysToExam;
  if (examDate != null) {
    final exam = DateTime(examDate.year, examDate.month, examDate.day);
    daysToExam = exam.difference(today).inDays;
  }

  return DgtWeeklySummary(
    daysStudied: activeDays.length,
    questionsAnswered: totalQuestions,
    accuracyPct: accuracy,
    weakestTopicName: weakestName,
    daysToExam: daysToExam,
  );
}

/// Provider del resumen. Combina fuentes locales con degradacion robusta:
/// si alguna dependencia falla, sigue construyendo un resumen parcial.
final dgtWeeklySummaryProvider = FutureProvider<DgtWeeklySummary>((ref) async {
  // Failures: ya filtrados a windowDays=7 por el repo.
  final failuresRepo = ref.watch(dgtFailuresRepositoryProvider);
  List<DgtFailureEntry> failures;
  try {
    failures = await failuresRepo.recentFailures();
  } catch (_) {
    failures = const <DgtFailureEntry>[];
  }
  final failuresByDay = <DateTime, int>{};
  for (final f in failures) {
    final d = DateTime(f.failedAt.year, f.failedAt.month, f.failedAt.day);
    failuresByDay[d] = (failuresByDay[d] ?? 0) + 1;
  }

  int completedToday = 0;
  try {
    final quest = await ref.watch(dailyQuestProvider.future);
    completedToday = quest.completed;
  } catch (_) {
    completedToday = 0;
  }

  DgtPrediction prediction;
  try {
    prediction = await ref.watch(dgtPredictionProvider.future);
  } catch (_) {
    prediction = DgtPrediction.empty;
  }

  DgtSettings settings;
  try {
    settings = await ref.watch(dgtSettingsProvider.future);
  } catch (_) {
    settings = DgtSettings.defaults;
  }

  return computeWeeklySummary(
    failuresByDay: failuresByDay,
    completedToday: completedToday,
    prediction: prediction,
    examDate: settings.examDate,
    now: DateTime.now(),
  );
});
