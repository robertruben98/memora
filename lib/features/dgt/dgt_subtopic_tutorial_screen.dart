import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';
import 'package:memora/core/widgets/card_with_icon_header.dart';

import 'dgt_tutorial_seen_provider.dart';
import 'dgt_tutorials_catalog.dart';

/// Tutorial breve pre-quiz (issue #153 dgt-ux).
///
/// Aparece ANTES del batch de preguntas de un subtopic, una sola vez por
/// topic_id (o hasta que el usuario lo marque "no mostrar mas"). Si no
/// existe entrada en `dgtTutorialsCatalog`, el caller NO debe abrir esta
/// pantalla — usar `lookupDgtTutorial` antes (silent fallback).
///
/// Resultado de la screen via `Navigator.pop`:
///   - `DgtTutorialResult.start`  -> usuario pulsa "Empezar 10 preguntas".
///   - `DgtTutorialResult.skip`   -> usuario pulsa skip (X arriba derecha).
///   - `DgtTutorialResult.suppress` -> usuario pulsa "No mostrar mas"; el
///     caller debe persistir via `DgtTutorialSeenStore.markSeen`.
///
/// No bloquea: cualquier resultado lleva al quiz. La distincion entre
/// `start` y `skip` es solo telemetria/UX — el flujo continua igual.
enum DgtTutorialResult { start, skip, suppress }

class DgtSubtopicTutorialScreen extends ConsumerWidget {
  /// id del topic — usado SOLO para `markSeen` cuando el usuario pulsa
  /// "No mostrar mas". El contenido viene del `tutorial` ya resuelto por
  /// el caller (evita doble lookup).
  final String topicId;

  /// Nombre legible del topic — encabezado de la pantalla.
  final String topicName;

  /// Tutorial pre-resuelto del catalogo. Inyectado por el caller para que
  /// la pantalla no sepa nada del map global.
  final DgtTutorial tutorial;

  const DgtSubtopicTutorialScreen({
    super.key,
    required this.topicId,
    required this.topicName,
    required this.tutorial,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Repaso rapido'),
        actions: [
          IconButton(
            tooltip: 'Saltar tutorial',
            onPressed: () =>
                Navigator.of(context).pop(DgtTutorialResult.skip),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topicName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Repaso de 30 segundos antes de las preguntas.',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.c.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 22),
                      CardWithIconHeader(
                        title: 'Concepto clave',
                        body: tutorial.concept,
                        accent: AppColors.brand,
                        icon: Icons.lightbulb_outline_rounded,
                      ),
                      const SizedBox(height: 14),
                      CardWithIconHeader(
                        title: 'Ejemplo',
                        body: tutorial.example,
                        accent: DgtStatusColors.success,
                        icon: Icons.check_circle_outline_rounded,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(DgtTutorialResult.start),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Empezar 10 preguntas',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => _onSuppress(context, ref),
                child: const Text('No mostrar mas para este tema'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSuppress(BuildContext context, WidgetRef ref) async {
    // Persistir antes de cerrar para que el caller pueda confiar en que el
    // estado ya esta escrito. SharedPreferences es local, no falla en
    // condiciones normales.
    await ref.read(dgtTutorialSeenStoreProvider).markSeen(topicId);
    if (!context.mounted) return;
    Navigator.of(context).pop(DgtTutorialResult.suppress);
  }
}
