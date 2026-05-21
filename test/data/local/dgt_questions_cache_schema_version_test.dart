import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/local/dgt_questions_cache.dart';
import 'package:memora/data/repositories/dgt_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue #156 (dgt-tech): handshake de version del schema para auto-invalidar
/// la cache local DGT cuando el contrato de `DgtQuestion.fromJson` cambia.
///
/// Estos tests son aditivos: no tocan los del cache "core" en
/// `dgt_repository_test.dart`. Cubren los 3 escenarios pedidos en el issue:
///   1. cache hit con version IGUAL a [kDgtCacheSchemaVersion].
///   2. cache miss con version DISTINTA (clientes que tenian la cache
///      escrita por una version anterior del codigo).
///   3. cache miss legacy: blob persistido por una build vieja que aun NO
///      escribia la key `keySchemaVersion` (default implicito = 1).

List<Map<String, dynamic>> _bank(int n) => List.generate(
      n,
      (i) => {
        'id': 'q$i',
        'statement': 'Pregunta $i',
        'option_a': 'A$i',
        'option_b': 'B$i',
        'option_c': 'C$i',
        'correct': 'a',
        'explanation': null,
        'image_url': null,
        'topic': 'senales',
      },
    );

Future<void> _seedLegacyBlob({required int versionToWrite}) async {
  // Sembramos el blob a mano simulando que una build anterior lo persistio.
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    DgtQuestionsCache.keyJson,
    '[{"id":"qLegacy","statement":"vieja","option_a":"a","option_b":"b",'
    '"option_c":"c","correct":"a"}]',
  );
  await prefs.setInt(
    DgtQuestionsCache.keyTimestampMs,
    DateTime.now().millisecondsSinceEpoch,
  );
  await prefs.setInt(DgtQuestionsCache.keyLimit, 30);
  if (versionToWrite >= 0) {
    await prefs.setInt(DgtQuestionsCache.keySchemaVersion, versionToWrite);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DgtQuestionsCache schema version handshake (issue #156)', () {
    test(
        'cache HIT cuando la version persistida coincide con '
        'kDgtCacheSchemaVersion', () async {
      final cache = DgtQuestionsCache();
      final src = _bank(3).map((m) => DgtQuestion.fromJson(m)).toList();
      await cache.write(src, limit: 3);

      // write() debio persistir kDgtCacheSchemaVersion -> read() lee OK.
      final got = await cache.read();
      expect(got, isNotNull);
      expect(got!.length, 3);
      expect(got.first.id, 'q0');
    });

    test('cache MISS cuando la version persistida difiere', () async {
      // Simulamos un cliente que tenia cache de una version anterior:
      // bumpeamos por debajo (version 0 != kDgtCacheSchemaVersion).
      await _seedLegacyBlob(versionToWrite: kDgtCacheSchemaVersion - 1);

      final cache = DgtQuestionsCache();
      final got = await cache.read();
      expect(got, isNull,
          reason: 'version != kDgtCacheSchemaVersion debe forzar cache miss');
    });

    test(
        'cache MISS legacy: blob persistido SIN keySchemaVersion '
        '(default implicito v1)', () async {
      // Cliente muy viejo que no escribia la key -> default implicito 1.
      // Como kDgtCacheSchemaVersion >= 2 ahora, debe invalidarse.
      await _seedLegacyBlob(versionToWrite: -1); // -1 = no escribir la key.

      final cache = DgtQuestionsCache();
      final got = await cache.read();
      expect(got, isNull,
          reason:
              'legacy sin keySchemaVersion debe tratarse como v1 y invalidarse '
              'si kDgtCacheSchemaVersion != 1');
    });

    test('write persiste keySchemaVersion = kDgtCacheSchemaVersion', () async {
      final cache = DgtQuestionsCache();
      final src = _bank(2).map((m) => DgtQuestion.fromJson(m)).toList();
      await cache.write(src, limit: 2);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(DgtQuestionsCache.keySchemaVersion),
        kDgtCacheSchemaVersion,
      );
    });

    test('clear() borra tambien la key de version', () async {
      final cache = DgtQuestionsCache();
      final src = _bank(2).map((m) => DgtQuestion.fromJson(m)).toList();
      await cache.write(src, limit: 2);
      await cache.clear();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(DgtQuestionsCache.keySchemaVersion), isNull);
    });

    test(
        'forceFresh sigue forzando miss incluso con version correcta',
        () async {
      final cache = DgtQuestionsCache();
      final src = _bank(2).map((m) => DgtQuestion.fromJson(m)).toList();
      await cache.write(src, limit: 2);
      final got = await cache.read(forceFresh: true);
      expect(got, isNull);
    });
  });
}
