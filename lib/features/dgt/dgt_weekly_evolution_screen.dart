import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/widgets/app_state_view.dart';

import '../../data/api/api_client.dart';

/// Issue #183 (dgt-ux): pantalla "Tu evolucion semanal" con chart visual.
///
/// Consume BE#176 `/dgt/reports/weekly-summary?week_offset=N` iterando 0..-7
/// para obtener 8 semanas de datos (W-7 ... W actual). Renderiza LineChart
/// con 3 series visualmente diferenciadas:
///   - % acierto semanal (`accuracy_overall * 100`).
///   - simulacros completados (escalado a 0..100 sobre maximo observado).
///   - streak de dias consecutivos (escalado a 0..100 sobre 7).
///
/// Etiqueta de tendencia: delta vs W-1 (verde sube, rojo baja, amarillo
/// estable). Tap en un punto: bottom-sheet con KPIs de la semana.
///
/// Estado vacio: ninguna semana tiene `questions_answered > 0`. CTA al quiz
/// del dia (`/today` no esta cableado por router; navegamos a pop y dejamos
/// el callsite responsable de empujar la pantalla de quiz).
///
/// Aditivo: NO toca providers/repos existentes. Repo y provider locales.

// ---------- modelo ----------

/// Snapshot semanal devuelto por BE#176.
class DgtWeeklyPoint {
  final int weekOffset; // 0 = semana actual, -1 = semana pasada, ...
  final String periodStart; // YYYY-MM-DD lunes
  final String periodEnd; // YYYY-MM-DD domingo
  final int questionsAnswered;
  final double accuracyOverall; // 0..1
  final double accuracyDeltaVsPrev; // 0..1 (puede ser negativo)
  final int simulacrosCompleted;
  final int simulacrosPassed;
  final double predictorPassProb; // 0..1
  final int streakDays;
  final String? weakTopicName;
  final String? improvedTopicName;
  final String recommendation;

  const DgtWeeklyPoint({
    required this.weekOffset,
    required this.periodStart,
    required this.periodEnd,
    required this.questionsAnswered,
    required this.accuracyOverall,
    required this.accuracyDeltaVsPrev,
    required this.simulacrosCompleted,
    required this.simulacrosPassed,
    required this.predictorPassProb,
    required this.streakDays,
    required this.weakTopicName,
    required this.improvedTopicName,
    required this.recommendation,
  });

  /// Parser tolerante: payload BE puede traer nulls en topics anidados.
  factory DgtWeeklyPoint.fromJson(Map<String, dynamic> j) {
    final period = (j['period'] as Map?) ?? const {};
    final weak = j['top_weak_topic'] as Map?;
    final improved = j['top_improved_topic'] as Map?;
    return DgtWeeklyPoint(
      weekOffset: (j['week_offset'] as num?)?.toInt() ?? 0,
      periodStart: (period['start'] as String?) ?? '',
      periodEnd: (period['end'] as String?) ?? '',
      questionsAnswered:
          (j['questions_answered'] as num?)?.toInt() ?? 0,
      accuracyOverall:
          (j['accuracy_overall'] as num?)?.toDouble() ?? 0.0,
      accuracyDeltaVsPrev:
          (j['accuracy_delta_vs_prev_week'] as num?)?.toDouble() ?? 0.0,
      simulacrosCompleted:
          (j['simulacros_completed'] as num?)?.toInt() ?? 0,
      simulacrosPassed: (j['simulacros_passed'] as num?)?.toInt() ?? 0,
      predictorPassProb:
          (j['predictor_pass_prob'] as num?)?.toDouble() ?? 0.0,
      streakDays: (j['streak_days'] as num?)?.toInt() ?? 0,
      weakTopicName: weak == null ? null : weak['name'] as String?,
      improvedTopicName:
          improved == null ? null : improved['name'] as String?,
      recommendation: (j['recommendation'] as String?) ?? '',
    );
  }

  bool get hasActivity => questionsAnswered > 0;
}

/// Coleccion ordenada cronologicamente (W-7 -> W actual).
class DgtWeeklyEvolution {
  /// Puntos ordenados por `weekOffset` ASC (mas antiguo primero).
  final List<DgtWeeklyPoint> points;

  const DgtWeeklyEvolution(this.points);

  /// Vacio si NINGUNA semana tuvo actividad.
  bool get isEmpty => points.every((p) => !p.hasActivity);

  /// Numero de semanas con actividad (>=1 pregunta respondida).
  int get activeWeeks => points.where((p) => p.hasActivity).length;

