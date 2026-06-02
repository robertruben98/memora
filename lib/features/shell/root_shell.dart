import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';

import '../browse/browse_feed_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../stats/stats_screen.dart';
import '../study/study_hub_screen.dart';

class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  int _index = 0;

  // Enfoque DGT: la app arranca en el hub "Estudiar" (teórico DGT). Lo
  // genérico (mazos propios, feed) queda en pestañas secundarias.
  static const _tabs = <Widget>[
    StudyHubScreen(),
    StatsScreen(),
    HomeScreen(),
    BrowseFeedScreen(),
    ProfileScreen(),
  ];

  void _select(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: _tabs,
      ),
      bottomNavigationBar: _BottomNav(
        index: _index,
        onSelect: _select,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;

  const _BottomNav({required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.c.surface,
        border: Border(
          top: BorderSide(color: context.c.border, width: 0.6),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                selected: index == 0,
                iconActive: Icons.play_circle_filled_rounded,
                iconInactive: Icons.play_circle_outline_rounded,
                label: 'Estudiar',
                onTap: () => onSelect(0),
                accent: true,
              ),
              _NavItem(
                selected: index == 1,
                iconActive: Icons.bar_chart_rounded,
                iconInactive: Icons.bar_chart_outlined,
                label: 'Progreso',
                onTap: () => onSelect(1),
              ),
              _NavItem(
                selected: index == 2,
                iconActive: Icons.style_rounded,
                iconInactive: Icons.style_outlined,
                label: 'Mazos',
                onTap: () => onSelect(2),
              ),
              _NavItem(
                selected: index == 3,
                iconActive: Icons.dynamic_feed_rounded,
                iconInactive: Icons.dynamic_feed_outlined,
                label: 'Feed',
                onTap: () => onSelect(3),
              ),
              _NavItem(
                selected: index == 4,
                iconActive: Icons.person_rounded,
                iconInactive: Icons.person_outline_rounded,
                label: 'Perfil',
                onTap: () => onSelect(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final bool selected;
  final IconData iconActive;
  final IconData iconInactive;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  const _NavItem({
    required this.selected,
    required this.iconActive,
    required this.iconInactive,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? (accent ? AppColors.brand : context.c.textPrimary)
        : context.c.textMuted;
    return Expanded(
      child: InkResponse(
        radius: 36,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                selected ? iconActive : iconInactive,
                key: ValueKey(selected),
                color: color,
                size: 26,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
