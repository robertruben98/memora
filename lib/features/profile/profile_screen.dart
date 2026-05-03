import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/deck_visuals.dart';
import '../auth/auth_state.dart';
import '../auth/login_screen.dart';
import '../settings/settings_screen.dart';
import '../shell/root_shell.dart';
import 'character_progress.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(characterProgressProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Perfil',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4),
        ),
        actions: [
          _AuthMenuButton(),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Ajustes',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: progressAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (progress) => _ProfileBody(progress: progress),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final CharacterProgress progress;
  const _ProfileBody({required this.progress});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _CharacterCard(progress: progress),
        const SizedBox(height: 24),
        _PrimaryStats(progress: progress),
        const SizedBox(height: 24),
        const _SectionTitle('Habilidades por mazo'),
        const SizedBox(height: 12),
        if (progress.decks.isEmpty)
          _emptyState()
        else
          for (final d in progress.decks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DeckSkillRow(deck: d),
            ),
        const SizedBox(height: 24),
        const _SectionTitle('Logros desbloqueados'),
        const SizedBox(height: 12),
        _Achievements(progress: progress),
      ],
    );
  }

  Widget _emptyState() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Center(
          child: Text(
            'Estudia para desbloquear habilidades',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
            ),
          ),
        ),
      );
}

/// Tarjeta de personaje principal: avatar con anillo de nivel, clase, título, XP bar.
class _CharacterCard extends StatelessWidget {
  final CharacterProgress progress;
  const _CharacterCard({required this.progress});

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
          color: const Color(0xFFFFD24F).withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C5CFF).withValues(alpha: 0.25),
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
              color: const Color(0xFFFFD24F).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFFFD24F).withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Text(
              progress.className.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFFFD24F),
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
                  Color(0xFFFFD24F),
                  Color(0xFFFF8A4F),
                  Color(0xFF7C5CFF),
                  Color(0xFF4F8AFF),
                  Color(0xFFFFD24F),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD24F).withValues(alpha: 0.4),
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
                  colors: [Color(0xFFFFD24F), Color(0xFFFF8A4F)],
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
                color: Color(0xFFFFD24F),
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
                          Color(0xFFFFD24F),
                          Color(0xFFFF8A4F),
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

class _PrimaryStats extends StatelessWidget {
  final CharacterProgress progress;
  const _PrimaryStats({required this.progress});

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

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD24F),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: Color(0xFFFFD24F),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeckSkillRow extends StatelessWidget {
  final DeckProgress deck;
  const _DeckSkillRow({required this.deck});

  @override
  Widget build(BuildContext context) {
    final color = DeckVisuals.colorFromHex(deck.colorHex);
    final progress = deck.reviews == 0
        ? 0.0
        : ((deck.correct / deck.reviews).clamp(0.0, 1.0));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  DeckVisuals.iconFor(deck.iconName),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${deck.reviews} reviews · ${(progress * 100).toStringAsFixed(0)}% acierto',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Lv ${deck.level}',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (deck.reviews > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 4,
                color: Colors.black.withValues(alpha: 0.4),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(color: color),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Achievements extends StatelessWidget {
  final CharacterProgress progress;
  const _Achievements({required this.progress});

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
          color: const Color(0xFF1A1A22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: unlocked
                ? const Color(0xFFFFD24F).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.06),
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
                    : Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthMenuButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return PopupMenuButton<String>(
      icon: Icon(
        auth.isLoggedIn ? Icons.account_circle : Icons.login_rounded,
      ),
      tooltip: auth.isLoggedIn ? auth.email ?? 'Cuenta' : 'Iniciar sesión',
      onSelected: (action) async {
        if (action == 'login') {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LoginScreen(
                onAuthenticated: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const RootShell()),
                  (_) => false,
                ),
              ),
            ),
          );
        } else if (action == 'logout') {
          await ref.read(authProvider.notifier).logout();
          if (!context.mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => LoginScreen(
                onAuthenticated: () =>
                    Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const RootShell()),
                  (_) => false,
                ),
              ),
            ),
            (_) => false,
          );
        }
      },
      itemBuilder: (ctx) {
        if (auth.isLoggedIn) {
          return [
            PopupMenuItem(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    auth.email ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'ID: ${auth.userId ?? ''}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, color: Color(0xFFFF4F6B)),
                  SizedBox(width: 8),
                  Text(
                    'Cerrar sesión',
                    style: TextStyle(color: Color(0xFFFF4F6B)),
                  ),
                ],
              ),
            ),
          ];
        }
        return [
          const PopupMenuItem(
            enabled: false,
            child: Text(
              'Modo legacy (sin login)',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'login',
            child: Row(
              children: [
                Icon(Icons.login_rounded),
                SizedBox(width: 8),
                Text('Iniciar sesión'),
              ],
            ),
          ),
        ];
      },
    );
  }
}
