import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/storage/image_storage.dart';

/// Renderiza la imagen de una tarjeta. Soporta:
///  - paths del server "/images/abc.jpg" (Image.network)
///  - URLs absolutas "https://..." (Image.network)
///  - paths legacy locales "card_images/xyz.jpg" (Image.file)
class MemoraImage extends ConsumerWidget {
  final String path;
  final double height;
  final BoxFit fit;
  final BorderRadiusGeometry borderRadius;

  const MemoraImage({
    super.key,
    required this.path,
    this.height = 220,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiClientProvider);
    final remoteUrl = api.remoteUrlFor(path);
    return ClipRRect(
      borderRadius: borderRadius,
      child: remoteUrl != null
          ? Image.network(
              remoteUrl,
              height: height,
              fit: fit,
              errorBuilder: (_, _, _) => _placeholder(),
              loadingBuilder: (_, child, prog) {
                if (prog == null) return child;
                return _placeholder(loading: true);
              },
            )
          : _localImage(ref),
    );
  }

  Widget _localImage(WidgetRef ref) {
    final storage = ref.read(imageStorageProvider);
    return Image.file(
      File(storage.absolutePathFor(path)),
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }

  Widget _placeholder({bool loading = false}) {
    return Container(
      height: height,
      color: const Color(0xFF242430),
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.broken_image_outlined,
              color: Colors.white.withValues(alpha: 0.3),
              size: 36,
            ),
    );
  }
}
