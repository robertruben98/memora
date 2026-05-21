import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_weekly_evolution_screen.dart';

/// Issue #183 (dgt-ux): tests pantalla "Tu evolucion semanal".
///
/// Cubre: parser BE#176 payload, build de evolution con multiples semanas,
/// render normal con chart, empty state cuando ninguna semana tiene
/// actividad, badge de tendencia (verde/rojo/amarillo) segun delta, y
/// bottom-sheet al tap en un tile semanal.

DgtWeeklyPoint _point({
  required int offset,
  double accuracy = 0.0,
  int questions = 0,
  int simulacros = 0,
  int streak = 0,
}) {
  return DgtWeeklyPoint(
    weekOffset: offset,
    periodStart: '2026-05-${offset.abs() + 1}',
    periodEnd: '2026-05-${offset.abs() + 7}',
    questionsAnswered: questions,
    accuracyOverall: accuracy,
    accuracyDeltaVsPrev: 0.0,
    simulacrosCompleted: simulacros,
    simulacrosPassed: 0,
    predictorPassProb: accuracy,
    streakDays: streak,
    weakTopicName: null,
    improvedTopicName: null,
    recommendation: '',
  );
}

Widget _wrap(DgtWeeklyEvolution evo) {
  return ProviderScope(
    overrides: [
      dgtWeeklyEvolutionProvider.overrideWith((ref) async => evo),
    ],
    child: const MaterialApp(home: DgtWeeklyEvolutionScreen()),
  );
}

