import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/widgets/app_state_view.dart';

import '../../data/repositories/dgt_repository.dart';
import 'dgt_exam_screen.dart';

/// Issue #135 (dgt-ux): mini-sesion de calentamiento de 10 preguntas variadas
/// pre-simulacro. Sin timer estricto, feedback inmediato (verde/rojo), y al
/// terminar muestra un resumen ligero con CTA para entrar al simulacro real.
///
/// **No se guarda en historial**: las respuestas se descartan al salir. El
/// objetivo es "activar la cabeza" en 3-5 minutos, no medir progreso.
///
/// Aditivo: no toca `DgtExamScreen` ni el historial. Reusa el card-de-pregunta
/// inline (mismo look-and-feel que practica/simulacro) pero sin cronometro,
/// reportes ni TTS para mantener la pantalla ligera y enfocada.
class DgtWarmupScreen extends ConsumerStatefulWidget {
  /// Cantidad de preguntas. Default 10 (3-5 minutos a 30s/pregunta).
  final int limit;

  const DgtWarmupScreen({super.key, this.limit = 10});

  @override
  ConsumerState<DgtWarmupScreen> createState() => _DgtWarmupScreenState();
}

class _DgtWarmupScreenState extends ConsumerState<DgtWarmupScreen> {
  late Future<List<DgtQuestion>> _future;
  List<DgtQuestion> _questions = const [];

  /// Letra elegida por pregunta (null = sin responder).
  final Map<int, String> _picked = {};
  int _current = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _future = ref
        .read(dgtRepositoryProvider)
        .fetchRandomWarmup(limit: widget.limit);
  }

  int get _correctCount {
    var n = 0;
    for (var i = 0; i < _questions.length; i++) {
      final pick = _picked[i];
      if (pick != null && pick == _questions[i].correct) n++;
    }
    return n;
  }

  void _onPick(String letter) {
    if (_picked[_current] != null) return; // ya respondida
    setState(() {
      _picked[_current] = letter;
    });
  }

  void _next() {
    if (_current >= _questions.length - 1) {
      setState(() => _finished = true);
      return;
    }
    setState(() => _current++);
  }

  void _startSimulacroReal() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const DgtExamScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Calentamiento DGT',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4),
        ),
      ),
      body: FutureBuilder<List<DgtQuestion>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return AppStateView.loading();
          }
          if (snapshot.hasError) {
            return _ErrorState(error: '${snapshot.error}');
          }
          final data = snapshot.data ?? const <DgtQuestion>[];
          if (data.isEmpty) {
            return const _ErrorState(
              error: 'No se pudieron cargar preguntas de calentamiento.',
            );
          }
          if (_questions.isEmpty) {
            _questions = data;
          }
          if (_finished) {
            return _WarmupSummary(
              total: _questions.length,
              correct: _correctCount,
              onSimulacroReal: _startSimulacroReal,
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                  _WarmupAnswerTile(
                    letter: 'a',
                    text: q.optionA,
                    picked: picked,
                    correct: q.correct,
                    answered: answered,
                    onTap: () => _onPick('a'),
                  ),
                  _WarmupAnswerTile(
                    letter: 'b',
                    text: q.optionB,
                    picked: picked,
                    correct: q.correct,
                    answered: answered,
                    onTap: () => _onPick('b'),
                  ),
                  _WarmupAnswerTile(
                    letter: 'c',
                    text: q.optionC,
                    picked: picked,
                    correct: q.correct,
                    answered: answered,
                    onTap: () => _onPick('c'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: answered ? _next : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.brand,
                foregroundColor: context.c.onAccent,
                disabledBackgroundColor: context.c.surfaceMuted,
                disabledForegroundColor: context.c.textMuted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _current >= _questions.length - 1 ? 'Terminar' : 'Siguiente',
                style: const TextStyle(
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

class _WarmupAnswerTile extends StatelessWidget {
  final String letter;
  final String text;
  final String? picked;
  final String correct;
  final bool answered;
  final VoidCallback onTap;

  const _WarmupAnswerTile({
    required this.letter,
    required this.text,
    required this.picked,
    required this.correct,
    required this.answered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = picked == letter;
    final isCorrectOption = letter == correct;

    Color bg = context.c.surfaceMuted;
    Color iconBg = context.c.border;
    Color iconFg = context.c.textPrimary;

    if (answered) {
      if (isCorrectOption) {
        bg = const Color(0xFF4FFFB0).withValues(alpha: 0.18);
        iconBg = const Color(0xFF4FFFB0);
        iconFg = Colors.black;
      } else if (selected) {
        bg = const Color(0xFFFF5C5C).withValues(alpha: 0.18);
        iconBg = const Color(0xFFFF5C5C);
        iconFg = Colors.white;
      }
    } else if (selected) {
      bg = AppColors.brand;
      iconFg = Colors.white;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: answered ? null : onTap,
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
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: iconFg,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 15, height: 1.35),
                  ),
                ),
                if (answered && isCorrectOption)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF4FFFB0),
                    size: 20,
                  )
                else if (answered && selected && !isCorrectOption)
                  const Icon(
                    Icons.cancel_rounded,
                    color: Color(0xFFFF5C5C),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WarmupSummary extends StatelessWidget {
  final int total;
  final int correct;
  final VoidCallback onSimulacroReal;
  final VoidCallback onExit;

  const _WarmupSummary({
    required this.total,
    required this.correct,
    required this.onSimulacroReal,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : ((correct / total) * 100).round();
    final isReady = pct >= 70;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              isReady
                  ? Icons.local_fire_department_rounded
                  : Icons.bolt_rounded,
              size: 72,
              color: isReady
                  ? const Color(0xFF4FFFB0)
                  : const Color(0xFFFFB84F),
            ),
            const SizedBox(height: 16),
            Text(
              isReady ? 'Estas listo' : 'Cabeza activada',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$correct de $total correctas ($pct%)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: context.c.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Este calentamiento no se guarda en tu historial.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: context.c.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: onSimulacroReal,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Ahora si, simulacro real',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onExit,
              child: Text(
                'Salir',
                style: TextStyle(
                  color: context.c.textSecondary,
                  fontWeight: FontWeight.w600,
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
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFFF5C5C),
              size: 56,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.c.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
