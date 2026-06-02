import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/widgets/app_state_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/api/api_client.dart';
import '../../data/repositories/dgt_repository.dart';

/// Modo "Reto dificultad alta" DGT (issue #78).
///
/// 10 preguntas con `difficulty=3` del backend, cronometro de 5 minutos
/// visible (no bloquea al expirar — solo warning visual). No persiste
/// historial de simulacros: solo guarda el ULTIMO intento (correct/total)
/// en SharedPreferences para mostrar el badge "tu ultimo reto: X/10".
///
/// Aditivo: no toca cache de simulacro, no rompe `DgtPracticeScreen` ni
/// `DgtQuickReviewScreen`. Reutiliza patron UI minimal de quiz (no extrae
/// a widget compartido por scope del issue — pendiente refactor futuro).
class DgtHardChallengeScreen extends ConsumerStatefulWidget {
  /// Numero de preguntas.
  static const int questionCount = 10;

  /// Cronometro total. NO bloquea — solo se muestra en rojo al expirar.
  static const Duration challengeDuration = Duration(minutes: 5);

  /// Difficulty pedida al backend (1-3 segun modelo DGT).
  static const int targetDifficulty = 3;

  /// Key SharedPreferences donde se persiste el ultimo intento (JSON).
  static const String lastAttemptPrefsKey = 'dgt_hard_challenge_last';

  const DgtHardChallengeScreen({super.key});

  @override
  ConsumerState<DgtHardChallengeScreen> createState() =>
      _DgtHardChallengeScreenState();

  /// Lee el ultimo intento persistido. Devuelve null si no existe o si el
  /// JSON esta corrupto. Usado por el tile del dashboard para mostrar
  /// "tu ultimo reto: X/Y".
  static Future<DgtHardChallengeLastAttempt?> readLastAttempt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(lastAttemptPrefsKey);
      if (raw == null || raw.isEmpty) return null;
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      final total = m['total'];
      final correct = m['correct'];
      if (total is! int || correct is! int) return null;
      return DgtHardChallengeLastAttempt(total: total, correct: correct);
    } catch (_) {
      return null;
    }
  }
}

class _DgtHardChallengeScreenState
    extends ConsumerState<DgtHardChallengeScreen> {
  late final int _totalSeconds;

  Future<List<DgtQuestion>>? _future;
  List<DgtQuestion> _questions = const [];
  final Map<int, String> _answers = {};
  int _current = 0;
  late int _secondsLeft;
  Timer? _ticker;
  bool _submitted = false;
  bool _finished = false;
  bool _timeExpired = false;
  _HardChallengeResult? _result;

  @override
  void initState() {
    super.initState();
    _totalSeconds = DgtHardChallengeScreen.challengeDuration.inSeconds;
    _secondsLeft = _totalSeconds;
    final repo = ref.read(dgtRepositoryProvider);
    _future = repo
        .fetchQuestionsByDifficulty(
      difficulty: DgtHardChallengeScreen.targetDifficulty,
      limit: DgtHardChallengeScreen.questionCount,
    )
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
          _secondsLeft = 0;
          _timeExpired = true;
          _ticker?.cancel();
          // No autosubmit: la consigna del issue es "no bloquea al expirar".
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
    if (_timeExpired) return const Color(0xFFFF5C5C);
    if (_secondsLeft <= _totalSeconds ~/ 3) return const Color(0xFFFFB74F);
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
        title: const Text('Terminar reto'),
        content: Text(
          unanswered == 0
              ? '¿Terminar el reto?'
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
    if (ok == true) await _submit();
  }

  Future<void> _submit() async {
    if (_submitted) return;
    _submitted = true;
    _ticker?.cancel();
    int correct = 0;
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final picked = _answers[i];
      if (picked != null && picked == q.correct) correct++;
    }
    final elapsed = _totalSeconds - _secondsLeft;
    final r = _HardChallengeResult(
      total: _questions.length,
      correct: correct,
      elapsedSeconds: elapsed,
      timeExpired: _timeExpired,
    );
    // Persistir best-effort. No bloquea UI si falla.
    try {
      await _persistLastAttempt(r);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _finished = true;
      _result = r;
    });
  }

  /// Persiste resultado en SharedPreferences. Privado al State.
  Future<void> _persistLastAttempt(_HardChallengeResult r) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode({
      'total': r.total,
      'correct': r.correct,
      'elapsed_seconds': r.elapsedSeconds,
      'time_expired': r.timeExpired,
      'ts': DateTime.now().toIso8601String(),
    });
    await prefs.setString(DgtHardChallengeScreen.lastAttemptPrefsKey, json);
  }

  @override
  Widget build(BuildContext context) {
    if (_finished && _result != null) {
      return _buildResult(context, _result!);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reto dificultad alta'),
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
                  'No se pudo cargar el reto: '
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
              if (_timeExpired)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFF5C5C).withValues(alpha: 0.18),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: const Text(
                    'Tiempo agotado. Puedes terminar cuando quieras.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF5C5C),
                    ),
                  ),
                ),
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
                            backgroundColor: const Color(0xFF4FFFB0),
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

  Widget _buildResult(BuildContext context, _HardChallengeResult r) {
    final wrong = r.total - r.correct;
    final pct = r.total == 0 ? 0 : ((r.correct / r.total) * 100).round();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reto dificultad alta'),
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
                  color: const Color(0xFFFF8A4F).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFF8A4F).withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: Color(0xFFFF8A4F),
                      size: 44,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reto terminado',
                      style: const TextStyle(
                        color: Color(0xFFFF8A4F),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${r.correct} / ${r.total} aciertos ($pct%)',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Fallos: $wrong - Tiempo: ${_formatTime(r.elapsedSeconds)}',
                      style: TextStyle(
                        color: context.c.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      // Placeholder hasta tener endpoint stats global.
                      '% vs media: pendiente (sin endpoint global)',
                      style: TextStyle(
                        color: context.c.textMuted,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (r.timeExpired) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Tiempo agotado antes de terminar.',
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

/// Resultado interno del reto. Visible solo dentro del archivo (test usa
/// `persistLastAttempt` con instancia construida ad-hoc).
class _HardChallengeResult {
  final int total;
  final int correct;
  final int elapsedSeconds;
  final bool timeExpired;
  const _HardChallengeResult({
    required this.total,
    required this.correct,
    required this.elapsedSeconds,
    required this.timeExpired,
  });
}

/// Snapshot ligero del ultimo intento. Expuesto para que el tile del
/// dashboard pueda mostrar "tu ultimo reto: X/Y" sin acoplarse al
/// `_HardChallengeResult` interno.
class DgtHardChallengeLastAttempt {
  final int total;
  final int correct;
  const DgtHardChallengeLastAttempt({
    required this.total,
    required this.correct,
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
    final color = selected
        ? const Color(0xFFFF8A4F)
        : context.c.surfaceMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
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
                    color: selected
                        ? Colors.white
                        : context.c.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    letter.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? const Color(0xFFFF8A4F)
                          : context.c.textPrimary,
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

