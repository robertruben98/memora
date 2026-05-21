import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/services/dgt_goal_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue #189 (dgt-ux): tests del servicio de notif al alcanzar meta
/// diaria. Cubre:
/// - Decision pura `dgtShouldFireGoalNotification` (toggle off, meta no
///   cumplida, idempotencia por dia).
/// - Copy `dgtGoalAchievedBody` (streak + dias a examen).
/// - Servicio: idempotencia real con SharedPreferences mockeadas. NO
///   verifica el `plugin.show` (skip en plataforma no soportada de test).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('dgtShouldFireGoalNotification (pura)', () {
    test('toggle OFF -> false aunque meta cumplida', () {
      expect(
        dgtShouldFireGoalNotification(
          enabled: false,
          answeredToday: 30,
          dailyGoal: 20,
          alreadyFiredToday: false,
        ),
        isFalse,
      );
    });

    test('meta no cumplida -> false', () {
      expect(
        dgtShouldFireGoalNotification(
          enabled: true,
          answeredToday: 5,
          dailyGoal: 20,
          alreadyFiredToday: false,
        ),
        isFalse,
      );
    });

    test('meta justo igual al goal -> dispara', () {
      expect(
        dgtShouldFireGoalNotification(
          enabled: true,
          answeredToday: 20,
          dailyGoal: 20,
          alreadyFiredToday: false,
        ),
        isTrue,
      );
    });

    test('meta superada -> dispara', () {
      expect(
        dgtShouldFireGoalNotification(
          enabled: true,
          answeredToday: 25,
          dailyGoal: 20,
          alreadyFiredToday: false,
        ),
        isTrue,
      );
    });

    test('ya disparada hoy -> false (idempotencia)', () {
      expect(
        dgtShouldFireGoalNotification(
          enabled: true,
          answeredToday: 25,
          dailyGoal: 20,
          alreadyFiredToday: true,
        ),
        isFalse,
      );
    });

    test('goal <= 0 -> false (config invalida)', () {
      expect(
        dgtShouldFireGoalNotification(
          enabled: true,
          answeredToday: 5,
          dailyGoal: 0,
          alreadyFiredToday: false,
        ),
        isFalse,
      );
    });
  });

  group('dgtGoalNotifiedKey', () {
    test('formato YYYY-MM-DD', () {
      expect(
        dgtGoalNotifiedKey(DateTime(2026, 5, 21)),
        'dgt.goal_notified.2026-05-21',
      );
    });

    test('padding 0 en mes y dia', () {
      expect(
        dgtGoalNotifiedKey(DateTime(2026, 1, 5)),
        'dgt.goal_notified.2026-01-05',
      );
    });
  });

  group('dgtGoalAchievedBody (pura)', () {
    test('streak >= 7 + examen <7d -> menciona ultima semana', () {
      final body = dgtGoalAchievedBody(streak: 8, daysToExam: 3);
      expect(body, contains('8 dias'));
      expect(body, contains('Ultima semana'));
    });

    test('streak >= 7 + examen medio -> ritmo examen', () {
      final body = dgtGoalAchievedBody(streak: 10, daysToExam: 20);
      expect(body, contains('10 dias'));
      expect(body, contains('ritmo'));
    });

    test('streak >= 7 sin examen -> records', () {
      final body = dgtGoalAchievedBody(streak: 12, daysToExam: null);
      expect(body, contains('12 dias'));
      expect(body, contains('records'));
    });

    test('streak 3-6 + examen cercano -> menciona examen', () {
      final body = dgtGoalAchievedBody(streak: 4, daysToExam: 2);
      expect(body, contains('4 dias'));
      expect(body.toLowerCase(), contains('examen'));
    });

    test('streak 3-6 sin urgencia -> constancia', () {
      final body = dgtGoalAchievedBody(streak: 3, daysToExam: 60);
      expect(body, contains('Constancia'));
    });

    test('streak 1 sin examen -> copy generico', () {
      final body = dgtGoalAchievedBody(streak: 1, daysToExam: null);
      expect(body, contains('Meta diaria'));
    });

    test('streak 0 + examen <7d -> tono urgente', () {
      final body = dgtGoalAchievedBody(streak: 0, daysToExam: 5);
      expect(body.toLowerCase(), contains('ultima semana'));
    });
  });

  group('DgtGoalNotificationService.maybeFireGoalAchievedNotification',
      () {
    setUp(() {
      // Reset prefs entre tests.
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('toggle OFF -> no dispara y NO marca idempotencia', () async {
      // Servicio sin plugin real: como toggle es false el flujo termina
      // antes de tocar el plugin.
      final service = _stubService();
      final fired = await service.maybeFireGoalAchievedNotification(
        enabled: false,
        answeredToday: 30,
        dailyGoal: 20,
        streak: 5,
        now: DateTime(2026, 5, 21),
      );
      expect(fired, isFalse);
      final prefs = await SharedPreferences.getInstance();
      // No marcamos cuando toggle es OFF: el usuario podria activarlo
      // mas tarde el mismo dia y aun querer la notif.
      expect(
        prefs.getBool(dgtGoalNotifiedKey(DateTime(2026, 5, 21))),
        isNull,
      );
    });

    test('meta no cumplida -> no dispara, no marca', () async {
      final service = _stubService();
      final fired = await service.maybeFireGoalAchievedNotification(
        enabled: true,
        answeredToday: 5,
        dailyGoal: 20,
        streak: 1,
        now: DateTime(2026, 5, 21),
      );
      expect(fired, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(dgtGoalNotifiedKey(DateTime(2026, 5, 21))),
        isNull,
      );
    });

    test('meta cumplida -> marca idempotencia (fire es best-effort)',
        () async {
      final service = _stubService();
      await service.maybeFireGoalAchievedNotification(
        enabled: true,
        answeredToday: 20,
        dailyGoal: 20,
        streak: 1,
        now: DateTime(2026, 5, 21),
      );
      final prefs = await SharedPreferences.getInstance();
      // Idempotencia se marca aunque el plugin no este en plataforma.
      expect(
        prefs.getBool(dgtGoalNotifiedKey(DateTime(2026, 5, 21))),
        isTrue,
      );
    });

    test('idempotencia: 3 answers consecutivos donde el segundo cruza '
        'umbral -> exactamente 1 marca', () async {
      final service = _stubService();
      final today = DateTime(2026, 5, 21);
      // Answer 1: answered=19 (no cruza)
      await service.maybeFireGoalAchievedNotification(
        enabled: true,
        answeredToday: 19,
        dailyGoal: 20,
        streak: 1,
        now: today,
      );
      // Answer 2: answered=20 (cruza umbral)
      await service.maybeFireGoalAchievedNotification(
        enabled: true,
        answeredToday: 20,
        dailyGoal: 20,
        streak: 1,
        now: today,
      );
      // Answer 3: answered=21 (sigue cumpliendo, idempotente)
      await service.maybeFireGoalAchievedNotification(
        enabled: true,
        answeredToday: 21,
        dailyGoal: 20,
        streak: 1,
        now: today,
      );
      final prefs = await SharedPreferences.getInstance();
      // Solo una marca para la fecha.
      expect(
        prefs.getBool(dgtGoalNotifiedKey(today)),
        isTrue,
      );
      // Total de keys con prefijo de hoy = 1 (no se duplica).
      final keys = prefs.getKeys().where(
            (k) => k.startsWith(kDgtGoalNotifiedPrefix),
          );
      expect(keys.length, 1);
    });

    test('dia siguiente -> nueva marca (no comparte estado)', () async {
      final service = _stubService();
      final d1 = DateTime(2026, 5, 21);
      final d2 = DateTime(2026, 5, 22);
      await service.maybeFireGoalAchievedNotification(
        enabled: true,
        answeredToday: 20,
        dailyGoal: 20,
        streak: 1,
        now: d1,
      );
      await service.maybeFireGoalAchievedNotification(
        enabled: true,
        answeredToday: 20,
        dailyGoal: 20,
        streak: 2,
        now: d2,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(dgtGoalNotifiedKey(d1)), isTrue);
      expect(prefs.getBool(dgtGoalNotifiedKey(d2)), isTrue);
      final keys = prefs.getKeys().where(
            (k) => k.startsWith(kDgtGoalNotifiedPrefix),
          );
      expect(keys.length, 2);
    });

    test('resetForDate borra la marca', () async {
      final service = _stubService();
      final today = DateTime(2026, 5, 21);
      await service.maybeFireGoalAchievedNotification(
        enabled: true,
        answeredToday: 20,
        dailyGoal: 20,
        streak: 1,
        now: today,
      );
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(dgtGoalNotifiedKey(today)), isTrue);
      await service.resetForDate(today);
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(dgtGoalNotifiedKey(today)), isNull);
    });
  });
}

/// Helper: instancia el servicio con plugin real sin inicializar. En el
/// entorno de test, `_isSupported` retorna false porque no hay Platform
/// channels: el flujo NUNCA invoca `plugin.show`. Lo que verificamos es
/// la marca de idempotencia (que ocurre ANTES de la decision de
/// plataforma).
DgtGoalNotificationService _stubService() {
  return DgtGoalNotificationService(FlutterLocalNotificationsPlugin());
}