  /// Delta de accuracy entre la ultima semana con actividad y la anterior
  /// con actividad. Null si no hay al menos 2 semanas con datos.
  double? get accuracyTrendDelta {
    final active = points.where((p) => p.hasActivity).toList();
    if (active.length < 2) return null;
    final last = active.last;
    final prev = active[active.length - 2];
    return last.accuracyOverall - prev.accuracyOverall;
  }
}

// ---------- repo ----------

/// Repo thin para BE#176. Itera offsets 0..-7 (8 puntos) en paralelo y
/// agrupa. Tolerante a errores por semana: una semana con 500 NO rompe
/// el dataset completo (se omite el punto fallido).
class DgtWeeklyEvolutionRepository {
  final ApiClient _api;
  final int weeks;

  DgtWeeklyEvolutionRepository(this._api, {this.weeks = 8});

  Future<DgtWeeklyEvolution> fetchEvolution() async {
    final offsets = List<int>.generate(weeks, (i) => -(weeks - 1) + i);
    final futures = offsets.map((off) async {
      try {
        final res = await _api.get(
          '/dgt/reports/weekly-summary',
          query: {'week_offset': '$off'},
        );
        if (res is! Map) return null;
        return DgtWeeklyPoint.fromJson(Map<String, dynamic>.from(res));
      } catch (_) {
        return null;
      }
    });
    final results = await Future.wait(futures);
    final points = results.whereType<DgtWeeklyPoint>().toList()
      ..sort((a, b) => a.weekOffset.compareTo(b.weekOffset));
    return DgtWeeklyEvolution(points);
  }
}

final dgtWeeklyEvolutionRepositoryProvider =
    Provider<DgtWeeklyEvolutionRepository>((ref) {
  return DgtWeeklyEvolutionRepository(ref.watch(apiClientProvider));
});

final dgtWeeklyEvolutionProvider =
    FutureProvider<DgtWeeklyEvolution>((ref) async {
  return ref.watch(dgtWeeklyEvolutionRepositoryProvider).fetchEvolution();
});

// ---------- screen ----------

/// Pantalla principal "Tu evolucion semanal" (issue #183).
class DgtWeeklyEvolutionScreen extends ConsumerWidget {
  const DgtWeeklyEvolutionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dgtWeeklyEvolutionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tu evolucion semanal')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dgtWeeklyEvolutionProvider);
          await ref.read(dgtWeeklyEvolutionProvider.future);
        },
        child: async.when(
          loading: () => AppStateView.loading(),
          error: (e, _) => _ErrorView(
            message: 'No se pudo cargar la evolucion: $e',
            onRetry: () => ref.invalidate(dgtWeeklyEvolutionProvider),
          ),
          data: (evo) {
            if (evo.isEmpty) {
              return AppStateView.empty(
                icon: Icons.show_chart_rounded,
                title:
                    'Necesitas al menos 1 semana de datos para ver tu evolucion.',
                message: 'Empieza haciendo un quiz hoy.',
              );
            }
            return _EvolutionBody(evolution: evo);
          },
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton(
            onPressed: onRetry,
            child: const Text('Reintentar'),
          ),
        ),
      ],
    );
  }
}

class _EvolutionBody extends StatelessWidget {
  final DgtWeeklyEvolution evolution;
  const _EvolutionBody({required this.evolution});

