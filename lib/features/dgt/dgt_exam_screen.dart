import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/repositories/dgt_repository.dart';
import 'dgt_prediction.dart';
import 'dgt_result_screen.dart';

/// Pantalla principal del simulacro DGT permiso B.
/// - 30 preguntas, 30 min, criterio aprobado <=3 fallos.
class DgtExamScreen extends ConsumerStatefulWidget {
  const DgtExamScreen({super.key});

  @override
  ConsumerState<DgtExamScreen> createState() => _DgtExamScreenState();
}

class _DgtExamScreenState extends ConsumerState<DgtExamScreen> {
  static const _totalSeconds = 30 * 60;

  Future<List<DgtQuestion>>? _future;
  List<DgtQuestion> _questions = const [];
  final Map<int, String> _answers = {};
  final Set<int> _flagged = {};
  int _current = 0;
  int _secondsLeft = _totalSeconds;
  Timer? _ticker;
  bool _submitted = false;

  /// Issue #52: el simulacro arranca con una landing que muestra la
  /// prediccion + boton "Empezar simulacro". El fetch y el timer
  /// SOLO se inician cuando el usuario pulsa "Empezar".
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // No prefetch: esperamos a que el usuario pulse "Empezar simulacro"
    // tras leer su prediccion. Esto evita gastar bandwidth para usuarios
    // que entran solo a consultar progreso.
  }

  void _startExam() {
    if (_started) return;
    final repo = ref.read(dgtRepositoryProvider);
    setState(() {
      _started = true;
      _future = repo.fetchExamQuestions(limit: 30).then((qs) {
        _questions = qs;
        _startTimer();
        return qs;
      });
    });
  }

  void _startTimer() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _secondsLeft = _secondsLeft - 1;
        if (_secondsLeft <= 0) {
          _ticker?.cancel();
          _submit(autoSubmit: true);
        }
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatTime(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  Color _timerColor() {
    if (_secondsLeft <= 5 * 60) return const Color(0xFFFF5C5C);
    return Colors.white;
  }

  void _selectAnswer(String letter) {
    setState(() => _answers[_current] = letter);
  }

  void _toggleFlag() {
    setState(() {
      if (_flagged.contains(_current)) {
        _flagged.remove(_current);
      } else {
        _flagged.add(_current);
      }
    });
  }

  void _go(int index) {
    if (index < 0 || index >= _questions.length) return;
    setState(() => _current = index);
  }

  Future<void> _confirmFinish() async {
    final unanswered = _questions.length - _answers.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminar simulacro'),
        content: Text(
          unanswered == 0
              ? 'Vas a entregar el examen. ¿Continuar?'
              : 'Te quedan $unanswered preguntas sin responder. '
                  'Las sin responder cuentan como falladas. ¿Entregar igual?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Entregar'),
          ),
        ],
      ),
    );
    if (ok == true) _submit();
  }

  void _submit({bool autoSubmit = false}) {
    if (_submitted) return;
    _submitted = true;
    _ticker?.cancel();
    final result = _buildResult();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DgtResultScreen(
          result: result,
          autoSubmitted: autoSubmit,
        ),
      ),
    );
  }

  DgtExamResult _buildResult() {
    int correct = 0;
    final wrong = <DgtAnswerReview>[];
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final picked = _answers[i];
      final ok = picked != null && picked == q.correct;
      if (ok) {
        correct++;
      } else {
        wrong.add(DgtAnswerReview(question: q, picked: picked));
      }
    }
    return DgtExamResult(
      total: _questions.length,
      correct: correct,
      wrong: wrong,
    );
  }

  void _showQuestionGrid() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A22),
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
                  children: List.generate(_questions.length, (i) {
                    final answered = _answers.containsKey(i);
                    final flagged = _flagged.contains(i);
                    final isCurrent = i == _current;
                    Color bg;
                    if (isCurrent) {
                      bg = const Color(0xFF7C5CFF);
                    } else if (flagged) {
                      bg = const Color(0xFFFFB74F);
                    } else if (answered) {
                      bg = const Color(0xFF4FFFB0).withValues(alpha: 0.35);
                    } else {
                      bg = Colors.white.withValues(alpha: 0.08);
                    }
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _go(i);
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
                _legendRow(const Color(0xFF7C5CFF), 'Actual'),
                _legendRow(
                    const Color(0xFF4FFFB0).withValues(alpha: 0.35), 'Respondida'),
                _legendRow(const Color(0xFFFFB74F), 'Marcada'),
                _legendRow(
                    Colors.white.withValues(alpha: 0.08), 'Sin responder'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _legendRow(Color c, String label) {
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

  /// Landing pre-simulacro: prediccion (#52) + boton "Empezar simulacro".
  /// Se muestra hasta que el usuario pulsa "Empezar".
  Widget _buildLanding(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      children: [
        // Banner prediccion: tema mas debil + CTA practicar.
        DgtPredictionCard(
          onPractice: (topicId) {
            // Fallback segun issue #52: si no hay deeplink al modo
            // practica por tema, hacemos scroll al boton de empezar.
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Modo practica del tema "$topicId" proximamente. '
                  'Mientras tanto, este simulacro lo cubre.',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Simulacro DGT',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '30 preguntas, 30 minutos. Aprobado con max 3 fallos.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _startExam,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Empezar simulacro'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) {
      return Scaffold(
        appBar: AppBar(title: const Text('Simulacro DGT')),
        body: _buildLanding(context),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulacro DGT'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                _formatTime(_secondsLeft),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: _timerColor(),
                ),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<DgtQuestion>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
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
          final qs = snap.data!;
          if (_current >= qs.length) _current = qs.length - 1;
          final q = qs[_current];
          final picked = _answers[_current];
          return Column(
            children: [
              LinearProgressIndicator(
                value: (_current + 1) / qs.length,
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Pregunta ${_current + 1} / ${qs.length}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: _flagged.contains(_current)
                                ? 'Desmarcar'
                                : 'Marcar para revisar',
                            onPressed: _toggleFlag,
                            icon: Icon(
                              _flagged.contains(_current)
                                  ? Icons.flag_rounded
                                  : Icons.outlined_flag_rounded,
                              color: _flagged.contains(_current)
                                  ? const Color(0xFFFFB74F)
                                  : null,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Ver panel de preguntas',
                            onPressed: _showQuestionGrid,
                            icon: const Icon(Icons.grid_view_rounded),
                          ),
                        ],
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
                          child: _DgtImage(path: q.imageUrl!),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _AnswerTile(
                        letter: 'a',
                        text: q.optionA,
                        selected: picked == 'a',
                        onTap: () => _selectAnswer('a'),
                      ),
                      _AnswerTile(
                        letter: 'b',
                        text: q.optionB,
                        selected: picked == 'b',
                        onTap: () => _selectAnswer('b'),
                      ),
                      _AnswerTile(
                        letter: 'c',
                        text: q.optionC,
                        selected: picked == 'c',
                        onTap: () => _selectAnswer('c'),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            _current > 0 ? () => _go(_current - 1) : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                        label: const Text('Anterior'),
                      ),
                      const Spacer(),
                      if (_current < qs.length - 1)
                        FilledButton.icon(
                          onPressed: () => _go(_current + 1),
                          icon: const Icon(Icons.chevron_right_rounded),
                          label: const Text('Siguiente'),
                        )
                      else
                        FilledButton.icon(
                          onPressed: _confirmFinish,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4FFFB0),
                            foregroundColor: Colors.black,
                          ),
                          icon: const Icon(Icons.check_circle_rounded),
                          label: const Text('Terminar'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnswerTile extends StatelessWidget {
  final String letter;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _AnswerTile({
    required this.letter,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? const Color(0xFF7C5CFF)
        : Colors.white.withValues(alpha: 0.08);
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
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    letter.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: selected ? const Color(0xFF7C5CFF) : Colors.white,
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

class _DgtImage extends ConsumerWidget {
  final String path;
  const _DgtImage({required this.path});

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
        color: Colors.white.withValues(alpha: 0.05),
        child: const Icon(Icons.image_not_supported_outlined),
      ),
    );
  }
}
