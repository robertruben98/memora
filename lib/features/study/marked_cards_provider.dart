import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/memora_card.dart';
import '../../data/repositories/card_repository.dart';

/// Clave en SharedPreferences donde se persiste el set local de cards marcadas.
/// Aditivo: no toca tablas existentes ni el SRS. Solo guarda IDs locales para
/// que el usuario construya su lista personal de "preguntas peligrosas" DGT.
const String kMarkedCardsPrefsKey = 'dgt.marked_card_ids.v1';

/// Estado del set de cards marcadas (favoritos para repasar antes del examen).
class MarkedCardsState {
  final Set<String> ids;
  const MarkedCardsState(this.ids);

  bool contains(String id) => ids.contains(id);
  int get count => ids.length;

  static const empty = MarkedCardsState(<String>{});
}

class MarkedCardsNotifier extends StateNotifier<MarkedCardsState> {
  MarkedCardsNotifier() : super(MarkedCardsState.empty) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(kMarkedCardsPrefsKey) ?? const [];
      state = MarkedCardsState(list.toSet());
    } catch (_) {
      // En caso de error de storage mantener estado vacio (no romper la UI).
      state = MarkedCardsState.empty;
    }
  }

  Future<void> _persist(Set<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(kMarkedCardsPrefsKey, ids.toList());
    } catch (_) {
      // Persist best-effort: si falla, el estado in-memory ya esta actualizado.
    }
  }

  /// Marca la card como favorita. Retorna true si se agrego, false si ya estaba.
  Future<bool> mark(String cardId) async {
    if (state.ids.contains(cardId)) return false;
    final next = {...state.ids, cardId};
    state = MarkedCardsState(next);
    await _persist(next);
    return true;
  }

  /// Quita la card de favoritas. Retorna true si se quito, false si no estaba.
  Future<bool> unmark(String cardId) async {
    if (!state.ids.contains(cardId)) return false;
    final next = {...state.ids}..remove(cardId);
    state = MarkedCardsState(next);
    await _persist(next);
    return true;
  }

  /// Toggle. Retorna true si quedo marcada (added), false si quedo desmarcada.
  Future<bool> toggle(String cardId) async {
    if (state.ids.contains(cardId)) {
      await unmark(cardId);
      return false;
    }
    await mark(cardId);
    return true;
  }
}

final markedCardsProvider =
    StateNotifierProvider<MarkedCardsNotifier, MarkedCardsState>(
  (ref) => MarkedCardsNotifier(),
);

/// Resultado de resolver IDs marcados a MemoraCard concretas.
class MarkedCardsResolved {
  final List<MemoraCard> cards;
  final int count;
  const MarkedCardsResolved({required this.cards, required this.count});

  static const empty = MarkedCardsResolved(cards: [], count: 0);
}

/// Provider derivado que materializa MarkedCardsState a lista de MemoraCard.
/// Filtra IDs que ya no existen (card eliminada).
final markedCardsResolvedProvider =
    FutureProvider<MarkedCardsResolved>((ref) async {
  final marked = ref.watch(markedCardsProvider);
  if (marked.ids.isEmpty) return MarkedCardsResolved.empty;

  final repo = ref.watch(cardRepositoryProvider);
  final all = await repo.getAllCards();
  final byId = {for (final c in all) c.id: c};

  final cards = <MemoraCard>[];
  for (final id in marked.ids) {
    final c = byId[id];
    if (c != null) cards.add(c);
  }

  return MarkedCardsResolved(cards: cards, count: cards.length);
});
