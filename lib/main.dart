import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/logging/app_logger.dart';
import 'core/srs/study_settings.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/theme_provider.dart';
import 'data/api/api_client.dart';
import 'data/database/database.dart';
import 'data/storage/image_storage.dart';
import 'data/sync/sync_service.dart';
import 'features/auth/auth_state.dart';
import 'features/auth/login_screen.dart';
import 'features/dgt/dgt_recurrent_failures_screen.dart';
import 'features/dgt/dgt_reminder_service.dart';
import 'features/dgt/dgt_settings.dart';
import 'features/dgt/dgt_weekly_report_scheduler.dart';
import 'features/dgt/dgt_weekly_report_screen.dart';
import 'features/dgt/services/dgt_streak_alert_service.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/settings/settings_repository.dart';
import 'features/shell/root_shell.dart';

/// Global navigator key (issue #102): permite navegar desde callbacks
/// que no tienen `BuildContext` activo, p.ej. el tap de la notificacion
/// diaria DGT.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final imageStorage = await ImageStorage.create();

  final container = ProviderContainer(
    overrides: [
      imageStorageProvider.overrideWithValue(imageStorage),
      // El token efectivo se deriva del authProvider (JWT) si hay sesión,
      // si no usa el legacy API_TOKEN.
      effectiveTokenProvider.overrideWith((ref) {
        final auth = ref.watch(authProvider);
        return auth.token != null && auth.token!.isNotEmpty
            ? auth.token!
            : fallbackApiToken;
      }),
    ],
  );

  // Carga el token persistido (si lo hay) ANTES del primer sync.
  await container.read(authProvider.notifier).bootstrap();

  final db = container.read(databaseProvider);

  // Bootstrap: bajamos del servidor (Postgres) al cache local.
  // Si falla la red, seguimos con lo que haya en local.
  try {
    await container.read(syncServiceProvider).bootstrapFromServer();
  } catch (e, st) {
    appLogger.warn(
      'sync',
      'Sync bootstrap failed (offline?)',
      error: e,
      stackTrace: st,
    );
  }

  // Cargar settings persistidos en estado.
  final settingsRepo = container.read(settingsRepositoryProvider);
  final loadedStudy = await settingsRepo.loadStudySettings();
  final loadedTheme = await settingsRepo.loadThemeMode();
  container.read(studySettingsProvider.notifier).state = loadedStudy;
  container.read(themeModeProvider.notifier).state = loadedTheme;

  final onboardingSeen =
      await db.settingsDao.getValue('onboarding_seen') == '1';

  // Issue #102 (dgt-ux): inicializa notificaciones locales DGT y reaplica
  // la config persistida (si esta enabled, garantiza que zonedSchedule
  // este vigente tras un reinicio del dispositivo).
  try {
    final reminder = container.read(dgtReminderServiceProvider);
    await reminder.init(
      onDeeplink: (payload) {
        if (payload == kDailyChallengeDeeplink) {
          // Navega a la pestana home donde vive la card "Reto de hoy".
          // RootShell ya monta el reto diario; con popUntil aseguramos
          // limpiar pantallas modales si las hubiera.
          final nav = appNavigatorKey.currentState;
          if (nav != null) {
            nav.popUntil((r) => r.isFirst);
          }
        } else if (payload == kDgtStreakRescueDeeplink) {
          // Issue #212 (dgt-ux): tap en alarma anti-perdida -> quiz
          // rapido de 5 preguntas (recurrent-failures).
          final nav = appNavigatorKey.currentState;
          if (nav != null) {
            nav.popUntil((r) => r.isFirst);
            nav.push(
              MaterialPageRoute<void>(
                builder: (_) => const DgtRecurrentFailuresScreen(
                  initialMinFails: 2,
                  initialLimit: kDgtStreakRescueQuizSize,
                ),
              ),
            );
          }
        } else if (payload == kDgtWeeklyReportDeeplink) {
          // Issue #174: tap en notificacion del domingo 20:00 -> abre
          // el resumen semanal por encima del shell. popUntil para no
          // apilar varias instancias si el usuario abre la app dos veces.
          final nav = appNavigatorKey.currentState;
          if (nav != null) {
            nav.popUntil((r) => r.isFirst);
            nav.push(
              MaterialPageRoute(
                builder: (_) => const DgtWeeklyReportScreen(),
                settings: const RouteSettings(
                  name: DgtWeeklyReportScreen.routeName,
                ),
              ),
            );
          }
        }
      },
    );
    final cfg = await reminder.loadConfig();
    if (cfg.enabled) {
      // Sincroniza meta diaria + fecha examen cacheadas (SharedPreferences)
      // con los valores actuales en DB para que el chequeo de "meta cumplida"
      // sea correcto desde el primer dia.
      try {
        final dgtRepo = container.read(dgtSettingsRepositoryProvider);
        final dgt = await dgtRepo.load();
        final shouldFire = await DgtReminderService.shouldFireToday();
        if (shouldFire) {
          await reminder.reschedule(cfg, examDate: dgt.examDate);
        } else {
          // Meta ya cumplida hoy: programar para manana evitando spam.
          await reminder.cancel();
          await reminder.reschedule(cfg, examDate: dgt.examDate);
        }
      } catch (e, st) {
        appLogger.warn(
          'dgt-reminder',
          'reschedule on boot failed',
          error: e,
          stackTrace: st,
        );
      }
    }
  } catch (e, st) {
    appLogger.warn(
      'dgt-reminder',
      'init failed (notifications disabled)',
      error: e,
      stackTrace: st,
    );
  }

  // Issue #174 (dgt-ux): reaplica el scheduler del resumen semanal.
  // Default ON (criterio). El plugin ya fue inicializado por el bloque
  // del recordatorio diario; aqui solo reprogramamos.
  try {
    final weekly = container.read(dgtWeeklyReportSchedulerProvider);
    await weekly.reschedule();
  } catch (e, st) {
    appLogger.warn(
      'dgt-weekly-report',
      'weekly reschedule on boot failed',
      error: e,
      stackTrace: st,
    );
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: MemoraApp(showOnboarding: !onboardingSeen),
    ),
  );
}

class MemoraApp extends ConsumerStatefulWidget {
  final bool showOnboarding;

  const MemoraApp({super.key, this.showOnboarding = false});

  @override
  ConsumerState<MemoraApp> createState() => _MemoraAppState();
}

class _MemoraAppState extends ConsumerState<MemoraApp> {
  /// Si el usuario eligió "continuar sin login" usamos el legacy token.
  /// El flag se conserva en memoria solo en esta sesión.
  bool _legacyAccepted = false;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final auth = ref.watch(authProvider);
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7C5CFF),
      brightness: Brightness.dark,
    );
    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7C5CFF),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'Memora',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        scaffoldBackgroundColor: AppColors.dark.surface,
        extensions: const [AppColors.dark],
        textTheme: Typography.whiteMountainView.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
        scaffoldBackgroundColor: AppColors.light.surface,
        extensions: const [AppColors.light],
        textTheme: Typography.blackMountainView.apply(
          bodyColor: AppColors.light.textPrimary,
          displayColor: AppColors.light.textPrimary,
        ),
      ),
      home: _resolveHome(auth),
    );
  }

  Widget _resolveHome(AuthState auth) {
    if (widget.showOnboarding) return const OnboardingScreen();
    if (!auth.isLoggedIn && !_legacyAccepted) {
      return LoginScreen(
        onAuthenticated: () => setState(() => _legacyAccepted = true),
      );
    }
    return const RootShell();
  }
}
