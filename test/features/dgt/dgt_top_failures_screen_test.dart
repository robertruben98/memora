import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/api/api_client.dart';
import 'package:memora/data/repositories/dgt_repository.dart';
import 'package:memora/features/dgt/dgt_top_failures_screen.dart';

/// Issue #190 (dgt-ux): pantalla "Top 5 fallos del mes" con insight de
/// palabras trampa. Cubre:
/// - [containsTrickKeyword]: detector case-insensitive con word boundary.
/// - [countTrickKeywords]: conteo sobre lista.
/// - [DgtTrickInsightBanner]: render con conteo exacto.
/// - [DgtTopFailuresScreen]: lista con 5 items + banner >=3 trampas,
///   estado vacio sin banner.

class _FakeApi extends ApiClient {
  final Object response;
  _FakeApi(this.response)
      : super(baseUrl: 'http://test.invalid', token: 'fake');

  @override
  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    if (response is Exception) throw response as Exception;
    return response;
  }
}

Map<String, dynamic> _rawItem({
  required String id,
  required String statement,
  int failCount = 3,
}) =>
    {
      'id': id,
      'statement': statement,
      'option_a': 'A',
      'option_b': 'B',
      'option_c': 'C',
      'correct': 'a',
      'fail_count': failCount,
    };

DgtRecurrentFailureItem _item(String statement, {int fc = 3}) {
  return DgtRecurrentFailureItem(
    question: DgtQuestion(
      id: statement.hashCode.toString(),
      statement: statement,
      optionA: 'A',
      optionB: 'B',
      optionC: 'C',
      correct: 'a',
    ),
    failCount: fc,
  );
}

