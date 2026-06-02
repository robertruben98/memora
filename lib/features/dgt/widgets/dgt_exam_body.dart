import 'package:flutter/material.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/widgets/app_state_view.dart';

import '../../../data/repositories/dgt_repository.dart';
import '../dgt_exam_controller.dart';
import 'dgt_exam_widgets.dart';

/// Issue #139 (dgt-tech): cuerpo del simulacro en curso (pregunta + tiles +
/// barra inferior de navegacion), extraido de `dgt_exam_screen.dart` para
/// que el archivo principal quede como capa fina de orquestacion.
///
/// El widget es puro presentacion: lee estado del [DgtExamController] y
/// expone callbacks para acciones que requieren contexto del screen padre
/// (mostrar grid sheet, confirmar finalizacion).
class DgtExamBody extends StatelessWidget {
  final Future<List<DgtQuestion>>? future;
  final DgtExamController? controller;
  final bool strictMode;
  final VoidCallback onShowQuestionGrid;
  final VoidCallback onConfirmFinish;

  const DgtExamBody({
    super.key,
    required this.future,
    required this.controller,
    required this.strictMode,
    required this.onShowQuestionGrid,
    required this.onConfirmFinish,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DgtQuestion>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return AppStateView.loading();
        }
        if (snap.hasError || (snap.data ?? const []).isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudo cargar el simulacro: ${snap.error ?? "sin preguntas"}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final ctrl = controller;
        if (ctrl == null) {
          return AppStateView.loading();
        }
        final qs = ctrl.questions;
        final currentIndex = ctrl.currentIndex;
        final q = qs[currentIndex];
        final picked = ctrl.pickedAt();
        return Column(
          children: [
            LinearProgressIndicator(
              value: (currentIndex + 1) / qs.length,
              minHeight: 4,
              backgroundColor: context.c.surfaceMuted,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _QuestionHeader(
                      currentIndex: currentIndex,
                      total: qs.length,
                      strictMode: strictMode,
                      isFlagged: ctrl.isFlagged(),
                      onToggleFlag: ctrl.toggleFlag,
                      onOpenGrid: onShowQuestionGrid,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      q.statement,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    if (q.imageUrl != null && q.imageUrl!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: DgtExamImage(path: q.imageUrl!),
                      ),
                    ],
                    const SizedBox(height: 16),
                    DgtAnswerTile(
                      letter: 'a',
                      text: q.optionA,
                      selected: picked == 'a',
                      onTap: () => ctrl.selectAnswer('a'),
                    ),
                    DgtAnswerTile(
                      letter: 'b',
                      text: q.optionB,
                      selected: picked == 'b',
                      onTap: () => ctrl.selectAnswer('b'),
                    ),
                    DgtAnswerTile(
                      letter: 'c',
                      text: q.optionC,
                      selected: picked == 'c',
                      onTap: () => ctrl.selectAnswer('c'),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: _ExamNavRow(
                  currentIndex: currentIndex,
                  total: qs.length,
                  strictMode: strictMode,
                  pickedCurrent: picked,
                  onPrevious: ctrl.previous,
                  onNext: ctrl.next,
                  onConfirmFinish: onConfirmFinish,
                  onSubmit: () => ctrl.submit(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuestionHeader extends StatelessWidget {
  final int currentIndex;
  final int total;
  final bool strictMode;
  final bool isFlagged;
  final VoidCallback onToggleFlag;
  final VoidCallback onOpenGrid;

  const _QuestionHeader({
    required this.currentIndex,
    required this.total,
    required this.strictMode,
    required this.isFlagged,
    required this.onToggleFlag,
    required this.onOpenGrid,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Pregunta ${currentIndex + 1} / $total',
          style: TextStyle(
            color: context.c.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (!strictMode) ...[
          IconButton(
            tooltip: isFlagged ? 'Desmarcar' : 'Marcar para revisar',
            onPressed: onToggleFlag,
            icon: Icon(
              isFlagged ? Icons.flag_rounded : Icons.outlined_flag_rounded,
              color: isFlagged ? const Color(0xFFFFB74F) : null,
            ),
          ),
          IconButton(
            tooltip: 'Ver panel de preguntas',
            onPressed: onOpenGrid,
            icon: const Icon(Icons.grid_view_rounded),
          ),
        ],
      ],
    );
  }
}

/// Barra inferior con "Anterior" / "Siguiente" o "Terminar"/"Entregar".
/// Encapsula las 3 variantes (no-strict mid-exam, no-strict last,
/// strict last) que antes vivian inline en el monolito.
class _ExamNavRow extends StatelessWidget {
  final int currentIndex;
  final int total;
  final bool strictMode;
  final String? pickedCurrent;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onConfirmFinish;
  final VoidCallback onSubmit;

  const _ExamNavRow({
    required this.currentIndex,
    required this.total,
    required this.strictMode,
    required this.pickedCurrent,
    required this.onPrevious,
    required this.onNext,
    required this.onConfirmFinish,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = currentIndex >= total - 1;
    return Row(
      children: [
        if (!strictMode)
          OutlinedButton.icon(
            onPressed: currentIndex > 0 ? onPrevious : null,
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Anterior'),
          ),
        const Spacer(),
        if (!isLast)
          FilledButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            label: const Text('Siguiente'),
          )
        else if (strictMode)
          FilledButton.icon(
            onPressed: pickedCurrent != null ? onSubmit : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF5C5C),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.flag_rounded),
            label: const Text('Entregar examen'),
          )
        else
          FilledButton.icon(
            onPressed: onConfirmFinish,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4FFFB0),
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Terminar'),
          ),
      ],
    );
  }
}
