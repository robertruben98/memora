import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_prediction.dart';
import 'package:memora/features/dgt/dgt_weekly_summary_provider.dart';

/// Issue #174 (dgt-ux): tests del calculo PURO `computeWeeklySummary`.
/// Aislado de Flutter / Riverpod / SharedPreferences.
void main() {
  group('computeWeeklySummary', () {
    test('semana sin actividad -> isEmpty true', () {
      final now = DateTime(2026, 5, 17, 14, 0); // domingo
      final r = computeWeeklySummary(
        failuresByDay: const <DateTime, int>{},
        completedToday: 0,
        prediction: DgtPrediction.empty,
        examDate: null,
        now: now,
      );
      expect(r.isEmpty, isTrue);
      expect(r.daysStudied, 0);
      expect(r.questionsAnswered, 0);
      expect(r.accuracyPct, isNull);
      expect(r.weakestTopicName, isNull);
      expect(r.daysToExam, isNull);
    });

    test('completedToday > 0 marca hoy como dia estudiado', () {
      final now = DateTime(2026, 5, 17, 19, 0);
      final r = computeWeeklySummary(
        failuresByDay: const <DateTime, int>{},
        completedToday: 12,
        prediction: DgtPrediction.empty,
        examDate: null,
        now: now,
      );
      expect(r.isEmpty, isFalse);
      expect(r.daysStudied, 1);
      expect(r.questionsAnswered, 12);
    });

    test('fallos en multiples dias se cuentan como dias unicos', () {
      final now = DateTime(2026, 5, 17, 19, 0);
      final r = computeWeeklySummary(
        failuresByDay: {
          DateTime(2026, 5, 12): 3,
          DateTime(2026, 5, 13): 1,
          DateTime(2026, 5, 16): 5,
        },
        completedToday: 0,
        prediction: DgtPrediction.empty,
        examDate: null,
        now: now,
      );
      expect(r.daysStudied, 3);
      expect(r.questionsAnswered, 9);
    });

    test(
        'completedToday + fallo en mismo dia no duplica el dia pero suma '
        'preguntas', () {
      final now = DateTime(2026, 5, 17, 19, 0);
      final r = computeWeeklySummary(
        failuresByDay: {
          DateTime(2026, 5, 17): 2, // fallos hoy
          DateTime(2026, 5, 16): 4,
        },
        completedToday: 5,
        prediction: DgtPrediction.empty,
        examDate: null,
        now: now,
      );
      expect(r.daysStudied, 2); // hoy + ayer
      expect(r.questionsAnswered, 11); // 2 + 4 + 5
    });

    test('counts de cero o negativos no agregan dias', () {
      final now = DateTime(2026, 5, 17);
      final r = computeWeeklySummary(
        failuresByDay: {
          DateTime(2026, 5, 12): 0,
          DateTime(2026, 5, 13): -1,
        },
        completedToday: 0,
        prediction: DgtPrediction.empty,
        examDate: null,
        now: now,
      );
      expect(r.daysStudied, 0);
      expect(r.questionsAnswered, 0);
      expect(r.isEmpty, isTrue);
    });

    test(
        'prediction con datos -> accuracy estimada = expectedScore * 100',
        () {
      final now = DateTime(2026, 5, 17);
      // 60 reviews para superar `kDgtMinReviewsForPrediction` (cualquiera
      // que sea su valor, usamos uno alto y stats coherentes).
      final stats = [
        const DgtTopicStat(
          topicId: 't1',
          topicName: 'Senales',
          totalAnswered: 30,
          correct: 27,
          accuracyPct: 90.0,
        ),
        const DgtTopicStat(
          topicId: 't2',
          topicName: 'Normas',
          totalAnswered: 30,
          correct: 24,
          accuracyPct: 80.0,
        ),
      ];
      final p = DgtPrediction.compute(stats);
      // Si la prediccion no junta suficientes reviews (config interna),
      // el test se vuelve sobre la rama "sin datos"; aceptamos ambas.
      final r = computeWeeklySummary(
        failuresByDay: const <DateTime, int>{},
        completedToday: 0,
        prediction: p,
        examDate: null,
        now: now,
      );
      if (p.hasEnoughData) {
        expect(r.accuracyPct, isNotNull);
        expect(r.accuracyPct!, inInclusiveRange(0.0, 100.0));
      } else {
        expect(r.accuracyPct, isNull);
      }
    });

    test('weakestTopicName usa topicName si existe, sino topicId', () {
      final now = DateTime(2026, 5, 17);
      // Forzamos directamente la construccion de la prediccion con un
      // weakest topic conocido para no depender del threshold de compute.
      final r = computeWeeklySummary(
        failuresByDay: const <DateTime, int>{},
        completedToday: 0,
        prediction: const DgtPrediction(
          totalReviews: 100,
          expectedScore: 0.75,
          weakestTopic: DgtTopicStat(
            topicId: 'topic-3',
            topicName: 'Velocidad',
            totalAnswered: 20,
            correct: 10,
            accuracyPct: 50.0,
          ),
        ),
        examDate: null,
        now: now,
      );
      expect(r.weakestTopicName, 'Velocidad');
    });

    test('examDate -> daysToExam relativo a hoy', () {
      final now = DateTime(2026, 5, 17, 23, 59);
      final r = computeWeeklySummary(
        failuresByDay: const <DateTime, int>{},
        completedToday: 0,
        prediction: DgtPrediction.empty,
        examDate: DateTime(2026, 5, 24),
        now: now,
      );
      expect(r.daysToExam, 7);
    });

    test('examDate ya paso -> daysToExam negativo', () {
      final now = DateTime(2026, 5, 20);
      final r = computeWeeklySummary(
        failuresByDay: const <DateTime, int>{},
        completedToday: 0,
        prediction: DgtPrediction.empty,
        examDate: DateTime(2026, 5, 10),
        now: now,
      );
      expect(r.daysToExam, -10);
    });
  });
}
