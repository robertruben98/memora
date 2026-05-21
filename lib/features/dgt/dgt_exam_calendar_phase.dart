/// Issue #187 (dgt-ux): fases del ramp-up al examen DGT.
///
/// Funcion pura sin dependencias de Flutter. Calcula en que fase del
/// ramp-up esta el estudiante segun `daysUntilExam` (>=0). Diseno de buckets
/// segun criterios del issue:
///
///   - `temario` (>=21d):  "Temario amplio - 30 preg/dia + 1 simulacro/sem"
///   - `refuerzo` (8..20d): "Refuerzo - weak-focus + 2 simulacros/sem"
///   - `simulacros` (3..7d): "Examenes reales - 1 simulacro/dia + revision fallos"
///   - `repaso` (<=2d):     "Repaso ligero - favoritos + descanso"
///
/// Para `daysUntilExam < 0` (ya paso) o `null` (sin fecha) el caller debe
/// gestionar el caso aparte; este enum solo describe el ramp-up activo.
library;

enum DgtExamPhase {
  temario(
    code: 'temario',
    title: 'Temario amplio',
    subtitle: '30 preguntas/dia + 1 simulacro/semana',
    minDays: 21,
    maxDays: 9999,
  ),
  refuerzo(
    code: 'refuerzo',
    title: 'Refuerzo',
    subtitle: 'Weak-focus + 2 simulacros/semana',
    minDays: 8,
    maxDays: 20,
  ),
  simulacros(
    code: 'simulacros',
    title: 'Examenes reales',
    subtitle: '1 simulacro/dia + revision de fallos',
    minDays: 3,
    maxDays: 7,
  ),
  repaso(
    code: 'repaso',
    title: 'Repaso ligero',
    subtitle: 'Favoritos + descanso, sin agobios',
    minDays: 0,
    maxDays: 2,
  );

  final String code;
  final String title;
  final String subtitle;
  final int minDays; // inclusive
  final int maxDays; // inclusive

  const DgtExamPhase({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.minDays,
    required this.maxDays,
  });

  /// Orden visual en la timeline: temario primero, repaso ultimo.
  static List<DgtExamPhase> orderedTimeline() => const [
        DgtExamPhase.temario,
        DgtExamPhase.refuerzo,
        DgtExamPhase.simulacros,
        DgtExamPhase.repaso,
      ];

  /// Devuelve la fase ACTUAL segun dias hasta el examen.
  ///
  /// Contrato:
  ///   - days >= 21 -> [temario]
  ///   - 8 <= days <= 20 -> [refuerzo]
  ///   - 3 <= days <= 7 -> [simulacros]
  ///   - 0 <= days <= 2 -> [repaso]
  ///   - days < 0 (examen pasado): null (caller maneja estado especial).
  static DgtExamPhase? forDays(int days) {
    if (days < 0) return null;
    for (final p in orderedTimeline()) {
      if (days >= p.minDays && days <= p.maxDays) return p;
    }
    return null;
  }
}

/// Estado de una fase en la timeline.
enum DgtExamPhaseStatus {
  /// Ya superada (estudiante avanzo de fase).
  passed,

  /// Fase activa: highlight visual.
  current,

  /// Aun no alcanzada.
  upcoming,
}

/// Calcula el estado de [phase] respecto a la fase actual [current].
///
/// La timeline va de mayor a menor dias hasta el examen: `temario` -> `repaso`.
/// Conforme se acerca la fecha, `temario` queda en `passed`, la fase actual es
/// `current`, y las siguientes son `upcoming` hasta que el estudiante avance.
DgtExamPhaseStatus dgtExamPhaseStatus({
  required DgtExamPhase phase,
  required DgtExamPhase? current,
}) {
  if (current == null) return DgtExamPhaseStatus.upcoming;
  if (phase == current) return DgtExamPhaseStatus.current;
  final order = DgtExamPhase.orderedTimeline();
  final phaseIdx = order.indexOf(phase);
  final currentIdx = order.indexOf(current);
  return phaseIdx < currentIdx
      ? DgtExamPhaseStatus.passed
      : DgtExamPhaseStatus.upcoming;
}
