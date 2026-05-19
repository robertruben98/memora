import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/api/api_client.dart';
import 'package:memora/data/repositories/dgt_repository.dart';
import 'package:memora/features/dgt/dgt_exam_screen.dart';
import 'package:memora/features/dgt/dgt_failures_repository.dart';
import 'package:memora/features/dgt/dgt_prediction.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue #103 (dgt-tech): tests dedicados para `DgtExamScreen`.
///
/// Aditivo respecto a `dgt_simulacro_e2e_test.dart`: cubre comportamientos
/// granulares que el E2E no testea directamente:
/// - Timer countdown decrementa segundo a segundo.
/// - strictMode oculta UI de navegacion libre (Anterior, flag, grid).
/// - Toggle flag persiste estado entre re-renders en modo normal.
/// - Navegacion via grid bottom-sheet salta a otra pregunta.
///
/// Mocks: override de `apiClientProvider`, `dgtRepositoryProvider`,
/// `dgtPredictionRepositoryProvider` y `dgtFailuresRepositoryProvider`.
/// No usa mocktail (no esta en deps).

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'http://test.invalid', token: 'fake');
}

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

class _FakePredictionRepo extends DgtPredictionRepository {
  _FakePredictionRepo() : super(_FakeApiClient());

  @override
  Future<DgtPrediction> fetchPrediction({int days = 30}) async {
    return DgtPrediction.empty;
  }
}

/// Fake del repo de fallos que evita el bug de "const []" sin tocar
/// produccion. Devuelve lista mutable y no persiste nada.
class _FakeFailuresRepo extends DgtFailuresRepository {
  final List<DgtFailureEntry> _store = [];

  @override
  Future<void> recordFailures(Iterable<DgtQuestion> questions) async {
    final ids = questions.map((q) => q.id).toSet();
    _store.removeWhere((e) => ids.contains(e.question.id));
    final now = DateTime.now();
    for (final q in questions) {
      _store.add(DgtFailureEntry(question: q, failedAt: now));
    }
  }

  @override
  Future<void> recordFailure(DgtQuestion question) async {
    _store.removeWhere((e) => e.question.id == question.id);
    _store.add(DgtFailureEntry(question: question, failedAt: DateTime.now()));
  }

  @override
  Future<List<DgtFailureEntry>> recentFailures() async => List.of(_store);

  @override
  Future<int> recentCount() async => _store.length;
}

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

