import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_tutorials_catalog.dart';

/// Issue #153 (dgt-ux): cubre el catalogo estatico de tutoriales pre-quiz
/// y la helper de lookup case-insensitive. Funcion pura, sin IO.
void main() {
  group('dgtTutorialsCatalog', () {
    test('cubre los 5 subtopics iniciales acordados con autoescuelas', () {
      // Las keys son contrato externo (analytics, contenido). Si una
      // desaparece accidentalmente este test falla y obliga a revisar
      // el cambio en review.
      const expected = <String>{
        'senales',
        'normas',
        'mecanica',
        'seguridad',
        'circulacion',
      };
      expect(dgtTutorialsCatalog.keys.toSet().containsAll(expected), isTrue);
    });

    test('cada entrada tiene concept y example no vacios', () {
      for (final entry in dgtTutorialsCatalog.entries) {
        expect(entry.value.concept.trim(), isNotEmpty,
            reason: 'concept vacio en ${entry.key}');
        expect(entry.value.example.trim(), isNotEmpty,
            reason: 'example vacio en ${entry.key}');
      }
    });
  });

  group('lookupDgtTutorial', () {
    test('match exacto por id', () {
      expect(lookupDgtTutorial('senales'), isNotNull);
      expect(lookupDgtTutorial('mecanica'), isNotNull);
    });

    test('case-insensitive', () {
      expect(lookupDgtTutorial('Senales'), isNotNull);
      expect(lookupDgtTutorial('NORMAS'), isNotNull);
    });

    test('normaliza espacios a underscore (no aplicable aun pero estable)',
        () {
      // No hay keys con espacios en el catalogo inicial, pero la helper
      // debe seguir reconociendo "senales" venga con whitespace lateral.
      expect(lookupDgtTutorial(' senales '), isNotNull);
    });

    test('null o vacio -> null', () {
      expect(lookupDgtTutorial(null), isNull);
      expect(lookupDgtTutorial(''), isNull);
    });

    test('topic_id desconocido -> null (silent fallback)', () {
      expect(lookupDgtTutorial('topic_inexistente_xyz'), isNull);
    });
  });
}
