import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/data/topic_pills.dart';
import 'package:memora/features/dgt/widgets/topic_pill_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue #110 (dgt-content): test widget basico para [DgtTopicPillSheet].
///
/// Cubre:
/// - maybeShow no muestra si no hay pildora definida.
/// - maybeShow muestra el bottom sheet la primera vez para topic critico.
/// - Tap "Saltar" marca seen=true (no se vuelve a mostrar).
/// - Tap "OK, empezar" cierra sin marcar seen si checkbox off.

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<bool> pumpAndOpen(WidgetTester tester, String topicId) async {
    bool shown = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  shown = await DgtTopicPillSheet.maybeShow(
                    context: ctx,
                    topicId: topicId,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return shown;
  }

  testWidgets('no muestra sheet si no hay pildora para el topic',
      (tester) async {
    await pumpAndOpen(tester, 'tema-inexistente-xyz');
    expect(find.text('Repaso rapido antes de practicar'), findsNothing);
  });

  testWidgets('muestra sheet la primera vez para tema critico',
      (tester) async {
    await pumpAndOpen(tester, 'primeros-auxilios');
    expect(find.text('Primeros auxilios'), findsOneWidget);
    expect(find.text('Repaso rapido antes de practicar'), findsOneWidget);
    expect(find.text('OK, empezar'), findsOneWidget);
    expect(find.text('Saltar'), findsOneWidget);
    // Mnemotecnia presente.
    expect(find.textContaining('PAS'), findsWidgets);
  });

  testWidgets('tap Saltar marca seen=true y no vuelve a mostrar',
      (tester) async {
    await pumpAndOpen(tester, 'alcohol-drogas');
    expect(find.text('Alcohol y drogas'), findsOneWidget);

    await tester.tap(find.text('Saltar'));
    await tester.pumpAndSettle();
    expect(find.text('Alcohol y drogas'), findsNothing);

    // Segundo intento: no muestra.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('${kDgtPillSeenPrefix}alcohol-drogas'), isTrue);
  });

  testWidgets(
      'tap OK empezar sin checkbox no marca seen (puede volver a mostrar)',
      (tester) async {
    await pumpAndOpen(tester, 'normas');
    expect(find.text('Distancia de seguridad y adelantamiento'),
        findsOneWidget);

    await tester.tap(find.text('OK, empezar'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('${kDgtPillSeenPrefix}normas'), isNot(isTrue));
  });

  testWidgets('checkbox "No mostrar otra vez" + OK marca seen=true',
      (tester) async {
    await pumpAndOpen(tester, 'prioridad');
    expect(find.text('Glorietas y prioridad'), findsOneWidget);

    // Marca el checkbox.
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    await tester.tap(find.text('OK, empezar'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('${kDgtPillSeenPrefix}prioridad'), isTrue);
  });

  testWidgets('todos los 5 temas criticos tienen pildora definida',
      (tester) async {
    expect(pillForTopic('primeros-auxilios'), isNotNull);
    expect(pillForTopic('normas'), isNotNull);
    expect(pillForTopic('alcohol-drogas'), isNotNull);
    expect(pillForTopic('prioridad'), isNotNull);
    expect(pillForTopic('velocidad'), isNotNull);
    expect(pillForTopic('senales'), isNull); // no critico
  });
}
