import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/repositories/dgt_repository.dart';
import 'package:memora/features/dgt/dgt_prediction.dart';

/// Helpers para golden tests de pantallas DGT (issue #132).
///
/// Filosofia:
/// - Render determinista: theme dark fijo, surface size fija, sin animaciones
///   abiertas (confetti se silencia y se hace `pump(...)` con duracion
///   acotada en lugar de `pumpAndSettle`).
/// - Datos mockeados: ningun test toca red ni storage real.
/// - Goldens viven en `test/golden/goldens/` y son regenerables con
///   `flutter test --update-goldens`. En CI fallan si difieren.
///
/// Ver README de tests para la receta de regeneracion.

/// Tema dark estable equivalente al de produccion (lib/main.dart) pero
/// inyectado a mano para no depender de bootstrap del app.
ThemeData buildGoldenDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7C5CFF),
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF0E0E12),
    textTheme: Typography.whiteMountainView.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
  );
}

/// Tamanio de "telefono" estable para snapshots (logical px).
const Size kGoldenPhoneSize = Size(390, 844);

/// Wrappea [child] con `MaterialApp` + tema dark + `ProviderScope`
/// (con [overrides] opcionales). Tambien fija el viewport via
/// `MediaQuery` para que sea reproducible incluso si la suite no
/// configuro `tester.view`.
Widget wrapForGolden(
  Widget child, {
  List<Override> overrides = const [],
  Size size = kGoldenPhoneSize,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildGoldenDarkTheme(),
      darkTheme: buildGoldenDarkTheme(),
      themeMode: ThemeMode.dark,
      home: MediaQuery(
        data: MediaQueryData(size: size, devicePixelRatio: 1.0),
        child: child,
      ),
    ),
  );
}

/// Fija el viewport de [tester] al tamanio standard del snapshot. Hay
/// que llamarlo *antes* de `pumpWidget` para evitar relayouts.
Future<void> setGoldenViewport(
  WidgetTester tester, {
  Size size = kGoldenPhoneSize,
}) async {
  tester.view.physicalSize = size * 1.0;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Silencia el haptic feedback (lo dispara `DgtResultScreen` al aprobar)
/// y evita ruido de canales nativos en tests. Se restaura via [addTearDown].
void mockHapticFeedback(WidgetTester tester) {
  final binding = tester.binding;
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
  addTearDown(() {
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
}

/// Builder de [DgtQuestion] minimo para mocks reproducibles. Mantiene
/// los textos cortos y deterministas para que el golden sea estable.
DgtQuestion goldenQuestion({
  String id = 'q-01',
  String statement = 'A que distancia se debe encender la luz de cruce?',
  String optionA = '50 metros',
  String optionB = '150 metros',
  String optionC = '200 metros',
  String correct = 'b',
  String? explanation =
      'Articulo 99 RGCir: luz de cruce obligatoria a partir del crepusculo.',
  String? topic = 'Senales',
}) {
  return DgtQuestion(
    id: id,
    statement: statement,
    optionA: optionA,
    optionB: optionB,
    optionC: optionC,
    correct: correct,
    explanation: explanation,
    topic: topic,
  );
}

/// Builder de [DgtTopicStat] minimo para mocks.
DgtTopicStat goldenStat({
  required String id,
  String? name,
  required int total,
  required int correct,
}) {
  final pct = total == 0 ? 0.0 : (correct / total) * 100.0;
  return DgtTopicStat(
    topicId: id,
    topicName: name,
    totalAnswered: total,
    correct: correct,
    accuracyPct: pct,
  );
}

/// Avanza el reloj lo justo para que el layout estabilice pero ANTES de
/// que el `ConfettiController` empiece a emitir particulas visibles. El
/// controller llama a `play()` en `initState` con `emissionFrequency=0.05`,
/// asi que con un solo `pump()` (frame de layout) las particulas aun no
/// han entrado en el arbol de pintado.
///
/// Esto hace el golden determinista: la geometria de la pantalla es
/// estable, pero el ruido aleatorio del confetti no contamina el PNG.
Future<void> pumpAfterConfetti(WidgetTester tester) async {
  await tester.pump();
  // No mas pumps con duracion: el confetti emite si el clock avanza.
}

/// Stub para compat: `flutter_test` ya configura la fuente "Ahem" para
/// que el render sea determinista en CI. Si en el futuro pasamos a Roboto
/// real via `golden_toolkit`, este es el unico sitio a tocar.
Future<void> loadGoldenFonts() async {
  // Intencionalmente vacio. `flutter_test` usa la fuente test por defecto
  // (Ahem) que produce glifos reproducibles entre plataformas.
}

/// Comparator de goldens que tolera hasta [tolerance] diff de pixeles
/// (0.0 a 1.0). Necesario para `DgtResultScreen` cuando se aprueba: el
/// `ConfettiController` emite particulas con `Random` no seedeable, asi
/// que un pequeno % de pixeles puede variar entre corridas aunque el
/// layout principal sea identico.
///
/// Solo wrappea `LocalFileComparator` (el default de `flutter test` en
/// IO). Para web o entornos custom, cae al comparator original sin
/// envolverlo.
class TolerantGoldenComparator extends LocalFileComparator {
  final LocalFileComparator _delegate;

  /// Fraccion (0..1) de pixeles que pueden diferir antes de fallar.
  /// Default 1% es suficiente para tolerar el ruido del confetti sin
  /// dejar pasar cambios significativos de layout.
  final double tolerance;

  TolerantGoldenComparator(this._delegate, {this.tolerance = 0.01})
      : super(Uri.parse('${_delegate.basedir}placeholder_test.dart'));

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final masterBytes = await _delegate.getGoldenBytes(golden);
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      masterBytes,
    );
    if (result.passed) {
      result.dispose();
      return true;
    }
    if (result.diffPercent <= tolerance) {
      debugPrint(
        'TolerantGoldenComparator: ${golden.path} '
        'difiere ${(result.diffPercent * 100).toStringAsFixed(3)}% '
        '(<= ${(tolerance * 100).toStringAsFixed(2)}% tolerado).',
      );
      result.dispose();
      return true;
    }
    final error = 'Golden ${golden.path}: diff '
        '${(result.diffPercent * 100).toStringAsFixed(3)}% '
        '> ${(tolerance * 100).toStringAsFixed(2)}% tolerado.\n${result.error}';
    result.dispose();
    throw FlutterError(error);
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) {
    return _delegate.update(golden, imageBytes);
  }
}

/// Helper para instalar el comparator tolerante alrededor de un grupo
/// de tests. Restaura el comparator original en `addTearDown`.
///
/// La tolerancia default (1%) absorbe el ruido del confetti random pero
/// hace fallar cambios reales de layout (que tipicamente afectan mucho
/// mas del 1% de los pixeles).
void useTolerantGoldenComparator({double tolerance = 0.01}) {
  final original = goldenFileComparator;
  if (original is! LocalFileComparator) {
    // En entornos no-IO dejamos el comparator default; no hay confetti
    // que tolerar tampoco.
    return;
  }
  goldenFileComparator = TolerantGoldenComparator(
    original,
    tolerance: tolerance,
  );
  addTearDown(() {
    goldenFileComparator = original;
  });
}

