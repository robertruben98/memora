import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/memora_card.dart';
import '../../data/repositories/review_repository.dart';
import '../review/review_invalidation.dart';
import '../review/widgets/card_page.dart';
import 'failed_cards_provider.dart';

/// Modo "Repaso de falladas" para examen DGT:
/// cola dedicada con cards cuya ultima review (ultimos 14 dias) fue incorrecta.
///
/// Aditivo: reutiliza CardPage + reviewRepository.recordReview existentes.
/// No altera SRS ni queue normal.
class FailedReviewScreen extends ConsumerWidget {
  const FailedReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(failedCardsProvider);
    return async.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (result) {
        if (result.cards.isEmpty) {
          return const _FailedEmptyScreen();
        }
        return _ActiveFailedReview(cards: result.cards);
      },
    );
  }
}

class _ActiveFailedReview extends ConsumerStatefulWidget {
  final List<MemoraCard> cards;
  const _ActiveFailedReview({required this.cards});

  @override
  ConsumerState<_ActiveFailedReview> createState() =>
      _ActiveFailedReviewState();
}

class _ActiveFailedReviewState extends ConsumerState<_ActiveFailedReview> {
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
    // Refrescar tambien el provider de falladas para mantener badge al dia.
    ref.invalidate(failedCardsProvider);

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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A22),
        title: const Text('¡Repaso completado!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tarjetas repasadas: ${widget.cards.length}'),
            const SizedBox(height: 4),
            Text('Aciertos: $_correct'),
            Text('Fallos: $_incorrect'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Volver'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Falladas · ${_currentIndex + 1} / ${widget.cards.length}',
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

class _FailedEmptyScreen extends StatelessWidget {
  const _FailedEmptyScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Repaso de falladas',
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
                  color: const Color(0xFF4FFFB0).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_outlined,
                  size: 56,
                  color: Color(0xFF4FFFB0),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Sin fallos recientes',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Sigue asi. Cuando falles una tarjeta en una sesion normal\n'
                'aparecera aqui para que la refuerces.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
