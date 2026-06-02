import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';
import 'package:memora/core/widgets/app_state_view.dart';
import 'package:memora/core/widgets/dgt_answer_tile.dart';
import 'package:memora/core/widgets/dgt_question_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/dgt_repository.dart';
import 'dgt_session_summary_screen.dart';
import 'widgets/dgt_report_question_sheet.dart';
import 'widgets/topic_pill_sheet.dart';

/// Modo practica DGT por tema: sin cronometro, feedback inmediato y
/// explicacion al fallar (inline). Aditivo respecto a [DgtExamScreen]; no
/// comparte estado ni rompe el flujo del simulacro cronometrado.
class DgtPracticeScreen extends ConsumerStatefulWidget {
  final DgtTopic topic;

  /// Numero de preguntas a cargar. Si es <=0 (p.ej. -1), no se aplica limit
  /// y se piden todas las del tema.
  final int limit;

  /// Issue #138 (dgt-ux): cuando se entra desde el heatmap "practicar rojos",
  /// la pantalla recibe la lista de subtopic_ids a filtrar. Es opcional para
  /// no romper los call sites previos (todos navegan sin filtrar subtemas).
  /// Cuando el backend exponga filtro por subtopic, esto se pasa al endpoint;
  /// mientras tanto se conserva como contexto de sesion.
  final List<String>? subtopicIds;

