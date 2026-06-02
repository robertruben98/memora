import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';
import 'package:memora/core/widgets/app_state_view.dart';

import '../../data/api/api_client.dart';
import '../../data/repositories/dgt_repository.dart';
import 'dgt_failures_repository.dart';

/// Modo Review Rapido DGT: 10 preguntas, 3 minutos, sin persistencia en
/// historial de simulacros. Pensado para micro-sesiones (cola del super,
/// autobus). Reutiliza la UI base de [DgtExamScreen] pero con parametros
/// reducidos y un veredicto simple "Bien (X/10)" sin clasificacion oficial.
///
/// Issue: https://github.com/robertruben98/memora/issues/53
///
/// Parametros (constantes publicas para futura parametrizacion sin refactor):
/// - [questionCount] = 10
/// - [examDuration] = 3 minutos
/// - [passingThreshold] = 1 fallo max (a efectos del badge "Bien", no oficial)
class DgtQuickReviewScreen extends ConsumerStatefulWidget {
  /// Numero de preguntas del repaso rapido.
  static const int questionCount = 10;

  /// Duracion total del repaso rapido.
  static const Duration examDuration = Duration(minutes: 3);

  /// Max fallos para considerar el repaso "bien" hecho (no es criterio DGT).
  static const int passingThreshold = 1;

  const DgtQuickReviewScreen({super.key});

  @override
  ConsumerState<DgtQuickReviewScreen> createState() =>
      _DgtQuickReviewScreenState();
}

