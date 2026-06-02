import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:memora/core/theme/app_colors.dart';

import '../../../core/models/memora_card.dart';
import '../../../data/repositories/review_repository.dart';
import '../../review/review_completion_handler.dart';
import '../../review/review_invalidation.dart';
import 'feed_post_actions.dart';
import 'feed_post_content.dart';
import 'feed_post_header.dart';
import 'feed_post_more_menu.dart';
import 'feed_post_overlays.dart';

/// Tarjeta tipo "post de Instagram" para el feed scrollable.
///
/// Composicion de sub-widgets (todos en `lib/features/browse/widgets/`):
///   - `FeedPostHeader`: avatar + deck + estado SRS + menu "...".
///   - `FeedPostContent`: pregunta/respuesta con `AnimatedSwitcher`.
///   - `FeedPostActions`: heart, broken-heart, share, bookmark.
///   - `FeedDoubleTapHeart`, `FeedPostStatsLine`, `FeedAnsweredPill`:
///     piezas auxiliares.
///   - `FeedPostMoreMenu`: bottom sheet de "editar/eliminar".
///
/// La logica de level-up + title-up se delega en
/// `ReviewCompletionHandler` (en `features/review/`).
class FeedPostCard extends ConsumerStatefulWidget {
  final MemoraCard card;

  const FeedPostCard({super.key, required this.card});

  @override
  ConsumerState<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends ConsumerState<FeedPostCard>
    with TickerProviderStateMixin {
  bool _revealed = false;
  bool _answered = false;
  bool? _wasCorrect;
  bool _saving = false;
  bool _bookmarked = false;
  late final AnimationController _heartBounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final AnimationController _heartOverlay = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final AnimationController _bookmarkBounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  @override
  void dispose() {
    _heartBounce.dispose();
    _heartOverlay.dispose();
    _bookmarkBounce.dispose();
    super.dispose();
  }

  void _onDoubleTapHeart() {
    if (_answered || _saving) return;
    HapticFeedback.lightImpact();
    _heartOverlay.forward(from: 0);
    _answer(true);
  }

  void _reveal() {
    if (_revealed) return;
    HapticFeedback.lightImpact();
    setState(() => _revealed = true);
  }

  void _toggleBookmark() {
    HapticFeedback.lightImpact();
    _bookmarkBounce.forward(from: 0);
    setState(() => _bookmarked = !_bookmarked);
  }

  Future<void> _share() async {
    final c = widget.card;
    final text = '${c.deck}\n\n'
        'Pregunta: ${c.front}\n\n'
        'Respuesta: ${c.back}\n\n'
        '— RutaB';
    await Share.share(text, subject: c.deck);
  }

  Future<void> _answer(bool correct) async {
    if (_answered || _saving) return;
    HapticFeedback.mediumImpact();
    if (correct) {
      _heartBounce.forward(from: 0);
    }
    setState(() {
      _saving = true;
      _wasCorrect = correct;
    });
    final completion = ReviewCompletionHandler(ref);
    final beforeProgress = completion.snapshotBefore();
    await ref.read(reviewRepositoryProvider).recordReview(
          cardId: widget.card.id,
          correct: correct,
          now: DateTime.now(),
        );
    if (!mounted) return;
    invalidateAfterReview(ref);
    setState(() {
      _answered = true;
      _saving = false;
    });
    await completion.handleAfter(
      context: context,
      beforeProgress: beforeProgress,
      card: widget.card,
      isMounted: () => mounted,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: context.c.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: c.deckColor.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: c.deckColor.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FeedPostHeader(
            card: c,
            onMore: () => FeedPostMoreMenu.show(
              context: context,
              ref: ref,
              card: c,
            ),
          ),
          GestureDetector(
            onTap: (_revealed || _answered) ? null : _reveal,
            onDoubleTap: _onDoubleTapHeart,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              alignment: Alignment.center,
              children: [
                FeedPostContent(
                  card: c,
                  revealed: _revealed,
                  frontImagePath: c.frontImagePath,
                  backImagePath: c.backImagePath,
                ),
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _heartOverlay,
                    builder: (ctx, _) => FeedDoubleTapHeart(t: _heartOverlay.value),
                  ),
                ),
              ],
            ),
          ),
          FeedPostActions(
            answered: _answered,
            wasCorrect: _wasCorrect,
            bookmarked: _bookmarked,
            saving: _saving,
            heartAnim: _heartBounce,
            bookmarkAnim: _bookmarkBounce,
            onCorrect: () => _answer(true),
            onIncorrect: () => _answer(false),
            onBookmark: _toggleBookmark,
            onShare: _share,
          ),
          if (!_revealed && !_answered)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: GestureDetector(
                onTap: _reveal,
                child: Text(
                  'Ver respuesta',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.c.textMuted,
                  ),
                ),
              ),
            ),
          FeedPostStatsLine(cardId: widget.card.id),
          if (_answered)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: FeedAnsweredPill(correct: _wasCorrect == true),
            )
          else
            const SizedBox(height: 10),
        ],
      ),
    );
  }
}
