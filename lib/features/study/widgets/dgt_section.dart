import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dgt_exam_history.dart';
import '../dgt_exam_screen.dart';
import '../dgt_history_screen.dart';
import '../dgt_sections_screen.dart';

/// DGT-specific study modes section.
///
/// Encapsula los 3 tiles DGT (Simulacro, Historial, Estudio por Secciones)
/// que originalmente vivian inline en `study_hub_screen.dart`. Cualquier
/// feature DGT futura (cache offline #45, nuevos modos) edita ESTE archivo
/// en vez del hub general, evitando merge conflicts.
class DgtStudySection extends ConsumerWidget {
  const DgtStudySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyCount = ref.watch(dgtExamHistoryProvider).maybeWhen(
          data: (entries) => entries.length,
          orElse: () => null,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DgtExamTile(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DgtExamScreen()),
          ),
        ),
        const SizedBox(height: 10),
        _DgtHistoryTile(
          historyCount: historyCount,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DgtHistoryScreen()),
          ),
        ),
        const SizedBox(height: 14),
        _DgtSectionsTile(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const DgtStudySectionsScreen(),
            ),
          ),
        ),
      ],
    );
  }
}

class _DgtExamTile extends StatelessWidget {
  final VoidCallback onTap;
  const _DgtExamTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFFFA552)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.directions_car_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Simulacro DGT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '30 preguntas, 30 minutos, criterio examen oficial',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DgtHistoryTile extends StatelessWidget {
  final VoidCallback onTap;
  final int? historyCount;
  const _DgtHistoryTile({required this.onTap, required this.historyCount});

  @override
  Widget build(BuildContext context) {
    final count = historyCount ?? 0;
    final hasHistory = count > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.35),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.history_rounded,
                  color: Color(0xFFFF6B35),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Historial de simulacros',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasHistory
                          ? '$count simulacro${count == 1 ? '' : 's'} guardado${count == 1 ? '' : 's'}'
                          : 'Aun sin simulacros completados',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DgtSectionsTile extends StatelessWidget {
  final VoidCallback onTap;
  const _DgtSectionsTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF7C5CFF).withValues(alpha: 0.45),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C5CFF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Color(0xFFB9A6FF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estudiar por Secciones',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Clases teoricas DGT por bloque tematico (lectura)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
