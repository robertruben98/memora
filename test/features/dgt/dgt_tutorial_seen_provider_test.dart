import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_tutorial_seen_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue #153 (dgt-ux): cubre el store SharedPreferences-backed que
/// recuerda que topic_ids ya tuvieron tutorial mostrado / suprimido.
void main() {
  // Required para que SharedPreferences.setMockInitialValues funcione.
  TestWidgetsFlutterBinding.ensureInitialized();

  late DgtTutorialSeenStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = DgtTutorialSeenStore();
  });

  group('DgtTutorialSeenStore', () {
    test('hasSeen sin datos previos -> false', () async {
      expect(await store.hasSeen('senales'), isFalse);
    });

    test('hasSeen para topic vacio -> false (no throw)', () async {
      expect(await store.hasSeen(''), isFalse);
    });

    test('markSeen + hasSeen roundtrip', () async {
      await store.markSeen('senales');
      expect(await store.hasSeen('senales'), isTrue);
    });

    test('markSeen es idempotente (no duplica entradas)', () async {
      await store.markSeen('normas');
      await store.markSeen('normas');
      await store.markSeen('normas');
      // No exponemos `getAll`, pero verificamos en SharedPreferences raw
      // que solo hay una entrada.
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(DgtTutorialSeenStore.prefsKey) ?? [];
      expect(list.where((e) => e == 'normas').length, 1);
    });

    test('markSeen de topic vacio -> no-op (no escribe lista)', () async {
      await store.markSeen('');
      final prefs = await SharedPreferences.getInstance();
      // Aceptable: o no existe la key, o existe pero vacia.
      final list = prefs.getStringList(DgtTutorialSeenStore.prefsKey);
      expect(list == null || list.isEmpty, isTrue);
    });

    test('topics distintos coexisten', () async {
      await store.markSeen('senales');
      await store.markSeen('normas');
      expect(await store.hasSeen('senales'), isTrue);
      expect(await store.hasSeen('normas'), isTrue);
      expect(await store.hasSeen('mecanica'), isFalse);
    });

    test('clearAll borra todo y vuelve a false', () async {
      await store.markSeen('senales');
      expect(await store.hasSeen('senales'), isTrue);
      await store.clearAll();
      expect(await store.hasSeen('senales'), isFalse);
    });
  });
}
