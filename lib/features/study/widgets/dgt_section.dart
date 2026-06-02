import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memora/core/theme/dgt_status_colors.dart';

import '../../dgt/dgt_achievements_screen.dart';
import '../../dgt/dgt_autotest_screen.dart';
import '../../dgt/dgt_cohort_compare_screen.dart';
import '../../dgt/dgt_conceptual_errors_screen.dart';
import '../../dgt/dgt_exam_calendar_screen.dart';
import '../../dgt/dgt_prediction.dart';
import '../../dgt/dgt_recurrent_failures_screen.dart';
import '../../dgt/dgt_settings_screen.dart';
import '../../dgt/dgt_sprint_extreme_screen.dart';
import '../../dgt/dgt_top_failures_screen.dart';
import '../../dgt/dgt_signals_catalog_screen.dart';
import '../../dgt/dgt_today_study_screen.dart';
import '../../dgt/dgt_trick_questions_screen.dart';
import '../../dgt/dgt_true_false_screen.dart';
import '../../dgt/dgt_warmup_screen.dart';
import '../../dgt/dgt_weak_focus_screen.dart';
import '../../dgt/dgt_weekly_evolution_screen.dart';
import '../dgt_exam_history.dart';
import '../dgt_exam_screen.dart';
import '../dgt_history_screen.dart';
import '../dgt_sections_screen.dart';
import 'dgt_tile.dart';
import 'dgt_tile_spec.dart';

/// DGT-specific study modes section.
///
/// Encapsula los tiles DGT (Simulacro, Historial, Estudio por Secciones, etc.)
/// usando un patron de registry declarativo: cada tile es un `DgtTileSpec` en
/// `kDgtTileRegistry`. Agregar tile nuevo = anadir entrada al registry. NO
/// requiere editar este archivo ni duplicar boilerplate de Material/InkWell.
///
/// Issue #148 (dgt-tech): refactor desde 785 LOC con 8 widgets duplicados.
class DgtStudySection extends ConsumerWidget {
  const DgtStudySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = <Widget>[];
    var first = true;
    for (final spec in kDgtTileRegistry) {
      if (spec.visibleWhen != null && !spec.visibleWhen!(ref)) continue;
      if (!first) tiles.add(SizedBox(height: spec.spacingBefore));
      tiles.add(DgtTile(spec: spec));
      first = false;
    }
    // Issue #191 (dgt-tech): wrap la seccion en Semantics(header: true) para
    // screen readers (TalkBack / VoiceOver). El label anuncia la region como
    // "Seccion DGT" antes de leer los tiles individuales.
    return Semantics(
      header: true,
      label: 'Seccion DGT. Modos de estudio para el examen teorico.',
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: tiles,
      ),
    );
  }
}

