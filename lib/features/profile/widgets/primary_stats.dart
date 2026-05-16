import 'package:flutter/material.dart';

import '../character_progress.dart';

/// Fila con 3 tarjetas de estadísticas principales: reviews, aciertos y racha.
class PrimaryStats extends StatelessWidget {
  final CharacterProgress progress;
  const PrimaryStats({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: '⚔️',
            label: 'Reviews',
            value: progress.totalReviews.toString(),
            tint: const Color(0xFF7C5CFF),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: '🎯',
            label: 'Aciertos',
            value: progress.totalReviews == 0
                ? '—'
                : '${(progress.hitRate * 100).toStringAsFixed(0)}%',
            tint: const Color(0xFF4FFFB0),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: '🔥',
            label: 'Racha',
            value: '${progress.streakDays}d',
            tint: const Color(0xFFFF8A4F),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color tint;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: tint,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
