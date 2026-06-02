import 'package:flutter/material.dart';

import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/widgets/dgt_tinted_chip.dart';

import 'learn_methods_data.dart';

class LearnMethodsScreen extends StatelessWidget {
  const LearnMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Aprende a aprender',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const _Hero(),
          const SizedBox(height: 24),
          for (final cat in learnCategories) ...[
            _CategoryHeader(category: cat),
            const SizedBox(height: 12),
            for (final m in cat.methods)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MethodCard(method: m, accent: cat.accent),
              ),
            const SizedBox(height: 24),
          ],
          _Footer(),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C5CFF), Color(0xFF4F8AFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('📖', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Métodos de estudio',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Las técnicas con más evidencia científica para '
                  'aprender mejor y recordar más.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final LearnCategory category;
  const _CategoryHeader({required this.category});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: category.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: category.accent.withValues(alpha: 0.4),
              ),
            ),
            alignment: Alignment.center,
            child: Text(category.emoji, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              category.title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: category.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodCard extends StatefulWidget {
  final LearnMethod method;
  final Color accent;

  const _MethodCard({required this.method, required this.accent});

  @override
  State<_MethodCard> createState() => _MethodCardState();
}

class _MethodCardState extends State<_MethodCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.method;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: context.c.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _expanded
              ? widget.accent.withValues(alpha: 0.45)
              : context.c.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      m.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  m.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _EvidenceBadge(level: m.evidence),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m.tagline,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: context.c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 200),
                      turns: _expanded ? 0.5 : 0,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: context.c.textMuted,
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 220),
                  crossFadeState: _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox(height: 0, width: double.infinity),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 1,
                          color: context.c.border,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          m.body,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.55,
                            color: context.c.textPrimary,
                          ),
                        ),
                        if (m.memoraNote != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: widget.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: widget.accent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.psychology_alt_rounded,
                                  color: widget.accent,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Cómo lo usa RutaB',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                          color: widget.accent,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        m.memoraNote!,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          height: 1.45,
                                          color: context.c.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (m.source != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Fuente: ${m.source}',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: context.c.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EvidenceBadge extends StatelessWidget {
  final EvidenceLevel level;
  const _EvidenceBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    return DgtTintedChip(
      color: level.color,
      label: level.label,
      bgAlpha: 0.15,
      borderAlpha: 0.4,
      radius: 6,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      textStyle: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Center(
        child: Text(
          'Toca cada método para leer en detalle.\n'
          'La evidencia se basa en meta-análisis y revisiones académicas.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            height: 1.5,
            color: context.c.textMuted,
          ),
        ),
      ),
    );
  }
}
