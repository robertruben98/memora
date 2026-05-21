import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/repositories/dgt_repository.dart';
import 'package:memora/features/dgt/dgt_failures_repository.dart';
import 'package:memora/features/dgt/dgt_favorites_provider.dart';
import 'package:memora/features/dgt/dgt_reminder_service.dart';
import 'package:memora/features/study/dgt_exam_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue #202 (dgt-ux): tests del aislamiento del reset selectivo.
///
/// Acceptance critico: cada accion solo debe afectar SU almacen, no romper
/// los otros. Verificamos en el nivel notifier/repository sin levantar UI
/// (igual que `dgt_settings_new_fields_test.dart`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleQuestion = DgtQuestion(
    id: 'q-001',
    statement: 'Pregunta de prueba',
    optionA: 'A',
    optionB: 'B',
    optionC: 'C',
    correct: 'a',
  );

  final sampleExam = DgtExamHistoryEntry(
    date: DateTime(2025, 1, 1),
    correct: 28,
    total: 30,
    timeUsed: const Duration(minutes: 25),
    passed: true,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> seedAll() async {
    // 1. Fallo.
    final failuresRepo = DgtFailuresRepository();
    await failuresRepo.recordFailure(sampleQuestion);
    // 2. Favorita.
    final favs = DgtFavoritesNotifier();
    await favs.toggle('q-fav-1');
    // 3. Simulacro en historial.
    await DgtExamHistoryRepository().append(sampleExam);
    // 4. Contador "answered today" (proxy de la racha).
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${kDgtAnsweredTodayPrefix}2025-01-01', 42);
  }

  group('Reset selectivo - aislamiento (issue #202)', () {
    test('clearAll de fallos NO toca favoritas / simulacros / racha',
        () async {
      await seedAll();
      // Crear notifier despues del seed pero antes del clear para asegurar
      // que carga el estado persistido (toggle de 'q-fav-1').
      final favsBefore = DgtFavoritesNotifier();
      await Future<void>.delayed(Duration.zero);

      await DgtFailuresRepository().clearAll();

      // Fallos vacios.
      final failures = await DgtFailuresRepository().recentFailures();
      expect(failures, isEmpty);
      // Favoritas intactas (chequeamos via prefs ya que notifier in-memory).
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(kDgtFavoritesPrefsKey),
        contains('q-fav-1'),
      );
      // Simulacros intactos.
      final history = await DgtExamHistoryRepository().load();
      expect(history, hasLength(1));
      // Contador racha intacto.
      expect(prefs.getInt('${kDgtAnsweredTodayPrefix}2025-01-01'), 42);
      favsBefore.dispose();
    });

    test('clearAll de favoritas NO toca fallos / simulacros / racha',
        () async {
      await seedAll();
      final favs = DgtFavoritesNotifier();
      // Esperar load asincrono inicial.
      await Future<void>.delayed(Duration.zero);
      expect(favs.state.ids, contains('q-fav-1'));

      await favs.clearAll();

      expect(favs.state.ids, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(kDgtFavoritesPrefsKey), isNull);
      // Fallos intactos.
      final failures = await DgtFailuresRepository().recentFailures();
      expect(failures, hasLength(1));
      expect(failures.first.question.id, 'q-001');
      // Simulacros intactos.
      final history = await DgtExamHistoryRepository().load();
      expect(history, hasLength(1));
      // Racha (proxy) intacta.
      expect(prefs.getInt('${kDgtAnsweredTodayPrefix}2025-01-01'), 42);
      favs.dispose();
    });

    test('clear de simulacros NO toca fallos / favoritas / racha', () async {
      await seedAll();

      await DgtExamHistoryRepository().clear();

      final history = await DgtExamHistoryRepository().load();
      expect(history, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(kDgtFavoritesPrefsKey),
        contains('q-fav-1'),
      );
      final failures = await DgtFailuresRepository().recentFailures();
      expect(failures, hasLength(1));
      expect(prefs.getInt('${kDgtAnsweredTodayPrefix}2025-01-01'), 42);
    });

    test('reset de racha (limpia answered-today) NO toca fallos / '
        'favoritas / simulacros', () async {
      await seedAll();

      // Replica la accion del _SelectiveResetKind.streak: limpia las claves
      // que empiezan por kDgtAnsweredTodayPrefix.
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((k) => k.startsWith(kDgtAnsweredTodayPrefix))
          .toList();
      for (final k in keys) {
        await prefs.remove(k);
      }

      expect(prefs.getInt('${kDgtAnsweredTodayPrefix}2025-01-01'), isNull);
      // Fallos intactos.
      final failures = await DgtFailuresRepository().recentFailures();
      expect(failures, hasLength(1));
      // Favoritas intactas.
      expect(
        prefs.getStringList(kDgtFavoritesPrefsKey),
        contains('q-fav-1'),
      );
      // Simulacros intactos.
      final history = await DgtExamHistoryRepository().load();
      expect(history, hasLength(1));
    });

    test('clearAll de favoritas es idempotente (segunda llamada no rompe)',
        () async {
      SharedPreferences.setMockInitialValues({});
      final favs = DgtFavoritesNotifier();
      await Future<void>.delayed(Duration.zero);

      await favs.clearAll();
      await favs.clearAll();

      expect(favs.state.ids, isEmpty);
      favs.dispose();
    });
  });
}

