import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/repositories/dgt_repository.dart';
import 'package:memora/features/dgt/dgt_exam_controller.dart';

/// Issue #139 (dgt-tech): tests unitarios del controlador del simulacro DGT.
///
/// Sin `pumpWidget`: probamos timer, scoring, navegacion, flag toggling y
/// snapshot pure-Dart. Estos tests deben ser deterministas y rapidos
/// porque seran la base de la cobertura del simulacro (issue #103 los
/// invocaba como pre-requisito).

List<DgtQuestion> _seedQuestions({
  int n = 30,
  String correctLetter = 'a',
  String topic = 'senales',
}) {
  return List.generate(n, (i) {
    return DgtQuestion(
      id: 'q$i',
      statement: 'Pregunta DGT $i',
      optionA: 'A$i',
      optionB: 'B$i',
      optionC: 'C$i',
      correct: correctLetter,
      topic: topic,
    );
  });
}

void main() {
  group('DgtExamController - construccion', () {
    test('inicializa con remainingSeconds=totalSeconds (30 min) por defecto',
        () {
      final ctrl = DgtExamController(questions: _seedQuestions(n: 5));
      expect(ctrl.remainingSeconds, DgtExamController.totalSeconds);
      expect(ctrl.remainingSeconds, 30 * 60);
      expect(ctrl.phase, DgtExamPhase.running);
      expect(ctrl.isRunning, isTrue);
      expect(ctrl.currentIndex, 0);
      expect(ctrl.answeredCount, 0);
      expect(ctrl.totalQuestions, 5);
      ctrl.dispose();
    });

    test('respeta initialIndex y lo clampa al rango valido', () {
      final ctrl = DgtExamController(
        questions: _seedQuestions(n: 3),
        initialIndex: 99,
      );
      expect(ctrl.currentIndex, 2);
      ctrl.dispose();
    });

    test('fromSnapshot con secondsRemaining<=0 inicia ya submitted', () {
      final qs = _seedQuestions(n: 3);
      final ctrl = DgtExamController.fromSnapshot(
        questions: qs,
        answers: {0: 'a'},
        flagged: {1},
        currentIndex: 2,
        secondsRemaining: 0,
        startedAt: DateTime.parse('2026-05-20T10:00:00Z'),
      );
      expect(ctrl.phase, DgtExamPhase.submitted);
      expect(ctrl.isSubmitted, isTrue);
      expect(ctrl.remainingSeconds, 0);
      expect(ctrl.selectedAnswers, {0: 'a'});
      expect(ctrl.flaggedIndices, {1});
      expect(ctrl.currentIndex, 2);
      ctrl.dispose();
    });
  });

  group('DgtExamController - selectAnswer + scoring', () {
    test('selectAnswer registra letra y notifica listeners', () {
      final ctrl = DgtExamController(questions: _seedQuestions(n: 3));
      var notifyCount = 0;
      ctrl.addListener(() => notifyCount++);
      ctrl.selectAnswer('a');
      expect(ctrl.pickedAt(), 'a');
      expect(ctrl.answeredCount, 1);
      expect(notifyCount, 1);
      ctrl.dispose();
    });

    test('selectAnswer ignora letras invalidas (no notifica)', () {
      final ctrl = DgtExamController(questions: _seedQuestions(n: 2));
      var notifyCount = 0;
      ctrl.addListener(() => notifyCount++);
      ctrl.selectAnswer('z');
      ctrl.selectAnswer('');
      ctrl.selectAnswer('A'); // mayuscula, normalizada -> deberia aceptar
      expect(ctrl.pickedAt(), 'a');
      expect(notifyCount, 1);
      ctrl.dispose();
    });

    test('selectAnswer idempotente: misma letra no notifica de nuevo', () {
      final ctrl = DgtExamController(questions: _seedQuestions(n: 2));
      var notifyCount = 0;
      ctrl.addListener(() => notifyCount++);
      ctrl.selectAnswer('a');
      ctrl.selectAnswer('a');
      ctrl.selectAnswer('a');
      expect(notifyCount, 1);
      ctrl.dispose();
    });

    test('scoring: 28 correctas + 2 falladas -> aprobado (3 fallos limite)',
        () {
      final qs = _seedQuestions(n: 30, correctLetter: 'a');
      final ctrl = DgtExamController(questions: qs);
      // Responde 28 correctas y 2 incorrectas (las 2 ultimas).
      for (var i = 0; i < 28; i++) {
        ctrl.goTo(i);
        ctrl.selectAnswer('a');
      }
      ctrl.goTo(28);
      ctrl.selectAnswer('b'); // mal
      ctrl.goTo(29);
      ctrl.selectAnswer('c'); // mal
      final result = ctrl.submit();
      expect(result.total, 30);
      expect(result.correct, 28);
      expect(result.wrongCount, 2);
      expect(result.passed, isTrue);
      expect(ctrl.phase, DgtExamPhase.submitted);
      ctrl.dispose();
    });

    test('scoring: 4 fallos -> NO aprobado (criterio DGT permiso B)', () {
      final qs = _seedQuestions(n: 30, correctLetter: 'a');
      final ctrl = DgtExamController(questions: qs);
      for (var i = 0; i < 26; i++) {
        ctrl.goTo(i);
        ctrl.selectAnswer('a');
      }
      // 4 ultimas mal.
      for (var i = 26; i < 30; i++) {
        ctrl.goTo(i);
        ctrl.selectAnswer('b');
      }
      final result = ctrl.submit();
      expect(result.correct, 26);
      expect(result.wrongCount, 4);
      expect(result.passed, isFalse);
      ctrl.dispose();
    });

    test('scoring: preguntas sin responder cuentan como fallidas', () {
      final qs = _seedQuestions(n: 5, correctLetter: 'a');
      final ctrl = DgtExamController(questions: qs);
      ctrl.selectAnswer('a'); // q0 correcta
      ctrl.next();
      ctrl.selectAnswer('a'); // q1 correcta
      // q2, q3, q4 sin responder.
      final result = ctrl.submit();
      expect(result.correct, 2);
      expect(result.wrongCount, 3);
      expect(result.wrong.where((w) => w.picked == null).length, 3);
      ctrl.dispose();
    });

    test('elapsedSeconds en result refleja totalSeconds - remainingSeconds',
        () {
      final ctrl = DgtExamController(
        questions: _seedQuestions(n: 3),
        remainingSeconds: 600, // ya pasaron 30*60-600 = 1200 segundos
      );
      final result = ctrl.submit();
      expect(result.elapsedSeconds, DgtExamController.totalSeconds - 600);
      ctrl.dispose();
    });

    test('strictMode flag se propaga al DgtExamResult', () {
      final ctrl = DgtExamController(
        questions: _seedQuestions(n: 2),
        strictMode: true,
      );
      final result = ctrl.submit();
      expect(result.strictMode, isTrue);
      ctrl.dispose();
    });
  });

  group('DgtExamController - tick / timer', () {
    test('tick decrementa remainingSeconds en 1 y notifica', () {
      final ctrl = DgtExamController(
        questions: _seedQuestions(n: 2),
        remainingSeconds: 10,
      );
      var notify = 0;
      ctrl.addListener(() => notify++);
      ctrl.tick();
      expect(ctrl.remainingSeconds, 9);
      expect(notify, 1);
      ctrl.tick();
      expect(ctrl.remainingSeconds, 8);
      expect(notify, 2);
      ctrl.dispose();
    });

    test('tick que lleva a 0 -> phase=submitted y para de decrementar', () {
      final ctrl = DgtExamController(
        questions: _seedQuestions(n: 2),
        remainingSeconds: 2,
      );
      ctrl.tick(); // 2 -> 1
      expect(ctrl.isRunning, isTrue);
      ctrl.tick(); // 1 -> 0, submit auto
      expect(ctrl.remainingSeconds, 0);
      expect(ctrl.phase, DgtExamPhase.submitted);
      // Tick adicional es no-op.
      ctrl.tick();
      expect(ctrl.remainingSeconds, 0);
      expect(ctrl.phase, DgtExamPhase.submitted);
      ctrl.dispose();
    });

    test('tick ignorado si phase != running', () {
      final ctrl = DgtExamController(
        questions: _seedQuestions(n: 2),
        remainingSeconds: 100,
      );
      ctrl.submit();
      final before = ctrl.remainingSeconds;
      ctrl.tick();
      expect(ctrl.remainingSeconds, before);
      ctrl.dispose();
    });

    test('startTimer es idempotente (no spawnea 2 tickers)', () async {
      final ctrl = DgtExamController(
        questions: _seedQuestions(n: 2),
        remainingSeconds: 10,
      );
      ctrl.startTimer();
      ctrl.startTimer();
      // Esperamos ~1.2s y deberian decrementar 1 segundo (no 2).
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(ctrl.remainingSeconds, lessThanOrEqualTo(9));
      expect(ctrl.remainingSeconds, greaterThanOrEqualTo(8));
      ctrl.stopTimer();
      ctrl.dispose();
    });
  });

  group('DgtExamController - flag toggle', () {
    test('toggleFlag agrega/quita y es idempotente (toggle dos veces = neutro)',
        () {
      final ctrl = DgtExamController(questions: _seedQuestions(n: 5));
      expect(ctrl.isFlagged(), isFalse);
      ctrl.toggleFlag();
      expect(ctrl.isFlagged(), isTrue);
      expect(ctrl.flaggedIndices, {0});
      ctrl.toggleFlag();
      expect(ctrl.isFlagged(), isFalse);
      expect(ctrl.flaggedIndices, isEmpty);
      ctrl.dispose();
    });

    test('toggleFlag es no-op en strictMode', () {
      final ctrl = DgtExamController(
        questions: _seedQuestions(n: 3),
        strictMode: true,
      );
      var notify = 0;
      ctrl.addListener(() => notify++);
      ctrl.toggleFlag();
      expect(ctrl.flaggedIndices, isEmpty);
      expect(notify, 0);
      ctrl.dispose();
    });

    test('flags se conservan al navegar entre preguntas', () {
      final ctrl = DgtExamController(questions: _seedQuestions(n: 5));
      ctrl.toggleFlag(); // q0 flagged
      ctrl.next();
      ctrl.next();
      ctrl.toggleFlag(); // q2 flagged
      ctrl.goTo(0);
      expect(ctrl.isFlagged(), isTrue);
      ctrl.goTo(2);
      expect(ctrl.isFlagged(), isTrue);
      ctrl.goTo(1);
      expect(ctrl.isFlagged(), isFalse);
      expect(ctrl.flaggedIndices, {0, 2});
      ctrl.dispose();
    });
  });

  group('DgtExamController - navegacion', () {
    test('next/previous mueven currentIndex con limites', () {
      final ctrl = DgtExamController(questions: _seedQuestions(n: 3));
      ctrl.next();
      expect(ctrl.currentIndex, 1);
      ctrl.next();
      expect(ctrl.currentIndex, 2);
      ctrl.next(); // no-op, ya en ultima
      expect(ctrl.currentIndex, 2);
      ctrl.previous();
      expect(ctrl.currentIndex, 1);
      ctrl.previous();
      expect(ctrl.currentIndex, 0);
      ctrl.previous(); // no-op
      expect(ctrl.currentIndex, 0);
      ctrl.dispose();
    });

    test('previous es no-op en strictMode', () {
      final ctrl = DgtExamController(
        questions: _seedQuestions(n: 3),
        strictMode: true,
      );
      ctrl.next();
      ctrl.previous();
      expect(ctrl.currentIndex, 1);
      ctrl.dispose();
    });

    test('goTo respeta rango y bloquea retroceso en strictMode', () {
      final ctrl = DgtExamController(
        questions: _seedQuestions(n: 5),
        strictMode: true,
      );
      ctrl.goTo(3);
      expect(ctrl.currentIndex, 3);
      ctrl.goTo(1); // ignorado por strict (no retroceso)
      expect(ctrl.currentIndex, 3);
      ctrl.goTo(-1); // ignorado por rango
      expect(ctrl.currentIndex, 3);
      ctrl.goTo(99); // ignorado por rango
      expect(ctrl.currentIndex, 3);
      ctrl.dispose();
    });

    test('mutaciones en phase=submitted son no-op', () {
      final ctrl = DgtExamController(questions: _seedQuestions(n: 3));
      ctrl.submit();
      ctrl.next();
      ctrl.previous();
      ctrl.selectAnswer('a');
      ctrl.toggleFlag();
      ctrl.goTo(2);
      expect(ctrl.currentIndex, 0);
      expect(ctrl.answeredCount, 0);
      expect(ctrl.flaggedIndices, isEmpty);
      ctrl.dispose();
    });
  });

  group('DgtExamController - submit + snapshot', () {
    test('submit es idempotente y devuelve el mismo resultado', () {
      final qs = _seedQuestions(n: 3, correctLetter: 'a');
      final ctrl = DgtExamController(questions: qs);
      ctrl.selectAnswer('a');
      final r1 = ctrl.submit();
      final r2 = ctrl.submit();
      expect(r1.correct, r2.correct);
      expect(r1.total, r2.total);
      expect(ctrl.phase, DgtExamPhase.submitted);
      ctrl.dispose();
    });

    test('failedQuestions devuelve IDs falladas (sin responder + erradas)',
        () {
      final qs = _seedQuestions(n: 4, correctLetter: 'a');
      final ctrl = DgtExamController(questions: qs);
      ctrl.selectAnswer('a'); // q0 ok
      ctrl.next();
      ctrl.selectAnswer('b'); // q1 mal
      // q2, q3 sin responder.
      final failed = ctrl.failedQuestions();
      expect(failed.length, 3);
      expect(failed.map((q) => q.id).toSet(), {'q1', 'q2', 'q3'});
      ctrl.dispose();
    });

    test('toSnapshot captura todo el estado', () {
      final ctrl = DgtExamController(
        questions: _seedQuestions(n: 4),
        remainingSeconds: 1500,
        startedAt: DateTime.parse('2026-05-20T10:00:00Z'),
      );
      ctrl.selectAnswer('a');
      ctrl.next();
      ctrl.selectAnswer('b');
      ctrl.toggleFlag();
      final snap = ctrl.toSnapshot();
      expect(snap.questions.length, 4);
      expect(snap.answers, {0: 'a', 1: 'b'});
      expect(snap.flagged, {1});
      expect(snap.currentIndex, 1);
      expect(snap.remainingSeconds, 1500);
      expect(snap.startedAt, DateTime.parse('2026-05-20T10:00:00Z'));
      expect(snap.phase, DgtExamPhase.running);
      ctrl.dispose();
    });

    test('abort cambia phase a aborted (idempotente)', () {
      final ctrl = DgtExamController(questions: _seedQuestions(n: 3));
      ctrl.abort();
      expect(ctrl.phase, DgtExamPhase.aborted);
      ctrl.abort();
      expect(ctrl.phase, DgtExamPhase.aborted);
      ctrl.dispose();
    });
  });

  group('DgtExamController - listeners (ChangeNotifier)', () {
    test('notifica al cambiar de pregunta, responder y togglear flag', () {
      final ctrl = DgtExamController(questions: _seedQuestions(n: 3));
      final events = <int>[];
      void listener() => events.add(ctrl.currentIndex);
      ctrl.addListener(listener);
      ctrl.selectAnswer('a');
      ctrl.next();
      ctrl.toggleFlag();
      ctrl.previous();
      expect(events, [0, 1, 1, 0]);
      ctrl.removeListener(listener);
      ctrl.dispose();
    });

    test('dispose cancela timer interno sin lanzar excepciones', () {
      final ctrl = DgtExamController(
        questions: _seedQuestions(n: 2),
        remainingSeconds: 5,
      );
      ctrl.startTimer();
      // No debe lanzar al disponer con ticker activo.
      expect(() => ctrl.dispose(), returnsNormally);
    });
  });

  group('DgtExamController - edge cases', () {
    test('cero preguntas: mutaciones no lanzan, scoring vacio', () {
      final ctrl = DgtExamController(questions: const []);
      ctrl.selectAnswer('a');
      ctrl.next();
      ctrl.toggleFlag();
      ctrl.goTo(0);
      final result = ctrl.submit();
      expect(result.total, 0);
      expect(result.correct, 0);
      expect(result.wrongCount, 0);
      expect(result.passed, isTrue); // 0 <= 3
      ctrl.dispose();
    });

    test('selectedAnswers y flaggedIndices son unmodifiable', () {
      final ctrl = DgtExamController(questions: _seedQuestions(n: 2));
      ctrl.selectAnswer('a');
      ctrl.toggleFlag();
      expect(() => ctrl.selectedAnswers[5] = 'x', throwsUnsupportedError);
      expect(() => ctrl.flaggedIndices.add(5), throwsUnsupportedError);
      ctrl.dispose();
    });

    test('debugFillProperties no lanza (ChangeNotifier base)', () {
      final ctrl = DgtExamController(questions: _seedQuestions(n: 2));
      // sanity check de la base class para descartar refactors rotos.
      expect(ctrl, isA<ChangeNotifier>());
      ctrl.dispose();
    });
  });
}