void main() {
  group('containsTrickKeyword', () {
    test('detecta siempre/nunca/excepto/solo/obligatorio/prohibido', () {
      expect(containsTrickKeyword('El conductor siempre debe...'), isTrue);
      expect(containsTrickKeyword('Nunca se debe parar en...'), isTrue);
      expect(containsTrickKeyword('Todos los vehiculos excepto motos'),
          isTrue);
      expect(containsTrickKeyword('Solo en autovia se puede'), isTrue);
      expect(containsTrickKeyword('Es obligatorio llevar chaleco'), isTrue);
      expect(containsTrickKeyword('Esta prohibido aparcar aqui'), isTrue);
    });

    test('case-insensitive', () {
      expect(containsTrickKeyword('SIEMPRE hay que parar'), isTrue);
      expect(containsTrickKeyword('Nunca'), isTrue);
      expect(containsTrickKeyword('EXCEPTO en autopista'), isTrue);
    });

    test('NO matchea substring (solomillo, obligatoriedad, prohibicion)',
        () {
      expect(containsTrickKeyword('Lleva solomillo en el coche'), isFalse);
      expect(containsTrickKeyword('La obligatoriedad legal'), isFalse);
      expect(containsTrickKeyword('La prohibicion de adelantar'), isFalse);
      expect(containsTrickKeyword('Nuncamente'), isFalse);
    });

    test('enunciado sin trampa devuelve false', () {
      expect(
          containsTrickKeyword(
              'Cual es la velocidad maxima en autovia para turismo?'),
          isFalse);
      expect(containsTrickKeyword(''), isFalse);
      expect(containsTrickKeyword('   '), isFalse);
    });

    test('clasificacion sobre lista de 10 enunciados', () {
      const cases = <String, bool>{
        'Siempre se debe ceder el paso a peatones': true,
        'Nunca conduzcas bebido': true,
        'Todos los conductores excepto los profesionales': true,
        'Solo los mayores de edad pueden conducir': true,
        'Es obligatorio el cinturon': true,
        'Esta prohibido el alcohol al volante': true,
        'La velocidad maxima en ciudad es 50 km/h': false,
        'El semaforo amarillo indica precaucion': false,
        'Comer solomillo no afecta a la conduccion': false,
        'La obligatoriedad se establece en el reglamento': false,
      };
      for (final e in cases.entries) {
        expect(containsTrickKeyword(e.key), e.value,
            reason: 'fallo en: "${e.key}"');
      }
    });
  });

  group('countTrickKeywords', () {
    test('cuenta items con keyword trampa', () {
      final items = [
        _item('Siempre se debe ceder el paso'),
        _item('Nunca rebases el limite'),
        _item('Excepto en autopista'),
        _item('La velocidad maxima en ciudad'),
        _item('El semaforo rojo significa parar'),
      ];
      expect(countTrickKeywords(items), 3);
    });

    test('lista vacia -> 0', () {
      expect(
          countTrickKeywords(const <DgtRecurrentFailureItem>[]), 0);
    });
  });

  group('DgtTrickInsightBanner', () {
    testWidgets('renderiza titulo "Cuidado con absolutos" + conteo exacto',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DgtTrickInsightBanner(trickCount: 3, total: 5),
          ),
        ),
      );
      expect(find.text('Cuidado con absolutos'), findsOneWidget);
      expect(
          find.textContaining('3 de tus 5 fallos del mes'), findsOneWidget);
    });
  });

  group('DgtTopFailuresScreen', () {
    Widget wrap(Widget child, {required ApiClient api}) {
      return ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(home: child),
      );
    }

    testWidgets('5 preguntas (3 con trampa) -> banner visible "3 de tus 5"',
        (tester) async {
      final api = _FakeApi([
        _rawItem(
            id: 'q1',
            statement: 'Siempre hay que ceder el paso',
            failCount: 7),
        _rawItem(
            id: 'q2', statement: 'Nunca adelantes en curva', failCount: 5),
        _rawItem(
            id: 'q3',
            statement: 'Todos pueden adelantar excepto los pesados',
            failCount: 4),
        _rawItem(
            id: 'q4',
            statement: 'La velocidad maxima en autovia',
            failCount: 3),
        _rawItem(
            id: 'q5',
            statement: 'El semaforo en ambar indica',
            failCount: 2),
      ]);
      await tester.pumpWidget(
        wrap(const DgtTopFailuresScreen(), api: api),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Top 5 fallos del mes'), findsWidgets);
      expect(find.text('Cuidado con absolutos'), findsOneWidget);
      expect(
          find.textContaining('3 de tus 5 fallos del mes'), findsOneWidget);
      // Los 5 enunciados visibles.
      expect(find.textContaining('Siempre hay que ceder'), findsOneWidget);
      expect(find.textContaining('Nunca adelantes'), findsOneWidget);
      expect(find.textContaining('excepto los pesados'), findsOneWidget);
    });

    testWidgets('endpoint vacio -> empty state SIN banner', (tester) async {
      final api = _FakeApi(const <Map<String, dynamic>>[]);
      await tester.pumpWidget(
        wrap(const DgtTopFailuresScreen(), api: api),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Sin fallos en los ultimos 30 dias'), findsOneWidget);
      expect(find.text('Cuidado con absolutos'), findsNothing);
    });

    testWidgets('solo 2 trampas en 5 -> NO banner', (tester) async {
      final api = _FakeApi([
        _rawItem(
            id: 'q1', statement: 'Siempre debes detenerte', failCount: 4),
        _rawItem(
            id: 'q2', statement: 'Nunca conduzcas cansado', failCount: 3),
        _rawItem(
            id: 'q3',
            statement: 'Velocidad maxima en zona urbana',
            failCount: 2),
        _rawItem(
            id: 'q4',
            statement: 'Distancia minima de seguridad',
            failCount: 2),
        _rawItem(
            id: 'q5',
            statement: 'Senal triangular invertida',
            failCount: 2),
      ]);
      await tester.pumpWidget(
        wrap(const DgtTopFailuresScreen(), api: api),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Cuidado con absolutos'), findsNothing);
      expect(find.textContaining('Siempre debes'), findsOneWidget);
    });
  });
}
