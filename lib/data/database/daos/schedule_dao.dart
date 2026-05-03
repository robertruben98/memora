import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'schedule_dao.g.dart';

@DriftAccessor(tables: [CardSchedules])
class ScheduleDao extends DatabaseAccessor<MemoraDatabase>
    with _$ScheduleDaoMixin {
  ScheduleDao(super.db);

  Future<CardScheduleRow?> getScheduleByCardId(String cardId) =>
      (select(cardSchedules)..where((s) => s.cardId.equals(cardId)))
          .getSingleOrNull();

  Future<List<CardScheduleRow>> getDueSchedules(int nowEpochMs) {
    return (select(cardSchedules)
          ..where((s) => s.nextReviewDate.isSmallerOrEqualValue(nowEpochMs)))
        .get();
  }

  Future<int> upsertSchedule(CardSchedulesCompanion schedule) {
    return into(cardSchedules).insertOnConflictUpdate(schedule);
  }

  Future<int> deleteScheduleByCardId(String cardId) =>
      (delete(cardSchedules)..where((s) => s.cardId.equals(cardId))).go();

  Future<Map<String, CardScheduleRow>> getSchedulesByCardIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const {};
    final rows = await (select(cardSchedules)
          ..where((s) => s.cardId.isIn(ids)))
        .get();
    return {for (final r in rows) r.cardId: r};
  }
}
