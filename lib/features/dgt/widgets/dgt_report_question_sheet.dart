import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';

import '../../../data/repositories/dgt_repository.dart';

/// Issue #129 (dgt-ux): bottom sheet para reportar errata en pregunta DGT.
///
/// Consume backend BE#113 (`POST /dgt/questions/{id}/report`). Permite al
/// estudiante reportar:
/// - `wrong_answer`: la respuesta marcada como correcta esta mal.
/// - `ambiguous`: enunciado ambiguo o confuso.
/// - `bad_image`: la imagen no corresponde / esta cortada.
/// - `outdated_law`: la pregunta refiere normativa derogada.
/// - `typo`: erratas ortograficas en el texto.
/// - `other`: otro motivo (requiere comment para dar contexto).
///
/// Dedupe local in-memory por sesion (`_DgtReportedTracker`) para evitar
/// double-tap accidental que dispara 2 POST. El backend tambien deduplica
/// (devuelve 409) pero asi ahorramos la roundtrip.
///
/// Uso:
/// ```dart
/// IconButton(
///   icon: const Icon(Icons.flag_outlined),
///   onPressed: () => DgtReportQuestionSheet.show(
///     context: context,
///     ref: ref,
///     questionId: q.id,
///   ),
/// )
/// ```
class DgtReportQuestionSheet {
  DgtReportQuestionSheet._();

  /// Abre el bottom sheet de reporte. Si el [questionId] ya fue reportado en
  /// la sesion actual muestra un snackbar y no abre la hoja.
  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
    required String questionId,
  }) async {
    if (_DgtReportedTracker.instance.isReported(questionId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya reportaste esta pregunta en esta sesion.'),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.c.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _DgtReportQuestionSheetBody(
          questionId: questionId,
          ref: ref,
        ),
      ),
    );
  }
}

/// Tracker singleton in-memory de preguntas reportadas en la sesion actual.
/// Se resetea cuando la app reinicia: no persiste. Suficiente para evitar
/// spam por double-tap.
class _DgtReportedTracker {
  _DgtReportedTracker._();
  static final _DgtReportedTracker instance = _DgtReportedTracker._();

  final Set<String> _reported = <String>{};

  bool isReported(String id) => _reported.contains(id);
  void mark(String id) => _reported.add(id);
}

class _DgtReportQuestionSheetBody extends StatefulWidget {
  final String questionId;
  final WidgetRef ref;

  const _DgtReportQuestionSheetBody({
    required this.questionId,
    required this.ref,
  });

  @override
  State<_DgtReportQuestionSheetBody> createState() =>
      _DgtReportQuestionSheetBodyState();
}

class _DgtReportQuestionSheetBodyState
    extends State<_DgtReportQuestionSheetBody> {
  /// Valores alineados al enum del backend BE#113.
  static const List<_ReasonOption> _reasons = [
    _ReasonOption('wrong_answer', 'Respuesta marcada esta mal'),
    _ReasonOption('ambiguous', 'Enunciado ambiguo'),
    _ReasonOption('bad_image', 'Imagen no corresponde'),
    _ReasonOption('outdated_law', 'Normativa desactualizada'),
    _ReasonOption('typo', 'Errata ortografica'),
    _ReasonOption('other', 'Otro motivo'),
  ];

  String _reason = 'wrong_answer';
  final TextEditingController _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final repo = widget.ref.read(dgtRepositoryProvider);
    final ok = await repo.reportQuestion(
      questionId: widget.questionId,
      reason: _reason,
      comment: _commentCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      _DgtReportedTracker.instance.mark(widget.questionId);
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Gracias, revisaremos el reporte.'
              : 'No se pudo enviar el reporte. Reintenta mas tarde.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.flag_rounded, color: DgtStatusColors.warning),
                SizedBox(width: 8),
                Text(
                  'Reportar errata',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Ayudanos a mejorar el banco. Tu reporte se revisa manualmente.',
              style: TextStyle(
                color: context.c.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Motivo',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reasons.map((r) {
                final selected = r.value == _reason;
                return ChoiceChip(
                  label: Text(r.label),
                  selected: selected,
                  onSelected: _submitting
                      ? null
                      : (_) => setState(() => _reason = r.value),
                  selectedColor: AppColors.brand,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : null,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentCtrl,
              enabled: !_submitting,
              maxLength: 280,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Comentario (opcional)',
                hintText: 'Detalle adicional para el equipo...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_submitting ? 'Enviando...' : 'Enviar reporte'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonOption {
  final String value;
  final String label;
  const _ReasonOption(this.value, this.label);
}
