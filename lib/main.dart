import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MemoraApp());
}

class MemoraApp extends StatelessWidget {
  const MemoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7C5CFF),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'Memora',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF0E0E12),
        textTheme: Typography.whiteMountainView.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class MockCard {
  final String front;
  final String back;
  final String deck;
  final Color deckColor;

  const MockCard({
    required this.front,
    required this.back,
    required this.deck,
    required this.deckColor,
  });
}

const _mockCards = <MockCard>[
  MockCard(
    front: '¿Qué significa "to thrive"?',
    back: 'Prosperar, florecer. Crecer con vigor.',
    deck: 'Inglés - Verbos',
    deckColor: Color(0xFF4F8AFF),
  ),
  MockCard(
    front: '¿Cuál es la capital de Mongolia?',
    back: 'Ulán Bator (Ulaanbaatar).',
    deck: 'Geografía',
    deckColor: Color(0xFFFF8A4F),
  ),
  MockCard(
    front: 'En Big-O, ¿complejidad de búsqueda binaria?',
    back: 'O(log n) — divide el espacio de búsqueda a la mitad en cada paso.',
    deck: 'Algoritmos',
    deckColor: Color(0xFF4FFFB0),
  ),
  MockCard(
    front: '¿Qué es la repetición espaciada?',
    back:
        'Técnica de aprendizaje que aumenta los intervalos entre repasos de '
        'material ya aprendido para optimizar la memoria a largo plazo.',
    deck: 'Aprendizaje',
    deckColor: Color(0xFFFFD24F),
  ),
  MockCard(
    front: '¿Quién pintó "La noche estrellada"?',
    back: 'Vincent van Gogh, en 1889.',
    deck: 'Arte',
    deckColor: Color(0xFFE04FFF),
  ),
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Memora',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _StudyAllCard(
            cardCount: _mockCards.length,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const FeedScreen(cards: _mockCards),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Mis Mazos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._buildDeckSummaries(context),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo mazo'),
      ),
    );
  }

  List<Widget> _buildDeckSummaries(BuildContext context) {
    final byDeck = <String, List<MockCard>>{};
    for (final c in _mockCards) {
      byDeck.putIfAbsent(c.deck, () => []).add(c);
    }
    return byDeck.entries.map((e) {
      final color = e.value.first.deckColor;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _DeckTile(
          name: e.key,
          color: color,
          dueCount: e.value.length,
          totalCount: e.value.length,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FeedScreen(cards: e.value),
            ),
          ),
        ),
      );
    }).toList();
  }
}

class _StudyAllCard extends StatelessWidget {
  final int cardCount;
  final VoidCallback onTap;

  const _StudyAllCard({required this.cardCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C5CFF), Color(0xFF4F8AFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.public_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estudiar todo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$cardCount tarjetas pendientes',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeckTile extends StatelessWidget {
  final String name;
  final Color color;
  final int dueCount;
  final int totalCount;
  final VoidCallback onTap;

  const _DeckTile({
    required this.name,
    required this.color,
    required this.dueCount,
    required this.totalCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A22),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.style_rounded, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dueCount due · $totalCount total',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeedScreen extends StatefulWidget {
  final List<MockCard> cards;

  const FeedScreen({super.key, required this.cards});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _controller = PageController();
  int _currentIndex = 0;
  int _correctCount = 0;
  int _incorrectCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onAnswer({required bool correct}) {
    HapticFeedback.mediumImpact();
    setState(() {
      if (correct) {
        _correctCount++;
      } else {
        _incorrectCount++;
      }
    });
    if (_currentIndex < widget.cards.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _showCompletion();
    }
  }

  void _showCompletion() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A22),
        title: const Text('¡Sesión completa!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tarjetas revisadas: ${widget.cards.length}'),
            const SizedBox(height: 4),
            Text('Aciertos: $_correctCount'),
            Text('Fallos: $_incorrectCount'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Volver al inicio'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '${_currentIndex + 1} / ${widget.cards.length}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        itemCount: widget.cards.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, index) {
          return CardPage(
            card: widget.cards[index],
            onCorrect: () => _onAnswer(correct: true),
            onIncorrect: () => _onAnswer(correct: false),
          );
        },
      ),
    );
  }
}

class CardPage extends StatefulWidget {
  final MockCard card;
  final VoidCallback onCorrect;
  final VoidCallback onIncorrect;

  const CardPage({
    super.key,
    required this.card,
    required this.onCorrect,
    required this.onIncorrect,
  });

  @override
  State<CardPage> createState() => _CardPageState();
}

class _CardPageState extends State<CardPage> {
  bool _revealed = false;

  void _reveal() {
    if (_revealed) return;
    HapticFeedback.lightImpact();
    setState(() => _revealed = true);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _reveal,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
          _reveal();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          children: [
            _DeckBadge(
              name: widget.card.deck,
              color: widget.card.deckColor,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                child: _revealed
                    ? _AnsweredView(
                        key: const ValueKey('answered'),
                        front: widget.card.front,
                        back: widget.card.back,
                      )
                    : _QuestionView(
                        key: const ValueKey('question'),
                        front: widget.card.front,
                      ),
              ),
            ),
            AnimatedCrossFade(
              crossFadeState: _revealed
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
              firstChild: const _RevealHint(),
              secondChild: _AnswerButtons(
                onCorrect: widget.onCorrect,
                onIncorrect: widget.onIncorrect,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckBadge extends StatelessWidget {
  final String name;
  final Color color;

  const _DeckBadge({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Text(
          name,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _QuestionView extends StatelessWidget {
  final String front;
  const _QuestionView({super.key, required this.front});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        front,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          height: 1.3,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

class _AnsweredView extends StatelessWidget {
  final String front;
  final String back;
  const _AnsweredView({
    super.key,
    required this.front,
    required this.back,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          front,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.7),
            height: 1.3,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          height: 1,
          color: Colors.white.withValues(alpha: 0.1),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Text(
                back,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RevealHint extends StatelessWidget {
  const _RevealHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(
            Icons.touch_app_rounded,
            color: Colors.white.withValues(alpha: 0.4),
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            'Toca o desliza para ver la respuesta',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerButtons extends StatelessWidget {
  final VoidCallback onCorrect;
  final VoidCallback onIncorrect;

  const _AnswerButtons({
    required this.onCorrect,
    required this.onIncorrect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BigButton(
            label: 'No acerté',
            icon: Icons.close_rounded,
            color: const Color(0xFFFF4F6B),
            onPressed: onIncorrect,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BigButton(
            label: 'Acerté',
            icon: Icons.check_rounded,
            color: const Color(0xFF4FFFB0),
            onPressed: onCorrect,
          ),
        ),
      ],
    );
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _BigButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
