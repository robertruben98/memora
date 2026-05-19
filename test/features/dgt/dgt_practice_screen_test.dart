import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/api/api_client.dart';
import 'package:memora/data/repositories/dgt_repository.dart';
import 'package:memora/features/dgt/dgt_practice_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue #103 (dgt-tech): tests dedicados para `DgtPracticeScreen`.
///
/// Cubre los comportamientos basicos del modo practica DGT por tema:
/// - Render basico de la primera pregunta tras cargar.
/// - Feedback inmediato correcto (verde) e incorrecto (rojo) al tap respuesta.
/// - Boton "Siguiente" se habilita tras responder y avanza el indice.
/// - Toggle del modo audio TTS (sin ejecutar el bucle TTS real).
/// - Toggle del Pomodoro (sin esperar a que vuelva el ticker en tiempo real).
///
/// Mocks: override de `apiClientProvider` y `dgtRepositoryProvider` con
/// fakes. No usa mocktail. Los toggles de audio/Pomodoro solo verifican el
/// cambio inicial de estado UI (icono on/off, contador de pomodoros) sin
/// disparar timers reales — Flutter test no tolera Timer pendiente.

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'http://test.invalid', token: 'fake');
}

class _FakeDgtRepository extends DgtRepository {
  final List<DgtQuestion> seed;
  _FakeDgtRepository(this.seed) : super(_FakeApiClient());

  @override
  Future<List<DgtQuestion>> fetchQuestionsByTopic({
    required String topicId,
    int? limit,
  }) async {
    if (limit != null && limit > 0 && limit < seed.length) {
      return seed.take(limit).toList();
    }
    return List.of(seed);
  }
}

List<DgtQuestion> _seedQuestions(int n, {String letter = 'a'}) {
  return List.generate(n, (i) {
    return DgtQuestion(
      id: 'qp$i',
      statement: 'Practica DGT pregunta $i',
      optionA: 'Opcion A $i',
      optionB: 'Opcion B $i',
      optionC: 'Opcion C $i',
      correct: letter,
      explanation: 'Explicacion pregunta $i',
      topic: 'senales',
    );
  });
}

const _topic = DgtTopic(id: 'senales', name: 'Senales', questionCount: 5);

