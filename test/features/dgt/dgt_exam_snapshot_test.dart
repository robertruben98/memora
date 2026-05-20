import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/repositories/dgt_repository.dart';
import 'package:memora/features/dgt/dgt_exam_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue #133 (dgt-ux): tests del serializer/deserializer del snapshot del
/// simulacro DGT y del repo de persistencia.
///
/// El JSON roundtrip debe preservar: preguntas (incluyendo enunciado /
/// imageUrl / opciones / correct / explanation / topic), respuestas
/// (indice -> letra), flagged set, currentIndex, secondsRemaining y
/// startedAt. Tests adicionales cubren snapshot corrupto, vacio y clear().

List<DgtQuestion> _seed(int n) {
  return List.generate(n, (i) {
    return DgtQuestion(
      id: 'q$i',
      statement: 'Enunciado $i',
      optionA: 'A$i',
      optionB: 'B$i',
      optionC: 'C$i',
      correct: ['a', 'b', 'c'][i % 3],
      imageUrl: i.isEven ? '/img/$i.jpg' : null,
      explanation: i == 0 ? 'Porque si' : null,
      topic: 'topic-${i % 5}',
    );
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('DgtExamSnapshot json roundtrip preserva todo el estado', () {
    final qs = _seed(3);
    final started = DateTime.parse('2026-05-20T10:30:00.000Z');
    final original = DgtExamSnapshot(
      questions: qs,
      answers: {0: 'a', 2: 'c'},
      flagged: {1},
      currentIndex: 2,
      secondsRemaining: 1234,
      startedAt: started,
    );

    final j = original.toJson();
    final round = DgtExamSnapshot.tryFromJson(j);

    expect(round, isNotNull);
    expect(round!.questions.length, 3);
    expect(round.questions[0].id, 'q0');
    expect(round.questions[0].statement, 'Enunciado 0');
    expect(round.questions[0].optionA, 'A0');
    expect(round.questions[0].optionB, 'B0');
    expect(round.questions[0].optionC, 'C0');
    expect(round.questions[0].correct, 'a');
    expect(round.questions[0].imageUrl, '/img/0.jpg');
    expect(round.questions[0].explanation, 'Porque si');
    expect(round.questions[0].topic, 'topic-0');
    expect(round.questions[1].imageUrl, isNull);
    expect(round.questions[1].explanation, isNull);
    expect(round.answers, {0: 'a', 2: 'c'});
    expect(round.flagged, {1});
    expect(round.currentIndex, 2);
    expect(round.secondsRemaining, 1234);
    expect(round.startedAt, started);
    expect(round.answeredCount, 2);
    expect(round.totalCount, 3);
  });

  test('DgtExamSnapshot.tryFromJson devuelve null si questions vacio', () {
    final j = {
      'questions': <Map<String, dynamic>>[],
      'answers': <String, String>{},
      'flagged': <int>[],
      'currentIndex': 0,
      'secondsRemaining': 1800,
      'startedAt': DateTime.now().toIso8601String(),
    };
    expect(DgtExamSnapshot.tryFromJson(j), isNull);
  });

  test('DgtExamSnapshot.tryFromJson clamps currentIndex out-of-range', () {
    final qs = _seed(2);
    final j = DgtExamSnapshot(
      questions: qs,
      answers: const {},
      flagged: const {},
      currentIndex: 0,
      secondsRemaining: 60,
      startedAt: DateTime.now(),
    ).toJson();
    // Forzar currentIndex fuera de rango y secondsRemaining negativo.
    j['currentIndex'] = 99;
    j['secondsRemaining'] = -10;
    final round = DgtExamSnapshot.tryFromJson(j);
    expect(round, isNotNull);
    expect(round!.currentIndex, 1); // clamped a length-1
    expect(round.secondsRemaining, 0); // clamped a >= 0
  });

  test('DgtExamSnapshotRepository save + read devuelve snapshot identico',
      () async {
    final repo = DgtExamSnapshotRepository();
    final snap = DgtExamSnapshot(
      questions: _seed(2),
      answers: {0: 'b'},
      flagged: const {},
      currentIndex: 0,
      secondsRemaining: 1700,
      startedAt: DateTime.parse('2026-05-20T09:00:00.000Z'),
    );

    expect(await repo.hasPending(), isFalse);
    await repo.save(snap);
    expect(await repo.hasPending(), isTrue);

    final got = await repo.read();
    expect(got, isNotNull);
    expect(got!.questions.length, 2);
    expect(got.answers, {0: 'b'});
    expect(got.secondsRemaining, 1700);
    expect(got.startedAt, snap.startedAt);
  });

  test('DgtExamSnapshotRepository clear() borra el snapshot persistido',
      () async {
    final repo = DgtExamSnapshotRepository();
    await repo.save(
      DgtExamSnapshot(
        questions: _seed(1),
        answers: const {},
        flagged: const {},
        currentIndex: 0,
        secondsRemaining: 10,
        startedAt: DateTime.now(),
      ),
    );
    expect(await repo.read(), isNotNull);
    await repo.clear();
    expect(await repo.read(), isNull);
    expect(await repo.hasPending(), isFalse);
  });

  test('DgtExamSnapshotRepository.read() devuelve null si SharedPrefs vacio',
      () async {
    final repo = DgtExamSnapshotRepository();
    expect(await repo.read(), isNull);
    expect(await repo.hasPending(), isFalse);
  });

  test('DgtExamSnapshotRepository.read() devuelve null si raw es corrupto',
      () async {
    SharedPreferences.setMockInitialValues({
      'dgt.exam_in_progress.v1': '{not valid json',
    });
    final repo = DgtExamSnapshotRepository();
    expect(await repo.read(), isNull);
  });
}
