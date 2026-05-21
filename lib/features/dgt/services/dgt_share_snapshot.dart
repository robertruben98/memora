import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dgt_prediction.dart';
import '../dgt_settings.dart';
import '../dgt_streak_provider.dart';

/// Issue #182 (dgt-ux): snapshot publico read-only para compartir con
/// autoescuela. NO incluye email, lista de fallos, ni datos sensibles.
///
/// Tres responsabilidades:
/// 1. Construir el [DgtShareSnapshot] a partir de providers existentes.
/// 2. Generar un token local hash(uid+date) que sirve como ID publico.
/// 3. Serializar / formatear el copy humano (`buildHumanText`) y la URL
///    `memora://share/dgt/<token>` que va dentro del QR.
///
/// Funciona offline: NO requiere backend. Solo lee providers locales.

const _kShareUidKey = 'dgt.share.uid.v1';

/// Datos publicos compartibles con autoescuela. Read-only.
class DgtShareSnapshot {
  /// Token publico (hex). hash(uid + yyyy-mm-dd).
  final String token;

  /// Score esperado 0..100. `null` si no hay datos suficientes.
  final double? expectedScorePct;

  /// Racha actual (dias consecutivos cumpliendo meta).
  final int currentStreak;

  /// Total respondidas en el mes (proxy de actividad reciente).
  final int monthlyAnswered;

  /// Tema mas debil (ID) o `null` si no aplica.
  final String? weakestTopicId;

  /// % acierto del tema mas debil (0..100). `null` si no aplica.
  final double? weakestTopicAccuracyPct;

  /// Fecha objetivo de examen. `null` si no esta configurada.
  final DateTime? examDate;

  /// Fecha de generacion del snapshot (sirve como "valido a fecha de...").
  final DateTime generatedAt;

  const DgtShareSnapshot({
    required this.token,
    required this.currentStreak,
    required this.monthlyAnswered,
    required this.generatedAt,
    this.expectedScorePct,
    this.weakestTopicId,
    this.weakestTopicAccuracyPct,
    this.examDate,
  });

  /// URL deeplink `memora://share/dgt/<token>` que va en el QR.
  String get deeplink => 'memora://share/dgt/$token';

  /// `true` si el predictor tiene datos suficientes.
  bool get hasPrediction => expectedScorePct != null;

  /// Texto humano corto (para Share.share y para mostrar bajo el QR).
  String buildHumanText() {
    final buf = StringBuffer('Mi progreso DGT (Memora)\n');
    if (expectedScorePct != null) {
      buf.writeln('- Prediccion aprobado: ${expectedScorePct!.toStringAsFixed(0)}%');
    } else {
      buf.writeln('- Prediccion: datos insuficientes');
    }
    buf.writeln('- Racha: $currentStreak dias');
    buf.writeln('- Respuestas este mes: $monthlyAnswered');
    if (weakestTopicId != null && weakestTopicAccuracyPct != null) {
      buf.writeln(
        '- Tema mas debil: $weakestTopicId (${weakestTopicAccuracyPct!.toStringAsFixed(0)}%)',
      );
    }
    if (examDate != null) {
      final d = examDate!;
      buf.writeln(
        '- Examen objetivo: ${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      );
    }
    buf.writeln('Verificar: $deeplink');
    return buf.toString();
  }
}

/// Devuelve / crea el `uid` local persistido en SharedPreferences.
/// NO se envia al backend, NO contiene email. Solo entropia para que el
/// token sea estable por dispositivo.
Future<String> resolveShareUid() async {
  final prefs = await SharedPreferences.getInstance();
  var uid = prefs.getString(_kShareUidKey);
  if (uid != null && uid.isNotEmpty) return uid;
  // Generar uid pseudo-aleatorio simple (offline, sin uuid package).
  final now = DateTime.now();
  uid = 'm${now.microsecondsSinceEpoch.toRadixString(36)}'
      '${now.millisecond.toString().padLeft(3, '0')}';
  await prefs.setString(_kShareUidKey, uid);
  return uid;
}

/// Hash determinista (sin dependencias externas) — FNV-1a 64 bits.
/// Misma entrada => mismo token. uid+fecha => rota diariamente.
String computeShareToken(String uid, DateTime day) {
  final dayStr =
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  final input = '$uid|$dayStr';
  // FNV-1a 64-bit. Usamos BigInt para evitar overflow en JS (web build).
  final fnvOffset = BigInt.parse('14695981039346656037');
  final fnvPrime = BigInt.parse('1099511628211');
  final mask = BigInt.parse('FFFFFFFFFFFFFFFF', radix: 16);
  var hash = fnvOffset;
  final bytes = utf8.encode(input);
  for (final b in bytes) {
    hash = (hash ^ BigInt.from(b)) & mask;
    hash = (hash * fnvPrime) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

/// Provider del snapshot. Recolecta predictor + streak + settings y arma el
/// payload public. Si falla cualquier dependencia => degrada a "sin datos".
final dgtShareSnapshotProvider =
    FutureProvider<DgtShareSnapshot>((ref) async {
  final now = DateTime.now();
  final uid = await resolveShareUid();
  final token = computeShareToken(uid, now);

  DgtPrediction prediction = DgtPrediction.empty;
  try {
    prediction = await ref.watch(dgtPredictionProvider.future);
  } catch (_) {
    prediction = DgtPrediction.empty;
  }

  DgtStreakMonth streak = DgtStreakMonth.empty;
  try {
    streak = await ref.watch(dgtStreakMonthProvider.future);
  } catch (_) {
    streak = DgtStreakMonth.empty;
  }

  DgtSettings settings = DgtSettings.defaults;
  try {
    settings = await ref.watch(dgtSettingsProvider.future);
  } catch (_) {
    settings = DgtSettings.defaults;
  }

  return DgtShareSnapshot(
    token: token,
    expectedScorePct: prediction.hasEnoughData
        ? (prediction.expectedScore! * 100.0).clamp(0.0, 100.0)
        : null,
    currentStreak: streak.currentStreak,
    monthlyAnswered: streak.totalAnsweredMonth,
    weakestTopicId: prediction.weakestTopic?.topicId,
    weakestTopicAccuracyPct: prediction.weakestTopic?.accuracyPct,
    examDate: settings.examDate,
    generatedAt: now,
  );
});
