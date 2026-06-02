import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dgt_today_study_provider.dart';

/// Issue #167 (dgt-ux): pantalla "Estudio de hoy" auto-curada.
///
/// Combina 3 fuentes (5 weak + 5 recurrent + 5 nuevas) y corre el flujo de
/// quiz estandar. Al terminar muestra summary con accuracy parcial por bucket.
///
/// Diseno:
/// - Header: chip con desglose ("5 debil / 5 recurrentes / 5 nuevas") + CTA
///   "Empezar" antes de la primera pregunta.
/// - Body: mismo patron de feedback inline usado en `dgt_weak_focus_screen`.
/// - Summary final: accuracy global + breakdown por bucket + CTA "Repetir
///   manana" (deshabilitado el mismo dia mediante `_TodayCompletionGuard`).
///
/// Persiste el dia completado en SharedPreferences para que el usuario vea
/// warning si intenta repetir el mismo dia (spec: "no permitir repetirlo dos
/// veces consecutivas sin warning"). Implementacion mas simple que un
/// provider dedicado: la pantalla decide en `initState` si mostrar warning.
class DgtTodayStudyScreen extends ConsumerStatefulWidget {
  const DgtTodayStudyScreen({super.key});

  @override
  ConsumerState<DgtTodayStudyScreen> createState() =>
      _DgtTodayStudyScreenState();
}

class _DgtTodayStudyScreenState extends ConsumerState<DgtTodayStudyScreen> {
  /// Letra elegida por indice de pregunta (null = sin responder).
  final Map<int, String> _picked = {};
  int _current = 0;
  bool _started = false;
  bool _finished = false;
  bool _alreadyDoneTodayWarning = false;

  @override
  void initState() {
    super.initState();
    _checkAlreadyDoneToday();
  }

  Future<void> _checkAlreadyDoneToday() async {
    final guard = await _TodayCompletionGuard.load();
    if (!mounted) return;
    if (guard.completedToday()) {
      setState(() => _alreadyDoneTodayWarning = true);
    }
  }

  void _start() => setState(() => _started = true);

  void _selectAnswer(String letter) {
    if (_picked.containsKey(_current)) return;
    setState(() => _picked[_current] = letter);
  }

  void _next(int total) {
    if (_current < total - 1) {
      setState(() => _current++);
    } else {
      setState(() => _finished = true);
      // Persiste completion del dia.
      unawaited(_TodayCompletionGuard.markCompletedNow());
    }
  }

  int _correctCount(List<DgtTodayItem> items) {
    var c = 0;
    for (var i = 0; i < items.length; i++) {
      final p = _picked[i];
      if (p != null && p == items[i].question.correct) c++;
    }
    return c;
  }

