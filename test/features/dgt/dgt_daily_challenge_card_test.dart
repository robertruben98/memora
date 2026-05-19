import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_daily_challenge_card.dart';
import 'package:memora/features/dgt/dgt_prediction.dart';

/// Issue #85 (dgt-ux): cubre la heuristica de seleccion del "tema de hoy"
/// y el formateo de la clave de cache diaria. Funciones puras sin Flutter.
void main() {
  group('dgtDailyChallengeKey', () {
    test('formatea YYYY-MM-DD con padding', () {
      expect(
        dgtDailyChallengeKey(DateTime(2026, 1, 5)),
        '${kDgtDailyChallengePrefix}2026-01-05',
      );
      expect(
        dgtDailyChallengeKey(DateTime(2026, 12, 31)),
        '${kDgtDailyChallengePrefix}2026-12-31',
      );
    });
  });

  group('pickDgtDailyChallengeTopic', () {
    test('lista vacia -> null', () {
      expect(pickDgtDailyChallengeTopic(const []), isNull);
    });

    test('solo topics sin respuestas -> null', () {
      final stats = [
        const DgtTopicStat(
          topicId: 'dgt-t-01',
          totalAnswered: 0,
          correct: 0,
          accuracyPct: 0,
        ),
      ];
      expect(pickDgtDailyChallengeTopic(stats), isNull);
    });

    test('elige el tema con menor accuracy si hay alguno bajo umbral', () {
      final stats = [
        const DgtTopicStat(
          topicId: 'dgt-t-01',
          totalAnswered: 10,
          correct: 5,
          accuracyPct: 50.0,
        ),
        const DgtTopicStat(
          topicId: 'dgt-t-02',
          totalAnswered: 10,
          correct: 4,
          accuracyPct: 40.0,
        ),
        const DgtTopicStat(
          topicId: 'dgt-t-03',
          totalAnswered: 10,
          correct: 9,
          accuracyPct: 90.0,
        ),
      ];
      final picked = pickDgtDailyChallengeTopic(stats);
      expect(picked, isNotNull);
      expect(picked!.topicId, 'dgt-t-02');
    });

    test('si todos >= umbral dominado, elige el menos practicado', () {
      final stats = [
        const DgtTopicStat(
          topicId: 'dgt-t-01',
          totalAnswered: 50,
          correct: 45,
          accuracyPct: 90.0,
        ),
        const DgtTopicStat(
          topicId: 'dgt-t-02',
          totalAnswered: 20,
          correct: 18,
          accuracyPct: 90.0,
        ),
        const DgtTopicStat(
          topicId: 'dgt-t-03',
          totalAnswered: 100,
          correct: 80,
          accuracyPct: 80.0,
        ),
      ];
      final picked = pickDgtDailyChallengeTopic(stats);
      expect(picked, isNotNull);
      expect(picked!.topicId, 'dgt-t-02');
    });

    test('ignora topics sin respuestas al elegir el mas debil', () {
      final stats = [
        const DgtTopicStat(
          topicId: 'dgt-t-01',
          totalAnswered: 0,
          correct: 0,
          accuracyPct: 0,
        ),
        const DgtTopicStat(
          topicId: 'dgt-t-02',
          totalAnswered: 5,
          correct: 3,
          accuracyPct: 60.0,
        ),
      ];
      final picked = pickDgtDailyChallengeTopic(stats);
      expect(picked, isNotNull);
      expect(picked!.topicId, 'dgt-t-02');
    });
  });
}
