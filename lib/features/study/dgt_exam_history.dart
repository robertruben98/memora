import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clave SharedPreferences donde se persiste el historial de simulacros DGT.
/// Aditivo: no toca el SRS ni el backend. Solo guarda lista local capada a 50
/// entradas. Permite al estudiante ver evolucion (score, fecha, veredicto)
/// sin depender de sincronizacion con servidor.
const String kDgtExamHistoryPrefsKey = 'dgt.exam_history.v1';

/// Maximo de entradas que se conservan (FIFO).
const int kDgtExamHistoryMaxEntries = 50;

/// Una entrada del historial: un simulacro completado.
class DgtExamHistoryEntry {
  /// Momento en que se completo el simulacro.
  final DateTime date;

  /// Respuestas correctas.
  final int correct;

  /// Total de preguntas del simulacro (tipicamente 30).
  final int total;

  /// Duracion usada (puede ser <= limite si termino antes).
  final Duration timeUsed;

  /// Veredicto del estudiante: aprobado segun criterio DGT (max 3 fallos).
  final bool passed;

  const DgtExamHistoryEntry({
    required this.date,
    required this.correct,
    required this.total,
    required this.timeUsed,
    required this.passed,
  });

  /// Score formateado como "27/30".
  String get scoreLabel => '$correct/$total';

  /// Tiempo formateado mm:ss.
  String get timeLabel {
    final m = timeUsed.inMinutes.toString().padLeft(2, '0');
    final s = (timeUsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date.toIso8601String(),
        'correct': correct,
        'total': total,
        'time_used_seconds': timeUsed.inSeconds,
        'passed': passed,
      };

  static DgtExamHistoryEntry? fromJson(Map<String, dynamic> json) {
    try {
      final rawDate = json['date'];
      final rawCorrect = json['correct'];
      final rawTotal = json['total'];
      final rawSeconds = json['time_used_seconds'];
      final rawPassed = json['passed'];
      if (rawDate is! String ||
          rawCorrect is! int ||
          rawTotal is! int ||
          rawSeconds is! int ||
          rawPassed is! bool) {
        return null;
      }
      final date = DateTime.tryParse(rawDate);
      if (date == null) return null;
      if (rawTotal <= 0 || rawCorrect < 0 || rawCorrect > rawTotal) {
        return null;
      }
      return DgtExamHistoryEntry(
        date: date,
        correct: rawCorrect,
        total: rawTotal,
        timeUsed: Duration(seconds: rawSeconds.clamp(0, 24 * 60 * 60)),
        passed: rawPassed,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Resumen agregado del historial: total, % aprobados, mejor score.
class DgtExamHistorySummary {
  final int totalExams;
  final int passedExams;
  final int? bestCorrect;
  final int? bestTotal;

  const DgtExamHistorySummary({
    required this.totalExams,
    required this.passedExams,
    required this.bestCorrect,
    required this.bestTotal,
  });

  static const empty = DgtExamHistorySummary(
    totalExams: 0,
    passedExams: 0,
    bestCorrect: null,
    bestTotal: null,
  );

  /// Porcentaje aprobados [0..100]. 0 si no hay simulacros.
  int get passedPercent {
    if (totalExams == 0) return 0;
    return ((passedExams / totalExams) * 100).round();
  }

  /// "27/30" o null si no hay datos.
  String? get bestScoreLabel {
    final c = bestCorrect;
    final t = bestTotal;
    if (c == null || t == null) return null;
    return '$c/$t';
  }
}

/// Repositorio local con SharedPreferences. Best-effort: si falla el storage
/// se cae a estado vacio sin romper la UI.
class DgtExamHistoryRepository {
  /// Carga el historial ordenado del mas reciente al mas antiguo.
  Future<List<DgtExamHistoryEntry>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kDgtExamHistoryPrefsKey);
      if (raw == null || raw.isEmpty) return const <DgtExamHistoryEntry>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <DgtExamHistoryEntry>[];
      final entries = <DgtExamHistoryEntry>[];
      for (final item in decoded) {
        if (item is Map) {
          final entry = DgtExamHistoryEntry.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (entry != null) entries.add(entry);
        }
      }
      entries.sort((a, b) => b.date.compareTo(a.date));
      return entries;
    } catch (_) {
      return const <DgtExamHistoryEntry>[];
    }
  }

  /// Agrega una entrada nueva al principio. Capa a [kDgtExamHistoryMaxEntries].
  /// Retorna la lista resultante para que el caller pueda refrescar UI.
  Future<List<DgtExamHistoryEntry>> append(DgtExamHistoryEntry entry) async {
    final current = await load();
    final next = <DgtExamHistoryEntry>[entry, ...current];
    if (next.length > kDgtExamHistoryMaxEntries) {
      next.removeRange(kDgtExamHistoryMaxEntries, next.length);
    }
    await _persist(next);
    return next;
  }

  /// Sobreescribe historial (util en tests).
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kDgtExamHistoryPrefsKey);
    } catch (_) {
      // best-effort
    }
  }

  Future<void> _persist(List<DgtExamHistoryEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded =
          jsonEncode(entries.map((e) => e.toJson()).toList(growable: false));
      await prefs.setString(kDgtExamHistoryPrefsKey, encoded);
    } catch (_) {
      // best-effort
    }
  }

  /// Resumen agregado de una lista de entradas.
  static DgtExamHistorySummary summarize(List<DgtExamHistoryEntry> entries) {
    if (entries.isEmpty) return DgtExamHistorySummary.empty;
    int passed = 0;
    int? bestCorrect;
    int? bestTotal;
    double bestRatio = -1;
    for (final e in entries) {
      if (e.passed) passed++;
      final ratio = e.total == 0 ? 0.0 : e.correct / e.total;
      if (ratio > bestRatio) {
        bestRatio = ratio;
        bestCorrect = e.correct;
        bestTotal = e.total;
      }
    }
    return DgtExamHistorySummary(
      totalExams: entries.length,
      passedExams: passed,
      bestCorrect: bestCorrect,
      bestTotal: bestTotal,
    );
  }
}

/// Provider del repositorio (singleton sin estado interno mas alla de prefs).
final dgtExamHistoryRepositoryProvider =
    Provider<DgtExamHistoryRepository>((ref) => DgtExamHistoryRepository());

/// Provider que materializa el historial cargado desde SharedPreferences.
/// Se invalida tras `append` para refrescar la UI.
final dgtExamHistoryProvider =
    FutureProvider<List<DgtExamHistoryEntry>>((ref) async {
  final repo = ref.watch(dgtExamHistoryRepositoryProvider);
  return repo.load();
});

/// Formato relativo "hace 2d", "hace 3h", "hace 5m", "ahora".
/// Aditivo y deterministico, sin dependencias adicionales.
String formatRelativeDate(DateTime when, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(when);
  if (diff.isNegative) return 'ahora';
  if (diff.inSeconds < 60) return 'ahora';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
  if (diff.inHours < 24) return 'hace ${diff.inHours}h';
  if (diff.inDays < 7) return 'hace ${diff.inDays}d';
  if (diff.inDays < 30) return 'hace ${(diff.inDays / 7).floor()}sem';
  if (diff.inDays < 365) return 'hace ${(diff.inDays / 30).floor()}mes';
  return 'hace ${(diff.inDays / 365).floor()}a';
}
