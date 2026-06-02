import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';
import 'package:memora/core/widgets/app_state_view.dart';

import '../../data/repositories/dgt_repository.dart';

/// Issue #201 (dgt-ux): pantalla "V/F rapido" - entrenar reflejo logico DGT.
///
/// El temario DGT esta lleno de afirmaciones tipo "siempre / nunca / esta
/// permitido / esta prohibido" donde la diferencia entre acierto y error es
/// una sola palabra. Practicar solo con preguntas multi-opcion no entrena
/// bien ese reflejo - el estudiante necesita poder leer una afirmacion
/// suelta y decidir rapido SI/NO.
///
/// Se derivan afirmaciones del banco DGT existente (cache local v[a]
/// `fetchExamQuestions`):
/// - statement + opcion_correcta -> afirmacion VERDADERA
/// - statement + opcion_incorrecta -> afirmacion FALSA
///
/// 10 afirmaciones por ronda, distribucion ~50/50 V/F. No timer (reflexion,
/// no contrarreloj). Aditivo: NO toca otros endpoints ni screens.

/// Una afirmacion binaria V/F derivada de una pregunta multi-opcion DGT.
@immutable
class DgtTrueFalseStatement {
  /// Texto completo de la afirmacion (enunciado + opcion).
  final String text;

  /// True si la afirmacion es correcta (statement + opcion_correcta).
  final bool isTrue;

  /// Enunciado original (para feedback).
  final String questionStatement;

  /// Letra de la opcion usada ('a' | 'b' | 'c').
  final String optionLetter;

  /// Texto de la opcion correcta (para feedback explicativo).
  final String correctOptionText;

  const DgtTrueFalseStatement({
    required this.text,
    required this.isTrue,
    required this.questionStatement,
    required this.optionLetter,
    required this.correctOptionText,
  });
}

/// Generador puro de sets V/F a partir de un pool de preguntas DGT.
///
/// Public para tests: ver `dgt_true_false_screen_test.dart`.
class DgtTrueFalseSetGenerator {
  /// Genera [count] afirmaciones intentando distribucion ~50/50 V/F.
  ///
  /// Estrategia:
  /// 1. Por cada pregunta crea hasta 1 afirmacion verdadera (opcion correcta)
  ///    y hasta 2 falsas (las dos opciones incorrectas).
  /// 2. Baraja con [random] (semilla inyectable).
  /// 3. Toma alternando V/F hasta llegar a [count]. Si no hay suficientes
  ///    de un lado, rellena con el otro (mejor sesgo que set incompleto).
  static List<DgtTrueFalseStatement> generate({
    required List<DgtQuestion> pool,
    int count = 10,
    Random? random,
  }) {
    if (pool.isEmpty || count <= 0) return const [];
    final rnd = random ?? Random();

    final trues = <DgtTrueFalseStatement>[];
    final falses = <DgtTrueFalseStatement>[];
    for (final q in pool) {
      final correctText = _optionTextFor(q, q.correct);
      // Afirmacion verdadera (statement + opcion correcta).
      trues.add(DgtTrueFalseStatement(
        text: _composeAffirmation(q.statement, correctText),
        isTrue: true,
        questionStatement: q.statement,
        optionLetter: q.correct,
        correctOptionText: correctText,
      ));
      // Afirmaciones falsas (statement + opciones incorrectas).
      for (final letter in const ['a', 'b', 'c']) {
        if (letter == q.correct) continue;
        final txt = _optionTextFor(q, letter);
        if (txt.trim().isEmpty) continue;
        falses.add(DgtTrueFalseStatement(
          text: _composeAffirmation(q.statement, txt),
          isTrue: false,
          questionStatement: q.statement,
          optionLetter: letter,
          correctOptionText: correctText,
        ));
      }
    }

    trues.shuffle(rnd);
    falses.shuffle(rnd);

    final out = <DgtTrueFalseStatement>[];
    var ti = 0;
    var fi = 0;
    // Alternancia simple T,F,T,F... para reforzar distribucion 50/50.
    var pickTrue = true;
    while (out.length < count) {
      if (pickTrue && ti < trues.length) {
        out.add(trues[ti++]);
      } else if (!pickTrue && fi < falses.length) {
        out.add(falses[fi++]);
      } else if (ti < trues.length) {
        out.add(trues[ti++]);
      } else if (fi < falses.length) {
        out.add(falses[fi++]);
      } else {
        break; // sin material suficiente.
      }
      pickTrue = !pickTrue;
    }
    return out;
  }

