import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../quest/quest_provider.dart';
import 'dgt_prediction.dart';
import 'dgt_settings.dart';

/// Verdict de la prediccion DGT aplicado al criterio oficial:
/// >=27/30 = APROBADO.
enum DgtVerdict {
  /// No hay datos suficientes -> hacer 1er simulacro.
  noData,

  /// expectedScore >= 0.90 -> APROBADO (>=27/30 estimado).
  approved,

  /// expectedScore < 0.90 -> SUSPENSO.
  failed,
}

/// Estado agregado de preparacion DGT consumido por el banner Home.
/// Combina: dailyGoal (settings) + completed (quest hoy) + prediction.
///
/// Issue #54: dashboard de preparacion en Home.
/// Aditivo, NO sustituye `dgtSettingsProvider` ni `dgtPredictionProvider`.
class DgtPreparation {
  final DgtSettings settings;
  final int answeredToday;
  final DgtPrediction prediction;

  const DgtPreparation({
    required this.settings,
    required this.answeredToday,
    required this.prediction,
  });

  /// Progreso 0..1 de meta diaria. 0 si dailyGoal <= 0.
  double get dailyProgress {
    if (settings.dailyGoal <= 0) return 0;
    return (answeredToday / settings.dailyGoal).clamp(0.0, 1.0);
  }

  /// Cuantas preguntas quedan para la meta diaria. 0 si ya cumplida.
  int get dailyRemaining {
    final r = settings.dailyGoal - answeredToday;
    return r < 0 ? 0 : r;
  }

  /// Veredicto basado en prediction.expectedScore vs threshold 0.90.
  /// Si no hay datos suficientes -> noData.
  DgtVerdict get verdict {
    if (!prediction.hasEnoughData) return DgtVerdict.noData;
    final s = prediction.expectedScore!;
    return s >= kDgtThresholdReady ? DgtVerdict.approved : DgtVerdict.failed;
  }

  /// Texto corto para mostrar en el banner.
  String get verdictLabel {
    switch (verdict) {
      case DgtVerdict.noData:
        return 'Prediccion: hacer 1er simulacro';
      case DgtVerdict.approved:
        return 'Prediccion: APROBADO';
      case DgtVerdict.failed:
        return 'Prediccion: SUSPENSO';
    }
  }
}

/// Provider que combina settings + quest (responses hoy) + prediction.
/// Si alguno falla, degrada a defaults para no romper el Home.
///
/// Nota: usa `dgtPredictionProvider` como proxy del "historial reciente"
/// (basado en /dgt/stats/topics windowed). El criterio de aprobado mapea
/// expectedScore >= 0.90 -> APROBADO, equivalente a >=27/30 del examen real.
final dgtPreparationProvider = FutureProvider<DgtPreparation>((ref) async {
  final settings = await ref.watch(dgtSettingsProvider.future);
  // Quest no falla (tiene fallback en el provider), pero por seguridad
  // capturamos cualquier excepcion y usamos 0 respondidas.
  int answered = 0;
  try {
    final quest = await ref.watch(dailyQuestProvider.future);
    answered = quest.completed;
  } catch (_) {
    answered = 0;
  }
  // Prediction tambien tiene fallback a empty; capturamos por defensa.
  DgtPrediction prediction;
  try {
    prediction = await ref.watch(dgtPredictionProvider.future);
  } catch (_) {
    prediction = DgtPrediction.empty;
  }
  return DgtPreparation(
    settings: settings,
    answeredToday: answered,
    prediction: prediction,
  );
});