Widget _buildPractice({
  required List<DgtQuestion> seed,
  int limit = 3,
}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(_FakeApiClient()),
      dgtRepositoryProvider.overrideWithValue(_FakeDgtRepository(seed)),
    ],
    child: MaterialApp(
      home: DgtPracticeScreen(topic: _topic, limit: limit),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    // Mockea el canal de flutter_tts para que setLanguage/speak/etc. no
    // exploten con MissingPluginException. Devuelve null (sin error) en
    // todos los metodos invocados. El test no verifica reproduccion real,
    // solo toggles UI.
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => null,
    );
  });

  tearDown(() {
    // Limpia el handler del canal para no contaminar otros suites.
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          null,
        );
  });

  group('DgtPracticeScreen - render basico', () {
    testWidgets('muestra appbar con nombre del tema y primera pregunta',
        (tester) async {
      await tester.pumpWidget(_buildPractice(seed: _seedQuestions(3)));
      await tester.pumpAndSettle();

      // Appbar: nombre del tema.
      expect(find.text('Senales'), findsOneWidget);
      // Pregunta 1 visible.
      expect(find.text('Pregunta 1 / 3'), findsOneWidget);
      expect(find.text('Practica DGT pregunta 0'), findsOneWidget);
    });
  });

  group('DgtPracticeScreen - feedback inmediato', () {
    testWidgets('tap respuesta correcta muestra explicacion "Correcto"',
        (tester) async {
      await tester.pumpWidget(_buildPractice(seed: _seedQuestions(3)));
      await tester.pumpAndSettle();

      // Letra correcta es 'a' -> tap opcion A.
      await tester.tap(find.text('A').first);
      await tester.pump();

      // Explicacion inline aparece con badge "Correcto".
      expect(find.text('Correcto'), findsOneWidget);
      expect(find.text('Repasemos'), findsNothing);
      expect(find.textContaining('Explicacion pregunta 0'), findsOneWidget);
    });

    testWidgets('tap respuesta incorrecta muestra explicacion "Repasemos"',
        (tester) async {
      await tester.pumpWidget(_buildPractice(seed: _seedQuestions(3)));
      await tester.pumpAndSettle();

      // Letra correcta es 'a' -> tap opcion B (incorrecta).
      await tester.tap(find.text('B').first);
      await tester.pump();

      // Badge "Repasemos" (icono book) visible.
      expect(find.text('Repasemos'), findsOneWidget);
      // Tambien muestra la respuesta correcta.
      expect(find.text('Respuesta correcta: A'), findsOneWidget);
    });
  });

  group('DgtPracticeScreen - navegacion Siguiente', () {
    testWidgets('boton Siguiente disabled antes de responder, enabled despues',
        (tester) async {
      await tester.pumpWidget(_buildPractice(seed: _seedQuestions(3)));
      await tester.pumpAndSettle();

      // `FilledButton.icon` con icono crea un `_FilledButtonWithIcon`
      // (extiende FilledButton). El text "Siguiente" esta dentro del label
      // del icon-button. Para detectar onPressed sin acoplarnos al subtype
      // privado, buscamos el primer InkWell ancestor del label, que es
      // null cuando el ButtonStyleButton esta disabled.
      bool siguienteEnabled() {
        final inkwells = find.ancestor(
          of: find.text('Siguiente'),
          matching: find.byType(InkWell),
        );
        if (inkwells.evaluate().isEmpty) return false;
        final ink = tester.widget<InkWell>(inkwells.first);
        return ink.onTap != null;
      }

      expect(find.text('Siguiente'), findsOneWidget);
      expect(siguienteEnabled(), isFalse,
          reason: 'Siguiente debe estar disabled sin respuesta');

      // Respondemos -> se habilita.
      await tester.tap(find.text('A').first);
      await tester.pump();
      expect(siguienteEnabled(), isTrue,
          reason: 'Siguiente debe habilitarse tras responder');

      // Tap Siguiente -> avanza a pregunta 2.
      await tester.tap(find.text('Siguiente'));
      await tester.pump();
      expect(find.text('Pregunta 2 / 3'), findsOneWidget);
      expect(find.text('Practica DGT pregunta 1'), findsOneWidget);
    });
  });

  group('DgtPracticeScreen - toggle modo audio', () {
    testWidgets('tap icono audio cambia headset -> headset_off',
        (tester) async {
      await tester.pumpWidget(_buildPractice(seed: _seedQuestions(3)));
      await tester.pumpAndSettle();

      // Estado inicial: icono headset (audio off).
      expect(find.byIcon(Icons.headset_rounded), findsOneWidget);
      expect(find.byIcon(Icons.headset_off_rounded), findsNothing);

      // Tap toggle audio. Inicializa FlutterTts (que en test mode no hace
      // nada real sobre el plugin) y dispara el bucle. No esperamos al
      // pumpAndSettle porque el bucle TTS usa timers; solo verificamos
      // el cambio de UI inmediato tras el setState.
      await tester.tap(find.byIcon(Icons.headset_rounded));
      // Una sola pump: deja correr el setState que cambia _audioMode.
      // No usamos pumpAndSettle para evitar esperar el Timer del bucle.
      await tester.pump();
      await tester.pump();

      // Tras el toggle, el icono pasa a headset_off (audio on -> opcion
      // "Salir modo audio") y aparece el FAB de play/pause.
      expect(find.byIcon(Icons.headset_off_rounded), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);

      // Toggle de vuelta para apagar el bucle TTS y cancelar el timer
      // interno (evita pending timers al finalizar el test).
      await tester.tap(find.byIcon(Icons.headset_off_rounded));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.headset_rounded), findsOneWidget);
    });
  });

  group('DgtPracticeScreen - toggle Pomodoro', () {
    testWidgets('tap icono Pomodoro arranca y muestra chip de tiempo',
        (tester) async {
      await tester.pumpWidget(_buildPractice(seed: _seedQuestions(3)));
      await tester.pumpAndSettle();

      // Estado inicial: icono timer (Pomodoro inactivo).
      expect(find.byIcon(Icons.timer_rounded), findsOneWidget);
      expect(find.byIcon(Icons.timer_off_rounded), findsNothing);

      // Tap Pomodoro. Solo verificamos cambio UI inmediato del setState,
      // sin esperar al ticker.
      await tester.tap(find.byIcon(Icons.timer_rounded));
      await tester.pump();

      // Pomodoro activo: icono cambia a timer_off y aparece chip 25:00.
      expect(find.byIcon(Icons.timer_off_rounded), findsOneWidget);
      expect(find.text('25:00'), findsOneWidget);

      // Apagamos antes de finalizar para cancelar el ticker (evita pending
      // timers warning al cerrar el test).
      await tester.tap(find.byIcon(Icons.timer_off_rounded));
      await tester.pump();
      expect(find.byIcon(Icons.timer_rounded), findsOneWidget);
      expect(find.text('25:00'), findsNothing);
    });
  });
}
