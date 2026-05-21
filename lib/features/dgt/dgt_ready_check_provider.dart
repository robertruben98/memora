import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../quest/quest_provider.dart';
import '../study/dgt_exam_history.dart';
import 'dgt_prediction.dart';
import 'dgt_settings.dart';

/// Issue #136 (dgt-ux): "Listo para examen?" checklist.
///
/// Modelo + provider que evaluan 5 criterios objetivos para que el estudiante
/// sepa de un vistazo si esta preparado para presentarse al DGT real. Aditivo:
/// reutiliza providers existentes (historial de simulacros, daily quest para
/// streak, stats por tema para cobertura y temas debiles). NO toca la BBDD ni
/// el SRS.

/// Estado individual de cada criterio.
enum DgtReadyCriterionStatus {
  /// Criterio cumplido.
  pass,

  /// Criterio en zona dudosa (cerca del umbral pero sin cumplir del todo).
  warn,

  /// Criterio claramente NO cumplido.
  fail,
}

/// Identificador estable de cada criterio para destino de navegacion.
enum DgtReadyCriterionId {
  recentMocks,
  globalAccuracy,
  topicCoverage,
  weakTopics,
  activeStreak,
}

/// Un criterio individual evaluado.
class DgtReadyCriterion {
  final DgtReadyCriterionId id;
  final String label;

  /// Descripcion breve del estado actual ("3 simulacros aprobados / 0").
  final String detail;
  final DgtReadyCriterionStatus status;

  const DgtReadyCriterion({
    required this.id,
    required this.label,
    required this.detail,
    required this.status,
  });

  bool get isPass => status == DgtReadyCriterionStatus.pass;
}

/// Veredicto agregado.
enum DgtReadyVerdict {
  ready,
  almost,
  notReady,
}

extension DgtReadyVerdictX on DgtReadyVerdict {
  String label(int passCount, int total) {
    switch (this) {
      case DgtReadyVerdict.ready:
        return 'Listo ($passCount/$total)';
      case DgtReadyVerdict.almost:
        return 'Casi listo ($passCount/$total)';
      case DgtReadyVerdict.notReady:
        return 'Necesitas mas practica ($passCount/$total)';
    }
  }
}

/// Resultado de la evaluacion completa.
class DgtReadyCheckResult {
  final List<DgtReadyCriterion> criteria;

  /// Dias hasta el examen (puede ser null si no hay fecha fijada).
  final int? daysUntilExam;

  const DgtReadyCheckResult({
    required this.criteria,
    required this.daysUntilExam,
  });

  int get passCount =>
      criteria.where((c) => c.status == DgtReadyCriterionStatus.pass).length;

  int get total => criteria.length;

  DgtReadyVerdict get verdict {
    if (passCount >= total) return DgtReadyVerdict.ready;
    if (passCount >= 3) return DgtReadyVerdict.almost;
    return DgtReadyVerdict.notReady;
  }

  /// Helper para pasar a una vista compacta (banner Home).
  String get shortLabel => verdict.label(passCount, total);
}

/// Umbrales aceptacion (issue #136).
const int kDgtReadyRecentMocksRequired = 3;
const int kDgtReadyRecentMocksWindowDays = 7;
const double kDgtReadyAccuracyThreshold = 0.85;
const int kDgtReadyAccuracyMinReviews = 30;
const int kDgtReadyCoveragePerTopic = 10;
const double kDgtReadyWeakTopicThreshold = 75.0;
const int kDgtReadyStreakRequired = 5;

