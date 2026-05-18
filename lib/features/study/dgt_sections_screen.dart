import 'package:flutter/material.dart';

import '../../data/dgt/dgt_sections_local.dart';
import 'dgt_section_detail_screen.dart';

/// Pantalla "Estudiar por Secciones": lista las 13 secciones teoricas DGT.
///
/// Modo lectura (NO preguntas). Cada tile abre el detalle con conceptos
/// clave del bloque tematico. Aditivo respecto al simulacro y al modo
/// practica.
class DgtStudySectionsScreen extends StatelessWidget {
  const DgtStudySectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Estudiar por Secciones',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: kDgtSectionsLocal.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final section = kDgtSectionsLocal[index];
          return _SectionTile(
            section: section,
            index: index + 1,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DgtSectionDetailScreen(
                  sectionIndex: index,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  final DgtSection section;
  final int index;
  final VoidCallback onTap;

  const _SectionTile({
    required this.section,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
              color: const Color(0xFF7C5CFF).withValues(alpha: 0.35),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C5CFF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: Color(0xFFB9A6FF),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${section.concepts.length} conceptos · ${section.description}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
