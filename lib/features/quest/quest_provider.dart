import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';

class DailyQuest {
  final int target;
  final int completed;
  final int completedCorrect;
  final bool isComplete;
  final int streakDays;
  final int dueNow;

  const DailyQuest({
    required this.target,
    required this.completed,
    required this.completedCorrect,
    required this.isComplete,
    required this.streakDays,
    required this.dueNow,
  });

  double get progress =>
      target == 0 ? 0 : (completed / target).clamp(0.0, 1.0);

  int get remaining => (target - completed).clamp(0, target);

  factory DailyQuest.fromJson(Map<String, dynamic> j) => DailyQuest(
        target: (j['target'] as num).toInt(),
        completed: (j['completed'] as num).toInt(),
        completedCorrect: (j['completed_correct'] as num).toInt(),
        isComplete: j['is_complete'] as bool,
        streakDays: (j['streak_days'] as num).toInt(),
        dueNow: (j['due_now'] as num).toInt(),
      );
}

final dailyQuestProvider = FutureProvider<DailyQuest>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final res = await api.get('/quest/today', query: {'target': '10'});
    return DailyQuest.fromJson(res as Map<String, dynamic>);
  } catch (_) {
    return const DailyQuest(
      target: 10,
      completed: 0,
      completedCorrect: 0,
      isComplete: false,
      streakDays: 0,
      dueNow: 0,
    );
  }
});
