import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/api/api_client.dart';
import 'package:memora/data/repositories/dgt_repository.dart';
import 'package:memora/features/dgt/dgt_true_false_screen.dart';

/// Issue #201 (dgt-ux): tests del modo V/F rapido. Cubre:
/// - Generador puro de afirmaciones (T/F balance, mapping correcto).
/// - Notifier: carga set, answer, scoring, next, restart.
/// - Pantalla: loading state, render afirmacion + 2 botones, feedback,
///   pantalla resumen.

class _FakeApi extends ApiClient {
  final Object response;
  _FakeApi(this.response)
      : super(baseUrl: 'http://test.invalid', token: 'fake');

  @override
  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    if (response is Exception) throw response as Exception;
    return response;
  }
}

Map<String, dynamic> _q({
  String id = 'q1',
  String statement = 'En carretera convencional la velocidad maxima es',
  String correct = 'a',
  String optionA = '90 km/h',
  String optionB = '120 km/h',
  String optionC = '50 km/h',
}) =>
    {
      'id': id,
      'statement': statement,
      'option_a': optionA,
      'option_b': optionB,
      'option_c': optionC,
      'correct': correct,
      'explanation': null,
      'image_url': null,
      'topic': 'senales',
    };

DgtQuestion _dq({
  String id = 'q1',
  String statement = 'En autopista la velocidad maxima es',
  String correct = 'a',
  String optionA = '120 km/h',
  String optionB = '90 km/h',
  String optionC = '50 km/h',
}) {
  return DgtQuestion.fromJson(_q(
    id: id,
    statement: statement,
    correct: correct,
    optionA: optionA,
    optionB: optionB,
    optionC: optionC,
  ));
}

Widget _wrap(Widget child, {required ApiClient api}) {
  return ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(api)],
    child: MaterialApp(home: child),
  );
}

void main() {
  group('DgtTrueFalseSetGenerator', () {
    test('genera afirmaciones T y F desde una pregunta', () {
      final pool = [_dq()];
      final set = DgtTrueFalseSetGenerator.generate(
        pool: pool,
        count: 3,
        random: Random(42),
      );
      // 1 verdadera + 2 falsas disponibles = 3 items max.
      expect(set.length, 3);
      final trues = set.where((s) => s.isTrue).length;
      final falses = set.where((s) => !s.isTrue).length;
      expect(trues, greaterThanOrEqualTo(1));
      expect(falses, greaterThanOrEqualTo(1));
    });

    test('afirmacion verdadera usa la opcion correcta', () {
      final pool = [_dq(correct: 'b', optionB: 'OPCION_CORRECTA_B')];
      final set = DgtTrueFalseSetGenerator.generate(
        pool: pool,
        count: 1,
        random: Random(1),
      );
      // El primer pick deberia ser verdadero (alternancia comienza por T).
      expect(set.first.isTrue, true);
      expect(set.first.text, contains('OPCION_CORRECTA_B'));
    });

    test('afirmacion falsa NO usa la opcion correcta', () {
      final pool = [_dq(correct: 'a', optionA: 'CORRECTA', optionB: 'FALSA_B')];
      final set = DgtTrueFalseSetGenerator.generate(
        pool: pool,
        count: 5,
        random: Random(7),
      );
      for (final s in set) {
        if (!s.isTrue) {
          expect(s.text, isNot(contains('CORRECTA')));
        }
      }
    });

    test('distribucion ~50/50 con pool grande', () {
      final pool = List.generate(
        20,
        (i) => _dq(id: 'q$i', statement: 'Enunciado $i'),
      );
      final set = DgtTrueFalseSetGenerator.generate(
        pool: pool,
        count: 10,
        random: Random(123),
      );
      expect(set.length, 10);
      final trues = set.where((s) => s.isTrue).length;
      // Alternancia 50/50 estricta -> 5 y 5.
      expect(trues, 5);
    });

    test('pool vacio devuelve lista vacia', () {
      final set = DgtTrueFalseSetGenerator.generate(pool: const [], count: 10);
      expect(set, isEmpty);
    });

    test('count <= 0 devuelve lista vacia', () {
      final set = DgtTrueFalseSetGenerator.generate(
        pool: [_dq()],
        count: 0,
      );
      expect(set, isEmpty);
    });
  });

  group('DgtTrueFalseState.correctCount', () {
    test('cuenta respuestas que coinciden con isTrue', () {
      final stmts = [
        DgtTrueFalseStatement(
          text: 't1',
          isTrue: true,
          questionStatement: 'q',
          optionLetter: 'a',
          correctOptionText: 'a',
        ),
        DgtTrueFalseStatement(
          text: 't2',
          isTrue: false,
          questionStatement: 'q',
          optionLetter: 'b',
          correctOptionText: 'a',
        ),
        DgtTrueFalseStatement(
          text: 't3',
          isTrue: true,
          questionStatement: 'q',
          optionLetter: 'a',
          correctOptionText: 'a',
        ),
      ];
      final state = DgtTrueFalseState(
        statements: stmts,
        answers: const {0: true, 1: true, 2: true},
        loading: false,
      );
      // 0: T==T ok, 1: F==T fail, 2: T==T ok -> 2 correctos.
      expect(state.correctCount, 2);
    });
  });

  group('DgtTrueFalseScreen widget', () {
    testWidgets('muestra loading al inicio', (tester) async {
      final api = _FakeApi([_q()]);
      await tester.pumpWidget(_wrap(const DgtTrueFalseScreen(), api: api));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('renderiza afirmacion + botones V/F + contador',
        (tester) async {
      final api = _FakeApi(List.generate(20, (i) => _q(id: 'q$i')));
      await tester.pumpWidget(_wrap(const DgtTrueFalseScreen(), api: api));
      await tester.pumpAndSettle();

      expect(find.text('V/F rapido'), findsOneWidget);
      expect(find.text('Verdadero'), findsOneWidget);
      expect(find.text('Falso'), findsOneWidget);
      expect(find.text('1 / 10'), findsOneWidget);
    });

    testWidgets('tap en Verdadero muestra feedback', (tester) async {
      final api = _FakeApi(List.generate(20, (i) => _q(id: 'q$i')));
      await tester.pumpWidget(_wrap(const DgtTrueFalseScreen(), api: api));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Verdadero'));
      await tester.pumpAndSettle();
      // Aparece feedback (Correcto o Incorrecto) y boton Siguiente.
      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            (w.data == 'Correcto' || w.data == 'Incorrecto')),
        findsOneWidget,
      );
      expect(find.text('Siguiente'), findsOneWidget);
    });

    testWidgets('al completar las 10, muestra resumen con score',
        (tester) async {
      final api = _FakeApi(List.generate(20, (i) => _q(id: 'q$i')));
      await tester.pumpWidget(_wrap(const DgtTrueFalseScreen(), api: api));
      await tester.pumpAndSettle();

      for (var i = 0; i < 10; i++) {
        await tester.tap(find.text('Verdadero'));
        await tester.pumpAndSettle();
        final btnLabel = i == 9 ? 'Ver resumen' : 'Siguiente';
        await tester.tap(find.text(btnLabel));
        await tester.pumpAndSettle();
      }

      expect(find.text('Resumen de la ronda'), findsOneWidget);
      expect(find.text('Otra ronda'), findsOneWidget);
      expect(find.text('Aciertos'), findsOneWidget);
    });
  });
}
