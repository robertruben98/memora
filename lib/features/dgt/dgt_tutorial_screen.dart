// Tutorial inicial del modulo DGT.
//
// Issue: https://github.com/robertruben98/memora/issues/68
// Resuelve: estudiante nuevo no entiende la diferencia entre los distintos
// modos del modulo DGT (Practica por tema, Simulacro, Review Rapido).
//
// Aditivo: no modifica el onboarding general ni ninguna pantalla existente.
// Solo introduce DgtTutorialScreen + DgtTutorialGate, listos para que el
// futuro entry-point del modulo DGT los consuma sin tener que cambiar nada
// aqui.
//
// Persistencia: usa SettingsDao (mismo patron que onboarding_screen.dart)
// con la key 'dgt_tutorial_seen'. Si el acceso a settings falla, el gate
// degrada a "no mostrar" para no bloquear el flujo (acceptance criteria).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';

/// Clave persistida en AppSettings (settings_dao). Marca que el usuario ya
/// vio (o se salto) el tutorial DGT al menos una vez.
const String dgtTutorialSeenKey = 'dgt_tutorial_seen';

/// Lee el flag del tutorial DGT. Devuelve `false` ante cualquier error para
/// no bloquear el flujo (degradacion definida en el acceptance del issue).
Future<bool> isDgtTutorialSeen(MemoraDatabase db) async {
  try {
    final value = await db.settingsDao.getValue(dgtTutorialSeenKey);
    return value == '1';
  } catch (_) {
    return false;
  }
}

/// Marca el tutorial como visto. Silencia errores: el flag es UX, no critico.
Future<void> markDgtTutorialSeen(MemoraDatabase db) async {
  try {
    await db.settingsDao.setValue(dgtTutorialSeenKey, '1');
  } catch (_) {
    // best-effort: si falla, el peor caso es que se muestre de nuevo.
  }
}

/// Gate widget: muestra [DgtTutorialScreen] la primera vez y luego [child].
/// El entry-point del modulo DGT puede envolver su pantalla principal con
/// esto sin preocuparse por la persistencia.
class DgtTutorialGate extends ConsumerStatefulWidget {
  final Widget child;
  const DgtTutorialGate({super.key, required this.child});

  @override
  ConsumerState<DgtTutorialGate> createState() => _DgtTutorialGateState();
}

class _DgtTutorialGateState extends ConsumerState<DgtTutorialGate> {
  Future<bool>? _seenFuture;

  @override
  void initState() {
    super.initState();
    final db = ref.read(databaseProvider);
    _seenFuture = isDgtTutorialSeen(db);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _seenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final seen = snapshot.data ?? false;
        if (seen) return widget.child;
        return DgtTutorialScreen(onDone: () {
          if (mounted) {
            setState(() {
              _seenFuture = Future.value(true);
            });
          }
        });
      },
    );
  }
}

/// Pantalla de tutorial: 3 slides explicando los modos DGT.
class DgtTutorialScreen extends ConsumerStatefulWidget {
  /// Callback cuando el usuario completa o se salta el tutorial. Si es null,
  /// se hace Navigator.pop. Permite reusar la screen tanto desde un gate
  /// como desde una entrada manual ("Ver tutorial otra vez" en settings).
  final VoidCallback? onDone;
  const DgtTutorialScreen({super.key, this.onDone});

  @override
  ConsumerState<DgtTutorialScreen> createState() => _DgtTutorialScreenState();
}

class _DgtTutorialScreenState extends ConsumerState<DgtTutorialScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final db = ref.read(databaseProvider);
    await markDgtTutorialSeen(db);
    if (!mounted) return;
    if (widget.onDone != null) {
      widget.onDone!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = const <_DgtPage>[
      _DgtPage(
        gradient: [Color(0xFF4F8AFF), Color(0xFF7C5CFF)],
        icon: Icons.menu_book_rounded,
        title: 'Practica por tema',
        body: 'Estudia bloque por bloque (senales, normas, mecanica...). '
            'Sin presion de tiempo, ideal para aprender de cero.',
      ),
      _DgtPage(
        gradient: [Color(0xFFFF8A4F), Color(0xFFFFD24F)],
        icon: Icons.timer_rounded,
        title: 'Simulacro',
        body: '30 preguntas en 30 minutos como en el examen DGT real. '
            'Mide tu nivel antes de presentarte.',
      ),
      _DgtPage(
        gradient: [Color(0xFF4FFFB0), Color(0xFF4FFFE9)],
        icon: Icons.bolt_rounded,
        title: 'Review Rapido',
        body: '10 preguntas para repaso diario, mezcladas inteligentemente '
            'con tus puntos debiles.',
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
                      key: const Key('dgt-tutorial-skip'),
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

class _DgtPage extends StatelessWidget {
  final List<Color> gradient;
  final IconData icon;
  final String title;
  final String body;

  const _DgtPage({
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
