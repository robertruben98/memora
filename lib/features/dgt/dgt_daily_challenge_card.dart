import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/dgt_repository.dart';
import 'dgt_practice_screen.dart';
import 'dgt_prediction.dart';

/// Issue #85 (dgt-ux): "Reto de hoy" - card en Home que sugiere el tema
/// con peor accuracy del usuario y ofrece un mini-quiz de 10 preguntas.
///
/// Aditivo: no reemplaza ningun banner existente. Si no hay datos suficientes
/// (<kDgtMinReviewsForChallenge respuestas) muestra una card alternativa
/// generica "Empieza tu primer reto". Cachea la seleccion del dia en
/// SharedPreferences con key fechada (YYYY-MM-DD) para que no cambie de
/// tema durante el dia.

/// Minimo de respuestas totales para mostrar reto personalizado.
/// Bajo este umbral se muestra reto generico.
const int kDgtMinReviewsForChallenge = 20;

/// Umbral por encima del cual consideramos que un tema "ya esta dominado"
/// (0..100). Si TODOS los temas superan este umbral, en lugar del tema mas
/// debil se elige el que tiene MENOS respuestas (para fomentar exploracion).
const double kDgtMasteredAccuracy = 70.0;

/// Numero de preguntas del mini-quiz del reto diario.
const int kDgtDailyChallengeLimit = 10;

/// Prefijo de la key de SharedPreferences donde cacheamos el topicId del
/// "tema del dia". La clave completa es `kDgtDailyChallengePrefix + YYYY-MM-DD`.
const String kDgtDailyChallengePrefix = 'dgt_daily_challenge_topic_';

/// Formatea fecha como `YYYY-MM-DD` (clave del cache diario, sin TZ).
String dgtDailyChallengeKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$kDgtDailyChallengePrefix$y-$m-$d';
}

/// Selecciona el tema sugerido para el reto del dia segun la heuristica
/// del issue #85:
/// - Si hay tema con accuracy < kDgtMasteredAccuracy: el mas debil.
/// - Si todos >= umbral: el de menor `totalAnswered` (exploracion).
/// - Si la lista esta vacia: null (caller muestra reto generico).
///
/// Aislada como funcion pura para poder testear sin Flutter.
DgtTopicStat? pickDgtDailyChallengeTopic(List<DgtTopicStat> stats) {
  if (stats.isEmpty) return null;
  final withData = stats.where((s) => s.totalAnswered > 0).toList();
  if (withData.isEmpty) return null;
  final weakBelowThreshold = withData
      .where((s) => s.accuracyPct < kDgtMasteredAccuracy)
      .toList();
  if (weakBelowThreshold.isNotEmpty) {
    weakBelowThreshold.sort((a, b) => a.accuracyPct.compareTo(b.accuracyPct));
    return weakBelowThreshold.first;
  }
  // Todos dominados: elegir el menos practicado.
  withData.sort((a, b) => a.totalAnswered.compareTo(b.totalAnswered));
  return withData.first;
}

/// Lee el topicId cacheado para hoy, si existe. Best-effort; ante error
/// devuelve null y la card recalcula.
Future<String?> readDailyChallengeCache(DateTime now) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(dgtDailyChallengeKey(now));
  } catch (_) {
    return null;
  }
}

/// Persiste el topicId del reto de hoy. Best-effort.
Future<void> writeDailyChallengeCache(DateTime now, String topicId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(dgtDailyChallengeKey(now), topicId);
  } catch (_) {
    // ignore
  }
}

/// Card Home con el reto contextual de hoy. Aditivo respecto a
/// [_DgtBanner] / [_DgtExamBanner]: se posiciona despues del banner de
/// urgencia y antes del listado de mazos.
class DgtDailyChallengeCard extends ConsumerStatefulWidget {
  const DgtDailyChallengeCard({super.key});

  @override
  ConsumerState<DgtDailyChallengeCard> createState() =>
      _DgtDailyChallengeCardState();
}

class _DgtDailyChallengeCardState
    extends ConsumerState<DgtDailyChallengeCard> {
  String? _cachedTopicId;
  bool _cacheChecked = false;

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  Future<void> _loadCache() async {
    final cached = await readDailyChallengeCache(DateTime.now());
    if (!mounted) return;
    setState(() {
      _cachedTopicId = cached;
      _cacheChecked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_cacheChecked) return const SizedBox.shrink();
    final statsAsync = ref.watch(dgtTopicStatsProvider);
    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (stats) {
        final total = stats.fold<int>(0, (acc, s) => acc + s.totalAnswered);
        if (total < kDgtMinReviewsForChallenge) {
          return _GenericChallengeTile(
            onTap: () => _navigateGeneric(context),
          );
        }
        // Resuelve tema: si hay cache valido, usarlo; si no, recalcular.
        DgtTopicStat? topic;
        if (_cachedTopicId != null) {
          topic = stats.firstWhere(
            (s) => s.topicId == _cachedTopicId,
            orElse: () => const DgtTopicStat(
              topicId: '',
              totalAnswered: 0,
              correct: 0,
              accuracyPct: 0,
            ),
          );
          if (topic.topicId.isEmpty) topic = null;
        }
        topic ??= pickDgtDailyChallengeTopic(stats);
        if (topic == null) {
          return _GenericChallengeTile(
            onTap: () => _navigateGeneric(context),
          );
        }
        // Persistir seleccion solo si no estaba cacheada.
        if (_cachedTopicId == null) {
          writeDailyChallengeCache(DateTime.now(), topic.topicId);
        }
        return _PersonalizedChallengeTile(
          stat: topic,
          onTap: () => _navigatePersonalized(context, topic!),
        );
      },
    );
  }

  Future<void> _navigatePersonalized(
    BuildContext context,
    DgtTopicStat stat,
  ) async {
    final navigator = Navigator.of(context);
    final name = stat.topicName ?? stat.topicId;
    final topic = DgtTopic(id: stat.topicId, name: name);
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => DgtPracticeScreen(
          topic: topic,
          limit: kDgtDailyChallengeLimit,
        ),
      ),
    );
  }

  Future<void> _navigateGeneric(BuildContext context) async {
    // Reto generico: practica sobre el primer tema disponible. Best-effort,
    // sin bloquear: si no hay topics no navegamos.
    final navigator = Navigator.of(context);
    final topics = await ref.read(dgtRepositoryProvider).fetchTopics();
    if (!mounted || topics.isEmpty) return;
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => DgtPracticeScreen(
          topic: topics.first,
          limit: kDgtDailyChallengeLimit,
        ),
      ),
    );
  }
}

class _PersonalizedChallengeTile extends StatelessWidget {
  final DgtTopicStat stat;
  final VoidCallback onTap;

  const _PersonalizedChallengeTile({required this.stat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accuracy = stat.accuracyPct.round();
    final name = stat.topicName ?? stat.topicId;
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
                  color: const Color(0xFFFF8A65).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Color(0xFFFF8A65),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reto de hoy: $name',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tu accuracy: $accuracy%. Mejoralo con $kDgtDailyChallengeLimit preguntas.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFFF8A65),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenericChallengeTile extends StatelessWidget {
  final VoidCallback onTap;
  const _GenericChallengeTile({required this.onTap});

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
                  color: const Color(0xFF7C5CFF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: Color(0xFF7C5CFF),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Empieza tu primer reto',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Responde algunas preguntas para que personalicemos tu reto diario.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xA6FFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF7C5CFF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
