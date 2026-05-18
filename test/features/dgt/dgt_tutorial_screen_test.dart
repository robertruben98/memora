// Tests para DgtTutorialScreen (issue #68).
//
// Cubre:
//  - settings_dao set/get del flag dgt_tutorial_seen
//  - markDgtTutorialSeen / isDgtTutorialSeen helpers
//  - render de las 3 paginas + tap en "Saltar"
//  - el callback onDone se dispara al saltar

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memora/data/database/database.dart';
import 'package:memora/features/dgt/dgt_tutorial_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('dgt_tutorial_seen flag (SettingsDao)', () {
    late MemoraDatabase db;

    setUp(() {
      db = MemoraDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('isDgtTutorialSeen returns false when flag is absent', () async {
      expect(await isDgtTutorialSeen(db), isFalse);
    });

    test('markDgtTutorialSeen persists "1" and isDgtTutorialSeen reads it',
        () async {
      await markDgtTutorialSeen(db);
      expect(await db.settingsDao.getValue(dgtTutorialSeenKey), '1');
      expect(await isDgtTutorialSeen(db), isTrue);
    });

    test('isDgtTutorialSeen returns false for any non-"1" value', () async {
      await db.settingsDao.setValue(dgtTutorialSeenKey, '0');
      expect(await isDgtTutorialSeen(db), isFalse);
    });
  });

  group('DgtTutorialScreen widget', () {
    Widget wrap(MemoraDatabase db, {VoidCallback? onDone}) {
      return ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: DgtTutorialScreen(onDone: onDone)),
      );
    }

    testWidgets('renders 3 slides with expected titles', (tester) async {
      final db = MemoraDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      // Primera slide visible.
      expect(find.text('Practica por tema'), findsOneWidget);

      // Boton "Siguiente" hasta llegar al ultimo.
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Simulacro'), findsOneWidget);

      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Review Rapido'), findsOneWidget);

      // En la ultima slide aparece "Empezar" en lugar de "Siguiente".
      expect(find.text('Empezar'), findsOneWidget);
      expect(find.text('Siguiente'), findsNothing);
    });

    testWidgets('tap Saltar fires onDone and persists flag', (tester) async {
      final db = MemoraDatabase.forTesting(NativeDatabase.memory());
      var doneCount = 0;

      await tester.pumpWidget(wrap(db, onDone: () => doneCount++));
      await tester.pump();

      await tester.tap(find.byKey(const Key('dgt-tutorial-skip')));
      // _finish hace un await a markDgtTutorialSeen (drift/sqlite I/O).
      // runAsync deja que el codigo real (no el fake async del tester) lo
      // resuelva. Sin runAsync, drift queda colgado esperando un timer real.
      await tester.runAsync(() async {
        // Pequeno yield para que el listener post-tap arranque _finish.
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(doneCount, 1);
      expect(await isDgtTutorialSeen(db), isTrue);
      await db.close();
    });

    testWidgets('tap Empezar in last slide fires onDone and persists flag',
        (tester) async {
      final db = MemoraDatabase.forTesting(NativeDatabase.memory());
      var doneCount = 0;

      await tester.pumpWidget(wrap(db, onDone: () => doneCount++));
      await tester.pump();

      // Avanzar a la ultima slide.
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Empezar'));
      // Mismo patron que el test de Saltar: runAsync para que drift complete.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(doneCount, 1);
      expect(await isDgtTutorialSeen(db), isTrue);
      await db.close();
    });
  });
}
