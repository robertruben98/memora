import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/api/api_client.dart';
import 'package:memora/data/repositories/dgt_repository.dart';
import 'package:memora/features/dgt/dgt_exam_screen.dart';
import 'package:memora/features/dgt/dgt_prediction.dart';
import 'package:memora/features/dgt/dgt_result_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue #66 (dgt-tech): E2E test del simulacro DGT completo.
///
/// Cubre:
/// 1. Modelo `DgtExamResult` (criterio aprobado/suspenso DGT permiso B,
///    contadores correct/wrong, % calculado).
/// 2. Flujo UI: intro -> tap "Empezar simulacro" -> renderiza 30 preguntas
///    una a una -> progreso UI avanza -> "Terminar" -> pantalla resultado.
/// 3. Happy path: 30/30 aciertos -> APROBADO.
/// 4. Edge case: 0/30 aciertos -> SUSPENSO.
/// 5. Edge case: timer expira -> auto-submit con preguntas sin responder
///    contadas como falladas.
///
/// IMPORTANTE: no toca logica produccion. Overridea providers Riverpod
/// (apiClient + dgtRepository + dgtPrediction) con fakes. No usa mocktail
/// (no esta en pubspec dev_deps); se usan fakes manuales.

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// `ApiClient` falso: hereda del real pero ignora la red. Sirve para que
/// `apiClientProvider` no rompa con `baseUrl` real.
class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'http://test.invalid', token: 'fake');
}

/// `DgtRepository` falso con preguntas predefinidas y respuesta correcta
/// conocida. Permite scoring deterministico desde el test.
class _FakeDgtRepository extends DgtRepository {
  final List<DgtQuestion> seed;

  _FakeDgtRepository(this.seed) : super(_FakeApiClient());

  @override
  Future<List<DgtQuestion>> fetchExamQuestions({
    int limit = 30,
    bool forceRefresh = false,
  }) async {
    return seed.take(limit).toList();
  }
}

/// `DgtPredictionRepository` falso: devuelve prediccion fija. Evita roundtrip
/// HTTP en el `_buildIntro`.
class _FakePredictionRepo extends DgtPredictionRepository {
  _FakePredictionRepo() : super(_FakeApiClient());

  @override
  Future<DgtPrediction> fetchPrediction({int days = 30}) async {
    // Sin datos suficientes -> la card muestra copy "necesitas mas reviews".
    return DgtPrediction.empty;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Genera N preguntas DGT con respuesta correcta conocida.
/// `letter` define la letra correcta para TODAS (a/b/c) — facilita los tests
/// "tap correcta vs tap incorrecta" sin tener que mirar pregunta a pregunta.
List<DgtQuestion> _seedQuestions(int n, {String letter = 'a'}) {
  return List.generate(n, (i) {
    return DgtQuestion(
      id: 'q$i',
      statement: 'Pregunta DGT numero $i',
      optionA: 'Opcion A $i',
      optionB: 'Opcion B $i',
      optionC: 'Opcion C $i',
      correct: letter,
      topic: 'senales',
    );
  });
}

/// Construye el `ProviderScope` con overrides y monta `DgtExamScreen`.
Widget _buildApp({required List<DgtQuestion> seed}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(_FakeApiClient()),
      dgtRepositoryProvider.overrideWithValue(_FakeDgtRepository(seed)),
      dgtPredictionRepositoryProvider.overrideWithValue(_FakePredictionRepo()),
    ],
    child: const MaterialApp(home: DgtExamScreen()),
  );
}

