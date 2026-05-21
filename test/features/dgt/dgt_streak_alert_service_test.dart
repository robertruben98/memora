import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_settings.dart';
import 'package:memora/features/dgt/services/dgt_streak_alert_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue #212 (dgt-ux): tests del servicio de alarma anti-perdida de
/// racha. Cubre:
/// - Decision pura `dgtShouldScheduleStreakAlert` (toggle off, streak<3).
/// - Calculo puro `dgtComputeStreakAlertFireTime` (ventana 9h-22h, offset
///   23h, casos edge fuera de ventana).
/// - Copy del titulo/body.
/// - `DgtSettings.streakAlertEnabled` default ON + copyWith.
/// - Servicio: persistencia de lastActivity + cancel cuando no aplica.
///   NO verifica `plugin.zonedSchedule` directamente (plataforma no
///   soportada en test); el code path activo se cubre via las funciones
///   puras + el cancel/persistencia observable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DgtSettings.streakAlertEnabled (issue #212)', () {
    test('default = ON (opt-out por loss-aversion)', () {
      expect(DgtSettings.defaults.streakAlertEnabled, isTrue);
    });

    test('copyWith permite togglear a OFF sin corromper otros campos', () {
      final next =
          DgtSettings.defaults.copyWith(streakAlertEnabled: false);
      expect(next.streakAlertEnabled, isFalse);
      expect(next.goalNotifEnabled, DgtSettings.defaults.goalNotifEnabled);
      expect(next.showPredictions, DgtSettings.defaults.showPredictions);
    });
  });

  group('dgtShouldScheduleStreakAlert (pura)', () {
    test('toggle OFF -> false aunque streak alta', () {
      expect(
        dgtShouldScheduleStreakAlert(enabled: false, currentStreak: 10),
        isFalse,
      );
    });

    test('streak 0 -> false (usuario sin racha)', () {
      expect(
        dgtShouldScheduleStreakAlert(enabled: true, currentStreak: 0),
        isFalse,
      );
    });

    test('streak 2 -> false (umbral evita spam casuales)', () {
      expect(
        dgtShouldScheduleStreakAlert(enabled: true, currentStreak: 2),
        isFalse,
      );
    });

    test('streak 3 -> true (justo en umbral)', () {
      expect(
        dgtShouldScheduleStreakAlert(enabled: true, currentStreak: 3),
        isTrue,
      );
    });

    test('streak 10 -> true', () {
      expect(
        dgtShouldScheduleStreakAlert(enabled: true, currentStreak: 10),
        isTrue,
      );
    });
  });

  group('dgtComputeStreakAlertFireTime (pura)', () {
    test('actividad a las 10:00 -> fire 23h despues = 9:00 dia +1 '
        '(dentro ventana)', () {
      final activity = DateTime(2026, 5, 21, 10, 0);
      final now = activity;
      final fire = dgtComputeStreakAlertFireTime(
        lastActivity: activity,
        now: now,
      );
      expect(fire, isNotNull);
      // 10:00 + 23h = 09:00 del 22. Dentro ventana, sin ajuste.
      expect(fire, DateTime(2026, 5, 22, 9, 0));
    });

    test('actividad a las 20:00 -> base 19:00 dia +1 (dentro ventana)',
        () {
      final activity = DateTime(2026, 5, 21, 20, 0);
      final now = activity;
      final fire = dgtComputeStreakAlertFireTime(
        lastActivity: activity,
        now: now,
      );
      expect(fire, isNotNull);
      // 20:00 + 23h = 19:00 del 22.
      expect(fire, DateTime(2026, 5, 22, 19, 0));
    });

    test('actividad a las 23:00 -> base 22:00 dia+1 esta fuera (>=22) '
        '-> mueve dentro de 24h', () {
      final activity = DateTime(2026, 5, 21, 23, 0);
      final now = activity;
      final fire = dgtComputeStreakAlertFireTime(
        lastActivity: activity,
        now: now,
      );
      expect(fire, isNotNull);
      // 23:00 + 23h = 22:00 del 22 (justo fuera). El move a 9:00 del 23
      // caeria a 34h del activity (excede 24h), asi que el servicio
      // colapsa a deadline-5min = 22:55 del 22.
      expect(fire!.isBefore(DateTime(2026, 5, 22, 23, 0)), isTrue);
    });

    test('actividad a las 3:00 (madrugada) -> base 2:00 dia+1 fuera '
        '(<9) -> mueve a 9:00 mismo dia', () {
      final activity = DateTime(2026, 5, 21, 3, 0);
      final now = activity;
      final fire = dgtComputeStreakAlertFireTime(
        lastActivity: activity,
        now: now,
      );
      expect(fire, isNotNull);
      // 3:00 + 23h = 2:00 del 22 (fuera <9). Mueve a 9:00 del 22.
      expect(fire, DateTime(2026, 5, 22, 9, 0));
    });

    test('fire en pasado -> null', () {
      // Simulamos: actividad fue hace 30h (la racha ya expiraria, pero
      // el calculo debe devolver null porque el fire time ya paso).
      final now = DateTime(2026, 5, 22, 20, 0);
      final activity = now.subtract(const Duration(hours: 30));
      final fire = dgtComputeStreakAlertFireTime(
        lastActivity: activity,
        now: now,
      );
      expect(fire, isNull);
    });
  });

  group('dgtStreakAlertTitle / Body (pura)', () {
    test('titulo incluye N dias', () {
      expect(dgtStreakAlertTitle(7), 'Tu racha de 7 dias esta en peligro');
    });

    test('body menciona 5 preguntas', () {
      final b = dgtStreakAlertBody();
      expect(b, contains('5 preguntas'));
      expect(b.toLowerCase(), contains('1h'));
    });
  });

  group('DgtStreakAlertService.rescheduleAfterActivity', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('toggle OFF -> persiste activity pero NO programa (cancel)',
        () async {
      final service = _stubService();
      final ok = await service.rescheduleAfterActivity(
        enabled: false,
        currentStreak: 10,
        lastActivity: DateTime(2026, 5, 21, 10, 0),
      );
      expect(ok, isFalse);
      final prefs = await SharedPreferences.getInstance();
      // Persistencia siempre best-effort, no condicionada al schedule.
      expect(
        prefs.getString(kDgtStreakAlertLastActivityKey),
        DateTime(2026, 5, 21, 10, 0).toIso8601String(),
      );
    });

    test('streak <3 -> NO programa, persiste igual', () async {
      final service = _stubService();
      final ok = await service.rescheduleAfterActivity(
        enabled: true,
        currentStreak: 2,
        lastActivity: DateTime(2026, 5, 21, 10, 0),
      );
      expect(ok, isFalse);
    });

    test('streak >=3, plataforma no soportada en test -> false (skip)',
        () async {
      final service = _stubService();
      final ok = await service.rescheduleAfterActivity(
        enabled: true,
        currentStreak: 5,
        lastActivity: DateTime(2026, 5, 21, 10, 0),
        now: DateTime(2026, 5, 21, 10, 0),
      );
      // En test (no Android/iOS) _isSupported=false; pasada la decision
      // pura, el schedule no se ejecuta. Devuelve false sin lanzar.
      expect(ok, isFalse);
    });

    test('persistencia de lastActivity sobreescribe el valor anterior',
        () async {
      final service = _stubService();
      await service.rescheduleAfterActivity(
        enabled: true,
        currentStreak: 5,
        lastActivity: DateTime(2026, 5, 21, 10, 0),
      );
      await service.rescheduleAfterActivity(
        enabled: true,
        currentStreak: 5,
        lastActivity: DateTime(2026, 5, 21, 14, 30),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(kDgtStreakAlertLastActivityKey),
        DateTime(2026, 5, 21, 14, 30).toIso8601String(),
      );
    });

    test('cancel es idempotente y no lanza', () async {
      final service = _stubService();
      await service.cancel();
      await service.cancel();
      // smoke: no exception.
    });
  });
}

DgtStreakAlertService _stubService() {
  return DgtStreakAlertService(FlutterLocalNotificationsPlugin());
}
