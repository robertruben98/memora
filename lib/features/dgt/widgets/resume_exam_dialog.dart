import 'package:flutter/material.dart';

import '../dgt_exam_snapshot.dart';

/// Issue #133: dialogo que pregunta al usuario si quiere reanudar un
/// simulacro DGT interrumpido o descartarlo.
///
/// Aditivo respecto al flow base: si no hay snapshot, este dialogo no se
/// muestra y el flow original es identico.
enum ResumeExamChoice { resume, discard }

class ResumeExamDialog extends StatelessWidget {
  final DgtExamSnapshot snapshot;
  const ResumeExamDialog({super.key, required this.snapshot});

  /// Muestra el dialogo y devuelve la eleccion del usuario.
  ///
  /// `null` si el usuario cierra con back (equivalente a "no decidir aun" —
  /// el caller debe interpretarlo como "no abrir nada todavia").
  static Future<ResumeExamChoice?> show(
    BuildContext context,
    DgtExamSnapshot snapshot,
  ) {
    return showDialog<ResumeExamChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ResumeExamDialog(snapshot: snapshot),
    );
  }

  String _formatRemaining(int secs) {
    final clamped = secs < 0 ? 0 : secs;
    final m = clamped ~/ 60;
    final s = clamped % 60;
    if (m <= 0) return '${s}s';
    return '${m}min ${s.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final answered = snapshot.answeredCount;
    final total = snapshot.totalCount;
    final remainingTxt = _formatRemaining(snapshot.secondsRemaining);
    final expired = snapshot.secondsRemaining <= 0;
    return AlertDialog(
      key: const ValueKey('dgt-resume-exam-dialog'),
      title: const Text('Simulacro pendiente'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            expired
                ? 'Tienes un simulacro a medias.\n\n'
                    'Llevas $answered/$total preguntas respondidas. El tiempo '
                    'expiro mientras estaba cerrado — al reanudar iras directo '
                    'al resultado con las respuestas que llevabas.'
                : 'Tienes un simulacro a medias.\n\n'
                    'Llevas $answered/$total preguntas y quedan $remainingTxt '
                    'en el cronometro.',
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('dgt-resume-discard-btn'),
          onPressed: () =>
              Navigator.of(context).pop(ResumeExamChoice.discard),
          child: const Text('Descartar'),
        ),
        FilledButton(
          key: const ValueKey('dgt-resume-resume-btn'),
          onPressed: () =>
              Navigator.of(context).pop(ResumeExamChoice.resume),
          child: Text(expired ? 'Ver resultado' : 'Reanudar'),
        ),
      ],
    );
  }
}
