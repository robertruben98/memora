import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';

/// Pesos default por tema DGT (suman 1.0). Basado en distribucion del
/// examen teorico permiso B. Editar aqui sin tocar el resto del codigo.
///
/// Topic ids segun `app/seed_dgt.py` (DGT_TOPICS):
///   dgt-t-01 senales verticales         -> 0.30 (senales)
///   dgt-t-08 normas de circulacion      -> 0.30 (normas)
///   dgt-t-03 iluminacion                -> 0.10 (luces)
///   dgt-t-12 mecanica                   -> 0.10 (mecanica)
///   dgt-t-13 primeros auxilios          -> 0.10 (primeros auxilios)
///   resto (02,04,05,06,07,09,10,11)     -> 0.10 reparto plano (otros)
const Map<String, double> kDgtTopicWeights = {
  'dgt-t-01': 0.30,
  'dgt-t-08': 0.30,
  'dgt-t-03': 0.10,
  'dgt-t-12': 0.10,
  'dgt-t-13': 0.10,
  // "Otros" -> 8 temas restantes a 0.0125 cada uno = 0.10 total.
  'dgt-t-02': 0.0125,
  'dgt-t-04': 0.0125,
  'dgt-t-05': 0.0125,
  'dgt-t-06': 0.0125,
  'dgt-t-07': 0.0125,
  'dgt-t-09': 0.0125,
  'dgt-t-10': 0.0125,
  'dgt-t-11': 0.0125,
};

/// Minimo de reviews totales para mostrar prediccion numerica.
/// Bajo ese umbral, recomendamos "haz un simulacro" sin numero.
const int kDgtMinReviewsForPrediction = 10;

/// Umbrales de aprobado (>=27 / 30 = 0.90), casi (>=0.75) y necesita repaso.
const double kDgtThresholdReady = 0.90;
const double kDgtThresholdAlmost = 0.75;

/// Stat por tema devuelta por GET /dgt/stats/topics.
class DgtTopicStat {
  final String topicId;
  final String? topicName;
  final int totalAnswered;
  final int correct;
  final double accuracyPct;

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
}

/// Resultado del calculo de prediccion.
class DgtPrediction {
  /// Score esperado en escala 0..1 (sum peso_tema * accuracy_tema).
  /// `null` si no hay suficientes datos.
  final double? expectedScore;

  /// Tema mas debil (menor accuracy). `null` si no hay datos.
  final DgtTopicStat? weakestTopic;

  /// Total de reviews que alimentaron el calculo.
  final int totalReviews;

  /// `true` si totalReviews >= [kDgtMinReviewsForPrediction].
  bool get hasEnoughData =>
      totalReviews >= kDgtMinReviewsForPrediction && expectedScore != null;

  const DgtPrediction({
    required this.totalReviews,
    this.expectedScore,
    this.weakestTopic,
  });

  static const empty = DgtPrediction(totalReviews: 0);

  /// Calcula score esperado ponderando accuracy de cada tema por su peso.
  /// Si un tema no tiene datos, asume 0.5 (50%) — heuristica neutra.
  factory DgtPrediction.compute(
    List<DgtTopicStat> stats, {
    Map<String, double> weights = kDgtTopicWeights,
  }) {
    final total = stats.fold<int>(0, (acc, s) => acc + s.totalAnswered);
    if (stats.isEmpty || total < kDgtMinReviewsForPrediction) {
      return DgtPrediction(totalReviews: total);
    }
    final byTopic = {for (final s in stats) s.topicId: s};
    var score = 0.0;
    weights.forEach((tid, w) {
      final s = byTopic[tid];
      final acc = s != null && s.totalAnswered > 0
          ? (s.accuracyPct / 100.0).clamp(0.0, 1.0)
          : 0.5;
      score += w * acc;
    });
    // Si los pesos no suman exactamente 1, normalizamos para evitar drift.
    final weightSum = weights.values.fold<double>(0.0, (a, b) => a + b);
    if (weightSum > 0) score = score / weightSum;
    // Tema mas debil: solo entre los que tienen datos reales.
    DgtTopicStat? weakest;
    for (final s in stats) {
      if (s.totalAnswered <= 0) continue;
      if (weakest == null || s.accuracyPct < weakest.accuracyPct) {
        weakest = s;
      }
    }
    return DgtPrediction(
      totalReviews: total,
      expectedScore: score,
      weakestTopic: weakest,
    );
  }
}

/// Repositorio thin para GET /dgt/stats/topics. Aislado del repo de
/// preguntas para no contaminar [DgtRepository].
class DgtPredictionRepository {
  final ApiClient _api;
  DgtPredictionRepository(this._api);

