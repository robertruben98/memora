import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';

import '../../data/repositories/dgt_repository.dart';
import 'dgt_exam_controller.dart';
import 'dgt_exam_snapshot.dart';
import 'dgt_failures_repository.dart';
import 'dgt_favorites_provider.dart';
import 'dgt_favorites_screen.dart';
import 'dgt_prediction.dart';
import 'dgt_result_screen.dart';
import 'dgt_sprint_screen.dart';
import 'dgt_topics_screen.dart';
import 'dgt_video_questions_screen.dart';
import 'widgets/dgt_exam_body.dart';
import 'widgets/dgt_exam_intro.dart';
import 'widgets/dgt_exam_widgets.dart';
import 'widgets/dgt_report_question_sheet.dart';

/// Pantalla principal del simulacro DGT permiso B.
/// - 30 preguntas, 30 min, criterio aprobado <=3 fallos.
///
/// Modos:
/// - Estandar: navegacion libre, flag, grid, terminar antes.
/// - Estricto ([strictMode]=true, issue #87): timer 30min sin pausa,
///   solo "Siguiente" (no Anterior, no flag, no grid), entrega automatica
///   al responder la 30 o al agotar tiempo. Sin revision intermedia.
///
/// Issue #139 (dgt-tech): timer + scoring + navegacion viven en
/// [DgtExamController]. Esta pantalla solo orquesta UI + persistencia del
/// snapshot (issue #133) + push a [DgtResultScreen]. La intro y los tiles
/// de respuesta viven en `widgets/dgt_exam_intro.dart` y
/// `widgets/dgt_exam_widgets.dart`.
class DgtExamScreen extends ConsumerStatefulWidget {
  final bool strictMode;

  /// Issue #133 (dgt-ux): si se proporciona, el simulacro se inicia desde
  /// este snapshot persistido (preguntas, respuestas, indice, timer) en
  /// lugar de pedir uno nuevo. Solo aplica en modo no-estricto.
  final DgtExamSnapshot? resumeFrom;

  const DgtExamScreen({
    super.key,
    this.strictMode = false,
    this.resumeFrom,
  });

  @override
  ConsumerState<DgtExamScreen> createState() => _DgtExamScreenState();
}

class _DgtExamScreenState extends ConsumerState<DgtExamScreen> {
  Future<List<DgtQuestion>>? _future;
  DgtExamController? _controller;
  bool _resultNavigationLaunched = false;

  bool get _strict => widget.strictMode;

