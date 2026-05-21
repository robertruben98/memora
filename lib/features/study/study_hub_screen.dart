import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/memora_card.dart';
import '../../core/theme/deck_visuals.dart';
import '../../data/repositories/deck_repository.dart';
import '../dgt/dgt_ready_check_screen.dart';
import '../learn/learn_methods_screen.dart';
import '../review/feed_screen.dart';
import '../review/study_queue.dart';
import 'failed_cards_provider.dart';
import 'failed_review_screen.dart';
import 'marked_cards_provider.dart';
import 'marked_review_screen.dart';
import 'widgets/dgt_section.dart';
import 'widgets/study_mode_tile.dart';

class StudyHubScreen extends ConsumerWidget {
  const StudyHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(studyQueueProvider(null));
    final decksAsync = ref.watch(deckSummariesProvider);
    final failedCount = ref.watch(failedCardsProvider).maybeWhen(
          data: (r) => r.count,
          orElse: () => null,
        );
    final markedCount = ref.watch(markedCardsProvider).count;

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
          const DgtStudySection(),
          const SizedBox(height: 14),
          // Issue #136 (dgt-ux): entrada permanente al checklist "Listo para
          // examen?". Aditivo, no toca dgt_section.dart.
          StudyModeTile(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DgtReadyCheckScreen()),
            ),
            accentColor: const Color(0xFF4FFFB0),
            leadingIcon: Icons.fact_check_rounded,
            title: 'Listo para el examen?',
            subtitle: 'Revisa 5 criterios antes de presentarte al DGT',
          ),
          const SizedBox(height: 14),
          StudyModeTile(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FailedReviewScreen()),
            ),
            accentColor: const Color(0xFFFF6B6B),
            leadingIcon: Icons.replay_rounded,
            title: 'Repaso de falladas',
            subtitle: (failedCount ?? 0) > 0
                ? 'Refuerza las cards que fallaste recientemente'
                : 'Sin fallos recientes',
            badgeCount: failedCount,
          ),
          const SizedBox(height: 14),
          StudyModeTile(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MarkedReviewScreen()),
            ),
            accentColor: const Color(0xFFFFC857),
            leadingIcon: Icons.star_rounded,
            title: markedCount > 0
                ? 'Repasar marcadas ($markedCount)'
                : 'Repasar marcadas',
            subtitle: markedCount > 0
                ? 'Tus preguntas peligrosas para repasar pre-examen'
                : 'Marca preguntas con la estrella durante el estudio',
            badgeCount: markedCount > 0 ? markedCount : null,
            badgeTextColor: const Color(0xFF1A1A22),
          ),
          const SizedBox(height: 14),
          StudyModeTile(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LearnMethodsScreen()),
            ),
            accentColor: const Color(0xFF4FFFB0),
            leadingEmoji: '📖',
            title: 'Aprende a aprender',
            subtitle:
                'Métodos con evidencia: SRS, recall, Feynman, mnemónicas…',
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
