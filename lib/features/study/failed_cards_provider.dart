import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/memora_card.dart';
import '../../data/repositories/card_repository.dart';
import '../../data/repositories/review_repository.dart';

/// Ventana de tiempo en dias para considerar una review fallada como "reciente".
const _failedLookbackDays = 14;

/// Devuelve las cards cuya ULTIMA review en los ultimos N dias fue incorrecta.
/// Ordenadas por reviewedAt desc (mas recientes primero).
///
/// Aditivo: no toca SRS, no muta nada. Solo deriva una vista de logs locales.
class FailedCardsResult {
  final List<MemoraCard> cards;
  final int count;

  const FailedCardsResult({required this.cards, required this.count});

  static const empty = FailedCardsResult(cards: [], count: 0);
}

final failedCardsProvider =
    FutureProvider<FailedCardsResult>((ref) async {
  final reviewRepo = ref.watch(reviewRepositoryProvider);
  final cardRepo = ref.watch(cardRepositoryProvider);

  final since = DateTime.now().subtract(
    const Duration(days: _failedLookbackDays),
  );
  final logs = await reviewRepo.getLogsSince(since);
  if (logs.isEmpty) return FailedCardsResult.empty;

  // Ordenar desc por reviewedAt para procesar primero las mas recientes.
  final sorted = [...logs]
    ..sort((a, b) => b.reviewedAt.compareTo(a.reviewedAt));

  // Para cada cardId conservar SOLO el resultado mas reciente dentro del window.
  // Si ese mas reciente fue 'incorrect', la card entra en la cola.
  final latestByCard = <String, _LatestReview>{};
  for (final log in sorted) {
    final existing = latestByCard[log.cardId];
    if (existing == null || log.reviewedAt > existing.reviewedAt) {
      latestByCard[log.cardId] = _LatestReview(
        reviewedAt: log.reviewedAt,
        result: log.result,
      );
    }
  }

  final failedCardIds = latestByCard.entries
      .where((e) => e.value.result == 'incorrect')
      .toList()
    ..sort((a, b) => b.value.reviewedAt.compareTo(a.value.reviewedAt));

  if (failedCardIds.isEmpty) return FailedCardsResult.empty;

  // Materializar a MemoraCard preservando orden por reviewedAt desc.
  final allCards = await cardRepo.getAllCards();
  final byId = {for (final c in allCards) c.id: c};

  final result = <MemoraCard>[];
  for (final entry in failedCardIds) {
    final card = byId[entry.key];
    if (card != null) result.add(card);
  }

  return FailedCardsResult(cards: result, count: result.length);
});

class _LatestReview {
  final int reviewedAt;
  final String result;
  const _LatestReview({required this.reviewedAt, required this.result});
}
