import 'package:flutter/material.dart';

import '../../data/repositories/dgt_repository.dart';

class DgtAnswerReview {
  final DgtQuestion question;
  final String? picked;
  DgtAnswerReview({required this.question, this.picked});
}

class DgtExamResult {
  final int total;
  final int correct;
  final List<DgtAnswerReview> wrong;

  const DgtExamResult({
    required this.total,
    required this.correct,
    required this.wrong,
  });

  int get wrongCount => total - correct;
  // Criterio oficial DGT permiso B: hasta 3 fallos para aprobar.
  bool get passed => wrongCount <= 3;
}

class DgtResultScreen extends StatelessWidget {
  final DgtExamResult result;
  final bool autoSubmitted;

  const DgtResultScreen({
    super.key,
    required this.result,
    this.autoSubmitted = false,
  });

  @override
  Widget build(BuildContext context) {
    final passed = result.passed;
    final color = passed ? const Color(0xFF4FFFB0) : const Color(0xFFFF5C5C);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado simulacro'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                  passed ? Icons.emoji_events_rounded : Icons.replay_rounded,
                  color: color,
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  passed ? 'APROBADO' : 'SUSPENSO',
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${result.correct} / ${result.total} aciertos '
                  '(${result.wrongCount} fallos)',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
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
                if (autoSubmitted) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Tiempo agotado: entregado automaticamente.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
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
