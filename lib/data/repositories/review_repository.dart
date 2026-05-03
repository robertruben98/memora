import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/srs/srs_algorithm.dart';
import '../database/daos/review_log_dao.dart';
import '../database/daos/schedule_dao.dart';
import '../database/database.dart';
import '../sync/sync_service.dart';

class ReviewRepository {
  final ScheduleDao _scheduleDao;
  final ReviewLogDao _reviewLogDao;
  final SyncService _sync;

  ReviewRepository(this._scheduleDao, this._reviewLogDao, this._sync);

  Future<CardScheduleRow> getOrCreateSchedule(
    String cardId, {
    required DateTime now,
  }) async {
    final existing = await _scheduleDao.getScheduleByCardId(cardId);
    if (existing != null) return existing;
    final nowMs = now.millisecondsSinceEpoch;
    await _scheduleDao.upsertSchedule(
      CardSchedulesCompanion.insert(
        cardId: cardId,
        nextReviewDate: nowMs,
      ),
    );
    final fresh = await _scheduleDao.getScheduleByCardId(cardId);
    return fresh!;
  }

  Future<SrsResult> recordReview({
    required String cardId,
    required bool correct,
    required DateTime now,
  }) async {
    final nowMs = now.millisecondsSinceEpoch;
    final previous = await _scheduleDao.getScheduleByCardId(cardId);
    final previousInterval = previous?.intervalDays ?? 0;

    // Server applies SM-2 atómicamente y devuelve el nuevo schedule.
    final res = await _sync.recordReview(
      cardId: cardId,
      correct: correct,
      nowMs: nowMs,
    );

    final newInterval = (res['interval_days'] as num).toInt();
    final newRepetitions = (res['repetitions'] as num).toInt();
    final newEase = (res['ease_factor'] as num).toDouble();
    final newState = res['state'] as String;
    final nextReviewMs = (res['next_review_date'] as num).toInt();

    // Mirror local
    await _scheduleDao.upsertSchedule(
      CardSchedulesCompanion(
        cardId: Value(cardId),
        easeFactor: Value(newEase),
        repetitions: Value(newRepetitions),
        intervalDays: Value(newInterval),
        state: Value(newState),
        nextReviewDate: Value(nextReviewMs),
        lastReviewDate: Value(nowMs),
      ),
    );
    await _reviewLogDao.insertLog(
      ReviewLogsCompanion.insert(
        cardId: cardId,
        reviewedAt: nowMs,
        result: correct ? 'correct' : 'incorrect',
        previousIntervalDays: previousInterval,
        newIntervalDays: newInterval,
      ),
    );

    return SrsResult(
      easeFactor: newEase,
      repetitions: newRepetitions,
      intervalDays: newInterval,
      state: SrsCardState.fromDb(newState),
    );
  }

  Future<Map<String, CardScheduleRow>> getSchedulesByCardIds(
    List<String> ids,
  ) {
    return _scheduleDao.getSchedulesByCardIds(ids);
  }

  Future<List<String>> getDueCardIds(DateTime now) async {
    final rows = await _scheduleDao.getDueSchedules(now.millisecondsSinceEpoch);
    return rows.map((s) => s.cardId).toList();
  }

  Future<List<ReviewLogRow>> getRecentLogs({int limit = 100}) {
    return _reviewLogDao.getRecentLogs(limit: limit);
  }

  Future<List<ReviewLogRow>> getLogsSince(DateTime since) {
    return _reviewLogDao.getLogsSince(since.millisecondsSinceEpoch);
  }
}

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ReviewRepository(
    db.scheduleDao,
    db.reviewLogDao,
    ref.watch(syncServiceProvider),
  );
});

/// Map cardId -> schedule, para vistas que necesitan estado SRS por tarjeta
/// (evita N+1 queries).
final allCardSchedulesProvider =
    FutureProvider<Map<String, CardScheduleRow>>((ref) async {
  final db = ref.watch(databaseProvider);
  final cards = await db.cardDao.getAllCards();
  final ids = cards.map((c) => c.id).toList();
  return ref.read(reviewRepositoryProvider).getSchedulesByCardIds(ids);
});
