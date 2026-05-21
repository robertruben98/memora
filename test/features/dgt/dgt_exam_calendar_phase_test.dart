import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_exam_calendar_phase.dart';

/// Issue #187 (dgt-ux): tests para la matriz de fases del ramp-up al examen
/// DGT y su estado en la timeline. Funcion pura sin dependencias.
void main() {
  group('DgtExamPhase.forDays', () {
    test('days=0 -> repaso', () {
      expect(DgtExamPhase.forDays(0), DgtExamPhase.repaso);
    });

    test('days=1 -> repaso', () {
      expect(DgtExamPhase.forDays(1), DgtExamPhase.repaso);
    });

    test('days=2 -> repaso (limite superior)', () {
      expect(DgtExamPhase.forDays(2), DgtExamPhase.repaso);
    });

    test('days=3 -> simulacros (limite inferior)', () {
      expect(DgtExamPhase.forDays(3), DgtExamPhase.simulacros);
    });

    test('days=5 -> simulacros', () {
      expect(DgtExamPhase.forDays(5), DgtExamPhase.simulacros);
    });

    test('days=7 -> simulacros (limite superior)', () {
      expect(DgtExamPhase.forDays(7), DgtExamPhase.simulacros);
    });

    test('days=8 -> refuerzo (limite inferior)', () {
      expect(DgtExamPhase.forDays(8), DgtExamPhase.refuerzo);
    });

    test('days=10 -> refuerzo', () {
      expect(DgtExamPhase.forDays(10), DgtExamPhase.refuerzo);
    });

    test('days=20 -> refuerzo (limite superior)', () {
      expect(DgtExamPhase.forDays(20), DgtExamPhase.refuerzo);
    });

    test('days=21 -> temario (limite inferior)', () {
      expect(DgtExamPhase.forDays(21), DgtExamPhase.temario);
    });

    test('days=25 -> temario', () {
      expect(DgtExamPhase.forDays(25), DgtExamPhase.temario);
    });

    test('days=365 -> temario (mucho margen)', () {
      expect(DgtExamPhase.forDays(365), DgtExamPhase.temario);
    });

    test('days<0 -> null (examen pasado)', () {
      expect(DgtExamPhase.forDays(-1), isNull);
      expect(DgtExamPhase.forDays(-10), isNull);
    });
  });

  group('dgtExamPhaseStatus', () {
    test('current==null -> todo upcoming (caso examen pasado o sin fecha)', () {
      for (final p in DgtExamPhase.orderedTimeline()) {
        expect(
          dgtExamPhaseStatus(phase: p, current: null),
          DgtExamPhaseStatus.upcoming,
        );
      }
    });

    test('current=temario -> temario current, resto upcoming', () {
      expect(
        dgtExamPhaseStatus(
            phase: DgtExamPhase.temario, current: DgtExamPhase.temario),
        DgtExamPhaseStatus.current,
      );
      expect(
        dgtExamPhaseStatus(
            phase: DgtExamPhase.refuerzo, current: DgtExamPhase.temario),
        DgtExamPhaseStatus.upcoming,
      );
      expect(
        dgtExamPhaseStatus(
            phase: DgtExamPhase.simulacros, current: DgtExamPhase.temario),
        DgtExamPhaseStatus.upcoming,
      );
      expect(
        dgtExamPhaseStatus(
            phase: DgtExamPhase.repaso, current: DgtExamPhase.temario),
        DgtExamPhaseStatus.upcoming,
      );
    });

    test('current=refuerzo -> temario passed, refuerzo current, resto upcoming',
        () {
      expect(
        dgtExamPhaseStatus(
            phase: DgtExamPhase.temario, current: DgtExamPhase.refuerzo),
        DgtExamPhaseStatus.passed,
      );
      expect(
        dgtExamPhaseStatus(
            phase: DgtExamPhase.refuerzo, current: DgtExamPhase.refuerzo),
        DgtExamPhaseStatus.current,
      );
      expect(
        dgtExamPhaseStatus(
            phase: DgtExamPhase.simulacros, current: DgtExamPhase.refuerzo),
        DgtExamPhaseStatus.upcoming,
      );
      expect(
        dgtExamPhaseStatus(
            phase: DgtExamPhase.repaso, current: DgtExamPhase.refuerzo),
        DgtExamPhaseStatus.upcoming,
      );
    });

    test('current=repaso -> todo lo anterior passed', () {
      expect(
        dgtExamPhaseStatus(
            phase: DgtExamPhase.temario, current: DgtExamPhase.repaso),
        DgtExamPhaseStatus.passed,
      );
      expect(
        dgtExamPhaseStatus(
            phase: DgtExamPhase.refuerzo, current: DgtExamPhase.repaso),
        DgtExamPhaseStatus.passed,
      );
      expect(
        dgtExamPhaseStatus(
            phase: DgtExamPhase.simulacros, current: DgtExamPhase.repaso),
        DgtExamPhaseStatus.passed,
      );
      expect(
        dgtExamPhaseStatus(
            phase: DgtExamPhase.repaso, current: DgtExamPhase.repaso),
        DgtExamPhaseStatus.current,
      );
    });
  });

  group('orderedTimeline', () {
    test('orden visual: temario -> refuerzo -> simulacros -> repaso', () {
      expect(DgtExamPhase.orderedTimeline(), [
        DgtExamPhase.temario,
        DgtExamPhase.refuerzo,
        DgtExamPhase.simulacros,
        DgtExamPhase.repaso,
      ]);
    });
  });
}
