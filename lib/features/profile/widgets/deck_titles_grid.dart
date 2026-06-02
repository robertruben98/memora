import 'package:flutter/material.dart';

import 'package:memora/core/theme/app_colors.dart';
import '../../../core/theme/deck_visuals.dart';
import '../character_progress.dart';

/// Listado de títulos del personaje según los rangos alcanzados por mazo.
class DeckTitlesGrid extends StatelessWidget {
  final List<DeckProgress> decks;
  const DeckTitlesGrid({super.key, required this.decks});

  @override
  Widget build(BuildContext context) {
    final earned = decks
        .where((d) => d.rank != DeckRank.none)
        .toList()
      ..sort((a, b) => b.rank.index.compareTo(a.rank.index));

    if (earned.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.c.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.c.border),
        ),
        child: Column(
          children: [
            Text(
              '🏷️',
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 8),
            Text(
              'Sin títulos todavía',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.c.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Acierta 5 cartas de un mazo para ganar el primer rango.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: context.c.textMuted,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final d in earned)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _DeckTitleBadge(deck: d),
          ),
      ],
    );
  }
}

class _DeckTitleBadge extends StatelessWidget {
  final DeckProgress deck;
  const _DeckTitleBadge({required this.deck});

  @override
  Widget build(BuildContext context) {
    final color = DeckVisuals.colorFromHex(deck.colorHex);
    final next = _nextRank(deck.rank);
    final progressToNext = next == null
        ? 1.0
        : ((deck.correct - deck.rank.threshold) /
                (next.threshold - deck.rank.threshold))
            .clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                deck.rank.emoji,
                style: const TextStyle(fontSize: 26),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${deck.rank.label} de ${deck.name}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${deck.correct} aciertos',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (next != null)
                Text(
                  next.emoji,
                  style: TextStyle(
                    fontSize: 18,
                    color: context.c.textMuted,
                  ),
                ),
            ],
          ),
          if (next != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 4,
                color: Colors.black.withValues(alpha: 0.4),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progressToNext,
                  child: Container(color: color),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Próximo: ${next.label} a los ${next.threshold} aciertos '
              '(${deck.correct}/${next.threshold})',
              style: TextStyle(
                fontSize: 10,
                color: context.c.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  DeckRank? _nextRank(DeckRank current) {
    final values = DeckRank.values;
    final idx = values.indexOf(current);
    return idx < values.length - 1 ? values[idx + 1] : null;
  }
}
