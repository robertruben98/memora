import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/data/dgt_tutorials.dart';

/// Issue #153 (dgt-ux): cubre el catalogo estatico de tutoriales y la
/// funcion de lookup tolerante a casing/separadores. Test puro, sin IO.
void main() {
  group('lookupDgtTutorial', () {
    test('returns null para topic vacio', () {
      expect(lookupDgtTutorial(''), isNull);
      expect(lookupDgtTutorial('   '), isNull);
    });

    test('returns null para topic desconocido (silent fallback)', () {
      expect(lookupDgtTutorial('topic-que-no-existe-xyz'), isNull);
      expect(lookupDgtTutorial('whatever'), isNull);
    });

    test('lookup por key exacta funciona para entries del catalogo', () {
      final t = lookupDgtTutorial('senales');
      expect(t, isNotNull);
      expect(t!.topicId, 'senales');
      expect(t.concept, isNotEmpty);
      expect(t.example, isNotEmpty);
    });

    test('lookup es case-insensitive', () {
      expect(lookupDgtTutorial('SENALES'), isNotNull);
      expect(lookupDgtTutorial('Normas'), isNotNull);
      expect(lookupDgtTutorial('MeCaNiCa'), isNotNull);
    });

    test('lookup tolera underscore vs hyphen', () {
      // Si el backend devuelve 'medio_ambiente' debe encontrar
      // 'medio-ambiente' en el catalogo.
      final t = lookupDgtTutorial('medio_ambiente');
      expect(t, isNotNull);
      expect(t!.topicId, 'medio-ambiente');
    });

    test('lookup tolera whitespace alrededor', () {
      expect(lookupDgtTutorial('  senales  '), isNotNull);
    });
  });

  group('kDgtTutorials catalogo', () {
    test('todas las entries tienen topicId no vacio coherente con la key', () {
      for (final entry in kDgtTutorials.entries) {
        expect(entry.value.topicId, entry.key,
            reason: 'key=${entry.key} debe coincidir con topicId interno');
        expect(entry.value.concept, isNotEmpty,
            reason: 'concept vacio para ${entry.key}');
        expect(entry.value.example, isNotEmpty,
            reason: 'example vacio para ${entry.key}');
      }
    });

    test('catalogo cubre al menos 5 subtopics iniciales (criterio aceptacion)',
        () {
      expect(kDgtTutorials.length, greaterThanOrEqualTo(5));
    });

    test('keys del catalogo estan en minusculas y sin underscore', () {
      for (final key in kDgtTutorials.keys) {
        expect(key, key.toLowerCase(),
            reason: 'key $key deberia estar en minusculas');
        expect(key.contains('_'), isFalse,
            reason: 'key $key deberia usar guion medio no bajo');
      }
    });
  });
}
