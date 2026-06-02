import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memora/core/theme/app_colors.dart';

import '../../../core/models/memora_card.dart';
import '../../../core/theme/deck_visuals.dart';
import '../../../data/database/database.dart';
import '../../../data/repositories/review_repository.dart';

/// Cabecera de la tarjeta del feed: avatar + nombre del mazo +
/// label de estado SRS + boton de menu "...".
class FeedPostHeader extends ConsumerWidget {
  final MemoraCard card;
  final VoidCallback onMore;

  const FeedPostHeader({
    super.key,
    required this.card,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(allCardSchedulesProvider);
    final schedule = schedulesAsync.maybeWhen(
      data: (m) => m[card.id],
      orElse: () => null,
    );
    final stateLabel = _stateLabelFor(schedule);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  card.deckColor,
                  card.deckColor.withValues(alpha: 0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.c.surfaceElevated,
              ),
              child: Center(
                child: Icon(
                  DeckVisuals.iconFor(card.deckIconName),
                  color: card.deckColor,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.deck,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.c.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  stateLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.c.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, size: 22),
            color: context.c.textSecondary,
            onPressed: onMore,
            tooltip: 'Más',
          ),
        ],
      ),
    );
  }

  String _stateLabelFor(CardScheduleRow? s) {
    if (s == null || s.state == 'new') return 'Nueva';
    if (s.state == 'learning') return 'Aprendiendo';
    final now = DateTime.now();
    final next = DateTime.fromMillisecondsSinceEpoch(s.nextReviewDate);
    final today = DateTime(now.year, now.month, now.day);
    final nextDay = DateTime(next.year, next.month, next.day);
    final diffDays = nextDay.difference(today).inDays;
    if (diffDays <= 0) return 'Due ahora';
    if (diffDays == 1) return 'Due mañana';
    if (diffDays < 7) return 'En $diffDays días';
    final weeks = (diffDays / 7).round();
    return weeks == 1 ? 'En 1 semana' : 'En $weeks semanas';
  }
}
