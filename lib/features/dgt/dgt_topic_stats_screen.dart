import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/widgets/app_state_view.dart';

import '../../data/repositories/dgt_repository.dart';
import 'dgt_practice_screen.dart';
import 'dgt_prediction.dart';
import 'dgt_reminder_service.dart';
import 'dgt_time_of_day_insight_provider.dart';
import 'dgt_topic_heatmap_screen.dart';
import 'widgets/best_hour_card.dart';

/// Issue #67 (dgt-ux): pantalla "Estadisticas por tema".
///
/// Lista cada bloque tematico DGT con accuracy% (aciertos/respondidas).
/// Ordena por debilidad (peor accuracy primero) para que el estudiante
/// vea donde invertir tiempo. Tap en un tema -> abre [DgtPracticeScreen]
/// con un limit razonable (10).
///
/// Consume [dgtTopicStatsProvider] (reusa [DgtPredictionRepository], NO
/// crea repo nuevo). Es aditivo: no toca prediccion existente.
class DgtTopicStatsScreen extends ConsumerWidget {
  /// Limit por defecto al navegar a practica del tema seleccionado.
  static const int _defaultPracticeLimit = 10;

  const DgtTopicStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dgtTopicStatsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadisticas por tema'),
        actions: [
          IconButton(
            tooltip: 'Que significa accuracy vs cobertura',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => _showLegend(context),
          ),
        ],
      ),
      body: async.when(
        loading: () => AppStateView.loading(),
        error: (e, _) => _ErrorView(
          message: 'No se pudieron cargar las estadisticas: $e',
          onRetry: () => ref.invalidate(dgtTopicStatsProvider),
        ),
        data: (stats) {
          if (stats.where((s) => s.totalAnswered > 0).isEmpty) {
            return _EmptyView(
              onRetry: () => ref.invalidate(dgtTopicStatsProvider),
            );
          }
          // Issue #117: ya no filtramos temas con totalAnswered=0; los
          // mostramos al final como "intactos" para que el estudiante
          // vea que partes del temario no ha tocado nunca.
          final sorted = [...stats]
            ..sort((a, b) {
              // Primero los que tienen respuestas (peor accuracy primero).
              final aHas = a.totalAnswered > 0;
              final bHas = b.totalAnswered > 0;
              if (aHas != bHas) return aHas ? -1 : 1;
              if (aHas) return a.accuracyPct.compareTo(b.accuracyPct);
              // Entre intactos, orden estable por topicId.
              return a.topicId.compareTo(b.topicId);
            });
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dgtTopicStatsProvider);
              await ref.read(dgtTopicStatsProvider.future);
            },
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                24 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              // Issue #137: inyecta card "Tu mejor hora" como primer item.
              itemCount: sorted.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return BestHourCard(
                    onProgramReminder: (b) =>
                        _programReminder(context, ref, b),
                  );
                }
                final s = sorted[i - 1];
                return TopicStatTile(
                  stat: s,
                  onTap: () => _openHeatmap(context, s),
                  onLongPress: () => _openPractice(context, s),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showLegend(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Accuracy vs Cobertura'),
        content: const Text(
          'Accuracy = % de aciertos sobre las preguntas que has '
          'respondido en este tema.\n\n'
          'Cobertura = % del temario que has tocado (preguntas vistas / '
          'total estimado del banco DGT por tema).\n\n'
          'Un tema con 90% accuracy y 10% cobertura significa que '
          'aciertas, pero solo has visto una pequena parte: aun no '
          'puedes dar por dominado el bloque.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _openPractice(BuildContext context, DgtTopicStat stat) {
    final topic = DgtTopic(
      id: stat.topicId,
      name: stat.topicName ?? stat.topicId,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DgtPracticeScreen(
          topic: topic,
          limit: _defaultPracticeLimit,
        ),
      ),
    );
  }

  /// Issue #137 (dgt-ux): pre-configura recordatorio con la hora ganadora.
  /// Usa la hora inicial del bucket; el usuario puede afinar en settings.
  Future<void> _programReminder(
    BuildContext context,
    WidgetRef ref,
    DgtTimeOfDayBucket bucket,
  ) async {
    final service = ref.read(dgtReminderServiceProvider);
    final current = await ref.read(dgtReminderConfigProvider.future);
    final next = current.copyWith(
      enabled: true,
      hour: bucket.startHour,
      minute: 0,
    );
    try {
      await service.saveConfig(next);
      await service.reschedule(next);
    } catch (_) {
      // Best-effort: si la persistencia falla seguimos mostrando feedback.
    }
    ref.invalidate(dgtReminderConfigProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Recordatorio programado a las ${bucket.startHour
              .toString()
              .padLeft(2, '0')}:00',
        ),
      ),
    );
  }

  /// Issue #138 (dgt-ux): tap normal abre el drill-down heatmap del tema.
  /// El long-press conserva el atajo a practica directa para no perder
  /// el flujo previo (issue #67).
  void _openHeatmap(BuildContext context, DgtTopicStat stat) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DgtTopicHeatmapScreen(
          topicId: stat.topicId,
          topicName: stat.topicName ?? stat.topicId,
        ),
      ),
    );
  }
}

