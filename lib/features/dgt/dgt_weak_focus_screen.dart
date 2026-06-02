import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';

import '../../data/repositories/dgt_repository.dart';
import 'dgt_prediction.dart';
import 'dgt_session_summary_screen.dart';

/// Pantalla DGT "Quiz Intensivo Peor Tema" (issue #134, dgt-ux).
///
/// Consume `GET /dgt/quiz/weak-focus` via
/// [DgtRepository.fetchWeakFocusQuiz] (BE#93). El backend devuelve un quiz
/// adaptativo 50/50: mitad preguntas del worst_topic (menor accuracy en
/// ventana de 60 dias) + mitad del resto, mas el `worst_topic_id` y su
/// accuracy actual. Pensado para nivelar al alumno acelerando practica del
/// tema cronico sin aburrirlo.
///
/// La pantalla muestra:
/// - Chip "Foco: TEMA" con accuracy del usuario en ese tema.
/// - Flujo de pregunta + feedback inmediato (similar a Trick Questions).
/// - Empty state si el backend responde 400 (historial DGT insuficiente,
///   mensaje "necesitas mas practica general").
/// - Al terminar, navega a [DgtSessionSummaryScreen] con delta de accuracy
///   antes/despues (estimado: accuracy del quiz vs accuracy historica del
///   peor tema).
///
/// Aditivo: no toca [DgtPracticeScreen] ni [DgtExamScreen]. Reutiliza el
/// patron de feedback inline ya usado en otras pantallas DGT.
class DgtWeakFocusScreen extends ConsumerStatefulWidget {
  /// Numero de preguntas a pedir al backend. Clamp BE: [4, 50].
  final int n;

  const DgtWeakFocusScreen({super.key, this.n = 20});

  @override
  ConsumerState<DgtWeakFocusScreen> createState() =>
      _DgtWeakFocusScreenState();
}

class _DgtWeakFocusScreenState extends ConsumerState<DgtWeakFocusScreen> {
  late Future<DgtWeakFocusQuizResult> _future;
  DgtWeakFocusQuizResult? _result;

  /// Letra elegida por pregunta (null = sin responder).
  final Map<int, String> _picked = {};
  int _current = 0;
  bool _finished = false;
  bool _summaryNavigated = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<DgtWeakFocusQuizResult> _load() {
    final repo = ref.read(dgtRepositoryProvider);
    return repo.fetchWeakFocusQuiz(n: widget.n).then((r) {
      _result = r;
      return r;
    });
  }

  void _restart() {
    setState(() {
      _picked.clear();
      _current = 0;
      _finished = false;
      _summaryNavigated = false;
      _future = _load();
    });
  }

  void _selectAnswer(String letter, List<DgtQuestion> qs) {
    if (_picked.containsKey(_current)) return;
    setState(() => _picked[_current] = letter);
  }

  void _next(List<DgtQuestion> qs) {
    if (_current < qs.length - 1) {
      setState(() => _current++);
    } else {
      setState(() => _finished = true);
    }
  }

  int _correctCount(List<DgtQuestion> qs) {
    var c = 0;
    for (var i = 0; i < qs.length; i++) {
      final p = _picked[i];
      if (p != null && p == qs[i].correct) c++;
    }
    return c;
  }

