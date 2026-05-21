import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/repositories/dgt_repository.dart';
import 'dgt_simulacro_review_screen.dart';

class DgtAnswerReview {
  final DgtQuestion question;
  final String? picked;
  DgtAnswerReview({required this.question, this.picked});
}

class DgtExamResult {
  final int total;
  final int correct;
  final List<DgtAnswerReview> wrong;

  /// Segundos reales empleados en el examen (issue #87 modo estricto).
  /// Si null, no se muestra ("tiempo usado") -- modo estandar legacy.
  final int? elapsedSeconds;

  /// Si el examen se hizo en modo "Examen real" estricto (issue #87).
  final bool strictMode;

  const DgtExamResult({
    required this.total,
    required this.correct,
    required this.wrong,
    this.elapsedSeconds,
    this.strictMode = false,
  });

  int get wrongCount => total - correct;
  // Criterio oficial DGT permiso B: hasta 3 fallos para aprobar.
  bool get passed => wrongCount <= 3;
}

class DgtResultScreen extends StatefulWidget {
  final DgtExamResult result;
  final bool autoSubmitted;

  const DgtResultScreen({
    super.key,
    required this.result,
    this.autoSubmitted = false,
  });

  @override
  State<DgtResultScreen> createState() => _DgtResultScreenState();
}

class _DgtResultScreenState extends State<DgtResultScreen> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    if (widget.result.passed) {
      // Refuerzo motivacional: confetti + vibracion al aprobar.
      _confettiController.play();
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  String _composeShareText() {
    final result = widget.result;
    final passed = result.passed;
    final pct = result.total == 0
        ? 0
        : ((result.correct / result.total) * 100).round();
    final buf = StringBuffer();
    buf.writeln('Simulacro DGT - Memora');
    buf.writeln(
        'Resultado: ${result.correct}/${result.total} (${passed ? "APTO" : "NO APTO"})');
    buf.write('Aciertos: $pct%');
    if (result.elapsedSeconds != null) {
      final s = result.elapsedSeconds!;
      final m = (s ~/ 60).toString().padLeft(2, '0');
      final ss = (s % 60).toString().padLeft(2, '0');
      buf.write(' | Tiempo: $m:$ss');
    }
    buf.writeln();
    if (result.wrong.isNotEmpty) {
      final byTopic = <String, int>{};
      for (final w in result.wrong) {
        final t = (w.question.topic ?? '').trim();
        final key = t.isEmpty ? 'Otros' : t;
        byTopic[key] = (byTopic[key] ?? 0) + 1;
      }
      final parts =
          byTopic.entries.map((e) => '${e.key} (${e.value})').join(', ');
      buf.writeln('Fallos por tema: $parts');
    }
    buf.write('https://memora.a-robertdev.com');
    return buf.toString();
  }

  Future<void> _shareResult() async {
    final text = _composeShareText();
    await Share.share(text, subject: 'Mi simulacro DGT en Memora');
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final passed = result.passed;
    final color = passed ? const Color(0xFF4FFFB0) : const Color(0xFFFF5C5C);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado simulacro'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Compartir',
            onPressed: _shareResult,
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              24 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Icon(
                      passed
                          ? Icons.emoji_events_rounded
                          : Icons.replay_rounded,
                      color: color,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      passed ? 'APROBADO' : 'SUSPENSO',
                      style: TextStyle(
                        color: color,
                        fontSize: passed ? 26 : 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (passed) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Sigue asi! 🎉',
                        style: TextStyle(
                          color: color,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${result.correct} / ${result.total} aciertos '
                      '(${result.wrongCount} fallos)',
                      style: TextStyle(
                        fontSize: passed ? 18 : 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      passed
                          ? 'Criterio DGT permiso B: hasta 3 fallos.'
                          : 'Criterio DGT permiso B: maximo 3 fallos.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.autoSubmitted) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Tiempo agotado: entregado automaticamente.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (result.elapsedSeconds != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        () {
                          final s = result.elapsedSeconds!;
                          final m = (s ~/ 60).toString().padLeft(2, '0');
                          final ss = (s % 60).toString().padLeft(2, '0');
                          final prefix = result.strictMode
                              ? 'Modo examen real - tiempo usado'
                              : 'Tiempo usado';
                          return '$prefix: $m:$ss';
                        }(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Issue #181 (dgt-ux): boton "Revisar fallos (N)" que abre
              // pantalla PageView dedicada con explicacion + favorita.
              // Solo visible si hay fallos (si pleno 100%, se oculta).
              if (result.wrong.isNotEmpty) ...[
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DgtSimulacroReviewScreen(
                          failed: result.wrong,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.menu_book_rounded),
                  label: Text('Revisar fallos (${result.wrong.length})'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (result.wrong.isNotEmpty)
                const Text(
                  'Repaso de falladas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const SizedBox(height: 8),
              ...result.wrong.map((r) => _WrongTile(review: r)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Volver al inicio'),
              ),
            ],
          ),
          // Overlay de confetti solo cuando se aprueba.
          if (passed)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: math.pi / 2,
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                maxBlastForce: 18,
                minBlastForce: 6,
                gravity: 0.25,
                shouldLoop: false,
                colors: const [
                  Color(0xFF4FFFB0),
                  Color(0xFFFFD24F),
                  Color(0xFF4FB0FF),
                  Color(0xFFFF6FB5),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WrongTile extends StatelessWidget {
  final DgtAnswerReview review;
  const _WrongTile({required this.review});

  String _optionFor(DgtQuestion q, String letter) {
    switch (letter) {
      case 'a':
        return q.optionA;
      case 'b':
        return q.optionB;
      case 'c':
        return q.optionC;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final q = review.question;
    final picked = review.picked;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.statement,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          _line(
            label: 'Correcta',
            value: '${q.correct.toUpperCase()}) ${_optionFor(q, q.correct)}',
            color: const Color(0xFF4FFFB0),
          ),
          if (picked != null)
            _line(
              label: 'Tu respuesta',
              value: '${picked.toUpperCase()}) ${_optionFor(q, picked)}',
              color: const Color(0xFFFF5C5C),
            )
          else
            _line(
              label: 'Tu respuesta',
              value: 'Sin responder',
              color: const Color(0xFFFF5C5C),
            ),
          if (q.explanation != null && q.explanation!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                q.explanation!,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(
      {required String label, required String value, required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, height: 1.4),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
