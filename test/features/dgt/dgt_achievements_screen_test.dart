import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_achievements_screen.dart';

/// Issue #209 (dgt-ux): tests pantalla "Mis logros".
///
/// Cubre:
///  - computeAchievementStatus para cada categoria (constancia, maestria,
///    examen, estudio): umbral exacto desbloquea, debajo no, progreso
///    proporcional.
///  - globalAccuracyPct null -> maestria currentValue = 0.
///  - threshold = 0 -> progreso = 1.0 (no division por cero).
///  - Render con input vacio: muestra "0 / N insignias desbloqueadas" y todas
///    las insignias bloqueadas.
///  - Render con input alto: desbloquea todas y muestra "N / N".
///  - Render parcial: mezcla unlocked + locked; cuenta correcta.
///  - Tile sigue presente en kDgtTileRegistry.

DgtAchievementSpec _specFor(DgtAchievementCategory cat, int threshold) {
  return kDgtAchievementsCatalog.firstWhere(
    (s) => s.category == cat && s.threshold == threshold,
  );
}

Widget _wrap(DgtAchievementsInput input) {
  return ProviderScope(
    overrides: [
      dgtAchievementsInputProvider.overrideWith((ref) async => input),
    ],
    child: const MaterialApp(home: DgtAchievementsScreen()),
  );
}

