import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';

class CardStats {
  final int correct;
  final int total;
  final int? lastReviewMs;

  const CardStats({
    required this.correct,
    required this.total,
    this.lastReviewMs,
  });

  bool get hasReviews => total > 0;

  static const empty = CardStats(correct: 0, total: 0);
}

final cardStatsProvider =
    FutureProvider<Map<String, CardStats>>((ref) async {
  final db = ref.watch(databaseProvider);
  final logs = await db.reviewLogDao.getRecentLogs(limit: 50000);
  final byCard = <String, _Acc>{};
  for (final l in logs) {
    final acc = byCard.putIfAbsent(l.cardId, _Acc.new);
    acc.total++;
    if (l.result == 'correct') acc.correct++;
    final ts = l.reviewedAt;
    if (acc.lastReviewMs == null || ts > acc.lastReviewMs!) {
      acc.lastReviewMs = ts;
    }
  }
  return byCard.map(
    (k, v) => MapEntry(
      k,
      CardStats(
        correct: v.correct,
        total: v.total,
        lastReviewMs: v.lastReviewMs,
      ),
    ),
  );
});

class _Acc {
  int correct = 0;
  int total = 0;
  int? lastReviewMs;
}

String formatRelativeTime(int? ms, {DateTime? now}) {
  if (ms == null) return '';
  final n = now ?? DateTime.now();
  final past = DateTime.fromMillisecondsSinceEpoch(ms);
  final diff = n.difference(past);
  if (diff.inMinutes < 1) return 'ahora';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
  if (diff.inHours < 24) return 'hace ${diff.inHours}h';
  if (diff.inDays < 7) return 'hace ${diff.inDays}d';
  if (diff.inDays < 30) return 'hace ${(diff.inDays / 7).round()}sem';
  return 'hace ${(diff.inDays / 30).round()}m';
}
