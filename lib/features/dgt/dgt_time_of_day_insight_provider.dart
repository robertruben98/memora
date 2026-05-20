import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';

/// Issue #137 (dgt-ux): insight "tu mejor hora para estudiar".
///
/// Agrupa reviews locales por franjas de 3h (00-03, 03-06, ..., 21-24) y
/// calcula accuracy% por franja. Recomienda la franja con mejor rendimiento
/// para que el estudiante reserve ese hueco. Si no hay datos suficientes
/// (<kDgtTimeOfDayMinReviews), no muestra insight.
///
/// Funcion pura `computeTimeOfDayInsight` aislada para test sin Flutter ni
/// IO. El provider Riverpod reusa [ReviewRepository.getRecentLogs] (no toca
/// BE ni crea schema nuevo).

/// Numero de franjas: 24h / 3h = 8.
const int kDgtTimeOfDayBuckets = 8;

/// Ancho de cada franja en horas.
const int kDgtTimeOfDayBucketHours = 3;

/// Minimo de reviews totales para mostrar el insight. Por debajo, mostramos
/// el placeholder "necesitamos mas datos".
const int kDgtTimeOfDayMinReviews = 30;

/// Limite de reviews a leer para evitar quemar memoria si el usuario tiene
/// historial muy largo (suficiente para una recomendacion estable).
const int kDgtTimeOfDayMaxReviews = 2000;

/// Diferencia minima entre mejor franja y mediana de las demas para
/// considerar que hay una franja "ganadora" clara. Si la distribucion es
/// plana, mostramos copy mas neutro.
const double kDgtTimeOfDayMinEdgePct = 5.0;

/// Stats por franja.
class DgtTimeOfDayBucket {
  /// Indice 0..7. Hora inicial = `index * 3`.
  final int index;

  /// Total de reviews en la franja.
  final int total;

  /// Aciertos en la franja.
  final int correct;

  const DgtTimeOfDayBucket({
    required this.index,
    required this.total,
    required this.correct,
  });

  /// Accuracy 0..100. 0 si total==0 (sin division por cero).
  double get accuracyPct {
    if (total <= 0) return 0.0;
    return (correct / total) * 100.0;
  }

  /// Hora inicial de la franja (00, 03, 06, ...).
  int get startHour => index * kDgtTimeOfDayBucketHours;

  /// Hora final exclusiva (03, 06, ..., 24).
  int get endHour => startHour + kDgtTimeOfDayBucketHours;

  /// Etiqueta corta "00-03".
  String get label {
    final s = startHour.toString().padLeft(2, '0');
    final e = endHour.toString().padLeft(2, '0');
    return '$s-$e';
  }
}

/// Estado completo del insight.
class DgtTimeOfDayInsight {
  /// Reviews totales considerados.
  final int totalReviews;

  /// Stats por franja (siempre [kDgtTimeOfDayBuckets] elementos).
  final List<DgtTimeOfDayBucket> buckets;

  /// Indice de la franja ganadora (mayor accuracy con datos suficientes).
  /// `null` si no hay una franja claramente mejor.
  final int? bestBucketIndex;

  /// Cuanto mejora la franja ganadora respecto a la mediana del resto.
  /// Diferencia absoluta en puntos porcentuales. `null` si no hay best.
  final double? edgePct;

  const DgtTimeOfDayInsight({
    required this.totalReviews,
    required this.buckets,
    this.bestBucketIndex,
    this.edgePct,
  });

  /// Empty state: sin datos.
  static DgtTimeOfDayInsight empty() {
    return DgtTimeOfDayInsight(
      totalReviews: 0,
      buckets: List.generate(
        kDgtTimeOfDayBuckets,
        (i) => DgtTimeOfDayBucket(index: i, total: 0, correct: 0),
      ),
    );
  }

  /// `true` si tenemos suficientes reviews para mostrar el insight.
  bool get hasEnoughData => totalReviews >= kDgtTimeOfDayMinReviews;

  /// Devuelve el bucket ganador si existe.
  DgtTimeOfDayBucket? get bestBucket {
    final i = bestBucketIndex;
    if (i == null) return null;
    return buckets[i];
  }
}

