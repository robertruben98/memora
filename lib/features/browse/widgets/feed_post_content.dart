import 'package:flutter/material.dart';

import '../../../core/models/memora_card.dart';
import '../../../core/widgets/memora_image.dart';

/// Cuerpo de la tarjeta del feed: alterna entre la pregunta y la
/// respuesta usando un `AnimatedSwitcher` envuelto en `AnimatedSize`.
class FeedPostContent extends StatelessWidget {
  final MemoraCard card;
  final bool revealed;
  final String? frontImagePath;
  final String? backImagePath;

  const FeedPostContent({
    super.key,
    required this.card,
    required this.revealed,
    required this.frontImagePath,
    required this.backImagePath,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: child,
        ),
        child: !revealed
            ? _QuestionBlock(
                key: const ValueKey('question'),
                card: card,
                frontImagePath: frontImagePath,
              )
            : _AnswerBlock(
                key: const ValueKey('answer'),
                card: card,
                backImagePath: backImagePath,
                frontImagePath: frontImagePath,
              ),
      ),
    );
  }
}

class _QuestionBlock extends StatelessWidget {
  final MemoraCard card;
  final String? frontImagePath;

  const _QuestionBlock({
    super.key,
    required this.card,
    required this.frontImagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (frontImagePath != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: MemoraImage(path: frontImagePath!, height: 220),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                color: Colors.white,
              ),
              children: [
                TextSpan(
                  text: card.deck,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const TextSpan(text: '  '),
                TextSpan(text: card.front),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AnswerBlock extends StatelessWidget {
  final MemoraCard card;
  final String? frontImagePath;
  final String? backImagePath;

  const _AnswerBlock({
    super.key,
    required this.card,
    required this.frontImagePath,
    required this.backImagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (frontImagePath != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: MemoraImage(path: frontImagePath!, height: 220),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.65),
              ),
              children: [
                TextSpan(
                  text: card.deck,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const TextSpan(text: '  '),
                TextSpan(text: card.front),
              ],
            ),
          ),
        ),
        if (backImagePath != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: MemoraImage(path: backImagePath!, height: 200),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
          child: Text(
            card.back,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.45,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
