import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/home/welcome_tour.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue #84 (dgt-ux): tour interactivo de bienvenida.
/// Cubre: render de pasos, navegacion Siguiente, Saltar, completar,
/// y persistencia del flag dgt_tour_completed en SharedPreferences.
void main() {
  setUp(() {
    // Reset SharedPreferences mock entre tests.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('WelcomeTourOverlay', () {
    testWidgets('muestra titulo y descripcion del primer paso', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WelcomeTourOverlay(
              steps: kDefaultDgtTourSteps,
              onDismiss: () {},
              onCompleted: () {},
            ),
          ),
        ),
      );
      expect(find.text(kDefaultDgtTourSteps.first.title), findsOneWidget);
      expect(
        find.text(kDefaultDgtTourSteps.first.description),
        findsOneWidget,
      );
      // Step label: "1/5"
      expect(find.text('1/${kDefaultDgtTourSteps.length}'), findsOneWidget);
    });

    testWidgets('boton Siguiente avanza al siguiente paso', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WelcomeTourOverlay(
              steps: kDefaultDgtTourSteps,
              onDismiss: () {},
              onCompleted: () {},
            ),
          ),
        ),
      );
      expect(find.text(kDefaultDgtTourSteps[0].title), findsOneWidget);

      await tester.tap(find.byKey(const Key('welcome-tour-next')));
      await tester.pump();

      expect(find.text(kDefaultDgtTourSteps[1].title), findsOneWidget);
      expect(find.text('2/${kDefaultDgtTourSteps.length}'), findsOneWidget);
    });

    testWidgets('en el ultimo paso el boton dice "Empezar" y llama onCompleted',
        (tester) async {
      bool completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WelcomeTourOverlay(
              steps: kDefaultDgtTourSteps,
              onDismiss: () {},
              onCompleted: () => completed = true,
            ),
          ),
        ),
      );

      // Avanza hasta el ultimo paso.
      for (var i = 0; i < kDefaultDgtTourSteps.length - 1; i++) {
        await tester.tap(find.byKey(const Key('welcome-tour-next')));
        await tester.pump();
      }
      expect(find.text('Empezar'), findsOneWidget);
      expect(completed, isFalse);

      await tester.tap(find.byKey(const Key('welcome-tour-next')));
      await tester.pump();
      expect(completed, isTrue);
    });

    testWidgets('boton Saltar tour llama onDismiss', (tester) async {
      bool dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WelcomeTourOverlay(
              steps: kDefaultDgtTourSteps,
              onDismiss: () => dismissed = true,
              onCompleted: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('welcome-tour-skip')));
      await tester.pump();
      expect(dismissed, isTrue);
    });

    testWidgets('pasos por defecto contienen 5 elementos', (tester) async {
      // Spec del issue: 4-5 pasos.
      expect(kDefaultDgtTourSteps.length, 5);
    });
  });

  group('dgtTourCompletedProvider', () {
    testWidgets('devuelve false cuando la flag no esta seteada',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final completed = await container.read(dgtTourCompletedProvider.future);
      expect(completed, isFalse);
    });

    testWidgets('devuelve true despues de setDgtTourCompleted(true)',
        (tester) async {
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await setDgtTourCompleted(capturedRef, true);
      // Verifica directamente en SharedPreferences (que es la fuente de verdad).
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kDgtTourCompletedKey), isTrue);
    });

    testWidgets('setDgtTourCompleted(false) resetea la flag', (tester) async {
      SharedPreferences.setMockInitialValues(
        <String, Object>{kDgtTourCompletedKey: true},
      );
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await setDgtTourCompleted(capturedRef, false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kDgtTourCompletedKey), isFalse);
    });
  });
}