  Future<DgtPrediction> fetchPrediction({int days = 30}) async {
    try {
      final res =
          await _api.get('/dgt/stats/topics', query: {'days': '$days'});
      if (res is! List) return DgtPrediction.empty;
      final stats = res
          .whereType<Map>()
          .map((e) => DgtTopicStat.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return DgtPrediction.compute(stats);
    } catch (_) {
      // Backend offline / no autorizado / endpoint no expuesto: degrada
      // a "sin datos" y la UI muestra el copy de fallback.
      return DgtPrediction.empty;
    }
  }

  /// Devuelve el desglose crudo por tema (issue #67). Consume el mismo
  /// endpoint GET /dgt/stats/topics que [fetchPrediction] pero retorna la
  /// lista sin agregar (`accuracyPct` por bloque). UI nueva (estadisticas
  /// por tema) lo usa para listar y ordenar por debilidad.
  ///
  /// Si el endpoint no esta disponible o devuelve algo distinto a una
  /// lista, retorna lista vacia: la UI degrada a estado "sin datos aun".
  Future<List<DgtTopicStat>> fetchTopicStats({int days = 30}) async {
    try {
      final res =
          await _api.get('/dgt/stats/topics', query: {'days': '$days'});
      if (res is! List) return const <DgtTopicStat>[];
      return res
          .whereType<Map>()
          .map((e) => DgtTopicStat.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const <DgtTopicStat>[];
    }
  }
}

/// Provider con la lista cruda de stats por tema (issue #67). Aditivo
/// respecto a [dgtPredictionProvider]; no se mezclan.
final dgtTopicStatsProvider =
    FutureProvider<List<DgtTopicStat>>((ref) async {
  return ref.watch(dgtPredictionRepositoryProvider).fetchTopicStats();
});

final dgtPredictionRepositoryProvider =
    Provider<DgtPredictionRepository>((ref) {
  return DgtPredictionRepository(ref.watch(apiClientProvider));
});

final dgtPredictionProvider = FutureProvider<DgtPrediction>((ref) async {
  return ref.watch(dgtPredictionRepositoryProvider).fetchPrediction();
});

/// Banner/Card con prediccion + tema debil. Se incrusta antes del boton
/// "Empezar simulacro".
class DgtPredictionCard extends ConsumerWidget {
  /// Callback al pulsar "Practicar este tema". Recibe el topicId del tema
  /// mas debil (puede ser `null` si la prediccion no tiene weakestTopic).
  /// Si es `null`, la card NO muestra el boton (modo informativo).
  final void Function(String topicId)? onPracticeWeakest;

  /// Callback al pulsar "Ver detalle por tema" (issue #67). Si es `null`,
  /// el boton no se muestra (aditivo, no rompe usos existentes).
  final VoidCallback? onViewTopicStats;

  const DgtPredictionCard({
    super.key,
    this.onPracticeWeakest,
    this.onViewTopicStats,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dgtPredictionProvider);
    return async.when(
      data: (p) => _buildCard(context, p),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildCard(BuildContext context, DgtPrediction p) {
    if (!p.hasEnoughData) {
      return _baseCard(
        color: Colors.white.withValues(alpha: 0.06),
        accent: Colors.white.withValues(alpha: 0.5),
        title: 'Haz un simulacro para ver tu prediccion',
        subtitle:
            'Necesitamos al menos $kDgtMinReviewsForPrediction respuestas '
            'para estimar tu probabilidad de aprobar.',
      );
    }
    final score = p.expectedScore!;
    final pct = (score * 100).round();
    final tier = _tierFor(score);
    // Trailing: si hay weakest + callback de practica, mostramos boton
    // "Practicar tema X". Si NO hay practica pero si hay callback de stats
    // por tema (#67), mostramos "Ver detalle" como fallback informativo.
    Widget? trailing;
    if (p.weakestTopic != null && onPracticeWeakest != null) {
      trailing = TextButton(
        onPressed: () => onPracticeWeakest!(p.weakestTopic!.topicId),
        child: Text(
          'Practicar ${p.weakestTopic!.topicName ?? "tema"}',
          style: TextStyle(color: tier.accent),
        ),
      );
    } else if (onViewTopicStats != null) {
      trailing = TextButton(
        onPressed: onViewTopicStats,
        child: Text(
          'Ver detalle',
          style: TextStyle(color: tier.accent),
        ),
      );
    }
    return _baseCard(
      color: tier.background,
      accent: tier.accent,
      title: '${tier.label} - $pct% probabilidad estimada',
      subtitle: p.weakestTopic != null
          ? 'Tu punto debil: ${p.weakestTopic!.topicName ?? p.weakestTopic!.topicId} '
              '(${p.weakestTopic!.accuracyPct.toStringAsFixed(0)}% acierto)'
          : 'Sigue practicando para afinar la estimacion.',
      trailing: trailing,
    );
  }

  Widget _baseCard({
    required Color color,
    required Color accent,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 36,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  _PredictionTier _tierFor(double score) {
    if (score >= kDgtThresholdReady) {
      return const _PredictionTier(
        label: 'Listo',
        background: Color(0x224FFFB0),
        accent: Color(0xFF4FFFB0),
      );
    }
    if (score >= kDgtThresholdAlmost) {
      return const _PredictionTier(
        label: 'Casi',
        background: Color(0x22FFB74F),
        accent: Color(0xFFFFB74F),
      );
    }
    return const _PredictionTier(
      label: 'Necesitas repaso',
      background: Color(0x22FF5C5C),
      accent: Color(0xFFFF5C5C),
    );
  }
}

class _PredictionTier {
  final String label;
  final Color background;
  final Color accent;
  const _PredictionTier({
    required this.label,
    required this.background,
    required this.accent,
  });
}
