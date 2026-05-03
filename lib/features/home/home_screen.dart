import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/memora_card.dart';
import '../../core/theme/deck_visuals.dart';
import '../../data/repositories/deck_repository.dart';
import '../browse/browse_feed_screen.dart';
import '../decks/deck_editor_screen.dart';
import '../decks/deck_screen.dart';
import '../review/feed_screen.dart';
import '../review/study_queue.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decksAsync = ref.watch(deckSummariesProvider);
    final globalQueueAsync = ref.watch(studyQueueProvider(null));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Memora',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.dynamic_feed_rounded),
            tooltip: 'Feed',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BrowseFeedScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Estadísticas',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StatsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Ajustes',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
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
                MaterialPageRoute(
                  builder: (_) => const DeckEditorScreen(),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _StudyAllCard(
                pendingCount: globalQueueAsync.maybeWhen(
                  data: (q) => q.totalAvailable,
                  orElse: () => null,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FeedScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _BrowseFeedTile(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BrowseFeedScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Mis Mazos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...decks.map(
                (deck) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DeckTile(
                    deck: deck,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DeckScreen(deck: deck),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const DeckEditorScreen(),
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo mazo'),
      ),
    );
  }
}

class _StudyAllCard extends StatelessWidget {
  /// null = aún cargando; 0 = todo al día; >0 = hay tarjetas listas.
  final int? pendingCount;
  final VoidCallback onTap;

  const _StudyAllCard({required this.pendingCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final allCaughtUp = pendingCount == 0;
    final subtitle = pendingCount == null
        ? 'Calculando…'
        : allCaughtUp
            ? '¡Todo al día!'
            : '$pendingCount tarjetas pendientes';
    final icon = allCaughtUp
        ? Icons.check_circle_outline_rounded
        : Icons.public_rounded;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: allCaughtUp ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: allCaughtUp
                  ? [
                      const Color(0xFF1A1A22),
                      const Color(0xFF1A1A22),
                    ]
                  : const [Color(0xFF7C5CFF), Color(0xFF4F8AFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: allCaughtUp
                ? Border.all(
                    color: const Color(0xFF4FFFB0).withValues(alpha: 0.4),
                    width: 1.5,
                  )
                : null,
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: allCaughtUp
                      ? const Color(0xFF4FFFB0).withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color:
                      allCaughtUp ? const Color(0xFF4FFFB0) : Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estudiar todo',
                      style: TextStyle(
                        color: allCaughtUp ? Colors.white70 : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: allCaughtUp
                            ? const Color(0xFF4FFFB0)
                            : Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                        fontWeight:
                            allCaughtUp ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (!allCaughtUp)
                const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowseFeedTile extends StatelessWidget {
  final VoidCallback onTap;

  const _BrowseFeedTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A22),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE04FFF), Color(0xFF7C5CFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.dynamic_feed_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explorar feed',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Scroll relajado por todas tus tarjetas',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
