import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:memora/features/dgt/data/dgt_tutorials.dart';
import 'package:memora/features/dgt/dgt_subtopic_tutorial_screen.dart';
import 'package:memora/features/dgt/dgt_tutorial_seen_provider.dart';

/// Issue #153 (dgt-ux): smoke tests del flujo de la screen tutorial.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const tutorial = DgtTutorial(
    topicId: 'senales',
    concept: 'CONCEPTO_DEMO',
    example: 'EJEMPLO_DEMO',
  );

  Widget buildHost({required Widget child}) {
    return ProviderScope(
      child: MaterialApp(home: child),
    );
  }

  testWidgets('renderiza concepto, ejemplo y CTA con contador', (tester) async {
    await tester.pumpWidget(
      buildHost(
        child: const DgtSubtopicTutorialScreen(
          topicId: 'senales',
          topicName: 'Senales',
          tutorial: tutorial,
          questionCount: 10,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Senales'), findsOneWidget);
    expect(find.text('CONCEPTO_DEMO'), findsOneWidget);
    expect(find.text('EJEMPLO_DEMO'), findsOneWidget);
    expect(find.text('Empezar 10 preguntas'), findsOneWidget);
    expect(find.text('No mostrar mas para este tema'), findsOneWidget);
  });

  testWidgets('CTA "Empezar" devuelve true al popular', (tester) async {
    bool? popResult;
    await tester.pumpWidget(
      buildHost(
        child: Builder(builder: (ctx) {
          return ElevatedButton(
            onPressed: () async {
              popResult = await Navigator.of(ctx).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) => const DgtSubtopicTutorialScreen(
                    topicId: 'senales',
                    topicName: 'Senales',
                    tutorial: tutorial,
                    questionCount: 20,
                  ),
                ),
              );
            },
            child: const Text('go'),
          );
        }),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Empezar 20 preguntas'));
    await tester.pumpAndSettle();
    expect(popResult, isTrue);
  });

  testWidgets('"No mostrar mas" persiste el topic_id y devuelve true',
      (tester) async {
    bool? popResult;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(builder: (ctx) {
            return ElevatedButton(
              onPressed: () async {
                popResult = await Navigator.of(ctx).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => const DgtSubtopicTutorialScreen(
                      topicId: 'senales',
                      topicName: 'Senales',
                      tutorial: tutorial,
                      questionCount: 10,
                    ),
                  ),
                );
              },
              child: const Text('go'),
            );
          }),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('No mostrar mas para este tema'));
    await tester.pumpAndSettle();

    expect(popResult, isTrue);
    expect(
      container.read(dgtTutorialSeenProvider).contains('senales'),
      isTrue,
    );
  });

  testWidgets('boton skip pop con false', (tester) async {
    bool? popResult;
    await tester.pumpWidget(
      buildHost(
        child: Builder(builder: (ctx) {
          return ElevatedButton(
            onPressed: () async {
              popResult = await Navigator.of(ctx).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) => const DgtSubtopicTutorialScreen(
                    topicId: 'senales',
                    topicName: 'Senales',
                    tutorial: tutorial,
                  ),
                ),
              );
            },
            child: const Text('go'),
          );
        }),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Saltar tutorial'));
    await tester.pumpAndSettle();
    expect(popResult, isFalse);
  });

  testWidgets('sin questionCount muestra CTA generico', (tester) async {
    await tester.pumpWidget(
      buildHost(
        child: const DgtSubtopicTutorialScreen(
          topicId: 'senales',
          topicName: 'Senales',
          tutorial: tutorial,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Empezar quiz'), findsOneWidget);
  });
}
