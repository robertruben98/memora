import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/api/api_client.dart';

/// Issue #138 (dgt-ux): repositorio del desglose por subtema/cluster
/// dentro de un tema DGT. Aditivo respecto a [DgtPredictionRepository];
/// no toca el endpoint /dgt/stats/topics existente.
///
/// Si el endpoint backend `GET /dgt/stats/topics/{topic_id}/subtopic-breakdown`
/// aun no esta expuesto, este repositorio degrada a una serie mock detras
/// del flag [kUseMockSubtopics]. La idea es desacoplar la entrega de la UX
/// del backlog del backend (issue dependiente sera creado por QA).

/// Activa el modo mock cuando el endpoint backend aun no existe.
/// Cuando se publique el endpoint, basta con poner esto a `false`.
const bool kUseMockSubtopics = true;

/// Stat por subtema dentro de un tema DGT.
///
/// `failPct` es % de fallos (0..100). Se prefiere "fallos" sobre "aciertos"
/// porque la UX del heatmap se centra en el rojo (donde fallar duele mas).
class DgtSubtopicStat {
  final String subtopicId;
  final String subtopicName;
  final int totalAnswered;
  final int incorrect;
  final double failPct;

  const DgtSubtopicStat({
    required this.subtopicId,
    required this.subtopicName,
    required this.totalAnswered,
    required this.incorrect,
    required this.failPct,
  });

  factory DgtSubtopicStat.fromJson(Map<String, dynamic> j) {
    final total = (j['total_answered'] as num?)?.toInt() ?? 0;
    final inc = (j['incorrect'] as num?)?.toInt() ?? 0;
    final fail = (j['fail_pct'] as num?)?.toDouble() ??
        (total > 0 ? (inc / total) * 100.0 : 0.0);
    return DgtSubtopicStat(
      subtopicId: (j['subtopic_id'] ?? '').toString(),
      subtopicName: (j['subtopic_name'] ?? j['subtopic_id'] ?? '').toString(),
      totalAnswered: total,
      incorrect: inc,
      failPct: fail.clamp(0.0, 100.0),
    );
  }
}

/// Cubo de color del heatmap segun % de fallo.
/// Verde <20, ambar 20-50, rojo >=50. Definido como enum para que la UI
/// pueda agrupar/filtrar (boton "practicar rojos").
enum DgtHeatmapBucket { green, amber, red }

DgtHeatmapBucket bucketFor(double failPct) {
  if (failPct >= 50) return DgtHeatmapBucket.red;
  if (failPct >= 20) return DgtHeatmapBucket.amber;
  return DgtHeatmapBucket.green;
}

class DgtSubtopicRepository {
  final ApiClient _api;
  DgtSubtopicRepository(this._api);

  /// Trae el desglose para un tema. Si el endpoint no existe o falla,
  /// retorna mock o lista vacia segun el flag.
  Future<List<DgtSubtopicStat>> fetchSubtopicBreakdown(String topicId) async {
    if (kUseMockSubtopics) {
      return _mockFor(topicId);
    }
    try {
      final res = await _api.get(
        '/dgt/stats/topics/$topicId/subtopic-breakdown',
      );
      if (res is! List) return const <DgtSubtopicStat>[];
      return res
          .whereType<Map>()
          .map((e) => DgtSubtopicStat.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const <DgtSubtopicStat>[];
    }
  }

  /// Datos sinteticos para desbloquear UI antes del endpoint backend.
  /// Tres clusters por defecto cubriendo verde/ambar/rojo. Test los usa
  /// para verificar el rendering por buckets.
  List<DgtSubtopicStat> _mockFor(String topicId) {
    return [
      DgtSubtopicStat(
        subtopicId: '$topicId-sub-a',
        subtopicName: 'Cluster A',
        totalAnswered: 20,
        incorrect: 3,
        failPct: 15,
      ),
      DgtSubtopicStat(
        subtopicId: '$topicId-sub-b',
        subtopicName: 'Cluster B',
        totalAnswered: 18,
        incorrect: 6,
        failPct: 33.33,
      ),
      DgtSubtopicStat(
        subtopicId: '$topicId-sub-c',
        subtopicName: 'Cluster C',
        totalAnswered: 15,
        incorrect: 10,
        failPct: 66.66,
      ),
    ];
  }
}

final dgtSubtopicRepositoryProvider = Provider<DgtSubtopicRepository>((ref) {
  return DgtSubtopicRepository(ref.watch(apiClientProvider));
});

/// Provider familia: clave por topicId. Cada tema cachea su propio breakdown.
final subtopicBreakdownProvider =
    FutureProvider.family<List<DgtSubtopicStat>, String>((ref, topicId) async {
  return ref.watch(dgtSubtopicRepositoryProvider).fetchSubtopicBreakdown(
        topicId,
      );
});
