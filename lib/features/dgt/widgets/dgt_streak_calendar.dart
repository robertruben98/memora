import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dgt_streak_provider.dart';

/// Issue #147 (dgt-ux): widget calendario mensual de racha DGT.
///
/// Muestra grid 7 columnas x N filas con dias del mes coloreados segun
/// actividad. Funciona offline (datos locales). Si el provider falla o no
/// hay actividad alguna, se renderiza vacio (todos los dias en gris) sin
/// romper Home.
///
/// Tap en un dia muestra un snackbar con el conteo de preguntas. No navega.
class DgtStreakCalendar extends ConsumerWidget {
  const DgtStreakCalendar({super.key});

  static const _weekdayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMonth = ref.watch(dgtStreakMonthProvider);
    return asyncMonth.when(
      data: (m) => _Body(month: m),
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  static String _monthName(int month) {
    const names = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    if (month < 1 || month > 12) return '';
    return names[month - 1];
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.month});

  final DgtStreakMonth month;

  @override
  Widget build(BuildContext context) {
    if (month.year == DgtStreakMonth.empty.year) {
      return const SizedBox.shrink();
    }
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstOfMonth = DateTime(month.year, month.month, 1);
    // Lunes-first: weekday 1..7 (L..D). Restamos 1 para columna 0..6.
    final leadingEmpty = firstOfMonth.weekday - 1;
    final cells = <Widget>[];
    for (var i = 0; i < leadingEmpty; i++) {
      cells.add(const SizedBox.shrink());
    }
    final now = DateTime.now();
    for (var d = 1; d <= daysInMonth; d++) {
      final isToday = now.year == month.year &&
          now.month == month.month &&
          now.day == d;
      cells.add(_DayCell(day: d, month: month, isToday: isToday));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DgtStreakCalendar._monthName(month.month),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                'Racha: ${month.currentStreak} dias',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: DgtStreakCalendar._weekdayLabels
                .map((l) => Expanded(
                      child: Center(
                        child: Text(
                          l,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: cells,
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.month,
    required this.isToday,
  });

  final int day;
  final DgtStreakMonth month;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final status = month.statusForDay(day);
    final count = month.activityByDay[day] ?? 0;
    final color = switch (status) {
      DgtDayStatus.none => Colors.grey.shade300,
      DgtDayStatus.partial => Colors.amber.shade400,
      DgtDayStatus.full => Colors.green.shade500,
    };
    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        onTap: () {
          final mm = month.month.toString().padLeft(2, '0');
          final dd = day.toString().padLeft(2, '0');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count preguntas el $dd/$mm'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            border: isToday
                ? Border.all(color: Colors.blue, width: 2)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              color: status == DgtDayStatus.none
                  ? Colors.black54
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
