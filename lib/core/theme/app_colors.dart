import 'package:flutter/material.dart';

/// Tokens de color semánticos que se adaptan a modo claro/oscuro.
///
/// La app fue diseñada dark-first con colores hardcoded (`Colors.white`,
/// `Color(0xFF0E0E12)`, etc.). Para soportar modo claro sin reescribir cada
/// widget con `Theme.of(context)`, centralizamos la paleta aquí como
/// [ThemeExtension] y exponemos un acceso corto vía `context.c`.
///
/// Mapeo de los literales dark originales a tokens:
///   Color(0xFF0E0E12)                       -> surface        (fondo de página)
///   Color(0xFF1A1A22)/0xFF121218            -> surfaceElevated (cards/sheets)
///   Colors.white.withValues(alpha:.04-.10)  -> surfaceMuted    (fills sutiles)
///   Colors.white.withValues(alpha:.12-.30)  -> border          (bordes/divisores)
///   Colors.white                            -> textPrimary
///   Colors.white.withValues(alpha:.6-.75)   -> textSecondary
///   Colors.white.withValues(alpha:.4-.55)   -> textMuted
///   Color(0xFF7C5CFF)                        -> accent          (marca, igual en ambos)
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.shadow,
    required this.achievementUnlocked,
  });

  final Color surface;
  final Color surfaceElevated;
  final Color surfaceMuted;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color onAccent;
  final Color shadow;

  /// Color oro para logros desbloqueados, idéntico en ambos modos.
  final Color achievementUnlocked;

  /// Color de marca, idéntico en ambos modos.
  static const Color brand = Color(0xFF7C5CFF);

  static const AppColors dark = AppColors(
    surface: Color(0xFF0E0E12),
    surfaceElevated: Color(0xFF1A1A22),
    surfaceMuted: Color(0x14FFFFFF), // white @ 8%
    border: Color(0x29FFFFFF), // white @ 16%
    textPrimary: Colors.white,
    textSecondary: Color(0xB3FFFFFF), // white @ 70%
    textMuted: Color(0x80FFFFFF), // white @ 50%
    accent: brand,
    onAccent: Colors.white,
    shadow: Color(0x66000000),
    achievementUnlocked: Color(0xFFFFB74F),
  );

  static const AppColors light = AppColors(
    surface: Color(0xFFF7F6FB),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceMuted: Color(0x0A000000), // black @ 4%
    border: Color(0x1F000000), // black @ 12%
    textPrimary: Color(0xFF1A1A22),
    textSecondary: Color(0xD41A1A22), // ink @ 83% (WCAG AA 4.5:1 sobre surface)
    textMuted: Color(0x991A1A22), // ink @ 60%
    accent: brand,
    onAccent: Colors.white,
    shadow: Color(0x1F000000),
    achievementUnlocked: Color(0xFFFFB74F),
  );

  @override
  AppColors copyWith({
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceMuted,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? onAccent,
    Color? shadow,
    Color? achievementUnlocked,
  }) {
    return AppColors(
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      shadow: shadow ?? this.shadow,
      achievementUnlocked: achievementUnlocked ?? this.achievementUnlocked,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      achievementUnlocked:
          Color.lerp(achievementUnlocked, other.achievementUnlocked, t)!,
    );
  }
}

/// Acceso corto a los tokens: `context.c.textPrimary`.
extension AppColorsContext on BuildContext {
  AppColors get c =>
      Theme.of(this).extension<AppColors>() ?? AppColors.dark;
}
