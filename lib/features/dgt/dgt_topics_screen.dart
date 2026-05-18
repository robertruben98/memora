import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/dgt_repository.dart';
import 'dgt_practice_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _future = ref.read(dgtRepositoryProvider).fetchTopics();
  }

  Future<void> _refresh() async {
    final next = ref.read(dgtRepositoryProvider).fetchTopics();
    setState(() => _future = next);
    await next;
  }

  Future<void> _onPickTopic(DgtTopic topic) async {
    final limit = await _askQuestionCount(topic);
    if (limit == null) return;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DgtPracticeScreen(topic: topic, limit: limit),
      ),
    );
  }

  Future<int?> _askQuestionCount(DgtTopic topic) {
    final max = topic.questionCount;
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF1A1A22),
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
                      color: Colors.white.withValues(alpha: 0.2),
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
                    color: Colors.white.withValues(alpha: 0.7),
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
      ),
      body: FutureBuilder<List<DgtTopic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: topics.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final t = topics[i];
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
      color: Colors.white.withValues(alpha: 0.06),
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
                  color: const Color(0xFF7C5CFF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Color(0xFF7C5CFF),
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
                        color: Colors.white.withValues(alpha: 0.65),
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
        color: Colors.white.withValues(alpha: 0.06),
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
                          color: Colors.white.withValues(alpha: 0.65),
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
