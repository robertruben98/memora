import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';

import 'dgt_exam_screen.dart';
import 'dgt_ready_check_provider.dart';
import 'dgt_topic_stats_screen.dart';
import 'dgt_weak_focus_screen.dart';

/// Issue #136 (dgt-ux): pantalla "Listo para examen?".
///
/// Muestra un checklist de 5 criterios objetivos y un veredicto global para
/// que el estudiante decida si presentarse al DGT real. Aditivo: consume
/// [dgtReadyCheckProvider] y no muta estado.
class DgtReadyCheckScreen extends ConsumerWidget {
  const DgtReadyCheckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dgtReadyCheckProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listo para el examen?'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No pudimos cargar la evaluacion: $e'),
          ),
        ),
        data: (result) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dgtReadyCheckProvider);
            await ref.read(dgtReadyCheckProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              DgtReadyVerdictCard(result: result),
              const SizedBox(height: 20),
              for (final c in result.criteria) ...[
                DgtReadyCriterionTile(
                  criterion: c,
                  onTap: () => _openTargetFor(context, c.id),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Linkea cada criterio fallado a la pantalla relevante. Si no hay un
  /// destino claro para un criterio, no abre nada (no rompe).
  void _openTargetFor(BuildContext context, DgtReadyCriterionId id) {
    final nav = Navigator.of(context);
    switch (id) {
      case DgtReadyCriterionId.recentMocks:
        nav.push(MaterialPageRoute(builder: (_) => const DgtExamScreen()));
        break;
      case DgtReadyCriterionId.globalAccuracy:
      case DgtReadyCriterionId.topicCoverage:
        nav.push(
          MaterialPageRoute(builder: (_) => const DgtTopicStatsScreen()),
        );
        break;
      case DgtReadyCriterionId.weakTopics:
        nav.push(
          MaterialPageRoute(builder: (_) => const DgtWeakFocusScreen()),
        );
        break;
      case DgtReadyCriterionId.activeStreak:
        // No hay pantalla 1:1 para streak: nos quedamos donde estamos.
        break;
    }
  }
}

/// Card superior con veredicto agregado. Expone color/accent segun tier.
class DgtReadyVerdictCard extends StatelessWidget {
  final DgtReadyCheckResult result;

  const DgtReadyVerdictCard({super.key, required this.result});

  static Color colorFor(DgtReadyVerdict v) {
    switch (v) {
      case DgtReadyVerdict.ready:
        return const Color(0xFF4FFFB0);
      case DgtReadyVerdict.almost:
        return const Color(0xFFFFB74F);
      case DgtReadyVerdict.notReady:
        return const Color(0xFFFF5C5C);
    }
  }

  static IconData iconFor(DgtReadyVerdict v) {
    switch (v) {
      case DgtReadyVerdict.ready:
        return Icons.check_circle_rounded;
      case DgtReadyVerdict.almost:
        return Icons.timelapse_rounded;
      case DgtReadyVerdict.notReady:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = colorFor(result.verdict);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(iconFor(result.verdict), color: accent, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.shortLabel,
                  style: TextStyle(
                    color: accent,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                if (result.daysUntilExam != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    result.daysUntilExam! < 0
                        ? 'Tu fecha de examen ya paso'
                        : 'Faltan ${result.daysUntilExam} dias para el examen',
                    style: TextStyle(
                      color: context.c.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tile individual por criterio. Expone iconFor / colorFor para tests.
class DgtReadyCriterionTile extends StatelessWidget {
  final DgtReadyCriterion criterion;
  final VoidCallback? onTap;

  const DgtReadyCriterionTile({
    super.key,
    required this.criterion,
    this.onTap,
  });

  static Color colorFor(DgtReadyCriterionStatus s) {
    switch (s) {
      case DgtReadyCriterionStatus.pass:
        return const Color(0xFF4FFFB0);
      case DgtReadyCriterionStatus.warn:
        return const Color(0xFFFFB74F);
      case DgtReadyCriterionStatus.fail:
        return const Color(0xFFFF5C5C);
    }
  }

  static IconData iconFor(DgtReadyCriterionStatus s) {
    switch (s) {
      case DgtReadyCriterionStatus.pass:
        return Icons.check_circle_rounded;
      case DgtReadyCriterionStatus.warn:
        return Icons.error_outline_rounded;
      case DgtReadyCriterionStatus.fail:
        return Icons.cancel_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(criterion.status);
    return Material(
      color: context.c.surfaceElevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        // Solo permite tap si NO esta en pass (queremos llevar al fix).
        onTap: criterion.status == DgtReadyCriterionStatus.pass ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(iconFor(criterion.status), color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      criterion.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      criterion.detail,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (criterion.status != DgtReadyCriterionStatus.pass)
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.c.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
