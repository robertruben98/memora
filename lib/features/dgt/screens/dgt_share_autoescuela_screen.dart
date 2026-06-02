import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/widgets/app_state_view.dart';

import '../services/dgt_share_snapshot.dart';

/// Issue #182 (dgt-ux): pantalla "Compartir progreso con autoescuela".
///
/// Muestra un snapshot read-only con:
/// - QR code (qr_flutter) que codifica `memora://share/dgt/<token>`.
/// - URL en texto bajo el QR para que el profesor la verifique.
/// - Boton `Share.share()` con el texto humano (predictor, racha, etc.).
/// - Cuerpo con metricas publicas: % aprobado, racha, total mes, tema debil,
///   fecha examen objetivo.
///
/// NO incluye: email, lista de preguntas falladas, ni tokens auth. El QR
/// codifica solo el deeplink, que abre la app en vista read-only (la app
/// puede deserializar el snapshot a partir del token + datos locales).
class DgtShareAutoescuelaScreen extends ConsumerWidget {
  const DgtShareAutoescuelaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(dgtShareSnapshotProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Compartir con autoescuela')),
      body: snapshotAsync.when(
        loading: () => AppStateView.loading(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se pudo generar el snapshot.\n$e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (snap) => _Body(snapshot: snap),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final DgtShareSnapshot snapshot;
  const _Body({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final text = snapshot.buildHumanText();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _HeaderCopy(),
          const SizedBox(height: 16),
          _SnapshotCard(snapshot: snapshot),
          const SizedBox(height: 16),
          _QrCard(deeplink: snapshot.deeplink),
          const SizedBox(height: 12),
          SelectableText(
            snapshot.deeplink,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: context.c.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('dgt-share-autoescuela-share-button'),
            onPressed: () => Share.share(text, subject: 'Mi progreso DGT'),
            icon: const Icon(Icons.share_rounded),
            label: const Text('Compartir resumen'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('dgt-share-autoescuela-copy-link'),
            onPressed: () => Share.share(snapshot.deeplink, subject: 'Link DGT'),
            icon: const Icon(Icons.link_rounded),
            label: const Text('Compartir solo el link'),
          ),
          const SizedBox(height: 24),
          const _Disclaimer(),
        ],
      ),
    );
  }
}

class _HeaderCopy extends StatelessWidget {
  const _HeaderCopy();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Envia este resumen a tu profesor de autoescuela. Solo incluye '
      'metricas agregadas (no preguntas falladas ni email). El profesor '
      'puede escanear el QR para abrir tu progreso en modo verificacion.',
      style: TextStyle(fontSize: 13, color: context.c.textSecondary),
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  final DgtShareSnapshot snapshot;
  const _SnapshotCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.c.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen de progreso',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _Row(
            label: 'Prediccion aprobado',
            value: snapshot.hasPrediction
                ? '${snapshot.expectedScorePct!.toStringAsFixed(0)}%'
                : 'Datos insuficientes',
          ),
          _Row(
            label: 'Racha actual',
            value: '${snapshot.currentStreak} dias',
          ),
          _Row(
            label: 'Respuestas este mes',
            value: '${snapshot.monthlyAnswered}',
          ),
          if (snapshot.weakestTopicId != null &&
              snapshot.weakestTopicAccuracyPct != null)
            _Row(
              label: 'Tema mas debil',
              value:
                  '${snapshot.weakestTopicId!} (${snapshot.weakestTopicAccuracyPct!.toStringAsFixed(0)}%)',
            ),
          if (snapshot.examDate != null)
            _Row(
              label: 'Examen objetivo',
              value:
                  '${snapshot.examDate!.year}-${snapshot.examDate!.month.toString().padLeft(2, '0')}-${snapshot.examDate!.day.toString().padLeft(2, '0')}',
            ),
          const SizedBox(height: 8),
          Text(
            'Generado: ${snapshot.generatedAt.toIso8601String().split('T').first}',
            style: TextStyle(
              fontSize: 11,
              color: context.c.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: context.c.textSecondary, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  final String deeplink;
  const _QrCard({required this.deeplink});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: QrImageView(
          key: const Key('dgt-share-autoescuela-qr'),
          data: deeplink,
          version: QrVersions.auto,
          size: 220,
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Este snapshot se genera localmente. No se sube a ningun servidor. '
      'El token cambia cada dia para que el profesor sepa que es reciente.',
      style: TextStyle(fontSize: 11, color: context.c.textMuted),
      textAlign: TextAlign.center,
    );
  }
}
