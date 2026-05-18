import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/dgt_repository.dart';
import 'dgt_practice_screen.dart';
import 'dgt_prediction.dart';

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
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: 'No se pudieron cargar las estadisticas: $e',
          onRetry: () => ref.invalidate(dgtTopicStatsProvider),
        ),
        data: (stats) {
          final answered = stats.where((s) => s.totalAnswered > 0).toList();
          if (answered.isEmpty) {
            return _EmptyView(
              onRetry: () => ref.invalidate(dgtTopicStatsProvider),
            );
          }
          // Peor accuracy primero (foco en debilidades).
          final sorted = [...answered]
            ..sort((a, b) => a.accuracyPct.compareTo(b.accuracyPct));
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
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final s = sorted[i];
                return TopicStatTile(
                  stat: s,
                  onTap: () => _openPractice(context, s),
                );
              },
            ),
          );
        },
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
}

/// Tile visual por tema. Expuesto (no privado) para tests de widget.
class TopicStatTile extends StatelessWidget {
  final DgtTopicStat stat;
  final VoidCallback onTap;

  const TopicStatTile({
    super.key,
    required this.stat,
    required this.onTap,
  });

  /// Umbrales de color para la barra de accuracy.
  /// Rojo <60, ambar 60-80, verde >=80.
  static Color colorFor(double accuracyPct) {
    if (accuracyPct >= 80) return const Color(0xFF4FFFB0);
    if (accuracyPct >= 60) return const Color(0xFFFFB74F);
    return const Color(0xFFFF5C5C);
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(stat.accuracyPct);
    final pct = stat.accuracyPct.clamp(0.0, 100.0);
    final name = (stat.topicName == null || stat.topicName!.isEmpty)
        ? stat.topicId
        : stat.topicName!;
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
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
                '${stat.correct}/${stat.totalAnswered} aciertos',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct / 100.0,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ),
      ),
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
                color: Colors.white.withValues(alpha: 0.7),
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
