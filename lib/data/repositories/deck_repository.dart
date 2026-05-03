import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/memora_card.dart';
import '../database/daos/card_dao.dart';
import '../database/daos/deck_dao.dart';
import '../database/database.dart';

class DeckRepository {
  final DeckDao _deckDao;
  final CardDao _cardDao;

  DeckRepository(this._deckDao, this._cardDao);

  Future<List<DeckRow>> getAllDecks() => _deckDao.getAllDecks();

  Future<DeckRow?> getDeckById(String id) => _deckDao.getDeckById(id);

  Future<void> createDeck({
    required String id,
    required String name,
    String? description,
    String colorHex = '#7C5CFF',
    String iconName = 'style_rounded',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _deckDao.insertDeck(
      DecksCompanion.insert(
        id: id,
        name: name,
        description: Value(description),
        colorHex: Value(colorHex),
        iconName: Value(iconName),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> updateDeck({
    required String id,
    required String name,
    String? description,
    required String colorHex,
    required String iconName,
  }) async {
    final existing = await _deckDao.getDeckById(id);
    if (existing == null) return;
    await _deckDao.updateDeck(
      DecksCompanion(
        id: Value(id),
        name: Value(name),
        description: Value(description),
        colorHex: Value(colorHex),
        iconName: Value(iconName),
        createdAt: Value(existing.createdAt),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> deleteDeck(String id) => _deckDao.deleteDeck(id);

  Future<List<DeckSummary>> getDeckSummaries() async {
    final decks = await _deckDao.getAllDecks();
    final result = <DeckSummary>[];
    for (final d in decks) {
      final cardRows = await _cardDao.getCardsByDeck(d.id);
      final cards = cardRows
          .map((c) => MemoraCard(
                id: c.id,
                deckId: c.deckId,
                front: c.frontText,
                back: c.backText,
                frontImagePath: c.frontImagePath,
                backImagePath: c.backImagePath,
                deck: d.name,
                deckIconName: d.iconName,
                deckColor: _parseColor(d.colorHex),
              ))
          .toList();
      result.add(
        DeckSummary(
          id: d.id,
          name: d.name,
          color: _parseColor(d.colorHex),
          iconName: d.iconName,
          dueCount: cards.length,
          totalCount: cards.length,
          cards: cards,
        ),
      );
    }
    return result;
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

final deckRepositoryProvider = Provider<DeckRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DeckRepository(db.deckDao, db.cardDao);
});

final deckSummariesProvider = FutureProvider<List<DeckSummary>>((ref) async {
  return ref.read(deckRepositoryProvider).getDeckSummaries();
});

final deckByIdProvider =
    FutureProvider.family<DeckRow?, String>((ref, id) async {
  return ref.read(deckRepositoryProvider).getDeckById(id);
});