  /// Nombre humano del worst topic: si lo tenemos en cache via
  /// [dgtTopicStatsProvider] (issue #67), usamos el `topic_name`; si no,
  /// caemos al `topic_id` directamente.
  String _worstTopicName(WidgetRef ref) {
    final id = _result?.worstTopicId ?? '';
    if (id.isEmpty) return '';
    final statsAsync = ref.read(dgtTopicStatsProvider);
    final stats = statsAsync.maybeWhen(data: (s) => s, orElse: () => null);
    if (stats != null) {
      for (final s in stats) {
        if (s.topicId == id) {
          final name = s.topicName;
          if (name != null && name.isNotEmpty) return name;
          break;
        }
      }
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Atacar mi punto debil'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<DgtWeakFocusQuizResult>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final result = snap.data;
          if (result == null) {
            return _empty(
              message: 'Error cargando el quiz. Reintenta en unos segundos.',
              icon: Icons.cloud_off_rounded,
            );
          }
          if (result.insufficientData) {
            return _empty(
              message:
                  'Aun no tenemos suficiente historial para identificar tu '
                  'peor tema. Necesitas mas practica general '
                  '(al menos 20 respuestas DGT y 5 por tema).',
              icon: Icons.psychology_outlined,
            );
          }
          if (result.questions.isEmpty) {
            return _empty(
              message:
                  'No hay preguntas disponibles para el peor tema ahora '
                  'mismo. Reintenta o vuelve mas tarde.',
              icon: Icons.cloud_off_rounded,
            );
          }
          if (_finished) {
            // Navega al session summary una sola vez. Mientras tanto pintamos
            // un placeholder ligero (Spinner) para no parpadear.
            _maybeNavigateToSummary(context, result);
            return const Center(child: CircularProgressIndicator());
          }
          return _buildQuestion(result);
        },
      ),
    );
  }

  void _maybeNavigateToSummary(
    BuildContext context,
    DgtWeakFocusQuizResult result,
  ) {
    if (_summaryNavigated) return;
    _summaryNavigated = true;
    // Diferimos al siguiente frame para evitar navegar durante el build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final qs = result.questions;
      final correct = _correctCount(qs);
      final total = qs.length;
      final sessionAccPct =
          total == 0 ? 0.0 : (correct / total) * 100.0;
      final delta = sessionAccPct - result.worstTopicAccuracyPct;
      final deltaSign = delta >= 0 ? '+' : '';
      final deltaTxt = '$deltaSign${delta.toStringAsFixed(1)}%';
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DgtSessionSummaryScreen(
            topicName:
                'Foco: ${_worstTopicName(ref)} (delta $deltaTxt)',
            answeredCount: total,
            correctCount: correct,
            elapsed: Duration.zero,
            weakestTopic: _worstTopicName(ref),
          ),
        ),
      );
    });
  }

  Widget _empty({required String message, required IconData icon}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFFFB74F), size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion(DgtWeakFocusQuizResult result) {
    final qs = result.questions;
    if (_current >= qs.length) _current = qs.length - 1;
    final q = qs[_current];
    final picked = _picked[_current];
    final answered = picked != null;

    return Column(
      children: [
        LinearProgressIndicator(
          value: (_current + 1) / qs.length,
          minHeight: 4,
          backgroundColor: context.c.surfaceMuted,
          valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6B35)),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DgtWeakFocusHeaderChip(
                  topicName: _worstTopicName(ref),
                  accuracyPct: result.worstTopicAccuracyPct,
                ),
                const SizedBox(height: 10),
                Text(
                  'Pregunta ${_current + 1} / ${qs.length}',
                  style: TextStyle(
                    color: context.c.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  q.statement,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                _WeakFocusAnswerTile(
                  letter: 'a',
                  text: q.optionA,
                  picked: picked,
                  correct: q.correct,
                  answered: answered,
                  onTap: () => _selectAnswer('a', qs),
                ),
                _WeakFocusAnswerTile(
                  letter: 'b',
                  text: q.optionB,
                  picked: picked,
                  correct: q.correct,
                  answered: answered,
                  onTap: () => _selectAnswer('b', qs),
                ),
                _WeakFocusAnswerTile(
                  letter: 'c',
                  text: q.optionC,
                  picked: picked,
                  correct: q.correct,
                  answered: answered,
                  onTap: () => _selectAnswer('c', qs),
                ),
                if (answered) ...[
                  const SizedBox(height: 16),
                  _ExplanationCard(question: q, picked: picked),
                ],
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              children: [
                const Spacer(),
                FilledButton.icon(
                  onPressed: answered ? () => _next(qs) : null,
                  icon: Icon(_current == qs.length - 1
                      ? Icons.flag_rounded
                      : Icons.chevron_right_rounded),
                  label: Text(_current == qs.length - 1
                      ? 'Ver resumen'
                      : 'Siguiente'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Chip de cabecera en la pantalla weak-focus mostrando el tema y la
/// accuracy actual del usuario en ese tema. Public para tests directos.
class DgtWeakFocusHeaderChip extends StatelessWidget {
  final String topicName;
  final double accuracyPct;

  const DgtWeakFocusHeaderChip({
    super.key,
    required this.topicName,
    required this.accuracyPct,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accuracyPct < 50
        ? const Color(0xFFFF5C5C)
        : accuracyPct < 75
            ? const Color(0xFFFFB74F)
            : const Color(0xFF4FFFB0);
    final accStr = accuracyPct.toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gps_fixed_rounded, color: accent, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Foco: $topicName  ·  $accStr% acierto',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: accent,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeakFocusAnswerTile extends StatelessWidget {
  final String letter;
  final String text;
  final String? picked;
  final String correct;
  final bool answered;
  final VoidCallback onTap;

  const _WeakFocusAnswerTile({
    required this.letter,
    required this.text,
    required this.picked,
    required this.correct,
    required this.answered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = picked == letter;
    final isCorrectOption = letter == correct;

    Color bg = context.c.surfaceMuted;
    Color iconBg = context.c.border;
    Color iconFg = context.c.textPrimary;

    if (answered) {
      if (isCorrectOption) {
        bg = const Color(0xFF4FFFB0).withValues(alpha: 0.18);
        iconBg = const Color(0xFF4FFFB0);
        iconFg = Colors.black;
      } else if (selected) {
        bg = const Color(0xFFFF5C5C).withValues(alpha: 0.18);
        iconBg = const Color(0xFFFF5C5C);
        iconFg = Colors.white;
      }
    } else if (selected) {
      bg = AppColors.brand;
      iconFg = Colors.white;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: answered ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    letter.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: iconFg,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 15, height: 1.35),
                  ),
                ),
                if (answered && isCorrectOption)
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF4FFFB0), size: 20)
                else if (answered && selected && !isCorrectOption)
                  const Icon(Icons.cancel_rounded,
                      color: Color(0xFFFF5C5C), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  final DgtQuestion question;
  final String picked;
  const _ExplanationCard({required this.question, required this.picked});

  @override
  Widget build(BuildContext context) {
    final isCorrect = picked == question.correct;
    final accent =
        isCorrect ? const Color(0xFF4FFFB0) : const Color(0xFFFF8A4F);
    final base = (question.explanation ?? '').trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect
                    ? Icons.check_circle_rounded
                    : Icons.lightbulb_rounded,
                color: accent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'Correcto' : 'Fallaste, repasa',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Respuesta correcta: ${question.correct.toUpperCase()}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          if (base.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              base,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: context.c.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