  /// Modo intro: muestra Card de prediccion antes del simulacro (issue #52).
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // Dispara fetch de prediccion al construir; el simulacro se carga
    // cuando el usuario pulsa "Empezar".
    ref.read(dgtPredictionProvider);
    if (_strict) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _begin();
      });
    }
    if (!_strict && widget.resumeFrom != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resumeFromSnapshot(widget.resumeFrom!);
      });
    }
  }

  void _resumeFromSnapshot(DgtExamSnapshot snap) {
    final ctrl = DgtExamController.fromSnapshot(
      questions: snap.questions,
      answers: snap.answers,
      flagged: snap.flagged,
      currentIndex: snap.currentIndex,
      secondsRemaining: snap.secondsRemaining,
      startedAt: snap.startedAt,
      strictMode: _strict,
    );
    setState(() {
      _started = true;
      _controller = ctrl;
      _future = Future.value(snap.questions);
    });
    ctrl.addListener(_onControllerChanged);
    if (ctrl.isSubmitted) {
      // Tiempo expirado mientras la app estaba cerrada -> entrega auto.
      _handleSubmittedResult(autoSubmit: true);
      return;
    }
    ctrl.startTimer();
    _persistSnapshot();
  }

  void _onControllerChanged() {
    final ctrl = _controller;
    if (ctrl == null) return;
    _persistSnapshot();
    if (ctrl.isSubmitted) {
      _handleSubmittedResult(autoSubmit: ctrl.remainingSeconds <= 0);
    }
    if (mounted) setState(() {});
  }

  /// Issue #133: persiste snapshot best-effort. No-op en strict.
  void _persistSnapshot() {
    final ctrl = _controller;
    if (ctrl == null) return;
    if (_strict || ctrl.isSubmitted || ctrl.questions.isEmpty) return;
    final snap = ctrl.toSnapshot();
    final repo = ref.read(dgtExamSnapshotRepositoryProvider);
    repo.save(
      DgtExamSnapshot(
        questions: snap.questions,
        answers: snap.answers,
        flagged: snap.flagged,
        currentIndex: snap.currentIndex,
        secondsRemaining: snap.remainingSeconds,
        startedAt: snap.startedAt,
      ),
    );
  }

  void _clearSnapshot() {
    final repo = ref.read(dgtExamSnapshotRepositoryProvider);
    repo.clear();
  }

  void _begin() {
    if (_started) return;
    final repo = ref.read(dgtRepositoryProvider);
    setState(() {
      _started = true;
      _future = repo.fetchExamQuestions(limit: 30).then((qs) {
        final ctrl = DgtExamController(
          questions: qs,
          strictMode: _strict,
        );
        ctrl.addListener(_onControllerChanged);
        ctrl.startTimer();
        _controller = ctrl;
        _persistSnapshot();
        if (mounted) setState(() {});
        return qs;
      });
    });
  }

  /// Issue #87: confirmacion explicita antes de entrar al modo estricto.
  Future<void> _confirmStartStrict() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modo examen real'),
        content: const Text(
          'Vas a hacer un examen en condiciones reales:\n\n'
          '- 30 minutos sin pausa\n'
          '- No podras volver a preguntas anteriores\n'
          '- No veras explicaciones hasta terminar\n'
          '- Si se acaba el tiempo, se entrega automaticamente\n\n'
          'Estas listo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: DgtStatusColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Empezar examen'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const DgtExamScreen(strictMode: true),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  String _formatTime(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  Color _timerColor(BuildContext context, int remainingSeconds) {
    if (remainingSeconds <= 5 * 60) return DgtStatusColors.error;
    return context.c.textPrimary;
  }

  Future<void> _confirmFinish() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    final unanswered = ctrl.questions.length - ctrl.answeredCount;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminar simulacro'),
        content: Text(
          unanswered == 0
              ? 'Vas a entregar el examen. ¿Continuar?'
              : 'Te quedan $unanswered preguntas sin responder. '
                  'Las sin responder cuentan como falladas. ¿Entregar igual?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Entregar'),
          ),
        ],
      ),
    );
    if (ok == true) ctrl.submit();
  }

  /// Centraliza handling de `submitted`: persiste fallos + limpia snapshot
  /// + navega al result screen. Guarded por flag para evitar dobles push.
  void _handleSubmittedResult({required bool autoSubmit}) {
    if (_resultNavigationLaunched) return;
    final ctrl = _controller;
    if (ctrl == null) return;
    _resultNavigationLaunched = true;
    _clearSnapshot();
    final result = ctrl.buildResult();
    // Issue #95 (dgt-content): persistir fallos para "Repaso de fallos".
    if (result.wrong.isNotEmpty) {
      final failedQs = result.wrong.map((r) => r.question).toList();
      ref
          .read(dgtFailuresRepositoryProvider)
          .recordFailures(failedQs)
          .then((_) {
        ref.invalidate(dgtRecentFailuresCountProvider);
        ref.invalidate(dgtRecentFailuresProvider);
      });
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DgtResultScreen(
          result: result,
          autoSubmitted: autoSubmit,
        ),
      ),
    );
  }

  void _showQuestionGrid() {
    final ctrl = _controller;
    if (ctrl == null) return;
    DgtQuestionGridSheet.show(context: context, controller: ctrl);
  }

  Widget _buildIntro(BuildContext context) {
    return DgtExamIntro(
      strictMode: _strict,
      onBegin: _begin,
      onStartStrict: _confirmStartStrict,
      onOpenFavorites: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const DgtFavoritesScreen(),
          ),
        );
      },
      onOpenVideos: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const DgtVideoQuestionsScreen(),
          ),
        );
      },
      onOpenSprint: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const DgtSprintScreen(),
          ),
        );
      },
      onPracticeWeakest: (topicId) {
        // Sin pantalla de practica por tema todavia (issue #51 en curso):
        // mostramos un snackbar informativo. Cuando #51 aterrice se
        // sustituira por un Navigator.push al modo practica.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Modo practica por tema todavia no disponible. '
              'Tema sugerido: $topicId',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) return _buildIntro(context);
    final ctrl = _controller;
    final currentQ = ctrl?.currentQuestion;
    final isFavCurrent = currentQ == null
        ? false
        : ref.watch(dgtFavoritesProvider).contains(currentQ.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(_strict ? 'Examen real DGT' : 'Simulacro DGT'),
        automaticallyImplyLeading: !_strict,
        actions: [
          if (!_strict && currentQ != null)
            IconButton(
              tooltip:
                  isFavCurrent ? 'Quitar de favoritas' : 'Marcar favorita',
              icon: Icon(
                isFavCurrent
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: isFavCurrent ? const Color(0xFFFFC857) : null,
              ),
              onPressed: () {
                ref
                    .read(dgtFavoritesProvider.notifier)
                    .toggle(currentQ.id);
              },
            ),
          if (!_strict)
            IconButton(
              tooltip: 'Practica por tema',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DgtTopicsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.category_outlined),
            ),
          // Issue #129 (dgt-ux): reportar errata.
          if (!_strict && currentQ != null)
            IconButton(
              tooltip: 'Reportar errata',
              icon: const Icon(Icons.flag_outlined),
              onPressed: () => DgtReportQuestionSheet.show(
                context: context,
                ref: ref,
                questionId: currentQ.id,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                _formatTime(
                    ctrl?.remainingSeconds ?? DgtExamController.totalSeconds),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: _timerColor(context,
                      ctrl?.remainingSeconds ?? DgtExamController.totalSeconds),
                ),
              ),
            ),
          ),
        ],
      ),
      body: DgtExamBody(
        future: _future,
        controller: ctrl,
        strictMode: _strict,
        onShowQuestionGrid: _showQuestionGrid,
        onConfirmFinish: _confirmFinish,
      ),
    );
  }
}
