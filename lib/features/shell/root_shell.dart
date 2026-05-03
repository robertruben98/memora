import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../browse/browse_feed_screen.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../study/study_hub_screen.dart';

class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  int _index = 0;

  static const _tabs = <Widget>[
    BrowseFeedScreen(),
    HomeScreen(),
    StudyHubScreen(),
    StatsScreen(),
    SettingsScreen(),
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
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E12),
        border: Border(
          top: BorderSide(color: Color(0x14FFFFFF), width: 0.6),
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
                iconActive: Icons.home_rounded,
                iconInactive: Icons.home_outlined,
                label: 'Inicio',
                onTap: () => onSelect(0),
              ),
              _NavItem(
                selected: index == 1,
                iconActive: Icons.style_rounded,
                iconInactive: Icons.style_outlined,
                label: 'Mazos',
                onTap: () => onSelect(1),
              ),
              _NavItem(
                selected: index == 2,
                iconActive: Icons.play_circle_filled_rounded,
                iconInactive: Icons.play_circle_outline_rounded,
                label: 'Estudiar',
                onTap: () => onSelect(2),
                accent: true,
              ),
              _NavItem(
                selected: index == 3,
                iconActive: Icons.bar_chart_rounded,
                iconInactive: Icons.bar_chart_outlined,
                label: 'Stats',
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
        ? (accent ? const Color(0xFF7C5CFF) : Colors.white)
        : Colors.white.withValues(alpha: 0.45);
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
