import 'package:flutter/material.dart';

import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';

/// Fila de acciones estilo Instagram: heart (acerté), X (fallé),
/// share y bookmark con animaciones de bounce.
class FeedPostActions extends StatelessWidget {
  final bool answered;
  final bool? wasCorrect;
  final bool bookmarked;
  final bool saving;
  final AnimationController heartAnim;
  final AnimationController bookmarkAnim;
  final VoidCallback onCorrect;
  final VoidCallback onIncorrect;
  final VoidCallback onBookmark;
  final VoidCallback onShare;

  const FeedPostActions({
    super.key,
    required this.answered,
    required this.wasCorrect,
    required this.bookmarked,
    required this.saving,
    required this.heartAnim,
    required this.bookmarkAnim,
    required this.onCorrect,
    required this.onIncorrect,
    required this.onBookmark,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final liked = answered && wasCorrect == true;
    final disliked = answered && wasCorrect == false;
    final disabled = saving;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Row(
        children: [
          ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.35).animate(
              CurvedAnimation(
                parent: heartAnim,
                curve: Curves.elasticOut,
              ),
            ),
            child: _IconAction(
              icon: liked ? Icons.favorite_rounded : Icons.favorite_outline,
              color: liked ? DgtStatusColors.danger : context.c.textPrimary,
              onTap: disabled || answered ? null : onCorrect,
              tooltip: 'Acerté',
            ),
          ),
          _IconAction(
            icon: disliked
                ? Icons.heart_broken_rounded
                : Icons.close_rounded,
            color: disliked ? DgtStatusColors.danger : context.c.textPrimary,
            onTap: disabled || answered ? null : onIncorrect,
            tooltip: 'No acerté',
          ),
          _IconAction(
            icon: Icons.send_rounded,
            color: context.c.textPrimary,
            onTap: onShare,
            tooltip: 'Compartir',
          ),
          const Spacer(),
          ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.35).animate(
              CurvedAnimation(
                parent: bookmarkAnim,
                curve: Curves.elasticOut,
              ),
            ),
            child: _IconAction(
              icon: bookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: bookmarked ? DgtStatusColors.warningStrong : context.c.textPrimary,
              onTap: onBookmark,
              tooltip: bookmarked ? 'Quitar marcador' : 'Guardar',
            ),
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String tooltip;

  const _IconAction({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        radius: 24,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 26,
            color: onTap == null
                ? color.withValues(alpha: 0.3)
                : color.withValues(alpha: 0.92),
          ),
        ),
      ),
    );
  }
}
