import 'package:flutter/material.dart';

import 'package:memora/core/theme/app_colors.dart';

/// Título de sección reutilizable.
///
/// Pequeño encabezado usado para separar bloques dentro de pantallas tipo
/// lista (Ajustes, Ajustes DGT, Estadísticas). Centraliza el estilo que antes
/// vivía duplicado como `_SectionTitle` privado en cada pantalla.
///
/// Los parámetros permiten reproducir las variantes existentes sin cambiar el
/// aspecto: tamaño/peso de fuente, mayúsculas, interletraje, color, padding y
/// una barra de acento opcional (estilo del header de Perfil).
class SectionTitle extends StatelessWidget {
  /// Texto a mostrar. Se transforma a mayúsculas si [uppercase] es `true`.
  final String text;

  /// Convierte el texto a mayúsculas antes de renderizar.
  final bool uppercase;

  final double fontSize;
  final FontWeight fontWeight;
  final double? letterSpacing;

  /// Color del texto (y de la barra, si está presente). Si es `null`, usa
  /// `context.c.textMuted` del tema activo.
  final Color? color;

  /// Padding alrededor del título.
  final EdgeInsetsGeometry padding;

  /// Muestra una barra vertical de acento a la izquierda del texto (variante
  /// del header de Perfil). Usa [color] cuando está definido.
  final bool showAccentBar;

  const SectionTitle(
    this.text, {
    super.key,
    this.uppercase = true,
    this.fontSize = 11,
    this.fontWeight = FontWeight.w700,
    this.letterSpacing = 1.0,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 4),
    this.showAccentBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? context.c.textMuted;
    final label = Text(
      uppercase ? text.toUpperCase() : text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        color: effectiveColor,
      ),
    );

    if (!showAccentBar) {
      return Padding(padding: padding, child: label);
    }

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: effectiveColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          label,
        ],
      ),
    );
  }
}
