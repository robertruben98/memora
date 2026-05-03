import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';

class DailyActivity {
  final DateTime day;
  final int count;

  const DailyActivity({required this.day, required this.count});
}

class StatsSnapshot {
  final int streak;
  final int reviewsToday;
  final int reviewsThisWeek;
  final int totalReviews;
  final double retention; // 0..1
  final int newCount;
  final int learningCount;
  final int reviewingCount;
  final int totalCards;
  final List<DailyActivity> last30Days;

  const StatsSnapshot({
    required this.streak,
    required this.reviewsToday,
    required this.reviewsThisWeek,
    required this.totalReviews,
    required this.retention,
    required this.newCount,
    required this.learningCount,
    required this.reviewingCount,
    required this.totalCards,
    required this.last30Days,
  });

  static const empty = StatsSnapshot(
    streak: 0,
    reviewsToday: 0,
    reviewsThisWeek: 0,
    totalReviews: 0,
    retention: 0.0,
    newCount: 0,
    learningCount: 0,
    reviewingCount: 0,
    totalCards: 0,
    last30Days: [],
  );
}

class StatsRepository {
  final MemoraDatabase db;

  StatsRepository(this.db);

  Future<StatsSnapshot> snapshot({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final todayStart = DateTime(clock.year, clock.month, clock.day);
    final weekStart = todayStart.subtract(Duration(days: clock.weekday - 1));
    final monthAgo = todayStart.subtract(const Duration(days: 30));

    final allLogs = await db.reviewLogDao.getRecentLogs(limit: 5000);

    int reviewsToday = 0;
    int reviewsThisWeek = 0;
    int monthCorrect = 0;
    int monthTotal = 0;
    final daysWithReviews = <DateTime>{};

    for (final log in allLogs) {
      final dt = DateTime.fromMillisecondsSinceEpoch(log.reviewedAt);
      final dayKey = DateTime(dt.year, dt.month, dt.day);
      daysWithReviews.add(dayKey);
      if (!dt.isBefore(todayStart)) reviewsToday++;
      if (!dt.isBefore(weekStart)) reviewsThisWeek++;
      if (!dt.isBefore(monthAgo)) {
        monthTotal++;
        if (log.result == 'correct') monthCorrect++;
      }
    }

    final retention = monthTotal == 0 ? 0.0 : monthCorrect / monthTotal;

    // Streak: días consecutivos hasta hoy (o hasta ayer si no hubo hoy).
    int streak = 0;
    var cursor = todayStart;
    if (!daysWithReviews.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (daysWithReviews.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // Actividad últimos 30 días (incluyendo hoy).
    final byDay = <DateTime, int>{};
    for (final log in allLogs) {
      final dt = DateTime.fromMillisecondsSinceEpoch(log.reviewedAt);
      final dayKey = DateTime(dt.year, dt.month, dt.day);
      if (!dayKey.isBefore(monthAgo)) {
        byDay[dayKey] = (byDay[dayKey] ?? 0) + 1;
      }
    }
    final activity = <DailyActivity>[];
    for (var i = 29; i >= 0; i--) {
      final d = todayStart.subtract(Duration(days: i));
      activity.add(DailyActivity(day: d, count: byDay[d] ?? 0));
    }

    // Distribución por estado.
    final cards = await db.cardDao.getAllCards();
    final cardIds = cards.map((c) => c.id).toList();
    final schedules = await db.scheduleDao.getSchedulesByCardIds(cardIds);

    int newCount = 0;
    int learningCount = 0;
    int reviewingCount = 0;
    for (final c in cards) {
      final s = schedules[c.id];
      if (s == null || s.state == 'new') {
        newCount++;
      } else if (s.state == 'learning') {
        learningCount++;
      } else {
        reviewingCount++;
      }
    }

    return StatsSnapshot(
      streak: streak,
      reviewsToday: reviewsToday,
      reviewsThisWeek: reviewsThisWeek,
      totalReviews: allLogs.length,
      retention: retention,
      newCount: newCount,
      learningCount: learningCount,
      reviewingCount: reviewingCount,
      totalCards: cards.length,
      last30Days: activity,
    );
  }
}

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository(ref.watch(databaseProvider));
});

final statsSnapshotProvider =
    FutureProvider.autoDispose<StatsSnapshot>((ref) async {
  return ref.read(statsRepositoryProvider).snapshot();
});
