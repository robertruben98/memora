import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/widgets/app_state_view.dart';

import 'dgt_exam_calendar_phase.dart';
import 'dgt_favorites_screen.dart';
import 'dgt_ready_check_screen.dart';
import 'dgt_settings.dart';
import 'dgt_settings_screen.dart';
import 'dgt_today_study_screen.dart';
import 'dgt_weak_focus_screen.dart';
import '../study/dgt_exam_screen.dart' as study_exam;

/// Issue #187 (dgt-ux): pantalla "Mi calendario examen" con countdown D-N
/// y plan ramp-up por fases.
///
/// Lee `examDate` desde `dgtSettingsProvider`. Si esta vacia: empty-state con
/// CTA a Ajustes DGT. Si esta fijada: hero countdown + 4 fases del ramp-up.
class DgtExamCalendarScreen extends ConsumerWidget {
  const DgtExamCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dgtSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi calendario examen')),
      body: async.when(
        loading: () => AppStateView.loading(),
        error: (e, _) => _ErrorView(message: 'No se pudo cargar: $e'),
        data: (settings) => settings.examDate == null
            ? AppStateView.empty(
                icon: Icons.event_busy_rounded,
                title: 'Aun no tienes fecha de examen',
                message:
                    'Configura tu fecha en Ajustes DGT para ver tu countdown y plan de ramp-up.',
                retryLabel: 'Abrir Ajustes DGT',
                onRetry: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const DgtSettingsScreen(),
                    ),
                  );
                },
              )
            : _CalendarBody(settings: settings),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(child: Text(message, textAlign: TextAlign.center)),
    );
  }
}

class _CalendarBody extends StatelessWidget {
  final DgtSettings settings;
  const _CalendarBody({required this.settings});

  @override
  Widget build(BuildContext context) {
    final days = settings.daysUntilExam ?? 0;
    final isPast = days < 0;
    final isToday = days == 0;
    final current = isPast ? null : DgtExamPhase.forDays(days);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CountdownHero(
          days: days,
          examDate: settings.examDate!,
          isPast: isPast,
          isToday: isToday,
        ),
        const SizedBox(height: 24),
        if (isPast) const _ExamPassedTips() else ...[
          if (isToday) const _ExamTodayTips(),
          Text(
            'Tu plan de ramp-up',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final phase in DgtExamPhase.orderedTimeline())
            _PhaseTile(
              phase: phase,
              status: dgtExamPhaseStatus(
                phase: phase,
                current: current,
              ),
            ),
        ],
      ],
    );
  }
}

class _CountdownHero extends StatelessWidget {
  final int days;
  final DateTime examDate;
  final bool isPast;
  final bool isToday;

  const _CountdownHero({
    required this.days,
    required this.examDate,
    required this.isPast,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final accent = dgtBannerAccentColor(isPast ? null : days);
    final String headline;
    final String sub;
    if (isPast) {
      headline = 'Examen pasado';
      sub = '${-days} dia${-days == 1 ? '' : 's'} desde tu examen';
    } else if (isToday) {
      headline = 'Hoy es tu examen!';
      sub = 'Mucha suerte';
    } else {
      headline = 'D-$days';
      sub = '$days dia${days == 1 ? '' : 's'} para el examen';
    }
    final dateLabel = _formatDate(examDate);
    return Container(
      key: const Key('examCalendarHero'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.85), accent],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 8),
              Text(
                dateLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            headline,
            key: const Key('examCalendarHeadline'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 56,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _ExamTodayTips extends StatelessWidget {
  const _ExamTodayTips();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('examCalendarTodayTips'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB74F)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Consejos finales',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text('- Descansa y respira hondo.'),
          Text('- Lleva DNI y resguardo en regla.'),
          Text('- Lee cada pregunta entera antes de marcar.'),
          Text('- Atento a "siempre / nunca / excepto".'),
        ],
      ),
    );
  }
}

class _ExamPassedTips extends StatelessWidget {
  const _ExamPassedTips();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('examCalendarPassedTips'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4F8AFF)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Examen ya realizado',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Si necesitas repetirlo, actualiza tu fecha en Ajustes DGT '
            'para volver a ver tu plan de ramp-up.',
          ),
        ],
      ),
    );
  }
}

class _PhaseTile extends StatelessWidget {
  final DgtExamPhase phase;
  final DgtExamPhaseStatus status;

  const _PhaseTile({required this.phase, required this.status});

