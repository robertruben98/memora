import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';

/// Tipo de permiso de conduccion DGT.
enum DgtLicenseType {
  b('B', 'Coche', 'Permiso B - turismos'),
  a('A', 'Moto', 'Permiso A - motocicletas'),
  c('C', 'Camion', 'Permiso C - camiones'),
  d('D', 'Autobus', 'Permiso D - autobuses');

  final String code;
  final String shortLabel;
  final String description;
  const DgtLicenseType(this.code, this.shortLabel, this.description);

  static DgtLicenseType fromCode(String? code) {
    if (code == null) return DgtLicenseType.b;
    return DgtLicenseType.values.firstWhere(
      (t) => t.code == code,
      orElse: () => DgtLicenseType.b,
    );
  }
}

/// Estado inmutable de los ajustes DGT.
class DgtSettings {
  final DgtLicenseType licenseType;
  final DateTime? examDate;
  final int dailyGoal;
  // DGT issue #42: mostrar modal explicativo al fallar una card.
  // Aditivo, opcional, default ON. No rompe llamadas existentes.
  final bool showExplanationOnFail;

  const DgtSettings({
    required this.licenseType,
    required this.examDate,
    required this.dailyGoal,
    this.showExplanationOnFail = true,
  });

  static const DgtSettings defaults = DgtSettings(
    licenseType: DgtLicenseType.b,
    examDate: null,
    dailyGoal: 20,
    showExplanationOnFail: true,
  );

  DgtSettings copyWith({
    DgtLicenseType? licenseType,
    DateTime? examDate,
    bool clearExamDate = false,
    int? dailyGoal,
    bool? showExplanationOnFail,
  }) {
    return DgtSettings(
      licenseType: licenseType ?? this.licenseType,
      examDate: clearExamDate ? null : (examDate ?? this.examDate),
      dailyGoal: dailyGoal ?? this.dailyGoal,
      showExplanationOnFail:
          showExplanationOnFail ?? this.showExplanationOnFail,
    );
  }

  /// Dias restantes hasta el examen (negativo si ya paso).
  int? get daysUntilExam {
    if (examDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exam = DateTime(examDate!.year, examDate!.month, examDate!.day);
    return exam.difference(today).inDays;
  }
}

const kDgtLicenseTypeKey = 'dgt_license_type';
const kDgtExamDateKey = 'dgt_exam_date';
const kDgtDailyGoalKey = 'dgt_daily_goal';
const kDgtOnboardedKey = 'dgt_onboarded';
const kDgtShowExplanationOnFailKey = 'dgt_show_explanation_on_fail';

/// Repositorio: lee/escribe ajustes DGT en settingsDao.
class DgtSettingsRepository {
  final MemoraDatabase _db;
  DgtSettingsRepository(this._db);

  Future<DgtSettings> load() async {
    final license = await _db.settingsDao.getValue(kDgtLicenseTypeKey);
    final exam = await _db.settingsDao.getValue(kDgtExamDateKey);
    final goal = await _db.settingsDao.getValue(kDgtDailyGoalKey);
    final showExp =
        await _db.settingsDao.getValue(kDgtShowExplanationOnFailKey);
    return DgtSettings(
      licenseType: DgtLicenseType.fromCode(license),
      examDate: (exam == null || exam.isEmpty) ? null : DateTime.tryParse(exam),
      dailyGoal: int.tryParse(goal ?? '') ?? DgtSettings.defaults.dailyGoal,
      // Si el valor no existe (instalaciones previas al issue #42),
      // mantenemos el default ON.
      showExplanationOnFail: showExp == null
          ? DgtSettings.defaults.showExplanationOnFail
          : showExp == '1',
    );
  }

  Future<void> save(DgtSettings s) async {
    await _db.settingsDao.setValue(kDgtLicenseTypeKey, s.licenseType.code);
    if (s.examDate != null) {
      await _db.settingsDao.setValue(
        kDgtExamDateKey,
        s.examDate!.toIso8601String(),
      );
    } else {
      await _db.settingsDao.deleteValue(kDgtExamDateKey);
    }
    await _db.settingsDao.setValue(kDgtDailyGoalKey, s.dailyGoal.toString());
    await _db.settingsDao.setValue(kDgtOnboardedKey, '1');
    await _db.settingsDao.setValue(
      kDgtShowExplanationOnFailKey,
      s.showExplanationOnFail ? '1' : '0',
    );
  }
}

final dgtSettingsRepositoryProvider = Provider<DgtSettingsRepository>((ref) {
  return DgtSettingsRepository(ref.watch(databaseProvider));
});

/// Provider asincrono que carga los ajustes DGT desde la BBDD.
final dgtSettingsProvider = FutureProvider<DgtSettings>((ref) async {
  return ref.watch(dgtSettingsRepositoryProvider).load();
});
