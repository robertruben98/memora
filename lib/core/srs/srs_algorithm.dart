// Implementación pura del algoritmo SM-2 (SuperMemo 2).
// Sin dependencias en Flutter o BD. Migrable luego a FSRS-4.5.

class SrsResult {
  final double easeFactor;
  final int repetitions;
  final int intervalDays;
  final SrsCardState state;

  const SrsResult({
    required this.easeFactor,
    required this.repetitions,
    required this.intervalDays,
    required this.state,
  });

  @override
  String toString() =>
      'SrsResult(ef=$easeFactor, reps=$repetitions, '
      'interval=${intervalDays}d, state=$state)';
}

enum SrsCardState {
  newCard,
  learning,
  reviewing;

  String get dbValue {
    switch (this) {
      case SrsCardState.newCard:
        return 'new';
      case SrsCardState.learning:
        return 'learning';
      case SrsCardState.reviewing:
        return 'reviewing';
    }
  }

  static SrsCardState fromDb(String value) {
    switch (value) {
      case 'learning':
        return SrsCardState.learning;
      case 'reviewing':
        return SrsCardState.reviewing;
      case 'new':
      default:
        return SrsCardState.newCard;
    }
  }
}

/// Etiquetas legibles para el estado de una tarjeta SRS.
/// Single source of truth para los magic strings de UI dispersos.
extension SrsCardStateLabel on SrsCardState {
  String get displayLabel {
    switch (this) {
      case SrsCardState.newCard:
        return 'Nueva';
      case SrsCardState.learning:
        return 'Aprendiendo';
      case SrsCardState.reviewing:
        return 'Pendiente';
    }
  }
}

class SrsAlgorithm {
  /// Mapeo binario: usuario marca "Acerté" -> 4, "No acerté" -> 1.
  /// Equivale a "good" y "again" en terminología Anki.
  static const int qualityCorrect = 4;
  static const int qualityIncorrect = 1;

  /// SM-2 floor para el ease factor.
  static const double minEaseFactor = 1.3;
  static const double initialEaseFactor = 2.5;

  static SrsResult computeNext({
    required double easeFactor,
    required int repetitions,
    required int intervalDays,
    required int quality,
  }) {
    assert(
      quality == qualityCorrect || quality == qualityIncorrect,
      'DGT usa calidad binaria: quality debe ser qualityCorrect '
      '($qualityCorrect) o qualityIncorrect ($qualityIncorrect), '
      'recibido: $quality',
    );
    final int newReps;
    final int newInterval;

    if (quality < 3) {
      newReps = 0;
      newInterval = 1;
    } else {
      if (repetitions == 0) {
        newInterval = 1;
      } else if (repetitions == 1) {
        newInterval = 6;
      } else {
        newInterval = (intervalDays * easeFactor).round();
      }
      newReps = repetitions + 1;
    }

    final delta = 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02);
    final updatedEase = easeFactor + delta;
    final newEase =
        updatedEase < minEaseFactor ? minEaseFactor : updatedEase;

    final SrsCardState newState;
    if (quality < 3) {
      newState = SrsCardState.learning;
    } else if (newReps < 2) {
      newState = SrsCardState.learning;
    } else {
      newState = SrsCardState.reviewing;
    }

    return SrsResult(
      easeFactor: newEase,
      repetitions: newReps,
      intervalDays: newInterval,
      state: newState,
    );
  }

  static SrsResult initialState() => const SrsResult(
        easeFactor: initialEaseFactor,
        repetitions: 0,
        intervalDays: 0,
        state: SrsCardState.newCard,
      );
}
