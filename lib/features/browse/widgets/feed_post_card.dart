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
import '../../review/study_queue.dart';
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

  @override
  void dispose() {
    _heartBounce.dispose();
    super.dispose();
  }

  void _reveal() {
    if (_revealed) return;
    HapticFeedback.lightImpact();
    setState(() => _revealed = true);
  }

  void _toggleBookmark() {
    HapticFeedback.lightImpact();
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: c.deckColor.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            card: c,
            onMore: () => _showMoreMenu(context),
          ),
          if (!_revealed)
            _QuestionBlock(card: c, frontImagePath: frontImg, storage: storage)
          else
            _AnswerBlock(
              card: c,
              backImagePath: backImg,
              frontImagePath: frontImg,
              storage: storage,
            ),
          _ActionRow(
            answered: _answered,
            wasCorrect: _wasCorrect,
            bookmarked: _bookmarked,
            saving: _saving,
            heartAnim: _heartBounce,
            onCorrect: () => _answer(true),
            onIncorrect: () => _answer(false),
            onBookmark: _toggleBookmark,
            onShare: _share,
          ),
          if (!_revealed && !_answered)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: GestureDetector(
                onTap: _reveal,
                child: Text(
                  'Ver respuesta',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 6),
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
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
          child: Text(
            card.front,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.35,
              letterSpacing: -0.2,
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
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
          child: Text(
            card.front,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 10),
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        if (backImagePath != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
          child: Text(
            card.back,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              height: 1.45,
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
          // Bookmark a la derecha (como en IG)
          _IconAction(
            icon: bookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            color: bookmarked ? const Color(0xFFFFD24F) : Colors.white,
            onTap: onBookmark,
            tooltip: bookmarked ? 'Quitar marcador' : 'Guardar',
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
