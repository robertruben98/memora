import 'package:flutter/material.dart';

import 'package:memora/core/theme/dgt_status_colors.dart';

/// Banner de error reutilizable con el aspecto tintado [DgtStatusColors.danger].
///
/// Replica el contenedor de error que estaba inline en `login_screen.dart`:
/// fondo `danger` al 12% de opacidad, esquinas redondeadas y texto en `danger`.
/// Centraliza ese patrón (DRY) para que cualquier pantalla muestre errores con
/// idéntico aspecto.
///
/// Si se pasa [onDismiss], se añade un icono de cerrar a la derecha que lo
/// invoca (útil para que el usuario descarte el mensaje).
///
/// Ejemplo:
/// ```dart
/// if (_error != null)
///   ErrorAlert(
///     _error!,
///     onDismiss: () => setState(() => _error = null),
///   ),
/// ```
class ErrorAlert extends StatelessWidget {
  /// Mensaje de error a mostrar.
  final String message;

  /// Si no es null, muestra un botón de cierre que lo invoca al pulsarlo.
  final VoidCallback? onDismiss;

  const ErrorAlert(this.message, {super.key, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: DgtStatusColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: DgtStatusColors.danger,
                fontSize: 13,
              ),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onDismiss,
              borderRadius: BorderRadius.circular(16),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: DgtStatusColors.danger,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
