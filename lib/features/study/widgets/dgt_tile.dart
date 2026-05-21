import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dgt_tile_spec.dart';

/// Issue #148 (dgt-tech): widget reusable que renderiza un `DgtTileSpec`.
///
/// Reemplaza los 8 widgets `_DgtXxxTile` individuales que vivian inline en
/// `dgt_section.dart` (785 LOC -> ~150 LOC). Las 3 variantes visuales
/// (hero/primary/standard) replican EXACTAMENTE el styling previo para que
/// el QA no detecte regresion visual.
class DgtTile extends ConsumerWidget {
  final DgtTileSpec spec;

  const DgtTile({super.key, required this.spec});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = spec.subtitleBuilder(ref);
    final badge = spec.badgeBuilder?.call(ref);

    switch (spec.variant) {
      case DgtTileVariant.hero:
        return _buildHero(context, subtitle);
      case DgtTileVariant.primary:
        return _buildPrimary(context, subtitle);
      case DgtTileVariant.standard:
        return _buildStandard(context, subtitle, badge);
    }
  }

  void _onTap(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: spec.routeBuilder),
    );
  }

  /// Variante "hero": gradiente + sombra. Estilo del Simulacro DGT.
  Widget _buildHero(BuildContext context, String subtitle) {
    final gradientEnd = spec.gradientEndColor ?? _lighten(spec.accentColor, 0.15);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onTap(context),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [spec.accentColor, gradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: spec.accentColor.withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  spec.icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Variante "primary": border accent + tamano mediano (44x44 icon).
  Widget _buildPrimary(BuildContext context, String subtitle) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onTap(context),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: spec.accentColor.withValues(alpha: 0.45),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: spec.accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  spec.icon,
                  color: spec.primaryIconColor ?? _lighten(spec.accentColor, 0.25),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Variante "standard": border accent + tamano compacto (36x36 icon).
  /// Acepta badge opcional al lado del titulo.
  Widget _buildStandard(
    BuildContext context,
    String subtitle,
    DgtTileBadge? badge,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onTap(context),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: spec.accentColor.withValues(alpha: 0.4),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: spec.accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  spec.icon,
                  color: spec.accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    badge == null
                        ? Text(
                            spec.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          )
                        : Row(
                            children: [
                              Flexible(
                                child: Text(
                                  spec.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: badge.color.withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  badge.text,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: badge.color,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Aclara un color hacia blanco con un factor [0..1]. Util para hero
  /// gradient (de accent a accent-claro) y primary icon (icon mas claro
  /// que el border accent).
  Color _lighten(Color color, double factor) {
    assert(factor >= 0 && factor <= 1);
    final r = (color.r * 255).round();
    final g = (color.g * 255).round();
    final b = (color.b * 255).round();
    final a = color.a;
    return Color.fromARGB(
      (a * 255).round(),
      r + ((255 - r) * factor).round(),
      g + ((255 - g) * factor).round(),
      b + ((255 - b) * factor).round(),
    );
  }
}
