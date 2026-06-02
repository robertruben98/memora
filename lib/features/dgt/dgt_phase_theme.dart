import 'package:flutter/material.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';

import 'dgt_exam_calendar_phase.dart';

/// Issue #187 (dgt-ux): tema visual por fase del ramp-up DGT.
///
/// Centraliza el color de acento y el icono de cada [DgtExamPhase] para
/// evitar `switch` duplicados en la pantalla de calendario. Tambien expone
/// las constantes compartidas del estado "passed" (check + verde) usadas
/// tanto por el tile de fase como por el chip de estado.

/// Color e icono asociados a una fase del ramp-up.
class DgtPhaseTheme {
  final Color accent;
  final IconData icon;
  const DgtPhaseTheme({required this.accent, required this.icon});
}

/// Color verde y check usados para representar una fase ya superada.
const Color dgtPhasePassedColor = Color(0xFF2E9E5B);
const IconData dgtPhasePassedIcon = Icons.check_circle_rounded;

/// Devuelve el [DgtPhaseTheme] (acento + icono) de [phase].
DgtPhaseTheme phaseTheme(DgtExamPhase phase) {
  switch (phase) {
    case DgtExamPhase.temario:
      return const DgtPhaseTheme(
        accent: DgtStatusColors.success,
        icon: Icons.menu_book_rounded,
      );
    case DgtExamPhase.refuerzo:
      return const DgtPhaseTheme(
        accent: DgtStatusColors.warning,
        icon: Icons.gps_fixed_rounded,
      );
    case DgtExamPhase.simulacros:
      return const DgtPhaseTheme(
        accent: Color(0xFFFF6B35),
        icon: Icons.directions_car_rounded,
      );
    case DgtExamPhase.repaso:
      return const DgtPhaseTheme(
        accent: DgtStatusColors.error,
        icon: Icons.self_improvement_rounded,
      );
  }
}
