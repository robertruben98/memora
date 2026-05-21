import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/dgt_repository.dart';

/// Pantalla DGT "Errores recurrentes" (issue #154, dgt-ux).
///
/// Consume `GET /dgt/quiz/recurrent-failures?min_fails=N&limit=M` via
/// [DgtRepository.fetchRecurrentFailures] (BE#149). El backend devuelve
/// preguntas DGT falladas `>= min_fails` veces en los ultimos 60 dias,
/// ordenadas por fallos DESC y fecha del ultimo fallo DESC.
///
/// La pantalla muestra:
/// - Slider `min_fails` (2-10, default 2) + selector `limit` (10/20/50).
/// - Lista de preguntas con badge `fail_count` (chip rojo).
/// - Tap en una pregunta inicia un quiz dirigido inline (similar a
///   `dgt_failures_review_screen`).
/// - Empty state, loading skeleton y error con retry.
///
/// Aditivo: NO toca otros endpoints, screens ni cache. Reusa el patron
/// inline de quiz (un solo intento por pregunta + explanation + next).
class DgtRecurrentFailuresScreen extends ConsumerStatefulWidget {
  /// Default `min_fails` inicial (clamp BE [2, 10]).
  final int initialMinFails;

  /// Default `limit` inicial (clamp BE [1, 50]).
  final int initialLimit;

  const DgtRecurrentFailuresScreen({
    super.key,
    this.initialMinFails = 2,
    this.initialLimit = 20,
  });

  @override
  ConsumerState<DgtRecurrentFailuresScreen> createState() =>
      _DgtRecurrentFailuresScreenState();
}

class _DgtRecurrentFailuresScreenState
    extends ConsumerState<DgtRecurrentFailuresScreen> {
  late int _minFails;
  late int _limit;
  late Future<List<DgtRecurrentFailureItem>> _future;

  @override
  void initState() {
    super.initState();
    _minFails = widget.initialMinFails.clamp(2, 10);
    _limit = widget.initialLimit.clamp(1, 50);
    _future = _load();
  }

  Future<List<DgtRecurrentFailureItem>> _load() {
    final repo = ref.read(dgtRepositoryProvider);
    return repo.fetchRecurrentFailures(minFails: _minFails, limit: _limit);
  }

  void _reload() {
    setState(() => _future = _load());
  }

  void _openQuiz(List<DgtRecurrentFailureItem> items) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _RecurrentFailuresQuiz(items: items),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Errores recurrentes'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _FiltersBar(
            minFails: _minFails,
            limit: _limit,
            onMinFailsChanged: (v) {
              setState(() => _minFails = v);
            },
            onMinFailsCommitted: (_) => _reload(),
            onLimitChanged: (v) {
              setState(() => _limit = v);
              _reload();
            },
          ),
          Expanded(
            child: FutureBuilder<List<DgtRecurrentFailureItem>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const _LoadingSkeleton();
                }
                if (snap.hasError) {
                  return _ErrorState(onRetry: _reload);
                }
                final items = snap.data ?? const <DgtRecurrentFailureItem>[];
                if (items.isEmpty) {
                  return const _EmptyState();
                }
                return _List(items: items, onStartQuiz: _openQuiz);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  final int minFails;
  final int limit;
  final ValueChanged<int> onMinFailsChanged;
  final ValueChanged<int> onMinFailsCommitted;
  final ValueChanged<int> onLimitChanged;

  const _FiltersBar({
    required this.minFails,
    required this.limit,
    required this.onMinFailsChanged,
    required this.onMinFailsCommitted,
    required this.onLimitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.repeat_rounded,
                  color: Color(0xFFFF5C5C), size: 18),
              const SizedBox(width: 8),
              Text(
                'Min fallos: $minFails',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          Slider(
            value: minFails.toDouble(),
            min: 2,
            max: 10,
            divisions: 8,
            label: '$minFails',
            activeColor: const Color(0xFFFF5C5C),
            onChanged: (v) => onMinFailsChanged(v.round()),
            onChangeEnd: (v) => onMinFailsCommitted(v.round()),
          ),
          Row(
            children: [
              const Text('Limit:',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              for (final v in const [10, 20, 50]) ...[
                ChoiceChip(
                  label: Text('$v'),
                  selected: limit == v,
                  onSelected: (sel) {
                    if (sel) onLimitChanged(v);
                  },
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _List extends StatelessWidget {
  final List<DgtRecurrentFailureItem> items;
  final void Function(List<DgtRecurrentFailureItem>) onStartQuiz;

  const _List({required this.items, required this.onStartQuiz});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => onStartQuiz(items),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                'Repasar ${items.length} errata${items.length == 1 ? '' : 's'}',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF5C5C),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final it = items[i];
              return _FailureTile(item: it);
            },
          ),
        ),
      ],
    );
  }
}

