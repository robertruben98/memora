import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/repositories/dgt_repository.dart';

/// Modo practica DGT por tema: sin cronometro, feedback inmediato y
/// explicacion al fallar (inline). Aditivo respecto a [DgtExamScreen]; no
/// comparte estado ni rompe el flujo del simulacro cronometrado.
class DgtPracticeScreen extends ConsumerStatefulWidget {
  final DgtTopic topic;

  /// Numero de preguntas a cargar. Si es <=0 (p.ej. -1), no se aplica limit
  /// y se piden todas las del tema.
  final int limit;

  const DgtPracticeScreen({
    super.key,
    required this.topic,
    required this.limit,
  });

  @override
  ConsumerState<DgtPracticeScreen> createState() => _DgtPracticeScreenState();
}

class _DgtPracticeScreenState extends ConsumerState<DgtPracticeScreen> {
  late Future<List<DgtQuestion>> _future;
  List<DgtQuestion> _questions = const [];

  /// Letra elegida por pregunta (null = sin responder).
  final Map<int, String> _picked = {};
  int _current = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<DgtQuestion>> _load() {
    final repo = ref.read(dgtRepositoryProvider);
    final lim = widget.limit > 0 ? widget.limit : null;
    return repo
        .fetchQuestionsByTopic(topicId: widget.topic.id, limit: lim)
        .then((qs) {
      _questions = qs;
      return qs;
    });
  }

  void _selectAnswer(String letter) {
    if (_picked.containsKey(_current)) return; // ya respondida
    setState(() => _picked[_current] = letter);
  }

  void _next() {
    if (_current < _questions.length - 1) {
      setState(() => _current++);
    } else {
      setState(() => _finished = true);
    }
  }

  void _repeatTopic() {
    setState(() {
      _picked.clear();
      _current = 0;
      _finished = false;
      _future = _load();
    });
  }

  int _correctCount() {
    var c = 0;
    for (var i = 0; i < _questions.length; i++) {
      final p = _picked[i];
      if (p != null && p == _questions[i].correct) c++;
    }
    return c;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topic.name),
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
                  'No hay preguntas para este tema: '
                  '${snap.error ?? "lista vacia"}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (_finished) return _buildSummary();
          return _buildQuestion();
        },
      ),
    );
  }

  Widget _buildQuestion() {
    final qs = _questions;
    if (_current >= qs.length) _current = qs.length - 1;
    final q = qs[_current];
    final picked = _picked[_current];
    final answered = picked != null;
    final isCorrect = answered && picked == q.correct;

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
                Text(
                  'Pregunta ${_current + 1} / ${qs.length}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
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
                  picked: picked,
                  correct: q.correct,
                  answered: answered,
                  onTap: () => _selectAnswer('a'),
                ),
                _AnswerTile(
                  letter: 'b',
                  text: q.optionB,
                  picked: picked,
                  correct: q.correct,
                  answered: answered,
                  onTap: () => _selectAnswer('b'),
                ),
                _AnswerTile(
                  letter: 'c',
                  text: q.optionC,
                  picked: picked,
                  correct: q.correct,
                  answered: answered,
                  onTap: () => _selectAnswer('c'),
                ),
                if (answered) ...[
                  const SizedBox(height: 16),
                  _ExplanationCard(question: q, isCorrect: isCorrect),
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
                  onPressed: answered ? _next : null,
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

  Widget _buildSummary() {
    final total = _questions.length;
    final correct = _correctCount();
    final wrong = total - correct;
    final pct = total == 0 ? 0 : ((correct / total) * 100).round();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Icon(
              correct == total
                  ? Icons.emoji_events_rounded
                  : Icons.check_circle_outline_rounded,
              size: 64,
              color: correct == total
                  ? const Color(0xFFFFB74F)
                  : const Color(0xFF7C5CFF),
            ),
            const SizedBox(height: 12),
            Text(
              widget.topic.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Resumen practica',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatBox(label: 'Aciertos', value: '$correct'),
                _StatBox(label: 'Fallos', value: '$wrong'),
                _StatBox(label: '%', value: '$pct%'),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _repeatTopic,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Repetir tema'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Cambiar tema'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerTile extends StatelessWidget {
  final String letter;
  final String text;
  final String? picked;
  final String correct;
  final bool answered;
  final VoidCallback onTap;

  const _AnswerTile({
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

    Color bg = Colors.white.withValues(alpha: 0.08);
    Color iconBg = Colors.white.withValues(alpha: 0.12);
    Color iconFg = Colors.white;

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
      bg = const Color(0xFF7C5CFF);
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF4FFFB0),
                    size: 20,
                  )
                else if (answered && selected && !isCorrectOption)
                  const Icon(
                    Icons.cancel_rounded,
                    color: Color(0xFFFF5C5C),
                    size: 20,
                  ),
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
  final bool isCorrect;

  const _ExplanationCard({required this.question, required this.isCorrect});

  static const _fallbackText =
      'Sin explicacion adicional. Repasa el Reglamento General de '
      'Circulacion en la web oficial de la DGT.';

  @override
  Widget build(BuildContext context) {
    final explanation = (question.explanation ?? '').trim();
    final txt = explanation.isNotEmpty ? explanation : _fallbackText;
    final accent =
        isCorrect ? const Color(0xFF4FFFB0) : const Color(0xFFFF8A4F);
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
                isCorrect ? Icons.check_circle_rounded : Icons.menu_book_rounded,
                color: accent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'Correcto' : 'Repasemos',
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
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            txt,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
      ],
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
