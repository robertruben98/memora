import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'card_dao.g.dart';

@DriftAccessor(tables: [Cards])
class CardDao extends DatabaseAccessor<MemoraDatabase> with _$CardDaoMixin {
  CardDao(super.db);

  Future<List<Card>> getAllCards() => select(cards).get();

  Future<List<Card>> getCardsByDeck(String deckId) =>
      (select(cards)..where((c) => c.deckId.equals(deckId))).get();

  Stream<List<Card>> watchCardsByDeck(String deckId) =>
      (select(cards)..where((c) => c.deckId.equals(deckId))).watch();

  Future<Card?> getCardById(String id) =>
      (select(cards)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<int> insertCard(CardsCompanion card) => into(cards).insert(card);

  Future<bool> updateCard(CardsCompanion card) => update(cards).replace(card);

  Future<int> deleteCard(String id) =>
      (delete(cards)..where((c) => c.id.equals(id))).go();

  Future<int> countCardsByDeck(String deckId) async {
    final query = selectOnly(cards)
      ..addColumns([cards.id.count()])
      ..where(cards.deckId.equals(deckId));
    final result = await query.getSingle();
    return result.read(cards.id.count()) ?? 0;
  }
}