class _DgtQuickReviewScreenState
    extends ConsumerState<DgtQuickReviewScreen> {
  late final int _totalSeconds;

  Future<List<DgtQuestion>>? _future;
  List<DgtQuestion> _questions = const [];
  final Map<int, String> _answers = {};
  int _current = 0;
  late int _secondsLeft;
  Timer? _ticker;
  bool _submitted = false;
  bool _finished = false;
  _QuickReviewResult? _result;

  @override
  void initState() {
    super.initState();
    _totalSeconds = DgtQuickReviewScreen.examDuration.inSeconds;
    _secondsLeft = _totalSeconds;
    final repo = ref.read(dgtRepositoryProvider);
    _future = repo
        .fetchExamQuestions(limit: DgtQuickReviewScreen.questionCount)
        .then((qs) {
      _questions = qs;
      _startTimer();
      return qs;
    });
  }

  void _startTimer() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _secondsLeft = _secondsLeft - 1;
        if (_secondsLeft <= 0) {
          _ticker?.cancel();
          _submit(autoSubmit: true);
        }
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatTime(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  Color _timerColor(BuildContext context) {
    // Bajo umbral: ultimo tercio del tiempo total.
    if (_secondsLeft <= _totalSeconds ~/ 3) return DgtStatusColors.error;
    return context.c.textPrimary;
  }

  void _selectAnswer(String letter) {
    setState(() => _answers[_current] = letter);
  }

  void _go(int index) {
    if (index < 0 || index >= _questions.length) return;
    setState(() => _current = index);
  }

  Future<void> _confirmFinish() async {
    final unanswered = _questions.length - _answers.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminar repaso rapido'),
        content: Text(
          unanswered == 0
              ? '¿Terminar el repaso?'
              : 'Te quedan $unanswered preguntas sin responder. '
                  'Las sin responder cuentan como falladas. ¿Terminar igual?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terminar'),
          ),
        ],
      ),
    );
    if (ok == true) _submit();
  }

  void _submit({bool autoSubmit = false}) {
    if (_submitted) return;
    _submitted = true;
    _ticker?.cancel();
    int correct = 0;
    // Issue #95 (dgt-content): tracking de fallos en ventana 7 dias.
    final failed = <DgtQuestion>[];
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final picked = _answers[i];
      if (picked != null && picked == q.correct) {
        correct++;
      } else {
        failed.add(q);
      }
    }
    if (failed.isNotEmpty) {
      ref
          .read(dgtFailuresRepositoryProvider)
          .recordFailures(failed)
          .then((_) {
        ref.invalidate(dgtRecentFailuresCountProvider);
        ref.invalidate(dgtRecentFailuresProvider);
      });
    }
    setState(() {
      _finished = true;
      _result = _QuickReviewResult(
        total: _questions.length,
        correct: correct,
        autoSubmitted: autoSubmit,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_finished && _result != null) {
      return _buildResult(context, _result!);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Repaso rapido'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                _formatTime(_secondsLeft),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: _timerColor(context),
                ),
              ),
            ),
          ),
        ],
      ),
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
                  'No se pudo cargar el repaso: '
                  '${snap.error ?? "sin preguntas"}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final qs = snap.data!;
          if (_current >= qs.length) _current = qs.length - 1;
          final q = qs[_current];
          final picked = _answers[_current];
          return Column(
            children: [
              LinearProgressIndicator(
                value: (_current + 1) / qs.length,
                minHeight: 4,
                backgroundColor: context.c.surfaceMuted,
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
                          color: context.c.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
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
                          child: _DgtImage(path: q.imageUrl!),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _AnswerTile(
                        letter: 'a',
                        text: q.optionA,
                        selected: picked == 'a',
                        onTap: () => _selectAnswer('a'),
                      ),
                      _AnswerTile(
                        letter: 'b',
                        text: q.optionB,
                        selected: picked == 'b',
                        onTap: () => _selectAnswer('b'),
                      ),
                      _AnswerTile(
                        letter: 'c',
                        text: q.optionC,
                        selected: picked == 'c',
                        onTap: () => _selectAnswer('c'),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            _current > 0 ? () => _go(_current - 1) : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                        label: const Text('Anterior'),
                      ),
                      const Spacer(),
                      if (_current < qs.length - 1)
                        FilledButton.icon(
                          onPressed: () => _go(_current + 1),
                          icon: const Icon(Icons.chevron_right_rounded),
                          label: const Text('Siguiente'),
                        )
                      else
                        FilledButton.icon(
                          onPressed: _confirmFinish,
                          style: FilledButton.styleFrom(
                            backgroundColor: DgtStatusColors.success,
                            foregroundColor: Colors.black,
                          ),
                          icon: const Icon(Icons.check_circle_rounded),
                          label: const Text('Terminar'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResult(BuildContext context, _QuickReviewResult r) {
    // Veredicto simple, sin clasificacion oficial APROBADO/SUSPENSO ni
    // persistencia en historial de simulacros (criterio del issue).
    final wrong = r.total - r.correct;
    final wentWell = wrong <= DgtQuickReviewScreen.passingThreshold;
    final color =
        wentWell ? DgtStatusColors.success : DgtStatusColors.warning;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Repaso rapido'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Icon(
                      wentWell
                          ? Icons.thumb_up_rounded
                          : Icons.refresh_rounded,
                      color: color,
                      size: 44,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      wentWell ? 'Bien' : 'Sigue practicando',
                      style: TextStyle(
                        color: color,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${r.correct} / ${r.total}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Repaso no oficial - no se guarda en historial.',
                      style: TextStyle(
                        color: context.c.textSecondary,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (r.autoSubmitted) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Tiempo agotado.',
                        style: TextStyle(
                          color: context.c.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  // 48 = tap-target accesible (>=44).
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Volver'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickReviewResult {
  final int total;
  final int correct;
  final bool autoSubmitted;
  const _QuickReviewResult({
    required this.total,
    required this.correct,
    required this.autoSubmitted,
  });
}

class _AnswerTile extends StatelessWidget {
  final String letter;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _AnswerTile({
    required this.letter,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brand : context.c.surfaceMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            // Tap-target accesible: 48px altura minima cumple Material >=44.
            constraints: const BoxConstraints(minHeight: 48),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? context.c.onAccent : context.c.border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    letter.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: selected ? AppColors.brand : context.c.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.35,
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
        color: context.c.surfaceMuted,
        child: const Icon(Icons.image_not_supported_outlined),
      ),
    );
  }
}
