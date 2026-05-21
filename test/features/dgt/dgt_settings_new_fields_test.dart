import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_settings.dart';

/// Issue #169 (dgt-ux): cubre los campos nuevos de `DgtSettings`
/// (reminderDays, streakReminderMode, strictExamMode, showPredictions).
/// Tests puros, sin BBDD ni Flutter binding.
void main() {
  group('DgtSettings new fields (issue #169)', () {
    test('defaults: todos los dias activos, racha diaria, modo libre, '
        'predicciones ON', () {
      final d = DgtSettings.defaults;
      expect(d.reminderDays, [1, 2, 3, 4, 5, 6, 7]);
      expect(d.streakReminderMode, DgtStreakReminderMode.daily);
      expect(d.strictExamMode, isFalse);
      expect(d.showPredictions, isTrue);
    });

    test('copyWith preserva campos no especificados', () {
      final next = DgtSettings.defaults.copyWith(
        strictExamMode: true,
      );
      expect(next.strictExamMode, isTrue);
      expect(next.reminderDays, DgtSettings.defaults.reminderDays);
      expect(next.streakReminderMode, DgtSettings.defaults.streakReminderMode);
      expect(next.showPredictions, DgtSettings.defaults.showPredictions);
      expect(next.licenseType, DgtSettings.defaults.licenseType);
    });

    test('copyWith permite cambiar reminderDays (ej: solo L-V)', () {
      final next = DgtSettings.defaults.copyWith(reminderDays: [1, 2, 3, 4, 5]);
      expect(next.reminderDays, [1, 2, 3, 4, 5]);
    });

    test('copyWith permite cambiar streakReminderMode a never', () {
      final next = DgtSettings.defaults.copyWith(
        streakReminderMode: DgtStreakReminderMode.never,
      );
      expect(next.streakReminderMode, DgtStreakReminderMode.never);
    });

    test('copyWith permite togglear showPredictions a OFF', () {
      final next = DgtSettings.defaults.copyWith(showPredictions: false);
      expect(next.showPredictions, isFalse);
    });

    // Issue #189 (dgt-ux): toggle de notif al alcanzar meta diaria.
    test('default goalNotifEnabled = ON (opt-out)', () {
      expect(DgtSettings.defaults.goalNotifEnabled, isTrue);
    });

    test('copyWith permite togglear goalNotifEnabled a OFF', () {
      final next =
          DgtSettings.defaults.copyWith(goalNotifEnabled: false);
      expect(next.goalNotifEnabled, isFalse);
      // No corrompe el resto.
      expect(next.showPredictions, DgtSettings.defaults.showPredictions);
      expect(next.streakReminderMode, DgtSettings.defaults.streakReminderMode);
    });
  });

  group('DgtStreakReminderMode.fromCode', () {
    test('null devuelve daily (default)', () {
      expect(
        DgtStreakReminderMode.fromCode(null),
        DgtStreakReminderMode.daily,
      );
    });

    test('codigo desconocido devuelve daily (fallback seguro)', () {
      expect(
        DgtStreakReminderMode.fromCode('garbage'),
        DgtStreakReminderMode.daily,
      );
    });

    test('reconoce todos los codigos validos', () {
      expect(
        DgtStreakReminderMode.fromCode('daily'),
        DgtStreakReminderMode.daily,
      );
      expect(
        DgtStreakReminderMode.fromCode('only_if_broken'),
        DgtStreakReminderMode.onlyIfBroken,
      );
      expect(
        DgtStreakReminderMode.fromCode('never'),
        DgtStreakReminderMode.never,
      );
    });

    test('roundtrip code -> fromCode -> code es estable', () {
      for (final m in DgtStreakReminderMode.values) {
        expect(DgtStreakReminderMode.fromCode(m.code), m);
      }
    });
  });
}
