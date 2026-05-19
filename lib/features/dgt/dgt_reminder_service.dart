import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Issue #102 (dgt-ux): servicio para programar/cancelar la notificacion
/// local diaria que recuerda al usuario su meta de estudio DGT.
///
/// Diseno:
/// - Singleton ligero detras de un provider Riverpod.
/// - Config persistida en SharedPreferences (no en DB) para evitar
///   migraciones y porque es estado puramente local del dispositivo.
/// - Skip silencioso en plataformas no soportadas (web/desktop): los
///   metodos retornan sin error pero no programan nada.
///
/// API publica:
///   - [init]: llamar UNA vez al arrancar la app (main.dart).
///   - [loadConfig] / [saveConfig]: persistencia.
///   - [reschedule]: aplica la config actual (cancela + programa).
///   - [cancel]: cancela la notificacion.
///   - [requestPermissionsIfNeeded]: pide POST_NOTIFICATIONS (Android 13+/iOS).
///   - [shouldFireToday]: chequea si la meta ya esta cumplida.
///   - [dailyDeeplinkPayload] / [kDailyChallengeDeeplink]: constantes para
///     navegar al reto al hacer tap.

/// Payload del tap. main.dart lo lee y navega a Daily Challenge.
const String kDailyChallengeDeeplink = 'dgt_daily_challenge';

/// Keys SharedPreferences (issue #102).
const String kDgtReminderEnabledKey = 'dgt_reminder_enabled';
const String kDgtReminderHourKey = 'dgt_reminder_hour';
const String kDgtReminderMinuteKey = 'dgt_reminder_minute';

/// Default 19:00 (criterio del issue #102).
const int kDgtReminderDefaultHour = 19;
const int kDgtReminderDefaultMinute = 0;

/// ID fijo para la notificacion diaria (un solo recordatorio activo).
const int kDgtReminderNotifId = 1102;
const String kDgtReminderChannelId = 'dgt_daily_reminder';
const String kDgtReminderChannelName = 'Recordatorio DGT';
const String kDgtReminderChannelDesc =
    'Recordatorio diario para cumplir tu meta de preguntas DGT.';

/// Prefijo del contador local de respuestas DGT por dia.
/// Compartido con la logica de "meta cumplida hoy".
const String kDgtAnsweredTodayPrefix = 'dgt_answered_count_';
const String kDgtDailyGoalLocalKey = 'dgt_daily_goal_cached';
const String kDgtExamDateLocalKey = 'dgt_exam_date_cached';

/// Config inmutable del recordatorio diario.
@immutable
class DgtReminderConfig {
  final bool enabled;
  final int hour;
  final int minute;

