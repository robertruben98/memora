import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';

import '../marked_cards_provider.dart';

/// Boton estrella para marcar/desmarcar una card como favorita DGT.
/// Aditivo: no altera SRS ni queue. Solo toggle persistente local + snackbar.
class StarToggleButton extends ConsumerWidget {
  final String cardId;
  final double size;
  final EdgeInsetsGeometry padding;

  const StarToggleButton({
    super.key,
    required this.cardId,
    this.size = 24,
    this.padding = const EdgeInsets.all(8),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marked = ref.watch(markedCardsProvider).contains(cardId);
    return Tooltip(
      message: marked ? 'Quitar de marcadas' : 'Marcar para repaso DGT',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _onTap(context, ref),
        child: Padding(
          padding: padding,
          child: Icon(
            marked ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: marked
                ? const Color(0xFFFFC857)
                : context.c.textSecondary,
          ),
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    final notifier = ref.read(markedCardsProvider.notifier);
    final wasMarked = ref.read(markedCardsProvider).contains(cardId);
    final nowMarked = await notifier.toggle(cardId);
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          content: Text(nowMarked ? 'Marcada' : 'Quitada'),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () {
              // Restaurar estado anterior.
              if (wasMarked) {
                notifier.mark(cardId);
              } else {
                notifier.unmark(cardId);
              }
            },
          ),
        ),
      );
  }
}
