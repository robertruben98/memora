import 'package:flutter/material.dart';

import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';
import '../../data/dgt/dgt_sections_local.dart';
import '../../data/repositories/dgt_repository.dart';
import '../dgt/dgt_practice_screen.dart';

/// Detalle de una seccion teorica DGT: muestra los conceptos clave en cards
/// independientes (titulo + parrafo + ejemplo opcional). Navegacion
/// prev/next entre secciones y boton "Practicar este tema" que reusa el
/// modo practica existente (issue #51 / PR #56).
class DgtSectionDetailScreen extends StatelessWidget {
  final int sectionIndex;

  const DgtSectionDetailScreen({super.key, required this.sectionIndex});

  DgtSection get _section => kDgtSectionsLocal[sectionIndex];

  bool get _hasPrev => sectionIndex > 0;
  bool get _hasNext => sectionIndex < kDgtSectionsLocal.length - 1;

  void _go(BuildContext context, int newIndex) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DgtSectionDetailScreen(sectionIndex: newIndex),
      ),
    );
  }

  void _practiceThisTopic(BuildContext context) {
    // Lanzamos el modo practica existente con el topic_id de la seccion.
    // Si el backend no reconoce el topic_id, el repo respondera vacio y
    // el modo practica mostrara el estado vacio sin romper.
    final topic = DgtTopic(
      id: _section.id,
      name: _section.name,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DgtPracticeScreen(topic: topic, limit: -1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final section = _section;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Seccion ${sectionIndex + 1}/${kDgtSectionsLocal.length}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  _Header(section: section),
                  const SizedBox(height: 14),
                  for (final c in section.concepts) ...[
                    _ConceptCard(concept: c),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 8),
                  _PracticeButton(
                    onTap: () => _practiceThisTopic(context),
                  ),
                ],
              ),
            ),
            _NavBar(
              hasPrev: _hasPrev,
              hasNext: _hasNext,
              onPrev: _hasPrev ? () => _go(context, sectionIndex - 1) : null,
              onNext: _hasNext ? () => _go(context, sectionIndex + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final DgtSection section;
  const _Header({required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C5CFF), Color(0xFF4F8AFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            section.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConceptCard extends StatelessWidget {
  final DgtConcept concept;
  const _ConceptCard({required this.concept});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.c.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.c.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            concept.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            concept.body,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: context.c.textPrimary,
            ),
          ),
          if (concept.example != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DgtStatusColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: DgtStatusColors.success.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 16,
                    color: DgtStatusColors.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      concept.example!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: Color(0xFFB6FFD8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PracticeButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PracticeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFFFA552)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: const Row(
            children: [
              Icon(Icons.play_arrow_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Practicar este tema',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final bool hasPrev;
  final bool hasNext;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _NavBar({
    required this.hasPrev,
    required this.hasNext,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: context.c.surfaceElevated,
        border: Border(
          top: BorderSide(
            color: context.c.border,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPrev,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Anterior'),
              style: OutlinedButton.styleFrom(
                foregroundColor: hasPrev ? context.c.textPrimary : context.c.textMuted,
                side: BorderSide(
                  color: context.c.border,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Siguiente'),
              style: FilledButton.styleFrom(
                backgroundColor: hasNext
                    ? AppColors.brand
                    : context.c.surfaceElevated,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
