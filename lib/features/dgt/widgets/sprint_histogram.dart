import 'package:flutter/material.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';
import 'package:memora/core/widgets/app_state_view.dart';

import '../dgt_sprint_history_provider.dart';

/// Issue #152 (dgt-ux): histograma horizontal con las ultimas N entradas del
/// historial de sprints. Cada barra representa los aciertos (0..total) y el
/// color depende de si el sprint esta aprobado ([DgtSprintEntry.passed]).
///
/// Aditivo: no maneja persistencia, solo presenta. Espera entradas ordenadas
/// de mas reciente a mas antigua.
class SprintHistogram extends StatelessWidget {
  final List<DgtSprintEntry> entries;

  /// Ventana maxima de barras visibles. Por defecto
  /// [kDgtSprintHistogramWindow]. Las entradas mas antiguas se ignoran.
  final int window;

  /// Altura total disponible para las barras. Las barras escalan dentro de
  /// este alto en proporcion a los aciertos.
  final double height;

  const SprintHistogram({
    super.key,
    required this.entries,
    this.window = kDgtSprintHistogramWindow,
    this.height = 110,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return SizedBox(
        height: height,
        child: AppStateView.empty(
          icon: Icons.bar_chart_rounded,
          title: 'Aun no tienes sprints',
          message: 'Este es tu primero.',
        ),
      );
    }

    // Tomamos los N mas recientes, pero los pintamos de izquierda (antiguo)
    // a derecha (reciente) para que la lectura visual sea cronologica.
    final visible = entries.take(window).toList().reversed.toList();
    final total = visible.first.total;

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final e in visible)
                  Expanded(
                    child: Semantics(
                      label:
                          'Sprint ${e.correct} de ${e.total} aciertos en ${e.secondsUsed} segundos',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _Bar(
                          ratio: total > 0 ? e.correct / total : 0,
                          passed: e.passed,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double ratio;
  final bool passed;

  const _Bar({required this.ratio, required this.passed});

  @override
  Widget build(BuildContext context) {
    final color = DgtStatusColors.forPassed(passed);
    final clamped = ratio.clamp(0.05, 1.0);
    return LayoutBuilder(
      builder: (context, c) {
        final h = (c.maxHeight * clamped).clamp(4.0, c.maxHeight);
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: h,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
