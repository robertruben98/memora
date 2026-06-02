import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/theme/dgt_status_colors.dart';
import 'package:memora/core/widgets/app_state_view.dart';
import 'package:video_player/video_player.dart';

import '../../data/api/api_client.dart';
import '../../data/repositories/dgt_repository.dart';

/// Player de pregunta DGT 2026 con video de percepcion de riesgo (issue #77).
///
/// Flow:
/// 1. Reproduce el video automaticamente (sin sonido obligatorio).
/// 2. Al terminar el video, las opciones a/b/c aparecen habilitadas (mientras
///    el video reproduce, las opciones siguen visibles pero el usuario las
///    puede pulsar tambien antes de finalizar el video, igual que en el
///    examen real).
/// 3. Tap en una opcion = feedback inmediato (correcto/incorrecto) +
///    explicacion textual debajo. Las demas opciones quedan bloqueadas.
///
/// Aditivo: no toca el flow del simulacro cronometrado, ni endpoints. Si
/// `video_player` fallara en init (codec no soportado, url 404), muestra
/// fallback con thumbnail + opciones (usuario puede contestar igual).
class DgtVideoQuestionPlayerScreen extends ConsumerStatefulWidget {
  final DgtVideoQuestion question;

  const DgtVideoQuestionPlayerScreen({super.key, required this.question});

  @override
  ConsumerState<DgtVideoQuestionPlayerScreen> createState() =>
      _DgtVideoQuestionPlayerScreenState();
}

