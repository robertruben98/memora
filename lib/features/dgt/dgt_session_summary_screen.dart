import 'package:flutter/material.dart';
import 'package:memora/core/theme/app_colors.dart';

import 'dgt_failures_review_screen.dart';
import 'dgt_weak_focus_screen.dart';

/// Issue #113 (dgt-ux): pantalla de resumen mostrada al cerrar una sesion
/// de practica DGT con >= [_minQuestions] preguntas respondidas.
///
/// Refuerza el habito y la meta diaria mostrando tiempo invertido, # de
/// preguntas, % acierto y el tema con menos acierto (en practica libre por
/// tema solo hay 1 -> se sugiere repasar ese mismo tema en quick review).
/// Aditivo: no rompe el flujo natural del [DgtPracticeScreen] cuando se
/// completa el quiz entero (ese sigue mostrando el resumen inline tradicional).
class DgtSessionSummaryScreen extends StatelessWidget {
  /// Nombre legible del tema de la sesion (p.ej. "Senales").
  final String topicName;

  /// Numero total de preguntas respondidas durante la sesion.
  final int answeredCount;

  /// Numero de respuestas correctas.
  final int correctCount;

  /// Duracion total de la sesion (desde initState hasta exit).
  final Duration elapsed;

  /// Tema con menor % de acierto. En practica libre por tema coincide con
  /// [topicName]; queda como parametro independiente para soportar futuras
  /// sesiones multi-tema sin romper el contrato del widget.
  final String? weakestTopic;

  const DgtSessionSummaryScreen({
    super.key,
    required this.topicName,
    required this.answeredCount,
    required this.correctCount,
    required this.elapsed,
    this.weakestTopic,
  });

  /// Umbral minimo de preguntas para que tenga sentido mostrar resumen.
  /// Sesiones cortas (< 5) salen directo sin sheet para no entorpecer la UX
  /// de ojeada rapida.
  static const int _minQuestions = 5;

  /// Determina si una sesion merece mostrar el resumen al exit.
  static bool shouldShowFor(int answered) => answered >= _minQuestions;

  int get _wrong => (answeredCount - correctCount).clamp(0, answeredCount);
  int get _pct => answeredCount == 0
      ? 0
      : ((correctCount / answeredCount) * 100).round();

  String _formatElapsed() {
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final accent = _pct >= 80
        ? const Color(0xFF4FFFB0)
        : _pct >= 50
            ? const Color(0xFF7C5CFF)
            : const Color(0xFFFF8A4F);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen sesion'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Icon(
                Icons.insights_rounded,
                size: 64,
                color: accent,
              ),
              const SizedBox(height: 12),
              Text(
                topicName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Buen trabajo. Esto invertiste hoy.',
                style: TextStyle(
                  color: context.c.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SummaryStat(
                    label: 'Tiempo',
                    value: _formatElapsed(),
                  ),
                  _SummaryStat(
                    label: 'Preguntas',
                    value: '$answeredCount',
                  ),
                  _SummaryStat(
                    label: '% acierto',
                    value: '$_pct%',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (weakestTopic != null && _wrong > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
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
                          Icon(Icons.menu_book_rounded,
                              color: accent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Tema mas debil',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Repasa "$weakestTopic" en quick review para '
                        'consolidar lo que fallaste.',
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              if (_wrong > 0)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      // Reemplaza la pantalla de resumen por failures review,
                      // dejando el stack del navigator limpio (sin volver a
                      // este resumen con el back).
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const DgtFailuresReviewScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Repasar fallos'),
                  ),
                ),
              if (_wrong > 0) const SizedBox(height: 10),
              // Issue #134 (dgt-ux): CTA condicional "Atacar mi punto debil".
              // Solo aparece si el resumen identifica un tema mas debil
              // (weakestTopic != null). Reemplaza la pantalla actual con la
              // weak-focus screen para que el back vuelva al hub, no aqui.
              if (weakestTopic != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const DgtWeakFocusScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.gps_fixed_rounded),
                    label: const Text('Atacar mi punto debil'),
                  ),
                ),
              if (weakestTopic != null) const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryStat({required this.label, required this.value});

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
