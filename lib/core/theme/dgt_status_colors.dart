import 'package:flutter/material.dart';

/// Paleta semántica de estado de RutaB, centralizada (DRY).
///
/// Los valores son IDÉNTICOS a los literales que antes estaban hardcoded por
/// toda la app, así que sustituir `Color(0xFF...)` por estas constantes es
/// pixel-idéntico (sin cambio visual). Son colores de SEÑAL (acierto, fallo,
/// aviso), iguales en modo claro y oscuro, por lo que NO van en [AppColors]
/// (que sí se adapta al tema).
class DgtStatusColors {
  DgtStatusColors._();

  /// Verde acierto / aprobado / correcto.
  static const Color success = Color(0xFF4FFFB0);

  /// Rojo fallo / incorrecto.
  static const Color error = Color(0xFFFF5C5C);

  /// Rojo-rosa peligro / acción destructiva.
  static const Color danger = Color(0xFFFF4F6B);

  /// Ámbar aviso / atención.
  static const Color warning = Color(0xFFFFB74F);

  /// Amarillo aviso fuerte / destacado.
  static const Color warningStrong = Color(0xFFFFD24F);

  /// Naranja acento (rachas, energía).
  static const Color accentOrange = Color(0xFFFF8A4F);

  /// Azul información / nuevas.
  static const Color info = Color(0xFF4FA8FF);

  /// Verde si aprobado/correcto, rojo si no.
  static Color forPassed(bool passed) => passed ? success : error;
}
