import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/memora_card.dart';
import '../../../core/theme/deck_visuals.dart';
import '../../../data/repositories/card_repository.dart';
import '../../../data/repositories/deck_repository.dart';
import '../../../data/repositories/review_repository.dart';
import '../../../data/storage/image_storage.dart';
import '../../review/study_queue.dart';
import '../../stats/stats_repository.dart';

/// Tarjeta tipo "post de Instagram" para el feed scrollable.
class FeedPostCard extends ConsumerStatefulWidget {
  final MemoraCard card;

  const FeedPostCard({super.key, required this.card});

  @override
  ConsumerState<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends ConsumerState<FeedPostCard> {
  bool _revealed = false;
  bool _answered = false;
  bool? _wasCorrect;
  bool _saving = false;

  void _reveal() {
    if (_revealed) return;
    HapticFeedback.lightImpact();
    setState(() => _revealed = true);
  }

  Future<void> _answer(bool correct) async {
    if (_answered || _saving) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _saving = true;
      _wasCorrect = correct;
    });
    await ref.read(reviewRepositoryProvider).recordReview(
          cardId: widget.card.id,
          correct: correct,
          now: DateTime.now(),
        );
    if (!mounted) return;
    ref.invalidate(deckSummariesProvider);
    ref.invalidate(allCardsProvider);
    ref.invalidate(studyQueueProvider(null));
    ref.invalidate(statsSnapshotProvider);
    setState(() {
      _answered = true;
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    final storage = ref.watch(imageStorageProvider);
    final frontImg = c.frontImagePath;
    final backImg = c.backImagePath;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: c.deckColor.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(card: c),
          if (!_revealed)
            _QuestionBlock(card: c, frontImagePath: frontImg, storage: storage)
          else
            _AnswerBlock(
              card: c,
              backImagePath: backImg,
              frontImagePath: frontImg,
              storage: storage,
            ),
          _Footer(
            revealed: _revealed,
            answered: _answered,
            wasCorrect: _wasCorrect,
            saving: _saving,
            onReveal: _reveal,
            onCorrect: () => _answer(true),
            onIncorrect: () => _answer(false),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final MemoraCard card;
  const _Header({required this.card});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: card.deckColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: card.deckColor.withValues(alpha: 0.45),
                width: 1,
              ),
            ),
            child: Icon(
              DeckVisuals.iconFor(_iconForDeckName(card.deck)),
              color: card.deckColor,
              size: 18,
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
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: card.deckColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Tarjeta',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Heurística: el icono real está en la BD pero MemoraCard no lo expone aún.
  // Usamos el icon por defecto del DeckVisuals fallback.
  String _iconForDeckName(String _) => 'style_rounded';
}

class _QuestionBlock extends StatelessWidget {
  final MemoraCard card;
  final String? frontImagePath;
  final ImageStorage storage;

  const _QuestionBlock({
    required this.card,
    required this.frontImagePath,
    required this.storage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (frontImagePath != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(storage.absolutePathFor(frontImagePath!)),
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
          child: Text(
            card.front,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.35,
              letterSpacing: -0.2,
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
  final ImageStorage storage;

  const _AnswerBlock({
    required this.card,
    required this.frontImagePath,
    required this.backImagePath,
    required this.storage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (frontImagePath != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(storage.absolutePathFor(frontImagePath!)),
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
          child: Text(
            card.front,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 10),
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        if (backImagePath != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(storage.absolutePathFor(backImagePath!)),
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
          child: Text(
            card.back,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  final bool revealed;
  final bool answered;
  final bool? wasCorrect;
  final bool saving;
  final VoidCallback onReveal;
  final VoidCallback onCorrect;
  final VoidCallback onIncorrect;

  const _Footer({
    required this.revealed,
    required this.answered,
    required this.wasCorrect,
    required this.saving,
    required this.onReveal,
    required this.onCorrect,
    required this.onIncorrect,
  });

  @override
  Widget build(BuildContext context) {
    if (answered) {
      final ok = wasCorrect == true;
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: (ok ? const Color(0xFF4FFFB0) : const Color(0xFFFF4F6B))
                .withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: ok
                    ? const Color(0xFF4FFFB0)
                    : const Color(0xFFFF4F6B),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                ok ? 'Marcada como acertada' : 'Marcada como fallada',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ok
                      ? const Color(0xFF4FFFB0)
                      : const Color(0xFFFF4F6B),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (!revealed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
        child: Material(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onReveal,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.visibility_rounded,
                    size: 17,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ver respuesta',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: _SmallButton(
              label: 'No acerté',
              icon: Icons.close_rounded,
              color: const Color(0xFFFF4F6B),
              onPressed: saving ? null : onIncorrect,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SmallButton(
              label: 'Acerté',
              icon: Icons.check_rounded,
              color: const Color(0xFF4FFFB0),
              onPressed: saving ? null : onCorrect,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _SmallButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border:
                Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