  static String _optionTextFor(DgtQuestion q, String letter) {
    switch (letter) {
      case 'a':
        return q.optionA;
      case 'b':
        return q.optionB;
      case 'c':
        return q.optionC;
    }
    return '';
  }

  /// Combina enunciado + opcion en una afirmacion plana. Si el enunciado
  /// termina en '?' lo eliminamos y prefijamos con la opcion.
  static String _composeAffirmation(String statement, String option) {
    final s = statement.trim();
    final o = option.trim();
    if (s.isEmpty) return o;
    if (o.isEmpty) return s;
    final cleaned = s.endsWith('?') ? s.substring(0, s.length - 1).trim() : s;
    return '$cleaned: $o';
  }
}

/// Estado del notifier V/F. Public para tests.
@immutable
class DgtTrueFalseState {
  final List<DgtTrueFalseStatement> statements;
  final Map<int, bool> answers; // index -> respuesta del usuario.
  final int current;
  final bool finished;
  final bool loading;
  final String? error;

  const DgtTrueFalseState({
    this.statements = const [],
    this.answers = const {},
    this.current = 0,
    this.finished = false,
    this.loading = true,
    this.error,
  });

  bool get answeredCurrent => answers.containsKey(current);
  int get total => statements.length;
  int get correctCount {
    var c = 0;
    for (final e in answers.entries) {
      if (e.key < statements.length && statements[e.key].isTrue == e.value) {
        c++;
      }
    }
    return c;
  }

  DgtTrueFalseState copyWith({
    List<DgtTrueFalseStatement>? statements,
    Map<int, bool>? answers,
    int? current,
    bool? finished,
    bool? loading,
    Object? error = _sentinel,
  }) {
    return DgtTrueFalseState(
      statements: statements ?? this.statements,
      answers: answers ?? this.answers,
      current: current ?? this.current,
      finished: finished ?? this.finished,
      loading: loading ?? this.loading,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }

  static const _sentinel = Object();
}

/// Notifier que orquesta la sesion V/F. Public para tests.
class DgtTrueFalseNotifier extends StateNotifier<DgtTrueFalseState> {
  final DgtRepository _repo;
  final int _count;
  final Random? _random;

  DgtTrueFalseNotifier(this._repo, {int count = 10, Random? random})
      : _count = count,
        _random = random,
        super(const DgtTrueFalseState());

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      // Pool grande para sortear suficientes T/F. fetchRandomWarmup hace
      // fallback a banco local si offline, sin tocar cache de simulacro.
      final pool = await _repo.fetchRandomWarmup(limit: 60);
      final set = DgtTrueFalseSetGenerator.generate(
        pool: pool,
        count: _count,
        random: _random,
      );
      state = state.copyWith(
        statements: set,
        loading: false,
        answers: const {},
        current: 0,
        finished: false,
        error: set.isEmpty ? 'Sin afirmaciones disponibles.' : null,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Error cargando set.');
    }
  }

  void answer(bool response) {
    if (state.finished || state.answeredCurrent) return;
    final updated = Map<int, bool>.from(state.answers)
      ..[state.current] = response;
    state = state.copyWith(answers: updated);
  }

  void next() {
    if (!state.answeredCurrent) return;
    if (state.current >= state.statements.length - 1) {
      state = state.copyWith(finished: true);
    } else {
      state = state.copyWith(current: state.current + 1);
    }
  }

  void restart() {
    state = const DgtTrueFalseState();
    load();
  }
}

/// Provider del notifier V/F. Autodispose para limpiar entre entradas.
final dgtTrueFalseNotifierProvider = StateNotifierProvider.autoDispose<
    DgtTrueFalseNotifier, DgtTrueFalseState>((ref) {
  final repo = ref.watch(dgtRepositoryProvider);
  final n = DgtTrueFalseNotifier(repo);
  n.load();
  return n;
});

