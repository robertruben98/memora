import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dgt/dgt_autotest_screen.dart';
import '../../dgt/dgt_prediction.dart';
import '../../dgt/dgt_signals_catalog_screen.dart';
import '../../dgt/dgt_trick_questions_screen.dart';
import '../../dgt/dgt_warmup_screen.dart';
import '../../dgt/dgt_weak_focus_screen.dart';
import '../dgt_exam_history.dart';
import '../dgt_exam_screen.dart';
import '../dgt_history_screen.dart';
import '../dgt_sections_screen.dart';
import 'dgt_tile.dart';
import 'dgt_tile_spec.dart';

/// Registry inmutable de tiles DGT en el orden visual del Study Hub.
///
/// Issue #148: tile registry pattern. Antes habia 8 widgets `_DgtXxxTile`
/// inline (~80 LOC cada uno) y un `build()` que los componia con `SizedBox`s
/// intermedios. Cada feature DGT nueva forzaba a editar este archivo en dos
/// sitios -> cascade DIRTY/merge-conflicts (mismo patron que sufria
/// `app.seed_dgt` antes del registry auto-discovery ITER 39 en backend).
///
/// Ahora basta con anadir un `DgtTileSpec` aqui. La construccion del Column
/// se hace generica en `DgtStudySection.build`.
List<DgtTileSpec> buildDgtTileRegistry() {
  return <DgtTileSpec>[
    // 1. Simulacro DGT (hero). Issue original del modulo: tile principal con
    //    gradiente naranja oficial.
    DgtTileSpec(
      title: 'Simulacro DGT',
      subtitle: '30 preguntas, 30 minutos, criterio examen oficial',
      icon: Icons.directions_car_rounded,
      accentColor: const Color(0xFFFF6B35),
      variant: DgtTileVariant.hero,
      routeBuilder: (_, _) => const DgtExamScreen(),
    ),

    // 2. Atacar mi punto debil (condicional). Issue #134 (dgt-ux).
    //    Visible solo cuando dgtPredictionProvider tiene weakestTopic.
    DgtTileSpec(
      title: 'Atacar mi punto debil',
      subtitleBuilder: (ref) {
        final weakest = ref.watch(dgtPredictionProvider).maybeWhen(
              data: (p) => p.weakestTopic,
              orElse: () => null,
            );
        if (weakest == null) return '';
        final pct = weakest.accuracyPct.toStringAsFixed(0);
        final topicName = weakest.topicName ?? weakest.topicId;
        return 'Foco: $topicName  ·  $pct% acierto';
      },
      icon: Icons.gps_fixed_rounded,
      accentColor: const Color(0xFFFF5C5C),
      badgeText: 'Adaptativo',
      visibleWhen: (ref) {
        return ref.watch(dgtPredictionProvider).maybeWhen(
              data: (p) => p.weakestTopic != null,
              orElse: () => false,
            );
      },
      routeBuilder: (_, _) => const DgtWeakFocusScreen(),
    ),

    // 3. Calentar 5 min. Issue #135 (dgt-ux). Cerca del CTA principal para
    //    que el estudiante elija warmup ligero vs simulacro completo.
    DgtTileSpec(
      title: 'Calentar 5 min',
      subtitle: '10 preguntas variadas, sin timer. No cuenta historial',
      icon: Icons.local_fire_department_rounded,
      accentColor: const Color(0xFF7C5CFF),
      routeBuilder: (_, _) => const DgtWarmupScreen(),
    ),

    // 4. Historial de simulacros (subtitulo dinamico segun count).
    DgtTileSpec(
      title: 'Historial de simulacros',
      subtitleBuilder: (ref) {
        final count = ref.watch(dgtExamHistoryProvider).maybeWhen(
                  data: (entries) => entries.length,
                  orElse: () => null,
                ) ??
            0;
        if (count <= 0) return 'Aun sin simulacros completados';
        final plural = count == 1 ? '' : 's';
        return '$count simulacro$plural guardado$plural';
      },
      icon: Icons.history_rounded,
      accentColor: const Color(0xFFFF6B35),
      routeBuilder: (_, _) => const DgtHistoryScreen(),
    ),

    // 5. Trampas frecuentes. Issue dgt-ux trick questions.
    DgtTileSpec(
      title: 'Trampas frecuentes',
      subtitle: 'Practica las palabras siempre / nunca / excepto / solo',
      icon: Icons.warning_amber_rounded,
      accentColor: const Color(0xFFFFB74F),
      badgeText: 'Anti-trampa',
      routeBuilder: (_, _) => const DgtTrickQuestionsScreen(),
    ),

    // 6. Autotest mental. Issue #127 (dgt-ux). Active recall sin opciones.
    DgtTileSpec(
      title: 'Autotest mental',
      subtitle: 'Pregunta sin opciones. Piensa, revela, self-report.',
      icon: Icons.psychology_alt_rounded,
      accentColor: const Color(0xFFB9A6FF),
      badgeText: 'Active recall',
      routeBuilder: (_, _) => const DgtAutotestScreen(),
    ),

    // 7. Estudiar por Secciones (variante section, gap mayor previo).
    DgtTileSpec(
      title: 'Estudiar por Secciones',
      subtitle: 'Clases teoricas DGT por bloque tematico (lectura)',
      icon: Icons.menu_book_rounded,
      accentColor: const Color(0xFF7C5CFF),
      variant: DgtTileVariant.section,
      leadingGap: 14,
      routeBuilder: (_, _) => const DgtStudySectionsScreen(),
    ),

    // 8. Catalogo de senales.
    DgtTileSpec(
      title: 'Catalogo de senales',
      subtitle: 'Repasa senales por categoria (peligro, prohibicion...)',
      icon: Icons.traffic_rounded,
      accentColor: const Color(0xFF4FFFB0),
      routeBuilder: (_, _) => const DgtSignalsCatalogScreen(),
    ),
  ];
}

/// DGT-specific study modes section.
///
/// Renderiza el registry `buildDgtTileRegistry()` filtrando por
/// `visibleWhen` y respetando el `leadingGap` declarado en cada spec.
/// Para anadir un tile nuevo: agregar un `DgtTileSpec` al registry. NO editar
/// este `build()`.
class DgtStudySection extends ConsumerWidget {
  const DgtStudySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = buildDgtTileRegistry();
    final visible =
        registry.where((spec) => spec.isVisible(ref)).toList(growable: false);

    final children = <Widget>[];
    for (var i = 0; i < visible.length; i++) {
      if (i > 0) {
        children.add(SizedBox(height: visible[i].leadingGap));
      }
      children.add(DgtTile(spec: visible[i]));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