/// Helper puro: evalua simulacros recientes aprobados.
DgtReadyCriterion evalRecentMocks(
  List<DgtExamHistoryEntry> history, {
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final cutoff = ref.subtract(
    const Duration(days: kDgtReadyRecentMocksWindowDays),
  );
  final recentPassed =
      history.where((e) => e.date.isAfter(cutoff) && e.passed).length;
  final DgtReadyCriterionStatus status;
  if (recentPassed >= kDgtReadyRecentMocksRequired) {
    status = DgtReadyCriterionStatus.pass;
  } else if (recentPassed >= 1) {
    status = DgtReadyCriterionStatus.warn;
  } else {
    status = DgtReadyCriterionStatus.fail;
  }
  return DgtReadyCriterion(
    id: DgtReadyCriterionId.recentMocks,
    label: 'Simulacros aprobados (>=$kDgtReadyRecentMocksRequired '
        'en ${kDgtReadyRecentMocksWindowDays}d)',
    detail: '$recentPassed aprobados en los ultimos '
        '$kDgtReadyRecentMocksWindowDays dias',
    status: status,
  );
}

/// Helper puro: evalua acierto global agregado desde stats por tema.
/// Usa accuracy ponderada por totalAnswered. Si totalAnswered acumulado
/// < kDgtReadyAccuracyMinReviews, devuelve `fail` (todavia no hay base).
DgtReadyCriterion evalGlobalAccuracy(List<DgtTopicStat> stats) {
  final total =
      stats.fold<int>(0, (acc, s) => acc + s.totalAnswered);
  if (total < kDgtReadyAccuracyMinReviews) {
    return DgtReadyCriterion(
      id: DgtReadyCriterionId.globalAccuracy,
      label: 'Acierto global >=${(kDgtReadyAccuracyThreshold * 100).toInt()}%',
      detail: 'Aun no hay reviews suficientes ($total/$kDgtReadyAccuracyMinReviews)',
      status: DgtReadyCriterionStatus.fail,
    );
  }
  final correct = stats.fold<int>(0, (acc, s) => acc + s.correct);
  final pct = correct / total;
  final DgtReadyCriterionStatus status;
  if (pct >= kDgtReadyAccuracyThreshold) {
    status = DgtReadyCriterionStatus.pass;
  } else if (pct >= kDgtReadyAccuracyThreshold - 0.05) {
    status = DgtReadyCriterionStatus.warn;
  } else {
    status = DgtReadyCriterionStatus.fail;
  }
  return DgtReadyCriterion(
    id: DgtReadyCriterionId.globalAccuracy,
    label: 'Acierto global >=${(kDgtReadyAccuracyThreshold * 100).toInt()}%',
    detail: '${(pct * 100).toStringAsFixed(1)}% sobre $total respuestas',
    status: status,
  );
}

/// Helper puro: evalua cobertura del temario (todos los temas oficiales con
/// al menos [kDgtReadyCoveragePerTopic] preguntas respondidas).
/// Usa [kDgtTopicBankSize] como conjunto de temas oficiales.
DgtReadyCriterion evalTopicCoverage(List<DgtTopicStat> stats) {
  final officialTopics = kDgtTopicBankSize.keys.toSet();
  final byId = {for (final s in stats) s.topicId: s};
  var covered = 0;
  for (final tid in officialTopics) {
    final s = byId[tid];
    if (s != null && s.totalAnswered >= kDgtReadyCoveragePerTopic) {
      covered++;
    }
  }
  final totalTopics = officialTopics.length;
  final missing = totalTopics - covered;
  final DgtReadyCriterionStatus status;
  if (covered >= totalTopics) {
    status = DgtReadyCriterionStatus.pass;
  } else if (covered >= totalTopics - 2) {
    status = DgtReadyCriterionStatus.warn;
  } else {
    status = DgtReadyCriterionStatus.fail;
  }
  return DgtReadyCriterion(
    id: DgtReadyCriterionId.topicCoverage,
    label: 'Cobertura temario (>=$kDgtReadyCoveragePerTopic preguntas/tema)',
    detail: missing == 0
        ? 'Todos los temas cubiertos ($covered/$totalTopics)'
        : '$missing tema(s) sin cubrir ($covered/$totalTopics)',
    status: status,
  );
}

/// Helper puro: evalua que ningun tema tenga accuracy < kDgtReadyWeakTopicThreshold.
/// Solo cuenta temas con datos reales (totalAnswered > 0).
DgtReadyCriterion evalWeakTopics(List<DgtTopicStat> stats) {
  final weak = stats
      .where(
        (s) =>
            s.totalAnswered > 0 &&
            s.accuracyPct < kDgtReadyWeakTopicThreshold,
      )
      .toList();
  final DgtReadyCriterionStatus status;
  if (weak.isEmpty) {
    // Si no hay datos en absoluto, no se puede decir que no haya temas
    // debiles - lo dejamos como fail para empujar a practicar.
    final hasAnyData = stats.any((s) => s.totalAnswered > 0);
    status = hasAnyData
        ? DgtReadyCriterionStatus.pass
        : DgtReadyCriterionStatus.fail;
  } else if (weak.length == 1) {
    status = DgtReadyCriterionStatus.warn;
  } else {
    status = DgtReadyCriterionStatus.fail;
  }
  final detail = weak.isEmpty
      ? (stats.any((s) => s.totalAnswered > 0)
          ? 'Sin temas por debajo del ${kDgtReadyWeakTopicThreshold.toInt()}%'
          : 'Aun no hay datos para evaluar temas debiles')
      : '${weak.length} tema(s) bajo ${kDgtReadyWeakTopicThreshold.toInt()}%';
  return DgtReadyCriterion(
    id: DgtReadyCriterionId.weakTopics,
    label: 'Sin temas debiles (<${kDgtReadyWeakTopicThreshold.toInt()}%)',
    detail: detail,
    status: status,
  );
}

/// Helper puro: evalua streak activa.
DgtReadyCriterion evalActiveStreak(int streakDays) {
  final DgtReadyCriterionStatus status;
  if (streakDays >= kDgtReadyStreakRequired) {
    status = DgtReadyCriterionStatus.pass;
  } else if (streakDays >= kDgtReadyStreakRequired - 2) {
    status = DgtReadyCriterionStatus.warn;
  } else {
    status = DgtReadyCriterionStatus.fail;
  }
  return DgtReadyCriterion(
    id: DgtReadyCriterionId.activeStreak,
    label: 'Racha activa (>=$kDgtReadyStreakRequired dias)',
    detail: streakDays == 0
        ? 'Sin racha activa'
        : '$streakDays dias consecutivos',
    status: status,
  );
}

/// Compone el resultado completo a partir de los datos crudos. Helper puro
/// para que el test no dependa de Riverpod / SharedPreferences.
DgtReadyCheckResult buildReadyCheck({
  required List<DgtExamHistoryEntry> history,
  required List<DgtTopicStat> stats,
  required int streakDays,
  required int? daysUntilExam,
  DateTime? now,
}) {
  return DgtReadyCheckResult(
    daysUntilExam: daysUntilExam,
    criteria: [
      evalRecentMocks(history, now: now),
      evalGlobalAccuracy(stats),
      evalTopicCoverage(stats),
      evalWeakTopics(stats),
      evalActiveStreak(streakDays),
    ],
  );
}

/// Provider asincrono que combina las fuentes existentes. Sin estado propio.
final dgtReadyCheckProvider =
    FutureProvider<DgtReadyCheckResult>((ref) async {
  final history = await ref.watch(dgtExamHistoryProvider.future);
  final stats = await ref.watch(dgtTopicStatsProvider.future);
  final quest = await ref.watch(dailyQuestProvider.future);
  final settings = await ref.watch(dgtSettingsProvider.future);
  return buildReadyCheck(
    history: history,
    stats: stats,
    streakDays: quest.streakDays,
    daysUntilExam: settings.daysUntilExam,
  );
});
