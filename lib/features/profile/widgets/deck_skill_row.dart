import 'package:flutter/material.dart';

import 'package:memora/core/theme/app_colors.dart';
import '../../../core/theme/deck_visuals.dart';
import '../character_progress.dart';

/// Fila con habilidad/nivel de un mazo concreto.
class DeckSkillRow extends StatelessWidget {
  final DeckProgress deck;
  const DeckSkillRow({super.key, required this.deck});

  @override
  Widget build(BuildContext context) {
    final color = DeckVisuals.colorFromHex(deck.colorHex);
    final progress = deck.reviews == 0
        ? 0.0
        : ((deck.correct / deck.reviews).clamp(0.0, 1.0));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.c.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  DeckVisuals.iconFor(deck.iconName),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        if (deck.rank != DeckRank.none) ...[
                          Text(
                            '${deck.rank.emoji} ${deck.rank.label}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                          Text(
                            '  ·  ',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.c.textMuted,
                            ),
                          ),
                        ],
                        Flexible(
                          child: Text(
                            '${deck.reviews} reviews · ${(progress * 100).toStringAsFixed(0)}% acierto',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.c.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Lv ${deck.level}',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (deck.reviews > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 4,
                color: Colors.black.withValues(alpha: 0.4),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(color: color),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
