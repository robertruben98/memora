import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'dgt_reminder_service.dart';

/// Issue #174 (dgt-ux): scheduler de notificacion local SEMANAL.
///
/// Diseno reusa la infra del recordatorio diario (issue #102):
/// - mismo plugin `FlutterLocalNotificationsPlugin` (init en main.dart).
/// - distinta `kDgtWeeklyReportNotifId` y canal Android para evitar
///   pisar el daily.
/// - distinto payload [kDgtWeeklyReportDeeplink] -> abre la pantalla
///   `DgtWeeklyReportScreen`.
///
/// Periodicidad: domingo 20:00 hora local. Plugin no expone "weekly cron"
/// nativo: usamos `zonedSchedule` con `matchDateTimeComponents:
/// dayOfWeekAndTime`, que es la forma soportada de repetir semanalmente.

/// Payload para distinguir el tap. main.dart lo lee y navega al screen.
const String kDgtWeeklyReportDeeplink = 'dgt_weekly_report';

/// Keys SharedPreferences (issue #174). Toggle on/off. Default ON.
const String kDgtWeeklyReportEnabledKey = 'dgt_weekly_report_enabled';

/// ID fijo para la notificacion semanal. Distinto del diario (1102) para
/// no pisarlo. 1174 = anio (no), simplemente "issue 174".
const int kDgtWeeklyReportNotifId = 1174;
const String kDgtWeeklyReportChannelId = 'dgt_weekly_report';
const String kDgtWeeklyReportChannelName = 'Resumen semanal DGT';
const String kDgtWeeklyReportChannelDesc =
    'Aviso semanal (domingo 20:00) con tu resumen de progreso DGT.';

/// Domingo 20:00 fijo segun el criterio del issue. Se exponen por si en
/// el futuro se quiere config (mantenerlas const evita drift).
const int kDgtWeeklyReportWeekday = DateTime.sunday;
const int kDgtWeeklyReportHour = 20;
const int kDgtWeeklyReportMinute = 0;

/// Servicio thin para programar / cancelar la notificacion semanal.
/// Comparte el plugin con `DgtReminderService` (mismo singleton inyectado
/// via `flutterLocalNotificationsPluginProvider`).
class DgtWeeklyReportScheduler {
  DgtWeeklyReportScheduler(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  bool _channelCreated = false;

  /// Plataformas soportadas: Android / iOS. Resto: noop.
  bool get _isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Crea el canal Android la primera vez. Idempotente. Asume que el
  /// plugin ya fue inicializado por `DgtReminderService.init`.
  Future<void> _ensureChannel() async {
    if (!_isSupported) return;
    if (_channelCreated) return;
    if (!Platform.isAndroid) {
      _channelCreated = true;
      return;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        kDgtWeeklyReportChannelId,
        kDgtWeeklyReportChannelName,
        description: kDgtWeeklyReportChannelDesc,
        importance: Importance.high,
      ),
    );
    _channelCreated = true;
  }

  /// Lee el flag enabled. Default ON (criterio issue #174).
  Future<bool> loadEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kDgtWeeklyReportEnabledKey) ?? true;
  }

  /// Persiste el flag enabled.
  Future<void> saveEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kDgtWeeklyReportEnabledKey, enabled);
  }

  /// Cancela la notificacion semanal (no toca la diaria).
  Future<void> cancel() async {
    if (!_isSupported) return;
    try {
      await _plugin.cancel(kDgtWeeklyReportNotifId);
    } catch (_) {
      // ignore
    }
  }

  /// Reaplica el estado actual: si enabled -> reprograma, si no -> cancela.
  /// Reusa el permiso ya concedido al daily (no vuelve a pedir).
  Future<void> reschedule({bool? enabled}) async {
    if (!_isSupported) return;
    final on = enabled ?? await loadEnabled();
    await cancel();
    if (!on) return;
    await _ensureChannel();

    final scheduled = nextSundayAt(
      hour: kDgtWeeklyReportHour,
      minute: kDgtWeeklyReportMinute,
      now: tz.TZDateTime.now(tz.local),
    );

    const androidDetails = AndroidNotificationDetails(
      kDgtWeeklyReportChannelId,
      kDgtWeeklyReportChannelName,
      channelDescription: kDgtWeeklyReportChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'DGT',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Alarma inexacta: no requiere SCHEDULE_EXACT_ALARM (politica Play).
    // El sistema puede agrupar el aviso, pero para un recordatorio semanal
    // unos minutos de holgura son aceptables.
    await _plugin.zonedSchedule(
      kDgtWeeklyReportNotifId,
      'Memora DGT - resumen semanal',
      'Toca para ver tu progreso de la semana.',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: kDgtWeeklyReportDeeplink,
    );
  }
}

/// Calcula el proximo `DateTime.sunday` con la hora/minuto dados. Si hoy
/// es domingo y aun no paso la hora, retorna HOY a esa hora; si ya paso,
/// retorna el domingo siguiente. PURA: testable con `tz.TZDateTime` o
/// equivalente que implemente `weekday`/`isAfter`/aritmetica de dias.
tz.TZDateTime nextSundayAt({
  required int hour,
  required int minute,
  required tz.TZDateTime now,
}) {
  // weekday: lunes=1..domingo=7.
  final daysUntilSunday = (kDgtWeeklyReportWeekday - now.weekday) % 7;
  tz.TZDateTime candidate = tz.TZDateTime(
    tz.local,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  ).add(Duration(days: daysUntilSunday));
  if (!candidate.isAfter(now)) {
    candidate = candidate.add(const Duration(days: 7));
  }
  return candidate;
}

/// Provider del scheduler. Reusa el plugin singleton (issue #102).
final dgtWeeklyReportSchedulerProvider = Provider<DgtWeeklyReportScheduler>((
  ref,
) {
  return DgtWeeklyReportScheduler(
    ref.watch(flutterLocalNotificationsPluginProvider),
  );
});

/// Flag enabled persistido. UI lo observa para mostrar el toggle.
final dgtWeeklyReportEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(dgtWeeklyReportSchedulerProvider).loadEnabled();
});
