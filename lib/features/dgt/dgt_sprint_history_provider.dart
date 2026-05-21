import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue #152 (dgt-ux): historial local del modo "Sprint diario".
///
/// Persiste los ultimos sprints completados (sin tocar backend ni el historial
/// de simulacros DGT). Cada entrada guarda timestamp, total preguntas,
/// aciertos y segundos usados. Aditivo y local.
///
/// Clave SharedPreferences. v1 para permitir migraciones futuras si el shape
/// del JSON cambia (igual que [`kDgtFavoritesPrefsKey`]).
const String kDgtSprintHistoryPrefsKey = 'dgt.sprint_history.v1';

/// Maximo de entradas guardadas. Se mantiene una ventana corta para que la
/// lectura desde SharedPreferences sea O(1) y la UI del histograma no necesite
/// paginacion.
const int kDgtSprintHistoryMax = 30;

/// Numero de barras visibles en el histograma de la pantalla de resultado.
const int kDgtSprintHistogramWindow = 14;

/// Duracion del sprint en segundos.
const int kDgtSprintDurationSeconds = 120;

/// Cantidad fija de preguntas por sprint.
const int kDgtSprintQuestionCount = 10;

/// Umbral de aciertos para considerar el sprint "aprobado". Se elige 7/10
/// como equivalente a la regla DGT del simulacro (max 3 fallos en 30
/// preguntas, escalado a 10).
const int kDgtSprintPassThreshold = 7;

/// Entrada del historial.
class DgtSprintEntry {
  /// Fecha (UTC) en la que se completo el sprint.
  final DateTime timestamp;

  /// Total de preguntas (siempre [kDgtSprintQuestionCount] en v1 pero se
  /// guarda para permitir variantes futuras sin migracion).
  final int total;

  /// Aciertos.
  final int correct;

  /// Segundos usados (entre 0 y [kDgtSprintDurationSeconds]).
  final int secondsUsed;

  const DgtSprintEntry({
    required this.timestamp,
    required this.total,
    required this.correct,
    required this.secondsUsed,
  });

  bool get passed => correct >= kDgtSprintPassThreshold;

  Map<String, dynamic> toJson() => {
        'ts': timestamp.toUtc().toIso8601String(),
        'total': total,
        'correct': correct,
        'seconds_used': secondsUsed,
      };

  static DgtSprintEntry? fromJson(Map<String, dynamic> j) {
    try {
      final ts = DateTime.parse((j['ts'] ?? '').toString());
      final total = (j['total'] as num?)?.toInt() ?? 0;
      final correct = (j['correct'] as num?)?.toInt() ?? 0;
      final secs = (j['seconds_used'] as num?)?.toInt() ?? 0;
      if (total <= 0) return null;
      return DgtSprintEntry(
        timestamp: ts,
        total: total,
        correct: correct,
        secondsUsed: secs,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Estado in-memory del historial. Ordenado de mas reciente a mas antiguo.
class DgtSprintHistoryState {
  final List<DgtSprintEntry> entries;
  const DgtSprintHistoryState(this.entries);

  static const empty = DgtSprintHistoryState(<DgtSprintEntry>[]);

  /// Sprint completado en la fecha local de [now], si existe. Permite a la
  /// UI mostrar "ya hiciste el sprint de hoy" en lugar de empezar uno nuevo.
  DgtSprintEntry? todayEntry({DateTime? now}) {
    final ref = (now ?? DateTime.now()).toLocal();
    for (final e in entries) {
      final local = e.timestamp.toLocal();
      if (local.year == ref.year &&
          local.month == ref.month &&
          local.day == ref.day) {
        return e;
      }
    }
    return null;
  }

  /// Media de aciertos. Devuelve 0 si no hay entradas.
  double get averageCorrect {
    if (entries.isEmpty) return 0;
    var sum = 0;
    for (final e in entries) {
      sum += e.correct;
    }
    return sum / entries.length;
  }
}

/// Notifier que carga / persiste / agrega entradas al historial.
class DgtSprintHistoryNotifier extends StateNotifier<DgtSprintHistoryState> {
  DgtSprintHistoryNotifier() : super(DgtSprintHistoryState.empty) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kDgtSprintHistoryPrefsKey);
      if (raw == null || raw.isEmpty) {
        state = DgtSprintHistoryState.empty;
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        state = DgtSprintHistoryState.empty;
        return;
      }
      final parsed = <DgtSprintEntry>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final entry = DgtSprintEntry.fromJson(item);
          if (entry != null) parsed.add(entry);
        }
      }
      parsed.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      state = DgtSprintHistoryState(parsed);
    } catch (_) {
      state = DgtSprintHistoryState.empty;
    }
  }

  Future<void> _persist(List<DgtSprintEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
      await prefs.setString(kDgtSprintHistoryPrefsKey, encoded);
    } catch (_) {
      // Estado in-memory queda actualizado aunque persistencia falle.
    }
  }

  /// Agrega una entrada nueva. Si ya existe un sprint en el mismo dia local,
  /// **no** se agrega (regla 1 sprint por dia, criterio aceptacion del issue).
  /// Retorna `true` si se guardo, `false` si se descarto por duplicado diario.
  Future<bool> record(DgtSprintEntry entry) async {
    if (state.todayEntry(now: entry.timestamp) != null) {
      return false;
    }
    final next = <DgtSprintEntry>[entry, ...state.entries];
    if (next.length > kDgtSprintHistoryMax) {
      next.removeRange(kDgtSprintHistoryMax, next.length);
    }
    state = DgtSprintHistoryState(next);
    await _persist(next);
    return true;
  }
}

final dgtSprintHistoryProvider = StateNotifierProvider<
    DgtSprintHistoryNotifier, DgtSprintHistoryState>(
  (ref) => DgtSprintHistoryNotifier(),
);
