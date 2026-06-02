import 'package:flutter/material.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';

/// Muestra un diálogo de confirmación estándar y resuelve a `true` si el
/// usuario confirma o `false` si cancela / descarta el diálogo (tap fuera,
/// botón atrás). Centraliza el patrón repetido por toda la app (un
/// [AlertDialog] con botón cancelar + confirmar), respetando los tokens de
/// tema claro/oscuro vía `context.c` y la paleta de señal [DgtStatusColors].
///
/// - [title]: encabezado del diálogo (obligatorio).
/// - [message]: cuerpo explicativo opcional.
/// - [confirmLabel] / [cancelLabel]: textos de los botones.
/// - [destructive]: si es `true`, el botón de confirmar usa el color de
///   peligro ([DgtStatusColors.danger]) como [FilledButton] sólido para
///   acciones irreversibles (borrar, resetear). Si es `false`, el confirmar es
///   un [FilledButton] con el acento de marca.
///
/// Devuelve siempre un `bool` (nunca `null`), así que es seguro usarlo en un
/// `if` directo sin comprobar `== true`.
///
/// Ejemplo:
/// ```dart
/// final ok = await showConfirmationDialog(
///   context,
///   title: '¿Eliminar mazo?',
///   message: 'Se eliminará el mazo y todas sus tarjetas. '
///       'Esta acción no se puede deshacer.',
///   confirmLabel: 'Eliminar',
///   destructive: true,
/// );
/// if (!ok || !context.mounted) return;
/// await repo.deleteDeck(id);
/// ```
Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final confirmStyle = destructive
          ? FilledButton.styleFrom(backgroundColor: DgtStatusColors.danger)
          : FilledButton.styleFrom(backgroundColor: ctx.c.accent);
      return AlertDialog(
        backgroundColor: ctx.c.surfaceElevated,
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: confirmStyle,
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