Widget _buildExam({
  required List<DgtQuestion> seed,
  bool strictMode = false,
}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(_FakeApiClient()),
      dgtRepositoryProvider.overrideWithValue(_FakeDgtRepository(seed)),
      dgtPredictionRepositoryProvider.overrideWithValue(_FakePredictionRepo()),
      dgtFailuresRepositoryProvider.overrideWithValue(_FakeFailuresRepo()),
    ],
    child: MaterialApp(home: DgtExamScreen(strictMode: strictMode)),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('DgtExamScreen - timer countdown', () {
    testWidgets('timer arranca en 30:00 y decrementa al pasar 1 minuto',
        (tester) async {
      await tester.pumpWidget(_buildExam(seed: _seedQuestions(30)));
      await tester.pump();
      await tester.tap(find.text('Empezar simulacro'));
      await tester.pump();
      await tester.pump();

      // Estado inicial: 30:00.
      expect(find.text('30:00'), findsOneWidget);

      // Avanza 1 minuto -> 29:00.
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('29:00'), findsOneWidget);
      expect(find.text('30:00'), findsNothing);

      // Limpieza: forzamos auto-submit por timeout para que el ticker se
      // cancele y no quede pending. _FakeFailuresRepo evita el bug del
      // const [] en _readAll del repo real.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(minutes: 1));
      }
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
    });
  });

  group('DgtExamScreen - strictMode oculta UI navegacion libre', () {
    testWidgets('strict oculta boton "Anterior" desde la primera pregunta',
        (tester) async {
      await tester.pumpWidget(
        _buildExam(seed: _seedQuestions(2), strictMode: true),
      );
      // En strict el examen arranca solo via postFrameCallback.
      await tester.pump();
      await tester.pump();

      expect(find.text('Pregunta 1 / 2'), findsOneWidget);
      expect(find.text('Anterior'), findsNothing);
    });

    testWidgets('strict oculta icono flag y grid', (tester) async {
      await tester.pumpWidget(
        _buildExam(seed: _seedQuestions(2), strictMode: true),
      );
      await tester.pump();
      await tester.pump();

      // Iconos especificos de modo libre (flag y grid).
      expect(find.byIcon(Icons.outlined_flag_rounded), findsNothing);
      expect(find.byIcon(Icons.flag_rounded), findsNothing);
      expect(find.byIcon(Icons.grid_view_rounded), findsNothing);
    });

    testWidgets('strict en la ultima muestra "Entregar examen"',
        (tester) async {
      await tester.pumpWidget(
        _buildExam(seed: _seedQuestions(2), strictMode: true),
      );
      await tester.pump();
      await tester.pump();

      // Responde pregunta 1 y avanza.
      await tester.tap(find.text('A').first);
      await tester.pump();
      await tester.tap(find.text('Siguiente'));
      await tester.pump();

      // Ultima pregunta: "Entregar examen", no "Terminar".
      expect(find.text('Pregunta 2 / 2'), findsOneWidget);
      expect(find.text('Entregar examen'), findsOneWidget);
      expect(find.text('Terminar'), findsNothing);
    });
  });

  group('DgtExamScreen - flag toggle (modo normal)', () {
    testWidgets('tap flag pinta icono lleno y tap de nuevo lo restaura',
        (tester) async {
      await tester.pumpWidget(_buildExam(seed: _seedQuestions(30)));
      await tester.pump();
      await tester.tap(find.text('Empezar simulacro'));
      await tester.pump();
      await tester.pump();

      // Inicialmente: flag vacio.
      expect(find.byIcon(Icons.outlined_flag_rounded), findsOneWidget);
      expect(find.byIcon(Icons.flag_rounded), findsNothing);

      // Tap flag -> pasa a lleno (filled).
      await tester.tap(find.byIcon(Icons.outlined_flag_rounded));
      await tester.pump();
      expect(find.byIcon(Icons.flag_rounded), findsOneWidget);
      expect(find.byIcon(Icons.outlined_flag_rounded), findsNothing);

      // Tap de nuevo -> vuelve a vacio.
      await tester.tap(find.byIcon(Icons.flag_rounded));
      await tester.pump();
      expect(find.byIcon(Icons.outlined_flag_rounded), findsOneWidget);

      // Cleanup timer via auto-submit.
      for (var i = 0; i < 31; i++) {
        await tester.pump(const Duration(minutes: 1));
      }
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
    });
  });

  group('DgtExamScreen - grid navigation (modo normal)', () {
    testWidgets('tap grid abre bottom-sheet y permite saltar a pregunta 3',
        (tester) async {
      await tester.pumpWidget(_buildExam(seed: _seedQuestions(30)));
      await tester.pump();
      await tester.tap(find.text('Empezar simulacro'));
      await tester.pump();
      await tester.pump();

      // Abre grid.
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pumpAndSettle();
      // Header del bottom-sheet.
      expect(find.text('Preguntas'), findsOneWidget);
      // Leyenda visible.
      expect(find.text('Actual'), findsOneWidget);

      // Tap en celda "3" para saltar a pregunta 3.
      await tester.tap(find.text('3').first);
      await tester.pumpAndSettle();

      // La pantalla debe mostrar pregunta 3.
      expect(find.text('Pregunta 3 / 30'), findsOneWidget);

      // Cleanup timer via auto-submit.
      for (var i = 0; i < 31; i++) {
        await tester.pump(const Duration(minutes: 1));
      }
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
    });
  });
}
