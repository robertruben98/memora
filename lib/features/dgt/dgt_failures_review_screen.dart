import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/dgt_repository.dart';
import 'dgt_failures_repository.dart';
import 'widgets/dgt_report_question_sheet.dart';

/// Issue #95 (dgt-content): pantalla "Repaso de fallos" - re-quiz de
/// preguntas falladas en los ultimos 7 dias.
///
/// Carga dataset desde [dgtRecentFailuresProvider] (snapshot local de
/// preguntas guardadas al momento del fallo). Al final muestra resumen
/// "Repasaste X fallos, acertaste Y" e invalida el provider para que la
/// card del Home refresque su count.
class DgtFailuresReviewScreen extends ConsumerStatefulWidget {
  const DgtFailuresReviewScreen({super.key});

  @override
  ConsumerState<DgtFailuresReviewScreen> createState() =>
      _DgtFailuresReviewScreenState();
}

class _DgtFailuresReviewScreenState
    extends ConsumerState<DgtFailuresReviewScreen> {
  /// `picked[i]` = letra elegida (`a|b|c`) o `null`.
  final Map<int, String> _picked = {};
  int _current = 0;
  bool _finished = false;
  int _correctCount = 0;
  int _totalAnswered = 0;

  void _select(String letter, DgtQuestion q) {
    if (_picked.containsKey(_current)) return; // un solo intento
    setState(() {
      _picked[_current] = letter;
      _totalAnswered++;
      if (letter == q.correct) {
        _correctCount++;
        // Acerto -> sacar de la queue de fallos.
        ref
            .read(dgtFailuresRepositoryProvider)
            .markResolved(q.id);
      } else {
        // Re-fallar refresca timestamp -> sigue en ventana 7d.
        ref.read(dgtFailuresRepositoryProvider).recordFailure(q);
      }
    });
  }

  void _next(int total) {
    if (_current + 1 >= total) {
      setState(() => _finished = true);
      ref.invalidate(dgtRecentFailuresCountProvider);
      ref.invalidate(dgtRecentFailuresProvider);
    } else {
      setState(() => _current++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final failuresAsync = ref.watch(dgtRecentFailuresProvider);
    // Issue #129 (dgt-ux): pregunta actual para el boton "Reportar errata"
    // del AppBar. Solo disponible cuando hay entries y el quiz no termino.
    DgtQuestion? currentQ;
    failuresAsync.whenData((entries) {
      if (entries.isNotEmpty && !_finished) {
        final idx = _current.clamp(0, entries.length - 1);
        currentQ = entries[idx].question;
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text('Repaso de fallos'),
        actions: [
          if (currentQ != null)
            IconButton(
              tooltip: 'Reportar errata',
              icon: const Icon(Icons.flag_outlined),
              onPressed: () => DgtReportQuestionSheet.show(
                context: context,
                ref: ref,
                questionId: currentQ!.id,
              ),
            ),
        ],
      ),
      body: failuresAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return const _EmptyState();
          }
          if (_finished) {
            return _SummaryView(
              total: _totalAnswered,
              correct: _correctCount,
              onClose: () => Navigator.of(context).pop(),
            );
          }
          // Clamp por si la lista cambio entre rebuilds (raro).
          final idx = _current.clamp(0, entries.length - 1);
          final q = entries[idx].question;
          return _QuizView(
            question: q,
            index: idx,
            total: entries.length,
            picked: _picked[idx],
            onSelect: (l) => _select(l, q),
            onNext: () => _next(entries.length),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration_rounded,
                size: 64, color: Color(0xFF4FFFB0)),
            const SizedBox(height: 16),
            const Text(
              'No tienes fallos recientes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Sigue practicando. Si fallas alguna pregunta en los proximos '
              '7 dias, aparecera aqui para repasarla.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizView extends StatelessWidget {
  final DgtQuestion question;
  final int index;
  final int total;
  final String? picked;
  final void Function(String letter) onSelect;
  final VoidCallback onNext;

  const _QuizView({
    required this.question,
    required this.index,
    required this.total,
    required this.picked,
    required this.onSelect,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final answered = picked != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: (index + 1) / total,
              minHeight: 6,
            ),
            const SizedBox(height: 8),
            Text(
              'Pregunta ${index + 1} de $total',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      question.statement,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _OptionTile(
                      letter: 'a',
                      text: question.optionA,
                      picked: picked,
                      correct: question.correct,
                      onTap: () => onSelect('a'),
                    ),
                    _OptionTile(
                      letter: 'b',
                      text: question.optionB,
                      picked: picked,
                      correct: question.correct,
                      onTap: () => onSelect('b'),
                    ),
                    _OptionTile(
                      letter: 'c',
                      text: question.optionC,
                      picked: picked,
                      correct: question.correct,
                      onTap: () => onSelect('c'),
                    ),
                    if (answered && question.explanation != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          question.explanation!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            FilledButton(
              onPressed: answered ? onNext : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(index + 1 >= total ? 'Terminar' : 'Siguiente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String letter;
  final String text;
  final String? picked;
  final String correct;
  final VoidCallback onTap;

  const _OptionTile({
    required this.letter,
    required this.text,
    required this.picked,
    required this.correct,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final answered = picked != null;
    final isThisPicked = picked == letter;
    final isCorrectOption = letter == correct;
    Color border = Colors.white.withValues(alpha: 0.15);
    Color bg = const Color(0xFF1A1A22);
    if (answered) {
      if (isCorrectOption) {
        border = const Color(0xFF4FFFB0);
        bg = const Color(0xFF4FFFB0).withValues(alpha: 0.08);
      } else if (isThisPicked) {
        border = const Color(0xFFFF5C5C);
        bg = const Color(0xFFFF5C5C).withValues(alpha: 0.08);
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: answered ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: border.withValues(alpha: 0.2),
                  ),
                  child: Text(
                    letter.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(text, style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  final int total;
  final int correct;
  final VoidCallback onClose;

  const _SummaryView({
    required this.total,
    required this.correct,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final wrong = total - correct;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.task_alt_rounded,
                size: 64, color: Color(0xFF4FFFB0)),
            const SizedBox(height: 16),
            Text(
              'Repasaste $total fallo${total == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Acertaste $correct - Fallaste $wrong',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onClose,
              style: FilledButton.styleFrom(
                minimumSize: const Size(180, 48),
              ),
              child: const Text('Volver al inicio'),
            ),
          ],
        ),
      ),
    );
  }
}
