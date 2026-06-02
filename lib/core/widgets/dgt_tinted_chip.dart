import 'package:flutter/material.dart';

/// Pill/badge tintado reutilizable para la UI DGT de RutaB.
///
/// Centraliza el patron repetido en muchas pantallas DGT: un `Container` con
/// un unico color de fondo tintado (`color.withValues(alpha: bgAlpha)`),
/// borde tintado opcional, padding, `borderRadius` (pill por defecto) y un
/// contenido formado por icono y/o texto. Sustituye widgets ad-hoc como
/// `_BucketChip`, `_IntroBreakdownRow`, `_BucketSummaryRow` o los badges
/// inline de `DgtTile`.
///
/// Fuera de alcance a proposito: este widget NO cubre fondos con gradiente ni
/// `BoxShadow` (p. ej. la variante "hero" de `DgtTile`). Para esos casos sigue
/// usandose un `Container`/`Ink` dedicado.
///
/// El color del icono y del texto deriva de [color] por defecto, lo que
/// produce el aspecto "tintado monocromo" tipico de los chips de estado. Si
/// necesitas otro color de texto, pasa [textStyle] con `color` explicito.
///
/// Ejemplo:
/// ```dart
/// DgtTintedChip(
///   color: DgtStatusColors.error,
///   icon: const Icon(Icons.gps_fixed_rounded, size: 14),
///   label: 'Tema mas debil',
///   borderAlpha: 0.5,
/// )
/// ```
class DgtTintedChip extends StatelessWidget {
  /// Color base del que se derivan fondo, borde, icono y texto.
  final Color color;

  /// Texto del chip. Ignorado si se pasa [child].
  final String? label;

  /// Contenido custom que reemplaza por completo a [label]/[icon] cuando se
  /// provee (p. ej. un `Row` propio). Si es null se construye el contenido a
  /// partir de [icon] + [label].
  final Widget? child;

  /// Icono opcional mostrado antes del [label]. Su color, si no esta fijado,
  /// se hereda de [color] via `IconTheme`. Pasa el `size` deseado al `Icon`.
  final Widget? icon;

  /// Opacidad del color de fondo. Defecto `0.12`.
  final double bgAlpha;

  /// Opacidad del borde tintado. `null` (defecto) = sin borde.
  final double? borderAlpha;

  /// Padding interior. Defecto `EdgeInsets.symmetric(horizontal: 10, vertical: 6)`.
  final EdgeInsetsGeometry padding;

  /// Radio de las esquinas. Defecto `999` (pill).
  final double radius;

  /// Estilo del texto del [label]. Se mezcla sobre un base
  /// (`fontWeight.w800`, color = [color]); cualquier campo que fijes aqui
  /// tiene prioridad. Ignorado si se usa [child].
  final TextStyle? textStyle;

  /// Separacion horizontal entre [icon] y [label]. Defecto `6`.
  final double gap;

  const DgtTintedChip({
    super.key,
    required this.color,
    this.label,
    this.child,
    this.icon,
    this.bgAlpha = 0.12,
    this.borderAlpha,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.radius = 999,
    this.textStyle,
    this.gap = 6,
  }) : assert(
          label != null || child != null || icon != null,
          'DgtTintedChip needs at least one of: label, child or icon',
        );

  @override
  Widget build(BuildContext context) {
    final Widget content = child ?? _buildDefaultContent();

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(radius),
        border: borderAlpha == null
            ? null
            : Border.all(color: color.withValues(alpha: borderAlpha!)),
      ),
      child: content,
    );
  }

  Widget _buildDefaultContent() {
    final baseStyle = TextStyle(
      fontWeight: FontWeight.w800,
      color: color,
    );
    final mergedStyle =
        textStyle == null ? baseStyle : baseStyle.merge(textStyle);

    final hasIcon = icon != null;
    final hasLabel = label != null;

    if (hasIcon && !hasLabel) {
      return IconTheme.merge(
        data: IconThemeData(color: color),
        child: icon!,
      );
    }

    if (!hasIcon && hasLabel) {
      return Text(label!, style: mergedStyle);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconTheme.merge(
          data: IconThemeData(color: color),
          child: icon!,
        ),
        SizedBox(width: gap),
        Flexible(
          child: Text(
            label!,
            style: mergedStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