/// Recorre las 30 preguntas, eligiendo `letter` en cada una y avanzando
/// con el boton "Siguiente". En la ultima pulsa "Terminar" y confirma.
Future<void> _answerAllAndFinish(
  WidgetTester tester, {
  required int total,
  required String letter,
}) async {
  for (var i = 0; i < total; i++) {
    // Verifica progreso UI: "Pregunta i+1 / total".
    expect(
      find.text('Pregunta ${i + 1} / $total'),
      findsOneWidget,
      reason: 'Progreso UI debe mostrar Pregunta ${i + 1} / $total',
    );

    // Tap opcion: usamos InkWell por letra dentro del tile (texto "A"/"B"/"C").
    await tester.tap(find.text(letter.toUpperCase()).first);
    await tester.pump();

    if (i < total - 1) {
      await tester.tap(find.text('Siguiente'));
      await tester.pump();
    } else {
      await tester.tap(find.text('Terminar'));
      await tester.pump();
      // Dialog confirmacion: "Entregar".
      await tester.tap(find.text('Entregar'));
      // Espera a que termine la transicion a la result screen.
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
    }
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    // dgtQuestionsCache lee SharedPreferences; lo mockeamos vacio.
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('DgtExamResult (modelo) - criterio DGT permiso B', () {
    test('30/30 aciertos => APROBADO (wrongCount=0)', () {
      final r = DgtExamResult(total: 30, correct: 30, wrong: const []);
      expect(r.wrongCount, 0);
      expect(r.passed, isTrue);
    });

    test('27/30 (3 fallos) => APROBADO (borde)', () {
      final r = DgtExamResult(
        total: 30,
        correct: 27,
        wrong: List.generate(
          3,
          (_) => DgtAnswerReview(
            question: _seedQuestions(1).first,
            picked: 'b',
          ),
        ),
      );
      expect(r.wrongCount, 3);
      expect(r.passed, isTrue, reason: 'Hasta 3 fallos es aprobado');
    });

    test('26/30 (4 fallos) => SUSPENSO', () {
      final r = DgtExamResult(
        total: 30,
        correct: 26,
        wrong: List.generate(
          4,
          (_) => DgtAnswerReview(
            question: _seedQuestions(1).first,
            picked: 'b',
          ),
        ),
      );
      expect(r.wrongCount, 4);
      expect(r.passed, isFalse);
    });

    test('0/30 => SUSPENSO con 30 fallos', () {
      final r = DgtExamResult(
        total: 30,
        correct: 0,
        wrong: List.generate(
          30,
          (_) => DgtAnswerReview(
            question: _seedQuestions(1).first,
            picked: null,
          ),
        ),
      );
      expect(r.wrongCount, 30);
      expect(r.passed, isFalse);
    });
  });

  group('Simulacro UI - flujo happy path', () {
    testWidgets('intro renderiza y tap "Empezar simulacro" arranca examen',
        (tester) async {
      await tester.pumpWidget(_buildApp(seed: _seedQuestions(30)));
      await tester.pump(); // initState + futures.

      // Intro visible: texto cabecera + boton.
      expect(find.text('Examen oficial DGT'), findsOneWidget);
      expect(find.text('Empezar simulacro'), findsOneWidget);
      // Pregunta 1 NO debe estar aun visible.
      expect(find.text('Pregunta 1 / 30'), findsNothing);

      // Tap empezar.
      await tester.tap(find.text('Empezar simulacro'));
      await tester.pump(); // dispara fetchExamQuestions
      await tester.pump(); // settle del FutureBuilder

      // Pregunta 1 visible.
      expect(find.text('Pregunta 1 / 30'), findsOneWidget);
      expect(find.text('Pregunta DGT numero 0'), findsOneWidget);
    });

    testWidgets(
        'responder 30 preguntas correctas (a) => APROBADO con 30/30 aciertos',
        (tester) async {
      await tester.pumpWidget(_buildApp(seed: _seedQuestions(30, letter: 'a')));
      await tester.pump();
      await tester.tap(find.text('Empezar simulacro'));
      await tester.pump();
      await tester.pump();

      await _answerAllAndFinish(tester, total: 30, letter: 'a');

      // Pantalla resultado.
      expect(find.text('APROBADO'), findsOneWidget);
      expect(find.text('30 / 30 aciertos (0 fallos)'), findsOneWidget);
    });

    testWidgets(
        'responder 30 incorrectas (b cuando correcta es a) => SUSPENSO con 30 fallos',
        (tester) async {
      await tester.pumpWidget(_buildApp(seed: _seedQuestions(30, letter: 'a')));
      await tester.pump();
      await tester.tap(find.text('Empezar simulacro'));
      await tester.pump();
      await tester.pump();

      await _answerAllAndFinish(tester, total: 30, letter: 'b');

      expect(find.text('SUSPENSO'), findsOneWidget);
      expect(find.text('0 / 30 aciertos (30 fallos)'), findsOneWidget);
    });
  });

  group('Simulacro UI - edge case timer', () {
    testWidgets(
        'timer expira (>30 min) => auto-submit con todas las preguntas como falladas',
        (tester) async {
      await tester.pumpWidget(_buildApp(seed: _seedQuestions(30)));
      await tester.pump();
      await tester.tap(find.text('Empezar simulacro'));
      await tester.pump();
      await tester.pump();

      // Estado inicial: timer 30:00 visible.
      expect(find.text('30:00'), findsOneWidget);

      // Simulamos el paso del tiempo: pump avanzando 31 minutos en chunks.
      // Periodic timer dispara cada 1s; basta con pumpear lo justo para
      // que _secondsLeft <= 0.
      for (var i = 0; i < 31; i++) {
        await tester.pump(const Duration(minutes: 1));
      }
      // Pump extra para navegar a la result screen.
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // Resultado: SUSPENSO con 30 fallos y nota "Tiempo agotado".
      expect(find.text('SUSPENSO'), findsOneWidget);
      expect(find.text('0 / 30 aciertos (30 fallos)'), findsOneWidget);
      expect(
        find.text('Tiempo agotado: entregado automaticamente.'),
        findsOneWidget,
      );
    });
  });
}
