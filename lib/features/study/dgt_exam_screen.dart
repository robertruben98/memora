import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/memora_card.dart';
import '../../data/repositories/card_repository.dart';
import 'dgt_exam_result_screen.dart';

/// Simulacro DGT permiso B: 30 preguntas aleatorias, 30 minutos, sin feedback
/// inmediato. Replica condiciones del examen oficial para preparacion.
///
/// Issue: https://github.com/robertruben98/memora/issues/31
class DgtExamScreen extends ConsumerStatefulWidget {
  static const int questionCount = 30;
  static const Duration examDuration = Duration(minutes: 30);
  static const int passingThreshold = 3; // max fallos para aprobar

  const DgtExamScreen({super.key});

  @override
  ConsumerState<DgtExamScreen> createState() => _DgtExamScreenState();
}

class _DgtExamScreenState extends ConsumerState<DgtExamScreen> {
  late final DateTime _startedAt;
  Timer? _ticker;
  Duration _remaining = DgtExamScreen.examDuration;
  int _index = 0;
  // Selecciones del usuario: null = sin contestar. true = correcta marcada,
  // false = incorrecta marcada. Lo guardamos como bool? para no exponer texto
  // de respuesta (las flashcards solo tienen front/back).
  final Map<int, bool> _selections = {};
  List<MemoraCard> _questions = const [];
  bool _initialised = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        final elapsed = DateTime.now().difference(_startedAt);
        final left = DgtExamScreen.examDuration - elapsed;
        _remaining = left.isNegative ? Duration.zero : left;
      });
      if (_remaining == Duration.zero && !_finished) {
        _finish(expired: true);
      }
    });
  }

  void _initialiseQuestions(List<MemoraCard> all) {
    if (_initialised) return;
    _initialised = true;
    final shuffled = [...all]..shuffle(Random());
    _questions = shuffled.take(DgtExamScreen.questionCount).toList();
    _startTicker();
  }

  void _finish({bool expired = false}) {
    if (_finished) return;
    _finished = true;
    _ticker?.cancel();
    final elapsed = DateTime.now().difference(_startedAt);
    final usedTime = elapsed > DgtExamScreen.examDuration
        ? DgtExamScreen.examDuration
        : elapsed;
    // Convertimos selecciones a estructura para la pantalla resultado.
    final results = <DgtExamAnswer>[];
    for (var i = 0; i < _questions.length; i++) {
      results.add(
        DgtExamAnswer(
          card: _questions[i],
          correct: _selections[i] == true,
          answered: _selections.containsKey(i),
        ),
      );
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DgtExamResultScreen(
          answers: results,
          timeUsed: usedTime,
          expired: expired,
        ),
      ),
    );
  }

  Future<bool> _confirmExit() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A22),
        title: const Text('¿Salir del simulacro?'),
        content: const Text(
          'Si sales perderas el progreso. El examen oficial no permite pausa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Seguir'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salir', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(allCardsProvider);
    return cardsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Simulacro DGT')),
        body: Center(child: Text('Error cargando preguntas: $e')),
      ),
      data: (cards) {
        if (cards.length < DgtExamScreen.questionCount) {
          return _NotEnoughCardsScreen(have: cards.length);
        }
        _initialiseQuestions(cards);
        return _examShell();
      },
    );
  }

  Widget _examShell() {
    final danger = _remaining.inSeconds <= 5 * 60;
    final mins = _remaining.inMinutes.toString().padLeft(2, '0');
    final secs = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    final current = _questions[_index];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit()) {
          if (mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Pregunta ${_index + 1}/${DgtExamScreen.questionCount}'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: danger
                        ? Colors.redAccent.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: danger ? Colors.redAccent : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 18,
                        color: danger ? Colors.redAccent : Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$mins:$secs',
                        style: TextStyle(
                          color: danger ? Colors.redAccent : Colors.white,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          current.front,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Marca tu respuesta (correcta / incorrecta). En el simulacro no veras la solucion hasta el final.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _AnswerTile(
                          label: 'Marcar como correcta',
                          icon: Icons.check_circle_outline_rounded,
                          selected: _selections[_index] == true,
                          color: Colors.greenAccent,
                          onTap: () => setState(() {
                            _selections[_index] = true;
                          }),
                        ),
                        const SizedBox(height: 10),
                        _AnswerTile(
                          label: 'Marcar como incorrecta',
                          icon: Icons.cancel_outlined,
                          selected: _selections[_index] == false,
                          color: Colors.redAccent,
                          onTap: () => setState(() {
                            _selections[_index] = false;
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _index == 0
                            ? null
                            : () => setState(() => _index--),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Anterior'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _index == DgtExamScreen.questionCount - 1
                          ? FilledButton.icon(
                              onPressed: () => _finish(),
                              icon: const Icon(Icons.flag_rounded),
                              label: const Text('Terminar'),
                            )
                          : FilledButton.icon(
                              onPressed: () => setState(() => _index++),
                              icon: const Icon(Icons.arrow_forward_rounded),
                              label: const Text('Siguiente'),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnswerTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _AnswerTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.15) : const Color(0xFF1A1A22),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : Colors.white12,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: selected ? color : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotEnoughCardsScreen extends StatelessWidget {
  final int have;
  const _NotEnoughCardsScreen({required this.have});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Simulacro DGT')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
                size: 56,
              ),
              const SizedBox(height: 16),
              const Text(
                'Necesitas al menos 30 tarjetas',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Tienes $have. Crea o importa mas tarjetas (preguntas DGT) para poder hacer un simulacro completo.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
