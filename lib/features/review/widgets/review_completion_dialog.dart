import 'package:flutter/material.dart';
import 'package:memora/core/theme/app_colors.dart';

/// A single stat line rendered inside the completion dialog body.
class ReviewCompletionStat {
  const ReviewCompletionStat(this.label, this.value);

  final String label;
  final int value;
}

/// Shared end-of-session completion dialog used by the review/study screens.
///
/// Replaces the near-identical `_showCompletion` AlertDialogs in
/// `failed_review_screen.dart`, `marked_review_screen.dart` and
/// `feed_screen.dart`.
///
/// Differences between the original three are parameterized:
/// - [title]: dialog heading (e.g. '¡Repaso completado!' vs '¡Sesión completa!').
/// - [stats]: the score lines (reviewed count, hits, misses).
/// - [actionLabel]: the CTA text (e.g. 'Volver' vs 'Volver al inicio').
/// - [onAction]: callback for the CTA. Defaults to popping the dialog and the
///   underlying screen (`Navigator.pop` twice), matching the original behavior.
Future<void> showReviewCompletionDialog(
  BuildContext context, {
  required String title,
  required List<ReviewCompletionStat> stats,
  String actionLabel = 'Volver',
  VoidCallback? onAction,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: dialogContext.c.surfaceElevated,
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i == 1) const SizedBox(height: 4),
            Text('${stats[i].label}: ${stats[i].value}'),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: onAction ??
              () {
                Navigator.of(dialogContext).pop();
                Navigator.of(dialogContext).pop();
              },
          child: Text(actionLabel),
        ),
      ],
    ),
  );
}