  @override
  Widget build(BuildContext context) {
    final highlight = status == DgtExamPhaseStatus.current;
    final passed = status == DgtExamPhaseStatus.passed;
    final accent = _phaseAccent(phase);
    final borderColor = highlight ? accent : context.c.border;
    final IconData icon = passed ? Icons.check_circle_rounded : _phaseIcon(phase);
    final iconColor = passed
        ? const Color(0xFF2E9E5B)
        : (highlight ? accent : context.c.textMuted);
    final cta = _phaseCta(context, phase);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        key: Key('examCalendarPhase-${phase.code}'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: highlight
              ? accent.withValues(alpha: 0.08)
              : context.c.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: highlight ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          phase.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: passed
                                ? context.c.textMuted
                                : context.c.textPrimary,
                          ),
                        ),
                      ),
                      _StatusChip(status: status, accent: accent),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phase.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: passed
                          ? context.c.textMuted
                          : context.c.textSecondary,
                    ),
                  ),
                  Text(
                    _rangeLabel(phase),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.c.textMuted,
                    ),
                  ),
                  if (highlight && cta != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        key: Key('examCalendarPhaseCta-${phase.code}'),
                        onPressed: cta.onTap,
                        icon: Icon(cta.icon),
                        label: Text(cta.label),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final DgtExamPhaseStatus status;
  final Color accent;
  const _StatusChip({required this.status, required this.accent});

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color bg;
    final Color fg;
    switch (status) {
      case DgtExamPhaseStatus.passed:
        label = 'Hecho';
        bg = const Color(0xFFE6F4EC);
        fg = const Color(0xFF2E9E5B);
      case DgtExamPhaseStatus.current:
        label = 'Ahora';
        bg = accent.withValues(alpha: 0.15);
        fg = accent;
      case DgtExamPhaseStatus.upcoming:
        label = 'Proxima';
        bg = context.c.surfaceMuted;
        fg = context.c.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _PhaseCta {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  _PhaseCta({required this.label, required this.icon, required this.onTap});
}

_PhaseCta? _phaseCta(BuildContext context, DgtExamPhase phase) {
  switch (phase) {
    case DgtExamPhase.temario:
      return _PhaseCta(
        label: 'Estudio de hoy',
        icon: Icons.today_rounded,
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const DgtTodayStudyScreen()),
        ),
      );
    case DgtExamPhase.refuerzo:
      return _PhaseCta(
        label: 'Atacar punto debil',
        icon: Icons.gps_fixed_rounded,
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const DgtWeakFocusScreen()),
        ),
      );
    case DgtExamPhase.simulacros:
      return _PhaseCta(
        label: 'Simulacro DGT',
        icon: Icons.directions_car_rounded,
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => const study_exam.DgtExamScreen(),
          ),
        ),
      );
    case DgtExamPhase.repaso:
      return _PhaseCta(
        label: 'Favoritos + ready-check',
        icon: Icons.favorite_rounded,
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => const DgtFavoritesScreen(),
          ),
        ).then((_) {
          if (context.mounted) {
            Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const DgtReadyCheckScreen()),
            );
          }
        }),
      );
  }
}

Color _phaseAccent(DgtExamPhase phase) {
  switch (phase) {
    case DgtExamPhase.temario:
      return const Color(0xFF4FFFB0);
    case DgtExamPhase.refuerzo:
      return const Color(0xFFFFB74F);
    case DgtExamPhase.simulacros:
      return const Color(0xFFFF6B35);
    case DgtExamPhase.repaso:
      return const Color(0xFFFF5C5C);
  }
}

IconData _phaseIcon(DgtExamPhase phase) {
  switch (phase) {
    case DgtExamPhase.temario:
      return Icons.menu_book_rounded;
    case DgtExamPhase.refuerzo:
      return Icons.gps_fixed_rounded;
    case DgtExamPhase.simulacros:
      return Icons.directions_car_rounded;
    case DgtExamPhase.repaso:
      return Icons.self_improvement_rounded;
  }
}

String _rangeLabel(DgtExamPhase phase) {
  if (phase.maxDays >= 9999) return 'A partir de D-${phase.minDays}';
  if (phase.minDays == phase.maxDays) return 'En D-${phase.minDays}';
  return 'Entre D-${phase.maxDays} y D-${phase.minDays}';
}

/// Formato local corto: "Mar 4 Jun".
String _formatDate(DateTime d) {
  const weekdays = ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];
  const months = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];
  // DateTime.weekday: 1=Lun .. 7=Dom -> indexar a 0..6.
  final wd = weekdays[d.weekday - 1];
  final mo = months[d.month - 1];
  return '$wd ${d.day} $mo';
}