  const DgtReminderConfig({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  static const DgtReminderConfig defaults = DgtReminderConfig(
    enabled: false,
    hour: kDgtReminderDefaultHour,
    minute: kDgtReminderDefaultMinute,
  );

  DgtReminderConfig copyWith({bool? enabled, int? hour, int? minute}) {
    return DgtReminderConfig(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  /// Formato corto "HH:MM" para UI.
  String get label {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Servicio thin sobre flutter_local_notifications.
class DgtReminderService {
  DgtReminderService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  /// Indica si la plataforma soporta el plugin. Web/desktop -> false.
  bool get _isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Llamar UNA vez al iniciar la app.
  ///
  /// [onDeeplink] se invoca cuando el usuario toca la notificacion. El
  /// payload sera [kDailyChallengeDeeplink] (o null si la notif fue creada
  /// sin payload).
  Future<void> init({
    void Function(String? payload)? onDeeplink,
  }) async {
    if (!_isSupported) return;
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        if (onDeeplink != null) onDeeplink(resp.payload);
      },
    );

    // Crear canal Android (idempotente).
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        kDgtReminderChannelId,
        kDgtReminderChannelName,
        description: kDgtReminderChannelDesc,
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }

  /// Pide permisos POST_NOTIFICATIONS (Android 13+) / iOS.
  /// Devuelve true si concedido o si no aplica (Android < 13).
  Future<bool> requestPermissionsIfNeeded() async {
    if (!_isSupported) return false;
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? true;
    }
    if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return false;
  }

  /// Lee la config persistida.
  Future<DgtReminderConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return DgtReminderConfig(
      enabled: prefs.getBool(kDgtReminderEnabledKey) ?? false,
      hour: prefs.getInt(kDgtReminderHourKey) ?? kDgtReminderDefaultHour,
      minute: prefs.getInt(kDgtReminderMinuteKey) ?? kDgtReminderDefaultMinute,
    );
  }

  /// Persiste la config.
  Future<void> saveConfig(DgtReminderConfig cfg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kDgtReminderEnabledKey, cfg.enabled);
    await prefs.setInt(kDgtReminderHourKey, cfg.hour);
    await prefs.setInt(kDgtReminderMinuteKey, cfg.minute);
  }

  /// Aplica la config: cancela y, si esta habilitada, reprograma.
  Future<void> reschedule(DgtReminderConfig cfg, {DateTime? examDate}) async {
    if (!_isSupported) return;
    await cancel();
    if (!cfg.enabled) return;

    final scheduled = _nextInstanceOf(cfg.hour, cfg.minute);
    final body = _buildBody(examDate);

    const androidDetails = AndroidNotificationDetails(
      kDgtReminderChannelId,
      kDgtReminderChannelName,
      channelDescription: kDgtReminderChannelDesc,
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

    try {
      await _plugin.zonedSchedule(
        kDgtReminderNotifId,
        'Memora DGT',
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: kDailyChallengeDeeplink,
      );
    } on PlatformException {
      // Fallback si el dispositivo no permite alarmas exactas (Android 12+
      // sin permiso SCHEDULE_EXACT_ALARM). Usar modo inexact.
      await _plugin.zonedSchedule(
        kDgtReminderNotifId,
        'Memora DGT',
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: kDailyChallengeDeeplink,
      );
    }
  }

  /// Cancela la notificacion diaria.
  Future<void> cancel() async {
    if (!_isSupported) return;
    try {
      await _plugin.cancel(kDgtReminderNotifId);
    } catch (_) {
      // ignore
    }
  }

  /// Devuelve true si la meta de hoy NO esta cumplida (deberia disparar).
  /// Se basa en SharedPreferences locales (`kDgtAnsweredTodayPrefix$YYYY-MM-DD`)
  /// y `kDgtDailyGoalLocalKey`. Si no hay datos, asume que falta cumplir.
  static Future<bool> shouldFireToday({DateTime? now}) async {
    try {
      final ts = now ?? DateTime.now();
      final key = dailyCounterKey(ts);
      final prefs = await SharedPreferences.getInstance();
      final answered = prefs.getInt(key) ?? 0;
      final goal = prefs.getInt(kDgtDailyGoalLocalKey) ?? 0;
      if (goal <= 0) return true;
      return answered < goal;
    } catch (_) {
      return true;
    }
  }

  /// Builda la key del contador diario "$prefix$YYYY-MM-DD".
  static String dailyCounterKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$kDgtAnsweredTodayPrefix$y-$m-$d';
  }

  /// Calcula el proximo TZDateTime con hora HH:MM. Si ya paso hoy, usa
  /// manana.
  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Cuerpo del mensaje. Si hay [examDate], incluye dias restantes.
  String _buildBody(DateTime? examDate) {
    if (examDate == null) {
      return 'Hoy toca estudiar DGT, no rompas la racha.';
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exam = DateTime(examDate.year, examDate.month, examDate.day);
    final days = exam.difference(today).inDays;
    if (days < 0) {
      return 'Hoy toca estudiar DGT, no rompas la racha.';
    }
    if (days == 0) {
      return 'Hoy es tu examen DGT! Repasa antes de salir.';
    }
    return 'Hoy toca estudiar DGT - faltan $days dias para tu examen';
  }
}

/// Provider del plugin (singleton).
final flutterLocalNotificationsPluginProvider =
    Provider<FlutterLocalNotificationsPlugin>((ref) {
  return FlutterLocalNotificationsPlugin();
});

/// Provider del servicio.
final dgtReminderServiceProvider = Provider<DgtReminderService>((ref) {
  return DgtReminderService(
    ref.watch(flutterLocalNotificationsPluginProvider),
  );
});

/// FutureProvider que expone la config persistida (solo lectura).
final dgtReminderConfigProvider = FutureProvider<DgtReminderConfig>((ref) {
  return ref.watch(dgtReminderServiceProvider).loadConfig();
});
