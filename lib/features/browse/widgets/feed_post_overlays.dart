import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';

import '../../stats/card_stats_provider.dart';

/// Overlay del corazon en double-tap (estilo Instagram).
///
/// Recibe el valor [t] del controller (0..1) y mapea a una secuencia
/// de tres fases: aparece, mantiene tamano, desaparece.
class FeedDoubleTapHeart extends StatelessWidget {
  final double t;

  const FeedDoubleTapHeart({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    if (t == 0) return const SizedBox.shrink();
    final double scale;
    final double opacity;
    if (t < 0.35) {
      final p = t / 0.35;
      scale = Curves.easeOutBack.transform(p) * 1.2;
      opacity = (p * 1.2).clamp(0.0, 1.0);
    } else if (t < 0.6) {
      scale = 1.2 - (t - 0.35) / 0.25 * 0.2;
      opacity = 1.0;
    } else {
      scale = 1.0 - (t - 0.6) / 0.4 * 0.05;
      opacity = 1.0 - (t - 0.6) / 0.4;
    }
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale.clamp(0.0, 2.0),
        child: Icon(
          Icons.favorite_rounded,
          size: 110,
          color: Colors.white.withValues(alpha: 0.92),
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Linea con resumen de stats: "X aciertos · Y intentos · ultima Z".
class FeedPostStatsLine extends ConsumerWidget {
  final String cardId;

  const FeedPostStatsLine({super.key, required this.cardId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(cardStatsProvider);
    final stats = statsAsync.maybeWhen(
      data: (m) => m[cardId],
      orElse: () => null,
    );
    if (stats == null || !stats.hasReviews) {
      return const SizedBox(height: 4);
    }
    final relTime = formatRelativeTime(stats.lastReviewMs);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Text(
        '${stats.correct} aciertos · ${stats.total} intentos · última $relTime',
        style: TextStyle(
          fontSize: 12,
          color: context.c.textMuted,
        ),
      ),
    );
  }
}

/// Pill que muestra si la tarjeta fue marcada como acertada o fallada.
class FeedAnsweredPill extends StatelessWidget {
  final bool correct;

  const FeedAnsweredPill({super.key, required this.correct});

  @override
  Widget build(BuildContext context) {
    final color =
        correct ? const Color(0xFF4FFFB0) : const Color(0xFFFF4F6B);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            correct ? 'Marcada como acertada' : 'Marcada como fallada',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
