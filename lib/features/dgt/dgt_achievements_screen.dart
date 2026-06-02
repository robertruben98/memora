import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memora/core/theme/app_colors.dart';

import '../study/dgt_exam_history.dart';
import 'dgt_prediction.dart';
import 'dgt_streak_provider.dart';

/// Issue #209 (dgt-ux): pantalla 'Mis logros' con grid de insignias.
///
/// Vista centralizada de hitos del estudiante DGT (rachas, simulacros
/// aprobados, % global, preguntas totales). Aditiva: deriva todo de
/// providers existentes (`dgtStreakMonthProvider`, `dgtExamHistoryProvider`,
/// `dgtPredictionProvider`, `dgtTopicStatsProvider`). NO requiere BE nuevo
/// ni storage adicional.
///
/// El catalogo de insignias agrupa 4 categorias x 3 niveles = 12 insignias
/// (alineado con el catalogo del issue: 8-10 minimo). Cada nivel se
/// desbloquea automaticamente al cruzar el umbral.
///
/// Tile registry: registrado en `kDgtTileRegistry` (`dgt_section.dart`).

/// Categorias de insignias DGT.
enum DgtAchievementCategory {
  /// Insignias de constancia (racha diaria).
  constancia,

  /// Insignias de maestria (% acierto global).
  maestria,

  /// Insignias de examen (simulacros aprobados).
  examen,

  /// Insignias de estudio (volumen total respondido).
  estudio,
}

/// Texto humano para una categoria.
String dgtAchievementCategoryLabel(DgtAchievementCategory cat) {
  switch (cat) {
    case DgtAchievementCategory.constancia:
      return 'Constancia';
    case DgtAchievementCategory.maestria:
      return 'Maestria';
    case DgtAchievementCategory.examen:
      return 'Examen';
    case DgtAchievementCategory.estudio:
      return 'Estudio';
  }
}

/// Definicion estatica de una insignia. PURA (sin dependencias de Flutter mas
/// alla del IconData). Una `DgtAchievementSpec` describe la insignia; el
/// estado real (unlocked / progreso) se calcula a partir de stats.
class DgtAchievementSpec {
  final String id;
  final String title;
  final String description;
  final String tip;
  final IconData icon;
  final DgtAchievementCategory category;

  /// Umbral entero a superar (>=) para desbloquear. Su unidad depende de
  /// la categoria: dias (constancia), % (maestria), conteo (examen / estudio).
  final int threshold;

  const DgtAchievementSpec({
    required this.id,
    required this.title,
    required this.description,
    required this.tip,
    required this.icon,
    required this.category,
    required this.threshold,
  });
}

/// Catalogo estatico ordenado por categoria y umbral ascendente.
const List<DgtAchievementSpec> kDgtAchievementsCatalog = <DgtAchievementSpec>[
  // Constancia: streak 7 / 14 / 30 dias.
  DgtAchievementSpec(
    id: 'constancia.7',
    title: 'Primera semana',
    description: '7 dias seguidos cumpliendo tu meta diaria',
    tip: 'Estudia hoy y manten la racha 7 dias seguidos.',
    icon: Icons.local_fire_department_rounded,
    category: DgtAchievementCategory.constancia,
    threshold: 7,
  ),
  DgtAchievementSpec(
    id: 'constancia.14',
    title: 'Dos semanas',
    description: '14 dias seguidos cumpliendo tu meta diaria',
    tip: 'Sigue tu racha. Te quedan pocos dias para los 14.',
    icon: Icons.local_fire_department_rounded,
    category: DgtAchievementCategory.constancia,
    threshold: 14,
  ),
  DgtAchievementSpec(
    id: 'constancia.30',
    title: 'Mes de fuego',
    description: '30 dias seguidos cumpliendo tu meta diaria',
    tip: 'Un mes seguido sin saltarte ningun dia.',
    icon: Icons.local_fire_department_rounded,
    category: DgtAchievementCategory.constancia,
    threshold: 30,
  ),
  // Maestria: % acierto global (basado en prediccion).
  DgtAchievementSpec(
    id: 'maestria.70',
    title: 'Nivel competente',
    description: '70% de acierto global estimado',
    tip: 'Practica los temas con menor % para subir tu nivel global.',
    icon: Icons.workspace_premium_rounded,
    category: DgtAchievementCategory.maestria,
    threshold: 70,
  ),
  DgtAchievementSpec(
    id: 'maestria.85',
    title: 'Nivel avanzado',
    description: '85% de acierto global estimado',
    tip: 'Cerca del aprobado oficial. Refuerza tus puntos debiles.',
    icon: Icons.workspace_premium_rounded,
    category: DgtAchievementCategory.maestria,
    threshold: 85,
  ),
  DgtAchievementSpec(
    id: 'maestria.95',
    title: 'Nivel experto',
    description: '95% de acierto global estimado',
    tip: 'Pulir trampas y casos limite te llevara al 95%.',
    icon: Icons.workspace_premium_rounded,
    category: DgtAchievementCategory.maestria,
    threshold: 95,
  ),
  // Examen: simulacros aprobados (>=27/30).
  DgtAchievementSpec(
    id: 'examen.1',
    title: 'Primer aprobado',
    description: 'Aprueba 1 simulacro con criterio DGT (>=27)',
    tip: 'Haz un simulacro completo y supera el corte.',
    icon: Icons.emoji_events_rounded,
    category: DgtAchievementCategory.examen,
    threshold: 1,
  ),
  DgtAchievementSpec(
    id: 'examen.5',
    title: 'Cinco aprobados',
    description: 'Aprueba 5 simulacros con criterio DGT',
    tip: 'Mantener consistencia es clave: encadena varios aprobados.',
    icon: Icons.emoji_events_rounded,
    category: DgtAchievementCategory.examen,
    threshold: 5,
  ),
  DgtAchievementSpec(
    id: 'examen.10',
    title: 'Veterano',
    description: 'Aprueba 10 simulacros con criterio DGT',
    tip: 'Acumula 10 aprobados. Estaras listo para el examen oficial.',
    icon: Icons.emoji_events_rounded,
    category: DgtAchievementCategory.examen,
    threshold: 10,
  ),
  // Estudio: preguntas totales respondidas.
  DgtAchievementSpec(
    id: 'estudio.100',
    title: 'Centenario',
    description: 'Responde 100 preguntas en total',
    tip: 'Una sesion diaria y llegas en una semana.',
    icon: Icons.menu_book_rounded,
    category: DgtAchievementCategory.estudio,
    threshold: 100,
  ),
  DgtAchievementSpec(
    id: 'estudio.500',
    title: 'Quinientas',
    description: 'Responde 500 preguntas en total',
    tip: 'Sigue con la rutina diaria, vas por buen camino.',
    icon: Icons.menu_book_rounded,
    category: DgtAchievementCategory.estudio,
    threshold: 500,
  ),
  DgtAchievementSpec(
    id: 'estudio.1000',
    title: 'Mil preguntas',
    description: 'Responde 1000 preguntas en total',
    tip: 'Volumen completo: cubres practicamente todo el banco DGT.',
    icon: Icons.menu_book_rounded,
    category: DgtAchievementCategory.estudio,
    threshold: 1000,
  ),
];

