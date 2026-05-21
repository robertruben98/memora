import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Issue #148: spec inmutable que describe un tile DGT para el registry-pattern
/// del Study Hub. Cada feature DGT nueva (signals, autotest, warmup, etc.)
/// solo necesita agregar un `DgtTileSpec` a `buildDgtTileRegistry()` en vez de
/// editar el `build()` de `DgtStudySection` y crear otra clase widget privada.
///
/// Tres variantes visuales:
/// - `DgtTileVariant.standard`: borde + accent color (mayoria de tiles)
/// - `DgtTileVariant.hero`: gradiente + shadow (Simulacro DGT)
/// - `DgtTileVariant.section`: ligeramente mas grande (Estudiar por Secciones)
enum DgtTileVariant { standard, hero, section }

/// Resolver dinamico de subtitulo. Recibe el `WidgetRef` para poder consumir
/// providers (ej. historial count, weakest topic accuracy). Devuelve un texto
/// final ya formateado para mostrar.
typedef DgtSubtitleBuilder = String Function(WidgetRef ref);

/// Resolver de visibilidad. Si retorna `false` el tile se omite del Column.
/// Si no se pasa, el tile siempre es visible.
typedef DgtVisibilityResolver = bool Function(WidgetRef ref);

/// Builder de la ruta de destino. Recibe el contexto y el ref por si la
/// pantalla destino necesita parametros derivados de providers.
typedef DgtRouteBuilder = Widget Function(BuildContext context, WidgetRef ref);

@immutable
class DgtTileSpec {
  /// Titulo principal del tile.
  final String title;

  /// Subtitulo estatico. Mutuamente excluyente con [subtitleBuilder].
  final String? subtitle;

  /// Subtitulo dinamico computado desde providers (history count, etc.).
  /// Si esta presente, prevalece sobre [subtitle].
  final DgtSubtitleBuilder? subtitleBuilder;

  /// Icono del leading box.
  final IconData icon;

  /// Color de acento (borde, icon bg, badge bg). Para `hero` se ignora y se
  /// usa el gradiente naranja oficial DGT.
  final Color accentColor;

  /// Etiqueta pequena tipo chip al lado del titulo (ej. "Active recall",
  /// "Anti-trampa", "Adaptativo"). Opcional.
  final String? badgeText;

  /// Builder de la pantalla a la que navega el tile.
  final DgtRouteBuilder routeBuilder;

  /// Visibilidad condicional. Si null -> siempre visible.
  final DgtVisibilityResolver? visibleWhen;

  /// Variante visual del tile.
  final DgtTileVariant variant;

  /// Spacing previo (en logical pixels). Default 10. El primer tile visible
  /// del registry no aplica spacing.
  final double leadingGap;

  const DgtTileSpec({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.routeBuilder,
    this.subtitle,
    this.subtitleBuilder,
    this.badgeText,
    this.visibleWhen,
    this.variant = DgtTileVariant.standard,
    this.leadingGap = 10,
  }) : assert(subtitle != null || subtitleBuilder != null,
            'DgtTileSpec requiere subtitle o subtitleBuilder');

  /// Resuelve el subtitulo final usando el provider correspondiente.
  String resolveSubtitle(WidgetRef ref) {
    if (subtitleBuilder != null) return subtitleBuilder!(ref);
    return subtitle ?? '';
  }

  /// Resuelve visibilidad. True por defecto.
  bool isVisible(WidgetRef ref) {
    if (visibleWhen == null) return true;
    return visibleWhen!(ref);
  }
}