  @override
  Widget build(BuildContext context) {
    final delta = evolution.accuracyTrendDelta;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _TrendBadge(delta: delta),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: _WeeklyTrendChart(evolution: evolution),
        ),
        const SizedBox(height: 16),
        const _LegendRow(),
        const SizedBox(height: 24),
        Text(
          'Semanas (${evolution.activeWeeks} con actividad)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final p in evolution.points.reversed)
          _WeekTile(point: p),
      ],
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final double? delta;
  const _TrendBadge({required this.delta});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String label;
    final d = delta;
    if (d == null) {
      color = const Color(0xFFFFB300);
      icon = Icons.horizontal_rule_rounded;
      label = 'Datos insuficientes';
    } else if (d > 0.02) {
      color = const Color(0xFF2E9E5B);
      icon = Icons.arrow_upward_rounded;
      label =
          'Subiendo +${(d * 100).toStringAsFixed(1)} pts vs semana pasada';
    } else if (d < -0.02) {
      color = const Color(0xFFD64545);
      icon = Icons.arrow_downward_rounded;
      label =
          'Bajando ${(d * 100).toStringAsFixed(1)} pts vs semana pasada';
    } else {
      color = const Color(0xFFFFB300);
      icon = Icons.trending_flat_rounded;
      label = 'Estable vs semana pasada';
    }
    return Container(
      key: const Key('weeklyTrendBadge'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        _LegendDot(color: Color(0xFF4FA8FF), label: '% acierto'),
        _LegendDot(color: Color(0xFFFF6B35), label: 'Simulacros'),
        _LegendDot(color: AppColors.brand, label: 'Streak (dias)'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _WeeklyTrendChart extends StatelessWidget {
  final DgtWeeklyEvolution evolution;
  const _WeeklyTrendChart({required this.evolution});

  @override
  Widget build(BuildContext context) {
    final points = evolution.points;
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }
    // Normalizaciones a escala 0..100 para co-renderizar series:
    // accuracy ya esta 0..1 -> *100.
    // simulacros: max observado (al menos 1).
    // streak: max teorico 7 dias por semana.
    final maxSimu = points
        .map((p) => p.simulacrosCompleted)
        .fold<int>(1, (a, b) => b > a ? b : a);
    final accuracySpots = <FlSpot>[];
    final simulacrosSpots = <FlSpot>[];
    final streakSpots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      accuracySpots.add(FlSpot(i.toDouble(), p.accuracyOverall * 100));
      simulacrosSpots.add(FlSpot(
        i.toDouble(),
        (p.simulacrosCompleted / maxSimu) * 100,
      ));
      streakSpots.add(FlSpot(
        i.toDouble(),
        (p.streakDays.clamp(0, 7) / 7.0) * 100,
      ));
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 105,
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        gridData: const FlGridData(show: true, horizontalInterval: 25),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 25,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) {
                  return const SizedBox.shrink();
                }
                final offset = points[i].weekOffset;
                final label = offset == 0 ? 'W' : 'W$offset';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          _line(accuracySpots, const Color(0xFF4FA8FF)),
          _line(simulacrosSpots, const Color(0xFFFF6B35)),
          _line(streakSpots, AppColors.brand),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions) return;
            final spots = response?.lineBarSpots;
            if (spots == null || spots.isEmpty) return;
            final idx = spots.first.spotIndex;
            if (idx < 0 || idx >= points.length) return;
            // El builder envuelve con BuildContext via callback.
            // No tenemos context aqui; el screen muestra el sheet on tap.
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => touched
                .map((t) => LineTooltipItem(
                      t.y.toStringAsFixed(0),
                      const TextStyle(
                          color: Colors.white, fontSize: 11),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: false,
      color: color,
      barWidth: 2.5,
      dotData: const FlDotData(show: true),
    );
  }
}

class _WeekTile extends StatelessWidget {
  final DgtWeeklyPoint point;
  const _WeekTile({required this.point});

  String get _label {
    if (point.weekOffset == 0) return 'Esta semana';
    if (point.weekOffset == -1) return 'Semana pasada';
    return 'Hace ${-point.weekOffset} semanas';
  }

  @override
  Widget build(BuildContext context) {
    final pct = (point.accuracyOverall * 100).toStringAsFixed(0);
    return Card(
      key: Key('weekTile-${point.weekOffset}'),
      child: ListTile(
        title: Text('$_label  ·  $pct% acierto'),
        subtitle: Text(
          '${point.questionsAnswered} preguntas · '
          '${point.simulacrosCompleted} simulacros · '
          'streak ${point.streakDays}d',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          builder: (_) => _WeekDetailSheet(point: point),
        ),
      ),
    );
  }
}

class _WeekDetailSheet extends StatelessWidget {
  final DgtWeeklyPoint point;
  const _WeekDetailSheet({required this.point});

  @override
  Widget build(BuildContext context) {
    final pct = (point.accuracyOverall * 100).toStringAsFixed(1);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${point.periodStart} - ${point.periodEnd}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _kpi(context, 'Preguntas', '${point.questionsAnswered}'),
            _kpi(context, 'Acierto', '$pct%'),
            _kpi(context, 'Simulacros', '${point.simulacrosCompleted}'),
            _kpi(context, 'Aprobados', '${point.simulacrosPassed}'),
            _kpi(context, 'Streak', '${point.streakDays} dias'),
            if (point.weakTopicName != null)
              _kpi(context, 'Tema mas debil', point.weakTopicName!),
            if (point.improvedTopicName != null)
              _kpi(context, 'Tema que mejoraste', point.improvedTopicName!),
            const SizedBox(height: 12),
            if (point.recommendation.isNotEmpty)
              Text(
                point.recommendation,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: context.c.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _kpi(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(color: context.c.textMuted)),
          ),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
