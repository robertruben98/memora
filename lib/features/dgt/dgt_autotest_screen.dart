import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/repositories/dgt_repository.dart';
import 'dgt_failures_repository.dart';

/// Issue #127 (dgt-ux): modo Autotest Mental DGT (active recall puro).
///
/// Muestra solo el enunciado + imagen de cada pregunta SIN las opciones a/b/c.
/// El usuario formula la respuesta mentalmente, pulsa "Ver respuesta correcta"
/// y luego auto-reporta acierto/fallo. Los fallos se registran en el repo
/// existente [DgtFailuresRepository] => integran con "Repaso de fallos".
///
/// Por que active recall sin opciones:
/// - Recognition (ver opciones) da pistas y reduce el esfuerzo cognitivo.
/// - Recall (formular sin pistas) consolida memoria a largo plazo (literatura
///   de aprendizaje: SQ3R, retrieval practice).
///
/// Pool: 20 preguntas random del banco (reusa [fetchExamQuestions] que ya
/// devuelve un random sample del banco completo, con cache + fallback local).
///
/// Aditivo: no toca el flujo de practice/exam/quick-review. Cero cambios al
/// backend. Reusa providers existentes (`dgtRepositoryProvider`,
/// `dgtFailuresRepositoryProvider`).
class DgtAutotestScreen extends ConsumerStatefulWidget {
  static const int questionCount = 20;

  const DgtAutotestScreen({super.key});

  @override
  ConsumerState<DgtAutotestScreen> createState() => _DgtAutotestScreenState();
}

class _DgtAutotestScreenState extends ConsumerState<DgtAutotestScreen> {
  late Future<List<DgtQuestion>> _future;
  List<DgtQuestion> _questions = const [];

  int _current = 0;
  bool _revealed = false;
  bool _finished = false;

  /// Auto-reporte por indice: true=acerto, false=fallo, null=sin reportar.
  final Map<int, bool> _selfReport = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<DgtQuestion>> _load() {
    final repo = ref.read(dgtRepositoryProvider);
    return repo
        .fetchExamQuestions(limit: DgtAutotestScreen.questionCount)
        .then((qs) {
      _questions = qs;
      return qs;
    });
  }

  void _reveal() {
    setState(() => _revealed = true);
  }

  Future<void> _report({required bool correct}) async {
    final q = _questions[_current];
    _selfReport[_current] = correct;
    if (!correct) {
      // Reusa el mismo repo de fallos que exam/practice => integra con repaso.
      final failures = ref.read(dgtFailuresRepositoryProvider);
      await failures.recordFailure(q);
    }
    if (!mounted) return;
    if (_current < _questions.length - 1) {
      setState(() {
        _current++;
        _revealed = false;
      });
    } else {
      setState(() => _finished = true);
    }
  }

  void _restart() {
    setState(() {
      _selfReport.clear();
      _current = 0;
      _revealed = false;
      _finished = false;
      _future = _load();
    });
  }

  int _hits() => _selfReport.values.where((v) => v).length;
  int _misses() => _selfReport.values.where((v) => !v).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Autotest mental'),
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
                  'No se pudieron cargar las preguntas: '
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
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
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
                const SizedBox(height: 18),
                if (!_revealed) _buildThinkPrompt() else _buildRevealedAnswer(q),
              ],
            ),
          ),
        ),
        _buildBottomActions(),
      ],
    );
  }

  Widget _buildThinkPrompt() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF7C5CFF).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF7C5CFF).withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.psychology_alt_rounded,
            color: Color(0xFFB9A6FF),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Piensa la respuesta mentalmente. Sin pistas: ni A, ni B, ni C. '
              'Cuando la tengas, revela.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevealedAnswer(DgtQuestion q) {
    final correctText = switch (q.correct) {
      'a' => q.optionA,
      'b' => q.optionB,
      'c' => q.optionC,
      _ => q.optionA,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF4FFFB0).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4FFFB0).withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF4FFFB0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  q.correct.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Respuesta correcta',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4FFFB0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            correctText,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          if ((q.explanation ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              q.explanation!.trim(),
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: !_revealed
            ? SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _reveal,
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('Ver respuesta correcta'),
                ),
              )
            : Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _report(correct: false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF5C5C),
                        side: const BorderSide(color: Color(0xFFFF5C5C)),
                      ),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Falle'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _report(correct: true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4FFFB0),
                        foregroundColor: Colors.black,
                      ),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Acerte'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSummary() {
    final total = _questions.length;
    final hits = _hits();
    final misses = _misses();
    final pct = total == 0 ? 0 : ((hits / total) * 100).round();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Icon(
              hits == total
                  ? Icons.emoji_events_rounded
                  : Icons.psychology_rounded,
              size: 64,
              color: hits == total
                  ? const Color(0xFFFFB74F)
                  : const Color(0xFF7C5CFF),
            ),
            const SizedBox(height: 12),
            const Text(
              'Autotest mental completado',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Self-report: aciertos / fallos',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatBox(label: 'Acerte', value: '$hits'),
                _StatBox(label: 'Falle', value: '$misses'),
                _StatBox(label: '%', value: '$pct%'),
              ],
            ),
            const SizedBox(height: 16),
            if (misses > 0)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB74F).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFFB74F).withValues(alpha: 0.30),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.replay_rounded,
                      color: Color(0xFFFFB74F),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$misses fallo${misses == 1 ? '' : 's'} guardado'
                        '${misses == 1 ? '' : 's'} en repaso de fallos.',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _restart,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Nuevo autotest'),
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
