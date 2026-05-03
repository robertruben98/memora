import 'package:drift/drift.dart' show Value;

import 'database/database.dart';

const _seedDecks = [
  _SeedDeck(
    id: 'seed-deck-1',
    name: 'Inglés - Verbos',
    colorHex: '#4F8AFF',
    iconName: 'translate_rounded',
  ),
  _SeedDeck(
    id: 'seed-deck-2',
    name: 'Geografía',
    colorHex: '#FF8A4F',
    iconName: 'public_rounded',
  ),
  _SeedDeck(
    id: 'seed-deck-3',
    name: 'Algoritmos',
    colorHex: '#4FFFB0',
    iconName: 'code_rounded',
  ),
  _SeedDeck(
    id: 'seed-deck-4',
    name: 'Aprendizaje',
    colorHex: '#FFD24F',
    iconName: 'psychology_rounded',
  ),
  _SeedDeck(
    id: 'seed-deck-5',
    name: 'Arte',
    colorHex: '#E04FFF',
    iconName: 'palette_rounded',
  ),
];

const _seedCards = [
  _SeedCard(
    id: 'seed-card-1',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to thrive"?',
    back: 'Prosperar, florecer. Crecer con vigor.',
  ),
  _SeedCard(
    id: 'seed-card-2',
    deckId: 'seed-deck-2',
    front: '¿Cuál es la capital de Mongolia?',
    back: 'Ulán Bator (Ulaanbaatar).',
  ),
  _SeedCard(
    id: 'seed-card-3',
    deckId: 'seed-deck-3',
    front: 'En Big-O, ¿complejidad de búsqueda binaria?',
    back: 'O(log n) — divide el espacio de búsqueda a la mitad en cada paso.',
  ),
  _SeedCard(
    id: 'seed-card-4',
    deckId: 'seed-deck-4',
    front: '¿Qué es la repetición espaciada?',
    back: 'Técnica de aprendizaje que aumenta los intervalos entre repasos de '
        'material ya aprendido para optimizar la memoria a largo plazo.',
  ),
  _SeedCard(
    id: 'seed-card-5',
    deckId: 'seed-deck-5',
    front: '¿Quién pintó "La noche estrellada"?',
    back: 'Vincent van Gogh, en 1889.',
  ),
];

Future<void> seedIfEmpty(MemoraDatabase db) async {
  final existing = await db.deckDao.getAllDecks();
  if (existing.isNotEmpty) return;

  final now = DateTime.now().millisecondsSinceEpoch;

  await db.batch((b) {
    for (final d in _seedDecks) {
      b.insert(
        db.decks,
        DecksCompanion.insert(
          id: d.id,
          name: d.name,
          colorHex: Value(d.colorHex),
          iconName: Value(d.iconName),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    for (final c in _seedCards) {
      b.insert(
        db.cards,
        CardsCompanion.insert(
          id: c.id,
          deckId: c.deckId,
          frontText: c.front,
          backText: c.back,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  });
}

class _SeedDeck {
  final String id;
  final String name;
  final String colorHex;
  final String iconName;

  const _SeedDeck({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.iconName,
  });
}

class _SeedCard {
  final String id;
  final String deckId;
  final String front;
  final String back;

  const _SeedCard({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
  });
}
