import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../dgt_preparation_provider.dart';
import '../dgt_reminder_service.dart';
import '../dgt_streak_provider.dart';

/// Issue #212 (dgt-ux): alarma local "anti-perdida de racha".
///
/// Programa una notificacion local 23h despues de la ULTIMA actividad
/// DGT registrada (toda nueva review re-programa la alarma). El usuario
/// recibe el aviso cuando le queda ~1h para perder la racha.
///
/// Reglas:
/// - Solo si `current_streak >= 3` (evita spam a usuarios casuales).
/// - Solo si el disparo cae entre 9h-22h locales (no despertar). Si cae
///   fuera, se mueve a las 9h del dia siguiente (sigue dentro de la
///   ventana de 24h, antes de perder la racha).
/// - Toggle `DgtSettings.streakAlertEnabled` (default ON) gobierna el
///   disparo. OFF cancela cualquier alarma pendiente.
///
/// Tap en la notif -> deep-link `kDgtStreakRescueDeeplink` -> abre quiz
/// rapido de 5 preguntas (`/dgt/quiz/recurrent-failures?limit=5`).
///
/// Reusa el plugin `flutter_local_notifications` (singleton via
/// `flutterLocalNotificationsPluginProvider`) y el canal del recordatorio
/// diario (`kDgtReminderChannelId`). Skip silencioso en web/desktop.

/// Payload del tap. main.dart lo lee y navega a la pantalla quiz rapido.
const String kDgtStreakRescueDeeplink = 'dgt_streak_rescue';

/// ID fijo de notificacion (distinto de #102=1102 y #189=1189).
const int kDgtStreakAlertNotifId = 1212;

/// Numero de preguntas del quiz rapido al hacer tap.
const int kDgtStreakRescueQuizSize = 5;

/// Streak minima para programar alarma. <3 = usuario casual, no spam.
const int kDgtStreakAlertMinStreak = 3;

/// Ventana horaria local en la que se permite disparar la alarma.
const int kDgtStreakAlertWindowStartHour = 9;
const int kDgtStreakAlertWindowEndHour = 22;

/// Offset (horas) tras la ultima actividad para el disparo. La racha se
/// pierde a las 24h sin actividad; programamos 23h para dar ~1h de margen.
const int kDgtStreakAlertOffsetHours = 23;

/// Decision PURA: indica si la racha justifica programar alarma.
bool dgtShouldScheduleStreakAlert({
  required bool enabled,
  required int currentStreak,
}) {
  if (!enabled) return false;
  if (currentStreak < kDgtStreakAlertMinStreak) return false;
  return true;
}

/// Calculo PURO del momento de disparo. Toma la `lastActivity` y devuelve
/// el `DateTime` (mismo huso local) en el que la notif debe sonar:
/// - base = lastActivity + 23h.
/// - si base.hour cae fuera de [9..22), mueve al siguiente 9:00 dentro
///   del intervalo 24h tras lastActivity (para no perder la racha).
///
/// El retorno SIEMPRE es estrictamente posterior a [now]. Si el base
/// calculado ya es pasado (caso edge: ultimo activity hace >23h pero la
/// racha aun no expiro porque el reloj cambio), devuelve null para que
/// el caller no programe alarma.
DateTime? dgtComputeStreakAlertFireTime({
  required DateTime lastActivity,
  required DateTime now,
}) {
  var fire = lastActivity.add(
    const Duration(hours: kDgtStreakAlertOffsetHours),
  );
  // Si la hora cae fuera de la ventana, mover al inicio de la ventana
  // del mismo dia (si aun no llego) o del dia siguiente.
  if (fire.hour < kDgtStreakAlertWindowStartHour) {
    fire = DateTime(
      fire.year,
      fire.month,
      fire.day,
      kDgtStreakAlertWindowStartHour,
    );
  } else if (fire.hour >= kDgtStreakAlertWindowEndHour) {
    // Mover al 9:00 del dia siguiente. Esto puede pasar de las 24h del
    // last activity, lo que rompe la garantia anti-perdida. Solo
    // aceptamos el move si sigue dentro de las 24h.
    final next = DateTime(
      fire.year,
      fire.month,
      fire.day,
      kDgtStreakAlertWindowStartHour,
    ).add(const Duration(days: 1));
    final deadline = lastActivity.add(const Duration(hours: 24));
    fire = next.isBefore(deadline) ? next : deadline.subtract(
      const Duration(minutes: 5),
    );
  }
  if (!fire.isAfter(now)) return null;
  return fire;
}

