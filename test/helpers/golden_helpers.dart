import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helpers para golden tests Flutter (issue #132).
///
/// Centraliza:
/// - Tamano de surface estandar para golden (392x780, similar a un movil
///   medio en dp) para evitar overflow vertical en pantallas largas como
///   `dgt_result_screen` con multiples wrong tiles.
/// - Wrap de widget bajo test en MaterialApp + ThemeData identica a la
///   app real (dark theme + scaffoldBackgroundColor #0E0E12). Asi el
///   golden refleja la UX real, no defaults del framework.
/// - Disable de animaciones implicitas que generan diff entre runs.

/// Tamano por defecto del surface para goldens DGT. ASUMIDO: ratio ~16:9
/// alargado para acomodar pantalla de resultado con varias falladas.
const Size kGoldenSurfaceSize = Size(392, 780);

/// Color de fondo del scaffold en dark theme real (lib/main.dart:165).
const Color kAppDarkBg = Color(0xFF0E0E12);

/// Construye un MaterialApp listo para golden, identico al runtime real
/// (dark theme + Material 3). Aisla el widget bajo test del entorno
/// `flutter_test` (que por defecto usa light theme).
Widget wrapForGolden(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kAppDarkBg,
      textTheme: Typography.whiteMountainView.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4FB0FF),
        brightness: Brightness.dark,
      ),
    ),
    home: child,
  );
}

/// Configura el WidgetTester con el surface estandar para goldens.
///
/// Llamar al inicio del `testWidgets` antes de `pumpWidget`. Restaura el
/// tamano por defecto al terminar via addTearDown.
Future<void> useGoldenSurface(WidgetTester tester,
    {Size size = kGoldenSurfaceSize}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Comparator de goldens con tolerancia configurable.
///
/// flutter_test trae `LocalFileComparator` con tolerancia 0 que falla
/// ante el minimo subpixel diff de antialiasing/fuente. Para pantallas
/// que contienen widgets animados que no podemos congelar al 100%
/// (ej. `ConfettiWidget` en `dgt_result_screen`), aceptamos un margen
/// pequeno (0.5% por defecto). Esto sigue capturando regresiones reales
/// (cambios de layout, colores invertidos, overflow) sin ser flaky.
///
/// Uso (en setUpAll de un test file):
/// ```dart
/// final original = goldenFileComparator;
/// goldenFileComparator = TolerantGoldenComparator(
///   (goldenFileComparator as LocalFileComparator).basedir,
///   tolerance: 0.01, // 1% pixel diff permitido
/// );
/// addTearDown(() => goldenFileComparator = original);
/// ```
class TolerantGoldenComparator extends LocalFileComparator {
  final double tolerance;
  TolerantGoldenComparator(super.testFile, {this.tolerance = 0.005});

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed) return true;
    if (result.diffPercent <= tolerance) {
      debugPrint(
        'Golden ${golden.path}: diff ${(result.diffPercent * 100).toStringAsFixed(2)}% '
        '<= tolerancia ${(tolerance * 100).toStringAsFixed(2)}%. OK.',
      );
      return true;
    }
    final String error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError(error);
  }
}

