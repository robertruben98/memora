import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/logging/app_logger.dart';
import 'core/srs/study_settings.dart';
import 'core/theme/theme_provider.dart';
import 'data/api/api_client.dart';
import 'data/database/database.dart';
import 'data/storage/image_storage.dart';
import 'data/sync/sync_service.dart';
import 'features/auth/auth_state.dart';
import 'features/auth/login_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/settings/settings_repository.dart';
import 'features/shell/root_shell.dart';

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
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        scaffoldBackgroundColor: const Color(0xFF0E0E12),
        textTheme: Typography.whiteMountainView.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
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
