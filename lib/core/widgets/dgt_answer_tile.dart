import 'package:flutter/material.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';

/// Tile de opcion de respuesta unificado para los modos quiz DGT.
///
/// Unifica el patron `_AnswerTile` que estaba triplicado en
/// `DgtPracticeScreen`, `DgtQuickReviewScreen` y `DgtHardChallengeScreen`:
/// una fila con un recuadro de 28x28 (la letra a/b/c o un texto corto) + el
/// texto de la opcion, dentro de un `Material` + `InkWell` con radio 12 y
/// padding inferior de 10.
///
/// Soporta dos modos de pintado, cubriendo las 3 implementaciones previas:
///
/// 1. Modo seleccion simple ([graded] = false): resalta la opcion elegida
///    con [accentColor]. Es el modo de Quick Review (brand) y Hard Challenge
///    (accentOrange).
/// 2. Modo corregido ([graded] = true): una vez [answered], pinta la opcion
///    correcta en verde ([DgtStatusColors.success]) con check, y la elegida
///    incorrecta en rojo ([DgtStatusColors.error]) con cancel. Es el modo de
///    Practice (feedback inmediato).
///
/// En modo corregido el `onTap` se desactiva automaticamente cuando
/// [answered] es true (replica el comportamiento de Practice).
class DgtAnswerTile extends StatelessWidget {
  /// Letra (`a`/`b`/`c`) o texto corto que va dentro del recuadro inicial.
  /// Se renderiza en mayuscula. Si la longitud es >1 caracter se sigue
  /// mostrando tal cual (no hay validacion: la letra es libre).
  final String letter;

  /// Texto de la opcion de respuesta.
  final String text;

  /// Tap sobre la opcion. En modo corregido se ignora una vez [answered].
  final VoidCallback onTap;

  /// Color de resalte de la opcion seleccionada en modo seleccion simple.
  /// Por defecto [AppColors.brand]. Ignorado en modo corregido.
  final Color accentColor;

  /// Color del texto/letra sobre [accentColor] cuando la opcion esta
  /// seleccionada en modo simple. Si es null se usa `context.c.onAccent`
  /// para el recuadro de la letra y el texto principal queda con su color
  /// por defecto (replica Quick Review). Hard Challenge pasa
  /// `Colors.white` para el recuadro.
  final Color? onAccentColor;

  /// Si la opcion esta seleccionada (modo seleccion simple).
  final bool selected;

  /// Activa el modo corregido (feedback success/error). Cuando es true se
  /// usan [picked]/[correct]/[answered] en lugar de [selected]/[accentColor].
  final bool graded;

  /// (Modo corregido) letra elegida por el usuario, null si sin responder.
  final String? picked;

  /// (Modo corregido) letra correcta de la pregunta.
  final String? correct;

  /// (Modo corregido) si la pregunta ya fue respondida. Al ser true se
  /// pintan los estados success/error y se desactiva el tap.
  final bool answered;

  /// Altura minima del tile (tap-target accesible). Quick Review y Hard
  /// Challenge usan 48; Practice no fijaba minimo (null).
  final double? minHeight;

  const DgtAnswerTile({
    super.key,
    required this.letter,
    required this.text,
    required this.onTap,
    this.accentColor = AppColors.brand,
    this.onAccentColor,
    this.selected = false,
    this.minHeight,
  })  : graded = false,
        picked = null,
        correct = null,
        answered = false;

  /// Constructor del modo corregido (feedback inmediato tipo Practice).
  const DgtAnswerTile.graded({
    super.key,
    required this.letter,
    required this.text,
    required this.onTap,
    required this.picked,
    required this.correct,
    required this.answered,
    this.minHeight,
  })  : graded = true,
        accentColor = AppColors.brand,
        onAccentColor = null,
        selected = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    // Resolucion de colores segun modo.
    Color bg;
    Color iconBg;
    Color iconFg;
    Color? textColor;
    Widget? trailing;
    bool tapEnabled = true;

    if (graded) {
      final isSelected = picked != null && picked == letter;
      final isCorrectOption = letter == correct;
      bg = c.surfaceMuted;
      iconBg = c.surfaceMuted;
      iconFg = c.textPrimary;
      if (answered) {
        tapEnabled = false;
        if (isCorrectOption) {
          bg = DgtStatusColors.success.withValues(alpha: 0.18);
          iconBg = DgtStatusColors.success;
          iconFg = Colors.black;
          trailing = const Icon(
            Icons.check_circle_rounded,
            color: DgtStatusColors.success,
            size: 20,
          );
        } else if (isSelected) {
          bg = DgtStatusColors.error.withValues(alpha: 0.18);
          iconBg = DgtStatusColors.error;
          iconFg = Colors.white;
          trailing = const Icon(
            Icons.cancel_rounded,
            color: DgtStatusColors.error,
            size: 20,
          );
        }
      } else if (isSelected) {
        bg = AppColors.brand;
      }
    } else {
      bg = selected ? accentColor : c.surfaceMuted;
      iconBg = selected ? (onAccentColor ?? c.onAccent) : c.border;
      iconFg = selected ? accentColor : c.textPrimary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: tapEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: minHeight != null
                ? BoxConstraints(minHeight: minHeight!)
                : null,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    letter.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: iconFg,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      color: textColor,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
