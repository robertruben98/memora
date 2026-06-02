import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/api/api_client.dart';
import '../theme/app_colors.dart';

/// Imagen asociada a una pregunta DGT (croquis, fotografia o senal).
///
/// Unifica el widget privado `_DgtImage` que estaba duplicado de forma
/// identica en las 5 pantallas DGT (practice, quick_review, hard_challenge,
/// favorites, autotest).
///
/// Comportamiento:
///  - Resuelve [path] a una URL absoluta via [ApiClient.remoteUrlFor]
///    (paths relativos tipo `/static/...` o `/images/...` se anteponen con la
///    base del API; URLs `http(s)://` se respetan tal cual). Si `remoteUrlFor`
///    devuelve null (path local), se usa [path] como fallback.
///  - Si la URL termina en `.svg` se renderiza con `flutter_svg`
///    ([SvgPicture.network]); en caso contrario con [Image.network] raster.
///  - Ante error de carga (o mientras el SVG resuelve su placeholder) muestra
///    un contenedor `surfaceMuted` con el icono de imagen no disponible,
///    preservando el aspecto original de las 5 copias.
///
/// Los parametros [fit], [placeholderHeight] y [placeholderIcon] exponen los
/// puntos que diferian (o podrian diferir) entre pantallas, con defaults que
/// igualan el caso mas comun (`BoxFit.cover`, altura 120, icono
/// `image_not_supported_outlined`).
///
/// Ejemplo:
/// ```dart
/// import 'package:memora/core/widgets/dgt_question_image.dart';
///
/// // En el cuerpo de una pregunta con imagen:
/// if (question.imageUrl != null)
///   AspectRatio(
///     aspectRatio: 16 / 9,
///     child: DgtQuestionImage(path: question.imageUrl!),
///   );
/// ```
class DgtQuestionImage extends ConsumerWidget {
  /// Path o URL de la imagen. Puede ser relativo (`/static/...`,
  /// `/images/...`) o absoluto (`http(s)://...`).
  final String path;

  /// Como ajustar la imagen dentro de su caja. Por defecto [BoxFit.cover],
  /// que es el valor usado por las 5 copias originales.
  final BoxFit fit;

  /// Altura del contenedor de error/placeholder. Por defecto `120`.
  final double placeholderHeight;

  /// Icono mostrado en el placeholder de error. Por defecto
  /// [Icons.image_not_supported_outlined].
  final IconData placeholderIcon;

  const DgtQuestionImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.placeholderHeight = 120,
    this.placeholderIcon = Icons.image_not_supported_outlined,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientProvider);
    final url = api.remoteUrlFor(path) ?? path;

    if (url.toLowerCase().endsWith('.svg')) {
      return SvgPicture.network(
        url,
        fit: fit,
        placeholderBuilder: (_) => _placeholder(context),
      );
    }

    return Image.network(
      url,
      fit: fit,
      errorBuilder: (_, _, _) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      height: placeholderHeight,
      alignment: Alignment.center,
      color: context.c.surfaceMuted,
      child: Icon(placeholderIcon),
    );
  }
}
