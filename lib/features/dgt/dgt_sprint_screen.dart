import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';
import 'package:memora/core/utils/format_duration.dart';
import 'package:memora/core/widgets/app_state_view.dart';

import '../../data/repositories/dgt_repository.dart';
import 'dgt_sprint_history_provider.dart';
import 'widgets/sprint_histogram.dart';

/// Issue #152 (dgt-ux): modo "Sprint diario".
///
/// 10 preguntas DGT random con cuenta atras de 2 minutos. Autoavanza al
/// responder, sin feedback verde/rojo durante el sprint (estilo wordle, no
/// distrae). Al terminar muestra: aciertos/10, tiempo usado, comparativa
/// vs media personal e histograma horizontal con los ultimos 14 sprints.
///
/// Reglas:
/// - 1 sprint por dia (regla criterio aceptacion). Si ya existe sprint hoy
///   se muestra directamente el resumen de hoy en lugar de empezar uno nuevo.
/// - Persistencia local via SharedPreferences (ver
///   [`dgt_sprint_history_provider.dart`]).
/// - Aditivo: no toca historial de simulacros, ni backend nuevo. Reusa
///   [`DgtRepository.fetchRandomWarmup`] que ya devuelve preguntas random
///   con fallback offline al banco local.
class DgtSprintScreen extends ConsumerStatefulWidget {
  const DgtSprintScreen({super.key});

  @override
  ConsumerState<DgtSprintScreen> createState() => _DgtSprintScreenState();
}

class _DgtSprintScreenState extends ConsumerState<DgtSprintScreen> {
  late Future<List<DgtQuestion>> _future;
  List<DgtQuestion> _questions = const [];

  /// Letra elegida por pregunta (null = sin responder).
  final Map<int, String> _picked = {};
  int _current = 0;
  bool _finished = false;

  Timer? _timer;
  int _secondsLeft = kDgtSprintDurationSeconds;
  DgtSprintEntry? _todayResult;
  bool _alreadyDoneToday = false;
  bool _futureInitialized = false;

  @override
  void initState() {
    super.initState();
    // El historial puede estar todavia hidratandose desde SharedPreferences
    // (carga async). Inicializamos en `build` cuando el provider ya tiene
    // datos para evitar arrancar un sprint nuevo cuando ya hay uno hoy.
    _future = Future.value(const <DgtQuestion>[]);
  }