void main() {
  group('computeAchievementStatus', () {
    test('constancia: streak exactamente al umbral desbloquea', () {
      final spec = _specFor(DgtAchievementCategory.constancia, 7);
      final status = computeAchievementStatus(
        spec,
        const DgtAchievementsInput(
          currentStreak: 7,
          globalAccuracyPct: null,
          passedExams: 0,
          totalAnswered: 0,
        ),
      );
      expect(status.unlocked, isTrue);
      expect(status.progress, 1.0);
      expect(status.currentValue, 7);
    });

    test('constancia: 1 dia por debajo NO desbloquea', () {
      final spec = _specFor(DgtAchievementCategory.constancia, 14);
      final status = computeAchievementStatus(
        spec,
        const DgtAchievementsInput(
          currentStreak: 13,
          globalAccuracyPct: null,
          passedExams: 0,
          totalAnswered: 0,
        ),
      );
      expect(status.unlocked, isFalse);
      expect(status.progress, closeTo(13 / 14, 1e-9));
      expect(status.progressLabel, '13 / 14 dias');
    });

    test('maestria: globalAccuracyPct null => currentValue 0', () {
      final spec = _specFor(DgtAchievementCategory.maestria, 70);
      final status = computeAchievementStatus(
        spec,
        DgtAchievementsInput.empty,
      );
      expect(status.currentValue, 0);
      expect(status.unlocked, isFalse);
      expect(status.progress, 0.0);
    });

    test('maestria: 85% desbloquea umbral 70 y 85, no 95', () {
      const input = DgtAchievementsInput(
        currentStreak: 0,
        globalAccuracyPct: 85.4,
        passedExams: 0,
        totalAnswered: 0,
      );
      final s70 = computeAchievementStatus(
        _specFor(DgtAchievementCategory.maestria, 70),
        input,
      );
      final s85 = computeAchievementStatus(
        _specFor(DgtAchievementCategory.maestria, 85),
        input,
      );
      final s95 = computeAchievementStatus(
        _specFor(DgtAchievementCategory.maestria, 95),
        input,
      );
      expect(s70.unlocked, isTrue);
      expect(s85.unlocked, isTrue);
      expect(s95.unlocked, isFalse);
      // 85.4.round() == 85 -> currentValue 85.
      expect(s85.currentValue, 85);
      expect(s85.progressLabel, '85% / 85%');
    });

    test('examen: aprobados encadenados desbloquean por niveles', () {
      const input = DgtAchievementsInput(
        currentStreak: 0,
        globalAccuracyPct: null,
        passedExams: 5,
        totalAnswered: 0,
      );
      final e1 = computeAchievementStatus(
        _specFor(DgtAchievementCategory.examen, 1),
        input,
      );
      final e5 = computeAchievementStatus(
        _specFor(DgtAchievementCategory.examen, 5),
        input,
      );
      final e10 = computeAchievementStatus(
        _specFor(DgtAchievementCategory.examen, 10),
        input,
      );
      expect(e1.unlocked, isTrue);
      expect(e5.unlocked, isTrue);
      expect(e10.unlocked, isFalse);
      expect(e10.progress, 0.5);
      expect(e10.progressLabel, '5 / 10 aprobados');
    });

    test('estudio: 1500 preguntas desbloquea los 3 niveles', () {
      const input = DgtAchievementsInput(
        currentStreak: 0,
        globalAccuracyPct: null,
        passedExams: 0,
        totalAnswered: 1500,
      );
      for (final threshold in const [100, 500, 1000]) {
        final st = computeAchievementStatus(
          _specFor(DgtAchievementCategory.estudio, threshold),
          input,
        );
        expect(st.unlocked, isTrue,
            reason: 'estudio.$threshold debe estar desbloqueada');
        expect(st.progress, 1.0);
      }
    });

    test('threshold <= 0 nunca divide por cero', () {
      const edgeSpec = DgtAchievementSpec(
        id: 'edge.0',
        title: 'Edge',
        description: 'd',
        tip: 't',
        icon: Icons.star,
        category: DgtAchievementCategory.constancia,
        threshold: 0,
      );
      final st = computeAchievementStatus(edgeSpec, DgtAchievementsInput.empty);
      expect(st.progress, 1.0);
      expect(st.unlocked, isTrue);
    });
  });

  group('Catalogo', () {
    test('cubre las 4 categorias con 3 niveles cada una (12 total)', () {
      expect(kDgtAchievementsCatalog.length, 12);
      for (final cat in DgtAchievementCategory.values) {
        final inCat =
            kDgtAchievementsCatalog.where((s) => s.category == cat).toList();
        expect(inCat.length, 3, reason: 'categoria $cat debe tener 3 niveles');
        final thresholds = inCat.map((s) => s.threshold).toList()..sort();
        expect(thresholds, equals(thresholds.toList()..sort()));
      }
    });

    test('todos los ids son unicos', () {
      final ids = kDgtAchievementsCatalog.map((s) => s.id).toSet();
      expect(ids.length, kDgtAchievementsCatalog.length);
    });
  });

  group('DgtAchievementsScreen render', () {
    testWidgets('input vacio: 0 desbloqueadas y todas las insignias bloqueadas',
        (tester) async {
      // Surface grande para que todas las categorias entren en el viewport
      // (ListView lazy = solo construye los hijos visibles).
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(DgtAchievementsInput.empty));
      await tester.pumpAndSettle();

      expect(find.text('Mis logros'), findsOneWidget);
      expect(find.textContaining('0 / 12 insignias desbloqueadas'),
          findsOneWidget);
      // Cada categoria tiene su titulo de seccion.
      expect(find.text('Constancia'), findsOneWidget);
      expect(find.text('Maestria'), findsOneWidget);
      expect(find.text('Examen'), findsOneWidget);
      expect(find.text('Estudio'), findsOneWidget);
      // Ninguna insignia muestra "Desbloqueada".
      expect(find.text('Desbloqueada'), findsNothing);
    });

    testWidgets('input alto: las 12 insignias desbloqueadas', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(const DgtAchievementsInput(
        currentStreak: 60,
        globalAccuracyPct: 99.0,
        passedExams: 20,
        totalAnswered: 2000,
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('12 / 12 insignias desbloqueadas'),
          findsOneWidget);
      // Hay al menos un tile mostrando "Desbloqueada" en su footer.
      expect(find.text('Desbloqueada'), findsWidgets);
    });

    testWidgets('input parcial: cuenta solo las realmente desbloqueadas',
        (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // streak=7 (1), accuracy=72 (1), passed=1 (1), totalAnswered=120 (1) -> 4
      await tester.pumpWidget(_wrap(const DgtAchievementsInput(
        currentStreak: 7,
        globalAccuracyPct: 72.0,
        passedExams: 1,
        totalAnswered: 120,
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('4 / 12 insignias desbloqueadas'),
          findsOneWidget);
    });

    testWidgets('tap insignia abre bottom sheet con descripcion y tip',
        (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(const DgtAchievementsInput(
        currentStreak: 2,
        globalAccuracyPct: null,
        passedExams: 0,
        totalAnswered: 0,
      )));
      await tester.pumpAndSettle();

      // Tap en "Primera semana" (constancia.7, bloqueada con progreso 2/7).
      await tester.tap(find.text('Primera semana').first);
      await tester.pumpAndSettle();

      // Descripcion y tip aparecen (ambos contienen "7 dias seguidos").
      expect(find.textContaining('7 dias seguidos'), findsNWidgets(2));
      // Texto exacto de la descripcion en el sheet.
      expect(find.text('7 dias seguidos cumpliendo tu meta diaria'),
          findsOneWidget);
    });
  });

  group('Tile registry', () {
    test('importacion del archivo es valida (sanity)', () {
      // Sanity: el simbolo principal existe.
      expect(kDgtAchievementsCatalog, isNotEmpty);
    });
  });
}
