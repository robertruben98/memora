import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/memora_card.dart';
import '../profile/character_progress.dart';
import '../profile/level_up_overlay.dart';
import '../profile/title_unlock_overlay.dart';

/// Helper testeable que detecta level-up + title-up de mazo despues
/// de un review y dispara los overlays correspondientes.
///
/// Centraliza la logica duplicada entre `FeedPostCard` (browse feed)
/// y `feed_screen.dart` (sesion de revision continua).
class ReviewCompletionHandler {
  ReviewCompletionHandler(this.ref);

  final WidgetRef ref;

  /// Captura el progreso ANTES del review. Devuelve null si todavia
  /// no esta disponible (en cuyo caso se debe omitir la deteccion).
  CharacterProgress? snapshotBefore() {
    return ref
        .read(characterProgressProvider)
        .maybeWhen(data: (p) => p, orElse: () => null);
  }

  /// Despues de [recordReview], compara progreso y muestra overlays.
  ///
  /// [isMounted] se evalua antes de cada uso de [context] para evitar
  /// usos asincronos del BuildContext.
  Future<void> handleAfter({
    required BuildContext context,
    required CharacterProgress? beforeProgress,
    required MemoraCard card,
    required bool Function() isMounted,
  }) async {
    if (beforeProgress == null) return;
    try {
      final after = await ref.read(characterProgressProvider.future);
      if (!isMounted()) return;

      final beforeDeck = beforeProgress.decks.firstWhere(
        (d) => d.deckId == card.deckId,
        orElse: () => DeckProgress(
          deckId: card.deckId,
          name: card.deck,
          iconName: card.deckIconName,
          colorHex: '',
          reviews: 0,
          correct: 0,
          level: 1,
          rank: DeckRank.none,
        ),
      );
      final afterDeck = after.decks.firstWhere(
        (d) => d.deckId == card.deckId,
        orElse: () => beforeDeck,
      );

      if (afterDeck.rank.index > beforeDeck.rank.index) {
        if (!isMounted()) return;
        TitleUnlockOverlay.show(
          // ignore: use_build_context_synchronously
          context,
          deckName: afterDeck.name,
          newRank: afterDeck.rank,
          accent: card.deckColor,
        );
        await Future.delayed(const Duration(milliseconds: 2900));
        if (!isMounted()) return;
      }

      if (after.level > beforeProgress.level) {
        if (!isMounted()) return;
        LevelUpOverlay.show(
          // ignore: use_build_context_synchronously
          context,
          newLevel: after.level,
          title: after.title != beforeProgress.title ? after.title : null,
        );
      }
    } catch (_) {
      // Silently ignore: overlays are best-effort.
    }
  }
}
