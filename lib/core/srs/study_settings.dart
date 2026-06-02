import 'package:flutter_riverpod/flutter_riverpod.dart';

class StudySettings {
  final int newCardsPerDay;
  final int maxReviewsPerDay;

  const StudySettings({
    required this.newCardsPerDay,
    required this.maxReviewsPerDay,
  })  : assert(
          newCardsPerDay >= 0 && newCardsPerDay <= 100,
          'newCardsPerDay must be between 0 and 100',
        ),
        assert(
          maxReviewsPerDay >= 0 && maxReviewsPerDay <= 300,
          'maxReviewsPerDay must be between 0 and 300',
        );

  static const defaults = StudySettings(
    newCardsPerDay: 10,
    maxReviewsPerDay: 50,
  );

  StudySettings copyWith({
    int? newCardsPerDay,
    int? maxReviewsPerDay,
  }) {
    return StudySettings(
      newCardsPerDay: newCardsPerDay ?? this.newCardsPerDay,
      maxReviewsPerDay: maxReviewsPerDay ?? this.maxReviewsPerDay,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StudySettings &&
        other.newCardsPerDay == newCardsPerDay &&
        other.maxReviewsPerDay == maxReviewsPerDay;
  }

  @override
  int get hashCode => Object.hash(newCardsPerDay, maxReviewsPerDay);
}

final studySettingsProvider =
    StateProvider<StudySettings>((ref) => StudySettings.defaults);
