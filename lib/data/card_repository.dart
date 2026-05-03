import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/memora_card.dart';

abstract class CardRepository {
  Future<List<MemoraCard>> getAllCards();
  Future<List<DeckSummary>> getDeckSummaries();
  Future<List<MemoraCard>> getCardsByDeck(String deckName);
}

class InMemoryCardRepository implements CardRepository {
  static const _cards = <MemoraCard>[
    MemoraCard(
      id: '1',
      front: '¿Qué significa "to thrive"?',
      back: 'Prosperar, florecer. Crecer con vigor.',
      deck: 'Inglés - Verbos',
      deckColor: Color(0xFF4F8AFF),
    ),
    MemoraCard(
      id: '2',
      front: '¿Cuál es la capital de Mongolia?',
      back: 'Ulán Bator (Ulaanbaatar).',
      deck: 'Geografía',
      deckColor: Color(0xFFFF8A4F),
    ),
    MemoraCard(
      id: '3',
      front: 'En Big-O, ¿complejidad de búsqueda binaria?',
      back: 'O(log n) — divide el espacio de búsqueda a la mitad en cada paso.',
      deck: 'Algoritmos',
      deckColor: Color(0xFF4FFFB0),
    ),
    MemoraCard(
      id: '4',
      front: '¿Qué es la repetición espaciada?',
      back:
          'Técnica de aprendizaje que aumenta los intervalos entre repasos de '
          'material ya aprendido para optimizar la memoria a largo plazo.',
      deck: 'Aprendizaje',
      deckColor: Color(0xFFFFD24F),
    ),
    MemoraCard(
      id: '5',
      front: '¿Quién pintó "La noche estrellada"?',
      back: 'Vincent van Gogh, en 1889.',
      deck: 'Arte',
      deckColor: Color(0xFFE04FFF),
    ),
  ];

  @override
  Future<List<MemoraCard>> getAllCards() async => List.of(_cards);

  @override
  Future<List<DeckSummary>> getDeckSummaries() async {
    final byDeck = <String, List<MemoraCard>>{};
    for (final c in _cards) {
      byDeck.putIfAbsent(c.deck, () => []).add(c);
    }
    return byDeck.entries.map((e) {
      return DeckSummary(
        name: e.key,
        color: e.value.first.deckColor,
        dueCount: e.value.length,
        totalCount: e.value.length,
        cards: List.of(e.value),
      );
    }).toList();
  }

  @override
  Future<List<MemoraCard>> getCardsByDeck(String deckName) async {
    return _cards.where((c) => c.deck == deckName).toList();
  }
}

final cardRepositoryProvider = Provider<CardRepository>(
  (ref) => InMemoryCardRepository(),
);

final allCardsProvider = FutureProvider<List<MemoraCard>>((ref) async {
  return ref.read(cardRepositoryProvider).getAllCards();
});

final deckSummariesProvider = FutureProvider<List<DeckSummary>>((ref) async {
  return ref.read(cardRepositoryProvider).getDeckSummaries();
});
