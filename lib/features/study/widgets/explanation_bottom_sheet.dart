import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/memora_card.dart';

/// BottomSheet modal mostrado al fallar una card (DGT issue #42).
///
/// Refuerzo didactico inmediato con:
/// - Enunciado y respuesta correcta.
/// - `explanation` (markdown lite) o fallback generico DGT.
/// - `normativaRef` (ej "Art. 21 RGCir") destacado.
/// - `sourceUrl` (link externo a dgt.es u otra fuente).
///
/// Es aditivo: si la card no es DGT, los campos extra son null y el modal
/// usa el fallback. No bloquea avanzar (boton "Entendido" cierra).
class ExplanationBottomSheet extends StatelessWidget {
  final MemoraCard card;

  const ExplanationBottomSheet({super.key, required this.card});

  static const _fallbackUrl = 'https://www.dgt.es/';
  static const _fallbackText =
      'Sin explicacion adicional. Revisa el Reglamento General de '
      'Circulacion en la web oficial de la DGT.';

  /// Conveniencia: muestra el modal y devuelve cuando se cierra.
  static Future<void> show(BuildContext context, MemoraCard card) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => ExplanationBottomSheet(card: card),
    );
  }

  // Sin url_launcher en pubspec: copiamos al portapapeles y avisamos.
  // Migracion a launchUrl trivial si se anade la dependencia.
  Future<void> _openSource(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Enlace copiado: $url'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final explanation = card.explanation?.trim();
    final hasExplanation = explanation != null && explanation.isNotEmpty;
    final normativa = card.normativaRef?.trim();
    final sourceUrl = card.sourceUrl?.trim();
    final hasSource = sourceUrl != null && sourceUrl.isNotEmpty;
    final effectiveUrl = hasSource ? sourceUrl : _fallbackUrl;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          14,
          18,
          18 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle.
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  color: const Color(0xFFFF8A4F),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Repasemos esta',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Enunciado.
            Text(
              card.front,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            // Respuesta correcta destacada.
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: const Color(0xFF4FFFB0).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF4FFFB0).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF4FFFB0),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      card.back,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Normativa (si la hay).
            if (normativa != null && normativa.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C5CFF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  normativa,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7C5CFF),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Explicacion o fallback.
            Text(
              hasExplanation ? explanation : _fallbackText,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
            const SizedBox(height: 16),
            // Link a fuente externa.
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _openSource(context, effectiveUrl),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        hasSource ? 'Ver fuente' : 'Web oficial DGT',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            // Boton primario.
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pop();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C5CFF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Entendido',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
