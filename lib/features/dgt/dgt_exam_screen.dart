import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/repositories/dgt_repository.dart';
import 'dgt_prediction.dart';
import 'dgt_result_screen.dart';
import 'dgt_topics_screen.dart';
import 'dgt_video_questions_screen.dart';

/// Pantalla principal del simulacro DGT permiso B.
/// - 30 preguntas, 30 min, criterio aprobado <=3 fallos.
///
/// Modos:
/// - Estandar: navegacion libre, flag, grid, terminar antes.
/// - Estricto ([strictMode]=true, issue #87): timer 30min sin pausa,
///   solo "Siguiente" (no Anterior, no flag, no grid), entrega automatica
///   al responder la 30 o al agotar tiempo. Sin revision intermedia.
class DgtExamScreen extends ConsumerStatefulWidget {
  final bool strictMode;
  const DgtExamScreen({super.key, this.strictMode = false});

  @override
  ConsumerState<DgtExamScreen> createState() => _DgtExamScreenState();
}

class _DgtExamScreenState extends ConsumerState<DgtExamScreen> {
  static const _totalSeconds = 30 * 60;

  Future<List<DgtQuestion>>? _future;
  List<DgtQuestion> _questions = const [];
  final Map<int, String> _answers = {};
  final Set<int> _flagged = {};
  int _current = 0;
  int _secondsLeft = _totalSeconds;
  Timer? _ticker;
  bool _submitted = false;

  bool get _strict => widget.strictMode;

