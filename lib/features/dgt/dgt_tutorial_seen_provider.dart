import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistencia "ya he visto el tutorial X" (issue #153 dgt-ux).
///
/// Usa SharedPreferences con un set de topic_ids (codificados como CSV
/// para evitar dependencias de packages adicionales — `setStringList` es
/// suficiente). NO mezcla con la BBDD: es estado puramente UI local y no
/// se sincroniza con backend.
///
/// API minima — solo dos operaciones:
///   - `markSeen(topicId)`: anade topicId al set (idempotente).
///   - `hasSeen(topicId)`: lee si esta en el set.
///
/// El boton "no mostrar mas" del tutorial llama a `markSeen`; el caller
/// (dgt_topics_screen) consulta `hasSeen` antes de abrir la pantalla.
///
/// Notas de diseno:
///   - Llamadas a SharedPreferences son async pero rapidas. No
///     pre-cargamos en memoria por ahora: la screen lo invoca solo en el
///     tap del topic. Si pasa a ser un hot path se puede cachear con
///     `StateNotifier`.
///   - Convencion key: prefijo `dgt_tutorial_seen_` reservado para no
///     colisionar con `dgt_hard_challenge_last` (issue #78) y
///     `dgt_answered_today` (issue #102).
class DgtTutorialSeenStore {
  /// Clave SharedPreferences donde se guarda la lista de topic_ids vistos.
  static const String prefsKey = 'dgt_tutorial_seen_topics';

  /// Lee `true` si el tutorial del topic ya se marco como visto.
  ///
  /// Devuelve `false` por defecto (incluso si la key no existe).
  Future<bool> hasSeen(String topicId) async {
    if (topicId.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(prefsKey) ?? const <String>[];
    return list.contains(topicId);
  }

  /// Marca el topic como visto. Idempotente — si ya estaba, no duplica.
  Future<void> markSeen(String topicId) async {
    if (topicId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(prefsKey) ?? const <String>[];
    if (list.contains(topicId)) return;
    await prefs.setStringList(prefsKey, [...list, topicId]);
  }

  /// Reset utilitario — usado solo en tests. NO expuesto en UI.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }
}

/// Provider del store. Riverpod 2.x — no usa NotifierProvider porque la
/// API es puramente IO y no hay estado observable (el caller consulta on
/// demand en el tap del topic).
final dgtTutorialSeenStoreProvider = Provider<DgtTutorialSeenStore>(
  (ref) => DgtTutorialSeenStore(),
);
