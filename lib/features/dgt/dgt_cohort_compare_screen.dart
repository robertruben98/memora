import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';
import 'package:memora/core/widgets/app_state_view.dart';
import 'package:memora/core/widgets/dgt_progress_bar_row.dart';

import '../../data/api/api_client.dart';

/// Issue #155 (dgt-ux): pantalla "Comparativa cohorte" consumiendo BE#107
/// (GET /dgt/stats/benchmark).
///
/// Muestra por cada tema DGT dos barras paralelas (usuario vs media global)
/// + delta en puntos porcentuales. Topbar con resumen "X por encima / Y por
/// debajo" y toggle de orden (donde estoy mas fuerte vs donde estoy mas
/// debil). Estado empty cuando la cohorte global esta vacia o el usuario
/// no tiene tracking.
///
/// Aditivo: NO toca `dgt_prediction.dart` ni el endpoint /dgt/stats/topics.
/// El tile se registra en `kDgtTileRegistry` (registry pattern, issue #148).

/// Item de la respuesta del endpoint /dgt/stats/benchmark.
///
/// Campos `userPct`, `delta`, `status` son nullable: BE#107 devuelve None
/// cuando el usuario no tiene respuestas en el tema (solo cohorte global).
class DgtBenchmarkItem {
  final String topicId;
  final String? topicName;
  final double? userPct;
  final double globalPct;
  final double? delta;

  /// `above` (delta > +5pp), `below` (delta < -5pp), `avg` resto. None si
  /// el usuario no tiene historial en el tema.
  final String? status;

  const DgtBenchmarkItem({
    required this.topicId,
    required this.globalPct,
    this.topicName,
    this.userPct,
    this.delta,
    this.status,
  });

  factory DgtBenchmarkItem.fromJson(Map<String, dynamic> j) {
    return DgtBenchmarkItem(
      topicId: (j['topic_id'] ?? '').toString(),
      topicName: j['topic_name'] as String?,
      userPct: (j['user_pct'] as num?)?.toDouble(),
      globalPct: (j['global_pct'] as num?)?.toDouble() ?? 0.0,
      delta: (j['delta'] as num?)?.toDouble(),
      status: j['status'] as String?,
    );
  }
}

/// Payload top-level del endpoint /dgt/stats/benchmark.
class DgtBenchmark {
  final double? userAvgAccuracyPct;
  final double globalAvgAccuracyPct;
  final int? percentile;
  final int sampleSize;
  final List<DgtBenchmarkItem> topics;

  const DgtBenchmark({
    required this.globalAvgAccuracyPct,
    required this.sampleSize,
    required this.topics,
    this.userAvgAccuracyPct,
    this.percentile,
  });

  static const empty = DgtBenchmark(
    globalAvgAccuracyPct: 0.0,
    sampleSize: 0,
    topics: <DgtBenchmarkItem>[],
  );

  factory DgtBenchmark.fromJson(Map<String, dynamic> j) {
    final rawTopics = j['topics'];
    final topics = <DgtBenchmarkItem>[];
    if (rawTopics is List) {
      for (final t in rawTopics) {
        if (t is Map) {
          topics.add(DgtBenchmarkItem.fromJson(Map<String, dynamic>.from(t)));
        }
      }
    }
    return DgtBenchmark(
      userAvgAccuracyPct: (j['user_avg_accuracy_pct'] as num?)?.toDouble(),
      globalAvgAccuracyPct:
          (j['global_avg_accuracy_pct'] as num?)?.toDouble() ?? 0.0,
      percentile: (j['percentile'] as num?)?.toInt(),
      sampleSize: (j['sample_size'] as num?)?.toInt() ?? 0,
      topics: topics,
    );
  }

  /// Cuantos temas el usuario tiene por ENCIMA de la media (delta > 0).
  int get aboveCount => topics
      .where((t) => t.delta != null && t.delta! > 0)
      .length;

  /// Cuantos temas el usuario tiene por DEBAJO de la media (delta < 0).
  int get belowCount => topics
      .where((t) => t.delta != null && t.delta! < 0)
      .length;

  /// True si la cohorte esta vacia (no hay otros usuarios con tracking
  /// suficiente para comparar) o el usuario no tiene historial DGT.
  bool get isEmpty => topics.isEmpty || sampleSize == 0;
}

/// Repositorio thin para GET /dgt/stats/benchmark (issue #107).
class DgtBenchmarkRepository {
  final ApiClient _api;
  DgtBenchmarkRepository(this._api);

  Future<DgtBenchmark> fetchBenchmark() async {
    try {
      final res = await _api.get('/dgt/stats/benchmark');
      if (res is! Map) return DgtBenchmark.empty;
      return DgtBenchmark.fromJson(Map<String, dynamic>.from(res));
    } catch (_) {
      return DgtBenchmark.empty;
    }
  }
}

final dgtBenchmarkRepositoryProvider =
    Provider<DgtBenchmarkRepository>((ref) {
  return DgtBenchmarkRepository(ref.watch(apiClientProvider));
});

final dgtBenchmarkProvider = FutureProvider<DgtBenchmark>((ref) async {
  return ref.watch(dgtBenchmarkRepositoryProvider).fetchBenchmark();
});

/// Pantalla "Comparativa cohorte" (issue #155).
class DgtCohortCompareScreen extends ConsumerStatefulWidget {
  const DgtCohortCompareScreen({super.key});

