import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memora/core/theme/app_colors.dart';

import '../dgt_time_of_day_insight_provider.dart';

/// Issue #137 (dgt-ux): card "tu mejor hora para estudiar".
///
/// Se renderiza en pantallas de stats DGT (p.ej. [DgtTopicStatsScreen]).
/// - Sin datos suficientes: muestra placeholder "necesitamos mas datos".
/// - Con datos pero sin franja ganadora clara: muestra el grafico solo.
/// - Con franja ganadora: highlight + copy "aciertas X% mas entre HH-HH".
/// - CTA opcional [onProgramReminder] con el bucket ganador prerelleno.
///
/// Aditivo: no toca el bloque existente de stats por tema.
class BestHourCard extends ConsumerWidget {
  /// Callback invocado al pulsar "Programar recordatorio en este rango".
  /// Si es null, el boton no se muestra (modo solo lectura).
  final void Function(DgtTimeOfDayBucket bucket)? onProgramReminder;

  const BestHourCard({super.key, this.onProgramReminder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dgtTimeOfDayInsightProvider);
    return async.when(
      loading: () => const _Container(
        child: SizedBox(
          height: 80,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (insight) => _BestHourBody(
        insight: insight,
        onProgramReminder: onProgramReminder,
      ),
    );
  }
}

class _BestHourBody extends StatelessWidget {
  final DgtTimeOfDayInsight insight;
  final void Function(DgtTimeOfDayBucket bucket)? onProgramReminder;

  const _BestHourBody({
    required this.insight,
    required this.onProgramReminder,
  });

  @override
  Widget build(BuildContext context) {
    if (!insight.hasEnoughData) {
      return _Container(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Necesitamos mas datos '
                  '(${insight.totalReviews}/$kDgtTimeOfDayMinReviews reviews)',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.c.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final best = insight.bestBucket;
    final maxAcc = insight.buckets
        .map((b) => b.accuracyPct)
        .fold<double>(0.0, (a, b) => b > a ? b : a);
    return _Container(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Tu mejor hora',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (best != null)
                  Text(
                    '${best.accuracyPct.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4FFFB0),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (best != null)
              Text(
                'Aciertas un ${insight.edgePct!.toStringAsFixed(0)}% mas '
                'entre ${best.label}h',
                style: TextStyle(
                  fontSize: 12,
                  color: context.c.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              Text(
                'Tu rendimiento esta repartido sin un horario ganador claro.',
                style: TextStyle(
                  fontSize: 12,
                  color: context.c.textSecondary,
                ),
              ),
            const SizedBox(height: 12),
            _BarChart(
              buckets: insight.buckets,
              bestIndex: insight.bestBucketIndex,
              maxAccuracy: maxAcc,
            ),
            if (best != null && onProgramReminder != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => onProgramReminder!(best),
                  icon: const Icon(
                    Icons.notifications_active_outlined,
                    size: 16,
                  ),
                  label: const Text('Programar recordatorio en este rango'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Wrapper visual estandar (mismo aspecto que tiles del screen padre).
class _Container extends StatelessWidget {
  final Widget child;
  const _Container({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.c.surfaceMuted,
      borderRadius: BorderRadius.circular(14),
      child: child,
    );
  }
}

/// Grafico de barras horizontal sin libreria externa.
/// Una columna por franja (8 columnas, 24h/3h). Altura proporcional a
/// accuracy. La franja ganadora se resalta en verde.
class _BarChart extends StatelessWidget {
  final List<DgtTimeOfDayBucket> buckets;
  final int? bestIndex;
  final double maxAccuracy;

  const _BarChart({
    required this.buckets,
    required this.bestIndex,
    required this.maxAccuracy,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < buckets.length; i++)
            Expanded(child: _Bar(bucket: buckets[i], isBest: i == bestIndex, maxAccuracy: maxAccuracy)),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final DgtTimeOfDayBucket bucket;
  final bool isBest;
  final double maxAccuracy;

  const _Bar({
    required this.bucket,
    required this.isBest,
    required this.maxAccuracy,
  });

  @override
  Widget build(BuildContext context) {
    final pct = bucket.accuracyPct;
    // Altura relativa al maximo, minimo 4px para que franjas no vacias
    // sean visibles. Vacias quedan a 2px (placeholder visual).
    final double ratio;
    if (bucket.total <= 0) {
      ratio = 0.04;
    } else if (maxAccuracy <= 0) {
      ratio = 0.1;
    } else {
      ratio = (pct / maxAccuracy).clamp(0.1, 1.0);
    }
    final fillColor = isBest
        ? const Color(0xFF4FFFB0)
        : context.c.textMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: FractionallySizedBox(
              alignment: Alignment.bottomCenter,
              heightFactor: ratio,
              child: Container(
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            bucket.startHour.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: 9,
              color: isBest ? context.c.textPrimary : context.c.textMuted,
              fontWeight: isBest ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