/// Logs de review minimos para alimentar el calculo. Aislado de la tabla
/// Drift para que el test no necesite la DB; solo precisa (timestampMs,
/// correct).
class DgtReviewSample {
  final int reviewedAtMs;
  final bool correct;

  const DgtReviewSample({
    required this.reviewedAtMs,
    required this.correct,
  });
}

/// Calculo PURO: dado una lista de samples, devuelve el insight.
/// Aislado para test sin Flutter, sin DB, sin timezone surprises (usa
/// `DateTime.fromMillisecondsSinceEpoch` con flag `isUtc=false`: hora local
/// del dispositivo, que es la franja perceptual del usuario).
DgtTimeOfDayInsight computeTimeOfDayInsight(
  List<DgtReviewSample> samples, {
  int minReviews = kDgtTimeOfDayMinReviews,
  double minEdgePct = kDgtTimeOfDayMinEdgePct,
}) {
  final totals = List<int>.filled(kDgtTimeOfDayBuckets, 0);
  final corrects = List<int>.filled(kDgtTimeOfDayBuckets, 0);

  for (final s in samples) {
    final dt = DateTime.fromMillisecondsSinceEpoch(s.reviewedAtMs);
    final idx = (dt.hour ~/ kDgtTimeOfDayBucketHours)
        .clamp(0, kDgtTimeOfDayBuckets - 1);
    totals[idx] += 1;
    if (s.correct) corrects[idx] += 1;
  }

  final buckets = <DgtTimeOfDayBucket>[];
  for (var i = 0; i < kDgtTimeOfDayBuckets; i++) {
    buckets.add(
      DgtTimeOfDayBucket(
        index: i,
        total: totals[i],
        correct: corrects[i],
      ),
    );
  }

  final total = samples.length;
  if (total < minReviews) {
    return DgtTimeOfDayInsight(totalReviews: total, buckets: buckets);
  }

  // Solo consideramos franjas con al menos 1 review para el ranking; las
  // vacias no aportan info y arrastran la mediana hacia 0.
  final candidates = buckets.where((b) => b.total > 0).toList();
  if (candidates.isEmpty) {
    return DgtTimeOfDayInsight(totalReviews: total, buckets: buckets);
  }

  // Mejor accuracy. En empate, gana mas total (mas evidencia); en empate
  // de total, gana indice menor (orden estable).
  candidates.sort((a, b) {
    final byAcc = b.accuracyPct.compareTo(a.accuracyPct);
    if (byAcc != 0) return byAcc;
    final byTotal = b.total.compareTo(a.total);
    if (byTotal != 0) return byTotal;
    return a.index.compareTo(b.index);
  });
  final best = candidates.first;

  // Mediana del resto. Si solo hay un candidato, no hay edge significativo.
  if (candidates.length < 2) {
    return DgtTimeOfDayInsight(totalReviews: total, buckets: buckets);
  }
  final others = candidates.sublist(1).map((b) => b.accuracyPct).toList()
    ..sort();
  final mid = others.length ~/ 2;
  final median = others.length.isOdd
      ? others[mid]
      : (others[mid - 1] + others[mid]) / 2.0;
  final edge = best.accuracyPct - median;

  if (edge < minEdgePct) {
    return DgtTimeOfDayInsight(totalReviews: total, buckets: buckets);
  }

  return DgtTimeOfDayInsight(
    totalReviews: total,
    buckets: buckets,
    bestBucketIndex: best.index,
    edgePct: edge,
  );
}

/// Provider del insight. Lee logs locales (best-effort: si DB falla,
/// degrada a empty para no romper la pantalla de stats).
final dgtTimeOfDayInsightProvider = FutureProvider<DgtTimeOfDayInsight>(
  (ref) async {
    try {
      final db = ref.watch(databaseProvider);
      final logs = await db.reviewLogDao
          .getRecentLogs(limit: kDgtTimeOfDayMaxReviews);
      final samples = logs
          .map(
            (l) => DgtReviewSample(
              reviewedAtMs: l.reviewedAt,
              correct: l.result == 'correct',
            ),
          )
          .toList();
      return computeTimeOfDayInsight(samples);
    } catch (_) {
      return DgtTimeOfDayInsight.empty();
    }
  },
);
