import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_weekly_report_scheduler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Issue #174 (dgt-ux): tests del calculo PURO `nextSundayAt`.
/// No toca el plugin de notificaciones; valida solo la aritmetica de
/// fechas que decide cuando disparar la notif semanal.
void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    // Fijamos una zona neutra para evitar dependencia del host.
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  group('nextSundayAt', () {
    test('si hoy es domingo y la hora aun no paso -> hoy a esa hora', () {
      // 2026-05-17 es domingo (DateTime(2026,5,17).weekday == 7).
      final now = tz.TZDateTime(tz.local, 2026, 5, 17, 10, 0);
      final next = nextSundayAt(hour: 20, minute: 0, now: now);
      expect(next.year, 2026);
      expect(next.month, 5);
      expect(next.day, 17);
      expect(next.hour, 20);
      expect(next.minute, 0);
    });

    test('si hoy es domingo y la hora ya paso -> domingo siguiente', () {
      final now = tz.TZDateTime(tz.local, 2026, 5, 17, 21, 30);
      final next = nextSundayAt(hour: 20, minute: 0, now: now);
      expect(next.day, 24); // domingo siguiente
      expect(next.hour, 20);
    });

    test('si hoy es lunes -> domingo de esta semana (proximo dia 6)', () {
      // 2026-05-18 lunes. Proximo domingo = 24.
      final now = tz.TZDateTime(tz.local, 2026, 5, 18, 12, 0);
      final next = nextSundayAt(hour: 20, minute: 0, now: now);
      expect(next.weekday, DateTime.sunday);
      expect(next.day, 24);
    });

    test('si hoy es sabado -> manana domingo', () {
      // 2026-05-16 sabado.
      final now = tz.TZDateTime(tz.local, 2026, 5, 16, 23, 0);
      final next = nextSundayAt(hour: 20, minute: 0, now: now);
      expect(next.weekday, DateTime.sunday);
      expect(next.day, 17);
    });

    test('always returns a TZDateTime strictly after now', () {
      // Aleatorios fijos para cubrir todos los weekdays.
      for (final d in [11, 12, 13, 14, 15, 16, 17]) {
        final now = tz.TZDateTime(tz.local, 2026, 5, d, 20, 0);
        // En el limite exacto, debe avanzar (no devolver "ahora").
        final next = nextSundayAt(hour: 20, minute: 0, now: now);
        expect(next.isAfter(now), isTrue,
            reason: 'falla con weekday ${now.weekday}');
        expect(next.weekday, DateTime.sunday);
      }
    });
  });
}
