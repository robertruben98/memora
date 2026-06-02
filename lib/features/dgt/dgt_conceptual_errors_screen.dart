import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/widgets/app_state_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/dgt_repository.dart';

/// Pantalla DGT "Errores conceptuales" (issue #195, dgt-ux).
///
/// Agrupa los fallos recurrentes del usuario por **concepto/topic** y permite
/// lanzar un quiz dirigido de preguntas similares (`concept-related`) sobre
/// ese mismo concepto. Inspirado en la realidad pedagogica DGT: los
/// estudiantes no fallan preguntas aisladas, fallan CONCEPTOS (prioridades,
/// adelantamiento, ADAS, senales raras, etc.).
///
/// Flujo:
///   1. `GET /dgt/quiz/recurrent-failures?min_fails=2&limit=50` (BE#149).
///   2. Agrupa client-side por `question.topic` (fallback "Sin topic").
///   3. Ordena topics por suma total de `fail_count` DESC.
///   4. Cada grupo expandible muestra sus preguntas + boton
///      "Practicar N similares" -> `GET /dgt/quiz/concept-related/{first_id}`
///      -> abre quiz inline (mismo patron que recurrent_failures_screen).
///
/// Funciona offline cacheando la ultima respuesta en SharedPreferences
/// (key `dgt_conceptual_errors_last_v1`).
class DgtConceptualErrorsScreen extends ConsumerStatefulWidget {
  const DgtConceptualErrorsScreen({super.key});

  @override
  ConsumerState<DgtConceptualErrorsScreen> createState() =>
      _DgtConceptualErrorsScreenState();
}

