import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/card_repository.dart';
import '../../data/repositories/deck_repository.dart';
import '../../data/repositories/review_repository.dart';
import '../profile/character_progress.dart';
import '../quest/quest_provider.dart';
import '../stats/card_stats_provider.dart';
import '../stats/stats_repository.dart';
import 'study_queue.dart';

/// Centraliza las invalidaciones de providers despues de registrar un review.
///
/// Reemplaza los bloques duplicados (antes presentes en `feed_post_card.dart`
/// y `feed_screen.dart`) para que anadir un nuevo provider dependiente de
/// reviews requiera modificar un unico lugar.
///
/// [deckId] es opcional: si se proporciona, se invalida tambien la cola
/// de estudio especifica de ese mazo, ademas de la cola global.
void invalidateAfterReview(WidgetRef ref, {String? deckId}) {
  ref.invalidate(deckSummariesProvider);
  ref.invalidate(allCardsProvider);
  ref.invalidate(studyQueueProvider(null));
  ref.invalidate(statsSnapshotProvider);
  ref.invalidate(allCardSchedulesProvider);
  ref.invalidate(cardStatsProvider);
  ref.invalidate(characterProgressProvider);
  ref.invalidate(dailyQuestProvider);
  if (deckId != null) {
    ref.invalidate(studyQueueProvider(deckId));
  }
}

/// Invalida providers tras una operacion de cambio de tarjeta
/// (crear/editar/eliminar) que no es un review.
///
/// Es un subconjunto de [invalidateAfterReview]: solo afecta a la
/// estructura de tarjetas y schedules, sin tocar stats/progreso/quest.
void invalidateAfterCardChange(WidgetRef ref) {
  ref.invalidate(allCardsProvider);
  ref.invalidate(deckSummariesProvider);
  ref.invalidate(allCardSchedulesProvider);
}
