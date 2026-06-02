import 'package:flutter/material.dart';

import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';
import '../character_progress.dart';

/// Tarjeta de personaje principal: avatar con anillo de nivel, clase, título, XP bar.
class CharacterCard extends StatelessWidget {
  final CharacterProgress progress;
  const CharacterCard({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2A1F4F),
            Color(0xFF1A1A22),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: DgtStatusColors.warningStrong.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          _CharacterAvatar(level: progress.level),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: DgtStatusColors.warningStrong.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: DgtStatusColors.warningStrong.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Text(
              progress.className.toUpperCase(),
              style: const TextStyle(
                color: DgtStatusColors.warningStrong,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            progress.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Color(0x80000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _XpBar(progress: progress),
        ],
      ),
    );
  }
}

class _CharacterAvatar extends StatelessWidget {
  final int level;
  const _CharacterAvatar({required this.level});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Anillo dorado exterior
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  DgtStatusColors.warningStrong,
                  DgtStatusColors.accentOrange,
                  Color(0xFF7C5CFF),
                  Color(0xFF4F8AFF),
                  DgtStatusColors.warningStrong,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: DgtStatusColors.warningStrong.withValues(alpha: 0.4),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          // Espacio interno oscuro
          Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0E0E12),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
          ),
          // Avatar interior (gradient violeta + letra M)
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF7C5CFF), Color(0xFF4F8AFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: const Text(
              'M',
              style: TextStyle(
                color: Colors.white,
                fontSize: 44,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Color(0x80000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          // Badge de nivel abajo
          Positioned(
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [DgtStatusColors.warningStrong, DgtStatusColors.accentOrange],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF0E0E12),
                  width: 2,
                ),
              ),
              child: Text(
                'Lv $level',
                style: const TextStyle(
                  color: Color(0xFF0E0E12),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _XpBar extends StatelessWidget {
  final CharacterProgress progress;
  const _XpBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Text(
              'EXP',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: DgtStatusColors.warningStrong,
              ),
            ),
            const Spacer(),
            Text(
              '${progress.xpInLevel} / ${progress.xpForNextLevel}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.7),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 12,
            color: Colors.black.withValues(alpha: 0.4),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: progress.progressToNext,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          DgtStatusColors.warningStrong,
                          DgtStatusColors.accentOrange,
                          Color(0xFFE04FFF),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x66FFD24F),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'XP total: ${progress.totalXp}',
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