/// Snapshot inmutable de inputs para calcular logros. Permite override en
/// tests sin tener que stubear cada provider individual.
class DgtAchievementsInput {
  /// Racha actual (dias consecutivos cumpliendo meta diaria).
  final int currentStreak;

  /// % acierto global estimado [0..100]. `null` si no hay datos suficientes.
  final double? globalAccuracyPct;

  /// Simulacros aprobados (criterio DGT >=27/30).
  final int passedExams;

  /// Total preguntas respondidas (acumulado historico).
  final int totalAnswered;

  const DgtAchievementsInput({
    required this.currentStreak,
    required this.globalAccuracyPct,
    required this.passedExams,
    required this.totalAnswered,
  });

  static const empty = DgtAchievementsInput(
    currentStreak: 0,
    globalAccuracyPct: null,
    passedExams: 0,
    totalAnswered: 0,
  );
}

/// Estado computado de una insignia: progress + unlocked.
class DgtAchievementStatus {
  final DgtAchievementSpec spec;

  /// Progreso normalizado [0..1]. 1.0 = desbloqueada.
  final double progress;

  /// Valor crudo actual (para mostrar "7/10", "65%", etc.).
  final int currentValue;

  /// `true` si currentValue >= spec.threshold.
  bool get unlocked => currentValue >= spec.threshold;

  const DgtAchievementStatus({
    required this.spec,
    required this.progress,
    required this.currentValue,
  });

  /// Label "actual/objetivo" segun la categoria.
  String get progressLabel {
    switch (spec.category) {
      case DgtAchievementCategory.constancia:
        return '$currentValue / ${spec.threshold} dias';
      case DgtAchievementCategory.maestria:
        return '$currentValue% / ${spec.threshold}%';
      case DgtAchievementCategory.examen:
        return '$currentValue / ${spec.threshold} aprobados';
      case DgtAchievementCategory.estudio:
        return '$currentValue / ${spec.threshold} preguntas';
    }
  }
}

/// Calculo PURO de estado de una insignia dado el input. Sin Flutter.
DgtAchievementStatus computeAchievementStatus(
  DgtAchievementSpec spec,
  DgtAchievementsInput input,
) {
  final int current;
  switch (spec.category) {
    case DgtAchievementCategory.constancia:
      current = input.currentStreak;
      break;
    case DgtAchievementCategory.maestria:
      final pct = input.globalAccuracyPct;
      current = pct == null ? 0 : pct.round().clamp(0, 100);
      break;
    case DgtAchievementCategory.examen:
      current = input.passedExams;
      break;
    case DgtAchievementCategory.estudio:
      current = input.totalAnswered;
      break;
  }
  final progress = spec.threshold <= 0
      ? 1.0
      : (current / spec.threshold).clamp(0.0, 1.0);
  return DgtAchievementStatus(
    spec: spec,
    progress: progress.toDouble(),
    currentValue: current,
  );
}

