import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';

import '../settings/settings_screen.dart';
import 'character_progress.dart';
import 'widgets/achievements_section.dart';
import 'widgets/auth_menu_button.dart';
import 'widgets/character_card.dart';
import 'widgets/deck_skill_row.dart';
import 'widgets/deck_titles_grid.dart';
import 'widgets/primary_stats.dart';
import 'widgets/section_title.dart';

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
          const AuthMenuButton(),
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
        CharacterCard(progress: progress),
        const SizedBox(height: 24),
        PrimaryStats(progress: progress),
        const SizedBox(height: 24),
        const SectionTitle('Títulos del personaje'),
        const SizedBox(height: 12),
        DeckTitlesGrid(decks: progress.decks),
        const SizedBox(height: 24),
        const SectionTitle('Habilidades por mazo'),
        const SizedBox(height: 12),
        if (progress.decks.isEmpty)
          _emptyState(context)
        else
          for (final d in progress.decks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DeckSkillRow(deck: d),
            ),
        const SizedBox(height: 24),
        const SectionTitle('Logros desbloqueados'),
        const SizedBox(height: 12),
        AchievementsSection(progress: progress),
      ],
    );
  }

  Widget _emptyState(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.c.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.c.border),
        ),
        child: Center(
          child: Text(
            'Estudia para desbloquear habilidades',
            style: TextStyle(
              color: context.c.textMuted,
              fontSize: 13,
            ),
          ),
        ),
      );
}
