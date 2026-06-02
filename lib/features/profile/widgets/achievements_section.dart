import 'package:flutter/material.dart';
import 'package:memora/core/theme/app_colors.dart';

import '../character_progress.dart';

/// Lista de logros desbloqueados/bloqueados en base al progreso del personaje.
class AchievementsSection extends StatelessWidget {
  final CharacterProgress progress;
  const AchievementsSection({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final achievements = <_Achievement>[
      _Achievement(
        icon: '🌱',
        label: 'Primer paso',
        unlocked: progress.totalReviews >= 1,
        desc: 'Completar la primera revisión',
      ),
      _Achievement(
        icon: '📚',
        label: 'Erudito novato',
        unlocked: progress.totalReviews >= 50,
        desc: '50 revisiones totales',
      ),
      _Achievement(
        icon: '🔥',
        label: 'En racha',
        unlocked: progress.streakDays >= 3,
        desc: 'Racha de 3 días',
      ),
      _Achievement(
        icon: '⚔️',
        label: 'Sin descanso',
        unlocked: progress.streakDays >= 7,
        desc: 'Racha de 7 días',
      ),
      _Achievement(
        icon: '🎯',
        label: 'Tirador certero',
        unlocked: progress.totalReviews >= 30 && progress.hitRate >= 0.8,
        desc: '80% de acierto en 30+ revisiones',
      ),
      _Achievement(
        icon: '⭐',
        label: 'Adepto',
        unlocked: progress.level >= 5,
        desc: 'Alcanzar nivel 5',
      ),
      _Achievement(
        icon: '💎',
        label: 'Erudito Errante',
        unlocked: progress.level >= 10,
        desc: 'Alcanzar nivel 10',
      ),
      _Achievement(
        icon: '👑',
        label: 'Sabio del Recuerdo',
        unlocked: progress.level >= 15,
        desc: 'Alcanzar nivel 15',
      ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in achievements) _AchievementBadge(achievement: a),
      ],
    );
  }
}

class _Achievement {
  final String icon;
  final String label;
  final bool unlocked;
  final String desc;

  const _Achievement({
    required this.icon,
    required this.label,
    required this.unlocked,
    required this.desc,
  });
}

class _AchievementBadge extends StatelessWidget {
  final _Achievement achievement;
  const _AchievementBadge({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    return Tooltip(
      message: '${achievement.label}\n${achievement.desc}',
      child: Container(
        width: 70,
        height: 80,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.c.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: unlocked
                ? const Color(0xFFFFD24F).withValues(alpha: 0.5)
                : context.c.border,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: unlocked ? 1.0 : 0.25,
              child: Text(
                achievement.icon,
                style: const TextStyle(fontSize: 26),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              achievement.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: unlocked
                    ? const Color(0xFFFFD24F)
                    : context.c.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
