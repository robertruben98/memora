import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/srs/study_settings.dart';
import '../../core/theme/theme_provider.dart';
import '../../data/database/database.dart';
import '../../data/sync/sync_service.dart';

class SettingsRepository {
  final MemoraDatabase _db;
  final SyncService _sync;

  SettingsRepository(this._db, this._sync);

  static const _kNewCardsPerDay = 'new_cards_per_day';
  static const _kMaxReviewsPerDay = 'max_reviews_per_day';
  static const _kThemeMode = 'theme_mode';

  Future<StudySettings> loadStudySettings() async {
    final n = await _db.settingsDao.getValue(_kNewCardsPerDay);
    final m = await _db.settingsDao.getValue(_kMaxReviewsPerDay);
    return StudySettings(
      newCardsPerDay:
          int.tryParse(n ?? '') ?? StudySettings.defaults.newCardsPerDay,
      maxReviewsPerDay:
          int.tryParse(m ?? '') ?? StudySettings.defaults.maxReviewsPerDay,
    );
  }

  Future<void> saveStudySettings(StudySettings s) async {
    await _sync.putSetting(_kNewCardsPerDay, s.newCardsPerDay.toString());
    await _sync.putSetting(_kMaxReviewsPerDay, s.maxReviewsPerDay.toString());
    await _db.settingsDao
        .setValue(_kNewCardsPerDay, s.newCardsPerDay.toString());
    await _db.settingsDao
        .setValue(_kMaxReviewsPerDay, s.maxReviewsPerDay.toString());
  }

  Future<ThemeMode> loadThemeMode() async {
    final v = await _db.settingsDao.getValue(_kThemeMode);
    return themeModeFromString(v);
  }

  Future<void> saveThemeMode(ThemeMode m) async {
    final v = themeModeToString(m);
    await _sync.putSetting(_kThemeMode, v);
    await _db.settingsDao.setValue(_kThemeMode, v);
  }

  /// Borra todos los `card_schedules` y `review_logs`. Las tarjetas quedan.
  Future<void> resetSrsProgress() async {
    await _db.scheduleDao.deleteAll();
    await _db.reviewLogDao.deleteAll();
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(
    ref.watch(databaseProvider),
    ref.watch(syncServiceProvider),
  );
});
