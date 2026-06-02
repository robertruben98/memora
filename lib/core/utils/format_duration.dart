/// Utilidades para formatear duraciones de tiempo (timers DGT, etc.).
///
/// Centraliza el formateo `MM:SS` que estaba duplicado en
/// `dgt_sprint_screen.dart` y `dgt_exam_screen.dart`.
library;

/// Formatea una cantidad total de segundos como `MM:SS`.
///
/// Tanto los minutos como los segundos se rellenan con cero a la izquierda
/// hasta 2 digitos (`padLeft(2, '0')`). Coincide exactamente con el formato
/// usado en los timers DGT existentes.
///
/// Los minutos NO tienen tope: para duraciones de una hora o mas, los minutos
/// siguen creciendo (p. ej. `3700s` -> `'61:40'`). Si necesitas horas como
/// segmento separado usa [formatHmsOrMmSs].
///
/// Valores negativos se tratan como `0`.
///
/// Ejemplos:
/// ```dart
/// formatMmSs(0);    // '00:00'
/// formatMmSs(5);    // '00:05'
/// formatMmSs(65);   // '01:05'
/// formatMmSs(600);  // '10:00'
/// formatMmSs(3599); // '59:59'
/// formatMmSs(3700); // '61:40'  (los minutos no se acotan)
/// formatMmSs(-10);  // '00:00'
/// ```
String formatMmSs(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  final m = (s ~/ 60).toString().padLeft(2, '0');
  final sec = (s % 60).toString().padLeft(2, '0');
  return '$m:$sec';
}

/// Formatea una cantidad total de segundos como `H:MM:SS` cuando hay al menos
/// una hora, o como `MM:SS` (via [formatMmSs]) cuando es menos de una hora.
///
/// Util para duraciones que pueden superar los 60 minutos y donde se prefiere
/// mostrar las horas como segmento separado en lugar de minutos acumulados.
///
/// - Horas: sin relleno (1, 2, ..., 10, ...).
/// - Minutos y segundos del segmento horario: rellenados a 2 digitos.
///
/// Valores negativos se tratan como `0`.
///
/// Ejemplos:
/// ```dart
/// formatHmsOrMmSs(45);    // '00:45'      (< 1h -> MM:SS)
/// formatHmsOrMmSs(600);   // '10:00'      (< 1h -> MM:SS)
/// formatHmsOrMmSs(3599);  // '59:59'      (< 1h -> MM:SS)
/// formatHmsOrMmSs(3600);  // '1:00:00'
/// formatHmsOrMmSs(3700);  // '1:01:40'
/// formatHmsOrMmSs(36000); // '10:00:00'
/// formatHmsOrMmSs(-10);   // '00:00'
/// ```
String formatHmsOrMmSs(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  if (s < 3600) return formatMmSs(s);
  final h = (s ~/ 3600).toString();
  final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
  final sec = (s % 60).toString().padLeft(2, '0');
  return '$h:$m:$sec';
}
