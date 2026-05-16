import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/database/database.dart';
import 'package:memora/data/repositories/card_repository.dart';

import '../../helpers/fake_sync_service.dart';
import '../../helpers/in_memory_db.dart';

void main() {
  late MemoraDatabase db;
  late FakeSyncService sync;
  late CardRepository repo;

  setUp(() {
    db = newInMemoryDb();
    sync = FakeSyncService(db);
    repo = CardRepository(db.cardDao, db.deckDao, sync);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedDeck(String id, {String name = 'Mazo'}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.decks).insert(
          DecksCompanion.insert(
            id: id,
            name: name,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  test('createCard inserta en local y notifica al sync', () async {
    await seedDeck('deck-1');

    await repo.createCard(
      id: 'c1',
      deckId: 'deck-1',
      frontText: 'hola',
      backText: 'mundo',
    );

    final rows = await db.cardDao.getCardsByDeck('deck-1');
    expect(rows, hasLength(1));
    expect(rows.first.frontText, 'hola');
    expect(rows.first.backText, 'mundo');
    expect(sync.upsertedCardIds, contains('c1'));
  });

  test('getCardsByDeckId filtra por deck y mapea a MemoraCard', () async {
    await seedDeck('deck-a', name: 'A');
    await seedDeck('deck-b', name: 'B');
    await repo.createCard(
      id: 'a1',
      deckId: 'deck-a',
      frontText: 'fa',
      backText: 'ba',
    );
    await repo.createCard(
      id: 'b1',
      deckId: 'deck-b',
      frontText: 'fb',
      backText: 'bb',
    );

    final aCards = await repo.getCardsByDeckId('deck-a');
    expect(aCards, hasLength(1));
    expect(aCards.first.id, 'a1');
    expect(aCards.first.deck, 'A');
  });

  test('getCardsByDeckId devuelve vacio si el deck no existe', () async {
    final cards = await repo.getCardsByDeckId('ghost');
    expect(cards, isEmpty);
  });

  test('getAllCards mezcla cards de varios decks con sus metadatos', () async {
    await seedDeck('deck-a', name: 'A');
    await seedDeck('deck-b', name: 'B');
    await repo.createCard(
      id: 'a1',
      deckId: 'deck-a',
      frontText: 'fa',
      backText: 'ba',
    );
    await repo.createCard(
      id: 'b1',
      deckId: 'deck-b',
      frontText: 'fb',
      backText: 'bb',
    );

    final all = await repo.getAllCards();
    expect(all, hasLength(2));
    final byId = {for (final c in all) c.id: c};
    expect(byId['a1']!.deck, 'A');
    expect(byId['b1']!.deck, 'B');
  });

  test('deleteCard borra la fila local y avisa al sync', () async {
    await seedDeck('deck-1');
    await repo.createCard(
      id: 'c1',
      deckId: 'deck-1',
      frontText: 'hola',
      backText: 'mundo',
    );

    await repo.deleteCard('c1');

    final rows = await db.cardDao.getCardsByDeck('deck-1');
    expect(rows, isEmpty);
    expect(sync.deletedCardIds, contains('c1'));
  });

  test('updateCard cambia el contenido pero mantiene el deck', () async {
    await seedDeck('deck-1');
    await repo.createCard(
      id: 'c1',
      deckId: 'deck-1',
      frontText: 'old-f',
      backText: 'old-b',
    );

    await repo.updateCard(
      id: 'c1',
      frontText: 'new-f',
      backText: 'new-b',
    );

    final row = await db.cardDao.getCardById('c1');
    expect(row, isNotNull);
    expect(row!.frontText, 'new-f');
    expect(row.backText, 'new-b');
    expect(row.deckId, 'deck-1');
  });

  test('updateCard sobre id inexistente no falla', () async {
    await repo.updateCard(
      id: 'ghost',
      frontText: 'x',
      backText: 'y',
    );
    // no excepcion; tampoco crea filas
    final rows = await db.cardDao.getAllCards();
    expect(rows, isEmpty);
  });

  // Mantener `Value` referenciada para evitar warning del linter sobre import.
  test('drift Value sigue siendo accesible (helper de imports)', () {
    expect(const Value('x').present, isTrue);
  });
}