class _DgtVideoQuestionPlayerScreenState
    extends ConsumerState<DgtVideoQuestionPlayerScreen> {
  VideoPlayerController? _controller;

  /// `null` = aun no respondida, sino letra elegida ('a'/'b'/'c').
  String? _picked;

  /// Error de init del video (codec, 404, etc). Si no es null, mostramos
  /// fallback con thumbnail estatica.
  Object? _videoError;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    final api = ref.read(apiClientProvider);
    final rawUrl = widget.question.videoUrl;
    final url = api.remoteUrlFor(rawUrl) ?? rawUrl;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme.isEmpty) {
      _videoError = 'URL invalida';
      return;
    }
    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _initialized = true);
      controller.setLooping(false);
      controller.play();
    }).catchError((Object err, _) {
      if (!mounted) return;
      setState(() => _videoError = err);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onPick(String letter) {
    if (_picked != null) return;
    setState(() => _picked = letter);
    // Pausa el video cuando el usuario responde (similar al examen real:
    // analiza la situacion -> contesta -> ve explicacion).
    _controller?.pause();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final picked = _picked;
    final answered = picked != null;
    final isCorrect = answered && picked == q.correct;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video DGT 2026'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _VideoArea(
              controller: _controller,
              error: _videoError,
              initialized: _initialized,
              thumbnailPath: q.thumbnailUrl,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFE04FFF).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'VIDEO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFE04FFF),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            DgtVideoQuestionLabels.labelFor(q.riskType),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.c.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      q.statement,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AnswerOption(
                      letter: 'a',
                      text: q.optionA,
                      picked: picked,
                      correct: q.correct,
                      onTap: () => _onPick('a'),
                    ),
                    _AnswerOption(
                      letter: 'b',
                      text: q.optionB,
                      picked: picked,
                      correct: q.correct,
                      onTap: () => _onPick('b'),
                    ),
                    _AnswerOption(
                      letter: 'c',
                      text: q.optionC,
                      picked: picked,
                      correct: q.correct,
                      onTap: () => _onPick('c'),
                    ),
                    if (answered) ...[
                      const SizedBox(height: 14),
                      _ExplanationCard(
                        question: q,
                        isCorrect: isCorrect,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helpers de etiquetas i18n para los risk_types DGT.
class DgtVideoQuestionLabels {
  static String labelFor(String riskType) {
    switch (riskType) {
      case 'peaton_oculto':
        return 'Peaton oculto';
      case 'ciclista_cruce':
        return 'Ciclista en cruce';
      case 'vehiculo_tapa_vision':
        return 'Vehiculo tapa vision';
      case 'semaforo_ambar':
        return 'Semaforo ambar';
      case 'otro':
        return 'Otra situacion';
      default:
        return riskType;
    }
  }
}

class _VideoArea extends ConsumerWidget {
  final VideoPlayerController? controller;
  final Object? error;
  final bool initialized;
  final String? thumbnailPath;

  const _VideoArea({
    required this.controller,
    required this.error,
    required this.initialized,
    required this.thumbnailPath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget child;
    if (error != null) {
      child = _FallbackThumb(thumbnailPath: thumbnailPath, errorText: '$error');
    } else if (!initialized || controller == null) {
      child = AppStateView.loading();
    } else {
      child = AspectRatio(
        aspectRatio: controller!.value.aspectRatio == 0
            ? 16 / 9
            : controller!.value.aspectRatio,
        child: VideoPlayer(controller!),
      );
    }

    return Container(
      width: double.infinity,
      color: Colors.black,
      constraints: const BoxConstraints(maxHeight: 280),
      child: Center(child: child),
    );
  }
}

class _FallbackThumb extends ConsumerWidget {
  final String? thumbnailPath;
  final String errorText;

  const _FallbackThumb({required this.thumbnailPath, required this.errorText});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientProvider);
    final t = thumbnailPath;
    final url = t != null && t.isNotEmpty ? (api.remoteUrlFor(t) ?? t) : null;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (url != null)
          SizedBox(
            height: 160,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.videocam_off_outlined,
                color: Colors.white54,
                size: 48,
              ),
            ),
          )
        else
          const Icon(
            Icons.videocam_off_outlined,
            color: Colors.white54,
            size: 48,
          ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Video no disponible. Puedes contestar igual.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _AnswerOption extends StatelessWidget {
  final String letter;
  final String text;
  final String? picked;
  final String correct;
  final VoidCallback onTap;

  const _AnswerOption({
    required this.letter,
    required this.text,
    required this.picked,
    required this.correct,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final answered = picked != null;
    final selected = picked == letter;
    final isCorrectOption = letter == correct;

    Color bg = context.c.surfaceMuted;
    Color iconBg = context.c.surfaceMuted;
    Color iconFg = context.c.textPrimary;

    if (answered) {
      if (isCorrectOption) {
        bg = DgtStatusColors.success.withValues(alpha: 0.18);
        iconBg = DgtStatusColors.success;
        iconFg = Colors.black;
      } else if (selected) {
        bg = DgtStatusColors.error.withValues(alpha: 0.18);
        iconBg = DgtStatusColors.error;
        iconFg = Colors.white;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: answered ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
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
                    style: const TextStyle(fontSize: 15, height: 1.35),
                  ),
                ),
                if (answered && isCorrectOption)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: DgtStatusColors.success,
                    size: 20,
                  )
                else if (answered && selected && !isCorrectOption)
                  const Icon(
                    Icons.cancel_rounded,
                    color: DgtStatusColors.error,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  final DgtVideoQuestion question;
  final bool isCorrect;

  const _ExplanationCard({required this.question, required this.isCorrect});

  static const _fallbackText =
      'Sin explicacion adicional. En videos de percepcion de riesgo la clave '
      'es anticipar la situacion antes de que ocurra.';

  @override
  Widget build(BuildContext context) {
    final explanation = question.explanation.trim();
    final txt = explanation.isNotEmpty ? explanation : _fallbackText;
    final accent =
        isCorrect ? DgtStatusColors.success : DgtStatusColors.accentOrange;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect
                    ? Icons.check_circle_rounded
                    : Icons.menu_book_rounded,
                color: accent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'Correcto' : 'Repasemos',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Respuesta correcta: ${question.correct.toUpperCase()}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            txt,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: context.c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
