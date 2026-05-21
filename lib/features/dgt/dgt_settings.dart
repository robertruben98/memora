import 'package:flutter/material.dart';
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

/// Issue #169 (dgt-ux): frecuencia con la que el recordatorio de racha
/// avisa al estudiante.
///
/// - [daily]: aviso diario (compatible con flujo issue #102).
/// - [onlyIfBroken]: solo si rompi racha (no estudie ayer).
/// - [never]: nunca enviar recordatorio de racha (silencio total).
enum DgtStreakReminderMode {
  daily('daily', 'Diario', 'Aviso todos los dias para mantener la racha'),
  onlyIfBroken(
    'only_if_broken',
    'Solo si rompo racha',
    'Avisa unicamente cuando hayas perdido la racha',
  ),
  never('never', 'Nunca', 'Sin recordatorio de racha');

  final String code;
  final String label;
  final String description;
  const DgtStreakReminderMode(this.code, this.label, this.description);

  static DgtStreakReminderMode fromCode(String? code) {
    if (code == null) return DgtStreakReminderMode.daily;
    return DgtStreakReminderMode.values.firstWhere(
      (m) => m.code == code,
      orElse: () => DgtStreakReminderMode.daily,
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
  // DGT issue #153: mostrar tutorial pre-quiz por subtopic.
  // Aditivo, opcional, default ON. Toggle global complementario al
  // "no mostrar mas" por-topic en SharedPreferences.
  final bool showSubtopicTutorial;

  // Issue #169 (dgt-ux): pantalla Ajustes DGT dedicada.
  // Aditivo, defaults preservan comportamiento previo.

  /// Dias de la semana activos para el recordatorio (ISO: 1=Lun..7=Dom).
  /// Default: todos los dias.
  final List<int> reminderDays;

  /// Modo de recordatorio de racha. Default: diario.
  final DgtStreakReminderMode streakReminderMode;

  /// Modo simulacro estricto: sin pausa, sin revision intermedia, sin volver
  /// atras. Default: OFF (modo libre).
  final bool strictExamMode;

  /// Mostrar tile predictor de aprobacion en home. Default: ON.
  final bool showPredictions;

  /// Issue #189 (dgt-ux): notificar al alcanzar la meta diaria de
  /// preguntas DGT. Idempotente por dia (un disparo / fecha).
  /// Default: ON (refuerzo positivo es opt-out, no opt-in).
  final bool goalNotifEnabled;

  const DgtSettings({
    required this.licenseType,
    required this.examDate,
    required this.dailyGoal,
    this.showExplanationOnFail = true,
    this.showSubtopicTutorial = true,
    this.reminderDays = const [1, 2, 3, 4, 5, 6, 7],
    this.streakReminderMode = DgtStreakReminderMode.daily,
    this.strictExamMode = false,
    this.showPredictions = true,
    this.goalNotifEnabled = true,
  });

  static const DgtSettings defaults = DgtSettings(
    licenseType: DgtLicenseType.b,
    examDate: null,
    dailyGoal: 20,
    showExplanationOnFail: true,
    showSubtopicTutorial: true,
    reminderDays: [1, 2, 3, 4, 5, 6, 7],
    streakReminderMode: DgtStreakReminderMode.daily,
    strictExamMode: false,
    showPredictions: true,
    goalNotifEnabled: true,
  );

  DgtSettings copyWith({
    DgtLicenseType? licenseType,
    DateTime? examDate,
    bool clearExamDate = false,
    int? dailyGoal,
    bool? showExplanationOnFail,
    bool? showSubtopicTutorial,
    List<int>? reminderDays,
    DgtStreakReminderMode? streakReminderMode,
    bool? strictExamMode,
    bool? showPredictions,
    bool? goalNotifEnabled,
  }) {
    return DgtSettings(
      licenseType: licenseType ?? this.licenseType,
      examDate: clearExamDate ? null : (examDate ?? this.examDate),
      dailyGoal: dailyGoal ?? this.dailyGoal,
      showExplanationOnFail:
          showExplanationOnFail ?? this.showExplanationOnFail,
      showSubtopicTutorial:
          showSubtopicTutorial ?? this.showSubtopicTutorial,
      reminderDays: reminderDays ?? this.reminderDays,
      streakReminderMode: streakReminderMode ?? this.streakReminderMode,
      strictExamMode: strictExamMode ?? this.strictExamMode,
      showPredictions: showPredictions ?? this.showPredictions,
      goalNotifEnabled: goalNotifEnabled ?? this.goalNotifEnabled,
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
const kDgtShowSubtopicTutorialKey = 'dgt_show_subtopic_tutorial';
// Issue #169 keys.
const kDgtReminderDaysKey = 'dgt_reminder_days';
const kDgtStreakReminderModeKey = 'dgt_streak_reminder_mode';
const kDgtStrictExamModeKey = 'dgt_strict_exam_mode';
const kDgtShowPredictionsKey = 'dgt_show_predictions';
// Issue #189 key.
const kDgtGoalNotifEnabledKey = 'dgt_goal_notif_enabled';

/// Repositorio: lee/escribe ajustes DGT en settingsDao.
class DgtSettingsRepository {
  final MemoraDatabase _db;
  DgtSettingsRepository(this._db);

  Future<DgtSettings> load() async {
    final license = await _db.settingsDao.getValue(kDgtLicenseTypeKey);
    final exam = await _db.settingsDao.getValue(kDgtExamDateKey);
    final goal = await _db.settingsDao.getValue(kDgtDailyGoalKey);
    final showExp = await _db.settingsDao.getValue(
      kDgtShowExplanationOnFailKey,
    );
    final showTut = await _db.settingsDao.getValue(
      kDgtShowSubtopicTutorialKey,
    );
    // Issue #169: nuevos campos (defaults para instalaciones previas).
    final daysRaw = await _db.settingsDao.getValue(kDgtReminderDaysKey);
    final streakMode = await _db.settingsDao.getValue(
      kDgtStreakReminderModeKey,
    );
    final strict = await _db.settingsDao.getValue(kDgtStrictExamModeKey);
    final showPred = await _db.settingsDao.getValue(kDgtShowPredictionsKey);
    // Issue #189: default ON para instalaciones previas.
    final goalNotif = await _db.settingsDao.getValue(kDgtGoalNotifEnabledKey);
    return DgtSettings(
      licenseType: DgtLicenseType.fromCode(license),
      examDate: (exam == null || exam.isEmpty) ? null : DateTime.tryParse(exam),
      dailyGoal: int.tryParse(goal ?? '') ?? DgtSettings.defaults.dailyGoal,
      // Si el valor no existe (instalaciones previas al issue #42),
      // mantenemos el default ON.
      showExplanationOnFail: showExp == null
          ? DgtSettings.defaults.showExplanationOnFail
          : showExp == '1',
      // Issue #153: instalaciones previas no tienen el flag -> default ON.
      showSubtopicTutorial: showTut == null
          ? DgtSettings.defaults.showSubtopicTutorial
          : showTut == '1',
      reminderDays: _parseReminderDays(daysRaw),
      streakReminderMode: DgtStreakReminderMode.fromCode(streakMode),
      strictExamMode: strict == '1',
      showPredictions: showPred == null
          ? DgtSettings.defaults.showPredictions
          : showPred == '1',
      goalNotifEnabled: goalNotif == null
          ? DgtSettings.defaults.goalNotifEnabled
          : goalNotif == '1',
    );
  }

  /// Parsea CSV "1,2,3" en `List` de enteros. Default todos los dias.
  static List<int> _parseReminderDays(String? raw) {
    if (raw == null || raw.isEmpty) {
      return DgtSettings.defaults.reminderDays;
    }
    final parts = raw.split(',');
    final out = <int>[];
    for (final p in parts) {
      final n = int.tryParse(p.trim());
      if (n != null && n >= 1 && n <= 7 && !out.contains(n)) {
        out.add(n);
      }
    }
    if (out.isEmpty) return DgtSettings.defaults.reminderDays;
    out.sort();
    return out;
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
    await _db.settingsDao.setValue(
      kDgtShowSubtopicTutorialKey,
      s.showSubtopicTutorial ? '1' : '0',
    );
    // Issue #169.
    await _db.settingsDao.setValue(
      kDgtReminderDaysKey,
      s.reminderDays.join(','),
    );
    await _db.settingsDao.setValue(
      kDgtStreakReminderModeKey,
      s.streakReminderMode.code,
    );
    await _db.settingsDao.setValue(
      kDgtStrictExamModeKey,
      s.strictExamMode ? '1' : '0',
    );
    await _db.settingsDao.setValue(
      kDgtShowPredictionsKey,
      s.showPredictions ? '1' : '0',
    );
    // Issue #189.
    await _db.settingsDao.setValue(
      kDgtGoalNotifEnabledKey,
      s.goalNotifEnabled ? '1' : '0',
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

/// Issue #54: color del banner DGT segun proximidad al examen.
/// verde >30d, ambar 7-30d, rojo <7d, azul (default) si null o pasado.
/// Aditivo, helper puro sin estado.
Color dgtBannerAccentColor(int? daysUntilExam) {
  if (daysUntilExam == null) return const Color(0xFF4F8AFF);
  if (daysUntilExam < 0) return const Color(0xFF4F8AFF);
  if (daysUntilExam < 7) return const Color(0xFFFF5C5C);
  if (daysUntilExam <= 30) return const Color(0xFFFFB74F);
  return const Color(0xFF4FFFB0);
}

/// Issue #79 (dgt-ux): mensaje motivacional contextual segun urgencia
/// (dias hasta examen) cruzado con progreso real (expectedScore).
///
/// Devuelve null cuando NO debe mostrarse:
/// - sin examen fijado (`days == null`)
/// - examen ya pasado (`days < 0`)
/// - sin prediccion disponible (`expectedScore == null`)
///
/// Matriz:
///   <7d & score<0.90  -> "Quedan pocos dias y no llegas - dale ya!"
///   <7d & score>=0.90 -> "A punto! Ultima semana, manten el ritmo"
///   7-30d & score<0.90  -> "Tienes margen pero hay que acelerar"
///   7-30d & score>=0.90 -> "Vas bien, sigue asi"
///   >30d (cualquier score) -> "Calma, hay tiempo de sobra"
///
/// Funcion PURA, sin estado, sin IO. Testeada en
/// test/features/dgt/dgt_motivation_test.dart.
String? dgtMotivationMessage(int? days, double? expectedScore) {
  if (days == null) return null;
  if (days < 0) return null;
  if (expectedScore == null) return null;
  const threshold = 0.90;
  if (days > 30) return 'Calma, hay tiempo de sobra';
  if (days < 7) {
    return expectedScore >= threshold
        ? 'A punto! Ultima semana, manten el ritmo'
        : 'Quedan pocos dias y no llegas - dale ya!';
  }
  // 7..30 inclusive
  return expectedScore >= threshold
      ? 'Vas bien, sigue asi'
      : 'Tienes margen pero hay que acelerar';
}
