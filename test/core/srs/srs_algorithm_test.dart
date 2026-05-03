import 'package:flutter_test/flutter_test.dart';
import 'package:memora/core/srs/srs_algorithm.dart';

void main() {
  group('SrsAlgorithm.computeNext', () {
    test('first correct review schedules 1 day, learning state', () {
      final r = SrsAlgorithm.computeNext(
        easeFactor: 2.5,
        repetitions: 0,
        intervalDays: 0,
        quality: SrsAlgorithm.qualityCorrect,
      );
      expect(r.repetitions, 1);
      expect(r.intervalDays, 1);
      expect(r.state, SrsCardState.learning);
      // q=4 -> ease delta is 0
      expect(r.easeFactor, closeTo(2.5, 1e-9));
    });

    test('second correct review schedules 6 days, transitions to reviewing',
        () {
      final r = SrsAlgorithm.computeNext(
        easeFactor: 2.5,
        repetitions: 1,
        intervalDays: 1,
        quality: SrsAlgorithm.qualityCorrect,
      );
      expect(r.repetitions, 2);
      expect(r.intervalDays, 6);
      expect(r.state, SrsCardState.reviewing);
    });

    test('third correct review multiplies by ease factor', () {
      final r = SrsAlgorithm.computeNext(
        easeFactor: 2.5,
        repetitions: 2,
        intervalDays: 6,
        quality: SrsAlgorithm.qualityCorrect,
      );
      expect(r.repetitions, 3);
      expect(r.intervalDays, 15); // 6 * 2.5
      expect(r.state, SrsCardState.reviewing);
    });

    test('failure resets repetitions and interval', () {
      final r = SrsAlgorithm.computeNext(
        easeFactor: 2.0,
        repetitions: 5,
        intervalDays: 30,
        quality: SrsAlgorithm.qualityIncorrect,
      );
      expect(r.repetitions, 0);
      expect(r.intervalDays, 1);
      expect(r.state, SrsCardState.learning);
    });

    test('failure drops ease factor by ~0.54', () {
      final r = SrsAlgorithm.computeNext(
        easeFactor: 2.5,
        repetitions: 3,
        intervalDays: 15,
        quality: SrsAlgorithm.qualityIncorrect,
      );
      // delta = 0.1 - 4 * (0.08 + 4 * 0.02) = 0.1 - 4*0.16 = -0.54
      expect(r.easeFactor, closeTo(1.96, 1e-9));
    });

    test('ease factor never drops below 1.3', () {
      var ease = 2.5;
      var reps = 5;
      var interval = 30;
      for (var i = 0; i < 10; i++) {
        final r = SrsAlgorithm.computeNext(
          easeFactor: ease,
          repetitions: reps,
          intervalDays: interval,
          quality: SrsAlgorithm.qualityIncorrect,
        );
        ease = r.easeFactor;
        reps = r.repetitions;
        interval = r.intervalDays;
        expect(ease, greaterThanOrEqualTo(SrsAlgorithm.minEaseFactor));
      }
      expect(ease, SrsAlgorithm.minEaseFactor);
    });

    test('quality=4 ("good") leaves ease factor unchanged', () {
      final r = SrsAlgorithm.computeNext(
        easeFactor: 2.5,
        repetitions: 4,
        intervalDays: 38,
        quality: SrsAlgorithm.qualityCorrect,
      );
      expect(r.easeFactor, closeTo(2.5, 1e-9));
    });

    test('successive correct reviews grow geometrically', () {
      var ease = 2.5;
      var reps = 0;
      var interval = 0;
      final intervals = <int>[];
      for (var i = 0; i < 5; i++) {
        final r = SrsAlgorithm.computeNext(
          easeFactor: ease,
          repetitions: reps,
          intervalDays: interval,
          quality: SrsAlgorithm.qualityCorrect,
        );
        ease = r.easeFactor;
        reps = r.repetitions;
        interval = r.intervalDays;
        intervals.add(interval);
      }
      expect(intervals, [1, 6, 15, 38, 95]);
    });

    test('first correct review -> learning; second -> reviewing', () {
      final r1 = SrsAlgorithm.computeNext(
        easeFactor: 2.5,
        repetitions: 0,
        intervalDays: 0,
        quality: SrsAlgorithm.qualityCorrect,
      );
      expect(r1.state, SrsCardState.learning);
      final r2 = SrsAlgorithm.computeNext(
        easeFactor: r1.easeFactor,
        repetitions: r1.repetitions,
        intervalDays: r1.intervalDays,
        quality: SrsAlgorithm.qualityCorrect,
      );
      expect(r2.state, SrsCardState.reviewing);
    });

    test('initialState returns sensible defaults', () {
      final s = SrsAlgorithm.initialState();
      expect(s.easeFactor, SrsAlgorithm.initialEaseFactor);
      expect(s.repetitions, 0);
      expect(s.intervalDays, 0);
      expect(s.state, SrsCardState.newCard);
    });
  });

  group('SrsCardState mapping', () {
    test('round-trip dbValue / fromDb', () {
      for (final s in SrsCardState.values) {
        expect(SrsCardState.fromDb(s.dbValue), s);
      }
    });

    test('unknown db value falls back to new', () {
      expect(SrsCardState.fromDb('unknown'), SrsCardState.newCard);
      expect(SrsCardState.fromDb(''), SrsCardState.newCard);
    });
  });
}
