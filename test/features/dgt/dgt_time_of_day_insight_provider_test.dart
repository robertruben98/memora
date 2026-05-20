import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_time_of_day_insight_provider.dart';

/// Issue #137 (dgt-ux): tests del calculo PURO de "tu mejor hora".
///
/// Cubre tres escenarios principales:
/// - Pocas reviews: insight sin franja ganadora (placeholder).
/// - Distribucion plana: edge insuficiente, sin franja ganadora.
/// - Franja claramente mejor: insight con bestBucketIndex + edgePct.
///
/// Funciones puras sin Flutter ni IO; usan DateTime local (mismo que
/// usaria el dispositivo en runtime).
void main() {
  /// Helper: crea sample con hora local fija en el dia 2026-05-19.
  DgtReviewSample sampleAt({
    required int hour,
    required bool correct,
    int minute = 0,
  }) {
    final dt = DateTime(2026, 5, 19, hour, minute);
    return DgtReviewSample(
      reviewedAtMs: dt.millisecondsSinceEpoch,
      correct: correct,
    );
  }

  group('computeTimeOfDayInsight', () {
    test('lista vacia -> empty insight, sin bestBucket', () {
      final r = computeTimeOfDayInsight(const []);
      expect(r.totalReviews, 0);
      expect(r.buckets, hasLength(kDgtTimeOfDayBuckets));
      for (final b in r.buckets) {
        expect(b.total, 0);
        expect(b.correct, 0);
        expect(b.accuracyPct, 0.0);
      }
      expect(r.bestBucketIndex, isNull);
      expect(r.edgePct, isNull);
      expect(r.hasEnoughData, isFalse);
    });

    test('pocas reviews (<min) -> sin franja ganadora aunque haya diferencia',
        () {
      final samples = <DgtReviewSample>[
        for (var i = 0; i < 5; i++) sampleAt(hour: 9, correct: true),
        for (var i = 0; i < 5; i++) sampleAt(hour: 22, correct: false),
      ];
      final r = computeTimeOfDayInsight(samples);
      expect(r.totalReviews, 10);
      expect(r.hasEnoughData, isFalse);
      expect(r.bestBucketIndex, isNull);
      // Pero los buckets si reflejan los datos crudos.
      expect(r.buckets[3].total, 5); // 09:00 cae en bucket 3 (09-12).
      expect(r.buckets[3].correct, 5);
      expect(r.buckets[7].total, 5); // 22:00 cae en bucket 7 (21-24).
      expect(r.buckets[7].correct, 0);
    });

    test('distribucion plana (todas franjas ~50%) -> sin franja ganadora', () {
      // 4 franjas con misma accuracy 50%, 10 reviews cada una.
      final samples = <DgtReviewSample>[
        for (final hour in [1, 7, 13, 19])
          for (var i = 0; i < 10; i++)
            sampleAt(hour: hour, correct: i % 2 == 0),
      ];
      final r = computeTimeOfDayInsight(samples);
      expect(r.totalReviews, 40);
      expect(r.hasEnoughData, isTrue);
      // Todas las franjas ocupadas tienen 50% -> edge=0 -> sin best.
      expect(r.bestBucketIndex, isNull);
      expect(r.edgePct, isNull);
    });

    test('franja claramente ganadora -> bestBucketIndex + edgePct > min', () {
      // Bucket 3 (09-12): 20 reviews, 18 aciertos -> 90%.
      // Bucket 7 (21-24): 15 reviews, 6 aciertos -> 40%.
      // Bucket 1 (03-06): 5 reviews, 2 aciertos -> 40%.
      // Total = 40 (>=30 min). Best = bucket 3 con 90%.
      final samples = <DgtReviewSample>[
        for (var i = 0; i < 20; i++) sampleAt(hour: 10, correct: i < 18),
        for (var i = 0; i < 15; i++) sampleAt(hour: 22, correct: i < 6),
        for (var i = 0; i < 5; i++) sampleAt(hour: 4, correct: i < 2),
      ];
      final r = computeTimeOfDayInsight(samples);
      expect(r.totalReviews, 40);
      expect(r.hasEnoughData, isTrue);
      expect(r.bestBucketIndex, 3);
      expect(r.bestBucket, isNotNull);
      expect(r.bestBucket!.accuracyPct, closeTo(90.0, 0.01));
      expect(r.edgePct, isNotNull);
      // Mediana de los demas (40, 40) = 40. Edge = 90-40 = 50.
      expect(r.edgePct, closeTo(50.0, 0.01));
    });

    test('un solo bucket con datos -> sin best (no hay con que comparar)', () {
      final samples = <DgtReviewSample>[
        for (var i = 0; i < 35; i++) sampleAt(hour: 10, correct: i % 2 == 0),
      ];
      final r = computeTimeOfDayInsight(samples);
      expect(r.totalReviews, 35);
      expect(r.hasEnoughData, isTrue);
      // Solo bucket 3 tiene datos -> no podemos comparar -> no best.
      expect(r.bestBucketIndex, isNull);
    });

    test('edge justo por debajo del minimo -> sin best (no llega al umbral)',
        () {
      // Bucket 3: 20 reviews, 11 aciertos -> 55%.
      // Bucket 7: 15 reviews, 8 aciertos -> ~53.3%.
      // Diff = 1.6 < 5 (min edge) -> sin best.
      final samples = <DgtReviewSample>[
        for (var i = 0; i < 20; i++) sampleAt(hour: 10, correct: i < 11),
        for (var i = 0; i < 15; i++) sampleAt(hour: 22, correct: i < 8),
      ];
      final r = computeTimeOfDayInsight(samples);
      expect(r.totalReviews, 35);
      expect(r.hasEnoughData, isTrue);
      expect(r.bestBucketIndex, isNull);
    });

    test('override minReviews permite calcular bestBucket con menos data', () {
      final samples = <DgtReviewSample>[
        for (var i = 0; i < 5; i++) sampleAt(hour: 10, correct: true),
        for (var i = 0; i < 5; i++) sampleAt(hour: 22, correct: false),
      ];
      final r = computeTimeOfDayInsight(
        samples,
        minReviews: 5,
        minEdgePct: 1.0,
      );
      // Nota: hasEnoughData usa la constante global (criterio UX) y por
      // eso queda false; pero el override permite que el compute calcule
      // la franja ganadora para tests deterministas.
      expect(r.bestBucketIndex, 3);
      expect(r.edgePct, 100.0); // 100% vs 0%.
    });
  });

  group('DgtTimeOfDayBucket labels', () {
    test('formato HH-HH con padding', () {
      const b0 = DgtTimeOfDayBucket(index: 0, total: 0, correct: 0);
      const b3 = DgtTimeOfDayBucket(index: 3, total: 0, correct: 0);
      const b7 = DgtTimeOfDayBucket(index: 7, total: 0, correct: 0);
      expect(b0.label, '00-03');
      expect(b3.label, '09-12');
      expect(b7.label, '21-24');
    });

    test('accuracy=0 cuando total=0 (sin div por cero)', () {
      const b = DgtTimeOfDayBucket(index: 0, total: 0, correct: 0);
      expect(b.accuracyPct, 0.0);
    });

    test('accuracy correcta cuando total>0', () {
      const b = DgtTimeOfDayBucket(index: 0, total: 4, correct: 3);
      expect(b.accuracyPct, 75.0);
    });
  });
}
