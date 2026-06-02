import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/memora_card.dart';
import 'dgt_exam_history.dart';
import 'dgt_exam_screen.dart';
import 'dgt_history_screen.dart';

/// Resultado del simulacro DGT: score, veredicto, tiempo y revision.
class DgtExamAnswer {
  final MemoraCard card;
  final bool correct;
  final bool answered;

  const DgtExamAnswer({
    required this.card,
    required this.correct,
    required this.answered,
  });
}

class DgtExamResultScreen extends ConsumerStatefulWidget {
  final List<DgtExamAnswer> answers;
  final Duration timeUsed;
  final bool expired;

  const DgtExamResultScreen({
    super.key,
    required this.answers,
    required this.timeUsed,
    this.expired = false,
  });

  @override
  ConsumerState<DgtExamResultScreen> createState() =>
      _DgtExamResultScreenState();
}

class _DgtExamResultScreenState extends ConsumerState<DgtExamResultScreen> {
  bool _persisted = false;

  @override
  void initState() {
    super.initState();
    // Persistir el simulacro completado una sola vez al entrar a la pantalla
    // de resultado. Best-effort: si falla no rompe la UI.
    WidgetsBinding.instance.addPostFrameCallback((_) => _persistEntry());
  }

  Future<void> _persistEntry() async {
    if (_persisted) return;
    _persisted = true;
    final answers = widget.answers;
    if (answers.isEmpty) return;
    final correct = answers.where((a) => a.correct).length;
    final failed = answers.length - correct;
    final passed = failed <= DgtExamScreen.passingThreshold;
    final entry = DgtExamHistoryEntry(
      date: DateTime.now(),
      correct: correct,
      total: answers.length,
      timeUsed: widget.timeUsed,
      passed: passed,
    );
    try {
      final repo = ref.read(dgtExamHistoryRepositoryProvider);
      await repo.append(entry);
      // Refrescar provider para que la pantalla de historial vea la entrada
      // nueva sin reiniciar la app.
      if (mounted) ref.invalidate(dgtExamHistoryProvider);
    } catch (_) {
      // best-effort
    }
  }

  int get _correct => widget.answers.where((a) => a.correct).length;
  int get _failed => widget.answers.length - _correct;
  bool get _passed => _failed <= DgtExamScreen.passingThreshold;

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final answers = widget.answers;
    final timeUsed = widget.timeUsed;
    final expired = widget.expired;
    final wrong = answers.where((a) => !a.correct).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado simulacro'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Compartir resultado',
            icon: const Icon(Icons.share_rounded),
            onPressed: () => _share(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _ScoreCard(
              correct: _correct,
              total: answers.length,
              passed: _passed,
              timeUsed: _fmtDuration(timeUsed),
              expired: expired,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const DgtExamScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Repetir simulacro'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: wrong.isEmpty
                        ? null
                        : () => _showReview(context, wrong),
                    icon: const Icon(Icons.error_outline_rounded),
                    label: Text('Revisar falladas (${wrong.length})'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (wrong.isEmpty)
              _AllCorrectBanner()
            else ...[
              const Text(
                'Preguntas falladas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              for (final a in wrong)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _WrongTile(answer: a),
                ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DgtHistoryScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: const Text('Ver historial'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).popUntil(
                    (r) => r.isFirst,
                  ),
                  child: const Text('Volver al inicio'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Genera el texto para compartir y lo expone via share_plus.
  ///
  /// Formato aprobado:   "Simulacro DGT - 27/30 (APROBADO) en 18:42. RutaB App."
  /// Formato suspenso:   "Simulacro DGT - 22/30 (SUSPENSO) en 18:42. RutaB App."
  /// Incluye emojis discretos (check verde / libro). No expone datos personales.
  String _buildShareText() {
    final total = widget.answers.length;
    final time = _fmtDuration(widget.timeUsed);
    final emoji = _passed ? '✅' : '📚';
    final veredicto = _passed ? 'APROBADO' : 'SUSPENSO';
    return '$emoji Simulacro DGT - $_correct/$total ($veredicto) en $time. RutaB App.';
  }

  Future<void> _share(BuildContext context) async {
    final text = _buildShareText();
    await Share.share(text, subject: 'Resultado simulacro DGT');
  }

  void _showReview(BuildContext context, List<DgtExamAnswer> wrong) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ReviewWrongScreen(answers: wrong),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final int correct;
  final int total;
  final bool passed;
  final String timeUsed;
  final bool expired;

  const _ScoreCard({
    required this.correct,
    required this.total,
    required this.passed,
    required this.timeUsed,
    required this.expired,
  });

  @override
  Widget build(BuildContext context) {
    final color = passed
        ? DgtStatusColors.success
        : Colors.redAccent.shade200;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                passed
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: color,
                size: 36,
              ),
              const SizedBox(width: 12),
              Text(
                passed ? 'Aprobado' : 'Suspenso',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$correct/$total correctas',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Criterio DGT: maximo 3 fallos para aprobar',
            style: TextStyle(
              fontSize: 12,
              color: context.c.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 16, color: context.c.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Tiempo usado: $timeUsed',
                style: TextStyle(fontSize: 13, color: context.c.textSecondary),
              ),
              if (expired) ...[
                const SizedBox(width: 10),
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Colors.amber,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Tiempo agotado',
                  style: TextStyle(fontSize: 12, color: Colors.amber),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AllCorrectBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DgtStatusColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DgtStatusColors.success),
      ),
      child: const Row(
        children: [
          Icon(Icons.emoji_events_rounded, color: DgtStatusColors.success),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Examen perfecto. Sin fallos para revisar.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _WrongTile extends StatelessWidget {
  final DgtExamAnswer answer;
  const _WrongTile({required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.c.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.cancel_outlined,
                color: Colors.redAccent,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                answer.answered ? 'Marcaste incorrecta' : 'Sin responder',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            answer.card.front,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Explicacion: ${answer.card.back}',
            style: TextStyle(
              fontSize: 13,
              color: context.c.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewWrongScreen extends StatelessWidget {
  final List<DgtExamAnswer> answers;
  const _ReviewWrongScreen({required this.answers});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Revisar falladas (${answers.length})')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: answers.length,
        separatorBuilder: (context, i) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _WrongTile(answer: answers[i]),
      ),
    );
  }
}
