import 'package:flutter/material.dart';
import 'package:memora/core/widgets/app_state_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';

import '../../data/api/api_client.dart';
import '../../data/repositories/dgt_repository.dart';
import 'dgt_favorites_provider.dart';

/// Pantalla de preguntas favoritas DGT (issue #88).
///
/// Lista las preguntas marcadas como favoritas y ofrece un boton para lanzar
/// una sesion de quiz dedicada con SOLO esas preguntas (shuffle, sin timer).
/// Si el usuario tiene menos del minimo requerido se muestra un empty state
/// con instrucciones.
///
/// Aditivo: no toca el simulacro oficial, no envia nada al backend, persiste
/// solo IDs locales via [dgtFavoritesProvider].
///
/// Issue #188: incluye fila de ChoiceChip arriba del listado para filtrar
/// favoritas por topic. Chip "Todos" default. Topics se computan en memoria
/// desde la lista de favoritas (ordenados alfa). Estado se preserva al
/// pull-to-refresh y se resetea al salir de la pantalla.
class DgtFavoritesScreen extends ConsumerStatefulWidget {
  /// Minimo requerido por el issue para habilitar el quiz dedicado.
  static const int minForQuiz = 5;

  /// Sentinel para la chip "Todos" (sin filtro).
  static const String allTopicsSentinel = '__all__';

  const DgtFavoritesScreen({super.key});

  @override
  ConsumerState<DgtFavoritesScreen> createState() =>
      _DgtFavoritesScreenState();
}

class _DgtFavoritesScreenState extends ConsumerState<DgtFavoritesScreen> {
  /// Topic seleccionado actualmente. `allTopicsSentinel` = sin filtro.
  String _selectedTopic = DgtFavoritesScreen.allTopicsSentinel;

  /// Future cacheado para evitar refetch en cada rebuild por cambio de chip.
  Future<List<DgtQuestion>>? _favoritesFuture;
  Set<String> _lastIds = const <String>{};

