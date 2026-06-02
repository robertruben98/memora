import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/widgets/app_state_view.dart';

import '../../data/repositories/dgt_repository.dart';
import 'dgt_hard_challenge_screen.dart';
import 'dgt_practice_screen.dart';
import 'dgt_settings.dart';
import 'dgt_subtopic_tutorial_screen.dart';
import 'dgt_topic_stats_screen.dart';
import 'dgt_tutorial_seen_provider.dart';
import 'dgt_tutorials_catalog.dart';

/// Selector de bloques tematicos DGT para modo "Practica por tema".
///
/// Aditivo respecto al simulacro: NO toca cronometro ni envia al servidor
/// nada nuevo. Reusa [DgtRepository.fetchTopics] (con fallback local si el
/// endpoint /dgt/topics todavia no existe).
class DgtTopicsScreen extends ConsumerStatefulWidget {
  const DgtTopicsScreen({super.key});

  @override
  ConsumerState<DgtTopicsScreen> createState() => _DgtTopicsScreenState();
}

class _DgtTopicsScreenState extends ConsumerState<DgtTopicsScreen> {
  late Future<List<DgtTopic>> _future;
  DgtHardChallengeLastAttempt? _lastHardAttempt;

  @override
  void initState() {
    super.initState();
    _future = ref.read(dgtRepositoryProvider).fetchTopics();
    _loadLastHardAttempt();
  }

  Future<void> _loadLastHardAttempt() async {
    final last = await DgtHardChallengeScreen.readLastAttempt();
    if (!mounted) return;
    setState(() => _lastHardAttempt = last);
  }

  Future<void> _refresh() async {
    final next = ref.read(dgtRepositoryProvider).fetchTopics();
    setState(() => _future = next);
    await next;
    await _loadLastHardAttempt();
  }

  Future<void> _openHardChallenge() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DgtHardChallengeScreen(),
      ),
    );
    // Refrescar badge "ultimo reto" al volver.
    await _loadLastHardAttempt();
  }

  Future<void> _onPickTopic(DgtTopic topic) async {
    final limit = await _askQuestionCount(topic);
    if (limit == null) return;
    if (!mounted) return;

    // Issue #153 (dgt-ux): intercept para mostrar tutorial pre-quiz.
    // Reglas (silent fallback en cualquier "false"):
    //   - toggle global desactivado -> saltar
    //   - topic ya marcado "no mostrar mas" -> saltar
    //   - sin entrada en catalogo -> saltar
    // Cualquier error en SharedPreferences/settings degrada a "saltar"
    // — no bloqueamos el quiz por fallos del tutorial.
    await _maybeShowTutorial(topic);
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DgtPracticeScreen(topic: topic, limit: limit),
      ),
    );
  }

  Future<void> _maybeShowTutorial(DgtTopic topic) async {
    final tutorial = lookupDgtTutorial(topic.id);
    if (tutorial == null) return;

    final settingsAsync = ref.read(dgtSettingsProvider);
    final settings = settingsAsync.asData?.value ?? DgtSettings.defaults;
    if (!settings.showSubtopicTutorial) return;

    final store = ref.read(dgtTutorialSeenStoreProvider);
    final seen = await store.hasSeen(topic.id);
    if (seen) return;
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<DgtTutorialResult>(
        builder: (_) => DgtSubtopicTutorialScreen(
          topicId: topic.id,
          topicName: topic.name,
          tutorial: tutorial,
        ),
      ),
    );
    // No miramos el result: cualquier camino lleva al quiz. `suppress` ya
    // persistio via DgtTutorialSeenStore dentro de la screen.
  }

  Future<int?> _askQuestionCount(DgtTopic topic) {
    final max = topic.questionCount;
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: context.c.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: ctx.c.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  topic.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '¿Cuantas preguntas quieres practicar?',
                  style: TextStyle(
                    fontSize: 13,
                    color: ctx.c.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                _CountOption(
                  label: '10 preguntas',
                  subtitle: 'Repaso rapido',
                  enabled: max == 0 || max >= 1,
                  onTap: () => Navigator.pop(ctx, 10),
                ),
                _CountOption(
                  label: '20 preguntas',
                  subtitle: 'Sesion media',
                  enabled: max == 0 || max >= 1,
                  onTap: () => Navigator.pop(ctx, 20),
                ),
                _CountOption(
                  label: 'Todas',
                  subtitle: max > 0 ? 'Bloque completo ($max)' : 'Bloque completo',
                  enabled: true,
                  onTap: () => Navigator.pop(ctx, -1),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Practica por tema'),
        actions: [
          IconButton(
            tooltip: 'Estadisticas por tema',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DgtTopicStatsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.insights_outlined),
          ),
        ],
      ),
      body: FutureBuilder<List<DgtTopic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return AppStateView.loading();
          }
          if (snap.hasError) {
            return _ErrorView(
              message: 'No se pudieron cargar los temas: ${snap.error}',
              onRetry: _refresh,
            );
          }
          final topics = snap.data ?? const <DgtTopic>[];
          if (topics.isEmpty) {
            return _ErrorView(
              message: 'No hay temas disponibles. El banco local podria '
                  'estar vacio o el backend no responde.',
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
              // +1: tile "Reto dificultad alta" antes de la lista de temas.
              itemCount: topics.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return _HardChallengeTile(
                    lastAttempt: _lastHardAttempt,
                    onTap: _openHardChallenge,
                  );
                }
                final t = topics[i - 1];
                return _TopicTile(topic: t, onTap: () => _onPickTopic(t));
              },
            ),
          );
        },
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  final DgtTopic topic;
  final VoidCallback onTap;

  const _TopicTile({required this.topic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.c.surfaceMuted,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.brand,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      topic.questionCount > 0
                          ? '${topic.questionCount} preguntas'
                          : 'Sin contador',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _CountOption({
    required this.label,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.c.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tile "Reto dificultad alta" (issue #78). Icono fuego + subtitulo
/// "10 preguntas dificiles - 5 min" y, si existe intento previo, badge
/// con el ultimo score.
class _HardChallengeTile extends StatelessWidget {
  final DgtHardChallengeLastAttempt? lastAttempt;
  final VoidCallback onTap;

  const _HardChallengeTile({required this.lastAttempt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF5C5C), Color(0xFFFF8A4F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reto dificultad alta',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '10 preguntas dificiles - 5 min',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (lastAttempt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Tu ultimo reto: '
                        '${lastAttempt!.correct}/${lastAttempt!.total}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
