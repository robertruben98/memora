import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/core/models/memora_card.dart';
import 'package:memora/data/database/database.dart';
import 'package:memora/data/repositories/review_repository.dart';
import 'package:memora/features/browse/widgets/feed_post_card.dart';
import 'package:memora/features/stats/card_stats_provider.dart';

void main() {
  testWidgets(
    'FeedPostCard renderiza pregunta sin schedule ni stats (smoke)',
    (tester) async {
      const card = MemoraCard(
        id: 'card-1',
        deckId: 'deck-1',
        front: '¿Capital de Francia?',
        back: 'París',
        deck: 'Geografía',
        deckIconName: 'public',
        deckColor: Color(0xFF4F8CFF),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allCardSchedulesProvider
                .overrideWith((ref) async => <String, CardScheduleRow>{}),
            cardStatsProvider
                .overrideWith((ref) async => <String, CardStats>{}),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FeedPostCard(card: card),
              ),
            ),
          ),
        ),
      );

      // Una pasada para resolver los FutureProviders.
      await tester.pump();

      // El widget se renderiza sin excepciones.
      expect(find.byType(FeedPostCard), findsOneWidget);
      // Header con nombre del mazo (aparece tanto en avatar como en TextSpan).
      expect(find.text('Geografía'), findsOneWidget);
      // CTA "Ver respuesta" presente antes de revelar.
      expect(find.text('Ver respuesta'), findsOneWidget);
      // Estado SRS por defecto cuando no hay schedule: "Nueva".
      expect(find.text('Nueva'), findsOneWidget);
    },
  );
}
