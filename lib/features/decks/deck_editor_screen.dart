import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';

import '../../core/theme/deck_visuals.dart';
import '../../data/database/database.dart';
import '../../data/repositories/card_repository.dart';
import '../../data/repositories/deck_repository.dart';

class DeckEditorScreen extends ConsumerStatefulWidget {
  final DeckRow? deckToEdit;

  const DeckEditorScreen({super.key, this.deckToEdit});

  @override
  ConsumerState<DeckEditorScreen> createState() => _DeckEditorScreenState();
}

class _DeckEditorScreenState extends ConsumerState<DeckEditorScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late String _colorHex;
  late String _iconName;
  bool _saving = false;

  bool get _isEditing => widget.deckToEdit != null;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.deckToEdit?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.deckToEdit?.description ?? '');
    _colorHex = widget.deckToEdit?.colorHex ?? DeckVisuals.palette.first;
    _iconName = widget.deckToEdit?.iconName ?? DeckVisuals.icons.first.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre es obligatorio')),
      );
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(deckRepositoryProvider);
    final desc = _descriptionController.text.trim();
    if (_isEditing) {
      await repo.updateDeck(
        id: widget.deckToEdit!.id,
        name: name,
        description: desc.isEmpty ? null : desc,
        colorHex: _colorHex,
        iconName: _iconName,
      );
    } else {
      await repo.createDeck(
        id: 'deck-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        description: desc.isEmpty ? null : desc,
        colorHex: _colorHex,
        iconName: _iconName,
      );
    }
    ref.invalidate(deckSummariesProvider);
    ref.invalidate(allCardsProvider);
    if (_isEditing) {
      ref.invalidate(deckByIdProvider(widget.deckToEdit!.id));
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.c.surfaceElevated,
        title: const Text('Eliminar mazo'),
        content: const Text(
          'Se eliminará el mazo y todas sus tarjetas. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF4F6B),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    await ref.read(deckRepositoryProvider).deleteDeck(widget.deckToEdit!.id);
    ref.invalidate(deckSummariesProvider);
    ref.invalidate(allCardsProvider);
    if (!mounted) return;
    Navigator.of(context).pop('deleted');
  }

  @override
  Widget build(BuildContext context) {
    final color = DeckVisuals.colorFromHex(_colorHex);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(_isEditing ? 'Editar mazo' : 'Nuevo mazo'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Eliminar mazo',
              icon: const Icon(Icons.delete_outline_rounded),
              color: const Color(0xFFFF4F6B),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PreviewCard(
              name: _nameController.text.isEmpty
                  ? 'Nombre del mazo'
                  : _nameController.text,
              color: color,
              iconName: _iconName,
            ),
            const SizedBox(height: 24),
            const _Label('Nombre'),
            const SizedBox(height: 8),
            _Field(
              controller: _nameController,
              hint: 'p. ej. Inglés - Verbos',
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 20),
            const _Label('Descripción (opcional)'),
            const SizedBox(height: 8),
            _Field(
              controller: _descriptionController,
              hint: 'Tema del mazo',
              minLines: 2,
              onChanged: () {},
            ),
            const SizedBox(height: 24),
            const _Label('Color'),
            const SizedBox(height: 12),
            _ColorPicker(
              selectedHex: _colorHex,
              onChanged: (h) => setState(() => _colorHex = h),
            ),
            const SizedBox(height: 24),
            const _Label('Icono'),
            const SizedBox(height: 12),
            _IconPicker(
              selectedName: _iconName,
              tint: color,
              onChanged: (n) => setState(() => _iconName = n),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(_isEditing ? 'Guardar cambios' : 'Crear mazo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String name;
  final Color color;
  final String iconName;

  const _PreviewCard({
    required this.name,
    required this.color,
    required this.iconName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.c.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              DeckVisuals.iconFor(iconName),
              color: color,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Vista previa',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.c.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.c.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int minLines;
  final VoidCallback onChanged;

  const _Field({
    required this.controller,
    required this.hint,
    this.minLines = 1,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: minLines == 1 ? 1 : 4,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 16),
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.c.textMuted),
        filled: true,
        fillColor: context.c.surfaceElevated,
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.c.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  final String selectedHex;
  final ValueChanged<String> onChanged;

  const _ColorPicker({required this.selectedHex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: DeckVisuals.palette.map((hex) {
        final color = DeckVisuals.colorFromHex(hex);
        final selected = hex == selectedHex;
        return GestureDetector(
          onTap: () => onChanged(hex),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? context.c.textPrimary : Colors.transparent,
                width: 3,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.black, size: 22)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class _IconPicker extends StatelessWidget {
  final String selectedName;
  final Color tint;
  final ValueChanged<String> onChanged;

  const _IconPicker({
    required this.selectedName,
    required this.tint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: DeckVisuals.icons.map((opt) {
        final selected = opt.name == selectedName;
        return GestureDetector(
          onTap: () => onChanged(opt.name),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: selected
                  ? tint.withValues(alpha: 0.2)
                  : context.c.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? tint : context.c.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Icon(
              opt.icon,
              color: selected ? tint : context.c.textSecondary,
              size: 26,
            ),
          ),
        );
      }).toList(),
    );
  }
}
