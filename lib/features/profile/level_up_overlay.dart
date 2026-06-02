import 'package:flutter/material.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';

/// Overlay tipo JRPG cuando el personaje sube de nivel.
/// Se muestra sobre la app entera durante ~2.4s y se cierra solo.
class LevelUpOverlay {
  static OverlayEntry? _current;

  static void show(BuildContext context, {required int newLevel, String? title}) {
    if (_current != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (_) => _LevelUpAnimated(
        newLevel: newLevel,
        title: title,
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

class _LevelUpAnimated extends StatefulWidget {
  final int newLevel;
  final String? title;
  final VoidCallback onDone;

  const _LevelUpAnimated({
    required this.newLevel,
    required this.title,
    required this.onDone,
  });

  @override
  State<_LevelUpAnimated> createState() => _LevelUpAnimatedState();
}

class _LevelUpAnimatedState extends State<_LevelUpAnimated>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
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
        // Fases:
        // 0..0.18 fade-in fondo
        // 0.18..0.45 zoom-in del badge "LEVEL UP"
        // 0.45..0.85 hold con shake/glow
        // 0.85..1 fade-out
        final bgOpacity = t < 0.18
            ? t / 0.18
            : t > 0.85
                ? 1 - (t - 0.85) / 0.15
                : 1.0;
        final scale = t < 0.45
            ? Curves.elasticOut.transform((t / 0.45).clamp(0.0, 1.0))
            : 1.0;
        final flashOpacity = t < 0.10
            ? t / 0.10
            : t < 0.25
                ? 1 - (t - 0.10) / 0.15
                : 0.0;

        return IgnorePointer(
          child: Stack(
            children: [
              // Fondo oscuro
              Opacity(
                opacity: bgOpacity * 0.85,
                child: Container(color: Colors.black),
              ),
              // Flash blanco inicial
              Opacity(
                opacity: flashOpacity,
                child: Container(color: Colors.white),
              ),
              // Rayos dorados de fondo (radial gradient)
              Opacity(
                opacity: bgOpacity,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.9,
                      colors: [
                        Color(0x66FFD24F),
                        Color(0x00000000),
                      ],
                    ),
                  ),
                ),
              ),
              // Contenido central
              Center(
                child: Opacity(
                  opacity: bgOpacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // "LEVEL UP" texto
                        ShaderMask(
                          shaderCallback: (rect) => const LinearGradient(
                            colors: [
                              DgtStatusColors.warningStrong,
                              DgtStatusColors.accentOrange,
                              DgtStatusColors.warningStrong,
                            ],
                          ).createShader(rect),
                          child: const Text(
                            'LEVEL UP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 6,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 18,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Lv badge gigante
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                DgtStatusColors.warningStrong,
                                DgtStatusColors.accentOrange,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: DgtStatusColors.warningStrong
                                    .withValues(alpha: 0.6),
                                blurRadius: 32,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            'Lv ${widget.newLevel}',
                            style: const TextStyle(
                              color: Color(0xFF1A1500),
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        if (widget.title != null) ...[
                          const SizedBox(height: 22),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: DgtStatusColors.warningStrong
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                            child: Text(
                              'Nuevo título: ${widget.title}',
                              style: const TextStyle(
                                color: DgtStatusColors.warningStrong,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
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
