import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memora/core/theme/app_colors.dart';

import '../../../core/models/memora_card.dart';
import '../../../data/repositories/card_repository.dart';
import '../../cards/card_editor_screen.dart';
import '../../review/review_invalidation.dart';

/// Bottom sheet con acciones de "Editar tarjeta" y "Eliminar tarjeta".
class FeedPostMoreMenu {
  const FeedPostMoreMenu._();

  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
    required MemoraCard card,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: context.c.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              decoration: BoxDecoration(
                color: context.c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Editar tarjeta'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CardEditorScreen(
                      deckId: card.deckId,
                      cardToEdit: card,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFFF4F6B),
              ),
              title: const Text(
                'Eliminar tarjeta',
                style: TextStyle(color: Color(0xFFFF4F6B)),
              ),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                final ok = await showDialog<bool>(
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
                          foregroundColor: const Color(0xFFFF4F6B),
                        ),
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref.read(cardRepositoryProvider).deleteCard(card.id);
                  invalidateAfterCardChange(ref);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
