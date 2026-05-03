import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/memora_card.dart';
import '../../../core/theme/deck_visuals.dart';
import '../../../data/database/database.dart';
import '../../../data/repositories/card_repository.dart';
import '../../../data/repositories/deck_repository.dart';
import '../../../data/repositories/review_repository.dart';
import '../../../data/storage/image_storage.dart';
import '../../cards/card_editor_screen.dart';
import '../../profile/character_progress.dart';
import '../../review/study_queue.dart';
import '../../stats/card_stats_provider.dart';
import '../../stats/stats_repository.dart';

/// Tarjeta tipo "post de Instagram" para el feed scrollable.
class FeedPostCard extends ConsumerStatefulWidget {
  final MemoraCard card;

  const FeedPostCard({super.key, required this.card});

  @override
  ConsumerState<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends ConsumerState<FeedPostCard>
    with TickerProviderStateMixin {
  bool _revealed = false;
  bool _answered = false;
  bool? _wasCorrect;
  bool _saving = false;
  bool _bookmarked = false;
  late final AnimationController _heartBounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final AnimationController _heartOverlay = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final AnimationController _bookmarkBounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  @override
  void dispose() {
    _heartBounce.dispose();
    _heartOverlay.dispose();
    _bookmarkBounce.dispose();
    super.dispose();
  }

  void _onDoubleTapHeart() {
    if (_answered || _saving) return;
    HapticFeedback.lightImpact();
    _heartOverlay.forward(from: 0);
    _answer(true);
  }

  void _reveal() {
    if (_revealed) return;
    HapticFeedback.lightImpact();
    setState(() => _revealed = true);
  }

  void _toggleBookmark() {
    HapticFeedback.lightImpact();
    _bookmarkBounce.forward(from: 0);
    setState(() => _bookmarked = !_bookmarked);
  }

  Future<void> _share() async {
    final c = widget.card;
    final text = '${c.deck}\n\n'
        'Pregunta: ${c.front}\n\n'
        'Respuesta: ${c.back}\n\n'
        '— Memora';
    await Share.share(text, subject: c.deck);
  }

  void _showMoreMenu(BuildContext context) {
    final c = widget.card;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Editar tarjeta'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CardEditorScreen(
                      deckId: c.deckId,
                      cardToEdit: c,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFFF4F6B),
              ),
              title: const Text(
                'Eliminar tarjeta',
                style: TextStyle(color: Color(0xFFFF4F6B)),
              ),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF1A1A22),
                    title: const Text('Eliminar tarjeta'),
                    content: const Text('Esta acción no se puede deshacer.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFF4F6B),
                        ),
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref.read(cardRepositoryProvider).deleteCard(c.id);
                  ref.invalidate(allCardsProvider);
                  ref.invalidate(deckSummariesProvider);
                  ref.invalidate(allCardSchedulesProvider);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _answer(bool correct) async {
    if (_answered || _saving) return;
    HapticFeedback.mediumImpact();
    if (correct) {
      _heartBounce.forward(from: 0);
    }
    setState(() {
      _saving = true;
      _wasCorrect = correct;
    });
    await ref.read(reviewRepositoryProvider).recordReview(
          cardId: widget.card.id,
          correct: correct,
          now: DateTime.now(),
        );
    if (!mounted) return;
    ref.invalidate(deckSummariesProvider);
    ref.invalidate(allCardsProvider);
    ref.invalidate(studyQueueProvider(null));
    ref.invalidate(statsSnapshotProvider);
    ref.invalidate(allCardSchedulesProvider);
    ref.invalidate(cardStatsProvider);
    ref.invalidate(characterProgressProvider);
    setState(() {
      _answered = true;
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    final storage = ref.watch(imageStorageProvider);
    final frontImg = c.frontImagePath;
    final backImg = c.backImagePath;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: c.deckColor.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: c.deckColor.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            card: c,
            onMore: () => _showMoreMenu(context),
          ),
          GestureDetector(
            onTap: (_revealed || _answered) ? null : _reveal,
            onDoubleTap: _onDoubleTapHeart,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: child,
                    ),
                    child: !_revealed
                        ? _QuestionBlock(
                            key: const ValueKey('question'),
                            card: c,
                            frontImagePath: frontImg,
                            storage: storage,
                          )
                        : _AnswerBlock(
                            key: const ValueKey('answer'),
                            card: c,
                            backImagePath: backImg,
                            frontImagePath: frontImg,
                            storage: storage,
                          ),
                  ),
                ),
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _heartOverlay,
                    builder: (ctx, _) {
                      final t = _heartOverlay.value;
                      if (t == 0) return const SizedBox.shrink();
                      // Fase 1 (0..0.35): scale 0 -> 1.2, opacidad 0 -> 1
                      // Fase 2 (0.35..0.6): scale 1.2 -> 1.0, opacidad 1
                      // Fase 3 (0.6..1): scale 1.0 -> 0.95, opacidad 1 -> 0
                      final double scale;
                      final double opacity;
                      if (t < 0.35) {
                        final p = t / 0.35;
                        scale = Curves.easeOutBack.transform(p) * 1.2;
                        opacity = (p * 1.2).clamp(0.0, 1.0);
                      } else if (t < 0.6) {
                        scale = 1.2 - (t - 0.35) / 0.25 * 0.2;
                        opacity = 1.0;
                      } else {
                        scale = 1.0 - (t - 0.6) / 0.4 * 0.05;
                        opacity = 1.0 - (t - 0.6) / 0.4;
                      }
                      return Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: scale.clamp(0.0, 2.0),
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 110,
                            color: Colors.white.withValues(alpha: 0.92),
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 18,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          _ActionRow(
            answered: _answered,
            wasCorrect: _wasCorrect,
            bookmarked: _bookmarked,
            saving: _saving,
            heartAnim: _heartBounce,
            bookmarkAnim: _bookmarkBounce,
            onCorrect: () => _answer(true),
            onIncorrect: () => _answer(false),
            onBookmark: _toggleBookmark,
            onShare: _share,
          ),
          if (!_revealed && !_answered)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: GestureDetector(
                onTap: _reveal,
                child: Text(
                  'Ver respuesta',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          _StatsLine(cardId: widget.card.id),
          if (_answered)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _AnsweredPill(correct: _wasCorrect == true),
            )
          else
            const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _StatsLine extends ConsumerWidget {
  final String cardId;

  const _StatsLine({required this.cardId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(cardStatsProvider);
    final stats = statsAsync.maybeWhen(
      data: (m) => m[cardId],
      orElse: () => null,
    );
    if (stats == null || !stats.hasReviews) {
      return const SizedBox(height: 4);
    }
    final relTime = formatRelativeTime(stats.lastReviewMs);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Text(
        '${stats.correct} aciertos · ${stats.total} intentos · última $relTime',
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _AnsweredPill extends StatelessWidget {
  final bool correct;

  const _AnsweredPill({required this.correct});

  @override
  Widget build(BuildContext context) {
    final color =
        correct ? const Color(0xFF4FFFB0) : const Color(0xFFFF4F6B);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            correct ? 'Marcada como acertada' : 'Marcada como fallada',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final MemoraCard card;
  final VoidCallback onMore;

  const _Header({required this.card, required this.onMore});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(allCardSchedulesProvider);
    final schedule = schedulesAsync.maybeWhen(
      data: (m) => m[card.id],
      orElse: () => null,
    );
    final stateLabel = _stateLabelFor(schedule);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Row(
        children: [
          // Avatar circular con anillo gradient + icono del mazo
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  card.deckColor,
                  card.deckColor.withValues(alpha: 0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1A1A22),
              ),
              child: Center(
                child: Icon(
                  DeckVisuals.iconFor(card.deckIconName),
                  color: card.deckColor,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.deck,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  stateLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, size: 22),
            color: Colors.white.withValues(alpha: 0.7),
            onPressed: onMore,
            tooltip: 'Más',
          ),
        ],
      ),
    );
  }

  String _stateLabelFor(CardScheduleRow? s) {
    if (s == null || s.state == 'new') return 'Nueva';
    if (s.state == 'learning') return 'Aprendiendo';
    final now = DateTime.now();
    final next = DateTime.fromMillisecondsSinceEpoch(s.nextReviewDate);
    final today = DateTime(now.year, now.month, now.day);
    final nextDay = DateTime(next.year, next.month, next.day);
    final diffDays = nextDay.difference(today).inDays;
    if (diffDays <= 0) return 'Due ahora';
    if (diffDays == 1) return 'Due mañana';
    if (diffDays < 7) return 'En $diffDays días';
    final weeks = (diffDays / 7).round();
    return weeks == 1 ? 'En 1 semana' : 'En $weeks semanas';
  }
}

class _QuestionBlock extends StatelessWidget {
  final MemoraCard card;
  final String? frontImagePath;
  final ImageStorage storage;

  const _QuestionBlock({
    super.key,
    required this.card,
    required this.frontImagePath,
    required this.storage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (frontImagePath != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(storage.absolutePathFor(frontImagePath!)),
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                color: Colors.white,
              ),
              children: [
                TextSpan(
                  text: card.deck,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const TextSpan(text: '  '),
                TextSpan(text: card.front),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AnswerBlock extends StatelessWidget {
  final MemoraCard card;
  final String? frontImagePath;
  final String? backImagePath;
  final ImageStorage storage;

  const _AnswerBlock({
    super.key,
    required this.card,
    required this.frontImagePath,
    required this.backImagePath,
    required this.storage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (frontImagePath != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(storage.absolutePathFor(frontImagePath!)),
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        // Caption: deck (bold) + pregunta (color tenue)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.65),
              ),
              children: [
                TextSpan(
                  text: card.deck,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const TextSpan(text: '  '),
                TextSpan(text: card.front),
              ],
            ),
          ),
        ),
        // Imagen de respuesta si existe
        if (backImagePath != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(storage.absolutePathFor(backImagePath!)),
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        // Respuesta como párrafo destacado
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
          child: Text(
            card.back,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.45,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// Fila de acciones estilo Instagram: heart (acerté), X (fallé),
/// bookmark, share, y a la derecha el estado SRS pill cuando ya fue contestada.
class _ActionRow extends StatelessWidget {
  final bool answered;
  final bool? wasCorrect;
  final bool bookmarked;
  final bool saving;
  final AnimationController heartAnim;
  final AnimationController bookmarkAnim;
  final VoidCallback onCorrect;
  final VoidCallback onIncorrect;
  final VoidCallback onBookmark;
  final VoidCallback onShare;

  const _ActionRow({
    required this.answered,
    required this.wasCorrect,
    required this.bookmarked,
    required this.saving,
    required this.heartAnim,
    required this.bookmarkAnim,
    required this.onCorrect,
    required this.onIncorrect,
    required this.onBookmark,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final liked = answered && wasCorrect == true;
    final disliked = answered && wasCorrect == false;
    final disabled = saving;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Row(
        children: [
          // Heart (Acerté)
          ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.35).animate(
              CurvedAnimation(
                parent: heartAnim,
                curve: Curves.elasticOut,
              ),
            ),
            child: _IconAction(
              icon: liked ? Icons.favorite_rounded : Icons.favorite_outline,
              color: liked ? const Color(0xFFFF4F6B) : Colors.white,
              onTap: disabled || answered ? null : onCorrect,
              tooltip: 'Acerté',
            ),
          ),
          // X (No acerté) — estilo "broken heart" como Instagram
          _IconAction(
            icon: disliked
                ? Icons.heart_broken_rounded
                : Icons.close_rounded,
            color: disliked ? const Color(0xFFFF4F6B) : Colors.white,
            onTap: disabled || answered ? null : onIncorrect,
            tooltip: 'No acerté',
          ),
          // Share
          _IconAction(
            icon: Icons.send_rounded,
            color: Colors.white,
            onTap: onShare,
            tooltip: 'Compartir',
          ),
          const Spacer(),
          // Bookmark a la derecha (como en IG) con bounce
          ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.35).animate(
              CurvedAnimation(
                parent: bookmarkAnim,
                curve: Curves.elasticOut,
              ),
            ),
            child: _IconAction(
              icon: bookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: bookmarked ? const Color(0xFFFFD24F) : Colors.white,
              onTap: onBookmark,
              tooltip: bookmarked ? 'Quitar marcador' : 'Guardar',
            ),
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String tooltip;

  const _IconAction({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        radius: 24,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 26,
            color: onTap == null
                ? color.withValues(alpha: 0.3)
                : color.withValues(alpha: 0.92),
          ),
        ),
      ),
    );
  }
}