/// Copy del titulo + cuerpo de la notif. PURO.
String dgtStreakAlertTitle(int streak) =>
    'Tu racha de $streak dias esta en peligro';

String dgtStreakAlertBody() =>
    'Te quedan ~1h. Solo $kDgtStreakRescueQuizSize preguntas la salvan.';

/// Servicio thin: programa/cancela la alarma local.
class DgtStreakAlertService {
  DgtStreakAlertService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  bool get _isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Cancela cualquier alarma pendiente. Idempotente.
  Future<void> cancel() async {
    if (!_isSupported) return;
    try {
      await _plugin.cancel(kDgtStreakAlertNotifId);
    } catch (_) {
      // ignore.
    }
  }

  /// Re-programa la alarma anti-perdida con los datos actuales. Cancela
  /// la previa (si la habia) y programa una nueva.
  ///
  /// Devuelve true si efectivamente programo una notif (cancel + schedule).
  /// false si no aplica (toggle off, streak<3, plataforma no soportada,
  /// fire time invalido).
  Future<bool> rescheduleAfterActivity({
    required bool enabled,
    required int currentStreak,
    required DateTime lastActivity,
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now();
    // Persistimos la ultima actividad para que un reboot pueda reprogramar.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        kDgtStreakAlertLastActivityKey,
        lastActivity.toIso8601String(),
      );
    } catch (_) {
      // ignore.
    }
    if (!dgtShouldScheduleStreakAlert(
      enabled: enabled,
      currentStreak: currentStreak,
    )) {
      await cancel();
      return false;
    }
    final fireAt = dgtComputeStreakAlertFireTime(
      lastActivity: lastActivity,
      now: ts,
    );
    if (fireAt == null) {
      await cancel();
      return false;
    }
    if (!_isSupported) return false;

    await cancel();

    final tz.TZDateTime scheduled = tz.TZDateTime.from(fireAt, tz.local);
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

    final title = dgtStreakAlertTitle(currentStreak);
    final body = dgtStreakAlertBody();

    try {
      await _plugin.zonedSchedule(
        kDgtStreakAlertNotifId,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: kDgtStreakRescueDeeplink,
      );
      return true;
    } on PlatformException {
      // Fallback inexact (Android 12+ sin SCHEDULE_EXACT_ALARM).
      try {
        await _plugin.zonedSchedule(
          kDgtStreakAlertNotifId,
          title,
          body,
          scheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: kDgtStreakRescueDeeplink,
        );
        return true;
      } catch (_) {
        return false;
      }
    } catch (_) {
      return false;
    }
  }
}

/// Key SharedPreferences donde se persiste la timestamp ISO de la ultima
/// actividad DGT (para reprogramar tras reboot).
const String kDgtStreakAlertLastActivityKey = 'dgt_streak_alert_last_activity';

/// Provider del servicio (reusa plugin singleton de #102).
final dgtStreakAlertServiceProvider =
    Provider<DgtStreakAlertService>((ref) {
  return DgtStreakAlertService(
    ref.watch(flutterLocalNotificationsPluginProvider),
  );
});

/// Listener side-effect: cada vez que `dgtPreparationProvider` emite,
/// reprograma la alarma con la racha actual. La idempotencia interna del
/// servicio (cancel + schedule) hace que sea seguro llamar varias veces.
///
/// Uso: `ref.watch(dgtStreakAlertListenerProvider)` montado en el arbol.
final dgtStreakAlertListenerProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<DgtPreparation>>(
    dgtPreparationProvider,
    (prev, next) {
      final prep = next.value;
      if (prep == null) return;
      // Solo nos interesa cuando hay actividad hoy (answered>0). Sin
      // actividad no hay nada que rescatar.
      if (prep.answeredToday <= 0) return;
      int streak = 0;
      try {
        final asyncMonth = ref.read(dgtStreakMonthProvider);
        streak = asyncMonth.value?.currentStreak ?? 0;
      } catch (_) {
        streak = 0;
      }
      final service = ref.read(dgtStreakAlertServiceProvider);
      unawaited(service.rescheduleAfterActivity(
        enabled: prep.settings.streakAlertEnabled,
        currentStreak: streak,
        lastActivity: DateTime.now(),
      ));
    },
  );
});
