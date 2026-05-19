import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_settings.dart';

/// Issue #79 (dgt-ux): cubre la matriz urgencia x progreso del mensaje
/// motivacional del banner Home. Funcion pura sin dependencias.
void main() {
  group('dgtMotivationMessage', () {
    test('returns null when days is null (sin examen fijado)', () {
      expect(dgtMotivationMessage(null, 0.5), isNull);
      expect(dgtMotivationMessage(null, 0.95), isNull);
      expect(dgtMotivationMessage(null, null), isNull);
    });

    test('returns null when exam already passed (days < 0)', () {
      expect(dgtMotivationMessage(-1, 0.5), isNull);
      expect(dgtMotivationMessage(-10, 0.95), isNull);
    });

    test('returns null when expectedScore is null (sin prediccion)', () {
      expect(dgtMotivationMessage(3, null), isNull);
      expect(dgtMotivationMessage(15, null), isNull);
      expect(dgtMotivationMessage(40, null), isNull);
      expect(dgtMotivationMessage(0, null), isNull);
    });

    test('<7d & score<0.90 -> urgencia roja', () {
      expect(
        dgtMotivationMessage(0, 0.5),
        'Quedan pocos dias y no llegas - dale ya!',
      );
      expect(
        dgtMotivationMessage(3, 0.89),
        'Quedan pocos dias y no llegas - dale ya!',
      );
      expect(
        dgtMotivationMessage(6, 0.0),
        'Quedan pocos dias y no llegas - dale ya!',
      );
    });

    test('<7d & score>=0.90 -> verde "a punto"', () {
      expect(
        dgtMotivationMessage(0, 0.90),
        'A punto! Ultima semana, manten el ritmo',
      );
      expect(
        dgtMotivationMessage(3, 0.95),
        'A punto! Ultima semana, manten el ritmo',
      );
      expect(
        dgtMotivationMessage(6, 1.0),
        'A punto! Ultima semana, manten el ritmo',
      );
    });

    test('7-30d & score<0.90 -> ambar acelerar', () {
      expect(
        dgtMotivationMessage(7, 0.5),
        'Tienes margen pero hay que acelerar',
      );
      expect(
        dgtMotivationMessage(15, 0.89),
        'Tienes margen pero hay que acelerar',
      );
      expect(
        dgtMotivationMessage(30, 0.0),
        'Tienes margen pero hay que acelerar',
      );
    });

    test('7-30d & score>=0.90 -> verde "vas bien"', () {
      expect(dgtMotivationMessage(7, 0.90), 'Vas bien, sigue asi');
      expect(dgtMotivationMessage(15, 0.95), 'Vas bien, sigue asi');
      expect(dgtMotivationMessage(30, 1.0), 'Vas bien, sigue asi');
    });

    test('>30d -> calma (sin importar score)', () {
      expect(dgtMotivationMessage(31, 0.0), 'Calma, hay tiempo de sobra');
      expect(dgtMotivationMessage(60, 0.5), 'Calma, hay tiempo de sobra');
      expect(dgtMotivationMessage(365, 0.95), 'Calma, hay tiempo de sobra');
    });

    test('boundary: dia 7 cae en cubo 7-30', () {
      expect(dgtMotivationMessage(7, 0.5), 'Tienes margen pero hay que acelerar');
      expect(dgtMotivationMessage(7, 0.90), 'Vas bien, sigue asi');
    });

    test('boundary: dia 30 cae en cubo 7-30', () {
      expect(dgtMotivationMessage(30, 0.5), 'Tienes margen pero hay que acelerar');
      expect(dgtMotivationMessage(30, 0.90), 'Vas bien, sigue asi');
    });

    test('boundary: dia 31 cae en >30', () {
      expect(dgtMotivationMessage(31, 0.5), 'Calma, hay tiempo de sobra');
      expect(dgtMotivationMessage(31, 0.95), 'Calma, hay tiempo de sobra');
    });
  });
}
