import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_sprint_history_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue #152 (dgt-ux): cobertura del historial local del Sprint diario.
/// - Persistencia / hidratacion desde SharedPreferences.
/// - Regla 1 sprint por dia (record rechaza duplicado).
/// - Trim al maximo permitido.
/// - Calculo de media personal y deteccion de "sprint de hoy".

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer makeContainer() => ProviderContainer();

  Future<DgtSprintHistoryState> readHistory(ProviderContainer c) async {
    // Forzar inicializacion del provider y dejar que microtasks de _load()
    // se completen. Hacemos varios pumps de microtask con yield.
    c.read(dgtSprintHistoryProvider);
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return c.read(dgtSprintHistoryProvider);
  }

  test('estado inicial vacio cuando no hay datos', () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    final state = await readHistory(c);
    expect(state.entries, isEmpty);
    expect(state.averageCorrect, 0);
    expect(state.todayEntry(), isNull);
  });

  test('hidrata desde SharedPreferences en orden descendente', () async {
    final now = DateTime(2026, 5, 21, 9, 0);
    final ayer = now.subtract(const Duration(days: 1));
    final entries = [
      // Guardadas en orden antiguo -> nuevo. El notifier debe ordenarlas
      // nuevo -> antiguo al hidratar.
      {
        'ts': ayer.toUtc().toIso8601String(),
        'total': 10,
        'correct': 6,
        'seconds_used': 110,
      },
      {
        'ts': now.toUtc().toIso8601String(),
        'total': 10,
        'correct': 9,
        'seconds_used': 90,
      },
    ];
    SharedPreferences.setMockInitialValues({
      kDgtSprintHistoryPrefsKey: jsonEncode(entries),
    });

    final c = makeContainer();
    addTearDown(c.dispose);
    final state = await readHistory(c);

    expect(state.entries.length, 2);
    expect(state.entries.first.correct, 9);
    expect(state.entries.last.correct, 6);
    expect(state.averageCorrect, closeTo(7.5, 0.001));
  });

  test('record guarda y persiste la entrada', () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    await readHistory(c);

    final entry = DgtSprintEntry(
      timestamp: DateTime(2026, 5, 21, 12),
      total: 10,
      correct: 8,
      secondsUsed: 95,
    );
    final ok =
        await c.read(dgtSprintHistoryProvider.notifier).record(entry);
    expect(ok, isTrue);
    expect(c.read(dgtSprintHistoryProvider).entries.length, 1);

    // Releemos persistencia para validar que se escribio.
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kDgtSprintHistoryPrefsKey);
    expect(raw, isNotNull);
    final decoded = jsonDecode(raw!) as List;
    expect(decoded.length, 1);
    expect((decoded.first as Map)['correct'], 8);
  });

  test('record rechaza segundo sprint del mismo dia (regla 1/dia)',
      () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    await readHistory(c);

    final today = DateTime(2026, 5, 21, 9);
    final first = DgtSprintEntry(
      timestamp: today,
      total: 10,
      correct: 8,
      secondsUsed: 100,
    );
    final second = DgtSprintEntry(
      timestamp: today.add(const Duration(hours: 5)),
      total: 10,
      correct: 3,
      secondsUsed: 120,
    );

    expect(
      await c.read(dgtSprintHistoryProvider.notifier).record(first),
      isTrue,
    );
    expect(
      await c.read(dgtSprintHistoryProvider.notifier).record(second),
      isFalse,
    );

    final state = c.read(dgtSprintHistoryProvider);
    expect(state.entries.length, 1);
    expect(state.entries.first.correct, 8); // se mantiene el primero
  });

  test('todayEntry devuelve sprint del mismo dia local', () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    await readHistory(c);

    final today = DateTime(2026, 5, 21, 7);
    await c.read(dgtSprintHistoryProvider.notifier).record(
          DgtSprintEntry(
            timestamp: today,
            total: 10,
            correct: 7,
            secondsUsed: 80,
          ),
        );
    final state = c.read(dgtSprintHistoryProvider);
    expect(state.todayEntry(now: today), isNotNull);
    expect(
      state.todayEntry(now: today.add(const Duration(days: 1))),
      isNull,
    );
  });

  test('record respeta limite kDgtSprintHistoryMax', () async {
    // Pre-popular kDgtSprintHistoryMax entradas en distintos dias.
    final raw = <Map<String, dynamic>>[];
    for (var i = 0; i < kDgtSprintHistoryMax; i++) {
      final ts = DateTime(2026, 4, 1).add(Duration(days: i));
      raw.add({
        'ts': ts.toUtc().toIso8601String(),
        'total': 10,
        'correct': i % 10,
        'seconds_used': 100,
      });
    }
    SharedPreferences.setMockInitialValues({
      kDgtSprintHistoryPrefsKey: jsonEncode(raw),
    });

    final c = makeContainer();
    addTearDown(c.dispose);
    await readHistory(c);
    expect(
      c.read(dgtSprintHistoryProvider).entries.length,
      kDgtSprintHistoryMax,
    );

    // Agregamos un sprint en un dia totalmente nuevo: debe trim a Max.
    final newest = DateTime(2026, 6, 1);
    await c.read(dgtSprintHistoryProvider.notifier).record(
          DgtSprintEntry(
            timestamp: newest,
            total: 10,
            correct: 9,
            secondsUsed: 60,
          ),
        );
    final state = c.read(dgtSprintHistoryProvider);
    expect(state.entries.length, kDgtSprintHistoryMax);
    expect(state.entries.first.timestamp, newest);
  });

  test('passed se calcula con kDgtSprintPassThreshold', () {
    final good = DgtSprintEntry(
      timestamp: DateTime(2026, 5, 21),
      total: 10,
      correct: kDgtSprintPassThreshold,
      secondsUsed: 100,
    );
    final bad = DgtSprintEntry(
      timestamp: DateTime(2026, 5, 21),
      total: 10,
      correct: kDgtSprintPassThreshold - 1,
      secondsUsed: 100,
    );
    expect(good.passed, isTrue);
    expect(bad.passed, isFalse);
  });

  test('json malformado en SharedPreferences resulta en estado vacio',
      () async {
    SharedPreferences.setMockInitialValues({
      kDgtSprintHistoryPrefsKey: 'no es json valido',
    });
    final c = makeContainer();
    addTearDown(c.dispose);
    final state = await readHistory(c);
    expect(state.entries, isEmpty);
  });
}