  ({int correct, int total}) _bucketStats(
    List<DgtTodayItem> items,
    DgtTodayBucket bucket,
  ) {
    var correct = 0;
    var total = 0;
    for (var i = 0; i < items.length; i++) {
      if (items[i].bucket != bucket) continue;
      total++;
      final p = _picked[i];
      if (p != null && p == items[i].question.correct) correct++;
    }
    return (correct: correct, total: total);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dgtTodayStudyProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estudio de hoy'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _Empty(
          icon: Icons.cloud_off_rounded,
          message:
              'Error cargando la sesion. Revisa conexion y reintenta.',
          onRetry: () => ref.invalidate(dgtTodayStudyProvider),
        ),
        data: (result) {
          if (result.isEmpty) {
            return _Empty(
              icon: Icons.psychology_outlined,
              message:
                  'Aun no tenemos suficientes datos para armar la sesion. '
                  'Practica un poco mas (simulacro libre o por tema) y '
                  'vuelve manana.',
              onRetry: () => ref.invalidate(dgtTodayStudyProvider),
            );
          }
          if (!_started) {
            return _IntroPanel(
              weak: result.weakCount,
              recurrent: result.recurrentCount,
              fresh: result.freshCount,
              total: result.total,
              alreadyDoneWarning: _alreadyDoneTodayWarning,
              onStart: _start,
            );
          }
          if (_finished) return _buildSummary(result);
          return _buildQuestion(result.items);
        },
      ),
    );
  }

  Widget _buildQuestion(List<DgtTodayItem> items) {
    if (_current >= items.length) _current = items.length - 1;
    final item = items[_current];
    final q = item.question;
    final picked = _picked[_current];
    final answered = picked != null;
    final total = items.length;

    return Column(
      children: [
        LinearProgressIndicator(
          value: (_current + 1) / total,
          minHeight: 4,
          backgroundColor: context.c.surfaceMuted,
          valueColor: const AlwaysStoppedAnimation(Color(0xFF4FA8FF)),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BucketChip(bucket: item.bucket),
                const SizedBox(height: 10),
                Text(
                  'Pregunta ${_current + 1} / $total',
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
                if (answered && (q.explanation ?? '').isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.c.surfaceMuted,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: context.c.border,
                      ),
                    ),
                    child: Text(
                      q.explanation!,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
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
                  onPressed: answered ? () => _next(total) : null,
                  icon: Icon(_current == total - 1
                      ? Icons.flag_rounded
                      : Icons.chevron_right_rounded),
                  label: Text(_current == total - 1
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

  Widget _buildSummary(DgtTodayStudyResult result) {
    final items = result.items;
    final correct = _correctCount(items);
    final total = items.length;
    final pct = total == 0 ? 0 : ((correct / total) * 100).round();

    final weakStats = _bucketStats(items, DgtTodayBucket.weak);
    final recurrentStats = _bucketStats(items, DgtTodayBucket.recurrent);
    final freshStats = _bucketStats(items, DgtTodayBucket.fresh);

    final accent = pct >= 80
        ? const Color(0xFF4FFFB0)
        : pct >= 50
            ? const Color(0xFF7C5CFF)
            : const Color(0xFFFF8A4F);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.emoji_events_rounded, color: accent, size: 56),
            const SizedBox(height: 8),
            Text(
              '$pct% acierto',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$correct de $total preguntas correctas',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.c.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            _BucketSummaryRow(
              label: 'Debil',
              correct: weakStats.correct,
              total: weakStats.total,
              color: const Color(0xFFFF5C5C),
            ),
            const SizedBox(height: 8),
            _BucketSummaryRow(
              label: 'Recurrentes',
              correct: recurrentStats.correct,
              total: recurrentStats.total,
              color: const Color(0xFFFFB74F),
            ),
            const SizedBox(height: 8),
            _BucketSummaryRow(
              label: 'Nuevas',
              correct: freshStats.correct,
              total: freshStats.total,
              color: const Color(0xFF4FA8FF),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.event_available_rounded),
              label: const Text('Repetir manana'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Salir'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroPanel extends StatelessWidget {
  final int weak;
  final int recurrent;
  final int fresh;
  final int total;
  final bool alreadyDoneWarning;
  final VoidCallback onStart;

  const _IntroPanel({
    required this.weak,
    required this.recurrent,
    required this.fresh,
    required this.total,
    required this.alreadyDoneWarning,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sesion mixta auto-curada',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '$total preguntas combinando 3 fuentes para que avances en lo '
              'que mas necesitas hoy.',
              style: TextStyle(color: context.c.textSecondary),
            ),
            const SizedBox(height: 18),
            _IntroBreakdownRow(
              label: 'Tema mas debil',
              count: weak,
              icon: Icons.gps_fixed_rounded,
              color: const Color(0xFFFF5C5C),
            ),
            const SizedBox(height: 10),
            _IntroBreakdownRow(
              label: 'Errores recurrentes',
              count: recurrent,
              icon: Icons.history_toggle_off_rounded,
              color: const Color(0xFFFFB74F),
            ),
            const SizedBox(height: 10),
            _IntroBreakdownRow(
              label: 'Preguntas nuevas',
              count: fresh,
              icon: Icons.fiber_new_rounded,
              color: const Color(0xFF4FA8FF),
            ),
            if (alreadyDoneWarning) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB74F).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFFB74F).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFFFFB74F),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ya hiciste Estudio de hoy. Puedes repetirlo, pero '
                        'rinde mas espaciar a manana.',
                        style: TextStyle(
                          color: context.c.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Empezar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroBreakdownRow extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  const _IntroBreakdownRow({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _BucketChip extends StatelessWidget {
  final DgtTodayBucket bucket;
  const _BucketChip({required this.bucket});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (bucket) {
      DgtTodayBucket.weak => (
          'Tema mas debil',
          const Color(0xFFFF5C5C),
          Icons.gps_fixed_rounded,
        ),
      DgtTodayBucket.recurrent => (
          'Error recurrente',
          const Color(0xFFFFB74F),
          Icons.history_toggle_off_rounded,
        ),
      DgtTodayBucket.fresh => (
          'Nueva',
          const Color(0xFF4FA8FF),
          Icons.fiber_new_rounded,
        ),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
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
    Color? bg;
    Color? border;
    IconData? trailing;
    if (answered) {
      final isCorrectOpt = letter == correct;
      final isPicked = letter == picked;
      if (isCorrectOpt) {
        bg = const Color(0xFF4FFFB0).withValues(alpha: 0.12);
        border = const Color(0xFF4FFFB0);
        trailing = Icons.check_circle_rounded;
      } else if (isPicked) {
        bg = const Color(0xFFFF5C5C).withValues(alpha: 0.12);
        border = const Color(0xFFFF5C5C);
        trailing = Icons.cancel_rounded;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: answered ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg ?? context.c.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: border ?? context.c.border,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor:
                    (border ?? context.c.textMuted).withValues(alpha: 0.18),
                child: Text(
                  letter.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text, style: const TextStyle(fontSize: 14)),
              ),
              if (trailing != null) Icon(trailing, color: border),
            ],
          ),
        ),
      ),
    );
  }
}

class _BucketSummaryRow extends StatelessWidget {
  final String label;
  final int correct;
  final int total;
  final Color color;

  const _BucketSummaryRow({
    required this.label,
    required this.correct,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct =
        total == 0 ? '—' : '${((correct / total) * 100).round()}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            total == 0 ? 'sin preguntas' : '$correct / $total · $pct',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback onRetry;

  const _Empty({
    required this.icon,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
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
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Guard simple para evitar repetir el mismo dia sin warning. Persistencia
/// en SharedPreferences (key 'dgt.today.last_completion_iso_date').
class _TodayCompletionGuard {
  static const _key = 'dgt.today.last_completion_iso_date';
  final String? lastDate; // ISO yyyy-mm-dd

  const _TodayCompletionGuard(this.lastDate);

  static Future<_TodayCompletionGuard> load() async {
    final prefs = await SharedPreferences.getInstance();
    return _TodayCompletionGuard(prefs.getString(_key));
  }

  static String _todayIso() {
    final n = DateTime.now();
    final y = n.year.toString().padLeft(4, '0');
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  bool completedToday() => lastDate == _todayIso();

  static Future<void> markCompletedNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _todayIso());
  }
}

