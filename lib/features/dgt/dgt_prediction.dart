import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';

/// Issue #52 (dgt-content): prediccion pre-simulacro DGT.
///
/// Calcula una probabilidad estimada de aprobar a partir del % de acierto
/// historico por bloque tematico (`GET /dgt/stats/topics`, issue #47) y un
/// vector de pesos default por tema que aproxima el peso real de cada
/// bloque en el examen DGT permiso B (PracticaTest 2026, DGT.es).
///
/// Aditivo: no toca el banco/cache ni el flujo simulacro. Se renderiza como
/// banner ANTES del boton "Empezar simulacro" en `dgt_exam_screen.dart`.

/// Pesos default por tema (editables sin redeploy si se ajustan aqui).
///
/// Bloques agregados segun el issue:
///   - senales (30%) -> dgt-t-01
///   - normas  (30%) -> dgt-t-02, dgt-t-08
///   - luces   (10%) -> dgt-t-03
///   - mecanica (10%) -> dgt-t-06, dgt-t-12
///   - primeros auxilios (10%) -> dgt-t-13
///   - otros   (10%) -> dgt-t-04, dgt-t-05, dgt-t-07, dgt-t-09, dgt-t-10, dgt-t-11
///
/// Los pesos individuales suman 1.0. Tema no presente en este mapa cae en
/// el bucket "otros" y contribuye con peso 0.0167 (10% / 6 temas).
const Map<String, double> kDgtTopicWeights = <String, double>{
  // senales (30%)
  'dgt-t-01': 0.30,
  // normas (30% repartido)
  'dgt-t-02': 0.15,
  'dgt-t-08': 0.15,
  // luces (10%)
  'dgt-t-03': 0.10,
  // mecanica (10% repartido)
  'dgt-t-06': 0.05,
  'dgt-t-12': 0.05,
  // primeros auxilios (10%)
  'dgt-t-13': 0.10,
  // otros (10% repartido entre 6 temas)
  'dgt-t-04': 0.0167,
  'dgt-t-05': 0.0167,
  'dgt-t-07': 0.0167,
  'dgt-t-09': 0.0167,
  'dgt-t-10': 0.0167,
  'dgt-t-11': 0.0167,
};

/// Minimo de reviews acumuladas para mostrar prediccion numerica.
/// Por debajo de esto, la muestra es demasiado pequena: se muestra texto guia.
const int kDgtMinReviewsForPrediction = 10;

/// Veredicto de prediccion segun threshold sobre score esperado [0..1].
enum DgtPredictionVerdict {
  /// >= 0.90 -> verde
  ready,

  /// 0.75-0.89 -> ambar
  almost,

  /// < 0.75 -> rojo
  needsReview,
}

extension DgtPredictionVerdictX on DgtPredictionVerdict {
  String get label {
    switch (this) {
      case DgtPredictionVerdict.ready:
        return 'Listo';
      case DgtPredictionVerdict.almost:
        return 'Casi';
      case DgtPredictionVerdict.needsReview:
        return 'Necesitas repaso';
    }
  }

  Color get color {
    switch (this) {
      case DgtPredictionVerdict.ready:
        return const Color(0xFF4FFFB0);
      case DgtPredictionVerdict.almost:
        return const Color(0xFFFFB74F);
      case DgtPredictionVerdict.needsReview:
        return const Color(0xFFFF5C5C);
    }
  }
}

/// Stats por tema devueltas por `GET /dgt/stats/topics`.
class DgtTopicStat {
  final String topicId;
  final String? topicName;
  final int totalAnswered;
  final int correct;
  final double accuracyPct; // 0..100

  const DgtTopicStat({
    required this.topicId,
    required this.totalAnswered,
    required this.correct,
    required this.accuracyPct,
    this.topicName,
  });