  @override
  ConsumerState<DgtCohortCompareScreen> createState() =>
      _DgtCohortCompareScreenState();
}

class _DgtCohortCompareScreenState
    extends ConsumerState<DgtCohortCompareScreen> {
  /// `true` = donde estoy mas fuerte primero (delta DESC, default).
  /// `false` = donde estoy mas debil primero (delta ASC).
  bool _strongestFirst = true;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dgtBenchmarkProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparativa cohorte'),
      ),
      body: async.when(
        loading: () => const _BenchmarkSkeleton(),
        error: (e, _) => AppStateView.error(
          'No se pudo cargar la comparativa: $e',
          onRetry: () => ref.invalidate(dgtBenchmarkProvider),
        ),
        data: (bench) {
          if (bench.isEmpty) {
            return AppStateView.empty(
              icon: Icons.insights_rounded,
              title: 'Aun no hay datos suficientes para comparar.',
              message: 'Responde algunas preguntas DGT y vuelve cuando la '
                  'cohorte tenga muestras suficientes.',
              onRetry: () => ref.invalidate(dgtBenchmarkProvider),
            );
          }
          return _BenchmarkBody(
            benchmark: bench,
            strongestFirst: _strongestFirst,
            onToggle: () =>
                setState(() => _strongestFirst = !_strongestFirst),
            onRefresh: () async {
              ref.invalidate(dgtBenchmarkProvider);
              await ref.read(dgtBenchmarkProvider.future);
            },
          );
        },
      ),
    );
  }
}

class _BenchmarkBody extends StatelessWidget {
  final DgtBenchmark benchmark;
  final bool strongestFirst;
  final VoidCallback onToggle;
  final Future<void> Function() onRefresh;

  const _BenchmarkBody({
    required this.benchmark,
    required this.strongestFirst,
    required this.onToggle,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final items = [...benchmark.topics];
    // Items sin user_pct (sin delta) van al final con orden estable.
    items.sort((a, b) {
      final aHas = a.delta != null;
      final bHas = b.delta != null;
      if (aHas != bHas) return aHas ? -1 : 1;
      if (!aHas) return a.topicId.compareTo(b.topicId);
      final cmp = a.delta!.compareTo(b.delta!);
      return strongestFirst ? -cmp : cmp;
    });

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          24 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          _SummaryCard(benchmark: benchmark),
          const SizedBox(height: 12),
          _OrderToggle(
            strongestFirst: strongestFirst,
            onToggle: onToggle,
          ),
          const SizedBox(height: 10),
          for (final item in items) ...[
            _BenchmarkTile(item: item),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final DgtBenchmark benchmark;
  const _SummaryCard({required this.benchmark});

  @override
  Widget build(BuildContext context) {
    final above = benchmark.aboveCount;
    final below = benchmark.belowCount;
    return Container(
      key: const Key('cohortSummary'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.c.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.c.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_rounded, color: DgtStatusColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Estas $above tema${above == 1 ? '' : 's'} por encima de '
              'la media, $below por debajo.',
              style: TextStyle(
                color: context.c.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderToggle extends StatelessWidget {
  final bool strongestFirst;
  final VoidCallback onToggle;
  const _OrderToggle({
    required this.strongestFirst,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Icon(
              strongestFirst
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              color: DgtStatusColors.info,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              strongestFirst
                  ? 'Donde estoy mas fuerte'
                  : 'Donde estoy mas debil',
              style: const TextStyle(
                color: DgtStatusColors.info,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.swap_vert_rounded,
              color: context.c.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tile con barras paralelas usuario vs cohorte global.
class _BenchmarkTile extends StatelessWidget {
  final DgtBenchmarkItem item;
  const _BenchmarkTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = item.topicName ?? item.topicId;
    final hasUser = item.userPct != null;
    final deltaText = _formatDelta(item.delta);
    final deltaColor = _deltaColor(item.delta);

    return Container(
      key: Key('benchmarkTile-${item.topicId}'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: context.c.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: context.c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (deltaText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: deltaColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    deltaText,
                    style: TextStyle(
                      color: deltaColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          DgtProgressBarRow(
            label: 'Tu',
            value: hasUser ? item.userPct! / 100.0 : 0,
            trailing: hasUser
                ? '${item.userPct!.toStringAsFixed(0)}%'
                : 'Sin respuestas',
            color: DgtStatusColors.info,
            labelFixedWidth: true,
            labelWidth: 48,
            trailingWidth: 54,
            barHeight: 8,
          ),
          const SizedBox(height: 6),
          DgtProgressBarRow(
            label: 'Media',
            value: item.globalPct / 100.0,
            trailing: '${item.globalPct.toStringAsFixed(0)}%',
            color: const Color(0xFF7A8497),
            labelFixedWidth: true,
            labelWidth: 48,
            trailingWidth: 54,
            barHeight: 8,
          ),
        ],
      ),
    );
  }

  static String? _formatDelta(double? delta) {
    if (delta == null) return null;
    final sign = delta >= 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(1)} pp';
  }

  static Color _deltaColor(double? delta) {
    if (delta == null) return const Color(0xFF7A8497);
    if (delta > 5) return DgtStatusColors.success;
    if (delta < -5) return DgtStatusColors.error;
    return DgtStatusColors.warning;
  }
}

class _BenchmarkSkeleton extends StatelessWidget {
  const _BenchmarkSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, _) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 80,
        decoration: BoxDecoration(
          color: context.c.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
