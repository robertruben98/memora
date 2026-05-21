import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/dgt_tutorials.dart';
import 'dgt_tutorial_seen_provider.dart';

/// Issue #153 (dgt-ux): tarjeta de tutorial breve mostrada ANTES de un
/// quiz por subtopic. UNA card con concepto clave + ejemplo + boton
/// "Empezar X preguntas".
///
/// Disenada para mostrarse via `Navigator.push` y completar con un
/// resultado boolean:
///   - true  -> el usuario quiere continuar al quiz.
///   - false -> el usuario salio sin continuar (skip / back button).
///
/// El llamador es responsable de comprobar [DgtSettings.showSubtopicTutorial]
/// y el set de topics ya vistos antes de empujar esta pantalla. Si no
/// existe tutorial para el `topicId`, NO mostrar esta screen (silent
/// fallback al quiz directo).
class DgtSubtopicTutorialScreen extends ConsumerWidget {
  /// `topic_id` del subtopic. Determina que tutorial cargar y que clave
  /// persistir en SharedPreferences si se marca "no mostrar mas".
  final String topicId;

  /// Nombre humano del subtopic (para el AppBar).
  final String topicName;

  /// Cuantas preguntas tendra el quiz (para el CTA "Empezar N preguntas").
  /// Si es null se usa "Empezar quiz" generico.
  final int? questionCount;

  /// Tutorial pre-resuelto. Pasado explicito en el constructor para
  /// permitir tests con mocks y para que el llamador haga el lookup
  /// (decidiendo si la screen aparece) antes de navegar.
  final DgtTutorial tutorial;

  const DgtSubtopicTutorialScreen({
    super.key,
    required this.topicId,
    required this.topicName,
    required this.tutorial,
    this.questionCount,
  });

  void _start(BuildContext context) {
    Navigator.of(context).pop(true);
  }

  Future<void> _markSeenAndStart(BuildContext context, WidgetRef ref) async {
    await ref.read(dgtTutorialSeenProvider.notifier).markSeen(topicId);
    if (!context.mounted) return;
    Navigator.of(context).pop(true);
  }

  void _skip(BuildContext context) {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cta = questionCount != null
        ? 'Empezar $questionCount preguntas'
        : 'Empezar quiz';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Antes de empezar'),
        actions: [
          IconButton(
            tooltip: 'Saltar tutorial',
            onPressed: () => _skip(context),
            icon: const Icon(Icons.skip_next_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                topicName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7C5CFF),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Repaso rapido',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              _TutorialCard(
                icon: Icons.lightbulb_outline_rounded,
                title: 'Concepto clave',
                body: tutorial.concept,
                accent: const Color(0xFF7C5CFF),
              ),
              const SizedBox(height: 12),
              _TutorialCard(
                icon: Icons.menu_book_rounded,
                title: 'Ejemplo',
                body: tutorial.example,
                accent: const Color(0xFF4FFFB0),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _start(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C5CFF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  cta,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _markSeenAndStart(context, ref),
                icon: const Icon(Icons.visibility_off_rounded, size: 18),
                label: const Text('No mostrar mas para este tema'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  const _TutorialCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}
