import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/widgets/app_state_view.dart';

import '../../data/repositories/dgt_repository.dart';
import 'data/dgt_subtopic_repository.dart';
import 'dgt_practice_screen.dart';

/// Issue #138 (dgt-ux): heatmap de fallos por subtema dentro de un tema
/// DGT. Drill-down desde [DgtTopicStatsScreen]. La UX se centra en el
/// rojo: el estudiante quiere saber donde fallar mas duele y practicar
/// solo esos clusters.
///
/// Aditivo: nueva pantalla, no toca pantallas existentes mas alla de
/// anadir el tap en topic stats (que se hace en otro archivo).
class DgtTopicHeatmapScreen extends ConsumerWidget {
  final String topicId;
  final String topicName;

  const DgtTopicHeatmapScreen({
    super.key,
    required this.topicId,
    required this.topicName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subtopicBreakdownProvider(topicId));
    return Scaffold(
      appBar: AppBar(
        title: Text(topicName),
      ),
      body: async.when(
        loading: () => AppStateView.loading(),
        error: (e, _) => _ErrorView(
          message: 'No se pudo cargar el desglose: $e',
          onRetry: () => ref.invalidate(subtopicBreakdownProvider(topicId)),
        ),
        data: (stats) {
          if (stats.isEmpty) {
            return const _EmptyView();
          }
          // Orden estable: rojo primero (peor accuracy primero), luego ambar,
          // luego verde. Dentro de cada bucket ordena por fallPct desc.
          final sorted = [...stats]
            ..sort((a, b) => b.failPct.compareTo(a.failPct));
          final reds = sorted
              .where((s) => bucketFor(s.failPct) == DgtHeatmapBucket.red)
              .toList();
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Toca un cluster para ver donde se concentran tus fallos.',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.c.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: sorted.length,
                    itemBuilder: (_, i) {
                      final s = sorted[i];
                      return SubtopicCell(stat: s);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: reds.isEmpty
                        ? null
                        : () => _practiceReds(context, reds),
                    icon: const Icon(Icons.local_fire_department_rounded),
                    label: Text(
                      reds.isEmpty
                          ? 'Sin clusters rojos: vas bien'
                          : 'Practicar solo los rojos (${reds.length})',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _practiceReds(BuildContext context, List<DgtSubtopicStat> reds) {
    final topic = DgtTopic(id: topicId, name: topicName);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DgtPracticeScreen(
          topic: topic,
          limit: 10,
          subtopicIds: reds.map((s) => s.subtopicId).toList(),
        ),
      ),
    );
  }
}

/// Celda visual del heatmap. Expuesta (no privada) para tests de widget.
class SubtopicCell extends StatelessWidget {
  final DgtSubtopicStat stat;

  const SubtopicCell({super.key, required this.stat});

  /// Colores del heatmap. Pastel apagado para no quemar al usuario.
  /// Verde <20 fallos, ambar 20-50, rojo >=50.
  static Color colorFor(DgtHeatmapBucket bucket) {
    switch (bucket) {
      case DgtHeatmapBucket.green:
        return const Color(0xFF2F8F5C);
      case DgtHeatmapBucket.amber:
        return const Color(0xFFB07A1F);
      case DgtHeatmapBucket.red:
        return const Color(0xFFB23A3A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bucket = bucketFor(stat.failPct);
    final bg = colorFor(bucket);
    return Material(
      color: bg.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                stat.subtopicName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${stat.failPct.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              Text(
                '${stat.totalAnswered} vistas',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.85),
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
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Aun no hay datos de subtemas. Practica unas cuantas '
          'preguntas y vuelve.',
          textAlign: TextAlign.center,
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
