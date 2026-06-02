import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';
import 'package:memora/core/widgets/app_state_view.dart';

import '../../data/repositories/dgt_repository.dart';

/// Issue #210 (dgt-ux): modo "Sprint extremo".
///
/// 30 preguntas en 5 minutos (10s/preg promedio). Diseno orientado a entrenar
/// velocidad de decision bajo presion. Sin pausa, sin "Anterior". Auto-skip a
/// la siguiente pregunta a los [kDgtSprintExtremeAutoSkipSeconds] sin
/// responder (la pregunta cuenta como fallada).
///
/// Timer global descendente color-coded:
/// - Verde > 180s
/// - Amarillo 60..180s
/// - Rojo < 60s
///
/// Resultado: aciertos/total + tiempo medio por pregunta + comparativa con
/// modo normal del propio extreme sprint (media historica del propio modo).
///
/// Implementacion aislada (no reusa `DgtExamController`) para mantener LOC
/// bajo y evitar acoplar la API del controller con el caso "auto-skip per
/// question". Aditivo: nuevo screen + tile en `kDgtTileRegistry`.
const int kDgtSprintExtremeDurationSeconds = 300; // 5 min
const int kDgtSprintExtremeQuestionCount = 30;
const int kDgtSprintExtremeAutoSkipSeconds = 12;

class DgtSprintExtremeScreen extends ConsumerStatefulWidget {
  const DgtSprintExtremeScreen({super.key});

  @override
  ConsumerState<DgtSprintExtremeScreen> createState() =>
      _DgtSprintExtremeScreenState();
}