/// Tile visual por tema. Expuesto (no privado) para tests de widget.
class TopicStatTile extends StatelessWidget {
  final DgtTopicStat stat;
  final VoidCallback onTap;

  /// Issue #138 (dgt-ux): long-press conserva el atajo a practica directa
  /// (atajo del flujo previo issue #67). Opcional para no romper call sites.
  final VoidCallback? onLongPress;

  const TopicStatTile({
    super.key,
    required this.stat,
    required this.onTap,
    this.onLongPress,
  });

  /// Umbrales de color para la barra de accuracy.
  /// Rojo <60, ambar 60-80, verde >=80.
  static Color colorFor(double accuracyPct) {
    if (accuracyPct >= 80) return const Color(0xFF4FFFB0);
    if (accuracyPct >= 60) return const Color(0xFFFFB74F);
    return const Color(0xFFFF5C5C);
  }

  /// Umbrales de color para la barra de COBERTURA (issue #117).
  /// Gris <30, ambar 30-70, verde >=70. Semantica: cuanto del temario
  /// has tocado, no que tan bien.
  static Color coverageColorFor(double coveragePct) {
    if (coveragePct >= 70) return const Color(0xFF4FFFB0);
    if (coveragePct >= 30) return const Color(0xFFFFB74F);
    return const Color(0xFF7A7A7A);
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(stat.accuracyPct);
    final pct = stat.accuracyPct.clamp(0.0, 100.0);
    final coveragePct = stat.coveragePct;
    final coverageColor = coverageColorFor(coveragePct);
    final name = (stat.topicName == null || stat.topicName!.isEmpty)
        ? stat.topicId
        : stat.topicName!;
    final isIntact = stat.totalAnswered <= 0;
    return Material(
      color: context.c.surfaceMuted,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isIntact)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7A7A7A).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Sin tocar',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isIntact
                    ? 'Aun no has respondido preguntas de este tema'
                    : '${stat.correct}/${stat.totalAnswered} aciertos',
                style: TextStyle(
                  fontSize: 12,
                  color: context.c.textSecondary,
                ),
              ),
              if (!isIntact) ...[
                const SizedBox(height: 8),
                _BarRow(
                  label: 'Accuracy',
                  pct: pct,
                  color: color,
                  trailing: '${stat.correct}/${stat.totalAnswered}',
                ),
              ],
              const SizedBox(height: 8),
              _BarRow(
                label: 'Cobertura',
                pct: coveragePct,
                color: coverageColor,
                trailing:
                    '${stat.totalAnswered.clamp(0, stat.bankSize)}/'
                    '${stat.bankSize}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila visual barra + etiqueta + porcentaje. Privada: solo se usa dentro
/// de [TopicStatTile] (no expuesta para no inflar la API publica).
class _BarRow extends StatelessWidget {
  final String label;
  final double pct;
  final Color color;
  final String? trailing;

  const _BarRow({
    required this.label,
    required this.pct,
    required this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = pct.clamp(0.0, 100.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: context.c.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              trailing ?? '${clamped.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 11,
                color: context.c.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: clamped / 100.0,
            minHeight: 6,
            backgroundColor: context.c.surfaceMuted,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insights_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Aun no hay respuestas registradas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Practica unas cuantas preguntas y vuelve para ver tu '
              'progreso por tema.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: context.c.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
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
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