/// Provider del input agregado. Combina varios providers existentes y degrada
/// a [DgtAchievementsInput.empty] ante cualquier fallo (la pantalla nunca
/// rompe).
final dgtAchievementsInputProvider =
    FutureProvider<DgtAchievementsInput>((ref) async {
  try {
    // Estos providers ya existen y son resilientes; await con try aislado para
    // no descartar todo el input si una sola fuente falla.
    int streak = 0;
    try {
      final s = await ref.watch(dgtStreakMonthProvider.future);
      streak = s.currentStreak;
    } catch (_) {}

    double? globalPct;
    int totalAnswered = 0;
    try {
      final pred = await ref.watch(dgtPredictionProvider.future);
      if (pred.expectedScore != null) {
        globalPct = (pred.expectedScore! * 100.0).clamp(0.0, 100.0);
      }
      totalAnswered = pred.totalReviews;
    } catch (_) {}

    // Si `dgtPredictionProvider` no trae stats utiles (totalReviews=0),
    // intentamos sumar desde `dgtTopicStatsProvider` (mismo endpoint pero
    // crudo). Esto cubre el caso en que prediction degrada a empty pero
    // stats por tema si esten disponibles via override en tests.
    if (totalAnswered == 0) {
      try {
        final topics = await ref.watch(dgtTopicStatsProvider.future);
        for (final t in topics) {
          totalAnswered += t.totalAnswered;
        }
      } catch (_) {}
    }

    int passed = 0;
    try {
      final entries = await ref.watch(dgtExamHistoryProvider.future);
      for (final e in entries) {
        if (e.passed) passed += 1;
      }
    } catch (_) {}

    return DgtAchievementsInput(
      currentStreak: streak,
      globalAccuracyPct: globalPct,
      passedExams: passed,
      totalAnswered: totalAnswered,
    );
  } catch (_) {
    return DgtAchievementsInput.empty;
  }
});

/// Pantalla principal "Mis logros".
class DgtAchievementsScreen extends ConsumerWidget {
  const DgtAchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inputAsync = ref.watch(dgtAchievementsInputProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis logros')),
      body: inputAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _AchievementsBody(input: DgtAchievementsInput.empty),
        data: (input) => _AchievementsBody(input: input),
      ),
    );
  }
}

class _AchievementsBody extends StatelessWidget {
  final DgtAchievementsInput input;
  const _AchievementsBody({required this.input});

  @override
  Widget build(BuildContext context) {
    final statuses = kDgtAchievementsCatalog
        .map((s) => computeAchievementStatus(s, input))
        .toList(growable: false);
    final unlocked = statuses.where((s) => s.unlocked).length;

    // Agrupar por categoria preservando el orden del enum.
    final byCategory = <DgtAchievementCategory, List<DgtAchievementStatus>>{};
    for (final st in statuses) {
      byCategory.putIfAbsent(st.spec.category, () => []).add(st);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        _Header(unlocked: unlocked, total: statuses.length),
        const SizedBox(height: 16),
        for (final cat in DgtAchievementCategory.values)
          if (byCategory[cat] != null)
            _CategorySection(
              category: cat,
              items: byCategory[cat]!,
            ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final int unlocked;
  final int total;
  const _Header({required this.unlocked, required this.total});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Tus logros: $unlocked de $total desbloqueados',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.c.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events_rounded, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tu progreso',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$unlocked / $total insignias desbloqueadas',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final DgtAchievementCategory category;
  final List<DgtAchievementStatus> items;
  const _CategorySection({required this.category, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              dgtAchievementCategoryLabel(category),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: 0.2,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) => _BadgeTile(status: items[i]),
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final DgtAchievementStatus status;
  const _BadgeTile({required this.status});

  @override
  Widget build(BuildContext context) {
    final unlocked = status.unlocked;
    final color = unlocked
        ? const Color(0xFFFFB74F)
        : context.c.textMuted;
    final bg = unlocked
        ? const Color(0xFFFFB74F).withValues(alpha: 0.12)
        : context.c.surfaceMuted;

    return Tooltip(
      message: unlocked
          ? '${status.spec.title}: desbloqueada'
          : '${status.spec.title}: ${status.progressLabel}',
      child: Semantics(
        button: true,
        label: unlocked
            ? 'Insignia ${status.spec.title} desbloqueada'
            : 'Insignia ${status.spec.title} bloqueada, '
                'progreso ${status.progressLabel}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showDetail(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color, width: 1.2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(status.spec.icon, color: color, size: 28),
                  const SizedBox(height: 6),
                  Text(
                    status.spec.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: unlocked ? null : context.c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    unlocked ? 'Desbloqueada' : status.progressLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: unlocked ? color : context.c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  status.spec.icon,
                  size: 36,
                  color: status.unlocked
                      ? const Color(0xFFFFB74F)
                      : context.c.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    status.spec.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(status.spec.description),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: status.progress,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              status.unlocked ? 'Desbloqueada' : status.progressLabel,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (!status.unlocked)
              Row(
                children: [
                  const Icon(Icons.lightbulb_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(status.spec.tip)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
