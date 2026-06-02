import 'package:flutter/material.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';

import 'character_progress.dart';

/// Overlay JRPG cuando el personaje sube de rango en un mazo.
class TitleUnlockOverlay {
  static OverlayEntry? _current;

  static void show(
    BuildContext context, {
    required String deckName,
    required DeckRank newRank,
    Color accent = DgtStatusColors.warningStrong,
  }) {
    if (_current != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (_) => _Animated(
        deckName: deckName,
        rank: newRank,
        accent: accent,
        onDone: () {
          _current?.remove();
          _current = null;
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _Animated extends StatefulWidget {
  final String deckName;
  final DeckRank rank;
  final Color accent;
  final VoidCallback onDone;

  const _Animated({
    required this.deckName,
    required this.rank,
    required this.accent,
    required this.onDone,
  });

  @override
  State<_Animated> createState() => _AnimatedState();
}

class _AnimatedState extends State<_Animated>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) {
        final t = _ctrl.value;
        final bgOpacity = t < 0.15
            ? t / 0.15
            : t > 0.88
                ? 1 - (t - 0.88) / 0.12
                : 1.0;
        final scale = t < 0.4
            ? Curves.elasticOut.transform((t / 0.4).clamp(0.0, 1.0))
            : 1.0;
        final flashOpacity = t < 0.08
            ? t / 0.08
            : t < 0.2
                ? 1 - (t - 0.08) / 0.12
                : 0.0;

        return IgnorePointer(
          child: Stack(
            children: [
              Opacity(
                opacity: bgOpacity * 0.85,
                child: Container(color: Colors.black),
              ),
              Opacity(
                opacity: flashOpacity,
                child: Container(color: widget.accent),
              ),
              Opacity(
                opacity: bgOpacity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.9,
                      colors: [
                        widget.accent.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: bgOpacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.rank.emoji,
                            style: const TextStyle(fontSize: 84),
                          ),
                          const SizedBox(height: 12),
                          ShaderMask(
                            shaderCallback: (rect) => LinearGradient(
                              colors: [
                                widget.accent,
                                Colors.white,
                                widget.accent,
                              ],
                            ).createShader(rect),
                            child: const Text(
                              'TÍTULO DESBLOQUEADO',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 4,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 16,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  widget.accent,
                                  widget.accent.withValues(alpha: 0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      widget.accent.withValues(alpha: 0.6),
                                  blurRadius: 28,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  widget.rank.label.toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF1A1500),
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                                Text(
                                  'de ${widget.deckName}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF1A1500),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
