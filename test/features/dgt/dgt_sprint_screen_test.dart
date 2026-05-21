import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/api/api_client.dart';
import 'package:memora/features/dgt/dgt_sprint_history_provider.dart';
import 'package:memora/features/dgt/dgt_sprint_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue #152 (dgt-ux): cobertura del Sprint diario.
/// - Loading state al inicio.
/// - Render de pregunta con opciones y timer visible.
/// - Tap autoavanza a la siguiente pregunta.
/// - Resumen final con score y CTA Cerrar.
/// - "Ya completaste hoy": atajo a summary sin empezar nuevo sprint.

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

Map<String, dynamic> _q({
  String id = 'q1',
  String statement = 'Pregunta sprint',
  String correct = 'a',
  String optionA = 'Opcion A correcta',
  String optionB = 'Opcion B',
  String optionC = 'Opcion C',
}) =>
    {
      'id': id,
      'statement': statement,
      'option_a': optionA,
      'option_b': optionB,
      'option_c': optionC,
      'correct': correct,
      'explanation': null,
      'image_url': null,
      'topic': 'senales',
    };

Widget _wrap(Widget child, {required ApiClient api}) {
  return ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(api)],
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DgtSprintScreen', () {
    testWidgets('muestra loading al inicio', (tester) async {
      final api = _FakeApi([_q()]);
      await tester.pumpWidget(_wrap(const DgtSprintScreen(), api: api));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets(
        'renderiza primera pregunta con opciones, progreso y timer 02:00',
        (tester) async {
      final api = _FakeApi([
        _q(id: 'q1'),
        _q(id: 'q2'),
      ]);
      await tester.pumpWidget(_wrap(const DgtSprintScreen(), api: api));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.text('Sprint diario'), findsOneWidget);
      expect(find.text('Pregunta 1 de 2'), findsOneWidget);
      expect(find.text('Opcion A correcta'), findsOneWidget);
      expect(find.byKey(const ValueKey('dgt-sprint-timer')), findsOneWidget);
      // Timer arranca en 02:00 (kDgtSprintDurationSeconds = 120).
      expect(find.text('02:00'), findsOneWidget);
    });

    testWidgets('autoavanza a la siguiente pregunta al responder',
        (tester) async {
      final api = _FakeApi([
        _q(id: 'q1', statement: 'Q1', optionA: 'A1'),
        _q(id: 'q2', statement: 'Q2', optionA: 'A2'),
      ]);
      await tester.pumpWidget(_wrap(const DgtSprintScreen(), api: api));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.text('Q1'), findsOneWidget);
      await tester.tap(find.text('A1'));
      // Esperar el delay de 250ms del autoavanza.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('Pregunta 2 de 2'), findsOneWidget);
      expect(find.text('Q2'), findsOneWidget);
    });

    testWidgets(
        'al terminar la ultima pregunta muestra resumen con score 1/1',
        (tester) async {
      final api = _FakeApi([
        _q(id: 'q1', correct: 'a', optionA: 'A correcta'),
      ]);
      await tester.pumpWidget(_wrap(const DgtSprintScreen(), api: api));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      await tester.tap(find.text('A correcta'));
      // 250ms autoavanza + frame del setState async + persistencia.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('dgt-sprint-score')), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);
      expect(find.text('Cerrar'), findsOneWidget);

      // Persistencia: el historial debe tener una entrada.
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(kDgtSprintHistoryPrefsKey),
        isNotNull,
      );
    });

    testWidgets(
        'si hay sprint hoy, muestra summary y aviso "ya completaste hoy"',
        (tester) async {
      final today = DateTime.now();
      final entry = DgtSprintEntry(
        timestamp: today,
        total: 10,
        correct: 7,
        secondsUsed: 80,
      );
      SharedPreferences.setMockInitialValues({
        kDgtSprintHistoryPrefsKey:
            '[${'{"ts":"${entry.timestamp.toUtc().toIso8601String()}","total":10,"correct":7,"seconds_used":80}'}]',
      });

      final api = _FakeApi([_q()]);
      await tester.pumpWidget(_wrap(const DgtSprintScreen(), api: api));
      // Una vez hidratado el provider, debe ir directo a summary.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.textContaining('Ya completaste el sprint de hoy'),
          findsOneWidget);
      expect(find.text('7 / 10'), findsOneWidget);
      // No timer visible (no estamos en quiz).
      expect(find.byKey(const ValueKey('dgt-sprint-timer')), findsNothing);
    });
  });
}
