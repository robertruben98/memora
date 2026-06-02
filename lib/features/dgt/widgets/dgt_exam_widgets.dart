import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';

import '../../../data/api/api_client.dart';
import '../dgt_exam_controller.dart';

/// Issue #139 (dgt-tech): widgets compartidos del simulacro DGT, extraidos
/// de `dgt_exam_screen.dart` para reducir su LOC.
///
/// Aditivo: visual identico al monolito previo. Estos widgets no estaban
/// re-utilizados antes; viven aqui solo por higiene de archivo.

/// Tile de respuesta del simulacro (letra A/B/C + texto + estado seleccionado).
class DgtAnswerTile extends StatelessWidget {
  final String letter;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const DgtAnswerTile({
    super.key,
    required this.letter,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brand : context.c.surfaceMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : context.c.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    letter.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: selected ? AppColors.brand : context.c.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid de preguntas para navegacion libre (issue #139, antes inline en
/// `dgt_exam_screen.dart`). Bottom-sheet con celdas coloreadas segun
/// estado: actual (purpura), respondida (verde), marcada (naranja), sin
/// responder (gris). El usuario tapea una celda para saltar a esa pregunta.
class DgtQuestionGridSheet {
  static Future<void> show({
    required BuildContext context,
    required DgtExamController controller,
  }) {
    final questions = controller.questions;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.c.surfaceElevated,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preguntas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(questions.length, (i) {
                    final answered =
                        controller.selectedAnswers.containsKey(i);
                    final flagged = controller.isFlagged(i);
                    final isCurrent = i == controller.currentIndex;
                    Color bg;
                    if (isCurrent) {
                      bg = AppColors.brand;
                    } else if (flagged) {
                      bg = const Color(0xFFFFB74F);
                    } else if (answered) {
                      bg =
                          const Color(0xFF4FFFB0).withValues(alpha: 0.35);
                    } else {
                      bg = context.c.surfaceMuted;
                    }
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        controller.goTo(i);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                _legendRow(AppColors.brand, 'Actual'),
                _legendRow(
                    const Color(0xFF4FFFB0).withValues(alpha: 0.35),
                    'Respondida'),
                _legendRow(const Color(0xFFFFB74F), 'Marcada'),
                _legendRow(context.c.surfaceMuted, 'Sin responder'),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _legendRow(Color c, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              )),
        ],
      ),
    );
  }
}

/// Imagen de la pregunta del simulacro, resuelve la URL via `apiClient`.
class DgtExamImage extends ConsumerWidget {
  final String path;
  const DgtExamImage({super.key, required this.path});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientProvider);
    final url = api.remoteUrlFor(path) ?? path;
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        height: 120,
        alignment: Alignment.center,
        color: context.c.surfaceMuted,
        child: const Icon(Icons.image_not_supported_outlined),
      ),
    );
  }
}
