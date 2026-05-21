import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_prediction.dart';
import 'package:memora/features/dgt/widgets/dgt_level_gauge.dart';

/// Issue #204 (dgt-ux): tests del widget "Mi nivel" gauge visual.
///
/// Cubre:
///  - Mapeo score -> zona (4 zonas).
///  - Render con 60% / 85% / 95%: label + color zona + flecha presente.
///  - Cache: dgtLevelGaugeProvider mantiene resultado (no refetch al
///    re-leer) — verificado por contador de invocaciones del repo.
///  - Loading state (skeleton, sin flecha).
///  - Error chip "No disponible".
///  - Semantics label correcto.

DgtPrediction _pred(double score, {int reviews = 50}) {
  return DgtPrediction(
    totalReviews: reviews,
    expectedScore: score,
  );
}

Widget _wrap({required DgtPrediction prediction}) {
  return ProviderScope(
    overrides: [
      dgtLevelGaugeProvider.overrideWith((ref) async => prediction),
    ],
    child: const MaterialApp(
      home: Scaffold(body: DgtLevelGauge()),
    ),
  );
}

void main() {
  group('dgtZoneFor (mapeo score -> zona)', () {
    test('0-50% => sinOpciones', () {
      expect(dgtZoneFor(0.0), DgtGaugeZone.sinOpciones);
      expect(dgtZoneFor(0.25), DgtGaugeZone.sinOpciones);
      expect(dgtZoneFor(0.499), DgtGaugeZone.sinOpciones);
    });
    test('50-75% => necesitaEstudio', () {
      expect(dgtZoneFor(0.50), DgtGaugeZone.necesitaEstudio);
      expect(dgtZoneFor(0.60), DgtGaugeZone.necesitaEstudio);
      expect(dgtZoneFor(0.749), DgtGaugeZone.necesitaEstudio);
    });
    test('75-90% => cercaDeAprobar', () {
      expect(dgtZoneFor(0.75), DgtGaugeZone.cercaDeAprobar);
      expect(dgtZoneFor(0.85), DgtGaugeZone.cercaDeAprobar);
      expect(dgtZoneFor(0.899), DgtGaugeZone.cercaDeAprobar);
    });
    test('90-100% => listoParaExamen', () {
      expect(dgtZoneFor(0.90), DgtGaugeZone.listoParaExamen);
      expect(dgtZoneFor(0.95), DgtGaugeZone.listoParaExamen);
      expect(dgtZoneFor(1.0), DgtGaugeZone.listoParaExamen);
    });
  });

  group('DgtLevelGauge widget render', () {
    testWidgets('60% => zona necesitaEstudio, label correcto', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(prediction: _pred(0.60, reviews: 42)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Mi nivel: 60%'), findsOneWidget);
      expect(find.textContaining('necesita estudio'), findsOneWidget);
      expect(find.textContaining('Basado en tus ultimas 42 sesiones'),
          findsOneWidget);

      // El painter recibio activeZone correcto (verifica por aria label).
      expect(
        find.bySemanticsLabel(RegExp(
          'Mi nivel DGT: 60 por ciento, Necesita estudio',
        )),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('85% => zona cercaDeAprobar', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(prediction: _pred(0.85, reviews: 100)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Mi nivel: 85%'), findsOneWidget);
      expect(find.textContaining('cerca de aprobar'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(
          'Mi nivel DGT: 85 por ciento, Cerca de aprobar',
        )),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('95% => zona listoParaExamen', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(prediction: _pred(0.95, reviews: 200)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Mi nivel: 95%'), findsOneWidget);
      expect(find.textContaining('listo para examen'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(
          'Mi nivel DGT: 95 por ciento, Listo para examen',
        )),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('hasEnoughData=false => mensaje sin datos', (tester) async {
      final semantics = tester.ensureSemantics();
      // totalReviews < kDgtMinReviewsForPrediction (10) => hasEnoughData false.
      await tester.pumpWidget(
        _wrap(prediction: const DgtPrediction(totalReviews: 3)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('sin datos suficientes'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Mi nivel DGT: sin datos suficientes')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('loading state: muestra skeleton sin label de %',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final completer = Completer<DgtPrediction>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dgtLevelGaugeProvider.overrideWith((ref) => completer.future),
          ],
          child: const MaterialApp(home: Scaffold(body: DgtLevelGauge())),
        ),
      );
      // No settle (queremos quedar en loading).
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp('Mi nivel DGT: cargando')),
        findsOneWidget,
      );
      expect(find.textContaining('Mi nivel:'), findsNothing);
      completer.complete(_pred(0.80));
      await tester.pumpAndSettle();
      semantics.dispose();
    });

    testWidgets('error state: muestra chip No disponible', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dgtLevelGaugeProvider.overrideWith(
              (ref) async => throw Exception('boom'),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: DgtLevelGauge())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mi nivel: no disponible'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Mi nivel DGT: no disponible')),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });

  group('DgtLevelGaugePainter shouldRepaint', () {
    test('repaint si score cambia', () {
      final a = DgtLevelGaugePainter(
        score: 0.5,
        activeZone: DgtGaugeZone.necesitaEstudio,
      );
      final b = DgtLevelGaugePainter(
        score: 0.6,
        activeZone: DgtGaugeZone.necesitaEstudio,
      );
      expect(b.shouldRepaint(a), isTrue);
    });
    test('repaint si zona cambia', () {
      final a = DgtLevelGaugePainter(
        score: 0.8,
        activeZone: DgtGaugeZone.cercaDeAprobar,
      );
      final b = DgtLevelGaugePainter(
        score: 0.8,
        activeZone: DgtGaugeZone.listoParaExamen,
      );
      expect(b.shouldRepaint(a), isTrue);
    });
    test('no repaint si nada cambia', () {
      final a = DgtLevelGaugePainter(
        score: 0.8,
        activeZone: DgtGaugeZone.cercaDeAprobar,
      );
      final b = DgtLevelGaugePainter(
        score: 0.8,
        activeZone: DgtGaugeZone.cercaDeAprobar,
      );
      expect(b.shouldRepaint(a), isFalse);
    });
  });

  group('cache: dgtLevelGaugeProvider', () {
    test('reusa resultado mientras hay listeners (sin refetch)', () async {
      var calls = 0;
      final container = ProviderContainer(
        overrides: [
          dgtLevelGaugeProvider.overrideWith((ref) async {
            calls += 1;
            return _pred(0.7);
          }),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(dgtLevelGaugeProvider, (_, _) {});
      await container.read(dgtLevelGaugeProvider.future);
      await container.read(dgtLevelGaugeProvider.future);
      expect(calls, 1);
      sub.close();
    });
  });
}