  const DgtPracticeScreen({
    super.key,
    required this.topic,
    required this.limit,
    this.subtopicIds,
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

  // Modo audio TTS manos libres (issue #92).
  bool _audioMode = false;
  bool _audioPaused = false;
  FlutterTts? _tts;
  Timer? _audioTimer;
  int _audioRunId = 0;

  // Pomodoro 25/5 modo estudio (issue #93). Aditivo: no afecta el modo audio
  // ni el flujo normal de practica. Persiste cantidad de pomodoros del dia
  // en SharedPreferences (key fechada YYYY-MM-DD) y otorga badge a los 4.
  static const Duration _pomoFocus = Duration(minutes: 25);
  static const Duration _pomoShortBreak = Duration(minutes: 5);
  static const Duration _pomoLongBreak = Duration(minutes: 15);
  static const String _pomoCountPrefix = 'dgt:pomo:count:';
  static const String _pomoBadgePrefix = 'dgt:pomo:badge:';

  bool _pomoActive = false;
  bool _pomoOnBreak = false;
  Duration _pomoRemaining = _pomoFocus;
  Timer? _pomoTicker;
  int _pomoCyclesToday = 0;
  bool _pomoBadgeShownToday = false;

  // Issue #113 (dgt-ux): tracker simple de la sesion de practica para
  // alimentar el resumen al cerrar. In-memory, sin persistencia. Las
  // metricas (# respondidas, # correctas) se derivan al exit usando
  // [_picked] y [_questions]; aqui solo guardamos el [DateTime] inicial.
  late final DateTime _sessionStartedAt = DateTime.now();
  bool _summaryShown = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadPomoState();
    // Issue #110: muestra pildora didactica pre-quiz si el tema es critico
    // y aun no fue vista. Aditivo: si no hay pildora definida no hace nada.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await DgtTopicPillSheet.maybeShow(
        context: context,
        topicId: widget.topic.id,
      );
    });
  }

  @override
  void dispose() {
    _audioTimer?.cancel();
    _tts?.stop();
    _pomoTicker?.cancel();
    super.dispose();
  }

  String _todayKey() {
    final n = DateTime.now();
    final mm = n.month.toString().padLeft(2, '0');
    final dd = n.day.toString().padLeft(2, '0');
    return '${n.year}-$mm-$dd';
  }

  Future<void> _loadPomoState() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    if (!mounted) return;
    setState(() {
      _pomoCyclesToday = prefs.getInt('$_pomoCountPrefix$today') ?? 0;
      _pomoBadgeShownToday = prefs.getBool('$_pomoBadgePrefix$today') ?? false;
    });
  }

  Future<void> _togglePomodoro() async {
    if (_pomoActive) {
      _pomoTicker?.cancel();
      setState(() {
        _pomoActive = false;
        _pomoOnBreak = false;
        _pomoRemaining = _pomoFocus;
      });
      return;
    }
    setState(() {
      _pomoActive = true;
      _pomoOnBreak = false;
      _pomoRemaining = _pomoFocus;
    });
    _startPomoTicker();
  }

  void _startPomoTicker() {
    _pomoTicker?.cancel();
    _pomoTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_pomoActive) return;
      final next = _pomoRemaining - const Duration(seconds: 1);
      if (next.inSeconds <= 0) {
        _onPomoPhaseComplete();
      } else {
        setState(() => _pomoRemaining = next);
      }
    });
  }

  Future<void> _onPomoPhaseComplete() async {
    _pomoTicker?.cancel();
    if (!_pomoOnBreak) {
      // Foco completado -> incrementa ciclos y entra a descanso.
      final prefs = await SharedPreferences.getInstance();
      final today = _todayKey();
      final newCount = (prefs.getInt('$_pomoCountPrefix$today') ?? 0) + 1;
      await prefs.setInt('$_pomoCountPrefix$today', newCount);
      final shouldShowBadge = newCount >= 4 && !_pomoBadgeShownToday;
      if (shouldShowBadge) {
        await prefs.setBool('$_pomoBadgePrefix$today', true);
      }
      if (!mounted) return;
      final isLongBreak = newCount % 4 == 0;
      setState(() {
        _pomoCyclesToday = newCount;
        _pomoOnBreak = true;
        _pomoRemaining = isLongBreak ? _pomoLongBreak : _pomoShortBreak;
        if (shouldShowBadge) _pomoBadgeShownToday = true;
      });
      _showPomoDialog(
        title: isLongBreak
            ? 'Descanso largo (15 min)'
            : 'Descanso corto (5 min)',
        message: isLongBreak
            ? 'Llevas $newCount pomodoros hoy. Tomate 15 min antes de seguir.'
            : 'Pomodoro #$newCount completado. Descansa 5 min.',
        showBadge: shouldShowBadge,
      );
      _startPomoTicker();
    } else {
      // Descanso completado -> vuelve a foco.
      if (!mounted) return;
      setState(() {
        _pomoOnBreak = false;
        _pomoRemaining = _pomoFocus;
      });
      _showPomoDialog(
        title: 'Vuelve al estudio',
        message: 'Empieza otro ciclo de 25 min.',
        showBadge: false,
      );
      _startPomoTicker();
    }
  }

  void _showPomoDialog({
    required String title,
    required String message,
    required bool showBadge,
  }) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.timer_rounded, color: AppColors.brand),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (showBadge) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DgtStatusColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: DgtStatusColors.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.emoji_events_rounded,
                        color: DgtStatusColors.warning),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Badge: 4 pomodoros en 1 dia',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatPomoRemaining() {
    final m = _pomoRemaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _pomoRemaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _initTtsIfNeeded() async {
    if (_tts != null) return;
    final tts = FlutterTts();
    await tts.setLanguage('es-ES');
    await tts.setSpeechRate(0.5);
    await tts.setVolume(1.0);
    await tts.awaitSpeakCompletion(true);
    _tts = tts;
  }

  Future<void> _toggleAudioMode() async {
    if (_audioMode) {
      _audioMode = false;
      _audioPaused = false;
      _audioRunId++;
      _audioTimer?.cancel();
      await _tts?.stop();
      if (mounted) setState(() {});
      return;
    }
    await _initTtsIfNeeded();
    setState(() {
      _audioMode = true;
      _audioPaused = false;
    });
    unawaited(_runAudioLoop());
  }

  Future<void> _toggleAudioPause() async {
    if (!_audioMode) return;
    setState(() => _audioPaused = !_audioPaused);
    if (_audioPaused) {
      _audioRunId++;
      _audioTimer?.cancel();
      await _tts?.stop();
    } else {
      unawaited(_runAudioLoop());
    }
  }

  Future<void> _speak(String text) async {
    final tts = _tts;
    if (tts == null) return;
    await tts.speak(text);
  }

  Future<bool> _wait(Duration d, int runId) async {
    final c = Completer<bool>();
    _audioTimer?.cancel();
    _audioTimer = Timer(d, () {
      if (!c.isCompleted) c.complete(true);
    });
    final ok = await c.future;
    return ok && runId == _audioRunId && _audioMode && !_audioPaused && mounted;
  }

  /// Bucle TTS: lee pregunta + opciones, espera, lee respuesta correcta,
  /// avanza a la siguiente. Se cancela si el usuario pausa, apaga audio o
  /// cambia manualmente de pregunta.
  Future<void> _runAudioLoop() async {
    final runId = ++_audioRunId;
    while (mounted && _audioMode && !_audioPaused && runId == _audioRunId) {
      if (_questions.isEmpty || _finished) return;
      if (_current >= _questions.length) return;
      final q = _questions[_current];
      await _speak(
        'Pregunta ${_current + 1}. ${q.statement}. '
        'Opcion A: ${q.optionA}. '
        'Opcion B: ${q.optionB}. '
        'Opcion C: ${q.optionC}.',
      );
      if (!await _wait(const Duration(seconds: 6), runId)) return;
      if (!_picked.containsKey(_current)) {
        // Auto-marca correcta para registrar avance.
        setState(() => _picked[_current] = q.correct);
      }
      final picked = _picked[_current];
      final correct = picked == q.correct;
      await _speak(
        correct
            ? 'Correcto. La respuesta es ${q.correct.toUpperCase()}.'
            : 'Incorrecto. La respuesta correcta es ${q.correct.toUpperCase()}.',
      );
      if (!await _wait(const Duration(seconds: 2), runId)) return;
      if (_current < _questions.length - 1) {
        setState(() => _current++);
      } else {
        setState(() => _finished = true);
        await _speak('Practica terminada.');
        return;
      }
    }
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

  /// Numero de preguntas con respuesta (independiente de si fue correcta).
  int _answeredCount() => _picked.length;

  /// Hook al exit: si la sesion tuvo >= 5 preguntas respondidas y aun no
  /// se mostro el resumen, abre [DgtSessionSummaryScreen] antes de hacer
  /// pop de la practica. Sesiones cortas salen directo. Si el quiz se
  /// completo via "Ver resumen" el flujo natural ya mostro el resumen
  /// inline y este hook se salta para no duplicar UX.
  Future<void> _handleExitWithSummary() async {
    if (_summaryShown || _finished) {
      // _finished: el usuario ya vio el resumen inline al completar el
      // quiz, no abrimos otro encima.
      Navigator.of(context).pop();
      return;
    }
    final answered = _answeredCount();
    if (!DgtSessionSummaryScreen.shouldShowFor(answered)) {
      Navigator.of(context).pop();
      return;
    }
    _summaryShown = true;
    final correct = _correctCount();
    final elapsed = DateTime.now().difference(_sessionStartedAt);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DgtSessionSummaryScreen(
          topicName: widget.topic.name,
          answeredCount: answered,
          correctCount: correct,
          elapsed: elapsed,
          weakestTopic: correct < answered ? widget.topic.name : null,
        ),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleExitWithSummary();
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final currentQ = (_questions.isNotEmpty && _current < _questions.length)
        ? _questions[_current]
        : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topic.name),
        actions: [
          if (currentQ != null && !_finished)
            IconButton(
              tooltip: 'Reportar errata',
              icon: const Icon(Icons.flag_outlined),
              onPressed: () => DgtReportQuestionSheet.show(
                context: context,
                ref: ref,
                questionId: currentQ.id,
              ),
            ),
          ..._PracticeAppBarActions(
            pomoActive: _pomoActive,
            pomoOnBreak: _pomoOnBreak,
            pomoRemainingLabel: _formatPomoRemaining(),
            pomoCyclesToday: _pomoCyclesToday,
            audioMode: _audioMode,
            onTogglePomodoro: _togglePomodoro,
            onToggleAudio: _toggleAudioMode,
          ).build(context),
        ],
      ),
      floatingActionButton: _audioMode
          ? FloatingActionButton(
              onPressed: _toggleAudioPause,
              backgroundColor: AppColors.brand,
              child: Icon(
                _audioPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              ),
            )
          : null,
      body: FutureBuilder<List<DgtQuestion>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return AppStateView.loading();
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
    final isLast = _current == qs.length - 1;

    return Column(
      children: [
        LinearProgressIndicator(
          value: (_current + 1) / qs.length,
          minHeight: 4,
          backgroundColor: context.c.surfaceMuted,
        ),
        Expanded(
          child: _PracticeQuestionView(
            question: q,
            index: _current,
            total: qs.length,
            picked: picked,
            onSelect: _selectAnswer,
          ),
        ),
        _PracticeBottomActions(
          answered: answered,
          isLast: isLast,
          onNext: _next,
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
                  ? DgtStatusColors.warning
                  : AppColors.brand,
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
                color: context.c.textSecondary,
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
        isCorrect ? DgtStatusColors.success : DgtStatusColors.accentOrange;
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
              color: context.c.textSecondary,
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
            color: context.c.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Issue #123 (dgt-tech): sub-componente puro para los `actions` del AppBar de
/// `DgtPracticeScreen`. Renderiza el chip Pomodoro activo (si corresponde) y
/// los toggles de Pomodoro y modo audio TTS. Sin estado propio: recibe flags y
/// callbacks del state principal para preservar el comportamiento original.
class _PracticeAppBarActions {
  final bool pomoActive;
  final bool pomoOnBreak;
  final String pomoRemainingLabel;
  final int pomoCyclesToday;
  final bool audioMode;
  final VoidCallback onTogglePomodoro;
  final VoidCallback onToggleAudio;

  const _PracticeAppBarActions({
    required this.pomoActive,
    required this.pomoOnBreak,
    required this.pomoRemainingLabel,
    required this.pomoCyclesToday,
    required this.audioMode,
    required this.onTogglePomodoro,
    required this.onToggleAudio,
  });

  List<Widget> build(BuildContext context) {
    return [
      if (pomoActive)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (pomoOnBreak
                      ? DgtStatusColors.success
                      : AppColors.brand)
                  .withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  pomoOnBreak
                      ? Icons.self_improvement_rounded
                      : Icons.timer_rounded,
                  size: 16,
                  color: pomoOnBreak
                      ? DgtStatusColors.success
                      : AppColors.brand,
                ),
                const SizedBox(width: 6),
                Text(
                  pomoRemainingLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      IconButton(
        tooltip: pomoActive
            ? 'Parar Pomodoro (hoy: $pomoCyclesToday)'
            : 'Iniciar Pomodoro 25/5 (hoy: $pomoCyclesToday)',
        icon: Icon(
          pomoActive ? Icons.timer_off_rounded : Icons.timer_rounded,
          color: pomoActive ? AppColors.brand : null,
        ),
        onPressed: onTogglePomodoro,
      ),
      IconButton(
        tooltip: audioMode ? 'Salir modo audio' : 'Modo audio',
        icon: Icon(
          audioMode ? Icons.headset_off_rounded : Icons.headset_rounded,
          color: audioMode ? AppColors.brand : null,
        ),
        onPressed: onToggleAudio,
      ),
    ];
  }
}

/// Issue #123 (dgt-tech): widget puro que renderiza la pregunta actual,
/// imagen opcional, las 3 opciones y la tarjeta de explicacion una vez
/// respondida. No tiene estado: recibe `picked` y delega seleccion via
/// `onSelect`. Equivalente 1:1 al inline anterior dentro de `_buildQuestion`.
class _PracticeQuestionView extends StatelessWidget {
  final DgtQuestion question;
  final int index;
  final int total;
  final String? picked;
  final ValueChanged<String> onSelect;

  const _PracticeQuestionView({
    required this.question,
    required this.index,
    required this.total,
    required this.picked,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final q = question;
    final answered = picked != null;
    final isCorrect = answered && picked == q.correct;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pregunta ${index + 1} / $total',
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
          if (q.imageUrl != null && q.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: DgtQuestionImage(path: q.imageUrl!),
            ),
          ],
          const SizedBox(height: 16),
          DgtAnswerTile.graded(
            letter: 'a',
            text: q.optionA,
            picked: picked,
            correct: q.correct,
            answered: answered,
            onTap: () => onSelect('a'),
          ),
          DgtAnswerTile.graded(
            letter: 'b',
            text: q.optionB,
            picked: picked,
            correct: q.correct,
            answered: answered,
            onTap: () => onSelect('b'),
          ),
          DgtAnswerTile.graded(
            letter: 'c',
            text: q.optionC,
            picked: picked,
            correct: q.correct,
            answered: answered,
            onTap: () => onSelect('c'),
          ),
          if (answered) ...[
            const SizedBox(height: 16),
            _ExplanationCard(question: q, isCorrect: isCorrect),
          ],
        ],
      ),
    );
  }
}

/// Issue #123 (dgt-tech): boton inferior "Siguiente" / "Ver resumen". El
/// callback `onNext` queda desactivado mientras no haya respuesta para
/// preservar la UX original (disabled hasta tap respuesta).
class _PracticeBottomActions extends StatelessWidget {
  final bool answered;
  final bool isLast;
  final VoidCallback onNext;

  const _PracticeBottomActions({
    required this.answered,
    required this.isLast,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Row(
          children: [
            const Spacer(),
            FilledButton.icon(
              onPressed: answered ? onNext : null,
              icon: Icon(isLast
                  ? Icons.flag_rounded
                  : Icons.chevron_right_rounded),
              label: Text(isLast ? 'Ver resumen' : 'Siguiente'),
            ),
          ],
        ),
      ),
    );
  }
}
