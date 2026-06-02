import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/widgets/app_state_view.dart';

import '../../data/repositories/review_repository.dart';
import '../dgt/dgt_settings.dart';
import '../profile/character_progress.dart';
import '../profile/level_up_overlay.dart';
import '../profile/title_unlock_overlay.dart';
import '../study/widgets/explanation_bottom_sheet.dart';
import 'feed_session_notifier.dart';
import 'review_invalidation.dart';
import 'study_queue.dart';
import 'widgets/card_page.dart';

class FeedScreen extends ConsumerWidget {
  /// null = estudiar todos los mazos (modo "Estudiar todo").
  final String? deckId;

  const FeedScreen({super.key, this.deckId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(studyQueueProvider(deckId));
    return queueAsync.when(
      loading: () => Scaffold(
        body: AppStateView.loading(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: AppStateView.error(e),
      ),
      data: (queue) {
        if (queue.isEmpty) {
          return const _AllCaughtUpScreen();
        }
        return _ActiveFeed(deckId: deckId, queue: queue);
      },
    );
  }
}

class _ActiveFeed extends ConsumerStatefulWidget {
  final String? deckId;
  final StudyQueue queue;

  const _ActiveFeed({required this.deckId, required this.queue});

  @override
  ConsumerState<_ActiveFeed> createState() => _ActiveFeedState();
}

class _ActiveFeedState extends ConsumerState<_ActiveFeed> {
  final _controller = PageController();
  bool _completionShown = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onAnswer(BuildContext context, {required bool correct}) async {
    HapticFeedback.mediumImpact();
    final notifier =
        ref.read(feedSessionProvider(widget.queue.cards).notifier);
    notifier.registerAnswer(correct: correct);

    final state = ref.read(feedSessionProvider(widget.queue.cards));
    final currentCard = widget.queue.cards[state.currentIndex];

    final beforeProgress = ref
        .read(characterProgressProvider)
        .maybeWhen(data: (p) => p, orElse: () => null);
    // Persist SRS update + review log (await to keep order tight).
    await ref.read(reviewRepositoryProvider).recordReview(
          cardId: currentCard.id,
          correct: correct,
          now: DateTime.now(),
        );
    if (!context.mounted) return;
    invalidateAfterReview(ref, deckId: widget.deckId);

    // DGT issue #42: refuerzo didactico al fallar.
    // Mostrar BottomSheet con explicacion ANTES de avanzar.
    // Aditivo: si el setting esta OFF, no se ejecuta nada extra.
    if (!correct) {
      final dgt = ref.read(dgtSettingsProvider).valueOrNull;
      if ((dgt?.showExplanationOnFail ?? true) && context.mounted) {
        await ExplanationBottomSheet.show(context, currentCard);
      }
    }
    if (!context.mounted) return;

    if (state.isCompleted) {
      if (context.mounted) _showCompletion(context, state);
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }

    if (beforeProgress != null) {
      try {
        final after = await ref.read(characterProgressProvider.future);
        if (!context.mounted) return;
        // Title-up del mazo de la card actual
        final beforeDeck = beforeProgress.decks.firstWhere(
          (d) => d.deckId == currentCard.deckId,
          orElse: () => DeckProgress(
            deckId: currentCard.deckId,
            name: currentCard.deck,
            iconName: currentCard.deckIconName,
            colorHex: '',
            reviews: 0,
            correct: 0,
            level: 1,
            rank: DeckRank.none,
          ),
        );
        final afterDeck = after.decks.firstWhere(
          (d) => d.deckId == currentCard.deckId,
          orElse: () => beforeDeck,
        );
        if (afterDeck.rank.index > beforeDeck.rank.index && context.mounted) {
          TitleUnlockOverlay.show(
            context,
            deckName: afterDeck.name,
            newRank: afterDeck.rank,
            accent: currentCard.deckColor,
          );
          await Future.delayed(const Duration(milliseconds: 2900));
        }
        if (after.level > beforeProgress.level && context.mounted) {
          LevelUpOverlay.show(
            context,
            newLevel: after.level,
            title: after.title != beforeProgress.title ? after.title : null,
          );
        }
      } catch (_) {}
    }
  }

  void _showCompletion(BuildContext context, FeedSessionState state) {
    if (_completionShown) return;
    _completionShown = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: context.c.surfaceElevated,
        title: const Text('¡Sesión completa!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tarjetas revisadas: ${state.cards.length}'),
            const SizedBox(height: 4),
            Text('Aciertos: ${state.correctCount}'),
            Text('Fallos: ${state.incorrectCount}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Volver al inicio'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedSessionProvider(widget.queue.cards));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '${state.currentIndex + 1} / ${state.cards.length}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (widget.queue.dueCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _Chip(
                label: '${widget.queue.dueCount} due',
                color: const Color(0xFFFF8A4F),
              ),
            ),
          if (widget.queue.newCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _Chip(
                label: '${widget.queue.newCount} nuevas',
                color: const Color(0xFF4F8AFF),
              ),
            ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        itemCount: state.cards.length,
        onPageChanged: (i) {
          ref
              .read(feedSessionProvider(widget.queue.cards).notifier)
              .setCurrentIndex(i);
        },
        itemBuilder: (context, index) {
          return CardPage(
            card: state.cards[index],
            onCorrect: () => _onAnswer(context, correct: true),
            onIncorrect: () => _onAnswer(context, correct: false),
          );
        },
      ),
    );
  }
}

class _AllCaughtUpScreen extends StatelessWidget {
  const _AllCaughtUpScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: const Color(0xFF4FFFB0).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 56,
                  color: Color(0xFF4FFFB0),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '¡Todo al día!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No tienes tarjetas pendientes ahora mismo.\n'
                'Vuelve cuando se acerque la próxima revisión.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: context.c.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                ),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
