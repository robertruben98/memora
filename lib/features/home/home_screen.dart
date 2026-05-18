import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/memora_card.dart';
import '../../core/theme/deck_visuals.dart';
import '../../data/repositories/deck_repository.dart';
import '../ai_gen/ai_generate_screen.dart';
import '../decks/deck_editor_screen.dart';
import '../decks/deck_screen.dart';
import '../dgt/dgt_exam_screen.dart';
import '../dgt/dgt_preparation_provider.dart';
import '../dgt/dgt_quick_review_screen.dart';
import '../dgt/dgt_settings.dart';
import '../stats/stats_screen.dart';
import '../quest/quest_provider.dart';
import '../review/feed_screen.dart';
import '../review/study_queue.dart';
import 'deck_sort_preference.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decksAsync = ref.watch(deckSummariesProvider);
    final globalQueueAsync = ref.watch(studyQueueProvider(null));
    final questAsync = ref.watch(dailyQuestProvider);
    final sortOption = ref.watch(deckSortProvider);
    final dgtSettingsAsync = ref.watch(dgtSettingsProvider);
    final dgtPreparationAsync = ref.watch(dgtPreparationProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Mazos',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4),
        ),
        actions: [
          PopupMenuButton<DeckSortOption>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Ordenar mazos',
            initialValue: sortOption,
            onSelected: (o) => ref.read(deckSortProvider.notifier).setOption(o),
            itemBuilder: (context) => DeckSortOption.values
                .map(
                  (o) => PopupMenuItem<DeckSortOption>(
                    value: o,
                    child: Row(
                      children: [
                        Icon(
                          o == sortOption
                              ? Icons.check_rounded
                              : Icons.circle_outlined,
                          size: 18,
                          color: o == sortOption
                              ? const Color(0xFF7C5CFF)
                              : Colors.white.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 10),
                        Text(deckSortOptionLabel(o)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      body: decksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (decks) {
          if (decks.isEmpty) {
            return _HomeEmptyState(
              onCreateDeck: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DeckEditorScreen()),
              ),
            );
          }
          final sorted = sortDecks(decks, sortOption);
          final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 96 + bottomInset),
            children: [
              dgtSettingsAsync.maybeWhen(
                data: (s) => s.examDate != null
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DgtBanner(
                          settings: s,
                          preparation: dgtPreparationAsync.maybeWhen(
                            data: (p) => p,
                            orElse: () => null,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),
              questAsync.maybeWhen(
                data: (q) => _QuestBanner(quest: q),
                orElse: () => const SizedBox.shrink(),
              ),
              if (questAsync.maybeWhen(data: (_) => true, orElse: () => false))
                const SizedBox(height: 12),
              if (globalQueueAsync.maybeWhen(
                data: (q) => q.totalAvailable > 0,
                orElse: () => false,
              ))
                _DueBanner(
                  pending: globalQueueAsync.maybeWhen(
                    data: (q) => q.totalAvailable,
                    orElse: () => 0,
                  ),
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const FeedScreen())),
                ),
              if (globalQueueAsync.maybeWhen(
                data: (q) => q.totalAvailable > 0,
                orElse: () => false,
              ))
                const SizedBox(height: 16),
              _DgtExamBanner(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DgtExamScreen()),
                ),
              ),
              const SizedBox(height: 16),
              ...sorted.map(
                (deck) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DeckTile(
                    deck: deck,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => DeckScreen(deck: deck)),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _HomeFab(),
    );
  }
}

class _DeckTile extends StatelessWidget {
  final DeckSummary deck;
  final VoidCallback onTap;

  const _DeckTile({required this.deck, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A22),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: deck.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  DeckVisuals.iconFor(deck.iconName),
                  color: deck.color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${deck.dueCount} due · ${deck.totalCount} total',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  final VoidCallback onCreateDeck;

  const _HomeEmptyState({required this.onCreateDeck});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7C5CFF), Color(0xFF4F8AFF)],
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.style_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Aún no tienes mazos',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Crea tu primer mazo para empezar a estudiar.\n'
            'Puedes organizar tarjetas por idioma, tema o lo que '
            'quieras aprender.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: onCreateDeck,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crear primer mazo'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _DueBanner extends StatelessWidget {
  final int pending;
  final VoidCallback onTap;

  const _DueBanner({required this.pending, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C5CFF), Color(0xFF4F8AFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$pending tarjetas listas para repasar',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestBanner extends StatelessWidget {
  final DailyQuest quest;
  const _QuestBanner({required this.quest});

  @override
  Widget build(BuildContext context) {
    final complete = quest.isComplete;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: complete
              ? const Color(0xFF4FFFB0).withValues(alpha: 0.45)
              : const Color(0xFFFFD24F).withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                complete ? '🏆' : '🎯',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'QUEST DIARIA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: Color(0xFFFFD24F),
                ),
              ),
              const Spacer(),
              if (quest.streakDays > 0)
                Text(
                  '🔥 ${quest.streakDays}d',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF8A4F),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            complete
                ? 'Quest completada — ¡a por mañana!'
                : 'Estudia ${quest.target} tarjetas hoy '
                      '(${quest.completed}/${quest.target})',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 6,
              color: Colors.black.withValues(alpha: 0.4),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: quest.progress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: complete
                          ? const [Color(0xFF4FFFB0), Color(0xFF4FFFE9)]
                          : const [Color(0xFFFFD24F), Color(0xFFFF8A4F)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner Home con mini-dashboard de preparacion DGT (issue #54).
/// - Header: dias hasta examen con color (verde >30, ambar 7-30, rojo <7).
/// - Body: progreso meta diaria (X/dailyGoal) + barra.
/// - Footer: prediccion APROBADO/SUSPENSO segun expectedScore vs >=0.90.
/// Tap en el banner navega a StatsScreen (vista DGT con detalle por tema).
/// Si `preparation` es null (loading o error inicial), degrada a la version
/// minima previa (solo header) para no romper el Home.
class _DgtBanner extends StatelessWidget {
  final DgtSettings settings;
  final DgtPreparation? preparation;
  const _DgtBanner({required this.settings, this.preparation});

  @override
  Widget build(BuildContext context) {
    final days = settings.daysUntilExam;
    final goal = settings.dailyGoal;
    final license = settings.licenseType.code;
    final accent = dgtBannerAccentColor(days);
    final String header;
    if (days == null) {
      header = 'Permiso $license - meta hoy: $goal preguntas';
    } else if (days < 0) {
      header = 'Examen pasado - sigue practicando ($goal/dia)';
    } else if (days == 0) {
      header = 'Hoy es tu examen! Suerte (Permiso $license)';
    } else {
      header = 'Examen en $days dia${days == 1 ? '' : 's'} (Permiso $license)';
    }

    final answered = preparation?.answeredToday ?? 0;
    final progress = preparation?.dailyProgress ?? 0.0;
    final verdictLabel = preparation?.verdictLabel ?? 'Prediccion: cargando...';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const StatsScreen())),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.55)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.directions_car_filled_rounded,
                    color: accent,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      header,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$answered/$goal',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                verdictLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 10),
              // CTA secundario: Repaso rapido (10 preguntas, 3 min). Pensado
              // para micro-sesiones. No persiste en historial. Issue #53.
              OutlinedButton.icon(
                // 44px tap-target accesible (Material guidelines).
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: accent,
                  side: BorderSide(color: accent.withValues(alpha: 0.45)),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DgtQuickReviewScreen(),
                  ),
                ),
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: const Text(
                  'Repaso rapido (3 min)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DgtExamBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _DgtExamBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8A4F), Color(0xFFE04FFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.directions_car_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Simulacro DGT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '30 preguntas · 30 min · permiso B',
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
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton(
          heroTag: 'fab-ai',
          backgroundColor: const Color(0xFFE04FFF),
          mini: true,
          tooltip: 'Generar con IA',
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AiGenerateScreen())),
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
        ),
        const SizedBox(height: 10),
        FloatingActionButton.extended(
          heroTag: 'fab-deck',
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const DeckEditorScreen())),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nuevo mazo'),
        ),
      ],
    );
  }
}
