import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Vista de estado reutilizable (carga / error / vacío) con tokens [AppColors].
///
/// Centraliza los estados repetidos por toda la app (antes cada pantalla
/// repetía `Center(child: Text('Error: $e'))` y spinners sueltos). Usa los
/// constructores `AppStateView.loading` / `.error` / `.empty`.
class AppStateView extends StatelessWidget {
  const AppStateView({
    super.key,
    this.icon,
    this.title,
    this.message,
    this.onRetry,
    this.retryLabel = 'Reintentar',
    this.loading = false,
  });

  final IconData? icon;
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final bool loading;

  /// Spinner centrado, con mensaje opcional.
  factory AppStateView.loading({String? message}) =>
      AppStateView(loading: true, message: message);

  /// Estado de error con icono, título y botón opcional de reintento.
  factory AppStateView.error(Object error, {VoidCallback? onRetry}) =>
      AppStateView(
        icon: Icons.error_outline_rounded,
        title: 'Algo salió mal',
        message: error.toString(),
        onRetry: onRetry,
      );

  /// Estado vacío con icono, título, mensaje y CTA opcional.
  factory AppStateView.empty({
    required IconData icon,
    required String title,
    String? message,
    VoidCallback? onRetry,
    String retryLabel = 'Reintentar',
  }) =>
      AppStateView(
        icon: icon,
        title: title,
        message: message,
        onRetry: onRetry,
        retryLabel: retryLabel,
      );

  @override
  Widget build(BuildContext context) {
    if (loading) {
      final loadingLabel = message ?? 'Cargando';
      return Semantics(
        label: loadingLabel,
        liveRegion: true,
        container: true,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.c.textSecondary),
                ),
              ],
            ],
          ),
        ),
      );
    }
    final stateLabel =
        [title, message].whereType<String>().join('. ');
    return Semantics(
      label: stateLabel.isEmpty ? null : stateLabel,
      container: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Icon(icon, size: 48, color: context.c.textMuted),
              if (title != null) ...[
                const SizedBox(height: 16),
                Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: context.c.textPrimary,
                  ),
                ),
              ],
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: context.c.textSecondary),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                FilledButton.tonal(onPressed: onRetry, child: Text(retryLabel)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
