import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/dgt_repository.dart';

/// Issue #95 (dgt-content): tracking local de preguntas DGT falladas en los
/// ultimos N dias para el modo "Repaso de fallos".
///
/// Backend NO expone endpoint `/study/failures` todavia; este repo persiste
/// fallos en SharedPreferences (key fechada por questionId) y filtra por
/// ventana temporal en el cliente. Solo guarda el ULTIMO fallo por
/// pregunta (re-fallar refresca timestamp -> queda en ventana 7d).
///
/// Datos minimos para reconstruir la pregunta en el quiz: snapshot completo
/// de [DgtQuestion] al momento del fallo (los enunciados no cambian seguido).
class DgtFailureEntry {
  final DgtQuestion question;
  final DateTime failedAt;

  DgtFailureEntry({required this.question, required this.failedAt});

  Map<String, dynamic> toJson() => {
        'q': {
          'id': question.id,
          'statement': question.statement,
          'image_url': question.imageUrl,
          'option_a': question.optionA,
          'option_b': question.optionB,
          'option_c': question.optionC,
          'correct': question.correct,
          'explanation': question.explanation,
          'topic': question.topic,
        },
        'failed_at_ms': failedAt.millisecondsSinceEpoch,
      };

  static DgtFailureEntry? tryFromJson(Map<String, dynamic> j) {
    try {
      final q = j['q'] as Map<String, dynamic>;
      final ts = j['failed_at_ms'] as int;
      return DgtFailureEntry(
        question: DgtQuestion.fromJson(q),
        failedAt: DateTime.fromMillisecondsSinceEpoch(ts),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Repositorio de fallos. Filtra por ventana de [windowDays] dias (default 7).
class DgtFailuresRepository {
  static const String _key = 'dgt.failures.v1';
  static const int windowDays = 7;

  final Future<SharedPreferences> Function() _prefsLoader;

  DgtFailuresRepository({
    Future<SharedPreferences> Function()? prefsLoader,
  }) : _prefsLoader = prefsLoader ?? SharedPreferences.getInstance;

  /// Devuelve TODOS los fallos persistidos (sin filtrar por ventana).
  Future<List<DgtFailureEntry>> _readAll() async {
    final prefs = await _prefsLoader();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final out = <DgtFailureEntry>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          final entry = DgtFailureEntry.tryFromJson(e);
          if (entry != null) out.add(entry);
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeAll(List<DgtFailureEntry> entries) async {
    final prefs = await _prefsLoader();
    final list = entries.map((e) => e.toJson()).toList();
    await prefs.setString(_key, jsonEncode(list));
  }

  /// Registra un fallo. Si la pregunta ya estaba marcada, refresca timestamp.
  Future<void> recordFailure(DgtQuestion question) async {
    final all = await _readAll();
    all.removeWhere((e) => e.question.id == question.id);
    all.add(DgtFailureEntry(question: question, failedAt: DateTime.now()));
    await _writeAll(all);
  }

  /// Registra varios fallos (caso resultado de simulacro). Idempotente.
  Future<void> recordFailures(Iterable<DgtQuestion> questions) async {
    final all = await _readAll();
    final ids = questions.map((q) => q.id).toSet();
    all.removeWhere((e) => ids.contains(e.question.id));
    final now = DateTime.now();
    for (final q in questions) {
      all.add(DgtFailureEntry(question: q, failedAt: now));
    }
    await _writeAll(all);
  }

  /// Marca una pregunta como acertada (la saca de la queue de fallos).
  Future<void> markResolved(String questionId) async {
    final all = await _readAll();
    final before = all.length;
    all.removeWhere((e) => e.question.id == questionId);
    if (all.length != before) await _writeAll(all);
  }

  /// Devuelve fallos dentro de la ventana de 7 dias, mas reciente primero.
  /// Limpia automaticamente entries fuera de ventana al leerlas.
  Future<List<DgtFailureEntry>> recentFailures() async {
    final all = await _readAll();
    final cutoff = DateTime.now().subtract(const Duration(days: windowDays));
    final inWindow = all.where((e) => e.failedAt.isAfter(cutoff)).toList()
      ..sort((a, b) => b.failedAt.compareTo(a.failedAt));
    // GC: si habia entries fuera de ventana, persistir limpieza.
    if (inWindow.length != all.length) {
      await _writeAll(inWindow);
    }
    return inWindow;
  }

  Future<int> recentCount() async {
    final r = await recentFailures();
    return r.length;
  }
}

final dgtFailuresRepositoryProvider =
    Provider<DgtFailuresRepository>((ref) => DgtFailuresRepository());

/// Provider del count de fallos recientes. Invalidate post-quiz para refresh.
final dgtRecentFailuresCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(dgtFailuresRepositoryProvider);
  return repo.recentCount();
});

/// Provider de la lista completa de fallos recientes (snapshot de preguntas).
final dgtRecentFailuresProvider =
    FutureProvider<List<DgtFailureEntry>>((ref) async {
  final repo = ref.watch(dgtFailuresRepositoryProvider);
  return repo.recentFailures();
});
