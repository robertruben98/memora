import 'package:flutter/material.dart';
import 'package:memora/core/theme/app_colors.dart';

/// Etiqueta de campo reutilizable usada por los editores (mazos/tarjetas).
///
/// Centraliza el estilo repetido de los labels de formulario para mantener
/// un aspecto consistente y evitar duplicación (DRY).
class AppLabel extends StatelessWidget {
  final String text;

  const AppLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.c.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}

/// Campo de texto reutilizable con la decoración estándar de la app.
///
/// Replica el patrón de `_decor` del login (fill + bordes redondeados +
/// borde `AppColors.brand` al enfocar) usando tokens de tema (`context.c.*`).
/// Sustituye a los antiguos `_Field`/`_EditorField` duplicados en los editores.
class StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int minLines;

  /// Número máximo de líneas. Si es `null` se calcula a partir de [minLines]
  /// (1 línea -> campo de una línea; varias -> hasta 4).
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final TextStyle? style;

  /// Tipo de teclado (p. ej. [TextInputType.emailAddress]).
  final TextInputType? keyboardType;

  /// Oculta el texto introducido (campos de contraseña).
  final bool obscureText;

  /// Acción del botón de envío del teclado (p. ej. [TextInputAction.next]).
  final TextInputAction? textInputAction;

  /// Callback al enviar desde el teclado.
  final ValueChanged<String>? onSubmitted;

  /// Si se indica, se usa como label flotante ([InputDecoration.labelText])
  /// en lugar del [hint]. Si es `null` se mantiene el comportamiento actual
  /// (solo hint).
  final String? label;

  /// Capitalización del texto. Si es `null` se mantiene el comportamiento
  /// actual ([TextCapitalization.sentences]); permite no forzar mayúsculas
  /// en campos como el email.
  final TextCapitalization? textCapitalization;

  const StyledTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.minLines = 1,
    this.maxLines,
    this.onChanged,
    this.style,
    this.keyboardType,
    this.obscureText = false,
    this.textInputAction,
    this.onSubmitted,
    this.label,
    this.textCapitalization,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines ?? (minLines == 1 ? 1 : 4),
      textCapitalization: textCapitalization ?? TextCapitalization.sentences,
      style: style ?? const TextStyle(fontSize: 16),
      onChanged: onChanged,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: context.c.textMuted),
        filled: true,
        fillColor: context.c.surfaceElevated,
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.c.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
      ),
    );
  }
}
