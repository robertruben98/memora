import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/memora_card.dart';
import '../../data/repositories/card_repository.dart';
import '../../data/repositories/deck_repository.dart';

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
  }

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    super.dispose();
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
    final repo = ref.read(cardRepositoryProvider);
    if (_isEditing) {
      await repo.updateCard(
        id: widget.cardToEdit!.id,
        frontText: front,
        backText: back,
      );
    } else {
      await repo.createCard(
        id: 'card-${DateTime.now().microsecondsSinceEpoch}',
        deckId: widget.deckId,
        frontText: front,
        backText: back,
      );
    }
    ref.invalidate(allCardsProvider);
    ref.invalidate(deckSummariesProvider);
    ref.invalidate(cardsByDeckProvider(widget.deckId));

    if (!mounted) return;
    if (createAnother && !_isEditing) {
      _frontController.clear();
      _backController.clear();
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tarjeta creada. Crea la siguiente.'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A22),
        title: const Text('Eliminar tarjeta'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF4F6B)),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    await ref.read(cardRepositoryProvider).deleteCard(widget.cardToEdit!.id);
    ref.invalidate(allCardsProvider);
    ref.invalidate(deckSummariesProvider);
    ref.invalidate(cardsByDeckProvider(widget.deckId));

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(_isEditing ? 'Editar tarjeta' : 'Nueva tarjeta'),
        actions: [
          if (_isEditing)
            IconButton(
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
            const _Label('Pregunta (front)'),
            const SizedBox(height: 8),
            _EditorField(
              controller: _frontController,
              hint: 'p. ej. ¿Qué significa "to thrive"?',
              minLines: 3,
            ),
            const SizedBox(height: 24),
            const _Label('Respuesta (back)'),
            const SizedBox(height: 8),
            _EditorField(
              controller: _backController,
              hint: 'p. ej. Prosperar, florecer.',
              minLines: 3,
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
        color: Colors.white.withValues(alpha: 0.7),
        letterSpacing: 0.3,
      ),
    );
  }
}

class _EditorField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int minLines;

  const _EditorField({
    required this.controller,
    required this.hint,
    this.minLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: 8,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 16, height: 1.4),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        filled: true,
        fillColor: const Color(0xFF1A1A22),
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF7C5CFF), width: 1.5),
        ),
      ),
    );
  }
}