  @override
  Widget build(BuildContext context) {
    final favs = ref.watch(dgtFavoritesProvider);
    // Si cambian los IDs (toggle), re-fetch. Cambiar chip NO refetch.
    if (_favoritesFuture == null || _lastIds != favs.ids) {
      _lastIds = favs.ids;
      _favoritesFuture = _loadFavoriteQuestions(ref, favs.ids);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Preguntas favoritas')),
      body: FutureBuilder<List<DgtQuestion>>(
        future: _favoritesFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return AppStateView.loading();
          }
          final all = snap.data ?? const <DgtQuestion>[];
          if (all.isEmpty) {
            return AppStateView.empty(
              icon: Icons.star_outline_rounded,
              title: 'Aun no has marcado preguntas',
              message:
                  'Marca preguntas con la estrella durante simulacros y '
                  'practica para repasarlas aqui antes del examen.',
            );
          }
          final topics = _computeTopics(all);
          final filtered = _applyTopicFilter(all);
          return Column(
            children: [
              if (all.length < DgtFavoritesScreen.minForQuiz)
                _MinHintBanner(
                  current: all.length,
                  min: DgtFavoritesScreen.minForQuiz,
                )
              else
                _StartQuizCta(questions: filtered),
              if (topics.isNotEmpty)
                _TopicChipsRow(
                  topics: topics,
                  selected: _selectedTopic,
                  onSelected: (t) => setState(() => _selectedTopic = t),
                ),
              _ResultsCounter(count: filtered.length),
              Expanded(
                child: filtered.isEmpty
                    ? AppStateView.empty(
                        icon: Icons.filter_alt_off_rounded,
                        title: 'No tienes favoritas en este tema',
                      )
                    : ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(12, 4, 12, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) =>
                            _FavoriteTile(question: filtered[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Topics distintos presentes en favoritas (excluye null/empty), ordenados
  /// alfabeticamente. La chip "Todos" se agrega aparte en la UI.
  static List<String> _computeTopics(List<DgtQuestion> qs) {
    final set = <String>{};
    for (final q in qs) {
      final t = q.topic;
      if (t != null && t.trim().isNotEmpty) set.add(t.trim());
    }
    final list = set.toList()..sort();
    return list;
  }

  List<DgtQuestion> _applyTopicFilter(List<DgtQuestion> all) {
    if (_selectedTopic == DgtFavoritesScreen.allTopicsSentinel) return all;
    return all.where((q) => (q.topic ?? '').trim() == _selectedTopic).toList();
  }

  /// Filtra el banco DGT por los IDs guardados como favoritos. Hace 1 fetch
  /// con limit alto y filtra in-memory; suficiente para listados modestos
  /// (<30 preguntas en favoritos en la practica).
  static Future<List<DgtQuestion>> _loadFavoriteQuestions(
    WidgetRef ref,
    Set<String> ids,
  ) async {
    if (ids.isEmpty) return const [];
    final repo = ref.read(dgtRepositoryProvider);
    final all = await repo.fetchExamQuestions(limit: 200);
    return all.where((q) => ids.contains(q.id)).toList();
  }
}

/// Fila horizontal scrollable de ChoiceChips para filtrar por topic.
/// Issue #188.
class _TopicChipsRow extends StatelessWidget {
  /// Topics ordenados alfabeticamente (no incluye "Todos").
  final List<String> topics;

  /// Topic seleccionado actual (sentinel `__all__` o un topic concreto).
  final String selected;

  final ValueChanged<String> onSelected;

  const _TopicChipsRow({
    required this.topics,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final all = [DgtFavoritesScreen.allTopicsSentinel, ...topics];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: all.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final t = all[i];
          final isAll = t == DgtFavoritesScreen.allTopicsSentinel;
          final label = isAll ? 'Todos' : t;
          final isSel = t == selected;
          return Center(
            child: ChoiceChip(
              key: ValueKey('topic-chip-$t'),
              label: Text(label),
              selected: isSel,
              onSelected: (_) => onSelected(t),
              selectedColor: AppColors.brand,
              labelStyle: TextStyle(
                color: isSel ? Colors.white : null,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Contador "N preguntas" debajo de los chips.
class _ResultsCounter extends StatelessWidget {
  final int count;
  const _ResultsCounter({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '$count pregunta${count == 1 ? '' : 's'}',
          key: const ValueKey('favorites-counter'),
          style: TextStyle(
            color: context.c.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MinHintBanner extends StatelessWidget {
  final int current;
  final int min;
  const _MinHintBanner({required this.current, required this.min});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DgtStatusColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: DgtStatusColors.warning.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: DgtStatusColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Marca al menos $min favoritas para hacer quiz '
              '(tienes $current).',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartQuizCta extends StatelessWidget {
  final List<DgtQuestion> questions;
  const _StartQuizCta({required this.questions});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: AppColors.brand,
          ),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text('Hacer quiz con favoritas (${questions.length})'),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DgtFavoritesQuizScreen(questions: questions),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FavoriteTile extends ConsumerWidget {
  final DgtQuestion question;
  const _FavoriteTile({required this.question});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: context.c.surfaceMuted,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        title: Text(
          question.statement,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: question.topic == null
            ? null
            : Text(
                question.topic!,
                style: TextStyle(
                  color: context.c.textMuted,
                  fontSize: 12,
                ),
              ),
        trailing: IconButton(
          icon: const Icon(Icons.star_rounded, color: Color(0xFFFFC857)),
          tooltip: 'Quitar de favoritas',
          onPressed: () {
            ref.read(dgtFavoritesProvider.notifier).toggle(question.id);
          },
        ),
      ),
    );
  }
}

/// Quiz dedicado a las preguntas favoritas. Reutiliza el patron de UI de
/// [DgtTrickQuestionsScreen]: una a una con feedback inmediato, sin timer.
/// Al fallar, registra ID en falladas (si existe ese sistema). Score final
/// con aciertos/fallos.
class DgtFavoritesQuizScreen extends ConsumerStatefulWidget {
  final List<DgtQuestion> questions;
  const DgtFavoritesQuizScreen({super.key, required this.questions});

  @override
  ConsumerState<DgtFavoritesQuizScreen> createState() =>
      _DgtFavoritesQuizScreenState();
}

class _DgtFavoritesQuizScreenState
    extends ConsumerState<DgtFavoritesQuizScreen> {
  late List<DgtQuestion> _questions;
  final Map<int, String> _picked = {};
  int _current = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    // Shuffle defensivo: si el usuario relanza el quiz, no quiere mismo orden.
    _questions = [...widget.questions]..shuffle();
  }

  void _select(String letter) {
    if (_picked.containsKey(_current)) return;
    setState(() => _picked[_current] = letter);
  }

  void _next() {
    if (_current < _questions.length - 1) {
      setState(() => _current++);
    } else {
      setState(() => _finished = true);
    }
  }

  int _correctCount() {
    var c = 0;
    for (var i = 0; i < _questions.length; i++) {
      final p = _picked[i];
      if (p != null && p == _questions[i].correct) c++;
    }
    return c;
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz favoritas')),
        body: AppStateView.empty(icon: Icons.star_border_rounded, title: 'No hay preguntas favoritas'),
      );
    }
    if (_finished) return _buildSummary();
    return _buildQuestion();
  }

  Widget _buildQuestion() {
    final q = _questions[_current];
    final picked = _picked[_current];
    final answered = picked != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz favoritas'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                '${_current + 1}/${_questions.length}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_current + 1) / _questions.length,
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
                    q.statement,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  if (q.imageUrl != null && q.imageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _DgtImage(path: q.imageUrl!),
                    ),
                  ],
                  const SizedBox(height: 14),
                  for (final entry in {
                    'a': q.optionA,
                    'b': q.optionB,
                    'c': q.optionC,
                  }.entries)
                    _AnswerTile(
                      letter: entry.key,
                      text: entry.value,
                      selected: picked == entry.key,
                      isCorrect: q.correct == entry.key,
                      revealed: answered,
                      onTap: () => _select(entry.key),
                    ),
                  if (answered && (q.explanation ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.c.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        q.explanation!,
                        style: TextStyle(
                          color: context.c.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: answered ? _next : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: Text(
                    _current < _questions.length - 1
                        ? 'Siguiente'
                        : 'Terminar',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final correct = _correctCount();
    final total = _questions.length;
    final wrong = total - correct;
    final wentWell = correct / total >= 0.7;
    final color =
        wentWell ? DgtStatusColors.success : DgtStatusColors.warning;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz favoritas'),
        automaticallyImplyLeading: false,
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
                      'Resultado',
                      style: TextStyle(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$correct aciertos / $wrong fallos',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total $total preguntas favoritas',
                      style: TextStyle(
                        color: context.c.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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

class _AnswerTile extends StatelessWidget {
  final String letter;
  final String text;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;

  const _AnswerTile({
    required this.letter,
    required this.text,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    if (!revealed) {
      color = selected
          ? AppColors.brand
          : context.c.surfaceMuted;
    } else {
      if (isCorrect) {
        color = DgtStatusColors.success.withValues(alpha: 0.22);
      } else if (selected) {
        color = DgtStatusColors.error.withValues(alpha: 0.22);
      } else {
        color = context.c.surfaceMuted;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: revealed ? null : onTap,
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
                    color: context.c.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    letter.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 15, height: 1.35),
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