class _DgtConceptualErrorsScreenState
    extends ConsumerState<DgtConceptualErrorsScreen> {
  static const _cacheKey = 'dgt_conceptual_errors_last_v1';

  late Future<List<DgtRecurrentFailureItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<DgtRecurrentFailureItem>> _load() async {
    final repo = ref.read(dgtRepositoryProvider);
    final fresh = await repo.fetchRecurrentFailures(minFails: 2, limit: 50);
    if (fresh.isNotEmpty) {
      // Cache best-effort (offline next time).
      unawaited(_writeCache(fresh));
      return fresh;
    }
    // Fresh vacio: puede ser sin errores (ok) u offline. Si hay cache,
    // preferimos mostrarla para no ocultar fallos previos cuando no hay red.
    final cached = await _readCache();
    if (cached.isNotEmpty) return cached;
    return fresh;
  }

  Future<List<DgtRecurrentFailureItem>> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) =>
              DgtRecurrentFailureItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeCache(List<DgtRecurrentFailureItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(items.map((it) {
        return {
          'id': it.question.id,
          'statement': it.question.statement,
          'option_a': it.question.optionA,
          'option_b': it.question.optionB,
          'option_c': it.question.optionC,
          'correct': it.question.correct,
          'explanation': it.question.explanation,
          'topic': it.question.topic,
          'image_url': it.question.imageUrl,
          'fail_count': it.failCount,
        };
      }).toList());
      await prefs.setString(_cacheKey, encoded);
    } catch (_) {
      // Best effort.
    }
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _practiceSimilar(_ConceptGroup group) async {
    final firstId = group.items.first.question.id;
    final repo = ref.read(dgtRepositoryProvider);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppStateView.loading(),
    );
    final related =
        await repo.fetchConceptRelated(questionId: firstId, limit: 10);
    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss spinner
    if (related.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudieron cargar preguntas similares. Reintenta luego.',
          ),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ConceptQuiz(
          conceptName: group.topic,
          questions: related,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Errores conceptuales'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<List<DgtRecurrentFailureItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _LoadingSkeleton();
          }
          final items = snap.data ?? const <DgtRecurrentFailureItem>[];
          if (items.isEmpty) {
            return AppStateView.empty(
              icon: Icons.celebration_rounded,
              title: 'Sin errores recurrentes. Sigue asi.',
              onRetry: _reload,
              retryLabel: 'Recargar',
            );
          }
          final groups = _groupByConcept(items);
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _ConceptGroupCard(
                group: groups[i],
                onPractice: () => _practiceSimilar(groups[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Agrupacion de fallos recurrentes por concepto/topic.
class _ConceptGroup {
  final String topic;
  final List<DgtRecurrentFailureItem> items;

  const _ConceptGroup({required this.topic, required this.items});

  int get totalFails => items.fold(0, (sum, it) => sum + it.failCount);
}

/// Helper publico para tests: agrupa por topic y ordena por totalFails DESC.
List<_ConceptGroup> _groupByConcept(List<DgtRecurrentFailureItem> items) {
  final map = <String, List<DgtRecurrentFailureItem>>{};
  for (final it in items) {
    final topic = (it.question.topic ?? '').trim();
    final key = topic.isEmpty ? 'Sin topic' : topic;
    map.putIfAbsent(key, () => []).add(it);
  }
  final groups = map.entries
      .map((e) => _ConceptGroup(topic: e.key, items: e.value))
      .toList();
  groups.sort((a, b) => b.totalFails.compareTo(a.totalFails));
  return groups;
}

class _ConceptGroupCard extends StatefulWidget {
  final _ConceptGroup group;
  final VoidCallback onPractice;

  const _ConceptGroupCard({required this.group, required this.onPractice});

  @override
  State<_ConceptGroupCard> createState() => _ConceptGroupCardState();
}

class _ConceptGroupCardState extends State<_ConceptGroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    return Container(
      decoration: BoxDecoration(
        color: context.c.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.c.border),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.psychology_alt_rounded,
              color: AppColors.brand,
            ),
            title: Text(
              group.topic,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${group.items.length} pregunta${group.items.length == 1 ? '' : 's'} '
              'fallada${group.items.length == 1 ? '' : 's'} '
              '${group.totalFails} ${group.totalFails == 1 ? 'vez' : 'veces'}',
              style: TextStyle(
                fontSize: 12,
                color: context.c.textSecondary,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5C5C).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFF5C5C)),
              ),
              child: Text(
                '${group.totalFails}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFF5C5C),
                ),
              ),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            for (final it in group.items)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFFFF5C5C).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${it.failCount}x',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFF5C5C),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        it.question.statement,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.onPractice,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    'Practicar ${group.items.length == 1 ? '' : ''}similares',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                  ),
                ),
              ),
            ),
          ],
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => Container(
        height: 72,
        decoration: BoxDecoration(
          color: context.c.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Quiz inline para preguntas del mismo concepto. Patron minimo: un intento
/// por pregunta + feedback + next + summary. Mismo estilo que el quiz de
/// recurrent_failures, pero independiente para no acoplar pantallas.
class _ConceptQuiz extends StatefulWidget {
  final String conceptName;
  final List<DgtQuestion> questions;

  const _ConceptQuiz({required this.conceptName, required this.questions});

  @override
  State<_ConceptQuiz> createState() => _ConceptQuizState();
}

class _ConceptQuizState extends State<_ConceptQuiz> {
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
    if (_current + 1 >= widget.questions.length) {
      setState(() => _finished = true);
    } else {
      setState(() => _current++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.questions;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.conceptName),
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
                    q: items[_current],
                    index: _current,
                    total: items.length,
                    picked: _picked[_current],
                    onSelect: (l) => _select(l, items[_current]),
                    onNext: _next,
                  ),
      ),
    );
  }
}

class _QuizQuestion extends StatelessWidget {
  final DgtQuestion q;
  final int index;
  final int total;
  final String? picked;
  final ValueChanged<String> onSelect;
  final VoidCallback onNext;

  const _QuizQuestion({
    required this.q,
    required this.index,
    required this.total,
    required this.picked,
    required this.onSelect,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
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
                const AlwaysStoppedAnimation(AppColors.brand),
          ),
          const SizedBox(height: 8),
          Text(
            'Pregunta ${index + 1} de $total',
            style: TextStyle(
              fontSize: 12,
              color: context.c.textSecondary,
            ),
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
                        color: context.c.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Respuesta correcta: ${q.correct.toUpperCase()}'
                        '${q.explanation == null || q.explanation!.isEmpty ? '' : '\n${q.explanation}'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.c.textPrimary,
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
    Color border = context.c.border;
    Color bg = context.c.surfaceElevated;
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
              'Practicaste $total pregunta${total == 1 ? '' : 's'}',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Acertaste $correct - Fallaste $wrong',
              style: TextStyle(
                fontSize: 14,
                color: context.c.textSecondary,
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

/// Funcion publica para tests: agrupa por concepto y devuelve records con
/// topic/totalFails/count. Solo para verificacion en tests.
List<({String topic, int totalFails, int count})> groupByConceptForTest(
  List<DgtRecurrentFailureItem> items,
) {
  final groups = _groupByConcept(items);
  return groups
      .map((g) =>
          (topic: g.topic, totalFails: g.totalFails, count: g.items.length))
      .toList();
}
