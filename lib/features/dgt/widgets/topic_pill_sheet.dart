import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/topic_pills.dart';

/// Issue #110 (dgt-content): bottom sheet con pildora didactica pre-quiz.
///
/// Muestra normativa clave + mnemotecnia ANTES de entrar a practica de tema
/// critico. Persiste en SharedPreferences (`dgt:pill:seen:<topic_id>`) si el
/// usuario marca "no mostrar otra vez" o pulsa "OK, empezar".
///
/// Aditivo: si no hay pildora definida para el topic_id, no hace nada.
class DgtTopicPillSheet extends StatefulWidget {
  final String topicId;
  final DgtTopicPill pill;

  const DgtTopicPillSheet({
    super.key,
    required this.topicId,
    required this.pill,
  });

  /// Muestra la pildora si existe para `topicId` y aun no fue vista. Marca
  /// como vista al cerrar mediante "OK" o "No mostrar otra vez".
  ///
  /// Devuelve true si llego a mostrarla, false en caso contrario.
  static Future<bool> maybeShow({
    required BuildContext context,
    required String topicId,
  }) async {
    final pill = pillForTopic(topicId);
    if (pill == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final key = '$kDgtPillSeenPrefix$topicId';
    if (prefs.getBool(key) ?? false) return false;

    if (!context.mounted) return false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DgtTopicPillSheet(topicId: topicId, pill: pill),
    );
    return true;
  }

  @override
  State<DgtTopicPillSheet> createState() => _DgtTopicPillSheetState();
}

class _DgtTopicPillSheetState extends State<DgtTopicPillSheet> {
  bool _dontShowAgain = false;

  Future<void> _markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      '$kDgtPillSeenPrefix${widget.topicId}',
      true,
    );
  }

  Future<void> _onStart() async {
    if (_dontShowAgain) await _markSeen();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _onDismissPermanent() async {
    await _markSeen();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final pill = widget.pill;
    final accent = const Color(0xFF7C5CFF);
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1B1A23),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    pill.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      pill.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Repaso rapido antes de practicar',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  children: [
                    ...pill.bullets.map(
                      (b) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: accent,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                b,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (pill.mnemonic != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lightbulb_rounded,
                              color: accent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                pill.mnemonic!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _dontShowAgain,
                    onChanged: (v) =>
                        setState(() => _dontShowAgain = v ?? false),
                  ),
                  const Expanded(
                    child: Text(
                      'No mostrar otra vez',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _onDismissPermanent,
                      child: const Text('Saltar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _onStart,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('OK, empezar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
