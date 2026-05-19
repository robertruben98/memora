import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clave SharedPreferences donde se persiste el set local de IDs de preguntas
/// DGT marcadas como favoritas por el usuario (issue #88).
///
/// Aditivo y local: no toca backend, no toca SRS de cards memora ni el set
/// [`kMarkedCardsPrefsKey`] del feature study/. Esto es exclusivo del banco
/// DGT (DgtQuestion.id) para que el usuario construya una lista personal de
/// preguntas a repasar antes del examen teorico.
const String kDgtFavoritesPrefsKey = 'dgt.favorite_question_ids.v1';

/// Estado in-memory del set de preguntas DGT favoritas.
class DgtFavoritesState {
  final Set<String> ids;
  const DgtFavoritesState(this.ids);

  bool contains(String id) => ids.contains(id);
  int get count => ids.length;

  static const empty = DgtFavoritesState(<String>{});
}

class DgtFavoritesNotifier extends StateNotifier<DgtFavoritesState> {
  DgtFavoritesNotifier() : super(DgtFavoritesState.empty) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(kDgtFavoritesPrefsKey) ?? const [];
      state = DgtFavoritesState(list.toSet());
    } catch (_) {
      // Best-effort: si falla storage, dejamos el set vacio para no romper UI.
      state = DgtFavoritesState.empty;
    }
  }

  Future<void> _persist(Set<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(kDgtFavoritesPrefsKey, ids.toList());
    } catch (_) {
      // El estado in-memory queda actualizado aunque persistencia falle.
    }
  }

  /// Toggle. Retorna true si quedo marcada (added), false si quedo desmarcada.
  Future<bool> toggle(String questionId) async {
    if (questionId.isEmpty) return false;
    final next = {...state.ids};
    final wasIn = next.contains(questionId);
    if (wasIn) {
      next.remove(questionId);
    } else {
      next.add(questionId);
    }
    state = DgtFavoritesState(next);
    await _persist(next);
    return !wasIn;
  }
}

final dgtFavoritesProvider =
    StateNotifierProvider<DgtFavoritesNotifier, DgtFavoritesState>(
  (ref) => DgtFavoritesNotifier(),
);