  void _initFutureIfNeeded() {
    if (_futureInitialized) return;
    _futureInitialized = true;
    _future = ref
        .read(dgtRepositoryProvider)
        .fetchRandomWarmup(limit: kDgtSprintQuestionCount);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() {
          _secondsLeft = 0;
        });
        _finishSprint(timeout: true);
        return;
      }
      setState(() => _secondsLeft--);
    });
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
    if (_picked[_current] != null) return; // ya respondida
    setState(() {
      _picked[_current] = letter;
    });
    // Autoavanza tras un breve respiro visual (estilo sprint).
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    if (_current >= _questions.length - 1) {
      _finishSprint(timeout: false);
    } else {
      setState(() => _current++);
    }
  }

  Future<void> _finishSprint({required bool timeout}) async {
    _timer?.cancel();
    final used = kDgtSprintDurationSeconds - _secondsLeft;
    final entry = DgtSprintEntry(
      timestamp: DateTime.now(),
      total: _questions.isEmpty ? kDgtSprintQuestionCount : _questions.length,
      correct: _correctCount,
      secondsUsed: timeout ? kDgtSprintDurationSeconds : used,
    );
    final saved =
        await ref.read(dgtSprintHistoryProvider.notifier).record(entry);
    if (!mounted) return;
    setState(() {
      _finished = true;
      _todayResult = saved
          ? entry
          : ref.read(dgtSprintHistoryProvider).todayEntry();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Si ya existe sprint hoy, atajamos a summary sin pedir preguntas.
    final history = ref.watch(dgtSprintHistoryProvider);
    final todayExisting = history.todayEntry();
    if (todayExisting != null && !_finished) {
      _alreadyDoneToday = true;
      _todayResult = todayExisting;
      _finished = true;
    }
    // Solo arrancamos el fetch si NO hay sprint hoy.
    if (!_alreadyDoneToday) {
      _initFutureIfNeeded();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sprint diario',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4),
        ),
      ),
      body: FutureBuilder<List<DgtQuestion>>(
        future: _future,
        builder: (context, snapshot) {
          if (_alreadyDoneToday) {
            return _SprintSummary(
              entry: _todayResult,
              history: history.entries,
              alreadyDoneToday: true,
              onExit: () => Navigator.of(context).pop(),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return AppStateView.loading();
          }
          if (snapshot.hasError) {
            return _ErrorState(error: '${snapshot.error}');
          }
          final data = snapshot.data ?? const <DgtQuestion>[];
          if (data.isEmpty && _questions.isEmpty) {
            return const _ErrorState(
              error: 'No se pudieron cargar preguntas del sprint.',
            );
          }
          if (_questions.isEmpty) {
            _questions = data;
            // Arrancar timer en el primer build con preguntas.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _timer == null && !_finished) {
                _startTimer();
              }
            });
          }
          if (_finished) {
            return _SprintSummary(
              entry: _todayResult,
              history: history.entries,
              alreadyDoneToday: false,
              onExit: () => Navigator.of(context).pop(),
            );
          }
          return _buildQuestion();
        },
      ),
    );
  }

  Widget _buildQuestion() {
    final q = _questions[_current];
    final picked = _picked[_current];
    final answered = picked != null;
    final progress = (_current + 1) / _questions.length;
    final timeFraction = _secondsLeft / kDgtSprintDurationSeconds;
    final urgent = _secondsLeft <= 15;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TimerBar(
              secondsLeft: _secondsLeft,
              fraction: timeFraction,
              urgent: urgent,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: context.c.surfaceMuted,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.brand,
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
            const SizedBox(height: 16),
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
                  const SizedBox(height: 18),
                  _SprintAnswerTile(
                    letter: 'a',
                    text: q.optionA,
                    selected: picked == 'a',
                    locked: answered,
                    onTap: () => _onPick('a'),
                  ),
                  _SprintAnswerTile(
                    letter: 'b',
                    text: q.optionB,
                    selected: picked == 'b',
                    locked: answered,
                    onTap: () => _onPick('b'),
                  ),
                  _SprintAnswerTile(
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
}

class _TimerBar extends StatelessWidget {
  final int secondsLeft;
  final double fraction;
  final bool urgent;

  const _TimerBar({
    required this.secondsLeft,
    required this.fraction,
    required this.urgent,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        urgent ? DgtStatusColors.error : AppColors.brand;
    return Row(
      children: [
        Icon(Icons.timer_outlined, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          formatMmSs(secondsLeft),
          key: const ValueKey('dgt-sprint-timer'),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: context.c.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}

class _SprintAnswerTile extends StatelessWidget {
  final String letter;
  final String text;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  const _SprintAnswerTile({
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
      bg = AppColors.brand.withValues(alpha: 0.28);
      iconBg = AppColors.brand;
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

class _SprintSummary extends StatelessWidget {
  final DgtSprintEntry? entry;
  final List<DgtSprintEntry> history;
  final bool alreadyDoneToday;
  final VoidCallback onExit;

  const _SprintSummary({
    required this.entry,
    required this.history,
    required this.alreadyDoneToday,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final entry = this.entry;
    if (entry == null) {
      return _ErrorState(
        error: 'No se pudo registrar el sprint. Intentalo otra vez.',
        onExit: onExit,
      );
    }
    // Para el "vs media personal" excluimos la entrada de hoy si esta dentro
    // del historial, para que la comparativa sea contra los anteriores.
    final prev = history.where((e) => e.timestamp != entry.timestamp).toList();
    final prevAvg = prev.isEmpty
        ? null
        : prev.map((e) => e.correct).fold<int>(0, (a, b) => a + b) /
            prev.length;
    final pctScore = (entry.correct / entry.total) * 100;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (alreadyDoneToday)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: DgtStatusColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: DgtStatusColors.warning,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ya completaste el sprint de hoy. Vuelve manana.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: DgtStatusColors.warning,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
              '${entry.correct} / ${entry.total}',
              key: const ValueKey('dgt-sprint-score'),
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                color: AppColors.brand,
              ),
            ),
            Text(
              '${pctScore.toStringAsFixed(0)}% de acierto - ${entry.secondsUsed}s usados',
              style: TextStyle(
                fontSize: 13,
                color: context.c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            if (prevAvg != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: context.c.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      entry.correct >= prevAvg
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: DgtStatusColors.forPassed(
                        entry.correct >= prevAvg,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tu media: ${prevAvg.toStringAsFixed(1)} aciertos',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 22),
            Text(
              'Ultimos sprints',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.c.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            SprintHistogram(entries: history),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onExit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Cerrar',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback? onExit;

  const _ErrorState({required this.error, this.onExit});

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
              if (onExit != null) ...[
                const SizedBox(height: 18),
                OutlinedButton(
                  onPressed: onExit,
                  child: const Text('Cerrar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
