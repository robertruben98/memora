import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/dgt_repository.dart';
import 'dgt_favorites_provider.dart';
import 'dgt_result_screen.dart';

/// Issue #181 (dgt-ux): pantalla "Revisar fallos" post-simulacro.
///
/// Recibe la lista de [DgtAnswerReview] de las preguntas falladas en el
/// simulacro que el usuario acaba de terminar y muestra un PageView con
/// una pregunta por pagina: enunciado, opciones (resaltando la elegida en
/// rojo + la correcta en verde), explicacion normativa si existe y un
/// boton "Marcar como favorita" (toggle) que reusa
/// [dgtFavoritesProvider]. Al llegar a la ultima pagina muestra el CTA
/// "Repaso completado" que vuelve al [DgtResultScreen] con un SnackBar.
class DgtSimulacroReviewScreen extends ConsumerStatefulWidget {
  final List<DgtAnswerReview> failed;

  const DgtSimulacroReviewScreen({super.key, required this.failed});

  @override
  ConsumerState<DgtSimulacroReviewScreen> createState() =>
      _DgtSimulacroReviewScreenState();
}

class _DgtSimulacroReviewScreenState
    extends ConsumerState<DgtSimulacroReviewScreen> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next(int total) {
    if (_index + 1 >= total) {
      // Ultima pagina: cerramos y avisamos al usuario.
      Navigator.of(context).pop();
      // SnackBar despues del pop sobre el scaffold anterior (result_screen).
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Repaso completado'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final failed = widget.failed;
    final total = failed.length;
    // Caso defensivo: si llegamos sin fallos, cerramos.
    if (total == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final favorites = ref.watch(dgtFavoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Revisar fallos (${_index + 1}/$total)'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_index + 1) / total,
              minHeight: 4,
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: total,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final review = failed[i];
                  return _ReviewPage(review: review);
                },
              ),
            ),
            _BottomBar(
              isFavorite: favorites.contains(failed[_index].question.id),
              onToggleFavorite: () async {
                final id = failed[_index].question.id;
                // Capturamos messenger antes del await para evitar el
                // lint use_build_context_synchronously: el ref no necesita
                // el context, pero ScaffoldMessenger.of(context) si.
                final messenger = ScaffoldMessenger.of(context);
                final added =
                    await ref.read(dgtFavoritesProvider.notifier).toggle(id);
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      added
                          ? 'Marcada como favorita'
                          : 'Quitada de favoritas',
                    ),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(milliseconds: 1500),
                  ),
                );
              },
              isLast: _index + 1 >= total,
              onNext: () => _next(total),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewPage extends StatelessWidget {
  final DgtAnswerReview review;
  const _ReviewPage({required this.review});

  String _optionFor(DgtQuestion q, String letter) {
    switch (letter) {
      case 'a':
        return q.optionA;
      case 'b':
        return q.optionB;
      case 'c':
        return q.optionC;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final q = review.question;
    final picked = review.picked;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            q.statement,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          for (final letter in const ['a', 'b', 'c'])
            _OptionRow(
              letter: letter,
              text: _optionFor(q, letter),
              isCorrect: letter == q.correct,
              isPicked: picked == letter,
            ),
          if (q.explanation != null && q.explanation!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Explicacion',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    q.explanation!,
                    style: const TextStyle(fontSize: 13.5, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String letter;
  final String text;
  final bool isCorrect;
  final bool isPicked;

  const _OptionRow({
    required this.letter,
    required this.text,
    required this.isCorrect,
    required this.isPicked,
  });

  @override
  Widget build(BuildContext context) {
    Color border = Colors.white.withValues(alpha: 0.15);
    Color bg = const Color(0xFF1A1A22);
    if (isCorrect) {
      border = const Color(0xFF4FFFB0);
      bg = const Color(0xFF4FFFB0).withValues(alpha: 0.10);
    } else if (isPicked) {
      border = const Color(0xFFFF5C5C);
      bg = const Color(0xFFFF5C5C).withValues(alpha: 0.10);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: border.withValues(alpha: 0.25),
              ),
              child: Text(
                letter.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: 14)),
            ),
            if (isCorrect)
              const Icon(Icons.check_circle_rounded,
                  size: 18, color: Color(0xFF4FFFB0))
            else if (isPicked)
              const Icon(Icons.cancel_rounded,
                  size: 18, color: Color(0xFFFF5C5C)),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final bool isLast;
  final VoidCallback onNext;

  const _BottomBar({
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.isLast,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onToggleFavorite,
              icon: Icon(
                isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                color: isFavorite ? const Color(0xFFFFD24F) : null,
              ),
              label: Text(isFavorite ? 'Favorita' : 'Favorita'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(isLast ? 'Volver' : 'Siguiente'),
            ),
          ),
        ],
      ),
    );
  }
}
