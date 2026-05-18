import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/core/models/memora_card.dart';
import 'package:memora/features/study/failed_cards_provider.dart';
import 'package:memora/features/study/failed_review_screen.dart';

MemoraCard _card(String id) => MemoraCard(
      id: id,
      deckId: 'deck-1',
      front: 'pregunta $id',
      back: 'respuesta $id',
      deck: 'Senales',
      deckIconName: 'style_rounded',
      deckColor: const Color(0xFF7C5CFF),
    );

void main() {
  testWidgets('empty state cuando no hay cards falladas', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          failedCardsProvider.overrideWith((ref) async {
            return FailedCardsResult.empty;
          }),
        ],
        child: const MaterialApp(home: FailedReviewScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin fallos recientes'), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
  });

  testWidgets('render con 3 cards muestra contador 1/3', (tester) async {
    final cards = [_card('a'), _card('b'), _card('c')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          failedCardsProvider.overrideWith((ref) async {
            return FailedCardsResult(cards: cards, count: cards.length);
          }),
        ],
        child: const MaterialApp(home: FailedReviewScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Falladas'), findsOneWidget);
    expect(find.textContaining('1 / 3'), findsOneWidget);
  });
}
