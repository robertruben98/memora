import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart' as http_testing;
import 'package:http/http.dart' as http;
import 'package:memora/data/api/api_client.dart';
import 'package:memora/data/repositories/dgt_repository.dart';
import 'package:memora/features/dgt/dgt_exam_screen.dart';
import 'package:memora/features/dgt/dgt_prediction.dart';
import 'package:memora/features/dgt/dgt_result_screen.dart';

// E2E flow test del simulacro DGT (issue #66):
// - fake repo entrega 30 preguntas
// - tap "Empezar simulacro" -> timer arranca (visible 30:00)
// - responder las 30 preguntas y avanzar
// - pulsar "Terminar" -> dialogo -> Entregar -> DgtResultScreen
// - assert aciertos / aprobado / suspenso segun caso
// - edge case: timer expira -> auto submit

DgtQuestion _q(int i) => DgtQuestion(
      id: 'q-$i',
      statement: 'Pregunta $i',
      optionA: 'a-$i',
      optionB: 'b-$i',
      optionC: 'c-$i',
      // Correcta alterna a/b/c segun indice.
      correct: ['a', 'b', 'c'][i % 3],
      topic: 'dgt-t-01',
    );

class _FakeApiClient extends ApiClient {
  _FakeApiClient()
      : super(
          baseUrl: 'http://localhost',
          token: 'test',
          // MockClient siempre devuelve 200 [] para que la cache no fallezca,
          // pero el repo fake intercepta antes.
          client: http_testing.MockClient(
            (req) async => http.Response('[]', 200),
          ),
        );

  @override
  String? remoteUrlFor(String path) => null;
}

class _FakeDgtRepository extends DgtRepository {
  final List<DgtQuestion> questions;
  _FakeDgtRepository(this.questions) : super(_FakeApiClient());

  @override
  Future<List<DgtQuestion>> fetchExamQuestions({
    int limit = 30,
    bool forceRefresh = false,
  }) async {
    return questions.take(limit).toList();
  }
}

// Bombea pumps con Duration explicito porque el ticker del simulacro
// usa Timer.periodic que nunca cierra en pumpAndSettle.
Future<void> _pumpQuick(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
}

Widget _harness(List<DgtQuestion> questions) {
  return ProviderScope(
    overrides: [
      dgtRepositoryProvider.overrideWithValue(
        _FakeDgtRepository(questions),
      ),
      // Cortocircuita el provider de prediccion para no llamar al backend.
      dgtPredictionProvider.overrideWith((ref) async => DgtPrediction.empty),
    ],
    child: const MaterialApp(home: DgtExamScreen()),
  );
}

