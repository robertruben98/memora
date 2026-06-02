import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';

import 'stats_repository.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(statsSnapshotProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Estadísticas',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (s) => _StatsBody(snapshot: s),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  final StatsSnapshot snapshot;
  const _StatsBody({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _StreakHero(streak: snapshot.streak),
        const SizedBox(height: 16),
        _StatsRow(snapshot: snapshot),
        const SizedBox(height: 24),
        const _SectionTitle('Distribución de tarjetas'),
        const SizedBox(height: 12),
        _StateDistribution(snapshot: snapshot),
        const SizedBox(height: 24),
        const _SectionTitle('Actividad — últimos 30 días'),
        const SizedBox(height: 12),
        _Heatmap(activity: snapshot.last30Days),
        const SizedBox(height: 12),
        _ActivityFooter(snapshot: snapshot),
      ],
    );
  }
}

class _StreakHero extends StatelessWidget {
  final int streak;
  const _StreakHero({required this.streak});

  @override
  Widget build(BuildContext context) {
    final hasStreak = streak > 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasStreak
              ? const [Color(0xFFFF8A4F), Color(0xFFFFD24F)]
              : [context.c.surfaceElevated, context.c.surfaceElevated],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: !hasStreak
            ? Border.all(color: context.c.border)
            : null,
      ),
      child: Row(
        children: [
          Text(
            hasStreak ? '🔥' : '💤',
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasStreak ? 'Racha actual' : 'Sin racha activa',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: hasStreak
                        ? Colors.black.withValues(alpha: 0.7)
                        : context.c.textSecondary,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasStreak
                      ? '$streak día${streak == 1 ? '' : 's'}'
                      : 'Estudia hoy para empezar',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: hasStreak ? Colors.black : context.c.textPrimary,
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

class _StatsRow extends StatelessWidget {
  final StatsSnapshot snapshot;
  const _StatsRow({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            value: snapshot.reviewsToday.toString(),
            label: 'hoy',
            icon: Icons.today_rounded,
            color: AppColors.brand,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStatCard(
            value: snapshot.reviewsThisWeek.toString(),
            label: 'esta semana',
            icon: Icons.calendar_view_week_rounded,
            color: const Color(0xFF4F8AFF),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStatCard(
            value: snapshot.totalReviews == 0
                ? '—'
                : '${(snapshot.retention * 100).toStringAsFixed(0)}%',
            label: 'retención',
            icon: Icons.psychology_rounded,
            color: const Color(0xFF4FFFB0),
          ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _MiniStatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: context.c.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: context.c.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StateDistribution extends StatelessWidget {
  final StatsSnapshot snapshot;
  const _StateDistribution({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final total = snapshot.totalCards;
    if (total == 0) {
      return _empty('Crea tarjetas para ver su distribución');
    }
    final items = [
      _DistItem('Nuevas', snapshot.newCount, const Color(0xFF4F8AFF)),
      _DistItem('Aprendiendo', snapshot.learningCount, const Color(0xFFFFD24F)),
      _DistItem('Repasando', snapshot.reviewingCount, const Color(0xFF4FFFB0)),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.c.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.c.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final it in items)
                Expanded(
                  flex: it.count == 0 ? 0 : it.count,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: it.color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map(
            (it) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: it.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      it.label,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Text(
                    '${it.count}',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.c.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 44,
                    child: Text(
                      total == 0
                          ? ''
                          : '${(it.count * 100 / total).toStringAsFixed(0)}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.c.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(String text) => Builder(
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.c.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.c.border),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(color: context.c.textMuted),
            ),
          ),
        ),
      );
}

class _DistItem {
  final String label;
  final int count;
  final Color color;
  const _DistItem(this.label, this.count, this.color);
}

class _Heatmap extends StatelessWidget {
  final List<DailyActivity> activity;
  const _Heatmap({required this.activity});

  @override
  Widget build(BuildContext context) {
    if (activity.isEmpty) return const SizedBox.shrink();
    final maxCount = activity.map((d) => d.count).fold<int>(0, (a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.c.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.c.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 30 squares laid out as 6 rows x 5 columns OR 5 rows x 6 columns
          // Going with 5 rows of 6 (each row = ~6 days)
          const cols = 6;
          const rows = 5;
          final gap = 6.0;
          final size = (constraints.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < rows * cols; i++)
                if (i < activity.length)
                  _HeatCell(
                    day: activity[i],
                    maxCount: maxCount,
                    size: size,
                  )
                else
                  SizedBox(width: size, height: size),
            ],
          );
        },
      ),
    );
  }
}

class _HeatCell extends StatelessWidget {
  final DailyActivity day;
  final int maxCount;
  final double size;

  const _HeatCell({
    required this.day,
    required this.maxCount,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final intensity = maxCount == 0 ? 0.0 : day.count / maxCount;
    final today = DateTime.now();
    final isToday = day.day.year == today.year &&
        day.day.month == today.month &&
        day.day.day == today.day;

    final base = AppColors.brand;
    final color = day.count == 0
        ? context.c.surfaceMuted
        : base.withValues(alpha: 0.18 + 0.6 * intensity);

    return Tooltip(
      message:
          '${day.day.day}/${day.day.month}: ${day.count} tarjeta${day.count == 1 ? '' : 's'}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: isToday
              ? Border.all(color: context.c.border, width: 1.5)
              : null,
        ),
        alignment: Alignment.center,
        child: day.count > 0
            ? Text(
                day.count.toString(),
                style: TextStyle(
                  fontSize: size > 36 ? 11 : 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              )
            : null,
      ),
    );
  }
}

class _ActivityFooter extends StatelessWidget {
  final StatsSnapshot snapshot;
  const _ActivityFooter({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(
            'Total revisiones: ${snapshot.totalReviews}',
            style: TextStyle(
              fontSize: 12,
              color: context.c.textMuted,
            ),
          ),
          const Spacer(),
          Text(
            'Tarjetas: ${snapshot.totalCards}',
            style: TextStyle(
              fontSize: 12,
              color: context.c.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