class DgtTrueFalseScreen extends ConsumerWidget {
  const DgtTrueFalseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dgtTrueFalseNotifierProvider);
    final notifier = ref.read(dgtTrueFalseNotifierProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('V/F rapido'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _buildBody(context, state, notifier),
    );
  }

  Widget _buildBody(
    BuildContext context,
    DgtTrueFalseState state,
    DgtTrueFalseNotifier notifier,
  ) {
    if (state.loading) {
      return AppStateView.loading();
    }
    if (state.error != null && state.statements.isEmpty) {
      return AppStateView.empty(
        icon: Icons.psychology_alt_rounded,
        title: state.error!,
        onRetry: notifier.restart,
      );
    }
    if (state.statements.isEmpty) {
      return AppStateView.empty(
        icon: Icons.psychology_alt_rounded,
        title: 'Aun no hay afirmaciones disponibles.',
        onRetry: notifier.restart,
      );
    }
    if (state.finished) {
      return _Summary(state: state, onRestart: notifier.restart);
    }
    return _Question(state: state, notifier: notifier);
  }
}

class _Question extends StatelessWidget {
  final DgtTrueFalseState state;
  final DgtTrueFalseNotifier notifier;
  const _Question({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final stmt = state.statements[state.current];
    final picked = state.answers[state.current];
    final answered = picked != null;
    final isCorrect = answered && picked == stmt.isTrue;

    return Column(
      children: [
        LinearProgressIndicator(
          value: (state.current + 1) / state.total,
          minHeight: 4,
          backgroundColor: context.c.surfaceMuted,
          valueColor: const AlwaysStoppedAnimation(DgtStatusColors.success),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${state.current + 1} / ${state.total}',
                  style: TextStyle(
                    color: context.c.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Text(
                        stmt.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
                if (answered) ...[
                  const SizedBox(height: 12),
                  _FeedbackCard(stmt: stmt, isCorrect: isCorrect),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _AnswerButton(
                    label: 'Verdadero',
                    icon: Icons.check_circle_rounded,
                    color: DgtStatusColors.success,
                    selected: picked == true,
                    revealed: answered,
                    isMatch: stmt.isTrue == true,
                    onTap: answered ? null : () => notifier.answer(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AnswerButton(
                    label: 'Falso',
                    icon: Icons.cancel_rounded,
                    color: DgtStatusColors.error,
                    selected: picked == false,
                    revealed: answered,
                    isMatch: stmt.isTrue == false,
                    onTap: answered ? null : () => notifier.answer(false),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (answered)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: notifier.next,
                  icon: Icon(state.current == state.total - 1
                      ? Icons.flag_rounded
                      : Icons.chevron_right_rounded),
                  label: Text(state.current == state.total - 1
                      ? 'Ver resumen'
                      : 'Siguiente'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AnswerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool revealed;
  final bool isMatch;
  final VoidCallback? onTap;

  const _AnswerButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.revealed,
    required this.isMatch,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    var bg = color.withValues(alpha: 0.12);
    var border = color.withValues(alpha: 0.40);
    var fg = color;
    if (revealed) {
      if (isMatch) {
        bg = color.withValues(alpha: 0.25);
        border = color;
      } else if (selected) {
        bg = color.withValues(alpha: 0.15);
        border = color.withValues(alpha: 0.60);
      } else {
        bg = context.c.surfaceMuted;
        border = context.c.border;
        fg = context.c.textMuted;
      }
    }
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg, size: 26),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final DgtTrueFalseStatement stmt;
  final bool isCorrect;
  const _FeedbackCard({required this.stmt, required this.isCorrect});

  @override
  Widget build(BuildContext context) {
    final accent = DgtStatusColors.forPassed(isCorrect);
    final label = isCorrect ? 'Correcto' : 'Incorrecto';
    final explanation = isCorrect
        ? (stmt.isTrue
            ? 'La afirmacion es verdadera.'
            : 'La afirmacion es falsa.')
        : 'Lo correcto seria: "${stmt.correctOptionText}".';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.40)),
      ),
      child: Row(
        children: [
          Icon(
            isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  explanation,
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final DgtTrueFalseState state;
  final VoidCallback onRestart;
  const _Summary({required this.state, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    final correct = state.correctCount;
    final total = state.total;
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
                  : Icons.psychology_alt_rounded,
              size: 64,
              color: DgtStatusColors.success,
            ),
            const SizedBox(height: 12),
            const Text(
              'V/F rapido',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Resumen de la ronda',
              style: TextStyle(color: context.c.textSecondary),
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
                onPressed: onRestart,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Otra ronda'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Volver'),
              ),
            ),
          ],
        ),
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
