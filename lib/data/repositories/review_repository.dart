import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/srs/srs_algorithm.dart';
import '../database/daos/review_log_dao.dart';
import '../database/daos/schedule_dao.dart';
import '../database/database.dart';

class ReviewRepository {
  final ScheduleDao _scheduleDao;
  final ReviewLogDao _reviewLogDao;

  ReviewRepository(this._scheduleDao, this._reviewLogDao);

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
    final sched = await getOrCreateSchedule(cardId, now: now);

    final result = SrsAlgorithm.computeNext(
      easeFactor: sched.easeFactor,
      repetitions: sched.repetitions,
      intervalDays: sched.intervalDays,
      quality: correct
          ? SrsAlgorithm.qualityCorrect
          : SrsAlgorithm.qualityIncorrect,
    );

    final nowMs = now.millisecondsSinceEpoch;
    final nextReviewMs =
        nowMs + Duration(days: result.intervalDays).inMilliseconds;

    await _scheduleDao.upsertSchedule(
      CardSchedulesCompanion(
        cardId: Value(cardId),
        easeFactor: Value(result.easeFactor),
        repetitions: Value(result.repetitions),
        intervalDays: Value(result.intervalDays),
        state: Value(result.state.dbValue),
        nextReviewDate: Value(nextReviewMs),
        lastReviewDate: Value(nowMs),
      ),
    );

    await _reviewLogDao.insertLog(
      ReviewLogsCompanion.insert(
        cardId: cardId,
        reviewedAt: nowMs,
        result: correct ? 'correct' : 'incorrect',
        previousIntervalDays: sched.intervalDays,
        newIntervalDays: result.intervalDays,
      ),
    );

    return result;
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
  return ReviewRepository(db.scheduleDao, db.reviewLogDao);
});