void main() {
  testWidgets('happy path: 30 preguntas, todas correctas -> APROBADO',
      (tester) async {
    final qs = List.generate(30, _q);
    await tester.pumpWidget(_harness(qs));
    await _pumpQuick(tester);

    // Intro screen visible.
    expect(find.text('Empezar simulacro'), findsOneWidget);
    expect(find.text('Examen oficial DGT'), findsOneWidget);

    // Arrancar simulacro.
    await tester.tap(find.text('Empezar simulacro'));
    await _pumpQuick(tester);
    await _pumpQuick(tester);

    // Timer visible (30:00 al inicio).
    expect(find.text('30:00'), findsOneWidget);
    // Primera pregunta y progreso 1/30.
    expect(find.text('Pregunta 1 / 30'), findsOneWidget);

    // Responder 30 preguntas correctas y avanzar.
    for (var i = 0; i < 30; i++) {
      final correct = ['A', 'B', 'C'][i % 3];
      // Tap en la letra correcta. _AnswerTile renderiza la letra en caja.
      await tester.tap(find.text(correct).first);
      await _pumpQuick(tester);

      if (i < 29) {
        // Avanzar a la siguiente.
        await tester.tap(find.text('Siguiente'));
        await _pumpQuick(tester);
      }
    }

    // En la ultima pregunta hay boton "Terminar".
    expect(find.text('Terminar'), findsOneWidget);
    await tester.tap(find.text('Terminar'));
    await _pumpQuick(tester);

    // Dialogo de confirmacion.
    expect(find.text('Terminar simulacro'), findsOneWidget);
    await tester.tap(find.text('Entregar'));
    await _pumpQuick(tester);
    await _pumpQuick(tester);

    // Resultado: APROBADO con 30/30.
    expect(find.text('APROBADO'), findsOneWidget);
    expect(find.text('30 / 30 aciertos (0 fallos)'), findsOneWidget);
  });

  testWidgets('umbral: 27 correctas / 3 falladas -> APROBADO (criterio DGT)',
      (tester) async {
    final qs = List.generate(30, _q);
    await tester.pumpWidget(_harness(qs));
    await _pumpQuick(tester);
    await tester.tap(find.text('Empezar simulacro'));
    await _pumpQuick(tester);
    await _pumpQuick(tester);

    // 27 correctas, 3 falladas (los 3 ultimos eligen letra incorrecta).
    for (var i = 0; i < 30; i++) {
      final String pick;
      if (i >= 27) {
        // Forzar fallo: elegir letra distinta a la correcta.
        final correctIdx = i % 3;
        final wrongIdx = (correctIdx + 1) % 3;
        pick = ['A', 'B', 'C'][wrongIdx];
      } else {
        pick = ['A', 'B', 'C'][i % 3];
      }
      await tester.tap(find.text(pick).first);
      await _pumpQuick(tester);
      if (i < 29) {
        await tester.tap(find.text('Siguiente'));
        await _pumpQuick(tester);
      }
    }

    await tester.tap(find.text('Terminar'));
    await _pumpQuick(tester);
    await tester.tap(find.text('Entregar'));
    await _pumpQuick(tester);
    await _pumpQuick(tester);

    expect(find.text('APROBADO'), findsOneWidget);
    expect(find.text('27 / 30 aciertos (3 fallos)'), findsOneWidget);
  });

  testWidgets('suspenso: 4 falladas -> SUSPENSO', (tester) async {
    final qs = List.generate(30, _q);
    await tester.pumpWidget(_harness(qs));
    await _pumpQuick(tester);
    await tester.tap(find.text('Empezar simulacro'));
    await _pumpQuick(tester);
    await _pumpQuick(tester);

    for (var i = 0; i < 30; i++) {
      final String pick;
      if (i >= 26) {
        // 4 fallos (i=26..29).
        final correctIdx = i % 3;
        final wrongIdx = (correctIdx + 1) % 3;
        pick = ['A', 'B', 'C'][wrongIdx];
      } else {
        pick = ['A', 'B', 'C'][i % 3];
      }
      await tester.tap(find.text(pick).first);
      await _pumpQuick(tester);
      if (i < 29) {
        await tester.tap(find.text('Siguiente'));
        await _pumpQuick(tester);
      }
    }

    await tester.tap(find.text('Terminar'));
    await _pumpQuick(tester);
    await tester.tap(find.text('Entregar'));
    await _pumpQuick(tester);
    await _pumpQuick(tester);

    expect(find.text('SUSPENSO'), findsOneWidget);
    expect(find.text('26 / 30 aciertos (4 fallos)'), findsOneWidget);
  });

  testWidgets(
      'edge: timer expira -> auto-submit, no respondidas cuentan como falladas',
      (tester) async {
    final qs = List.generate(30, _q);
    await tester.pumpWidget(_harness(qs));
    await _pumpQuick(tester);
    await tester.tap(find.text('Empezar simulacro'));
    await _pumpQuick(tester);
    await _pumpQuick(tester);

    // Sin responder nada, avanzar tiempo hasta agotar (>30 min).
    // Hacemos pumps de 1s para que el Timer.periodic dispare el setState.
    // 30 * 60 ticks. Para mantener test rapido, hacemos pumps largos.
    // Cada pump(Duration(seconds: 1)) ejecuta UN tick del periodic.
    for (var i = 0; i < 30 * 60 + 1; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    // Asentar navegacion post auto-submit.
    await _pumpQuick(tester);
    await _pumpQuick(tester);

    // Resultado: 0 correctas, 30 fallos, SUSPENSO, badge tiempo agotado.
    expect(find.text('SUSPENSO'), findsOneWidget);
    expect(find.text('0 / 30 aciertos (30 fallos)'), findsOneWidget);
    expect(
      find.text('Tiempo agotado: entregado automaticamente.'),
      findsOneWidget,
    );
  });
}
