import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Issue #148 (dgt-tech): tile registry pattern para el Study Hub DGT.
///
/// Define la "forma" declarativa de cada tile DGT: estilo visual + navegacion
/// + visibilidad condicional. Cada feature DGT nueva se agrega como un
/// `DgtTileSpec` en `kDgtTileRegistry` SIN tocar `dgt_section.dart` ni
/// duplicar boilerplate de Material/InkWell/Container.
///
/// Inspirado en el patron `app.seed_dgt` registry del backend (ITER 39).
enum DgtTileVariant {
  /// Estilo "hero": gradiente + sombra. Usar para CTA principal (simulacro).
  hero,

  /// Estilo "primary": border accent fuerte + tamano mediano (sections).
  primary,

  /// Estilo "standard": border accent + tamano compacto (default).
  standard,
}

/// Badge opcional al lado del titulo (ej: "Adaptativo", "Anti-trampa").
class DgtTileBadge {
  final String text;
  final Color color;

  const DgtTileBadge({required this.text, required this.color});
}

/// Spec declarativo de un tile DGT.
///
/// - [title] / [subtitleBuilder]: textos principales. `subtitleBuilder` recibe
///   `WidgetRef` para subtitulos dinamicos (ej: historial muestra count).
/// - [icon] / [accentColor]: estilo visual.
/// - [variant]: hero / primary / standard.
/// - [routeBuilder]: widget destino al tap.
/// - [visibleWhen]: si retorna false, el tile no se renderiza. Default = true.
/// - [badge]: chip opcional al lado del titulo.
/// - [spacingBefore]: SizedBox vertical antes del tile (default 10). Usa 14
///   para separadores semanticos (ej: antes del bloque "Estudio por Secciones").
class DgtTileSpec {
  final String title;
  final String Function(WidgetRef ref) subtitleBuilder;
  final IconData icon;
  final Color accentColor;

  /// Segundo color para gradient en variant=hero. Si null, se calcula
  /// "lighten" de accentColor. Ignorado en otros variants.
  final Color? gradientEndColor;

  /// Color del icono en variant=primary. Si null, se calcula "lighten"
  /// de accentColor. Ignorado en otros variants.
  final Color? primaryIconColor;

  final DgtTileVariant variant;
  final Widget Function(BuildContext context) routeBuilder;
  final bool Function(WidgetRef ref)? visibleWhen;
  final DgtTileBadge? Function(WidgetRef ref)? badgeBuilder;
  final double spacingBefore;

  const DgtTileSpec({
    required this.title,
    required this.subtitleBuilder,
    required this.icon,
    required this.accentColor,
    required this.routeBuilder,
    this.gradientEndColor,
    this.primaryIconColor,
    this.variant = DgtTileVariant.standard,
    this.visibleWhen,
    this.badgeBuilder,
    this.spacingBefore = 10,
  });
}
