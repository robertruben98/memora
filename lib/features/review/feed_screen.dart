import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/memora_card.dart';
import 'feed_session_notifier.dart';
import 'widgets/card_page.dart';

class FeedScreen extends ConsumerStatefulWidget {
  final List<MemoraCard> cards;

  const FeedScreen({super.key, required this.cards});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _controller = PageController();
  bool _completionShown = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onAnswer(BuildContext context, {required bool correct}) {
    HapticFeedback.mediumImpact();
    final notifier = ref.read(feedSessionProvider(widget.cards).notifier);
    notifier.registerAnswer(correct: correct);

    final state = ref.read(feedSessionProvider(widget.cards));
    if (state.isCompleted) {
      _showCompletion(context, state);
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showCompletion(BuildContext context, FeedSessionState state) {
    if (_completionShown) return;
    _completionShown = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A22),
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
    final state = ref.watch(feedSessionProvider(widget.cards));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '${state.currentIndex + 1} / ${state.cards.length}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        itemCount: state.cards.length,
        onPageChanged: (i) {
          ref
              .read(feedSessionProvider(widget.cards).notifier)
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
