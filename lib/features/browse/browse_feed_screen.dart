import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/memora_card.dart';
import '../../core/theme/deck_visuals.dart';
import '../../data/repositories/card_repository.dart';
import '../../data/repositories/deck_repository.dart';
import 'widgets/feed_post_card.dart';

class BrowseFeedScreen extends ConsumerStatefulWidget {
  const BrowseFeedScreen({super.key});

  @override
  ConsumerState<BrowseFeedScreen> createState() => _BrowseFeedScreenState();
}

class _BrowseFeedScreenState extends ConsumerState<BrowseFeedScreen> {
  String? _selectedDeckId; // null = todos

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(allCardsProvider);
    final decksAsync = ref.watch(deckSummariesProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Feed',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refrescar',
            onPressed: () {
              ref.invalidate(allCardsProvider);
              ref.invalidate(deckSummariesProvider);
            },
          ),
        ],
      ),
      body: cardsAsync.when(
        loading: () => const _SkeletonFeed(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (cards) {
          final filtered = _selectedDeckId == null
              ? cards
              : cards.where((c) => c.deckId == _selectedDeckId).toList();
          return RefreshIndicator(
            color: const Color(0xFF7C5CFF),
            backgroundColor: const Color(0xFF1A1A22),
            onRefresh: () async {
              ref.invalidate(allCardsProvider);
              ref.invalidate(deckSummariesProvider);
              await ref.read(allCardsProvider.future);
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _StoriesRibbon(
                    decks: decksAsync.maybeWhen(
                      data: (d) => d,
                      orElse: () => const [],
                    ),
                    selectedDeckId: _selectedDeckId,
                    onSelect: (id) =>
                        setState(() => _selectedDeckId = id),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _emptyState(),
                  )
                else
                  SliverList.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => FeedPostCard(
                      key: ValueKey(filtered[i].id),
                      card: filtered[i],
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dynamic_feed_rounded,
            size: 48,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedDeckId == null
                ? 'No hay tarjetas todavía'
                : 'Este mazo está vacío',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoriesRibbon extends StatelessWidget {
  final List<DeckSummary> decks;
  final String? selectedDeckId;
  final ValueChanged<String?> onSelect;

  const _StoriesRibbon({
    required this.decks,
    required this.selectedDeckId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (decks.isEmpty) {
      return const SizedBox(height: 8);
    }
    return Container(
      height: 100,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _StoryCircle(
            label: 'Todos',
            color: const Color(0xFF7C5CFF),
            iconName: 'dynamic_feed_rounded',
            isAllAccent: true,
            selected: selectedDeckId == null,
            onTap: () => onSelect(null),
          ),
          for (final d in decks)
            _StoryCircle(
              label: d.name,
              color: d.color,
              iconName: d.iconName,
              selected: selectedDeckId == d.id,
              onTap: () => onSelect(d.id),
            ),
        ],
      ),
    );
  }
}

class _StoryCircle extends StatelessWidget {
  final String label;
  final Color color;
  final String iconName;
  final bool selected;
  final bool isAllAccent;
  final VoidCallback onTap;

  const _StoryCircle({
    required this.label,
    required this.color,
    required this.iconName,
    required this.selected,
    required this.onTap,
    this.isAllAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            AnimatedScale(
              scale: selected ? 1.06 : 1.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selected
                      ? LinearGradient(
                          colors: isAllAccent
                              ? const [
                                  Color(0xFFE04FFF),
                                  Color(0xFF7C5CFF),
                                  Color(0xFF4F8AFF),
                                ]
                              : [
                                  color,
                                  color.withValues(alpha: 0.4),
                                  color,
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: selected ? null : Colors.transparent,
                  border: selected
                      ? null
                      : Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 1.5,
                        ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: (isAllAccent
                                    ? const Color(0xFF7C5CFF)
                                    : color)
                                .withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1A1A22),
                    border: Border.all(
                      color: const Color(0xFF0E0E12),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      DeckVisuals.iconFor(iconName),
                      color: color,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 70,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.65),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loader: 3 cards placeholder con shimmer ligero (AnimatedOpacity).
class _SkeletonFeed extends StatefulWidget {
  const _SkeletonFeed();

  @override
  State<_SkeletonFeed> createState() => _SkeletonFeedState();
}

class _SkeletonFeedState extends State<_SkeletonFeed>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      children: [
        const _SkeletonRibbon(),
        for (var i = 0; i < 3; i++) _SkeletonCard(shimmer: _shimmer),
      ],
    );
  }
}

class _SkeletonRibbon extends StatelessWidget {
  const _SkeletonRibbon();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 50,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(4),
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

class _SkeletonCard extends StatelessWidget {
  final AnimationController shimmer;
  const _SkeletonCard({required this.shimmer});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, _) {
        final opacity = 0.04 + 0.06 * shimmer.value;
        Widget bar({double w = double.infinity, double h = 12}) => Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: opacity),
                borderRadius: BorderRadius.circular(6),
              ),
            );
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A22),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: opacity),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(w: 120, h: 12),
                        const SizedBox(height: 6),
                        bar(w: 70, h: 9),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 12),
              bar(h: 14),
              const SizedBox(height: 8),
              bar(w: 220, h: 14),
            ],
          ),
        );
      },
    );
  }
}
