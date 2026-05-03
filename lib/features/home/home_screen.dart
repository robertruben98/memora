import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/memora_card.dart';
import '../../core/theme/deck_visuals.dart';
import '../../data/repositories/deck_repository.dart';
import '../decks/deck_editor_screen.dart';
import '../decks/deck_screen.dart';
import '../review/feed_screen.dart';
import '../review/study_queue.dart';

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
          'Mazos',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              if (globalQueueAsync.maybeWhen(
                    data: (q) => q.totalAvailable > 0,
                    orElse: () => false,
                  ))
                _DueBanner(
                  pending: globalQueueAsync.maybeWhen(
                    data: (q) => q.totalAvailable,
                    orElse: () => 0,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FeedScreen(),
                    ),
                  ),
                ),
              if (globalQueueAsync.maybeWhen(
                    data: (q) => q.totalAvailable > 0,
                    orElse: () => false,
                  ))
                const SizedBox(height: 16),
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
              const Icon(
                Icons.bolt_rounded,
                color: Colors.white,
                size: 22,
              ),
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