void main() {
  group('DgtWeeklyPoint.fromJson', () {
    test('parsea payload BE#176 completo', () {
      final j = {
        'period': {'start': '2026-05-11', 'end': '2026-05-17'},
        'week_offset': 0,
        'questions_answered': 42,
        'accuracy_overall': 0.78,
        'accuracy_delta_vs_prev_week': 0.05,
        'top_weak_topic': {
          'id': 'dgt-t-08',
          'name': 'Normas',
          'accuracy': 0.55,
        },
        'top_improved_topic': {
          'id': 'dgt-t-01',
          'name': 'Senales',
          'accuracy_delta': 0.12,
        },
        'simulacros_completed': 3,
        'simulacros_passed': 2,
        'predictor_pass_prob': 0.71,
        'predictor_delta': 0.04,
        'streak_days': 5,
        'recommendation': 'Sigue asi, foco en Normas.',
      };
      final p = DgtWeeklyPoint.fromJson(j);
      expect(p.weekOffset, 0);
      expect(p.questionsAnswered, 42);
      expect(p.accuracyOverall, closeTo(0.78, 1e-6));
      expect(p.simulacrosCompleted, 3);
      expect(p.simulacrosPassed, 2);
      expect(p.streakDays, 5);
      expect(p.weakTopicName, 'Normas');
      expect(p.improvedTopicName, 'Senales');
      expect(p.hasActivity, isTrue);
    });

    test('parsea payload con topics null (semana sin actividad)', () {
      final j = {
        'period': {'start': '2026-04-13', 'end': '2026-04-19'},
        'week_offset': -4,
        'questions_answered': 0,
        'accuracy_overall': 0.0,
        'accuracy_delta_vs_prev_week': 0.0,
        'top_weak_topic': null,
        'top_improved_topic': null,
        'simulacros_completed': 0,
        'simulacros_passed': 0,
        'predictor_pass_prob': 0.0,
        'predictor_delta': 0.0,
        'streak_days': 0,
        'recommendation': '',
      };
      final p = DgtWeeklyPoint.fromJson(j);
      expect(p.hasActivity, isFalse);
      expect(p.weakTopicName, isNull);
    });
  });

  group('DgtWeeklyEvolution', () {
    test('isEmpty true cuando ninguna semana tiene actividad', () {
      final evo = DgtWeeklyEvolution([
        _point(offset: -2),
        _point(offset: -1),
        _point(offset: 0),
      ]);
      expect(evo.isEmpty, isTrue);
      expect(evo.activeWeeks, 0);
    });

    test('isEmpty false con al menos 1 semana activa', () {
      final evo = DgtWeeklyEvolution([
        _point(offset: -1, accuracy: 0.6, questions: 10),
        _point(offset: 0),
      ]);
      expect(evo.isEmpty, isFalse);
      expect(evo.activeWeeks, 1);
    });

    test('accuracyTrendDelta: positivo cuando ultima > anterior activa', () {
      final evo = DgtWeeklyEvolution([
        _point(offset: -1, accuracy: 0.60, questions: 10),
        _point(offset: 0, accuracy: 0.75, questions: 12),
      ]);
      expect(evo.accuracyTrendDelta, closeTo(0.15, 1e-6));
    });

    test('accuracyTrendDelta: null si solo 1 semana activa', () {
      final evo = DgtWeeklyEvolution([
        _point(offset: -1),
        _point(offset: 0, accuracy: 0.7, questions: 5),
      ]);
      expect(evo.accuracyTrendDelta, isNull);
    });
  });

  group('DgtWeeklyEvolutionScreen', () {
    testWidgets('render normal: muestra chart + lista de semanas',
        (tester) async {
      final evo = DgtWeeklyEvolution([
        _point(offset: -2, accuracy: 0.55, questions: 10, simulacros: 1),
        _point(offset: -1, accuracy: 0.65, questions: 20, simulacros: 2),
        _point(offset: 0, accuracy: 0.75, questions: 30, simulacros: 3),
      ]);
      await tester.pumpWidget(_wrap(evo));
      await tester.pumpAndSettle();

      expect(find.text('Tu evolucion semanal'), findsOneWidget);
      // Reversed list: tile mas reciente (offset=0) primero (sin scroll).
      expect(find.byKey(const Key('weekTile-0')), findsOneWidget);
      // Tiles antiguos pueden estar fuera del viewport: scroll para
      // verificar que existen en el arbol.
      await tester.scrollUntilVisible(
        find.byKey(const Key('weekTile--2')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('weekTile--1')), findsOneWidget);
      expect(find.byKey(const Key('weekTile--2')), findsOneWidget);
    });

    testWidgets('empty state cuando ninguna semana tiene actividad',
        (tester) async {
      final evo = DgtWeeklyEvolution([
        _point(offset: -2),
        _point(offset: -1),
        _point(offset: 0),
      ]);
      await tester.pumpWidget(_wrap(evo));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Necesitas al menos 1 semana'),
        findsOneWidget,
      );
    });

    testWidgets('badge tendencia: verde subiendo cuando delta > 0',
        (tester) async {
      final evo = DgtWeeklyEvolution([
        _point(offset: -1, accuracy: 0.55, questions: 10),
        _point(offset: 0, accuracy: 0.75, questions: 12),
      ]);
      await tester.pumpWidget(_wrap(evo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('weeklyTrendBadge')), findsOneWidget);
      expect(find.textContaining('Subiendo'), findsOneWidget);
    });

    testWidgets('badge tendencia: rojo bajando cuando delta < 0',
        (tester) async {
      final evo = DgtWeeklyEvolution([
        _point(offset: -1, accuracy: 0.80, questions: 10),
        _point(offset: 0, accuracy: 0.60, questions: 12),
      ]);
      await tester.pumpWidget(_wrap(evo));
      await tester.pumpAndSettle();

      expect(find.textContaining('Bajando'), findsOneWidget);
    });

    testWidgets('badge tendencia: amarillo estable cuando |delta| <= 0.02',
        (tester) async {
      final evo = DgtWeeklyEvolution([
        _point(offset: -1, accuracy: 0.70, questions: 10),
        _point(offset: 0, accuracy: 0.71, questions: 12),
      ]);
      await tester.pumpWidget(_wrap(evo));
      await tester.pumpAndSettle();

      expect(find.textContaining('Estable'), findsOneWidget);
    });

    testWidgets('tap en tile semanal abre bottom-sheet con KPIs',
        (tester) async {
      final evo = DgtWeeklyEvolution([
        _point(
          offset: 0,
          accuracy: 0.80,
          questions: 25,
          simulacros: 2,
          streak: 4,
        ),
      ]);
      await tester.pumpWidget(_wrap(evo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('weekTile-0')));
      await tester.pumpAndSettle();

      expect(find.text('Preguntas'), findsOneWidget);
      // "25" aparece en tile (subtitle) y en sheet => >=1.
      expect(find.text('25'), findsAtLeastNWidgets(1));
      expect(find.text('Acierto'), findsOneWidget);
    });
  });
}