class _FailureTile extends StatelessWidget {
  final DgtRecurrentFailureItem item;
  const _FailureTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DgtFailCountBadge(count: item.failCount),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.question.statement,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge "Nx" indicando cuantas veces fue fallada una pregunta. Public para
/// tests directos (issue #154).
class DgtFailCountBadge extends StatelessWidget {
  final int count;
  const DgtFailCountBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5C5C).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFF5C5C)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.repeat_rounded,
              color: Color(0xFFFF5C5C), size: 12),
          const SizedBox(width: 4),
          Text(
            '${count}x',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFFFF5C5C),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) => Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: Color(0xFFFFB74F), size: 48),
            const SizedBox(height: 12),
            const Text(
              'Error cargando tus erratas. Reintenta en unos segundos.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration_rounded,
                color: Color(0xFF4FFFB0), size: 64),
            const SizedBox(height: 16),
            const Text(
              'Aun no tienes erratas recurrentes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Sigue practicando!',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.65),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Quiz inline dirigido a las preguntas recurrentemente falladas. Patron
/// minimo: un intento por pregunta, feedback + correct letter, next, resumen.
class _RecurrentFailuresQuiz extends StatefulWidget {
  final List<DgtRecurrentFailureItem> items;
  const _RecurrentFailuresQuiz({required this.items});

  @override
  State<_RecurrentFailuresQuiz> createState() => _RecurrentFailuresQuizState();
}

class _RecurrentFailuresQuizState extends State<_RecurrentFailuresQuiz> {
  final Map<int, String> _picked = {};
  int _current = 0;
  bool _finished = false;
  int _correctCount = 0;

  void _select(String letter, DgtQuestion q) {
    if (_picked.containsKey(_current)) return;
    setState(() {
      _picked[_current] = letter;
      if (letter == q.correct) _correctCount++;
    });
  }

  void _next() {
    if (_current + 1 >= widget.items.length) {
      setState(() => _finished = true);
    } else {
      setState(() => _current++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Repaso erratas'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: items.isEmpty
            ? const Center(child: Text('Sin preguntas'))
            : _finished
                ? _QuizSummary(
                    total: items.length,
                    correct: _correctCount,
                    onClose: () => Navigator.of(context).pop(),
                  )
                : _QuizQuestion(
                    item: items[_current],
                    index: _current,
                    total: items.length,
                    picked: _picked[_current],
                    onSelect: (l) => _select(l, items[_current].question),
                    onNext: _next,
                  ),
      ),
    );
  }
}

class _QuizQuestion extends StatelessWidget {
  final DgtRecurrentFailureItem item;
  final int index;
  final int total;
  final String? picked;
  final ValueChanged<String> onSelect;
  final VoidCallback onNext;

  const _QuizQuestion({
    required this.item,
    required this.index,
    required this.total,
    required this.picked,
    required this.onSelect,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final q = item.question;
    final answered = picked != null;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: (index + 1) / total,
            minHeight: 6,
            valueColor:
                const AlwaysStoppedAnimation(Color(0xFFFF5C5C)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Pregunta ${index + 1} de $total',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              DgtFailCountBadge(count: item.failCount),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    q.statement,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Option(
                      letter: 'a',
                      text: q.optionA,
                      picked: picked,
                      correct: q.correct,
                      onTap: () => onSelect('a')),
                  _Option(
                      letter: 'b',
                      text: q.optionB,
                      picked: picked,
                      correct: q.correct,
                      onTap: () => onSelect('b')),
                  _Option(
                      letter: 'c',
                      text: q.optionC,
                      picked: picked,
                      correct: q.correct,
                      onTap: () => onSelect('c')),
                  if (answered) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Respuesta correcta: ${q.correct.toUpperCase()}'
                        '${q.explanation == null || q.explanation!.isEmpty ? '' : '\n${q.explanation}'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          FilledButton(
            onPressed: answered ? onNext : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(index + 1 >= total ? 'Terminar' : 'Siguiente'),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final String letter;
  final String text;
  final String? picked;
  final String correct;
  final VoidCallback onTap;

  const _Option({
    required this.letter,
    required this.text,
    required this.picked,
    required this.correct,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final answered = picked != null;
    final isThisPicked = picked == letter;
    final isCorrectOption = letter == correct;
    Color border = Colors.white.withValues(alpha: 0.15);
    Color bg = const Color(0xFF1A1A22);
    if (answered) {
      if (isCorrectOption) {
        border = const Color(0xFF4FFFB0);
        bg = const Color(0xFF4FFFB0).withValues(alpha: 0.08);
      } else if (isThisPicked) {
        border = const Color(0xFFFF5C5C);
        bg = const Color(0xFFFF5C5C).withValues(alpha: 0.08);
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: answered ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: border.withValues(alpha: 0.2),
                  ),
                  child: Text(
                    letter.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(text, style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizSummary extends StatelessWidget {
  final int total;
  final int correct;
  final VoidCallback onClose;

  const _QuizSummary({
    required this.total,
    required this.correct,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final wrong = total - correct;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.task_alt_rounded,
                size: 64, color: Color(0xFF4FFFB0)),
            const SizedBox(height: 16),
            Text(
              'Repasaste $total errata${total == 1 ? '' : 's'}',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Acertaste $correct - Fallaste $wrong',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onClose,
              style: FilledButton.styleFrom(
                minimumSize: const Size(180, 48),
              ),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }
}
