import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageStorage {
  static const _subdir = 'card_images';

  /// Directorio absoluto donde se guardan las imágenes.
  /// Resuelto al inicializar — se cachea para evitar awaits en cada uso.
  final String docsRoot;

  ImageStorage(this.docsRoot);

  static Future<ImageStorage> create() async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(dir.path, _subdir));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return ImageStorage(dir.path);
  }

  String absolutePathFor(String relativePath) =>
      p.join(docsRoot, relativePath);

  /// Copia el archivo recogido por `image_picker` a la carpeta de la app
  /// y devuelve una ruta relativa estable (ej: "card_images/xyz.jpg").
  Future<String> saveFromXFile(
    XFile picked, {
    required String cardId,
    required String slot, // 'front' | 'back'
  }) async {
    final ext = p.extension(picked.path).isNotEmpty
        ? p.extension(picked.path).toLowerCase()
        : '.jpg';
    final ts = DateTime.now().microsecondsSinceEpoch;
    final filename = 'card-$cardId-$slot-$ts$ext';
    final relPath = p.join(_subdir, filename);
    final absPath = p.join(docsRoot, relPath);
    final source = File(picked.path);
    await source.copy(absPath);
    return relPath;
  }

  Future<void> delete(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return;
    final f = File(p.join(docsRoot, relativePath));
    if (await f.exists()) {
      try {
        await f.delete();
      } catch (_) {
        // No bloquear si falla; el archivo huérfano es inocuo.
      }
    }
  }

  bool exists(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return false;
    return File(p.join(docsRoot, relativePath)).existsSync();
  }
}

/// Inicializado en main() vía override; intentar usar antes lanza.
final imageStorageProvider = Provider<ImageStorage>((ref) {
  throw UnimplementedError(
    'imageStorageProvider debe ser overrideado en main()',
  );
});