  /// Modo intro: muestra Card de prediccion antes del simulacro.
  /// Issue #52: usuario ve "tu probabilidad de aprobar" y tema mas debil
  /// antes de empezar. Pulsa "Empezar simulacro" -> _begin().
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // Disparamos el fetch de prediccion al construir; el simulacro se
    // carga solo cuando el usuario pulsa "Empezar".
    ref.read(dgtPredictionProvider);
    // En modo estricto la confirmacion ya se mostro en la pantalla previa,
    // arrancamos sin intro post-frame para evitar setState en initState.
    if (_strict) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _begin();
      });
    }
  }

  void _begin() {
    if (_started) return;
    final repo = ref.read(dgtRepositoryProvider);
    setState(() {
      _started = true;
      _future = repo.fetchExamQuestions(limit: 30).then((qs) {
        _questions = qs;
        _startTimer();
        return qs;
      });
    });
  }

  /// Issue #87: confirmacion explicita antes de entrar al modo estricto.
  /// El usuario debe saber que no podra pausar ni revisar.
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
              backgroundColor: const Color(0xFFFF5C5C),
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

  Color _timerColor() {
    if (_secondsLeft <= 5 * 60) return const Color(0xFFFF5C5C);
    return Colors.white;
  }

  void _selectAnswer(String letter) {
    setState(() => _answers[_current] = letter);
  }

  void _toggleFlag() {
    setState(() {
      if (_flagged.contains(_current)) {
        _flagged.remove(_current);
      } else {
        _flagged.add(_current);
      }
    });
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
    if (ok == true) _submit();
  }

  void _submit({bool autoSubmit = false}) {
    if (_submitted) return;
    _submitted = true;
    _ticker?.cancel();
    final result = _buildResult();
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

  DgtExamResult _buildResult() {
    int correct = 0;
    final wrong = <DgtAnswerReview>[];
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final picked = _answers[i];
      final ok = picked != null && picked == q.correct;
      if (ok) {
        correct++;
      } else {
        wrong.add(DgtAnswerReview(question: q, picked: picked));
      }
    }
    return DgtExamResult(
      total: _questions.length,
      correct: correct,
      wrong: wrong,
      elapsedSeconds: _totalSeconds - _secondsLeft,
      strictMode: _strict,
    );
  }

  void _showQuestionGrid() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A22),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preguntas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_questions.length, (i) {
                    final answered = _answers.containsKey(i);
                    final flagged = _flagged.contains(i);
                    final isCurrent = i == _current;
                    Color bg;
                    if (isCurrent) {
                      bg = const Color(0xFF7C5CFF);
                    } else if (flagged) {
                      bg = const Color(0xFFFFB74F);
                    } else if (answered) {
                      bg = const Color(0xFF4FFFB0).withValues(alpha: 0.35);
                    } else {
                      bg = Colors.white.withValues(alpha: 0.08);
                    }
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _go(i);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                _legendRow(const Color(0xFF7C5CFF), 'Actual'),
                _legendRow(
                    const Color(0xFF4FFFB0).withValues(alpha: 0.35), 'Respondida'),
                _legendRow(const Color(0xFFFFB74F), 'Marcada'),
                _legendRow(
                    Colors.white.withValues(alpha: 0.08), 'Sin responder'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _legendRow(Color c, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              )),
        ],
      ),
    );
  }

  /// Pantalla previa al simulacro. Muestra la Card de prediccion (issue #52)
  /// y el boton "Empezar simulacro". Aditiva: si el usuario quiere saltarla
  /// no hay forma de skippearla porque es valor anadido — el flujo previo
  /// no tenia confirmacion explicita.
  Widget _buildIntro(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Simulacro DGT')),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Examen oficial DGT',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '30 preguntas - 30 minutos - aprobado con max 3 fallos.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Seccion "Examen 2026": novedades del examen oficial (videos de
            // percepcion de riesgo). Issue #77. Boton aditivo, no toca el flow
            // del simulacro clasico de 30 preguntas.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: _Examen2026Section(
                onOpenVideos: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DgtVideoQuestionsScreen(),
                    ),
                  );
                },
              ),
            ),
            DgtPredictionCard(
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
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _strict ? null : _begin,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF7C5CFF),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text(
                    'Empezar simulacro',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            // Modo examen real estricto (issue #87): sin pausa, sin revisar,
            // sin volver atras. Timer 30min y entrega automatica.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('dgt-strict-mode-cta'),
                  onPressed: _confirmStartStrict,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFFF5C5C)),
                    foregroundColor: const Color(0xFFFF5C5C),
                  ),
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text(
                    'Modo examen real',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) return _buildIntro(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_strict ? 'Examen real DGT' : 'Simulacro DGT'),
        // En estricto no permitimos abandonar con back del AppBar:
        // simulamos condiciones reales. El usuario puede cerrar la app,
        // pero no salir "limpio".
        automaticallyImplyLeading: !_strict,
        actions: [
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                _formatTime(_secondsLeft),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: _timerColor(),
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
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || (snap.data ?? const []).isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo cargar el simulacro: ${snap.error ?? "sin preguntas"}',
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
                backgroundColor: Colors.white.withValues(alpha: 0.08),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Pregunta ${_current + 1} / ${qs.length}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (!_strict) ...[
                            IconButton(
                              tooltip: _flagged.contains(_current)
                                  ? 'Desmarcar'
                                  : 'Marcar para revisar',
                              onPressed: _toggleFlag,
                              icon: Icon(
                                _flagged.contains(_current)
                                    ? Icons.flag_rounded
                                    : Icons.outlined_flag_rounded,
                                color: _flagged.contains(_current)
                                    ? const Color(0xFFFFB74F)
                                    : null,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Ver panel de preguntas',
                              onPressed: _showQuestionGrid,
                              icon: const Icon(Icons.grid_view_rounded),
                            ),
                          ],
                        ],
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
                      // En estricto no hay "Anterior": el usuario no puede
                      // volver a preguntas ya respondidas. Mantenemos el
                      // boton oculto para no romper el layout: usamos
                      // Spacer().
                      if (!_strict)
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
                      else if (_strict)
                        // Ultima pregunta en modo estricto: el boton entrega
                        // directamente sin pedir confirmacion (la confirmacion
                        // fue al iniciar). Solo permitir si hay respuesta
                        // seleccionada en la ultima pregunta para evitar
                        // entregas accidentales.
                        FilledButton.icon(
                          onPressed: picked != null ? () => _submit() : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5C5C),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.flag_rounded),
                          label: const Text('Entregar examen'),
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
        ? const Color(0xFF7C5CFF)
        : Colors.white.withValues(alpha: 0.08);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
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
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    letter.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: selected ? const Color(0xFF7C5CFF) : Colors.white,
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

/// Seccion "Examen 2026" en el intro del simulacro (issue #77).
///
/// Card promocional que abre el modo "Videos de percepcion de riesgo", la
/// novedad oficial DGT 2026. Aditivo: si el usuario no toca el boton, el
/// flow del simulacro clasico es identico al anterior.
class _Examen2026Section extends StatelessWidget {
  final VoidCallback onOpenVideos;
  const _Examen2026Section({required this.onOpenVideos});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB74F).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'NOVEDAD 2026',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFFB74F),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Examen 2026',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpenVideos,
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C5CFF), Color(0xFFE04FFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.movie_filter_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Videos de percepcion de riesgo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Practica el nuevo formato del examen DGT 2026',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
        color: Colors.white.withValues(alpha: 0.05),
        child: const Icon(Icons.image_not_supported_outlined),
      ),
    );
  }
}
