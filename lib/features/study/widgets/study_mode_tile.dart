import 'package:flutter/material.dart';

/// Reusable tile for the StudyHub screen.
///
/// Used by failed/marked review tiles and learn-methods tile. Provides a
/// consistent dark card with accent border, leading icon (or emoji), title,
/// subtitle, optional trailing badge (count) and a chevron when no badge.
///
/// Aditivo: NO altera comportamiento existente. Reemplaza tiles inline en
/// `study_hub_screen.dart` con misma estructura visual (mismo padding,
/// radios, paleta de colores, tipografias).
class StudyModeTile extends StatelessWidget {
  final VoidCallback onTap;
  final Color accentColor;
  final IconData? leadingIcon;
  final String? leadingEmoji;
  final String title;
  final String subtitle;
  final int? badgeCount;
  final Color? badgeColor;
  final Color? badgeTextColor;

  const StudyModeTile({
    super.key,
    required this.onTap,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    this.leadingIcon,
    this.leadingEmoji,
    this.badgeCount,
    this.badgeColor,
    this.badgeTextColor,
  }) : assert(
          leadingIcon != null || leadingEmoji != null,
          'Must provide either leadingIcon or leadingEmoji',
        );

  @override
  Widget build(BuildContext context) {
    final hasBadge = badgeCount != null && badgeCount! > 0;
    final borderAlpha = hasBadge ? 0.45 : 0.08;
    final borderColor = hasBadge
        ? accentColor.withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.08);

    // Issue #191 (dgt-tech): a11y. Label descriptivo para TalkBack / VoiceOver.
    // Si hay badge con count, anunciarlo via `value`.
    final semanticLabel = '$title. $subtitle. Pulsa para abrir';
    final semanticValue = hasBadge ? '$badgeCount pendientes' : null;

    return Semantics(
      label: semanticLabel,
      value: semanticValue,
      button: true,
      container: true,
      excludeSemantics: true,
      child: Material(
      color: Colors.transparent,
      child: Tooltip(
        message: '$title. $subtitle',
        child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: borderAlpha == 0.45 ? 1 : 1),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: leadingIcon != null
                    ? Icon(leadingIcon, color: accentColor, size: 24)
                    : Text(leadingEmoji!, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
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
              if (hasBadge)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor ?? accentColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: badgeTextColor ?? Colors.white,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
            ],
          ),
        ),
      ),
      ),
      ),
    );
  }
}
