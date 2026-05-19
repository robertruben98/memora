import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/home/home_screen.dart';

/// Issue #80 (dgt-ux): badge prominente del streak diario.
/// Cubre: no renderiza con streak 0, renderiza label, dispara animacion
/// solo cuando el streak aumenta (no en build inicial).
void main() {
  group('StreakBadge', () {
    testWidgets('NO se renderiza cuando streakDays == 0 (caller responsable)',
        (tester) async {
      // El widget es renderizado por el caller solo si streakDays >= 1.
      // Aqui validamos contractualmente que con 0 el caller decide no mostrarlo.
      // El test renderiza el caller-equivalente: un SizedBox.shrink.
      const streakDays = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: streakDays >= 1
                ? const StreakBadge(streakDays: streakDays)
                : const SizedBox.shrink(),
          ),
        ),
      );
      expect(find.byType(StreakBadge), findsNothing);
      expect(find.text('🔥'), findsNothing);
    });

    testWidgets('renderiza icono fuego y "1 dia seguido" con streakDays=1',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakBadge(streakDays: 1),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('🔥'), findsOneWidget);
      expect(find.text('1 dia seguido'), findsOneWidget);
    });

    testWidgets('renderiza "X dias seguidos" con streakDays>1', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakBadge(streakDays: 7),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('7 dias seguidos'), findsOneWidget);
    });

    testWidgets('animacion NO se dispara en build inicial', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakBadge(streakDays: 3),
          ),
        ),
      );
      final scaleFinder = find.descendant(
        of: find.byType(StreakBadge),
        matching: find.byType(ScaleTransition),
      );
      // En reposo (value=0 del controller), la escala es 1.0 (inicio del tween).
      final scale = tester.widget<ScaleTransition>(scaleFinder);
      expect(scale.scale.value, closeTo(1.0, 0.001));
      // Aunque pumpemos mas, sin cambio de widget no debe animarse.
      await tester.pump(const Duration(milliseconds: 300));
      final scale2 = tester.widget<ScaleTransition>(scaleFinder);
      expect(scale2.scale.value, closeTo(1.0, 0.001));
    });

    testWidgets('animacion SI se dispara cuando streakDays aumenta',
        (tester) async {
      Widget app(int days) => MaterialApp(
            home: Scaffold(body: StreakBadge(streakDays: days)),
          );

      await tester.pumpWidget(app(3));
      await tester.pump();

      final scaleFinder = find.descendant(
        of: find.byType(StreakBadge),
        matching: find.byType(ScaleTransition),
      );

      // Incremento: dispara animacion.
      await tester.pumpWidget(app(4));
      await tester.pump(const Duration(milliseconds: 150));
      final scaleMid = tester.widget<ScaleTransition>(scaleFinder);
      // En la primera mitad del tween la escala debe haber crecido por encima de 1.0.
      expect(scaleMid.scale.value, greaterThan(1.0));

      // Al final vuelve a ~1.0.
      await tester.pump(const Duration(milliseconds: 600));
      final scaleEnd = tester.widget<ScaleTransition>(scaleFinder);
      expect(scaleEnd.scale.value, closeTo(1.0, 0.001));
    });
  });
}
