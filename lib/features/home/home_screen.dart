import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';
import 'package:memora/core/widgets/app_state_view.dart';

import '../../core/models/memora_card.dart';
import '../../core/theme/deck_visuals.dart';
import '../../data/repositories/deck_repository.dart';
import '../decks/deck_editor_screen.dart';
import '../decks/deck_screen.dart';
import '../dgt/dgt_daily_challenge_card.dart';
import '../dgt/dgt_exam_screen.dart';
import '../dgt/dgt_exam_snapshot.dart';
import '../dgt/dgt_failures_repository.dart';
import '../dgt/widgets/resume_exam_dialog.dart';
import '../dgt/dgt_failures_review_screen.dart';
import '../dgt/dgt_preparation_provider.dart';
import '../dgt/dgt_quick_review_screen.dart';
import '../dgt/dgt_ready_check_screen.dart';
import '../dgt/dgt_settings.dart';
import '../dgt/services/dgt_goal_notification_service.dart';
import '../dgt/services/dgt_streak_alert_service.dart';
import '../dgt/widgets/adaptive_goal_banner.dart';
import '../stats/stats_screen.dart';
import '../quest/quest_provider.dart';
import '../review/feed_screen.dart';
import '../review/study_queue.dart';
import 'deck_sort_preference.dart';
import 'welcome_tour.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Issue #84 (dgt-ux): controla la visibilidad del tour de bienvenida.
  /// Se setea a `true` en el primer build si la flag no esta completada;
  /// el overlay se desmonta tocando "Siguiente" en el ultimo paso o "Saltar".
  bool _showTour = false;

  @override
  Widget build(BuildContext context) {
    final decksAsync = ref.watch(deckSummariesProvider);
    final globalQueueAsync = ref.watch(studyQueueProvider(null));
    final questAsync = ref.watch(dailyQuestProvider);
    final sortOption = ref.watch(deckSortProvider);
    final dgtSettingsAsync = ref.watch(dgtSettingsProvider);
    final dgtPreparationAsync = ref.watch(dgtPreparationProvider);
    final tourCompletedAsync = ref.watch(dgtTourCompletedProvider);
    // Issue #95 (dgt-content): card "Repaso de fallos" - solo visible si N>0.
    final dgtFailuresCountAsync = ref.watch(dgtRecentFailuresCountProvider);
    // Issue #189 (dgt-ux): mantiene vivo el listener de notif de meta diaria.
    // El provider devuelve void; el side-effect (ref.listen) corre mientras
    // el arbol este montado. Idempotencia + toggle gating dentro del servicio.
    ref.watch(dgtGoalNotificationListenerProvider);
    // Issue #212 (dgt-ux): mantiene vivo el listener de alarma anti-perdida
    // de racha. Cada nueva review reprograma la notif (23h offset).
    ref.watch(dgtStreakAlertListenerProvider);

    // Issue #84: si la flag esta cargada y es false, mostrar el tour.
    // No-op si ya esta visible o ya completado.
    tourCompletedAsync.whenData((completed) {
      if (!completed && !_showTour) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_showTour) setState(() => _showTour = true);
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Mazos',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4),
        ),
        actions: [
          PopupMenuButton<DeckSortOption>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Ordenar mazos',
            initialValue: sortOption,
            onSelected: (o) => ref.read(deckSortProvider.notifier).setOption(o),
            itemBuilder: (context) => DeckSortOption.values
                .map(
                  (o) => PopupMenuItem<DeckSortOption>(
                    value: o,
                    child: Row(
                      children: [
                        Icon(
                          o == sortOption
                              ? Icons.check_rounded
                              : Icons.circle_outlined,
                          size: 18,
                          color: o == sortOption
                              ? AppColors.brand
                              : context.c.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Text(deckSortOptionLabel(o)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      body: Stack(
        children: [
          decksAsync.when(
        loading: () => AppStateView.loading(),
        error: (e, _) => AppStateView.error(e),
        data: (decks) {
          if (decks.isEmpty) {
            return _HomeEmptyState(
              onCreateDeck: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DeckEditorScreen()),
              ),
            );
          }
          final sorted = sortDecks(decks, sortOption);
          final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 96 + bottomInset),
            children: [
              questAsync.maybeWhen(
                data: (q) => q.streakDays >= 1
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: StreakBadge(streakDays: q.streakDays),
                      )
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),
              dgtSettingsAsync.maybeWhen(
                data: (s) => s.examDate != null
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DgtBanner(
                          settings: s,
                          preparation: dgtPreparationAsync.maybeWhen(
                            data: (p) => p,
                            orElse: () => null,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),
              // Issue #107 (dgt-ux): meta diaria adaptativa. Aditivo;
              // se auto-oculta si no hay desfase o si el banner fue
              // dismisseado en las ultimas 24h.
              dgtSettingsAsync.maybeWhen(
                data: (s) => s.examDate != null
                    ? const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: DgtAdaptiveGoalBanner(),
                      )
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),
              // Issue #136 (dgt-ux): banner "Listo para examen?" cuando
              // faltan <=7 dias. Aditivo, condicional, no rompe nada.
              dgtSettingsAsync.maybeWhen(
                data: (s) {
                  final days = s.daysUntilExam;
                  if (days == null || days < 0 || days > 7) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DgtReadyCheckBanner(daysUntilExam: days),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              questAsync.maybeWhen(
                data: (q) => _QuestBanner(quest: q),
                orElse: () => const SizedBox.shrink(),
              ),
              if (questAsync.maybeWhen(data: (_) => true, orElse: () => false))
                const SizedBox(height: 12),
              if (globalQueueAsync.maybeWhen(
                data: (q) => q.totalAvailable > 0,
                orElse: () => false,
              ))
                _DueBanner(
                  pending: globalQueueAsync.maybeWhen(
                    data: (q) => q.totalAvailable,
                    orElse: () => 0,
                  ),
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const FeedScreen())),
                ),
              if (globalQueueAsync.maybeWhen(
                data: (q) => q.totalAvailable > 0,
                orElse: () => false,
              ))
                const SizedBox(height: 16),
              // Issue #85 (dgt-ux): "Reto de hoy" contextual. Aditivo.
              // Posicion: debajo del banner urgencia, encima de _DgtExamBanner.
              dgtSettingsAsync.maybeWhen(
                data: (s) => s.examDate != null
                    ? const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: DgtDailyChallengeCard(),
                      )
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),
              // Issue #95 (dgt-content): "Repaso de fallos" - solo si hay
              // fallos recientes (ventana 7 dias). Posicion: debajo del Daily
              // Challenge, encima del banner de simulacro DGT.
              dgtFailuresCountAsync.maybeWhen(
                data: (count) => count > 0
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _DgtFailuresCard(
                          count: count,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DgtFailuresReviewScreen(),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),
              _DgtExamBanner(
                onTap: () => _openExamWithResume(context),
              ),
              const SizedBox(height: 16),
              ...sorted.map(
                (deck) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DeckTile(
                    deck: deck,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => DeckScreen(deck: deck)),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
          ),
          if (_showTour)
            Positioned.fill(
              child: WelcomeTourOverlay(
                steps: kDefaultDgtTourSteps,
                onDismiss: () async {
                  setState(() => _showTour = false);
                  await setDgtTourCompleted(ref, true);
                },
                onCompleted: () async {
                  setState(() => _showTour = false);
                  await setDgtTourCompleted(ref, true);
                },
              ),
            ),
        ],
      ),
      floatingActionButton: _HomeFab(),
    );
  }

  /// Issue #133 (dgt-ux): abre el simulacro DGT. Si hay un snapshot
  /// persistido (simulacro interrumpido), muestra el dialogo "Reanudar /
  /// Descartar" antes. Aditivo: si no hay snapshot el flow es identico al
  /// anterior (push directo a DgtExamScreen).
  Future<void> _openExamWithResume(BuildContext context) async {
    final repo = ref.read(dgtExamSnapshotRepositoryProvider);
    final snap = await repo.read();
    if (!context.mounted) return;
    if (snap == null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const DgtExamScreen()),
      );
      return;
    }
    final choice = await ResumeExamDialog.show(context, snap);
    if (!context.mounted) return;
    if (choice == ResumeExamChoice.discard) {
      await repo.clear();
      ref.invalidate(dgtExamPendingSnapshotProvider);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const DgtExamScreen()),
      );
      return;
    }
    if (choice == ResumeExamChoice.resume) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DgtExamScreen(resumeFrom: snap),
        ),
      );
      ref.invalidate(dgtExamPendingSnapshotProvider);
    }
    // null (back/dismiss) -> no abrir nada.
  }
}

