import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';

import '../../data/repositories/dgt_repository.dart';

/// Palabras clave trampa que las DGT marca como las que mas suspenden en el
/// examen real 2026 (issue #74). Visibles publicamente para tests.
const dgtTrickKeywords = <String>{
  'siempre',
  'nunca',
  'excepto',
  'solo',
  'solo,',
  'sólo',
  'unicamente',
  'únicamente',
};

/// Pantalla DGT "Trampas frecuentes" (issue #74).
///
/// Consume `GET /dgt/quiz/trick-questions` via [DgtRepository.fetchTrickQuestions]
/// y muestra preguntas con palabras clave trampa
/// (siempre/nunca/excepto/solo) resaltadas visualmente en el enunciado
/// con [RichText]. Cuando el usuario falla, el panel de feedback explica
/// POR QUE la trampa engano: ej. "siempre" suele ser falso en normativa.
///
/// Aditivo: no toca [DgtPracticeScreen] ni el endpoint de preguntas por tema.
class DgtTrickQuestionsScreen extends ConsumerStatefulWidget {
  /// Numero maximo de preguntas a cargar. -1 = sin limite (todas).
  final int limit;

  const DgtTrickQuestionsScreen({super.key, this.limit = 20});

  @override
  ConsumerState<DgtTrickQuestionsScreen> createState() =>
      _DgtTrickQuestionsScreenState();
}

class _DgtTrickQuestionsScreenState
    extends ConsumerState<DgtTrickQuestionsScreen> {
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
    final lim = widget.limit > 0 ? widget.limit : 20;
    return repo.fetchTrickQuestions(limit: lim).then((qs) {
      _questions = qs;
      return qs;
    });
  }

  void _selectAnswer(String letter) {
    if (_picked.containsKey(_current)) return;
    setState(() => _picked[_current] = letter);
  }

  void _next() {
    if (_current < _questions.length - 1) {
      setState(() => _current++);
    } else {
      setState(() => _finished = true);
    }
  }

  void _restart() {
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
        title: const Text('Trampas frecuentes'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<List<DgtQuestion>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? const <DgtQuestion>[];
          if (snap.hasError && list.isEmpty) {
            return _empty(message: 'Error cargando preguntas trampa.');
          }
          if (list.isEmpty) {
            return _empty(
              message:
                  'Aun no hay preguntas trampa. Reintenta o vuelve mas tarde.',
            );
          }
          if (_finished) return _buildSummary();
          return _buildQuestion();
        },
      ),
    );
  }

  Widget _empty({required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFFFB74F), size: 48),
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
          backgroundColor: context.c.surfaceMuted,
          valueColor: const AlwaysStoppedAnimation(Color(0xFFFFB74F)),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _AntiTrampaBadge(),
                const SizedBox(height: 10),
                Text(
                  'Pregunta ${_current + 1} / ${qs.length}',
                  style: TextStyle(
                    color: context.c.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                DgtTrickHighlightedStatement(text: q.statement),
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
                  _TrickExplanationCard(question: q, isCorrect: isCorrect),
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
                  : Icons.psychology_alt_rounded,
              size: 64,
              color: const Color(0xFFFFB74F),
            ),
            const SizedBox(height: 12),
            const Text(
              'Trampas frecuentes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Resumen de sesion anti-trampa',
              style: TextStyle(color: context.c.textSecondary),
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
                onPressed: _restart,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Repetir trampas'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Volver'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renderiza el enunciado con las palabras trampa
/// (siempre/nunca/excepto/solo) resaltadas en negrita y color de alerta.
/// Public para tests directos.
class DgtTrickHighlightedStatement extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;

  const DgtTrickHighlightedStatement({
    super.key,
    required this.text,
    this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    final base = baseStyle ??
        const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.35);
    return RichText(
      text: TextSpan(
        style: base,
        children: _buildSpans(text, base),
      ),
    );
  }

  static List<TextSpan> _buildSpans(String text, TextStyle base) {
    final spans = <TextSpan>[];
    // Detecta palabras trampa case-insensitive (incluye acentos opcionales).
    final regex = RegExp(
      r'\b(siempre|nunca|excepto|solo|s[oó]lo|[uú]nicamente)\b',
      caseSensitive: false,
      unicode: true,
    );
    var last = 0;
    for (final m in regex.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(TextSpan(
        text: text.substring(m.start, m.end),
        style: base.merge(const TextStyle(
          color: Color(0xFFFFB74F),
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.underline,
          decorationColor: Color(0xFFFFB74F),
        )),
      ));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return spans;
  }
}

class _AntiTrampaBadge extends StatelessWidget {
  const _AntiTrampaBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB74F).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFFFFB74F).withValues(alpha: 0.45),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 14, color: Color(0xFFFFB74F)),
          SizedBox(width: 6),
          Text(
            'Anti-trampa',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFFB74F),
              letterSpacing: 0.3,
            ),
          ),
        ],
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

    Color bg = context.c.surfaceMuted;
    Color iconBg = context.c.surfaceMuted;
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

/// Panel de explicacion al responder en pantalla trampas.
///
/// Si la respuesta es incorrecta, anade un texto especifico sobre POR QUE
/// la palabra trampa engano (ej. "siempre" suele ser falso en normativa
/// real, casi todo tiene excepciones).
class _TrickExplanationCard extends StatelessWidget {
  final DgtQuestion question;
  final bool isCorrect;

  const _TrickExplanationCard({required this.question, required this.isCorrect});

  @override
  Widget build(BuildContext context) {
    final base = (question.explanation ?? '').trim();
    final trickReason = isCorrect ? '' : DgtTrickReasoning.forStatement(question.statement);
    final accent =
        isCorrect ? const Color(0xFF4FFFB0) : const Color(0xFFFFB74F);
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
                isCorrect ? 'Correcto, no caiste' : 'Trampa detectada',
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
          if (trickReason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              trickReason,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: context.c.textPrimary,
              ),
            ),
          ],
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

/// Razonamientos pre-escritos por palabra trampa. Public para tests.
class DgtTrickReasoning {
  static String forStatement(String statement) {
    final lower = statement.toLowerCase();
    if (lower.contains('siempre')) {
      return 'Atencion: la palabra "siempre" suele ser una trampa. En '
          'normativa real casi todo tiene excepciones (urgencias, agentes, '
          'condiciones especiales), por lo que afirmaciones absolutas suelen '
          'ser falsas.';
    }
    if (lower.contains('nunca')) {
      return 'Atencion: "nunca" tambien suele ser una trampa. Casi ninguna '
          'norma es absoluta: agentes, urgencias o senalizacion expresa '
          'pueden cambiar la regla.';
    }
    if (lower.contains('excepto')) {
      return 'Atencion: "excepto" introduce una excepcion. Lee con cuidado '
          'que queda fuera de la regla, suele ser el punto clave.';
    }
    if (lower.contains('solo') || lower.contains('sólo')) {
      return 'Atencion: "solo" restringe la accion a un unico caso. '
          'Comprueba si existen otros supuestos validos antes de descartar '
          'las demas opciones.';
    }
    if (lower.contains('unicamente') || lower.contains('únicamente')) {
      return 'Atencion: "unicamente" es restrictivo. Verifica que no haya '
          'otros casos validos no contemplados en el enunciado.';
    }
    return '';
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
            color: context.c.textSecondary,
          ),
        ),
      ],
    );
  }
}

