import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'review_log_dao.g.dart';

@DriftAccessor(tables: [ReviewLogs])
class ReviewLogDao extends DatabaseAccessor<MemoraDatabase>
    with _$ReviewLogDaoMixin {
  ReviewLogDao(super.db);

  Future<int> insertLog(ReviewLogsCompanion log) =>
      into(reviewLogs).insert(log);

  Future<List<ReviewLog>> getRecentLogs({int limit = 100}) {
    return (select(reviewLogs)
          ..orderBy([(t) => OrderingTerm.desc(t.reviewedAt)])
          ..limit(limit))
        .get();
  }

  Future<List<ReviewLog>> getLogsSince(int sinceEpochMs) {
    return (select(reviewLogs)
          ..where((l) => l.reviewedAt.isBiggerOrEqualValue(sinceEpochMs)))
        .get();
  }
}
