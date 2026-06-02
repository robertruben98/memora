import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';

import '../dgt_adaptive_goal_provider.dart';
import '../dgt_settings.dart';

/// Issue #107 (dgt-ux): banner sugiriendo ajuste de meta diaria.
///
/// Solo se renderiza si `dgtAdaptiveGoalProvider` devuelve `shouldShowBanner`.
/// Permite:
/// - CTA "Ajustar meta a N/dia" -> actualiza `DgtSettings.dailyGoal`.
/// - Boton "x" -> guarda timestamp en SharedPreferences (cooldown 24h).
///
/// Aditivo, no toca el banner existente `_DgtBanner` ni `DgtPreparation`.
class DgtAdaptiveGoalBanner extends ConsumerWidget {
  const DgtAdaptiveGoalBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalAsync = ref.watch(dgtAdaptiveGoalProvider);
    return goalAsync.maybeWhen(
      data: (g) {
        if (!g.shouldShowBanner) return const SizedBox.shrink();
        return _Banner(goal: g);
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Banner extends ConsumerStatefulWidget {
  final DgtAdaptiveGoal goal;
  const _Banner({required this.goal});

  @override
  ConsumerState<_Banner> createState() => _BannerState();
}

class _BannerState extends ConsumerState<_Banner> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.goal;
    final accelerate = g.mustAccelerate == true;
    final accent = accelerate
        ? DgtStatusColors.warning
        : DgtStatusColors.success;
    final suggested = g.suggested!;
    final days = g.daysToExam;
    final message = _buildMessage(
      accelerate: accelerate,
      suggested: suggested,
      current: g.currentGoal,
      days: days,
    );

    return Material(
      color: Colors.transparent,
      child: Ink(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: context.c.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.55)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  accelerate
                      ? Icons.trending_up_rounded
                      : Icons.beach_access_rounded,
                  color: accent,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Ocultar 24h',
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: _busy ? null : _dismiss,
                  icon: Icon(
                    Icons.close_rounded,
                    color: context.c.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _applyGoal(suggested),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: Text(
                      'Ajustar meta a $suggested/dia',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _buildMessage({
    required bool accelerate,
    required int suggested,
    required int current,
    required int? days,
  }) {
    final dayLabel = days == null
        ? ''
        : ' en $days dia${days == 1 ? '' : 's'}';
    if (accelerate) {
      return 'Vas tarde para llegar al examen$dayLabel. '
          'Sube de $current a $suggested preguntas/dia para llegar listo.';
    }
    return 'Vas sobrado$dayLabel. Puedes bajar de $current a $suggested '
        'preguntas/dia y mantener el progreso.';
  }

  Future<void> _applyGoal(int newGoal) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(dgtSettingsRepositoryProvider);
      final current = await ref.read(dgtSettingsProvider.future);
      await repo.save(current.copyWith(dailyGoal: newGoal));
      ref.invalidate(dgtSettingsProvider);
      ref.invalidate(dgtAdaptiveGoalProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Meta actualizada a $newGoal preguntas/dia'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar la meta'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dismiss() async {
    setState(() => _busy = true);
    try {
      await writeDgtAdaptiveBannerDismissedAt(DateTime.now());
      ref.invalidate(dgtAdaptiveBannerDismissedAtProvider);
      ref.invalidate(dgtAdaptiveGoalProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
