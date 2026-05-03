import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/memora_card.dart';
import '../../core/srs/study_settings.dart';
import '../../data/repositories/card_repository.dart';
import '../../data/repositories/review_repository.dart';

class StudyQueue {
  final List<MemoraCard> cards;
  final int dueCount;
  final int newCount;
  final int totalAvailable;

  const StudyQueue({
    required this.cards,
    required this.dueCount,
    required this.newCount,
    required this.totalAvailable,
  });

  bool get isEmpty => cards.isEmpty;

  static const empty = StudyQueue(
    cards: [],
    dueCount: 0,
    newCount: 0,
    totalAvailable: 0,
  );
}

class StudyQueueBuilder {
  final CardRepository cardRepo;
  final ReviewRepository reviewRepo;
  final StudySettings settings;

  StudyQueueBuilder({
    required this.cardRepo,
    required this.reviewRepo,
    required this.settings,
  });

  Future<StudyQueue> build({String? deckId, DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final cards = deckId != null
        ? await cardRepo.getCardsByDeckId(deckId)
        : await cardRepo.getAllCards();
    if (cards.isEmpty) return StudyQueue.empty;

    final scheduleMap =
        await reviewRepo.getSchedulesByCardIds(cards.map((c) => c.id).toList());
    final nowMs = clock.millisecondsSinceEpoch;

    final due = <MemoraCard>[];
    final newOnes = <MemoraCard>[];
    for (final c in cards) {
      final sched = scheduleMap[c.id];
      if (sched == null || sched.state == 'new') {
        newOnes.add(c);
      } else if (sched.nextReviewDate <= nowMs) {
        due.add(c);
      }
    }

    newOnes.shuffle();
    final selectedNew = newOnes.take(settings.newCardsPerDay).toList();

    final combined = [...due, ...selectedNew]..shuffle();
    final limited = combined.take(settings.maxReviewsPerDay).toList();

    return StudyQueue(
      cards: limited,
      dueCount: due.length,
      newCount: selectedNew.length,
      totalAvailable: due.length + newOnes.length,
    );
  }
}

final studyQueueBuilderProvider = Provider<StudyQueueBuilder>((ref) {
  return StudyQueueBuilder(
    cardRepo: ref.watch(cardRepositoryProvider),
    reviewRepo: ref.watch(reviewRepositoryProvider),
    settings: ref.watch(studySettingsProvider),
  );
});

final studyQueueProvider =
    FutureProvider.family<StudyQueue, String?>((ref, deckId) async {
  return ref.read(studyQueueBuilderProvider).build(deckId: deckId);
});
