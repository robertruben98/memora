import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/srs/study_settings.dart';
import 'core/theme/theme_provider.dart';
import 'data/database/database.dart';
import 'data/seeder.dart';
import 'data/storage/image_storage.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/settings/settings_repository.dart';
import 'features/shell/root_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final imageStorage = await ImageStorage.create();

  final container = ProviderContainer(
    overrides: [
      imageStorageProvider.overrideWithValue(imageStorage),
    ],
  );
  final db = container.read(databaseProvider);
  await seedIfEmpty(db);

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

class MemoraApp extends ConsumerWidget {
  final bool showOnboarding;

  const MemoraApp({super.key, this.showOnboarding = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
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
      home: showOnboarding ? const OnboardingScreen() : const RootShell(),
    );
  }
}
