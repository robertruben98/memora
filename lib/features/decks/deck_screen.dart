import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/memora_card.dart';
import '../../core/theme/deck_visuals.dart';
import '../../data/repositories/card_repository.dart';
import '../../data/repositories/deck_repository.dart';
import '../cards/card_editor_screen.dart';
import '../review/feed_screen.dart';
import 'deck_editor_screen.dart';

class DeckScreen extends ConsumerWidget {
  final DeckSummary deck;

  const DeckScreen({super.key, required this.deck});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(cardsByDeckProvider(deck.id));

    Future<void> openEditor() async {
      final deckRow =
          await ref.read(deckByIdProvider(deck.id).future);
      if (deckRow == null || !context.mounted) return;
      final result = await Navigator.of(context).push<dynamic>(
        MaterialPageRoute(
          builder: (_) => DeckEditorScreen(deckToEdit: deckRow),
        ),
      );
      if (result == 'deleted' && context.mounted) {
        Navigator.of(context).pop();
      }
    }

    return Scaffold(
      body: cardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (cards) => _DeckBody(
          deck: deck,
          cards: cards,
          onEditDeck: openEditor,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CardEditorScreen(deckId: deck.id),
            ),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva tarjeta'),
      ),
    );
  }
}

class _DeckBody extends StatelessWidget {
  final DeckSummary deck;
  final List<MemoraCard> cards;
  final VoidCallback onEditDeck;

  const _DeckBody({
    required this.deck,
    required this.cards,
    required this.onEditDeck,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          expandedHeight: 200,
          pinned: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: onEditDeck,
              tooltip: 'Editar mazo',
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              deck.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    deck.color.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: Icon(
                  DeckVisuals.iconFor(deck.iconName),
                  size: 80,
                  color: deck.color.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                _StudyButton(
                  enabled: cards.isNotEmpty,
                  cardCount: cards.length,
                  color: deck.color,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FeedScreen(cards: cards),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tarjetas (${cards.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (cards.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            sliver: SliverList.separated(
              itemCount: cards.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final card = cards[i];
                return _CardListTile(
                  card: card,
                  deckId: deck.id,
                  color: deck.color,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _StudyButton extends StatelessWidget {
  final bool enabled;
  final int cardCount;
  final Color color;
  final VoidCallback onTap;

  const _StudyButton({
    required this.enabled,
    required this.cardCount,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: enabled
                ? color.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: enabled
                  ? color.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.play_arrow_rounded,
                  color: enabled ? color : Colors.white38, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      enabled ? 'Estudiar este mazo' : 'Sin tarjetas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: enabled ? color : Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      enabled
                          ? '$cardCount tarjetas'
                          : 'Añade tarjetas para estudiar',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardListTile extends ConsumerWidget {
  final MemoraCard card;
  final String deckId;
  final Color color;

  const _CardListTile({
    required this.card,
    required this.deckId,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: const Color(0xFF1A1A22),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  CardEditorScreen(deckId: deckId, cardToEdit: card),
            ),
          );
        },
        onLongPress: () => _showActions(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.front,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                card.back,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.55),
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A22),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Editar'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CardEditorScreen(
                        deckId: deckId,
                        cardToEdit: card,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFFF4F6B),
                ),
                title: const Text(
                  'Eliminar',
                  style: TextStyle(color: Color(0xFFFF4F6B)),
                ),
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  await ref
                      .read(cardRepositoryProvider)
                      .deleteCard(card.id);
                  ref.invalidate(allCardsProvider);
                  ref.invalidate(cardsByDeckProvider(deckId));
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Aún no tienes tarjetas en este mazo',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toca "+ Nueva tarjeta" para crear la primera',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
