import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/memora_card.dart';
import '../../core/theme/deck_visuals.dart';
import '../../data/api/api_client.dart';
import '../../data/repositories/card_repository.dart';
import '../../data/repositories/deck_repository.dart';
import '../cards/card_editor_screen.dart';
import '../review/feed_screen.dart';
import '../review/review_invalidation.dart';
import '../review/study_queue.dart';
import 'deck_editor_screen.dart';

/// Borra [card] e invalida los providers de cards. Muestra un `SnackBar`
/// de 5s con accion "Deshacer" que re-crea la tarjeta con el snapshot
/// original (mismo id, deckId, textos e imagenes).
///
/// Usado tanto por el swipe-to-delete del listado como por la opcion
/// "Eliminar" del bottom sheet de long-press.
Future<void> deleteCardWithUndo({
  required BuildContext context,
  required WidgetRef ref,
  required MemoraCard card,
  required String deckId,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(cardRepositoryProvider);
  final snapshot = card;
  try {
    await repo.deleteCard(snapshot.id);
  } catch (_) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('No se pudo eliminar'),
        backgroundColor: Color(0xFFFF4F6B),
      ),
    );
    return;
  }
  ref.invalidate(allCardsProvider);
  ref.invalidate(cardsByDeckProvider(deckId));
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: const Text('Tarjeta eliminada'),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'Deshacer',
        textColor: const Color(0xFF7C5CFF),
        onPressed: () async {
          try {
            await repo.createCard(
              id: snapshot.id,
              deckId: snapshot.deckId,
              frontText: snapshot.front,
              backText: snapshot.back,
              frontImagePath: snapshot.frontImagePath,
              backImagePath: snapshot.backImagePath,
            );
            ref.invalidate(allCardsProvider);
            ref.invalidate(cardsByDeckProvider(deckId));
          } catch (_) {
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(
              const SnackBar(
                content: Text('No se pudo restaurar'),
                backgroundColor: Color(0xFFFF4F6B),
              ),
            );
          }
        },
      ),
    ),
  );
}

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

class _DeckBody extends StatefulWidget {
  final DeckSummary deck;
  final List<MemoraCard> cards;
  final VoidCallback onEditDeck;

  const _DeckBody({
    required this.deck,
    required this.cards,
    required this.onEditDeck,
  });

  @override
  State<_DeckBody> createState() => _DeckBodyState();
}

class _DeckBodyState extends State<_DeckBody> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MemoraCard> get _filteredCards {
    if (_query.isEmpty) return widget.cards;
    final q = _query.toLowerCase();
    return widget.cards
        .where((c) =>
            c.front.toLowerCase().contains(q) ||
            c.back.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final deck = widget.deck;
    final cards = widget.cards;
    final filtered = _filteredCards;
    final hasQuery = _query.isNotEmpty;
    final countLabel = hasQuery
        ? 'Tarjetas (${filtered.length}/${cards.length})'
        : 'Tarjetas (${cards.length})';

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          expandedHeight: 200,
          pinned: true,
          actions: [
            _ExportAnkiButton(deckId: deck.id, deckName: deck.name),
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: widget.onEditDeck,
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
                  deckId: deck.id,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FeedScreen(deckId: deck.id),
                      ),
                    );
                  },
                ),
                if (cards.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Buscar tarjeta...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: hasQuery
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              tooltip: 'Limpiar busqueda',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    countLabel,
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
        else if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "Sin coincidencias para '$_query'",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              96 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            sliver: SliverList.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final card = filtered[i];
                return Consumer(
                  key: ValueKey('dismiss-${card.id}'),
                  builder: (context, ref, _) {
                    return Dismissible(
                      key: ValueKey(card.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4F6B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                      onDismissed: (_) {
                        deleteCardWithUndo(
                          context: context,
                          ref: ref,
                          card: card,
                          deckId: deck.id,
                        );
                      },
                      child: _CardListTile(
                        card: card,
                        deckId: deck.id,
                        color: deck.color,
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

class _StudyButton extends ConsumerWidget {
  final bool enabled;
  final int cardCount;
  final Color color;
  final String deckId;
  final VoidCallback onTap;

  const _StudyButton({
    required this.enabled,
    required this.cardCount,
    required this.color,
    required this.deckId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(studyQueueProvider(deckId));
    final pending = queueAsync.maybeWhen(
      data: (q) => q.totalAvailable,
      orElse: () => null,
    );
    final allCaughtUp = enabled && pending == 0;

    final title = !enabled
        ? 'Sin tarjetas'
        : allCaughtUp
            ? '¡Todo al día!'
            : 'Estudiar este mazo';
    final subtitle = !enabled
        ? 'Añade tarjetas para estudiar'
        : allCaughtUp
            ? 'Vuelve cuando se acerque la próxima revisión'
            : pending == null
                ? '$cardCount tarjetas'
                : '$pending pendientes · $cardCount totales';
    final icon = !enabled
        ? Icons.add_circle_outline_rounded
        : allCaughtUp
            ? Icons.check_circle_outline_rounded
            : Icons.play_arrow_rounded;
    final accent = allCaughtUp ? const Color(0xFF4FFFB0) : color;

    final clickable = enabled && !allCaughtUp;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: clickable ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: enabled
                ? accent.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: enabled
                  ? accent.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon,
                  color: enabled ? accent : Colors.white38, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: enabled ? accent : Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Duplicar'),
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  final messenger = ScaffoldMessenger.of(context);
                  final repo = ref.read(cardRepositoryProvider);
                  try {
                    final newId =
                        'card-${DateTime.now().microsecondsSinceEpoch}';
                    await repo.createCard(
                      id: newId,
                      deckId: card.deckId,
                      frontText: card.front,
                      backText: card.back,
                      frontImagePath: card.frontImagePath,
                      backImagePath: card.backImagePath,
                    );
                    invalidateAfterCardChange(ref, deckId: deckId);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Tarjeta duplicada')),
                    );
                  } catch (_) {
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('No se pudo duplicar'),
                        backgroundColor: Color(0xFFFF4F6B),
                      ),
                    );
                  }
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
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  deleteCardWithUndo(
                    context: context,
                    ref: ref,
                    card: card,
                    deckId: deckId,
                  );
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

class _ExportAnkiButton extends ConsumerStatefulWidget {
  final String deckId;
  final String deckName;

  const _ExportAnkiButton({required this.deckId, required this.deckName});

  @override
  ConsumerState<_ExportAnkiButton> createState() => _ExportAnkiButtonState();
}

class _ExportAnkiButtonState extends ConsumerState<_ExportAnkiButton> {
  bool _busy = false;

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      final bytes = await api.downloadBytes(
        '/decks/${widget.deckId}/export.apkg',
      );
      final tmp = await getTemporaryDirectory();
      final safe = widget.deckName.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final file = File(p.join(tmp.path, '$safe.apkg'));
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/octet-stream')],
        subject: 'Mazo Anki: ${widget.deckName}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.ios_share_rounded),
      tooltip: 'Exportar a Anki (.apkg)',
      onPressed: _busy ? null : _export,
    );
  }
}
