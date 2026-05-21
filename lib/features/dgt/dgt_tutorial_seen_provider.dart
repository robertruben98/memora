import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue #153 (dgt-ux): persistencia local del set de `topic_id` cuyo
/// tutorial pre-quiz ya ha sido visto y silenciado por el usuario
/// (boton "No mostrar mas"). Aditivo, sin tocar tablas, sin tocar BBDD.
const String kDgtTutorialSeenPrefsKey = 'dgt.tutorial_seen_topics.v1';

/// Snapshot inmutable del set de topics cuyo tutorial fue marcado
/// como visto.
class DgtTutorialSeenState {
  final Set<String> ids;
  const DgtTutorialSeenState(this.ids);

  bool contains(String topicId) => ids.contains(_normalize(topicId));

  static String _normalize(String topicId) =>
      topicId.trim().toLowerCase().replaceAll('_', '-');

  static const empty = DgtTutorialSeenState(<String>{});
}

class DgtTutorialSeenNotifier extends StateNotifier<DgtTutorialSeenState> {
  DgtTutorialSeenNotifier() : super(DgtTutorialSeenState.empty) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(kDgtTutorialSeenPrefsKey) ?? const [];
      state = DgtTutorialSeenState(
        list.map(DgtTutorialSeenState._normalize).toSet(),
      );
    } catch (_) {
      state = DgtTutorialSeenState.empty;
    }
  }

  Future<void> _persist(Set<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(kDgtTutorialSeenPrefsKey, ids.toList());
    } catch (_) {
      // best-effort: estado in-memory ya actualizado.
    }
  }

  /// Marca el `topicId` como visto. Retorna true si se anadio,
  /// false si ya estaba presente. Idempotente.
  Future<bool> markSeen(String topicId) async {
    final normalized = DgtTutorialSeenState._normalize(topicId);
    if (normalized.isEmpty) return false;
    if (state.ids.contains(normalized)) return false;
    final next = {...state.ids, normalized};
    state = DgtTutorialSeenState(next);
    await _persist(next);
    return true;
  }

  /// Util: limpia el set entero. Pensado para "resetear tutoriales"
  /// (potencial boton futuro en ajustes; aqui solo se expone API).
  Future<void> resetAll() async {
    state = DgtTutorialSeenState.empty;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kDgtTutorialSeenPrefsKey);
    } catch (_) {
      // best-effort
    }
  }
}

final dgtTutorialSeenProvider = StateNotifierProvider<
  DgtTutorialSeenNotifier,
  DgtTutorialSeenState
>((ref) => DgtTutorialSeenNotifier());
