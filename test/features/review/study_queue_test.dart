import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/core/srs/study_settings.dart';
import 'package:memora/data/database/database.dart';
import 'package:memora/data/repositories/card_repository.dart';
import 'package:memora/data/repositories/review_repository.dart';
import 'package:memora/features/review/study_queue.dart';

import '../../helpers/fake_sync_service.dart';
import '../../helpers/in_memory_db.dart';

void main() {
  late MemoraDatabase db;
  late FakeSyncService sync;
  late CardRepository cardRepo;
  late ReviewRepository reviewRepo;

  setUp(() {
    db = newInMemoryDb();
    sync = FakeSyncService(db);
    cardRepo = CardRepository(db.cardDao, db.deckDao, sync);
    reviewRepo = ReviewRepository(db.scheduleDao, db.reviewLogDao, sync);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedDeck(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.decks).insert(
          DecksCompanion.insert(
            id: id,
            name: id,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> seedScheduledCard({
    required String cardId,
    required String deckId,
    required int nextReviewMs,
    String state = 'reviewing',
  }) async {
    await cardRepo.createCard(
      id: cardId,
      deckId: deckId,
      frontText: 'f-$cardId',
      backText: 'b-$cardId',
    );
    await db.scheduleDao.upsertSchedule(
      CardSchedulesCompanion.insert(
        cardId: cardId,
        nextReviewDate: nextReviewMs,
        state: Value(state),
        intervalDays: const Value(1),
        repetitions: const Value(1),
      ),
    );
  }

  test('cola vacia cuando no hay cards', () async {
    final builder = StudyQueueBuilder(
      cardRepo: cardRepo,
      reviewRepo: reviewRepo,
      settings: StudySettings.defaults,
    );

    final q = await builder.build();
    expect(q.isEmpty, isTrue);
    expect(q.cards, isEmpty);
    expect(q.dueCount, 0);
    expect(q.newCount, 0);
  });

  test('cards sin schedule se tratan como new y respetan newCardsPerDay',
      () async {
    await seedDeck('d1');
    for (var i = 0; i < 5; i++) {
      await cardRepo.createCard(
        id: 'n$i',
        deckId: 'd1',
        frontText: 'f$i',
        backText: 'b$i',
      );
    }

    final builder = StudyQueueBuilder(
      cardRepo: cardRepo,
      reviewRepo: reviewRepo,
      settings: const StudySettings(newCardsPerDay: 3, maxReviewsPerDay: 50),
    );

    final q = await builder.build();
    expect(q.newCount, 3);
    expect(q.dueCount, 0);
    expect(q.totalAvailable, 5); // total disponible no se trunca
    expect(q.cards, hasLength(3));
  });

  test('schedule con next_review_date <= now se considera due', () async {
    await seedDeck('d1');
    final now = DateTime(2026, 1, 1);
    await seedScheduledCard(
      cardId: 'due1',
      deckId: 'd1',
      nextReviewMs: now.millisecondsSinceEpoch - 1000,
    );
    await seedScheduledCard(
      cardId: 'future1',
      deckId: 'd1',
      nextReviewMs: now.millisecondsSinceEpoch + 86400000,
    );

    final builder = StudyQueueBuilder(
      cardRepo: cardRepo,
      reviewRepo: reviewRepo,
      settings: StudySettings.defaults,
    );

    final q = await builder.build(now: now);
    expect(q.dueCount, 1);
    expect(q.newCount, 0);
    final ids = q.cards.map((c) => c.id).toList();
    expect(ids, contains('due1'));
    expect(ids, isNot(contains('future1')));
  });

  test('schedule en estado "new" cuenta como new aunque haya fila', () async {
    await seedDeck('d1');
    final now = DateTime(2026, 1, 1);
    await seedScheduledCard(
      cardId: 'newish',
      deckId: 'd1',
      nextReviewMs: now.millisecondsSinceEpoch - 1000,
      state: 'new',
    );

    final builder = StudyQueueBuilder(
      cardRepo: cardRepo,
      reviewRepo: reviewRepo,
      settings: const StudySettings(newCardsPerDay: 5, maxReviewsPerDay: 50),
    );

    final q = await builder.build(now: now);
    expect(q.newCount, 1);
    expect(q.dueCount, 0);
  });

  test('maxReviewsPerDay limita el total de cards retornadas', () async {
    await seedDeck('d1');
    final now = DateTime(2026, 1, 1);
    for (var i = 0; i < 10; i++) {
      await seedScheduledCard(
        cardId: 'd$i',
        deckId: 'd1',
        nextReviewMs: now.millisecondsSinceEpoch - 1000,
      );
    }

    final builder = StudyQueueBuilder(
      cardRepo: cardRepo,
      reviewRepo: reviewRepo,
      settings: const StudySettings(newCardsPerDay: 0, maxReviewsPerDay: 4),
    );

    final q = await builder.build(now: now);
    expect(q.cards, hasLength(4));
    expect(q.dueCount, 10); // due count refleja todas las disponibles
  });

  test('build filtrado por deckId solo considera cards de ese deck', () async {
    await seedDeck('d1');
    await seedDeck('d2');
    final now = DateTime(2026, 1, 1);
    await seedScheduledCard(
      cardId: 'x',
      deckId: 'd1',
      nextReviewMs: now.millisecondsSinceEpoch - 1000,
    );
    await seedScheduledCard(
      cardId: 'y',
      deckId: 'd2',
      nextReviewMs: now.millisecondsSinceEpoch - 1000,
    );

    final builder = StudyQueueBuilder(
      cardRepo: cardRepo,
      reviewRepo: reviewRepo,
      settings: StudySettings.defaults,
    );

    final q = await builder.build(deckId: 'd1', now: now);
    expect(q.cards.map((c) => c.id), ['x']);
  });
}
