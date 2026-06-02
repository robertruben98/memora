import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/widgets/app_state_view.dart';

import '../../data/api/api_client.dart';
import '../../data/repositories/dgt_repository.dart';
import 'dgt_video_question_player_screen.dart';

/// Pantalla "Videos de percepcion de riesgo" del examen DGT 2026 (issue #77).
///
/// Lista preguntas con video asociado (peaton oculto, ciclista en interseccion,
/// vehiculo tapa vision, etc) consumiendo `GET /dgt/video-questions`. Aditiva:
/// no toca el flow del simulacro cronometrado existente, solo expone el nuevo
/// formato que se incorpora al examen DGT 2026.
///
/// Estados cubiertos:
/// - loading: spinner.
/// - error de red: mensaje + retry.
/// - empty (backend devuelve 0 videos): mensaje "Proximamente: videos
///   oficiales DGT 2026".
/// - listado: cards con thumbnail, statement, badge "VIDEO" y risk type.
///
/// Tap en una card abre [DgtVideoQuestionPlayerScreen] con el video.
class DgtVideoQuestionsScreen extends ConsumerStatefulWidget {
  /// Limite de preguntas a solicitar al backend (1..30). Default 10.
  final int limit;

  const DgtVideoQuestionsScreen({super.key, this.limit = 10});

  @override
  ConsumerState<DgtVideoQuestionsScreen> createState() =>
      _DgtVideoQuestionsScreenState();
}

class _DgtVideoQuestionsScreenState
    extends ConsumerState<DgtVideoQuestionsScreen> {
  late Future<List<DgtVideoQuestion>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<DgtVideoQuestion>> _load() {
    return ref
        .read(dgtRepositoryProvider)
        .fetchVideoQuestions(limit: widget.limit);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Videos de percepcion de riesgo'),
      ),
      body: FutureBuilder<List<DgtVideoQuestion>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _LoadingSkeleton();
          }
          if (snap.hasError) {
            return AppStateView.error(
              'No se pudo cargar la lista: ${snap.error}',
              onRetry: _refresh,
            );
          }
          final items = snap.data ?? const <DgtVideoQuestion>[];
          if (items.isEmpty) {
            return AppStateView.empty(
              icon: Icons.movie_filter_outlined,
              title: 'Proximamente: videos oficiales DGT 2026',
              message:
                  'La DGT incorpora videos de percepcion de riesgo al examen '
                  'teorico en 2026. En cuanto el banco oficial se publique, las '
                  'preguntas apareceran aqui.',
              onRetry: _refresh,
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                24 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final q = items[i];
                return DgtVideoQuestionTile(
                  question: q,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            DgtVideoQuestionPlayerScreen(question: q),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Card publica con thumbnail (si existe), enunciado y badge "VIDEO".
/// Exportada para tests widget.
class DgtVideoQuestionTile extends ConsumerWidget {
  final DgtVideoQuestion question;
  final VoidCallback onTap;

  const DgtVideoQuestionTile({
    super.key,
    required this.question,
    required this.onTap,
  });

  /// Etiqueta legible en espanol para cada risk_type del backend.
  static String labelForRiskType(String riskType) {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientProvider);
    final thumbUrl = question.thumbnailUrl;
    final resolvedThumb = thumbUrl != null && thumbUrl.isNotEmpty
        ? (api.remoteUrlFor(thumbUrl) ?? thumbUrl)
        : null;

    return Material(
      color: context.c.surfaceElevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 92,
                  height: 64,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (resolvedThumb != null)
                        Image.network(
                          resolvedThumb,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _ThumbPlaceholder(),
                        )
                      else
                        _ThumbPlaceholder(),
                      Container(
                        color: Colors.black.withValues(alpha: 0.22),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            labelForRiskType(question.riskType),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.c.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      question.statement,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.c.surfaceMuted,
      alignment: Alignment.center,
      child: Icon(
        Icons.videocam_off_outlined,
        color: context.c.textMuted,
        size: 22,
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: 4,
      itemBuilder: (_, _) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 88,
        decoration: BoxDecoration(
          color: context.c.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
