import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/database/database.dart';
import '../auth/auth_state.dart';
import '../auth/login_screen.dart';
import '../dgt/dgt_settings.dart';
import '../shell/root_shell.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  // Estado de los ajustes DGT que se van rellenando en el flujo.
  DgtLicenseType _licenseType = DgtSettings.defaults.licenseType;
  DateTime? _examDate;
  int _dailyGoal = DgtSettings.defaults.dailyGoal;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final db = ref.read(databaseProvider);
    await db.settingsDao.setValue('onboarding_seen', '1');
    // Persistir ajustes DGT (con defaults seguros si el usuario saltea).
    await ref.read(dgtSettingsRepositoryProvider).save(
          DgtSettings(
            licenseType: _licenseType,
            examDate: _examDate,
            dailyGoal: _dailyGoal,
          ),
        );
    ref.invalidate(dgtSettingsProvider);
    if (!mounted) return;
    final auth = ref.read(authProvider);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (routeContext) => auth.isLoggedIn
            ? const RootShell()
            : LoginScreen(
                onAuthenticated: () {
                  // Usar el context de ESTA ruta (LoginScreen sigue montado),
                  // no el de onboarding, que ya quedó defunct tras el
                  // pushReplacement -> evita "widget has been unmounted".
                  Navigator.of(routeContext).pushReplacement(
                    MaterialPageRoute(builder: (_) => const RootShell()),
                  );
                },
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _IntroPage(
        gradient: [Color(0xFF7C5CFF), Color(0xFF4F8AFF)],
        icon: Icons.bolt_rounded,
        title: 'Aprende como haces scroll',
        body: 'RutaB muestra tus tarjetas en un feed vertical. '
            'Toca para revelar la respuesta y di si la sabias.',
      ),
      const _IntroPage(
        gradient: [Color(0xFFFF8A4F), Color(0xFFFFD24F)],
        icon: Icons.auto_awesome_rounded,
        title: 'Repeticion espaciada',
        body: 'El algoritmo SM-2 calcula cuando deberias volver a '
            'ver cada tarjeta. Aciertas, mas espaciada. Fallas, '
            'vuelve antes.',
      ),
      const _IntroPage(
        gradient: [Color(0xFF4FFFB0), Color(0xFF4FFFE9)],
        icon: Icons.create_rounded,
        title: 'Crea tus mazos',
        body: 'Ingles, geografia, programacion, lo que quieras. '
            'Texto e imagenes, organizacion por mazos, todo local.',
      ),
      _LicensePage(
        selected: _licenseType,
        onChanged: (t) => setState(() => _licenseType = t),
      ),
      _ExamDatePage(
        date: _examDate,
        onChanged: (d) => setState(() => _examDate = d),
        onClear: () => setState(() => _examDate = null),
      ),
      _DailyGoalPage(
        goal: _dailyGoal,
        onChanged: (g) => setState(() => _dailyGoal = g),
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
                              ? context.c.textPrimary
                              : context.c.textPrimary.withValues(alpha: 0.22),
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

class _IntroPage extends StatelessWidget {
  final List<Color> gradient;
  final IconData icon;
  final String title;
  final String body;

  const _IntroPage({
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
              color: context.c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LicensePage extends StatelessWidget {
  final DgtLicenseType selected;
  final ValueChanged<DgtLicenseType> onChanged;

  const _LicensePage({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Para que permiso te preparas?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Personaliza tu plan DGT segun el examen al que te presentas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: context.c.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          ...DgtLicenseType.values.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LicenseCard(
                type: t,
                selected: t == selected,
                onTap: () => onChanged(t),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LicenseCard extends StatelessWidget {
  final DgtLicenseType type;
  final bool selected;
  final VoidCallback onTap;

  const _LicenseCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  IconData get _icon {
    switch (type) {
      case DgtLicenseType.b:
        return Icons.directions_car_rounded;
      case DgtLicenseType.a:
        return Icons.motorcycle_rounded;
      case DgtLicenseType.c:
        return Icons.local_shipping_rounded;
      case DgtLicenseType.d:
        return Icons.directions_bus_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.brand.withValues(alpha: 0.18)
          : context.c.surfaceElevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.brand : context.c.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C5CFF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, color: const Color(0xFF7C5CFF)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${type.code} - ${type.shortLabel}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      type.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF7C5CFF),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamDatePage extends StatelessWidget {
  final DateTime? date;
  final ValueChanged<DateTime> onChanged;
  final VoidCallback onClear;

  const _ExamDatePage({
    required this.date,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.event_rounded,
            size: 72,
            color: Color(0xFF7C5CFF),
          ),
          const SizedBox(height: 24),
          const Text(
            'Cuando es tu examen?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Si lo sabes ya, te ayudaremos a planificar las preguntas '
            'diarias hasta esa fecha.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: context.c.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: date ?? now.add(const Duration(days: 30)),
                firstDate: now,
                lastDate: now.add(const Duration(days: 365 * 2)),
              );
              if (picked != null) onChanged(picked);
            },
            icon: const Icon(Icons.calendar_today_rounded),
            label: Text(
              date == null
                  ? 'Elegir fecha'
                  : '${date!.day}/${date!.month}/${date!.year}',
            ),
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onClear,
            child: const Text('Aun no lo se'),
          ),
        ],
      ),
    );
  }
}

class _DailyGoalPage extends StatelessWidget {
  final int goal;
  final ValueChanged<int> onChanged;

  const _DailyGoalPage({required this.goal, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const options = [10, 20, 30, 50];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.flag_rounded,
            size: 72,
            color: Color(0xFFFFD24F),
          ),
          const SizedBox(height: 24),
          const Text(
            'Tu meta diaria',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Cuantas preguntas quieres responder cada dia? Podras '
            'cambiarlo desde Ajustes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: context.c.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: options
                .map(
                  (n) => ChoiceChip(
                    label: Text('$n preguntas/dia'),
                    selected: goal == n,
                    onSelected: (_) => onChanged(n),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