  factory DgtTopicStat.fromJson(Map<String, dynamic> j) {
    return DgtTopicStat(
      topicId: (j['topic_id'] ?? '').toString(),
      topicName: j['topic_name'] as String?,
      totalAnswered: (j['total_answered'] as num?)?.toInt() ?? 0,
      correct: (j['correct'] as num?)?.toInt() ?? 0,
      accuracyPct: (j['accuracy_pct'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Accuracy en [0..1] (no en %).
  double get accuracy => accuracyPct / 100.0;
}

/// Resultado de [computePrediction]: score, veredicto, tema mas debil y total
/// de reviews considerado.
class DgtPrediction {
  /// Score esperado en [0..1] (proporcion de aciertos ponderada por pesos).
  final double expectedScore;
  final DgtPredictionVerdict verdict;
  final DgtTopicStat? weakest;

  /// Total de respuestas usadas en el calculo (suma de `total_answered`).
  final int totalReviews;

  const DgtPrediction({
    required this.expectedScore,
    required this.verdict,
    required this.totalReviews,
    this.weakest,
  });

  /// Hay datos suficientes para mostrar prediccion numerica.
  bool get hasEnoughData => totalReviews >= kDgtMinReviewsForPrediction;

  /// Probabilidad como porcentaje 0..100 (entero).
  int get probabilityPct => (expectedScore * 100).round();
}

/// Calcula el score esperado ponderado y el tema mas debil.
///
/// Si [stats] esta vacio, devuelve prediccion sin datos (totalReviews=0).
/// Si [stats] tiene temas sin peso en [kDgtTopicWeights], se ignoran del
/// calculo del score pero pueden seguir siendo "weakest" si tienen reviews.
DgtPrediction computePrediction(List<DgtTopicStat> stats) {
  if (stats.isEmpty) {
    return const DgtPrediction(
      expectedScore: 0.0,
      verdict: DgtPredictionVerdict.needsReview,
      totalReviews: 0,
    );
  }

  // Score ponderado: sum(peso_tema * accuracy_tema).
  double weightedSum = 0.0;
  double weightTotal = 0.0;
  for (final s in stats) {
    final w = kDgtTopicWeights[s.topicId];
    if (w == null) continue;
    weightedSum += w * s.accuracy;
    weightTotal += w;
  }

  // Si pesamos solo algunos bloques, normalizamos por peso cubierto.
  // Esto evita penalizar al usuario cuando aun no ha tocado todos los temas.
  final score = weightTotal > 0 ? (weightedSum / weightTotal) : 0.0;

  // Veredicto por threshold.
  DgtPredictionVerdict verdict;
  if (score >= 0.90) {
    verdict = DgtPredictionVerdict.ready;
  } else if (score >= 0.75) {
    verdict = DgtPredictionVerdict.almost;
  } else {
    verdict = DgtPredictionVerdict.needsReview;
  }

  // Tema mas debil: menor accuracy entre los que tengan al menos 1 review.
  // Si todos empatan, devuelve el primero (orden backend: peor primero).
  DgtTopicStat? weakest;
  for (final s in stats) {
    if (s.totalAnswered <= 0) continue;
    if (weakest == null || s.accuracyPct < weakest.accuracyPct) {
      weakest = s;
    }
  }

  final totalReviews = stats.fold<int>(0, (sum, s) => sum + s.totalAnswered);

  return DgtPrediction(
    expectedScore: score,
    verdict: verdict,
    weakest: weakest,
    totalReviews: totalReviews,
  );
}

/// Provider: stats por tema desde `GET /dgt/stats/topics`. Tolerante a
/// fallos (devuelve lista vacia si offline o endpoint 4xx/5xx) para no
/// bloquear la pantalla DGT cuando no hay conexion.
final dgtTopicStatsProvider = FutureProvider<List<DgtTopicStat>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final res = await api.get('/dgt/stats/topics');
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => DgtTopicStat.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  } catch (_) {
    return const [];
  }
});

/// Widget banner que muestra la prediccion + tema debil + CTA "Practicar".
///
/// Se renderiza ANTES del boton "Empezar simulacro" en `dgt_exam_screen.dart`.
/// Si los stats aun se estan cargando, muestra un placeholder discreto.
/// Si no hay datos suficientes, muestra un texto guia sin numero.
///
/// [onPractice] se llama con el `topicId` del tema mas debil cuando el
/// usuario pulsa "Practicar [tema]". Si es `null`, no se muestra el boton.
class DgtPredictionCard extends ConsumerWidget {
  final void Function(String topicId)? onPractice;

  const DgtPredictionCard({super.key, this.onPractice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dgtTopicStatsProvider);
    return statsAsync.when(
      loading: () => const _PredictionPlaceholder(),
      error: (_, _) => const SizedBox.shrink(),
      data: (stats) {
        final pred = computePrediction(stats);
        return _PredictionCardView(prediction: pred, onPractice: onPractice);
      },
    );
  }
}

class _PredictionPlaceholder extends StatelessWidget {
  const _PredictionPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Calculando tu prediccion...'),
        ],
      ),
    );
  }
}

class _PredictionCardView extends StatelessWidget {
  final DgtPrediction prediction;
  final void Function(String topicId)? onPractice;

  const _PredictionCardView({
    required this.prediction,
    required this.onPractice,
  });

  @override
  Widget build(BuildContext context) {
    if (!prediction.hasEnoughData) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.insights_outlined, size: 22),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Haz un simulacro para ver tu prediccion',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    final verdict = prediction.verdict;
    final color = verdict.color;
    final weakName = prediction.weakest?.topicName ??
        prediction.weakest?.topicId ??
        'tu tema mas debil';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Text(
                  '${prediction.probabilityPct}%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      verdict.label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Probabilidad estimada de aprobar',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (prediction.weakest != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 18, color: Color(0xFFFFB74F)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Tu punto debil: '),
                          TextSpan(
                            text: weakName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (onPractice != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      onPractice!(prediction.weakest!.topicId),
                  icon: const Icon(Icons.school_outlined, size: 18),
                  label: Text('Practicar $weakName'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
