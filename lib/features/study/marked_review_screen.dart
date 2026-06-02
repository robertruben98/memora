import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/widgets/app_state_view.dart';
import '../../core/models/memora_card.dart';
import '../../data/repositories/review_repository.dart';
import '../review/review_invalidation.dart';
import '../review/widgets/card_page.dart';
import '../review/widgets/review_completion_dialog.dart';
import 'marked_cards_provider.dart';

/// Modo "Repasar marcadas": cola dedicada con cards que el usuario marco con
/// la estrella durante el estudio (favoritos para repaso pre-examen DGT).
///
/// Aditivo: reutiliza CardPage + reviewRepository.recordReview existentes.
/// No muta SRS ni queue principal.
class MarkedReviewScreen extends ConsumerWidget {
  const MarkedReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(markedCardsResolvedProvider);
    return async.when(
      loading: () => Scaffold(
        body: AppStateView.loading(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: AppStateView.error(e),
      ),
      data: (result) {
        if (result.cards.isEmpty) {
          return const _MarkedEmptyScreen();
        }
        return _ActiveMarkedReview(cards: result.cards);
      },
    );
  }
}

class _ActiveMarkedReview extends ConsumerStatefulWidget {
  final List<MemoraCard> cards;
  const _ActiveMarkedReview({required this.cards});

  @override
  ConsumerState<_ActiveMarkedReview> createState() =>
      _ActiveMarkedReviewState();
}

class _ActiveMarkedReviewState extends ConsumerState<_ActiveMarkedReview> {
  final _controller = PageController();
  int _currentIndex = 0;
  int _correct = 0;
  int _incorrect = 0;
  bool _completionShown = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onAnswer(BuildContext context, {required bool correct}) async {
    HapticFeedback.mediumImpact();
    final card = widget.cards[_currentIndex];

    setState(() {
      if (correct) {
        _correct++;
      } else {
        _incorrect++;
      }
    });

    await ref.read(reviewRepositoryProvider).recordReview(
          cardId: card.id,
          correct: correct,
          now: DateTime.now(),
        );
    if (!context.mounted) return;
    invalidateAfterReview(ref, deckId: null);

    final isLast = _currentIndex >= widget.cards.length - 1;
    if (isLast) {
      _showCompletion(context);
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showCompletion(BuildContext context) {
    if (_completionShown) return;
    _completionShown = true;
    showReviewCompletionDialog(
      context,
      title: '¡Repaso completado!',
      stats: [
        ReviewCompletionStat('Tarjetas repasadas', widget.cards.length),
        ReviewCompletionStat('Aciertos', _correct),
        ReviewCompletionStat('Fallos', _incorrect),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Marcadas · ${_currentIndex + 1} / ${widget.cards.length}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        itemCount: widget.cards.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, index) {
          return CardPage(
            card: widget.cards[index],
            onCorrect: () => _onAnswer(context, correct: true),
            onIncorrect: () => _onAnswer(context, correct: false),
          );
        },
      ),
    );
  }
}

class _MarkedEmptyScreen extends StatelessWidget {
  const _MarkedEmptyScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Repasar marcadas',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
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
                  color: const Color(0xFFFFC857).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star_rounded,
                  size: 56,
                  color: Color(0xFFFFC857),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Sin tarjetas marcadas',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Marca preguntas con la estrella durante el estudio\n'
                'para construir tu lista personal de repaso pre-examen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: context.c.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
