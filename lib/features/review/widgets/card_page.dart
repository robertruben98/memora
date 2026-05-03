import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/memora_card.dart';

class CardPage extends StatefulWidget {
  final MemoraCard card;
  final VoidCallback onCorrect;
  final VoidCallback onIncorrect;

  const CardPage({
    super.key,
    required this.card,
    required this.onCorrect,
    required this.onIncorrect,
  });

  @override
  State<CardPage> createState() => _CardPageState();
}

class _CardPageState extends State<CardPage> {
  bool _revealed = false;

  void _reveal() {
    if (_revealed) return;
    HapticFeedback.lightImpact();
    setState(() => _revealed = true);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _reveal,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
          _reveal();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          children: [
            _DeckBadge(
              name: widget.card.deck,
              color: widget.card.deckColor,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                child: _revealed
                    ? _AnsweredView(
                        key: const ValueKey('answered'),
                        front: widget.card.front,
                        back: widget.card.back,
                      )
                    : _QuestionView(
                        key: const ValueKey('question'),
                        front: widget.card.front,
                      ),
              ),
            ),
            AnimatedCrossFade(
              crossFadeState: _revealed
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
              firstChild: const _RevealHint(),
              secondChild: _AnswerButtons(
                onCorrect: widget.onCorrect,
                onIncorrect: widget.onIncorrect,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckBadge extends StatelessWidget {
  final String name;
  final Color color;

  const _DeckBadge({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Text(
          name,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _QuestionView extends StatelessWidget {
  final String front;
  const _QuestionView({super.key, required this.front});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        front,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          height: 1.3,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

class _AnsweredView extends StatelessWidget {
  final String front;
  final String back;
  const _AnsweredView({
    super.key,
    required this.front,
    required this.back,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          front,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.7),
            height: 1.3,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          height: 1,
          color: Colors.white.withValues(alpha: 0.1),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Text(
                back,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RevealHint extends StatelessWidget {
  const _RevealHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(
            Icons.touch_app_rounded,
            color: Colors.white.withValues(alpha: 0.4),
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            'Toca o desliza para ver la respuesta',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerButtons extends StatelessWidget {
  final VoidCallback onCorrect;
  final VoidCallback onIncorrect;

  const _AnswerButtons({
    required this.onCorrect,
    required this.onIncorrect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BigButton(
            label: 'No acerté',
            icon: Icons.close_rounded,
            color: const Color(0xFFFF4F6B),
            onPressed: onIncorrect,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BigButton(
            label: 'Acerté',
            icon: Icons.check_rounded,
            color: const Color(0xFF4FFFB0),
            onPressed: onCorrect,
          ),
        ),
      ],
    );
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _BigButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
