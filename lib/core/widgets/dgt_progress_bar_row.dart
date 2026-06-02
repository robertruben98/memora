import 'package:flutter/material.dart';
import 'package:memora/core/theme/app_colors.dart';

/// Fila de progreso reutilizable: `[label] [barra] [valor/porcentaje]`.
///
/// Unifica el patron `_BarRow` duplicado en las pantallas DGT (estadisticas
/// por tema, comparativa de cohorte): una etiqueta, una [LinearProgressIndicator]
/// y un texto opcional al final (porcentaje, fraccion, delta, etc).
///
/// Usa tokens de tema ([AppColors] via `context.c`) para fondo de la barra y
/// colores de texto, de modo que respeta modo claro/oscuro automaticamente. El
/// color de relleno de la barra se controla con [color]; si es null cae al
/// `accent` del tema.
///
/// ## Dos disposiciones
///
/// - **Inline** (por defecto, `labelFixedWidth: false`): la etiqueta toma su
///   ancho natural, la barra ocupa el espacio restante y el trailing se ajusta
///   a su contenido. Pensado para layouts apilados (la etiqueta + trailing en
///   su propia fila no es necesaria; aqui todo va en una sola linea).
/// - **Columnas fijas** (`labelFixedWidth: true`): la etiqueta y el trailing
///   reservan un ancho fijo ([labelWidth] / [trailingWidth]) y la barra ocupa
///   el centro. Util para alinear varias filas paralelas (p.ej. "Tu" vs
///   "Media" en la comparativa de cohorte), donde las barras deben empezar y
///   terminar exactamente en la misma columna.
///
/// El [value] siempre se interpreta en rango 0..1 y se hace clamp internamente,
/// asi que valores fuera de rango (negativos o > 1) no rompen el render.
///
/// ## Ejemplo
///
/// ```dart
/// // Inline, con fraccion de aciertos como trailing.
/// DgtProgressBarRow(
///   label: 'Accuracy',
///   value: 0.82, // 82%
///   trailing: '41/50',
///   color: DgtStatusColors.success,
/// )
///
/// // Columnas fijas para alinear barras paralelas usuario vs media.
/// DgtProgressBarRow(
///   label: 'Tu',
///   value: userPct / 100.0,
///   trailing: '${userPct.toStringAsFixed(0)}%',
///   labelFixedWidth: true,
///   labelWidth: 48,
///   trailingWidth: 54,
///   color: DgtStatusColors.info,
///   barHeight: 8,
/// )
/// ```
class DgtProgressBarRow extends StatelessWidget {
  /// Etiqueta a la izquierda de la barra (p.ej. "Accuracy", "Tu", "Media").
  final String label;

  /// Progreso en rango 0..1. Se hace clamp internamente a `[0, 1]`.
  final double value;

  /// Texto opcional al final de la fila (porcentaje, fraccion, delta...).
  /// Si es null no se reserva espacio para el.
  final String? trailing;

  /// Si `true`, la etiqueta y el trailing usan anchos fijos ([labelWidth] /
  /// [trailingWidth]) para alinear barras de filas paralelas. Si `false`
  /// (por defecto), ambos toman su ancho natural.
  final bool labelFixedWidth;

  /// Ancho fijo de la etiqueta cuando [labelFixedWidth] es `true`.
  /// Ignorado si [labelFixedWidth] es `false`. Por defecto 48.
  final double? labelWidth;

  /// Ancho fijo del trailing cuando [labelFixedWidth] es `true`.
  /// Ignorado si [labelFixedWidth] es `false` o [trailing] es null.
  /// Por defecto 54.
  final double? trailingWidth;

  /// Color de relleno de la barra. Si es null usa el `accent` del tema.
  final Color? color;

  /// Alto (minHeight) de la barra. Por defecto 8.
  final double barHeight;

  const DgtProgressBarRow({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
    this.labelFixedWidth = false,
    this.labelWidth,
    this.trailingWidth,
    this.color,
    this.barHeight = 8,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    final barColor = color ?? colors.accent;
    final clamped = value.clamp(0.0, 1.0);

    final labelWidget = Text(
      label,
      style: TextStyle(
        color: colors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: clamped,
        minHeight: barHeight,
        backgroundColor: colors.surfaceMuted,
        valueColor: AlwaysStoppedAnimation<Color>(barColor),
      ),
    );

    final trailingText = trailing;
    final trailingWidget = trailingText == null
        ? null
        : Text(
            trailingText,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          );

    return Row(
      children: [
        if (labelFixedWidth)
          SizedBox(width: labelWidth ?? 48, child: labelWidget)
        else
          labelWidget,
        const SizedBox(width: 10),
        Expanded(child: bar),
        if (trailingWidget != null) ...[
          const SizedBox(width: 10),
          if (labelFixedWidth)
            SizedBox(width: trailingWidth ?? 54, child: trailingWidget)
          else
            trailingWidget,
        ],
      ],
    );
  }
}
