import 'package:flutter/material.dart';
import 'package:memora/core/theme/app_colors.dart';

import '../dgt_prediction.dart';

/// Issue #139 (dgt-tech): pantalla intro del simulacro DGT, extraida del
/// monolito `dgt_exam_screen.dart` para reducir su LOC y permitir testing
/// independiente del controller.
///
/// Aditivo: la UX es identica a la previa (pred card, boton Empezar, boton
/// "Modo examen real", seccion "Examen 2026" issue #77, atajo a favoritas).
class DgtExamIntro extends StatelessWidget {
  /// Callback al pulsar "Empezar simulacro" en modo no-estricto.
  final VoidCallback onBegin;

  /// Callback al pulsar "Modo examen real" (issue #87).
  final VoidCallback onStartStrict;

  /// Callback al pulsar el atajo de "Preguntas favoritas" en el AppBar.
  final VoidCallback onOpenFavorites;

  /// Callback al pulsar el card "Examen 2026 - videos" (issue #77).
  final VoidCallback onOpenVideos;

  /// Callback al pedir practica del peor tema desde la Card de prediccion.
  final void Function(String topicId) onPracticeWeakest;

  /// Callback al pulsar el card "Sprint diario" (issue #152).
  /// Puede ser `null` si el feature esta deshabilitado.
  final VoidCallback? onOpenSprint;

  /// Si `true`, el simulacro arranca en modo estricto y el boton "Empezar"
  /// queda deshabilitado (caso edge: usuario llega a intro en strict). En
  /// el flow normal este intro solo se muestra en modo libre.
  final bool strictMode;

  const DgtExamIntro({
    super.key,
    required this.onBegin,
    required this.onStartStrict,
    required this.onOpenFavorites,
    required this.onOpenVideos,
    required this.onPracticeWeakest,
    this.onOpenSprint,
    this.strictMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulacro DGT'),
        actions: [
          IconButton(
            tooltip: 'Preguntas favoritas',
            icon: const Icon(Icons.star_outline_rounded),
            onPressed: onOpenFavorites,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Examen oficial DGT',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '30 preguntas - 30 minutos - aprobado con max 3 fallos.',
                    style: TextStyle(
                      color: context.c.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Seccion "Examen 2026": novedades del examen oficial (videos de
            // percepcion de riesgo). Issue #77.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: _Examen2026Section(onOpenVideos: onOpenVideos),
            ),
            // Issue #152 (dgt-ux): tile "Sprint diario". Si esta presente,
            // el contenido puede pasarse del alto disponible en pantallas
            // pequenas, asi que metemos a partir de aqui dentro de un
            // [Expanded] con scroll para no provocar overflow.
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    DgtPredictionCard(
                      onPracticeWeakest: onPracticeWeakest,
                    ),
                    if (onOpenSprint != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: _SprintDiarioTile(onTap: onOpenSprint!),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: strictMode ? null : onBegin,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.brand,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text(
                    'Empezar simulacro',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            // Modo examen real estricto (issue #87).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('dgt-strict-mode-cta'),
                  onPressed: onStartStrict,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFFF5C5C)),
                    foregroundColor: const Color(0xFFFF5C5C),
                  ),
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text(
                    'Modo examen real',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seccion "Examen 2026" en el intro (issue #77). Card promocional que abre
/// el modo "Videos de percepcion de riesgo".
class _Examen2026Section extends StatelessWidget {
  final VoidCallback onOpenVideos;
  const _Examen2026Section({required this.onOpenVideos});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB74F).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'NOVEDAD 2026',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFFB74F),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Examen 2026',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpenVideos,
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C5CFF), Color(0xFFE04FFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.movie_filter_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Videos de percepcion de riesgo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Practica el nuevo formato del examen DGT 2026',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tile de entrada al modo "Sprint diario" (issue #152). Vive dentro del
/// intro del simulacro porque ESE es el "dgt screen" canonico segun el issue
/// (la otra opcion `dgt_section.dart` esta bloqueada por refactor #148).
class _SprintDiarioTile extends StatelessWidget {
  final VoidCallback onTap;
  const _SprintDiarioTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('dgt-sprint-diario-cta'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFF4FFFB0).withValues(alpha: 0.12),
              border: Border.all(
                color: const Color(0xFF4FFFB0).withValues(alpha: 0.45),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4FFFB0).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFF4FFFB0),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sprint diario',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '10 preguntas en 2 min - histograma de tus ultimos sprints',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.c.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.c.textSecondary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
