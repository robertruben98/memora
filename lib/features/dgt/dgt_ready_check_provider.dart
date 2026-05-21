import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dgt_preparation_provider.dart';
import 'dgt_prediction.dart';
import 'dgt_streak_provider.dart';

/// Issue #136 (dgt-ux): checklist "Listo para examen?".
///
/// Evalua 5 criterios independientes y produce un veredicto agregado.
/// Toda la logica es PURA: el provider solo lee otros providers existentes
/// (preparation, prediction, topics, streak) y delega en `computeReadyCheck`.
///
/// Criterios:
/// 1. Simulacros recientes: estimado via `expectedScore >= kDgtThresholdReady`
///    (no tenemos endpoint "ultimos 7 dias de simulacros", asi que usamos
///    la prediction como proxy del nivel general).
/// 2. Acierto global: `expectedScore * 100 >= 85`.
/// 3. Cobertura temario: todos los topics conocidos con >=10 preguntas vistas.
/// 4. Sin temas debiles: ningun topic con accuracyPct < 75.
/// 5. Racha activa: streak >= 5 dias.

const int kDgtReadyMinCoveragePerTopic = 10;
const double kDgtReadyMinAccuracyPct = 85.0;
const double kDgtReadyWeakTopicPct = 75.0;
const int kDgtReadyMinStreakDays = 5;

/// Identificador estable de cada criterio.
enum DgtReadyCriterion {
  recentSimulacros,
  globalAccuracy,
  topicCoverage,
  noWeakTopics,
  activeStreak,
}

/// Estado individual de un criterio.
enum DgtReadyStatus {
  /// Criterio cumplido (icono check).
  pass,

  /// Criterio cercano a cumplirse (icono warn).
  warn,

  /// Criterio incumplido (icono cross).
  fail,
}

class DgtReadyItem {
  final DgtReadyCriterion criterion;
  final DgtReadyStatus status;
  final String label;
  final String detail;

  const DgtReadyItem({
    required this.criterion,
    required this.status,
    required this.label,
    required this.detail,
  });

  bool get isPass => status == DgtReadyStatus.pass;
}

/// Veredicto global.
enum DgtReadyVerdict {
  /// 5/5 -> listo.
  ready,

  /// 3 o 4 de 5 -> casi listo.
  almost,

  /// <3 -> no listo.
  notReady,
}

class DgtReadyCheck {
  final List<DgtReadyItem> items;

  const DgtReadyCheck({required this.items});

  static const empty = DgtReadyCheck(items: <DgtReadyItem>[]);

  int get passedCount => items.where((i) => i.isPass).length;
  int get totalCount => items.length;

  DgtReadyVerdict get verdict {
    final p = passedCount;
    if (totalCount == 0) return DgtReadyVerdict.notReady;
    if (p >= 5) return DgtReadyVerdict.ready;
    if (p >= 3) return DgtReadyVerdict.almost;
    return DgtReadyVerdict.notReady;
  }

  String get verdictLabel {
    switch (verdict) {
      case DgtReadyVerdict.ready:
        return 'Listo ($passedCount/$totalCount)';
      case DgtReadyVerdict.almost:
        return 'Casi listo ($passedCount/$totalCount)';
      case DgtReadyVerdict.notReady:
        return 'Necesitas mas practica ($passedCount/$totalCount)';
    }
  }
}

