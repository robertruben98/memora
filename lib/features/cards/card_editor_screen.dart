import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';

import '../../core/models/memora_card.dart';
import '../../core/widgets/memora_image.dart';
import '../../core/widgets/styled_text_field.dart';
import '../../data/api/api_client.dart';
import '../../data/repositories/card_repository.dart';
import '../../data/repositories/review_repository.dart';
import '../../data/storage/image_storage.dart';
import '../review/review_invalidation.dart';

class CardEditorScreen extends ConsumerStatefulWidget {
  final String deckId;
  final MemoraCard? cardToEdit;

  const CardEditorScreen({
    super.key,
    required this.deckId,
    this.cardToEdit,
  });

  @override
  ConsumerState<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends ConsumerState<CardEditorScreen> {
  late final TextEditingController _frontController;
  late final TextEditingController _backController;
  String? _frontImagePath;
  String? _backImagePath;
  bool _saving = false;

  bool get _isEditing => widget.cardToEdit != null;

  @override
  void initState() {
    super.initState();
    _frontController = TextEditingController(
      text: widget.cardToEdit?.front ?? '',
    );
    _backController = TextEditingController(
      text: widget.cardToEdit?.back ?? '',
    );
    _frontImagePath = widget.cardToEdit?.frontImagePath;
    _backImagePath = widget.cardToEdit?.backImagePath;
  }

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isFront) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.c.surfaceElevated,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Galería'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Cámara'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final XFile? picked;
    try {
      picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo seleccionar imagen: $e')),
      );
      return;
    }
    if (picked == null) return;

    setState(() => _saving = true);
    String? remotePath;
    try {
      // Sube al servidor; el server devuelve "/images/abc.jpg".
      final api = ref.read(apiClientProvider);
      final res = await api.uploadImage(File(picked.path));
      remotePath = res['path'] as String;
    } catch (e) {
      // Fallback offline: guarda en local.
      if (!mounted) return;
      final storage = ref.read(imageStorageProvider);
      final cardId = widget.cardToEdit?.id ??
          'tmp-${DateTime.now().microsecondsSinceEpoch}';
      remotePath = await storage.saveFromXFile(
        picked,
        cardId: cardId,
        slot: isFront ? 'front' : 'back',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sin conexión: imagen guardada solo en local'),
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      if (isFront) {
        _frontImagePath = remotePath;
      } else {
        _backImagePath = remotePath;
      }
      _saving = false;
    });
  }

  Future<void> _removeImage(bool isFront) async {
    final storage = ref.read(imageStorageProvider);
    final path = isFront ? _frontImagePath : _backImagePath;
    if (path != null) await storage.delete(path);
    setState(() {
      if (isFront) {
        _frontImagePath = null;
      } else {
        _backImagePath = null;
      }
    });
  }

  Future<void> _save({required bool createAnother}) async {
    final front = _frontController.text.trim();
    final back = _backController.text.trim();
    if (front.isEmpty || back.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pregunta y respuesta son obligatorias')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(cardRepositoryProvider);
      if (_isEditing) {
        await repo.updateCard(
          id: widget.cardToEdit!.id,
          frontText: front,
          backText: back,
          frontImagePath: _frontImagePath,
          backImagePath: _backImagePath,
        );
      } else {
        final newId = 'card-${DateTime.now().microsecondsSinceEpoch}';
        await repo.createCard(
          id: newId,
          deckId: widget.deckId,
          frontText: front,
          backText: back,
          frontImagePath: _frontImagePath,
          backImagePath: _backImagePath,
        );
        await ref
            .read(reviewRepositoryProvider)
            .getOrCreateSchedule(newId, now: DateTime.now());
      }
      invalidateAfterCardChange(ref, deckId: widget.deckId);

      if (!mounted) return;
      if (createAnother && !_isEditing) {
        _frontController.clear();
        _backController.clear();
        setState(() {
          _frontImagePath = null;
          _backImagePath = null;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tarjeta creada. Crea la siguiente.'),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la tarjeta: $e')),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.c.surfaceElevated,
        title: const Text('Eliminar tarjeta'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: DgtStatusColors.danger,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      final storage = ref.read(imageStorageProvider);
      if (_frontImagePath != null && !_frontImagePath!.startsWith('/')) {
        await storage.delete(_frontImagePath);
      }
      if (_backImagePath != null && !_backImagePath!.startsWith('/')) {
        await storage.delete(_backImagePath);
      }
      await ref.read(cardRepositoryProvider).deleteCard(widget.cardToEdit!.id);
      invalidateAfterCardChange(ref, deckId: widget.deckId);

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar la tarjeta: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(imageStorageProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(_isEditing ? 'Editar tarjeta' : 'Nueva tarjeta'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Eliminar tarjeta',
              color: DgtStatusColors.danger,
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const AppLabel('Pregunta (front)'),
            const SizedBox(height: 8),
            StyledTextField(
              controller: _frontController,
              hint: 'p. ej. ¿Qué significa "to thrive"?',
              minLines: 3,
              maxLines: 8,
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 8),
            _ImagePickerRow(
              path: _frontImagePath,
              storage: storage,
              onPick: () => _pickImage(true),
              onRemove: () => _removeImage(true),
            ),
            const SizedBox(height: 24),
            const AppLabel('Respuesta (back)'),
            const SizedBox(height: 8),
            StyledTextField(
              controller: _backController,
              hint: 'p. ej. Prosperar, florecer.',
              minLines: 3,
              maxLines: 8,
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 8),
            _ImagePickerRow(
              path: _backImagePath,
              storage: storage,
              onPick: () => _pickImage(false),
              onRemove: () => _removeImage(false),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : () => _save(createAnother: false),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(_isEditing ? 'Guardar cambios' : 'Guardar'),
            ),
            if (!_isEditing) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _saving ? null : () => _save(createAnother: true),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Guardar y crear otra'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImagePickerRow extends StatelessWidget {
  final String? path;
  final ImageStorage storage;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _ImagePickerRow({
    required this.path,
    required this.storage,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (path == null) {
      return TextButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.add_photo_alternate_rounded),
        label: const Text('Añadir imagen'),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          alignment: Alignment.centerLeft,
        ),
      );
    }
    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          child: MemoraImage(path: path!, height: 160),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              _IconButton(icon: Icons.swap_horiz_rounded, onTap: onPick),
              const SizedBox(width: 6),
              _IconButton(
                icon: Icons.close_rounded,
                onTap: onRemove,
                danger: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  const _IconButton({
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? DgtStatusColors.danger : Colors.white;
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

