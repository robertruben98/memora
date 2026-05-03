import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';
import '../shell/root_shell.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final db = ref.read(databaseProvider);
    await db.settingsDao.setValue('onboarding_seen', '1');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RootShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = const [
      _Page(
        gradient: [Color(0xFF7C5CFF), Color(0xFF4F8AFF)],
        icon: Icons.bolt_rounded,
        title: 'Aprende como haces scroll',
        body: 'Memora muestra tus tarjetas en un feed vertical. '
            'Toca para revelar la respuesta y di si la sabías.',
      ),
      _Page(
        gradient: [Color(0xFFFF8A4F), Color(0xFFFFD24F)],
        icon: Icons.auto_awesome_rounded,
        title: 'Repetición espaciada',
        body: 'El algoritmo SM-2 calcula cuándo deberías volver a '
            'ver cada tarjeta. Aciertas → más espaciada. Fallas → '
            'vuelve antes.',
      ),
      _Page(
        gradient: [Color(0xFF4FFFB0), Color(0xFF4FFFE9)],
        icon: Icons.create_rounded,
        title: 'Crea tus mazos',
        body: 'Inglés, geografía, programación, lo que quieras. '
            'Texto e imágenes, organización por mazos, todo local.',
      ),
    ];
    final isLast = _index == pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        if (isLast) {
                          _finish();
                        } else {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(isLast ? 'Empezar' : 'Siguiente'),
                    ),
                  ),
                  if (!isLast) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _finish,
                      child: const Text('Saltar'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  final List<Color> gradient;
  final IconData icon;
  final String title;
  final String body;

  const _Page({
    required this.gradient,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: gradient.first.withValues(alpha: 0.4),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 64),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
