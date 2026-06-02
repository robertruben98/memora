import 'package:flutter/material.dart';

import 'package:memora/core/theme/app_colors.dart';

/// Card reutilizable con cabecera "icono + titulo" tintada y un cuerpo debajo.
///
/// Centraliza el patron extraido de `dgt_subtopic_tutorial_screen.dart`
/// (antes la clase privada `_Section`): un `Container` con fondo
/// `surfaceMuted`, borde tintado con [accent], esquinas redondeadas y una
/// columna formada por una fila de cabecera (icono + titulo en color [accent])
/// y el contenido del cuerpo.
///
/// El cuerpo se provee como texto via [body] o como widget arbitrario via
/// [child]. Debe pasarse exactamente uno de los dos.
///
/// Ejemplo:
/// ```dart
/// CardWithIconHeader(
///   title: 'Concepto clave',
///   body: tutorial.concept,
///   accent: AppColors.brand,
///   icon: Icons.lightbulb_outline_rounded,
/// )
/// ```
class CardWithIconHeader extends StatelessWidget {
  /// Icono mostrado en la cabecera, tintado con [accent].
  final IconData icon;

  /// Titulo de la cabecera, en color [accent].
  final String title;

  /// Color base del que derivan borde, icono y titulo.
  final Color accent;

  /// Texto del cuerpo. Ignorado si se pasa [child].
  final String? body;

  /// Contenido custom del cuerpo. Tiene prioridad sobre [body].
  final Widget? child;

  const CardWithIconHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.accent,
    this.body,
    this.child,
  }) : assert(
          body != null || child != null,
          'CardWithIconHeader needs either body or child',
        );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: context.c.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child ??
              Text(
                body!,
                style: const TextStyle(fontSize: 14.5, height: 1.4),
              ),
        ],
      ),
    );
  }
}
