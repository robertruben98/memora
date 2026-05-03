import 'package:flutter_riverpod/flutter_riverpod.dart';

class StudySettings {
  final int newCardsPerDay;
  final int maxReviewsPerDay;

  const StudySettings({
    required this.newCardsPerDay,
    required this.maxReviewsPerDay,
  });

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
}

final studySettingsProvider =
    StateProvider<StudySettings>((ref) => StudySettings.defaults);
