import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';

import 'dgt_weekly_summary_provider.dart';

/// Issue #174 (dgt-ux): pantalla que muestra el resumen semanal de
/// progreso DGT. Abierta desde el tap a la notificacion local del
/// domingo 20:00 (payload `kDgtWeeklyReportDeeplink`) o desde un boton
/// "ver resumen" en otras secciones (futuro).
///
/// Datos consumidos via [dgtWeeklySummaryProvider] (todo local, sin
/// endpoints nuevos). Si la semana no tuvo actividad, se muestra el
/// copy motivacional del criterio: "no estudiaste nada esta semana,
/// faltan X dias".
class DgtWeeklyReportScreen extends ConsumerWidget {
  const DgtWeeklyReportScreen({super.key});

  /// Nombre ruta usado por main.dart al recibir el deeplink.
  static const String routeName = '/dgt/weekly-report';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dgtWeeklySummaryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen semanal DGT'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: 'No se pudo cargar el resumen: $e',
          onRetry: () => ref.invalidate(dgtWeeklySummaryProvider),
        ),
        data: (s) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dgtWeeklySummaryProvider);
            await ref.read(dgtWeeklySummaryProvider.future);
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              24 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
              if (s.isEmpty)
                _EmptyWeekCard(daysToExam: s.daysToExam)
              else ...[
                _MetricsGrid(summary: s),
                const SizedBox(height: 16),
                if (s.weakestTopicName != null)
                  _WeakestTopicCard(name: s.weakestTopicName!),
                if (s.daysToExam != null) ...[
                  const SizedBox(height: 12),
                  _DaysToExamCard(days: s.daysToExam!),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final DgtWeeklySummary summary;
  const _MetricsGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final accuracy = summary.accuracyPct;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Dias estudiados',
                value: '${summary.daysStudied}/7',
                icon: Icons.calendar_today_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                label: 'Preguntas',
                value: '${summary.questionsAnswered}',
                icon: Icons.quiz_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MetricTile(
          label: 'Accuracy estimada',
          value: accuracy != null
              ? '${accuracy.toStringAsFixed(1)}%'
              : 'Sin datos',
          icon: Icons.show_chart_rounded,
          full: true,
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool full;
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    this.full = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.c.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.c.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.c.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: full ? 18 : 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeakestTopicCard extends StatelessWidget {
  final String name;
  const _WeakestTopicCard({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.c.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tema mas debil',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.c.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DaysToExamCard extends StatelessWidget {
  final int days;
  const _DaysToExamCard({required this.days});

  @override
  Widget build(BuildContext context) {
    String label;
    if (days < 0) {
      label = 'Tu examen ya paso (${-days} dias)';
    } else if (days == 0) {
      label = 'Tu examen es HOY';
    } else {
      label = 'Faltan $days dias para tu examen';
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.c.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_rounded, color: Colors.greenAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyWeekCard extends StatelessWidget {
  final int? daysToExam;
  const _EmptyWeekCard({required this.daysToExam});

  @override
  Widget build(BuildContext context) {
    final tail = daysToExam == null
        ? 'Configura tu fecha de examen para verlo aqui.'
        : daysToExam! < 0
            ? 'Tu examen ya paso (${-daysToExam!} dias). Sigue practicando.'
            : daysToExam == 0
                ? 'Tu examen es HOY - todavia puedes hacer un repaso rapido.'
                : 'Faltan $daysToExam dias para tu examen.';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.c.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No estudiaste nada esta semana',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            tail,
            style: TextStyle(
              fontSize: 14,
              color: context.c.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
