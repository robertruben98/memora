import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/memora_card.dart';
import '../database/daos/card_dao.dart';
import '../database/daos/deck_dao.dart';
import '../database/database.dart';

class CardRepository {
  final CardDao _cardDao;
  final DeckDao _deckDao;

  CardRepository(this._cardDao, this._deckDao);

  Future<List<MemoraCard>> getAllCards() async {
    final cards = await _cardDao.getAllCards();
    final decks = await _deckDao.getAllDecks();
    final byId = {for (final d in decks) d.id: d};
    return cards.map((c) {
      final d = byId[c.deckId];
      return MemoraCard(
        id: c.id,
        deckId: c.deckId,
        front: c.frontText,
        back: c.backText,
        frontImagePath: c.frontImagePath,
        backImagePath: c.backImagePath,
        deck: d?.name ?? 'Sin mazo',
        deckIconName: d?.iconName ?? 'style_rounded',
        deckColor: _parseColor(d?.colorHex ?? '#7C5CFF'),
      );
    }).toList();
  }

  Future<List<MemoraCard>> getCardsByDeckId(String deckId) async {
    final cards = await _cardDao.getCardsByDeck(deckId);
    final deck = await _deckDao.getDeckById(deckId);
    if (deck == null) return [];
    return cards
        .map((c) => MemoraCard(
              id: c.id,
              deckId: c.deckId,
              front: c.frontText,
              back: c.backText,
              frontImagePath: c.frontImagePath,
              backImagePath: c.backImagePath,
              deck: deck.name,
              deckIconName: deck.iconName,
              deckColor: _parseColor(deck.colorHex),
            ))
        .toList();
  }

  Future<void> createCard({
    required String id,
    required String deckId,
    required String frontText,
    required String backText,
    String? frontImagePath,
    String? backImagePath,
  }) async {
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

  Future<void> deleteCard(String id) => _cardDao.deleteCard(id);
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
  return CardRepository(db.cardDao, db.deckDao);
});

final allCardsProvider = FutureProvider<List<MemoraCard>>((ref) async {
  return ref.read(cardRepositoryProvider).getAllCards();
});

final cardsByDeckProvider =
    FutureProvider.family<List<MemoraCard>, String>((ref, deckId) async {
  return ref.read(cardRepositoryProvider).getCardsByDeckId(deckId);
});
