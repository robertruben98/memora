import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_prediction.dart';

/// Issue #52 (dgt-content): prediccion pre-simulacro DGT.
///
/// Cubre: score ponderado, thresholds verde/ambar/rojo, tema mas debil,
/// "sin datos" cuando <10 reviews, parser JSON tolerante, peso normalizado
/// cuando el usuario aun no ha tocado todos los temas.

DgtTopicStat _stat(
  String topicId, {
  required int total,
  required int correct,
  String? name,
}) {
  return DgtTopicStat(
    topicId: topicId,
    topicName: name,
    totalAnswered: total,
    correct: correct,
    accuracyPct: total > 0 ? (correct / total) * 100 : 0,
  );
}

void main() {
  group('DgtTopicStat.fromJson', () {
    test('parses payload del backend', () {
      final j = {
        'topic_id': 'dgt-t-01',
        'topic_name': 'Senales verticales',
        'total_answered': 12,
        'correct': 9,
        'accuracy_pct': 75.0,
        'last_review_at': 1700000000000,
      };
      final s = DgtTopicStat.fromJson(j);
      expect(s.topicId, 'dgt-t-01');
      expect(s.topicName, 'Senales verticales');
      expect(s.totalAnswered, 12);
      expect(s.correct, 9);
      expect(s.accuracyPct, 75.0);
      expect(s.accuracy, 0.75);
    });

    test('tolera campos faltantes/null', () {
      final s = DgtTopicStat.fromJson(const {});
      expect(s.topicId, '');
      expect(s.topicName, isNull);
      expect(s.totalAnswered, 0);
      expect(s.correct, 0);
      expect(s.accuracyPct, 0);
    });
  });

  group('computePrediction', () {
    test('lista vacia -> totalReviews=0, hasEnoughData=false', () {
      final p = computePrediction(const []);
      expect(p.totalReviews, 0);
      expect(p.hasEnoughData, isFalse);
      expect(p.weakest, isNull);
    });

    test('<10 reviews -> hasEnoughData=false aunque haya datos', () {
      final p = computePrediction([
        _stat('dgt-t-01', total: 5, correct: 5),
      ]);
      expect(p.totalReviews, 5);
      expect(p.hasEnoughData, isFalse);
    });

    test('usuario perfecto (100% en senales) -> verde ready, >=90%', () {
      // 30 respuestas, todas correctas, solo en senales (peso 30%).
      // Solo cubrimos senales: peso cubierto=0.30, weightedSum=0.30,
      // score = 0.30 / 0.30 = 1.0 -> 100%.
      final p = computePrediction([
        _stat('dgt-t-01', total: 30, correct: 30, name: 'Senales verticales'),
      ]);
      expect(p.totalReviews, 30);
      expect(p.hasEnoughData, isTrue);
      expect(p.expectedScore, 1.0);
      expect(p.probabilityPct, 100);
      expect(p.verdict, DgtPredictionVerdict.ready);
      expect(p.weakest?.topicId, 'dgt-t-01');
    });

    test('rango ambar (0.75-0.89) -> almost', () {
      // senales 80% -> score 0.80 (peso cubierto 0.30 / weighted 0.24)
      final p = computePrediction([
        _stat('dgt-t-01', total: 10, correct: 8),
      ]);
      expect(p.verdict, DgtPredictionVerdict.almost);
      expect(p.probabilityPct, 80);
    });

    test('rango rojo (<0.75) -> needsReview', () {
      // senales 50%
      final p = computePrediction([
        _stat('dgt-t-01', total: 20, correct: 10),
      ]);
      expect(p.verdict, DgtPredictionVerdict.needsReview);
      expect(p.expectedScore, closeTo(0.5, 1e-9));
    });

    test('score ponderado mezcla varios temas', () {
      // senales (peso 0.30) 100% acierto
      // normas/t08 (peso 0.15) 50% acierto
      // peso cubierto = 0.45. weighted = 0.30*1 + 0.15*0.5 = 0.375.
      // score = 0.375 / 0.45 = 0.8333... -> 83% -> almost.
      final p = computePrediction([
        _stat('dgt-t-01', total: 10, correct: 10),
        _stat('dgt-t-08', total: 10, correct: 5),
      ]);
      expect(p.expectedScore, closeTo(0.8333, 1e-3));
      expect(p.probabilityPct, 83);
      expect(p.verdict, DgtPredictionVerdict.almost);
      // weakest es el de menor accuracy
      expect(p.weakest?.topicId, 'dgt-t-08');
    });

    test('tema desconocido (no en weights) no contribuye al score', () {
      // tema fantasma con 100 reviews al 0% no debe arrastrar el score.
      // senales (peso 0.30) al 100%. tema-fantasma no tiene peso.
      // score = 0.30 * 1.0 / 0.30 = 1.0 -> ready.
      final p = computePrediction([
        _stat('dgt-t-01', total: 10, correct: 10),
        _stat('topic-unknown', total: 100, correct: 0),
      ]);
      expect(p.verdict, DgtPredictionVerdict.ready);
      // pero weakest sigue siendo el fantasma porque tiene la menor accuracy
      expect(p.weakest?.topicId, 'topic-unknown');
    });

    test('weakest ignora temas sin reviews', () {
      final p = computePrediction([
        _stat('dgt-t-01', total: 0, correct: 0),
        _stat('dgt-t-08', total: 5, correct: 3),
      ]);
      expect(p.weakest?.topicId, 'dgt-t-08');
    });

    test('threshold exacto 0.90 -> ready', () {
      // 9/10 senales -> 0.90 exacto
      final p = computePrediction([
        _stat('dgt-t-01', total: 10, correct: 9),
      ]);
      expect(p.expectedScore, closeTo(0.90, 1e-9));
      expect(p.verdict, DgtPredictionVerdict.ready);
    });

    test('threshold exacto 0.75 -> almost (no rojo)', () {
      // 75 / 100 senales -> 0.75 exacto
      final p = computePrediction([
        _stat('dgt-t-01', total: 100, correct: 75),
      ]);
      expect(p.expectedScore, closeTo(0.75, 1e-9));
      expect(p.verdict, DgtPredictionVerdict.almost);
    });
  });

  group('kDgtTopicWeights', () {
    test('pesos totales suman ~1.0 (con tolerancia por redondeo 0.0167)', () {
      final sum = kDgtTopicWeights.values.fold<double>(0, (a, b) => a + b);
      // 0.30+0.15+0.15+0.10+0.05+0.05+0.10+0.0167*6 = 1.0002
      expect(sum, closeTo(1.0, 0.005));
    });

    test('todos los topic ids son dgt-t-NN', () {
      for (final k in kDgtTopicWeights.keys) {
        expect(k, matches(RegExp(r'^dgt-t-\d{2}$')));
      }
    });
  });

  group('DgtPredictionVerdict extensions', () {
    test('label y color distintos por veredicto', () {
      expect(DgtPredictionVerdict.ready.label, 'Listo');
      expect(DgtPredictionVerdict.almost.label, 'Casi');
      expect(DgtPredictionVerdict.needsReview.label, 'Necesitas repaso');
      // Colores deben diferir
      expect(
        DgtPredictionVerdict.ready.color,
        isNot(equals(DgtPredictionVerdict.almost.color)),
      );
      expect(
        DgtPredictionVerdict.almost.color,
        isNot(equals(DgtPredictionVerdict.needsReview.color)),
      );
    });
  });
}
