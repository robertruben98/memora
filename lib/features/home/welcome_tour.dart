import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:memora/core/theme/app_colors.dart';

/// Issue #84 (dgt-ux): tour interactivo de bienvenida en Home.
///
/// Muestra overlay oscuro + tooltip apuntando a elementos clave la primera
/// vez que el usuario entra a Home. Guarda flag `dgt_tour_completed=true`
/// en SharedPreferences. Re-lanzable desde Ajustes.
///
/// Pivot DGT aditivo: NO toca el modelo de tarjetas existente.

const String kDgtTourCompletedKey = 'dgt_tour_completed';

/// Provider que carga la flag de "tour completado" desde SharedPreferences.
/// Devuelve `true` si el tour ya se vio, `false` si es la primera vez.
final dgtTourCompletedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kDgtTourCompletedKey) ?? false;
});

/// Marca el tour como completado / lo resetea (para re-lanzarlo).
Future<void> setDgtTourCompleted(WidgetRef ref, bool completed) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kDgtTourCompletedKey, completed);
  ref.invalidate(dgtTourCompletedProvider);
}

/// Definicion de un paso del tour.
class TourStep {
  final String title;
  final String description;
  final IconData icon;
  const TourStep({
    required this.title,
    required this.description,
    required this.icon,
  });
}

/// Pasos por defecto del tour DGT (5 pasos, segun spec del issue).
const List<TourStep> kDefaultDgtTourSteps = <TourStep>[
  TourStep(
    title: '¡Bienvenido a RutaB DGT!',
    description: 'Aqui veras tu progreso, dias restantes hasta tu '
        'examen y meta diaria. Toca el banner para ver estadisticas.',
    icon: Icons.directions_car_filled_rounded,
  ),
  TourStep(
    title: 'Simulacro completo',
    description: 'Practica como en el examen real: 30 preguntas, '
        '30 minutos, aprobado con 27 aciertos o mas.',
    icon: Icons.play_arrow_rounded,
  ),
  TourStep(
    title: 'Repaso inteligente',
    description: 'El sistema te muestra las preguntas que fallaste '
        'o que llevan tiempo sin repasar. Repaso rapido en 3 minutos.',
    icon: Icons.bolt_rounded,
  ),
  TourStep(
    title: 'Estadisticas por tema',
    description: 'Mira tu porcentaje de acierto por tema y donde '
        'necesitas reforzar. Prediccion APROBADO/SUSPENSO en tiempo real.',
    icon: Icons.bar_chart_rounded,
  ),
  TourStep(
    title: 'Reto diario',
    description: 'Cada dia tienes una meta personalizada. Manten '
        'la racha y veras tu progreso despegar hacia el examen.',
    icon: Icons.local_fire_department_rounded,
  ),
];

/// Overlay del tour. Es un widget independiente que se monta como `Stack`
/// child sobre Home. Maneja su propio estado de paso actual y se desmonta
/// llamando `onDismiss` (sea por "Saltar" o por completar el ultimo paso).
class WelcomeTourOverlay extends StatefulWidget {
  final List<TourStep> steps;
  final VoidCallback onDismiss;
  final VoidCallback onCompleted;

  const WelcomeTourOverlay({
    super.key,
    required this.steps,
    required this.onDismiss,
    required this.onCompleted,
  });

  @override
  State<WelcomeTourOverlay> createState() => _WelcomeTourOverlayState();
}

class _WelcomeTourOverlayState extends State<WelcomeTourOverlay> {
  int _stepIndex = 0;

  void _next() {
    if (_stepIndex >= widget.steps.length - 1) {
      widget.onCompleted();
    } else {
      setState(() => _stepIndex++);
    }
  }

  void _skip() => widget.onDismiss();

  @override
  Widget build(BuildContext context) {
    assert(widget.steps.isNotEmpty);
    final step = widget.steps[_stepIndex];
    final isLast = _stepIndex == widget.steps.length - 1;
    final stepLabel = '${_stepIndex + 1}/${widget.steps.length}';

    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    key: const Key('welcome-tour-skip'),
                    onPressed: _skip,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.7),
                    ),
                    child: const Text('Saltar tour'),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.c.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.brand.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.brand
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(step.icon,
                                color: AppColors.brand),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              step.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            stepLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.c.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        step.description,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: context.c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const Key('welcome-tour-next'),
                          onPressed: _next,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            minimumSize: const Size.fromHeight(44),
                          ),
                          child: Text(isLast ? 'Empezar' : 'Siguiente'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
    );
  }
}