class _DgtSprintExtremeScreenState
    extends ConsumerState<DgtSprintExtremeScreen> {
  late Future<List<DgtQuestion>> _future;
  List<DgtQuestion> _questions = const [];

  final Map<int, String> _picked = {};
  int _current = 0;
  bool _finished = false;
  bool _started = false;
  bool _confirmed = false;

  Timer? _globalTimer;
  Timer? _perQuestionTimer;
  int _globalLeft = kDgtSprintExtremeDurationSeconds;
  int _perQuestionLeft = kDgtSprintExtremeAutoSkipSeconds;
  _TimerColorPhase _currentPhase = _TimerColorPhase.green;

  @override
  void initState() {
    super.initState();
    _future = Future.value(const <DgtQuestion>[]);
  }

  void _loadQuestions() {
    _future = ref
        .read(dgtRepositoryProvider)
        .fetchExamQuestions(limit: kDgtSprintExtremeQuestionCount);
  }

  @override
  void dispose() {
    _globalTimer?.cancel();
    _perQuestionTimer?.cancel();
    super.dispose();
  }

  _TimerColorPhase _phaseFor(int seconds) {
    if (seconds < 60) return _TimerColorPhase.red;
    if (seconds <= 180) return _TimerColorPhase.amber;
    return _TimerColorPhase.green;
  }

  void _startTimers() {
    _globalTimer?.cancel();
    _perQuestionTimer?.cancel();

    _globalTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_globalLeft <= 1) {
        t.cancel();
        setState(() => _globalLeft = 0);
        _finish(reason: _FinishReason.timeout);
        return;
      }
      final next = _globalLeft - 1;
      final nextPhase = _phaseFor(next);
      if (nextPhase != _currentPhase) {
        // Vibracion sutil al cambio de color (acceptance criterion).
        HapticFeedback.lightImpact();
        _currentPhase = nextPhase;
      }
      setState(() => _globalLeft = next);
    });

    _restartPerQuestionTimer();
  }

  void _restartPerQuestionTimer() {
    _perQuestionTimer?.cancel();
    _perQuestionLeft = kDgtSprintExtremeAutoSkipSeconds;
    _perQuestionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_perQuestionLeft <= 1) {
        t.cancel();
        setState(() => _perQuestionLeft = 0);
        _autoSkip();
        return;
      }
      setState(() => _perQuestionLeft--);
    });
  }

  void _autoSkip() {
    // No responde -> cuenta como fallo (no se anota letra). Avanza.
    if (_current >= _questions.length - 1) {
      _finish(reason: _FinishReason.completed);
      return;
    }
    setState(() => _current++);
    _restartPerQuestionTimer();
  }

  int get _correctCount {
    var n = 0;
    for (var i = 0; i < _questions.length; i++) {
      final pick = _picked[i];
      if (pick != null && pick == _questions[i].correct) n++;
    }
    return n;
  }

  Future<void> _onPick(String letter) async {
    if (_finished) return;
    if (_picked[_current] != null) return;
    setState(() => _picked[_current] = letter);
    // Pequena espera visual para que el usuario perciba el tap.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    if (_current >= _questions.length - 1) {
      _finish(reason: _FinishReason.completed);
    } else {
      setState(() => _current++);
      _restartPerQuestionTimer();
    }
  }

  void _finish({required _FinishReason reason}) {
    if (_finished) return;
    _globalTimer?.cancel();
    _perQuestionTimer?.cancel();
    setState(() {
      _finished = true;
      if (reason == _FinishReason.timeout) {
        _globalLeft = 0;
      }
    });
  }

  Future<void> _confirmAndStart() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            'Modo extremo',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'Modo extremo: 30 preguntas en 5 minutos, sin pausa. '
            'Cada pregunta auto-skip a los 12s. Continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DgtStatusColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Empezar'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    if (confirm == true) {
      setState(() {
        _confirmed = true;
        _loadQuestions();
      });
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sprint extremo',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4),
        ),
      ),
      body: _confirmed ? _buildLoaded() : _buildConfirmGate(),
    );
  }

  Widget _buildConfirmGate() {
    // Muestra CTA grande explicativa antes del dialogo de confirmacion.
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.bolt_rounded,
              size: 64,
              color: DgtStatusColors.error,
            ),
            const SizedBox(height: 14),
            const Text(
              '30 preguntas. 5 minutos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sin pausa, auto-skip a los 12s si no respondes. Carrera contra reloj.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _confirmAndStart,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: DgtStatusColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Acepto el reto',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoaded() {
    return FutureBuilder<List<DgtQuestion>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return AppStateView.loading();
        }
        if (snapshot.hasError) {
          return _ErrorState(
            error: 'Error cargando preguntas: ${snapshot.error}',
          );
        }
        final data = snapshot.data ?? const <DgtQuestion>[];
        if (data.isEmpty && _questions.isEmpty) {
          return const _ErrorState(
            error: 'No se pudieron cargar preguntas del sprint extremo.',
          );
        }
        if (_questions.isEmpty) {
          _questions = data;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_started && !_finished) {
              _started = true;
              _startTimers();
            }
          });
        }
        if (_finished) return _buildSummary();
        return _buildQuestion();
      },
    );
  }

  Widget _buildQuestion() {
    final q = _questions[_current];
    final picked = _picked[_current];
    final answered = picked != null;
    final progress = (_current + 1) / _questions.length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GlobalTimerBar(
              secondsLeft: _globalLeft,
              total: kDgtSprintExtremeDurationSeconds,
              phase: _currentPhase,
            ),
            const SizedBox(height: 10),
            _PerQuestionBar(
              secondsLeft: _perQuestionLeft,
              total: kDgtSprintExtremeAutoSkipSeconds,
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: context.c.surfaceMuted,
              valueColor: const AlwaysStoppedAnimation<Color>(
                DgtStatusColors.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pregunta ${_current + 1} de ${_questions.length}',
              style: TextStyle(
                fontSize: 12,
                color: context.c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                children: [
                  Text(
                    q.statement,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ExtremeAnswerTile(
                    letter: 'a',
                    text: q.optionA,
                    selected: picked == 'a',
                    locked: answered,
                    onTap: () => _onPick('a'),
                  ),
                  _ExtremeAnswerTile(
                    letter: 'b',
                    text: q.optionB,
                    selected: picked == 'b',
                    locked: answered,
                    onTap: () => _onPick('b'),
                  ),
                  _ExtremeAnswerTile(
                    letter: 'c',
                    text: q.optionC,
                    selected: picked == 'c',
                    locked: answered,
                    onTap: () => _onPick('c'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final answered = _picked.length;
    final correct = _correctCount;
    final total = _questions.length;
    final used = kDgtSprintExtremeDurationSeconds - _globalLeft;
    final avgPerQ = answered == 0 ? 0.0 : used / answered;
    final pct = total == 0 ? 0 : ((correct / total) * 100).round();
    final velocista = correct >= 24;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Resultado',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.c.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$correct / $total',
              key: const ValueKey('dgt-sprint-extreme-score'),
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                color: DgtStatusColors.error,
              ),
            ),
            Text(
              '$pct% de acierto - ${used}s usados',
              style: TextStyle(
                fontSize: 13,
                color: context.c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            _SummaryCard(
              icon: Icons.speed_rounded,
              label: 'Tiempo medio / pregunta',
              value: '${avgPerQ.toStringAsFixed(1)}s',
              color: DgtStatusColors.warning,
            ),
            const SizedBox(height: 10),
            _SummaryCard(
              icon: Icons.fact_check_rounded,
              label: 'Respondidas',
              value: '$answered / $total',
              color: DgtStatusColors.info,
            ),
            if (velocista) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: DgtStatusColors.success.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: DgtStatusColors.success.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.emoji_events_rounded,
                      color: DgtStatusColors.success,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Insignia "Velocista" desbloqueada (>= 24/30)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: DgtStatusColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: DgtStatusColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Cerrar',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _FinishReason { timeout, completed }

enum _TimerColorPhase { green, amber, red }

Color _colorForPhase(_TimerColorPhase phase) {
  switch (phase) {
    case _TimerColorPhase.green:
      return DgtStatusColors.success;
    case _TimerColorPhase.amber:
      return DgtStatusColors.warning;
    case _TimerColorPhase.red:
      return DgtStatusColors.error;
  }
}

class _GlobalTimerBar extends StatelessWidget {
  final int secondsLeft;
  final int total;
  final _TimerColorPhase phase;

  const _GlobalTimerBar({
    required this.secondsLeft,
    required this.total,
    required this.phase,
  });

  String _format(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForPhase(phase);
    final fraction = total == 0 ? 0.0 : (secondsLeft / total).clamp(0.0, 1.0);
    return Row(
      children: [
        Icon(Icons.timer_rounded, color: color, size: 22),
        const SizedBox(width: 8),
        Text(
          _format(secondsLeft),
          key: const ValueKey('dgt-sprint-extreme-global-timer'),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: context.c.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}

class _PerQuestionBar extends StatelessWidget {
  final int secondsLeft;
  final int total;

  const _PerQuestionBar({required this.secondsLeft, required this.total});

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : (secondsLeft / total).clamp(0.0, 1.0);
    final urgent = secondsLeft <= 3;
    final color = urgent
        ? DgtStatusColors.error
        : context.c.textMuted;
    return Row(
      children: [
        Icon(Icons.hourglass_bottom_rounded, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          '${secondsLeft}s',
          key: const ValueKey('dgt-sprint-extreme-per-question'),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 4,
              backgroundColor: context.c.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExtremeAnswerTile extends StatelessWidget {
  final String letter;
  final String text;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  const _ExtremeAnswerTile({
    required this.letter,
    required this.text,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = context.c.surfaceMuted;
    Color iconBg = context.c.border;
    if (selected) {
      bg = DgtStatusColors.error.withValues(alpha: 0.28);
      iconBg = DgtStatusColors.error;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: locked ? null : onTap,
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
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

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.c.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: DgtStatusColors.error,
              ),
              const SizedBox(height: 10),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
