import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'deck_dao.g.dart';

@DriftAccessor(tables: [Decks])
class DeckDao extends DatabaseAccessor<MemoraDatabase> with _$DeckDaoMixin {
  DeckDao(super.db);

  Future<List<DeckRow>> getAllDecks() => select(decks).get();

  Stream<List<DeckRow>> watchAllDecks() => select(decks).watch();

  Future<DeckRow?> getDeckById(String id) =>
      (select(decks)..where((d) => d.id.equals(id))).getSingleOrNull();

  Future<int> insertDeck(DecksCompanion deck) => into(decks).insert(deck);

  Future<bool> updateDeck(DecksCompanion deck) => update(decks).replace(deck);

  Future<int> deleteDeck(String id) =>
      (delete(decks)..where((d) => d.id.equals(id))).go();
}
