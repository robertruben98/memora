import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/memora_card.dart';
import '../database/daos/card_dao.dart';
import '../database/daos/deck_dao.dart';
import '../database/database.dart';
import '../sync/sync_service.dart';

class CardRepository {
  final CardDao _cardDao;
  final DeckDao _deckDao;
  final SyncService _sync;

  CardRepository(this._cardDao, this._deckDao, this._sync);

  MemoraCard _toMemoraCard(CardRow c, [DeckRow? deck]) {
    return MemoraCard(
      id: c.id,
      deckId: c.deckId,
      front: c.frontText,
      back: c.backText,
      frontImagePath: c.frontImagePath,
      backImagePath: c.backImagePath,
      deck: deck?.name ?? 'Sin mazo',
      deckIconName: deck?.iconName ?? 'style_rounded',
      deckColor: _parseColor(deck?.colorHex ?? '#7C5CFF'),
    );
  }

  Future<List<MemoraCard>> getAllCards() async {
    final cards = await _cardDao.getAllCards();
    final decks = await _deckDao.getAllDecks();
    final byId = {for (final d in decks) d.id: d};
    return cards.map((c) => _toMemoraCard(c, byId[c.deckId])).toList();
  }

  Future<List<MemoraCard>> getCardsByDeckId(String deckId) async {
    final cards = await _cardDao.getCardsByDeck(deckId);
    final deck = await _deckDao.getDeckById(deckId);
    if (deck == null) return [];
    return cards.map((c) => _toMemoraCard(c, deck)).toList();
  }

  Future<void> createCard({
    required String id,
    required String deckId,
    required String frontText,
    required String backText,
    String? frontImagePath,
    String? backImagePath,
  }) async {
    await _sync.upsertCard(
      id: id,
      deckId: deckId,
      frontText: frontText,
      backText: backText,
      frontImagePath: frontImagePath,
      backImagePath: backImagePath,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    await _cardDao.insertCard(
      CardsCompanion.insert(
        id: id,
        deckId: deckId,
        frontText: frontText,
        backText: backText,
        frontImagePath: Value(frontImagePath),
        backImagePath: Value(backImagePath),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> updateCard({
    required String id,
    required String frontText,
    required String backText,
    String? frontImagePath,
    String? backImagePath,
  }) async {
    final existing = await _cardDao.getCardById(id);
    if (existing == null) return;
    await _sync.upsertCard(
      id: id,
      deckId: existing.deckId,
      frontText: frontText,
      backText: backText,
      frontImagePath: frontImagePath,
      backImagePath: backImagePath,
    );
    await _cardDao.updateCard(
      CardsCompanion(
        id: Value(id),
        deckId: Value(existing.deckId),
        frontText: Value(frontText),
        backText: Value(backText),
        frontImagePath: Value(frontImagePath),
        backImagePath: Value(backImagePath),
        createdAt: Value(existing.createdAt),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> deleteCard(String id) async {
    await _sync.deleteCard(id);
    await _cardDao.deleteCard(id);
  }
}

Color _parseColor(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  final value = int.parse(cleaned, radix: 16);
  if (cleaned.length == 6) {
    return Color(0xFF000000 | value);
  }
  return Color(value);
}

final cardRepositoryProvider = Provider<CardRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CardRepository(db.cardDao, db.deckDao, ref.watch(syncServiceProvider));
});

final allCardsProvider = FutureProvider<List<MemoraCard>>((ref) async {
  return ref.read(cardRepositoryProvider).getAllCards();
});

final cardsByDeckProvider =
    FutureProvider.family<List<MemoraCard>, String>((ref, deckId) async {
  return ref.read(cardRepositoryProvider).getCardsByDeckId(deckId);
});
