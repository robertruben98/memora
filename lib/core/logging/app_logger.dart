import 'dart:developer' as developer;

/// Niveles de severidad expuestos por [AppLogger].
///
/// Se mapean a los valores numericos que espera `dart:developer.log()`
/// siguiendo la convencion de `package:logging`.
enum AppLogLevel {
  debug(500, 'DEBUG'),
  info(800, 'INFO'),
  warn(900, 'WARN'),
  error(1000, 'ERROR');

  const AppLogLevel(this.value, this.label);

  /// Valor numerico usado por `dart:developer.log()`.
  final int value;

  /// Etiqueta legible.
  final String label;
}

/// Logger minimo y estructurado para toda la app.
///
/// Es el **unico** punto donde se emiten logs en codigo de produccion.
/// Si se necesita un nuevo destino (Sentry, archivo, remoto) este es
/// el lugar para anadirlo.
///
/// Reemplaza el uso de `print()`, que se pierde en release/profile builds
/// y no permite filtrar por tag/nivel. `dart:developer.log()` se entrega
/// al runtime de Dart y aparece en devtools/logcat con nivel correcto.
///
/// Uso tipico:
/// ```dart
/// appLogger.warn('sync', 'Sync failed', error: e, stackTrace: st);
/// ```
class AppLogger {
  const AppLogger();

  /// Emite un registro con [level] bajo [tag] y mensaje [message].
  ///
  /// [error] y [stackTrace] son opcionales y se pasan al runtime para
  /// que aparezcan formateados en herramientas de inspeccion.
  void log(
    AppLogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: tag,
      level: level.value,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void debug(String tag, String message,
          {Object? error, StackTrace? stackTrace}) =>
      log(AppLogLevel.debug, tag, message, error: error, stackTrace: stackTrace);

  void info(String tag, String message,
          {Object? error, StackTrace? stackTrace}) =>
      log(AppLogLevel.info, tag, message, error: error, stackTrace: stackTrace);

  void warn(String tag, String message,
          {Object? error, StackTrace? stackTrace}) =>
      log(AppLogLevel.warn, tag, message, error: error, stackTrace: stackTrace);

  void error(String tag, String message,
          {Object? error, StackTrace? stackTrace}) =>
      log(AppLogLevel.error, tag, message, error: error, stackTrace: stackTrace);
}

/// Instancia compartida del logger.
const AppLogger appLogger = AppLogger();
