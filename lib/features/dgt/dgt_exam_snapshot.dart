import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/dgt_repository.dart';

/// Issue #133 (dgt-ux): persistencia del estado de un simulacro DGT en curso
/// para poder reanudarlo tras cerrar la app o salir del simulacro.
///
/// Diseno:
/// - Snapshot completo de las [DgtQuestion] tal cual estaban en pantalla (no
///   solo IDs) porque el banco se sirve via `/dgt/questions` con orden y subset
///   aleatorio: si reintentamos fetch al reanudar, las preguntas no coincidiran.
///   Persistir los enunciados garantiza identidad exacta a costa de ~ pocos KB.
/// - `secondsRemaining` se persiste tal cual: al reanudar el countdown se
///   reactiva desde ese valor (no se recalcula con startedAt para no penalizar
///   al usuario por el tiempo que la app estuvo cerrada).
/// - Clave SharedPreferences: `dgt.exam_in_progress.v1`. Se borra al
///   completar/timeout/descartar.
///
/// Aditivo: no toca el modo estricto ni el flow base; el snapshot solo se
/// usa en modo no-estricto (en estricto el usuario eligio condiciones reales
/// y no debe poder pausar saliendo de la app).
const String kDgtExamSnapshotKey = 'dgt.exam_in_progress.v1';

/// Snapshot serializable del estado de un simulacro DGT activo.
class DgtExamSnapshot {
  final List<DgtQuestion> questions;

  /// Mapa indice de pregunta -> letra elegida ('a'|'b'|'c').
  final Map<int, String> answers;

  /// Indices marcados con flag (en modo no-estricto).
  final Set<int> flagged;

  /// Indice (0-based) de la pregunta actual.
  final int currentIndex;

  /// Segundos restantes del timer (0..30*60).
  final int secondsRemaining;

  /// Instante en que se inicio el simulacro (sirve para el dialogo "X/30
  /// llevas, quedan Y min Z s" y como dato auditable).
  final DateTime startedAt;

  const DgtExamSnapshot({
    required this.questions,
    required this.answers,
    required this.flagged,
    required this.currentIndex,
    required this.secondsRemaining,
    required this.startedAt,
  });

  /// Numero de preguntas respondidas hasta el momento.
  int get answeredCount => answers.length;

  /// Total de preguntas (defensivo, normalmente 30).
  int get totalCount => questions.length;

  Map<String, dynamic> toJson() => {
        'questions': questions.map(_questionToJson).toList(),
        'answers': answers.map((k, v) => MapEntry(k.toString(), v)),
        'flagged': flagged.toList()..sort(),
        'currentIndex': currentIndex,
        'secondsRemaining': secondsRemaining,
        'startedAt': startedAt.toIso8601String(),
      };

  static DgtExamSnapshot? tryFromJson(Map<String, dynamic> j) {
    try {
      final rawQs = j['questions'] as List<dynamic>;
      final qs = <DgtQuestion>[];
      for (final e in rawQs) {
        if (e is Map<String, dynamic>) {
          qs.add(DgtQuestion.fromJson(e));
        }
      }
      final rawAns = (j['answers'] as Map<String, dynamic>?) ?? const {};
      final ans = <int, String>{};
      rawAns.forEach((k, v) {
        final idx = int.tryParse(k);
        if (idx != null && v is String) ans[idx] = v;
      });
      final rawFlag = (j['flagged'] as List<dynamic>?) ?? const [];
      final flag = <int>{};
      for (final e in rawFlag) {
        if (e is int) flag.add(e);
      }
      final current = (j['currentIndex'] as int?) ?? 0;
      final secs = (j['secondsRemaining'] as int?) ?? 0;
      final startedRaw = j['startedAt'] as String?;
      final started = startedRaw != null
          ? (DateTime.tryParse(startedRaw) ?? DateTime.now())
          : DateTime.now();
      if (qs.isEmpty) return null;
      return DgtExamSnapshot(
        questions: qs,
        answers: ans,
        flagged: flag,
        currentIndex: current.clamp(0, qs.length - 1),
        secondsRemaining: secs < 0 ? 0 : secs,
        startedAt: started,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _questionToJson(DgtQuestion q) => {
        'id': q.id,
        'statement': q.statement,
        'image_url': q.imageUrl,
        'option_a': q.optionA,
        'option_b': q.optionB,
        'option_c': q.optionC,
        'correct': q.correct,
        'explanation': q.explanation,
        'topic': q.topic,
      };
}

/// Repositorio de persistencia del snapshot. Usa SharedPreferences via
/// loader inyectable para tests.
class DgtExamSnapshotRepository {
  final Future<SharedPreferences> Function() _prefsLoader;

  DgtExamSnapshotRepository({
    Future<SharedPreferences> Function()? prefsLoader,
  }) : _prefsLoader = prefsLoader ?? SharedPreferences.getInstance;

  /// Guarda (o sobreescribe) el snapshot actual. Best-effort: si falla
  /// SharedPreferences silenciamos para no romper el simulacro en curso.
  Future<void> save(DgtExamSnapshot snapshot) async {
    try {
      final prefs = await _prefsLoader();
      await prefs.setString(
        kDgtExamSnapshotKey,
        jsonEncode(snapshot.toJson()),
      );
    } catch (_) {
      // ignore: best-effort
    }
  }

  /// Lee el snapshot persistido o `null` si no hay o esta corrupto.
  Future<DgtExamSnapshot?> read() async {
    try {
      final prefs = await _prefsLoader();
      final raw = prefs.getString(kDgtExamSnapshotKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return DgtExamSnapshot.tryFromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Borra el snapshot. Llamado al completar/timeout/descartar.
  Future<void> clear() async {
    try {
      final prefs = await _prefsLoader();
      await prefs.remove(kDgtExamSnapshotKey);
    } catch (_) {
      // ignore: best-effort
    }
  }

  /// Atajo: indica si hay snapshot pendiente (lectura ligera + best-effort).
  Future<bool> hasPending() async {
    final snap = await read();
    return snap != null && snap.questions.isNotEmpty;
  }
}

final dgtExamSnapshotRepositoryProvider =
    Provider<DgtExamSnapshotRepository>(
  (ref) => DgtExamSnapshotRepository(),
);

/// Provider futuro del snapshot actual (si existe). Sirve para que el home
/// o el hub de estudio decidan si mostrar el dialogo "Reanudar".
final dgtExamPendingSnapshotProvider =
    FutureProvider<DgtExamSnapshot?>((ref) async {
  final repo = ref.watch(dgtExamSnapshotRepositoryProvider);
  return repo.read();
});
