import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/screens/dgt_share_autoescuela_screen.dart';
import 'package:memora/features/dgt/services/dgt_share_snapshot.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Issue #182 (dgt-ux): widget tests para la pantalla "Compartir progreso
/// con autoescuela". Override `dgtShareSnapshotProvider` con fakes para no
/// depender del backend (offline-first).
///
/// Casos:
/// - Loading muestra CircularProgressIndicator.
/// - Con prediccion: muestra %, racha, total mes, tema debil, fecha examen,
///   QR (QrImageView) y deeplink.
/// - Sin prediccion: muestra "Datos insuficientes" pero el QR sigue
///   renderizando (offline-first).
/// - Boton compartir esta presente.

DgtShareSnapshot _fullSnapshot() => DgtShareSnapshot(
      token: 'tok-abc-12345678',
      expectedScorePct: 87.0,
      currentStreak: 9,
      monthlyAnswered: 240,
      weakestTopicId: 'senales',
      weakestTopicAccuracyPct: 52.0,
      examDate: DateTime(2026, 7, 10),
      generatedAt: DateTime(2026, 5, 21),
    );

DgtShareSnapshot _emptySnapshot() => DgtShareSnapshot(
      token: 'tok-empty-0000000',
      currentStreak: 0,
      monthlyAnswered: 0,
      generatedAt: DateTime(2026, 5, 21),
    );

Widget _harness(
  AsyncValue<DgtShareSnapshot> async, {
  Completer<DgtShareSnapshot>? loadingCompleter,
}) {
  return ProviderScope(
    overrides: [
      dgtShareSnapshotProvider.overrideWith((ref) async {
        if (async is AsyncData<DgtShareSnapshot>) return async.value;
        if (async is AsyncError<DgtShareSnapshot>) {
          throw async.error;
        }
        // Loading: usar Completer que el test controla para evitar timers pending.
        return loadingCompleter?.future ??
            Future<DgtShareSnapshot>.value(_emptySnapshot());
      }),
    ],
    child: const MaterialApp(home: DgtShareAutoescuelaScreen()),
  );
}

void main() {
  testWidgets('muestra CircularProgressIndicator en loading', (tester) async {
    final completer = Completer<DgtShareSnapshot>();
    await tester.pumpWidget(
      _harness(const AsyncLoading(), loadingCompleter: completer),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Resuelve antes de finalizar test para evitar future pendiente.
    completer.complete(_emptySnapshot());
    await tester.pumpAndSettle();
  });

  testWidgets('con snapshot completo: renderiza metricas + QR + deeplink',
      (tester) async {
    final snap = _fullSnapshot();
    await tester.pumpWidget(_harness(AsyncData(snap)));
    await tester.pumpAndSettle();

    expect(find.text('87%'), findsOneWidget);
    expect(find.text('9 dias'), findsOneWidget);
    expect(find.text('240'), findsOneWidget);
    expect(find.textContaining('senales'), findsOneWidget);
    expect(find.text('2026-07-10'), findsOneWidget);
    expect(find.textContaining('memora://share/dgt/tok-abc'), findsOneWidget);
    expect(find.byKey(const Key('dgt-share-autoescuela-qr')), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(
      find.byKey(const Key('dgt-share-autoescuela-share-button')),
      findsOneWidget,
    );
  });

  testWidgets('sin prediccion: muestra "Datos insuficientes" pero QR existe',
      (tester) async {
    await tester.pumpWidget(_harness(AsyncData(_emptySnapshot())));
    await tester.pumpAndSettle();

    expect(find.text('Datos insuficientes'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('error: muestra fallback con texto de error', (tester) async {
    await tester.pumpWidget(
      _harness(AsyncError<DgtShareSnapshot>(
        Exception('boom'),
        StackTrace.current,
      )),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No se pudo generar'), findsOneWidget);
  });
}
