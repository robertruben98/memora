import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dgt_preparation_provider.dart';
import '../dgt_reminder_service.dart';
import '../dgt_streak_provider.dart';

/// Issue #189 (dgt-ux): notificacion local inmediata al alcanzar la meta
/// diaria de preguntas DGT.
///
/// Diseno:
/// - Servicio thin que recibe estado y dispara notif via plugin compartido
///   `flutter_local_notifications` (ya inicializado por `DgtReminderService`,
///   issue #102) reutilizando canal `kDgtReminderChannelId`.
/// - Idempotente por dia natural: clave SharedPreferences
///   `dgt.goal_notified.YYYY-MM-DD`. Marca ANTES de programar para evitar
///   race condition (la carrera prefiere "no spam" a "no notif").
/// - Toggle `DgtSettings.goalNotifEnabled` (default ON) gobierna disparo.
/// - Skip silencioso en web/desktop: `maybeFire...` retorna false sin error.
///
/// Listener `dgtGoalNotificationListenerProvider` observa
/// `dgtPreparationProvider` y `dgtStreakMonthProvider` para detectar cruce
/// de umbral `answeredToday >= dailyGoal`. La idempotencia del servicio
/// hace que disparos repetidos en el mismo dia sean no-op.

/// Prefijo SharedPreferences para idempotencia por dia.
const String kDgtGoalNotifiedPrefix = 'dgt.goal_notified.';

/// ID fijo de notificacion (distinto del recordatorio diario #102=1102).
const int kDgtGoalAchievedNotifId = 1189;

/// Builda la clave de idempotencia `dgt.goal_notified.YYYY-MM-DD`.
String dgtGoalNotifiedKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$kDgtGoalNotifiedPrefix$y-$m-$d';
}

/// Copy del cuerpo de notificacion segun streak + dias restantes a examen.
/// Funcion PURA, testable sin Flutter ni IO.
///
/// Reglas:
/// - streak >= 7: menciona la racha y motiva a mantenerla.
/// - streak >= 3: refuerzo de constancia.
/// - streak <= 2: copy "primer paso" / generico.
/// - examDate cercano (<7d): tono "ultima semana".
/// - examDate medio (7-30d): tono "vas en ritmo".
/// - sin examen / pasado: copy generico.
String dgtGoalAchievedBody({
  required int streak,
  int? daysToExam,
}) {
  final exam = daysToExam;
  final urgent = exam != null && exam >= 0 && exam < 7;
  final mid = exam != null && exam >= 7 && exam <= 30;
  if (streak >= 7) {
    if (urgent) {
      return '$streak dias seguidos! Ultima semana, sigue asi.';
    }
    if (mid) {
      return 'Racha de $streak dias. Vas en ritmo para el examen.';
    }
    return 'Racha de $streak dias - sigue rompiendo records!';
  }
  if (streak >= 3) {
    if (urgent) {
      return '$streak dias seguidos cumpliendo. El examen esta cerca!';
    }
    return '$streak dias seguidos cumpliendo meta. Constancia pura.';
  }
  // streak 1 o desconocida.
  if (urgent) {
    return 'Meta diaria cumplida. Aprovecha esta ultima semana.';
  }
  if (mid) {
    return 'Meta diaria cumplida. Sigue acumulando dias.';
  }
  return 'Meta diaria cumplida. Buen trabajo!';
}

/// Decision PURA: indica si debe dispararse la notificacion. Centraliza
/// las reglas para test sin IO/Flutter.
bool dgtShouldFireGoalNotification({
  required bool enabled,
  required int answeredToday,
  required int dailyGoal,
  required bool alreadyFiredToday,
}) {
  if (!enabled) return false;
  if (dailyGoal <= 0) return false;
  if (answeredToday < dailyGoal) return false;
  if (alreadyFiredToday) return false;
  return true;
}

/// Servicio thin: idempotencia + disparo de notif local.
class DgtGoalNotificationService {
  DgtGoalNotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  bool get _isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Intenta disparar la notificacion. Idempotente por dia natural.
  /// Devuelve `true` solo si se llamo a `plugin.show`. `false` si se omite
  /// (toggle off, meta no cumplida, ya disparada hoy, plataforma no
  /// soportada, error de IO).
  Future<bool> maybeFireGoalAchievedNotification({
    required bool enabled,
    required int answeredToday,
    required int dailyGoal,
    required int streak,
    int? daysToExam,
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now();
    final key = dgtGoalNotifiedKey(ts);
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return false;
    }
    final already = prefs.getBool(key) ?? false;
    final should = dgtShouldFireGoalNotification(
      enabled: enabled,
      answeredToday: answeredToday,
      dailyGoal: dailyGoal,
      alreadyFiredToday: already,
    );
    if (!should) return false;
    // Marca ANTES de programar para evitar carrera si la UI dispara dos
    // veces seguidas. Prioridad: idempotencia > best-effort show.
    try {
      await prefs.setBool(key, true);
    } catch (_) {
      // ignore: degradacion aceptable.
    }
    if (!_isSupported) return false;

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

    final body = dgtGoalAchievedBody(streak: streak, daysToExam: daysToExam);
    try {
      await _plugin.show(
        kDgtGoalAchievedNotifId,
        'RutaB DGT',
        body,
        details,
        payload: kDailyChallengeDeeplink,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Reset (best-effort) para test/limpieza manual. No expuesto en UI.
  Future<void> resetForDate(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(dgtGoalNotifiedKey(date));
    } catch (_) {
      // ignore
    }
  }
}

/// Provider del servicio (reusa plugin singleton de #102).
final dgtGoalNotificationServiceProvider =
    Provider<DgtGoalNotificationService>((ref) {
  return DgtGoalNotificationService(
    ref.watch(flutterLocalNotificationsPluginProvider),
  );
});

/// Listener side-effect: cada vez que `dgtPreparationProvider` emite,
/// intenta disparar la notif. La idempotencia + toggle gating dentro del
/// servicio garantizan que esto sea no-op fuera del caso "cruce de
/// umbral".
///
/// Uso: `ref.watch(dgtGoalNotificationListenerProvider)` en el arbol
/// (por ejemplo en Home o main.dart). El provider devuelve void; basta
/// su existencia para mantener el listener vivo mientras el arbol este
/// montado.
final dgtGoalNotificationListenerProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<DgtPreparation>>(
    dgtPreparationProvider,
    (prev, next) {
      final prep = next.value;
      if (prep == null) return;
      final settings = prep.settings;
      // streak: best-effort desde cache de `dgtStreakMonthProvider`. Si no
      // esta cacheada, degradamos a 0 (no bloqueamos la notif por falta de
      // racha; solo afecta al copy via `dgtGoalAchievedBody`).
      int streak = 0;
      try {
        final asyncMonth = ref.read(dgtStreakMonthProvider);
        streak = asyncMonth.value?.currentStreak ?? 0;
      } catch (_) {
        streak = 0;
      }
      final service = ref.read(dgtGoalNotificationServiceProvider);
      // Fire-and-forget: la idempotencia interna evita doble notif.
      unawaited(service.maybeFireGoalAchievedNotification(
        enabled: settings.goalNotifEnabled,
        answeredToday: prep.answeredToday,
        dailyGoal: settings.dailyGoal,
        streak: streak,
        daysToExam: settings.daysUntilExam,
      ));
    },
  );
});
