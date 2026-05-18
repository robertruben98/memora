// Test de migracion para issue #35 (DGT pivot prep).
// Verifica que el upgrade v1 -> v2 anade las columnas cardType y
// questionPayloadJson a la tabla Cards sin perder datos existentes.
//
// Nota: el archivo se llama migration_v3_test como indicaba la sugerencia
// del issue, pero el schemaVersion actual sube de 1 a 2. Cuando se agregue
// el siguiente bump, este test puede extenderse a v3.

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/database/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('schemaVersion is 2 (v1 -> v2 pivot DGT)', () {
    final db = MemoraDatabase.forTesting(NativeDatabase.memory());
    expect(db.schemaVersion, 2);
    db.close();
  });

  test('cards inserted on v2 retain cardType default = flashcard', () async {
    final db = MemoraDatabase.forTesting(NativeDatabase.memory());

    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.decks).insert(
          DecksCompanion.insert(
            id: 'deck-1',
            name: 'Deck test',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.cards).insert(
          CardsCompanion.insert(
            id: 'card-1',
            deckId: 'deck-1',
            frontText: 'Q',
            backText: 'A',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final stored =
        await (db.select(db.cards)..where((c) => c.id.equals('card-1')))
            .getSingle();
    expect(stored.cardType, 'flashcard');
    expect(stored.questionPayloadJson, isNull);

    await db.close();
  });

  test('cards can store dgt_question payload without breaking flashcards',
      () async {
    final db = MemoraDatabase.forTesting(NativeDatabase.memory());

    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.decks).insert(
          DecksCompanion.insert(
            id: 'deck-dgt',
            name: 'DGT',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db.into(db.cards).insert(
          CardsCompanion.insert(
            id: 'flash-1',
            deckId: 'deck-dgt',
            frontText: 'classic',
            backText: 'classic',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.cards).insert(
          CardsCompanion.insert(
            id: 'dgt-1',
            deckId: 'deck-dgt',
            frontText: 'Que indica la senal R-1?',
            backText: 'Ceda el paso',
            cardType: const Value('dgt_question'),
            questionPayloadJson: const Value(
              '{"choices":["A","B","C"],"correct":1,"explanation":"..."}',
            ),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final flash =
        await (db.select(db.cards)..where((c) => c.id.equals('flash-1')))
            .getSingle();
    final dgt = await (db.select(db.cards)..where((c) => c.id.equals('dgt-1')))
        .getSingle();

    expect(flash.cardType, 'flashcard');
    expect(flash.questionPayloadJson, isNull);
    expect(dgt.cardType, 'dgt_question');
    expect(dgt.questionPayloadJson, contains('choices'));

    await db.close();
  });
}
