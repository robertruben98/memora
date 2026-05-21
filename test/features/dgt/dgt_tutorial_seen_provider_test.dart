import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:memora/features/dgt/dgt_tutorial_seen_provider.dart';

/// Issue #153 (dgt-ux): verifica persistencia y normalizacion del set
/// de topics con tutorial silenciado.

/// Flush varios microtasks para permitir que `_load` (que encadena
/// `SharedPreferences.getInstance()` async) complete antes del expect.
Future<void> _flushAsync() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('arranca vacio si no hay datos previos en SharedPreferences', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Disparar build.
    final initial = container.read(dgtTutorialSeenProvider);
    // El load es async tras el constructor; permitir microtasks.
    await _flushAsync();
    final after = container.read(dgtTutorialSeenProvider);
    expect(initial.ids, isEmpty);
    expect(after.ids, isEmpty);
  });

  test('markSeen agrega topic y persiste', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _flushAsync();

    final notifier = container.read(dgtTutorialSeenProvider.notifier);
    final added = await notifier.markSeen('senales');
    expect(added, isTrue);
    expect(container.read(dgtTutorialSeenProvider).contains('senales'), isTrue);

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(kDgtTutorialSeenPrefsKey);
    expect(stored, contains('senales'));
  });

  test('markSeen es idempotente (segundo call retorna false)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _flushAsync();

    final notifier = container.read(dgtTutorialSeenProvider.notifier);
    expect(await notifier.markSeen('normas'), isTrue);
    expect(await notifier.markSeen('normas'), isFalse);
  });

  test('contains es case-insensitive y tolera underscore', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _flushAsync();

    final notifier = container.read(dgtTutorialSeenProvider.notifier);
    await notifier.markSeen('Medio_Ambiente');
    final state = container.read(dgtTutorialSeenProvider);
    expect(state.contains('medio-ambiente'), isTrue);
    expect(state.contains('MEDIO_AMBIENTE'), isTrue);
    expect(state.contains('medio_ambiente'), isTrue);
  });

  test('topic vacio no se persiste', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _flushAsync();

    final notifier = container.read(dgtTutorialSeenProvider.notifier);
    expect(await notifier.markSeen(''), isFalse);
    expect(await notifier.markSeen('   '), isFalse);
    expect(container.read(dgtTutorialSeenProvider).ids, isEmpty);
  });

  test('load recupera datos previos persistidos', () async {
    SharedPreferences.setMockInitialValues({
      kDgtTutorialSeenPrefsKey: ['senales', 'normas'],
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Disparar build (instancia el notifier -> arranca _load).
    container.read(dgtTutorialSeenProvider);
    await _flushAsync();

    final state = container.read(dgtTutorialSeenProvider);
    expect(state.contains('senales'), isTrue);
    expect(state.contains('normas'), isTrue);
    expect(state.ids.length, 2);
  });

  test('resetAll limpia in-memory y storage', () async {
    SharedPreferences.setMockInitialValues({
      kDgtTutorialSeenPrefsKey: ['senales'],
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(dgtTutorialSeenProvider);
    await _flushAsync();

    final notifier = container.read(dgtTutorialSeenProvider.notifier);
    await notifier.resetAll();

    expect(container.read(dgtTutorialSeenProvider).ids, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(kDgtTutorialSeenPrefsKey), isNull);
  });
}