class _DeckTile extends StatelessWidget {
  final DeckSummary deck;
  final VoidCallback onTap;

  const _DeckTile({required this.deck, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.c.surfaceElevated,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: deck.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  DeckVisuals.iconFor(deck.iconName),
                  color: deck.color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${deck.dueCount} due · ${deck.totalCount} total',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.c.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  final VoidCallback onCreateDeck;

  const _HomeEmptyState({required this.onCreateDeck});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7C5CFF), Color(0xFF4F8AFF)],
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.style_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Aún no tienes mazos',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Crea tu primer mazo para empezar a estudiar.\n'
            'Puedes organizar tarjetas por idioma, tema o lo que '
            'quieras aprender.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: context.c.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: onCreateDeck,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crear primer mazo'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _DueBanner extends StatelessWidget {
  final int pending;
  final VoidCallback onTap;

  const _DueBanner({required this.pending, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C5CFF), Color(0xFF4F8AFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$pending tarjetas listas para repasar',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestBanner extends StatelessWidget {
  final DailyQuest quest;
  const _QuestBanner({required this.quest});

  @override
  Widget build(BuildContext context) {
    final complete = quest.isComplete;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: context.c.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: complete
              ? DgtStatusColors.success.withValues(alpha: 0.45)
              : DgtStatusColors.warningStrong.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                complete ? '🏆' : '🎯',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'QUEST DIARIA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: DgtStatusColors.warningStrong,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            complete
                ? 'Quest completada — ¡a por mañana!'
                : 'Estudia ${quest.target} tarjetas hoy '
                      '(${quest.completed}/${quest.target})',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 6,
              color: Colors.black.withValues(alpha: 0.4),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: quest.progress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: complete
                          ? const [DgtStatusColors.success, Color(0xFF4FFFE9)]
                          : const [
                              DgtStatusColors.warningStrong,
                              DgtStatusColors.accentOrange,
                            ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner Home con mini-dashboard de preparacion DGT (issue #54).
/// - Header: dias hasta examen con color (verde >30, ambar 7-30, rojo <7).
/// - Body: progreso meta diaria (X/dailyGoal) + barra.
/// - Footer: prediccion APROBADO/SUSPENSO segun expectedScore vs >=0.90.
/// Tap en el banner navega a StatsScreen (vista DGT con detalle por tema).
/// Si `preparation` es null (loading o error inicial), degrada a la version
/// minima previa (solo header) para no romper el Home.
class _DgtBanner extends StatelessWidget {
  final DgtSettings settings;
  final DgtPreparation? preparation;
  const _DgtBanner({required this.settings, this.preparation});

  @override
  Widget build(BuildContext context) {
    final days = settings.daysUntilExam;
    final goal = settings.dailyGoal;
    final license = settings.licenseType.code;
    final accent = dgtBannerAccentColor(days);
    final String header;
    if (days == null) {
      header = 'Permiso $license - meta hoy: $goal preguntas';
    } else if (days < 0) {
      header = 'Examen pasado - sigue practicando ($goal/dia)';
    } else if (days == 0) {
      header = 'Hoy es tu examen! Suerte (Permiso $license)';
    } else {
      header = 'Examen en $days dia${days == 1 ? '' : 's'} (Permiso $license)';
    }

    final answered = preparation?.answeredToday ?? 0;
    final progress = preparation?.dailyProgress ?? 0.0;
    final verdictLabel = preparation?.verdictLabel ?? 'Prediccion: cargando...';
    // Issue #79 (dgt-ux): mensaje motivacional contextual.
    // Null si no aplica (sin examen, examen pasado, sin prediccion).
    final motivation = (preparation != null && preparation!.prediction.hasEnoughData)
        ? dgtMotivationMessage(days, preparation!.prediction.expectedScore)
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const StatsScreen())),
        borderRadius: BorderRadius.circular(14),
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
                children: [
                  Icon(
                    Icons.directions_car_filled_rounded,
                    color: accent,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      header,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: context.c.surfaceMuted,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$answered/$goal',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                verdictLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.c.textSecondary,
                ),
              ),
              if (motivation != null) ...[
                const SizedBox(height: 6),
                Text(
                  motivation,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: accent.withValues(alpha: 0.9),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              // CTA secundario: Repaso rapido (10 preguntas, 3 min). Pensado
              // para micro-sesiones. No persiste en historial. Issue #53.
              OutlinedButton.icon(
                // 44px tap-target accesible (Material guidelines).
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: accent,
                  side: BorderSide(color: accent.withValues(alpha: 0.45)),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DgtQuickReviewScreen(),
                  ),
                ),
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: const Text(
                  'Repaso rapido (3 min)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Issue #95 (dgt-content): card Home "Repaso de fallos".
/// Aparece solo si el usuario tiene fallos en los ultimos 7 dias.
/// Tap navega a [DgtFailuresReviewScreen].
class _DgtFailuresCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _DgtFailuresCard({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [DgtStatusColors.error, DgtStatusColors.accentOrange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Repaso de fallos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count pendiente${count == 1 ? '' : 's'} (ultimos 7 dias)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _DgtExamBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _DgtExamBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [DgtStatusColors.accentOrange, Color(0xFFE04FFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.directions_car_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Simulacro DGT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '30 preguntas · 30 min · permiso B',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'fab-deck',
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const DeckEditorScreen())),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Nuevo mazo'),
    );
  }
}

/// Issue #80 (dgt-ux): badge prominente del streak diario en Home.
///
/// Muestra un pill horizontal con icono fuego y "X dias seguidos". Si el
/// `streakDays` aumenta respecto al valor previo, dispara una `ScaleTransition`
/// breve (1.0 -> 1.25 -> 1.0, 600ms). La animacion NO se dispara en el primer
/// build (initial value). Si `streakDays < 1`, el caller no debe renderizarlo.
class StreakBadge extends StatefulWidget {
  final int streakDays;
  const StreakBadge({super.key, required this.streakDays});

  @override
  State<StreakBadge> createState() => _StreakBadgeState();
}

class _StreakBadgeState extends State<StreakBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant StreakBadge old) {
    super.didUpdateWidget(old);
    if (widget.streakDays > old.streakDays) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.streakDays == 1
        ? '1 dia seguido'
        : '${widget.streakDays} dias seguidos';
    return Align(
      alignment: Alignment.centerLeft,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: context.c.surfaceElevated,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: DgtStatusColors.accentOrange,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: DgtStatusColors.accentOrange,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Issue #136 (dgt-ux): banner accionable cuando faltan <=7 dias para el
/// examen. Compacto, tappable, lleva a [DgtReadyCheckScreen]. Aditivo.
class _DgtReadyCheckBanner extends StatelessWidget {
  final int daysUntilExam;
  const _DgtReadyCheckBanner({required this.daysUntilExam});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DgtReadyCheckScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: DgtStatusColors.error.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: DgtStatusColors.error.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.fact_check_rounded,
                color: DgtStatusColors.error,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      daysUntilExam == 0
                          ? 'Examen hoy: estas listo?'
                          : 'Faltan $daysUntilExam dia(s): estas listo?',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: DgtStatusColors.error,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Revisa 5 criterios antes de presentarte',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.c.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