/// Registry de tiles DGT en orden visual de aparicion.
///
/// Para agregar un tile DGT nuevo: solo anadir un `DgtTileSpec` en la posicion
/// deseada. NO editar el `build()` de `DgtStudySection`. NO crear widget
/// nuevo (usar variants existentes: hero/primary/standard).
final List<DgtTileSpec> kDgtTileRegistry = [
  // Hero: simulacro DGT (CTA principal).
  DgtTileSpec(
    title: 'Simulacro DGT',
    subtitleBuilder: (_) => '30 preguntas, 30 minutos, criterio examen oficial',
    icon: Icons.directions_car_rounded,
    accentColor: const Color(0xFFFF6B35),
    gradientEndColor: const Color(0xFFFFA552),
    variant: DgtTileVariant.hero,
    routeBuilder: (_) => const DgtExamScreen(),
  ),

  // Issue #167 (dgt-ux): "Estudio de hoy" auto-curated. Sesion mixta de 15
  // preguntas (5 weak + 5 recurrentes + 5 nuevas). Tile visible siempre,
  // sobre fold y debajo del simulacro principal.
  DgtTileSpec(
    title: 'Estudio de hoy',
    subtitleBuilder: (_) => '15 preguntas, ~12 min · auto-curada',
    icon: Icons.today_rounded,
    accentColor: DgtStatusColors.info,
    primaryIconColor: const Color(0xFF9FCBFF),
    variant: DgtTileVariant.primary,
    routeBuilder: (_) => const DgtTodayStudyScreen(),
    badgeBuilder: (_) => const DgtTileBadge(
      text: 'Recomendado',
      color: DgtStatusColors.info,
    ),
  ),

  // Issue #134 (dgt-ux): "Atacar mi punto debil" condicional. Solo visible si
  // la prediccion identifica un weakest_topic con datos suficientes.
  DgtTileSpec(
    title: 'Atacar mi punto debil',
    subtitleBuilder: (ref) {
      final weakest = ref.watch(dgtPredictionProvider).maybeWhen(
            data: (p) => p.weakestTopic,
            orElse: () => null,
          );
      if (weakest == null) return '';
      final name = weakest.topicName ?? weakest.topicId;
      final pct = weakest.accuracyPct.toStringAsFixed(0);
      return 'Foco: $name  ·  $pct% acierto';
    },
    icon: Icons.gps_fixed_rounded,
    accentColor: DgtStatusColors.error,
    routeBuilder: (_) => const DgtWeakFocusScreen(),
    visibleWhen: (ref) => ref.watch(dgtPredictionProvider).maybeWhen(
          data: (p) => p.weakestTopic != null,
          orElse: () => false,
        ),
    badgeBuilder: (_) => const DgtTileBadge(
      text: 'Adaptativo',
      color: DgtStatusColors.error,
    ),
  ),

  // Issue #154 (dgt-ux): erratas personales recurrentes (fallos >= N veces).
  DgtTileSpec(
    title: 'Errores recurrentes',
    subtitleBuilder: (_) =>
        'Repasa las preguntas que fallas una y otra vez (>= 2 veces)',
    icon: Icons.repeat_rounded,
    accentColor: DgtStatusColors.error,
    routeBuilder: (_) => const DgtRecurrentFailuresScreen(),
    badgeBuilder: (_) => const DgtTileBadge(
      text: 'Erratas',
      color: DgtStatusColors.error,
    ),
  ),

  // Issue #190 (dgt-ux): "Top 5 fallos del mes" con insight de palabras
  // trampa (siempre/nunca/excepto/solo). Vista compacta y predictiva basada
  // en feedback de autoescuelas (autoescuelago, Velasco, Dribo).
  DgtTileSpec(
    title: 'Top 5 fallos del mes',
    subtitleBuilder: (_) =>
        'Tus 5 preguntas peor llevadas + insight de palabras trampa',
    icon: Icons.trending_down_rounded,
    accentColor: DgtStatusColors.warning,
    routeBuilder: (_) => const DgtTopFailuresScreen(),
    badgeBuilder: (_) => const DgtTileBadge(
      text: 'Predictivo',
      color: DgtStatusColors.warning,
    ),
  ),

  // Issue #195 (dgt-ux): fallos agrupados por concepto + practica similares.
  // Visualiza errores recurrentes agrupados por topic (prioridades,
  // adelantamiento, ADAS, etc.) y permite lanzar quiz `concept-related`
  // para estudio dirigido.
  DgtTileSpec(
    title: 'Errores conceptuales',
    subtitleBuilder: (_) =>
        'Tus fallos agrupados por concepto. Estudio dirigido.',
    icon: Icons.psychology_alt_rounded,
    accentColor: const Color(0xFFB9A6FF),
    routeBuilder: (_) => const DgtConceptualErrorsScreen(),
    badgeBuilder: (_) => const DgtTileBadge(
      text: 'Conceptos',
      color: Color(0xFFB9A6FF),
    ),
  ),

  // Issue #135 (dgt-ux): warmup ligero, justo debajo del simulacro principal.
  DgtTileSpec(
    title: 'Calentar 5 min',
    subtitleBuilder: (_) =>
        '10 preguntas variadas, sin timer. No cuenta historial',
    icon: Icons.local_fire_department_rounded,
    accentColor: const Color(0xFF7C5CFF),
    routeBuilder: (_) => const DgtWarmupScreen(),
  ),

  // Issue #210 (dgt-ux): "Sprint extremo" - 30 preguntas en 5 minutos, sin
  // pausa, auto-skip 12s/preg. Entrena velocidad de decision bajo presion.
  DgtTileSpec(
    title: 'Sprint extremo',
    subtitleBuilder: (_) =>
        '30 preguntas en 5 min, sin pausa, auto-skip 12s',
    icon: Icons.bolt_rounded,
    accentColor: DgtStatusColors.error,
    routeBuilder: (_) => const DgtSprintExtremeScreen(),
    badgeBuilder: (_) => const DgtTileBadge(
      text: 'Velocidad',
      color: DgtStatusColors.error,
    ),
  ),

  // Historial de simulacros (subtitle dinamico segun count).
  DgtTileSpec(
    title: 'Historial de simulacros',
    subtitleBuilder: (ref) {
      final count = ref.watch(dgtExamHistoryProvider).maybeWhen(
            data: (entries) => entries.length,
            orElse: () => 0,
          );
      if (count == 0) return 'Aun sin simulacros completados';
      return '$count simulacro${count == 1 ? '' : 's'} guardado${count == 1 ? '' : 's'}';
    },
    icon: Icons.history_rounded,
    accentColor: const Color(0xFFFF6B35),
    routeBuilder: (_) => const DgtHistoryScreen(),
  ),

  // Trampas frecuentes (anti-trampa, palabras clave siempre/nunca/excepto).
  DgtTileSpec(
    title: 'Trampas frecuentes',
    subtitleBuilder: (_) =>
        'Practica las palabras siempre / nunca / excepto / solo',
    icon: Icons.warning_amber_rounded,
    accentColor: DgtStatusColors.warning,
    routeBuilder: (_) => const DgtTrickQuestionsScreen(),
    badgeBuilder: (_) => const DgtTileBadge(
      text: 'Anti-trampa',
      color: DgtStatusColors.warning,
    ),
  ),

  // Issue #127 (dgt-ux): autotest mental (active recall puro sin opciones).
  DgtTileSpec(
    title: 'Autotest mental',
    subtitleBuilder: (_) =>
        'Pregunta sin opciones. Piensa, revela, self-report.',
    icon: Icons.psychology_alt_rounded,
    accentColor: const Color(0xFFB9A6FF),
    routeBuilder: (_) => const DgtAutotestScreen(),
    badgeBuilder: (_) => const DgtTileBadge(
      text: 'Active recall',
      color: Color(0xFFB9A6FF),
    ),
  ),

  // Issue #201 (dgt-ux): "V/F rapido" - afirmaciones binarias DGT para
  // entrenar el reflejo logico siempre/nunca/permitido/prohibido. 10
  // afirmaciones por ronda derivadas del banco DGT (cache local), sin
  // timer.
  DgtTileSpec(
    title: 'V/F rapido',
    subtitleBuilder: (_) =>
        '10 afirmaciones binarias. Entrena el reflejo si/no.',
    icon: Icons.rule_rounded,
    accentColor: DgtStatusColors.success,
    routeBuilder: (_) => const DgtTrueFalseScreen(),
    badgeBuilder: (_) => const DgtTileBadge(
      text: 'V/F',
      color: DgtStatusColors.success,
    ),
  ),

  // Separador semantico: estudio teorico (no quiz). Spacing extra 14.
  DgtTileSpec(
    title: 'Estudiar por Secciones',
    subtitleBuilder: (_) => 'Clases teoricas DGT por bloque tematico (lectura)',
    icon: Icons.menu_book_rounded,
    accentColor: const Color(0xFF7C5CFF),
    primaryIconColor: const Color(0xFFB9A6FF),
    variant: DgtTileVariant.primary,
    routeBuilder: (_) => const DgtStudySectionsScreen(),
    spacingBefore: 14,
  ),

  // Issue #155 (dgt-ux): comparativa cohorte vs media global. Consume
  // BE#107 GET /dgt/stats/benchmark. Visible siempre; el propio screen
  // maneja el empty state cuando no hay tracking suficiente.
  DgtTileSpec(
    title: 'Comparativa cohorte',
    subtitleBuilder: (_) =>
        'Tu acierto vs media global por tema (BE#107)',
    icon: Icons.people_alt_rounded,
    accentColor: DgtStatusColors.info,
    routeBuilder: (_) => const DgtCohortCompareScreen(),
    badgeBuilder: (_) => const DgtTileBadge(
      text: 'Cohorte',
      color: DgtStatusColors.info,
    ),
  ),

  // Issue #187 (dgt-ux): "Mi calendario examen" con countdown D-N y ramp-up
  // por fases. Visible siempre; el propio screen maneja el empty state cuando
  // no hay examDate configurada.
  DgtTileSpec(
    title: 'Mi calendario examen',
    subtitleBuilder: (_) =>
        'Countdown D-N + plan de ramp-up por fases',
    icon: Icons.event_rounded,
    accentColor: DgtStatusColors.warning,
    routeBuilder: (_) => const DgtExamCalendarScreen(),
    badgeBuilder: (_) => const DgtTileBadge(
      text: 'Plan',
      color: DgtStatusColors.warning,
    ),
  ),

  // Issue #209 (dgt-ux): pantalla "Mis logros" con grid de insignias
  // desbloqueadas / pendientes por categoria (constancia, maestria, examen,
  // estudio). Deriva todo de providers existentes (sin BE nuevo).
  DgtTileSpec(
    title: 'Mis logros',
    subtitleBuilder: (_) =>
        'Insignias desbloqueadas y progreso por categoria',
    icon: Icons.emoji_events_rounded,
    accentColor: DgtStatusColors.warning,
    routeBuilder: (_) => const DgtAchievementsScreen(),
    badgeBuilder: (_) => const DgtTileBadge(
      text: 'Logros',
      color: DgtStatusColors.warning,
    ),
  ),

  // Issue #183 (dgt-ux): evolucion semanal con chart visual (8 semanas).
  DgtTileSpec(
    title: 'Tu evolucion semanal',
    subtitleBuilder: (_) =>
        'Chart de tendencia: % acierto, simulacros y streak en 8 semanas',
    icon: Icons.show_chart_rounded,
    accentColor: DgtStatusColors.info,
    routeBuilder: (_) => const DgtWeeklyEvolutionScreen(),
    badgeBuilder: (_) => const DgtTileBadge(
      text: 'Tendencia',
      color: DgtStatusColors.info,
    ),
  ),

  // Catalogo de senales (repaso visual por categoria).
  DgtTileSpec(
    title: 'Catalogo de senales',
    subtitleBuilder: (_) =>
        'Repasa senales por categoria (peligro, prohibicion...)',
    icon: Icons.traffic_rounded,
    accentColor: DgtStatusColors.success,
    routeBuilder: (_) => const DgtSignalsCatalogScreen(),
  ),

  // Issue #169 (dgt-ux): pantalla dedicada de Ajustes DGT (recordatorios,
  // modo simulacro estricto, reset progreso, export stats). Spacing extra
  // para separar visualmente del bloque de estudio.
  DgtTileSpec(
    title: 'Ajustes DGT',
    subtitleBuilder: (_) =>
        'Recordatorios, modo estricto, reset progreso, exportar stats',
    icon: Icons.tune_rounded,
    accentColor: const Color(0xFF9FA6BC),
    routeBuilder: (_) => const DgtSettingsScreen(),
    spacingBefore: 14,
  ),
];
