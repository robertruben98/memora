import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/memora_card.dart';
import '../../core/theme/deck_visuals.dart';
import '../../data/repositories/deck_repository.dart';
import '../learn/learn_methods_screen.dart';
import '../review/feed_screen.dart';
import '../review/study_queue.dart';
import 'dgt_exam_history.dart';
import 'dgt_exam_screen.dart';
import 'dgt_history_screen.dart';
import 'dgt_sections_screen.dart';
import 'failed_cards_provider.dart';
import 'failed_review_screen.dart';
import 'marked_cards_provider.dart';
import 'marked_review_screen.dart';

class StudyHubScreen extends ConsumerWidget {
  const StudyHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(studyQueueProvider(null));
    final decksAsync = ref.watch(deckSummariesProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Estudiar',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_rounded),
            tooltip: 'Aprende a aprender',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LearnMethodsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          32 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          _StudyAllHero(
            pendingCount: queueAsync.maybeWhen(
              data: (q) => q.totalAvailable,
              orElse: () => null,
            ),
            dueCount: queueAsync.maybeWhen(
              data: (q) => q.dueCount,
              orElse: () => null,
            ),
            newCount: queueAsync.maybeWhen(
              data: (q) => q.newCount,
              orElse: () => null,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FeedScreen()),
            ),
          ),
          const SizedBox(height: 14),
          _DgtExamTile(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DgtExamScreen()),
            ),
          ),
          const SizedBox(height: 10),
          _DgtHistoryTile(
            historyCount: ref.watch(dgtExamHistoryProvider).maybeWhen(
                  data: (entries) => entries.length,
                  orElse: () => null,
                ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DgtHistoryScreen()),
            ),
          ),
          const SizedBox(height: 14),
          _DgtSectionsTile(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const DgtStudySectionsScreen(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _FailedReviewTile(
            failedCount: ref.watch(failedCardsProvider).maybeWhen(
                  data: (r) => r.count,
                  orElse: () => null,
                ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FailedReviewScreen()),
            ),
          ),
          const SizedBox(height: 14),
          _MarkedReviewTile(
            markedCount: ref.watch(markedCardsProvider).count,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MarkedReviewScreen()),
            ),
          ),
          const SizedBox(height: 14),
          _LearnMethodsTile(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LearnMethodsScreen()),
            ),
          ),
          const SizedBox(height: 28),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Estudiar un mazo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          decksAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (decks) {
              if (decks.isEmpty) {
                return _empty();
              }
              return Column(
                children: [
                  for (final d in decks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DeckQuickRow(
                        deck: d,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FeedScreen(deckId: d.id),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.style_rounded,
              size: 40,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'Crea un mazo desde la pestaña Mazos',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
}

class _StudyAllHero extends StatelessWidget {
  final int? pendingCount;
  final int? dueCount;
  final int? newCount;
  final VoidCallback onTap;

  const _StudyAllHero({
    required this.pendingCount,
    required this.dueCount,
    required this.newCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final allCaughtUp = pendingCount == 0;
    final loading = pendingCount == null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: allCaughtUp ? null : onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: allCaughtUp
                  ? const [Color(0xFF1A1A22), Color(0xFF1A1A22)]
                  : const [Color(0xFF7C5CFF), Color(0xFF4F8AFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: allCaughtUp
                ? Border.all(
                    color: const Color(0xFF4FFFB0).withValues(alpha: 0.4),
                    width: 1.5,
                  )
                : null,
            boxShadow: allCaughtUp
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF7C5CFF).withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: allCaughtUp
                          ? const Color(0xFF4FFFB0).withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      allCaughtUp
                          ? Icons.check_circle_outline_rounded
                          : Icons.play_arrow_rounded,
                      color: allCaughtUp
                          ? const Color(0xFF4FFFB0)
                          : Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          allCaughtUp
                              ? '¡Todo al día!'
                              : 'Empezar sesión',
                          style: TextStyle(
                            color: allCaughtUp
                                ? Colors.white70
                                : Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          loading
                              ? 'Calculando…'
                              : allCaughtUp
                                  ? 'No hay tarjetas pendientes'
                                  : '$pendingCount tarjetas listas',
                          style: TextStyle(
                            color: allCaughtUp
                                ? const Color(0xFF4FFFB0)
                                : Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                            fontWeight:
                                allCaughtUp ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!allCaughtUp && !loading) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    if ((dueCount ?? 0) > 0)
                      _StatChip(
                        label: '$dueCount due',
                        color: Colors.white,
                      ),
                    if ((dueCount ?? 0) > 0 && (newCount ?? 0) > 0)
                      const SizedBox(width: 8),
                    if ((newCount ?? 0) > 0)
                      _StatChip(
                        label: '$newCount nuevas',
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DeckQuickRow extends ConsumerWidget {
  final DeckSummary deck;
  final VoidCallback onTap;

  const _DeckQuickRow({required this.deck, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(studyQueueProvider(deck.id));
    final pending = queueAsync.maybeWhen(
      data: (q) => q.totalAvailable,
      orElse: () => null,
    );
    final allCaughtUp = pending == 0;
    return Material(
      color: const Color(0xFF1A1A22),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: allCaughtUp ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: deck.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  DeckVisuals.iconFor(deck.iconName),
                  color: deck.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pending == null
                          ? '${deck.totalCount} tarjetas'
                          : allCaughtUp
                              ? 'al día'
                              : '$pending pendientes',
                      style: TextStyle(
                        fontSize: 12,
                        color: allCaughtUp
                            ? const Color(0xFF4FFFB0)
                            : Colors.white.withValues(alpha: 0.55),
                        fontWeight:
                            allCaughtUp ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                allCaughtUp
                    ? Icons.check_circle_outline_rounded
                    : Icons.play_arrow_rounded,
                color: allCaughtUp
                    ? const Color(0xFF4FFFB0)
                    : deck.color,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DgtExamTile extends StatelessWidget {
  final VoidCallback onTap;
  const _DgtExamTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFFFA552)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.directions_car_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Simulacro DGT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '30 preguntas, 30 minutos, criterio examen oficial',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FailedReviewTile extends StatelessWidget {
  final VoidCallback onTap;
  final int? failedCount;
  const _FailedReviewTile({required this.onTap, required this.failedCount});

  @override
  Widget build(BuildContext context) {
    final hasFailed = (failedCount ?? 0) > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasFailed
                  ? const Color(0xFFFF6B6B).withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.replay_rounded,
                  color: Color(0xFFFF6B6B),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Repaso de falladas',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasFailed
                          ? 'Refuerza las cards que fallaste recientemente'
                          : 'Sin fallos recientes',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasFailed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$failedCount',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarkedReviewTile extends StatelessWidget {
  final VoidCallback onTap;
  final int markedCount;
  const _MarkedReviewTile({required this.onTap, required this.markedCount});

  @override
  Widget build(BuildContext context) {
    final hasMarked = markedCount > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasMarked
                  ? const Color(0xFFFFC857).withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC857).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFFC857),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasMarked
                          ? 'Repasar marcadas ($markedCount)'
                          : 'Repasar marcadas',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasMarked
                          ? 'Tus preguntas peligrosas para repasar pre-examen'
                          : 'Marca preguntas con la estrella durante el estudio',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasMarked)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC857),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$markedCount',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A22),
                    ),
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DgtHistoryTile extends StatelessWidget {
  final VoidCallback onTap;
  final int? historyCount;
  const _DgtHistoryTile({required this.onTap, required this.historyCount});

  @override
  Widget build(BuildContext context) {
    final count = historyCount ?? 0;
    final hasHistory = count > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.35),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.history_rounded,
                  color: Color(0xFFFF6B35),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Historial de simulacros',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasHistory
                          ? '$count simulacro${count == 1 ? '' : 's'} guardado${count == 1 ? '' : 's'}'
                          : 'Aun sin simulacros completados',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DgtSectionsTile extends StatelessWidget {
  final VoidCallback onTap;
  const _DgtSectionsTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF7C5CFF).withValues(alpha: 0.45),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C5CFF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Color(0xFFB9A6FF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estudiar por Secciones',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Clases teoricas DGT por bloque tematico (lectura)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LearnMethodsTile extends StatelessWidget {
  final VoidCallback onTap;
  const _LearnMethodsTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF4FFFB0).withValues(alpha: 0.35),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF4FFFB0).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text('📖', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aprende a aprender',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Métodos con evidencia: SRS, recall, Feynman, mnemónicas…',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: const Color(0xFF4FFFB0).withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