/// Calculo PURO: dada la informacion agregada, devuelve la checklist.
DgtReadyCheck computeReadyCheck({
  required DgtPrediction prediction,
  required List<DgtTopicStat> topics,
  required int streakDays,
}) {
  final items = <DgtReadyItem>[];

  // 1. Simulacros recientes -> proxy: expectedScore >= 0.90 con datos suficientes.
  final score = prediction.expectedScore ?? 0.0;
  final pct = score * 100.0;
  if (prediction.hasEnoughData && score >= kDgtThresholdReady) {
    items.add(const DgtReadyItem(
      criterion: DgtReadyCriterion.recentSimulacros,
      status: DgtReadyStatus.pass,
      label: 'Simulacros recientes solidos',
      detail: 'Tu nivel estimado supera el umbral de aprobado.',
    ));
  } else if (prediction.hasEnoughData && score >= kDgtThresholdAlmost) {
    items.add(const DgtReadyItem(
      criterion: DgtReadyCriterion.recentSimulacros,
      status: DgtReadyStatus.warn,
      label: 'Simulacros recientes mejorables',
      detail: 'Aproxima al umbral pero no lo supera todavia.',
    ));
  } else {
    items.add(const DgtReadyItem(
      criterion: DgtReadyCriterion.recentSimulacros,
      status: DgtReadyStatus.fail,
      label: 'Faltan simulacros recientes solidos',
      detail: 'Haz al menos 3 simulacros completos en los proximos dias.',
    ));
  }

  // 2. Acierto global -> >=85%.
  if (prediction.hasEnoughData && pct >= kDgtReadyMinAccuracyPct) {
    items.add(DgtReadyItem(
      criterion: DgtReadyCriterion.globalAccuracy,
      status: DgtReadyStatus.pass,
      label: 'Acierto global ${pct.toStringAsFixed(0)}%',
      detail: 'Por encima del 85% recomendado.',
    ));
  } else if (prediction.hasEnoughData && pct >= 75) {
    items.add(DgtReadyItem(
      criterion: DgtReadyCriterion.globalAccuracy,
      status: DgtReadyStatus.warn,
      label: 'Acierto global ${pct.toStringAsFixed(0)}%',
      detail: 'Apunta al 85% para presentarte con margen.',
    ));
  } else {
    items.add(DgtReadyItem(
      criterion: DgtReadyCriterion.globalAccuracy,
      status: DgtReadyStatus.fail,
      label: prediction.hasEnoughData
          ? 'Acierto global ${pct.toStringAsFixed(0)}%'
          : 'Acierto global sin datos suficientes',
      detail: 'Necesitas >=85% antes del examen.',
    ));
  }

  // 3. Cobertura temario -> todos los topics conocidos con >=10 vistos.
  final knownTopicIds = kDgtTopicBankSize.keys.toSet();
  final touchedById = <String, int>{};
  for (final t in topics) {
    touchedById[t.topicId] = t.totalAnswered;
  }
  final uncovered = <String>[];
  for (final tid in knownTopicIds) {
    final n = touchedById[tid] ?? 0;
    if (n < kDgtReadyMinCoveragePerTopic) uncovered.add(tid);
  }
  if (uncovered.isEmpty) {
    items.add(const DgtReadyItem(
      criterion: DgtReadyCriterion.topicCoverage,
      status: DgtReadyStatus.pass,
      label: 'Cobertura temario completa',
      detail: 'Has visto >=10 preguntas en cada tema.',
    ));
  } else if (uncovered.length <= 2) {
    items.add(DgtReadyItem(
      criterion: DgtReadyCriterion.topicCoverage,
      status: DgtReadyStatus.warn,
      label: 'Cobertura temario casi completa',
      detail: 'Faltan ${uncovered.length} temas por trabajar.',
    ));
  } else {
    items.add(DgtReadyItem(
      criterion: DgtReadyCriterion.topicCoverage,
      status: DgtReadyStatus.fail,
      label: 'Cobertura temario incompleta',
      detail: '${uncovered.length} temas con menos de '
          '$kDgtReadyMinCoveragePerTopic preguntas.',
    ));
  }

  // 4. Sin temas debiles (<75%).
  final weak = topics
      .where((t) =>
          t.totalAnswered >= kDgtReadyMinCoveragePerTopic &&
          t.accuracyPct < kDgtReadyWeakTopicPct)
      .toList();
  if (weak.isEmpty && topics.isNotEmpty) {
    items.add(const DgtReadyItem(
      criterion: DgtReadyCriterion.noWeakTopics,
      status: DgtReadyStatus.pass,
      label: 'Sin temas debiles',
      detail: 'Todos los temas relevantes >=75%.',
    ));
  } else if (weak.length == 1) {
    items.add(DgtReadyItem(
      criterion: DgtReadyCriterion.noWeakTopics,
      status: DgtReadyStatus.warn,
      label: 'Un tema debil',
      detail:
          'Tema "${weak.first.topicName ?? weak.first.topicId}" '
          'con ${weak.first.accuracyPct.toStringAsFixed(0)}% de acierto.',
    ));
  } else {
    items.add(DgtReadyItem(
      criterion: DgtReadyCriterion.noWeakTopics,
      status: DgtReadyStatus.fail,
      label: '${weak.length} temas debiles',
      detail: 'Repasa los temas con menos de '
          '${kDgtReadyWeakTopicPct.toStringAsFixed(0)}% de acierto.',
    ));
  }

  // 5. Racha activa.
  if (streakDays >= kDgtReadyMinStreakDays) {
    items.add(DgtReadyItem(
      criterion: DgtReadyCriterion.activeStreak,
      status: DgtReadyStatus.pass,
      label: 'Racha activa ($streakDays dias)',
      detail: 'Vas cumpliendo la meta diaria.',
    ));
  } else if (streakDays > 0) {
    items.add(DgtReadyItem(
      criterion: DgtReadyCriterion.activeStreak,
      status: DgtReadyStatus.warn,
      label: 'Racha corta ($streakDays dias)',
      detail: 'Mantenla al menos $kDgtReadyMinStreakDays dias seguidos.',
    ));
  } else {
    items.add(const DgtReadyItem(
      criterion: DgtReadyCriterion.activeStreak,
      status: DgtReadyStatus.fail,
      label: 'Sin racha activa',
      detail: 'Empieza una racha cumpliendo la meta diaria hoy.',
    ));
  }

  return DgtReadyCheck(items: items);
}

/// Provider principal. Combina preparation + topics + streak.
final dgtReadyCheckProvider = FutureProvider<DgtReadyCheck>((ref) async {
  try {
    DgtPrediction prediction = DgtPrediction.empty;
    List<DgtTopicStat> topics = const <DgtTopicStat>[];
    int streak = 0;
    try {
      final prep = await ref.watch(dgtPreparationProvider.future);
      prediction = prep.prediction;
    } catch (_) {/* default */}
    try {
      topics = await ref.watch(dgtTopicStatsProvider.future);
    } catch (_) {/* default */}
    try {
      final month = await ref.watch(dgtStreakMonthProvider.future);
      streak = month.currentStreak;
    } catch (_) {/* default */}
    return computeReadyCheck(
      prediction: prediction,
      topics: topics,
      streakDays: streak,
    );
  } catch (_) {
    return DgtReadyCheck.empty;
  }
});
