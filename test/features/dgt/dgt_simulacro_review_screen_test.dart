import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/repositories/dgt_repository.dart';
import 'package:memora/features/dgt/dgt_favorites_provider.dart';
import 'package:memora/features/dgt/dgt_result_screen.dart';
import 'package:memora/features/dgt/dgt_simulacro_review_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue #181 (dgt-ux): tests del widget [DgtSimulacroReviewScreen].
///
/// Cubre:
/// - Render basico: enunciado, opciones, indicador "1/N" en appbar.
/// - Explicacion visible cuando la pregunta la tiene.
/// - PageView navega a la siguiente pregunta al tocar "Siguiente".
/// - Ultima pagina muestra "Volver" y al tocarla cierra la pantalla.
/// - Toggle "Favorita" cambia el label entre estados.

DgtQuestion _q(String id, {String? explanation}) => DgtQuestion(
      id: id,
      statement: 'Enunciado pregunta $id',
      optionA: 'opcion A $id',
      optionB: 'opcion B $id',
      optionC: 'opcion C $id',
      correct: 'a',
      explanation: explanation,
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('DgtSimulacroReviewScreen', () {
    testWidgets('render basico: enunciado, opciones, contador en appbar',
        (tester) async {
      final failed = [
        DgtAnswerReview(question: _q('q1', explanation: 'porque la ley'),
            picked: 'b'),
        DgtAnswerReview(question: _q('q2'), picked: 'c'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: DgtSimulacroReviewScreen(failed: failed),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // AppBar muestra "Revisar fallos (1/2)".
      expect(find.text('Revisar fallos (1/2)'), findsOneWidget);
      // Enunciado primera pregunta.
      expect(find.text('Enunciado pregunta q1'), findsOneWidget);
      // Opciones todas visibles.
      expect(find.text('opcion A q1'), findsOneWidget);
      expect(find.text('opcion B q1'), findsOneWidget);
      expect(find.text('opcion C q1'), findsOneWidget);
      // Explicacion visible.
      expect(find.text('porque la ley'), findsOneWidget);
      expect(find.text('Explicacion'), findsOneWidget);
      // CTA "Siguiente" en pagina no-ultima.
      expect(find.text('Siguiente'), findsOneWidget);
    });

    testWidgets('sin explicacion no muestra bloque de explicacion',
        (tester) async {
      final failed = [
        DgtAnswerReview(question: _q('q1'), picked: 'b'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: DgtSimulacroReviewScreen(failed: failed),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Explicacion'), findsNothing);
    });

    testWidgets('PageView avanza al tocar Siguiente', (tester) async {
      final failed = [
        DgtAnswerReview(question: _q('q1'), picked: 'b'),
        DgtAnswerReview(question: _q('q2'), picked: 'b'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: DgtSimulacroReviewScreen(failed: failed),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Estado inicial: pagina 1.
      expect(find.text('Enunciado pregunta q1'), findsOneWidget);

      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      // Ahora pagina 2: contador y enunciado q2.
      expect(find.text('Revisar fallos (2/2)'), findsOneWidget);
      expect(find.text('Enunciado pregunta q2'), findsOneWidget);
      // CTA cambia a "Volver" en ultima pagina.
      expect(find.text('Volver'), findsOneWidget);
    });

    testWidgets('Volver en ultima pagina cierra la pantalla', (tester) async {
      final failed = [
        DgtAnswerReview(question: _q('q1'), picked: 'b'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            DgtSimulacroReviewScreen(failed: failed),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // En la pantalla review, con 1 pregunta es ya ultima -> "Volver".
      expect(find.text('Volver'), findsOneWidget);
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();

      // Volvimos al scaffold original.
      expect(find.text('open'), findsOneWidget);
      expect(find.text('Revisar fallos (1/1)'), findsNothing);
    });

    testWidgets('toggle Favorita actualiza estado del provider',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final failed = [
        DgtAnswerReview(question: _q('q1'), picked: 'b'),
      ];

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: DgtSimulacroReviewScreen(failed: failed),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(dgtFavoritesProvider).contains('q1'), isFalse);

      await tester.tap(find.byIcon(Icons.star_border_rounded));
      await tester.pumpAndSettle();

      expect(container.read(dgtFavoritesProvider).contains('q1'), isTrue);
      // Icono cambia a star_rounded (filled).
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });
  });

  group('DgtResultScreen - integracion boton Revisar fallos', () {
    testWidgets('muestra boton "Revisar fallos (N)" cuando hay fallos',
        (tester) async {
      final result = DgtExamResult(
        total: 10,
        correct: 7,
        wrong: [
          DgtAnswerReview(question: _q('q1'), picked: 'b'),
          DgtAnswerReview(question: _q('q2'), picked: 'b'),
          DgtAnswerReview(question: _q('q3'), picked: 'b'),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: DgtResultScreen(result: result),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Revisar fallos (3)'), findsOneWidget);
    });

    testWidgets('100% acierto no muestra el boton', (tester) async {
      const result = DgtExamResult(
        total: 10,
        correct: 10,
        wrong: [],
      );
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DgtResultScreen(result: result),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Revisar fallos'), findsNothing);
    });
  });
}
