import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/widgets/app_state_view.dart';

import '../../data/repositories/dgt_repository.dart';
import 'dgt_recurrent_failures_screen.dart' show DgtFailCountBadge;

/// Pantalla DGT "Top 5 fallos del mes" (issue #190, dgt-ux).
///
/// Muestra las 5 preguntas DGT mas falladas (recurrent-failures, ventana
/// backend 60 dias) + un banner de insight automatico cuando >=3 de esas
/// preguntas contienen palabras-clave trampa (siempre/nunca/excepto/solo/
/// obligatorio/prohibido).
///
/// Pensada como vista pivot "examen DGT": las autoescuelas (autoescuelago,
/// Velasco, Dribo) reportan que el predictor mas fiable del examen oficial
/// son los fallos recientes concentrados en preguntas trampa.
///
/// Aditivo: reusa [DgtRepository.fetchRecurrentFailures] (BE#149) con
/// `limit=5`. No agrega endpoints nuevos, no toca cache ni tile registry
/// de otros tiles. El tile propio se registra en `kDgtTileRegistry`.
class DgtTopFailuresScreen extends ConsumerStatefulWidget {
  const DgtTopFailuresScreen({super.key});

  @override
  ConsumerState<DgtTopFailuresScreen> createState() =>
      _DgtTopFailuresScreenState();
}

class _DgtTopFailuresScreenState extends ConsumerState<DgtTopFailuresScreen> {
  late Future<List<DgtRecurrentFailureItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<DgtRecurrentFailureItem>> _load() {
    final repo = ref.read(dgtRepositoryProvider);
    // Issue #190: top 5 del mes. Backend solo expone ventana 60d, limit
    // se clamp [1, 50]. Pedimos exactamente 5 y dejamos al BE ordenar
    // por fail_count DESC.
    return repo.fetchRecurrentFailures(minFails: 2, limit: 5);
  }

  void _reload() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Top 5 fallos del mes'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<List<DgtRecurrentFailureItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _LoadingSkeleton();
          }
          final items = snap.data ?? const <DgtRecurrentFailureItem>[];
          if (items.isEmpty) {
            return AppStateView.empty(
              icon: Icons.celebration_rounded,
              title: 'Sin fallos en los ultimos 30 dias',
              message: 'Sigue asi!',
            );
          }
          final trickCount = countTrickKeywords(items);
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              children: [
                if (trickCount >= 3)
                  DgtTrickInsightBanner(
                    trickCount: trickCount,
                    total: items.length,
                  ),
                const SizedBox(height: 8),
                for (final it in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _TopFailureTile(item: it),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Detector de palabras-clave trampa en enunciados DGT (issue #190).
///
/// Palabras absolutas que casi siempre invalidan un enunciado en el examen
/// teorico DGT: `siempre`, `nunca`, `excepto`, `solo`, `obligatorio`,
/// `prohibido`. Coincidencia case-insensitive con word boundary heuristico
/// (split por espacios/puntuacion) para evitar falsos positivos como
/// "solomillo" matchando "solo".
///
/// Devuelve el numero de items cuyo statement contiene >=1 palabra trampa.
int countTrickKeywords(List<DgtRecurrentFailureItem> items) {
  var n = 0;
  for (final it in items) {
    if (containsTrickKeyword(it.question.statement)) n++;
  }
  return n;
}

/// True si [statement] contiene cualquier keyword trampa (siempre/nunca/
/// excepto/solo/obligatorio/prohibido). Public para tests unitarios.
bool containsTrickKeyword(String statement) {
  if (statement.isEmpty) return false;
  // Lowercase + normalizar tildes basicas (DGT statements suelen tener
  // acentos): solo nos importa el match de palabras absolutas en raiz.
  final lower = statement.toLowerCase();
  // Split por caracteres no-alfabeticos (incluye espacios, comas, puntos,
  // signos ¿?, parentesis). Esto evita "solomillo" matchee "solo".
  final tokens =
      lower.split(RegExp(r'[^a-záéíóúñü]+', unicode: true));
  for (final t in tokens) {
    if (_kTrickKeywords.contains(t)) return true;
  }
  return false;
}

const Set<String> _kTrickKeywords = {
  'siempre',
  'nunca',
  'excepto',
  'solo',
  'obligatorio',
  'prohibido',
};

/// Banner de insight "Cuidado con absolutos" (issue #190). Public para tests.
class DgtTrickInsightBanner extends StatelessWidget {
  final int trickCount;
  final int total;

  const DgtTrickInsightBanner({
    super.key,
    required this.trickCount,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB74F).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB74F), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFFFB74F), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cuidado con absolutos',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFFFFB74F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$trickCount de tus $total fallos del mes son preguntas '
                  'trampa. Lee despacio las palabras absolutas (siempre, '
                  'nunca, excepto, solo).',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: context.c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopFailureTile extends StatelessWidget {
  final DgtRecurrentFailureItem item;
  const _TopFailureTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final isTrick = containsTrickKeyword(item.question.statement);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.c.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isTrick
              ? const Color(0xFFFFB74F).withValues(alpha: 0.55)
              : context.c.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DgtFailCountBadge(count: item.failCount),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.question.statement,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
                if (isTrick) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 12, color: Color(0xFFFFB74F)),
                      const SizedBox(width: 4),
                      Text(
                        'Pregunta trampa',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFFB74F)
                              .withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) => Container(
        height: 64,
        decoration: BoxDecoration(
          color: context.c.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

