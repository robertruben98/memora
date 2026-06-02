import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_colors.dart';

import '../dgt_prediction.dart';
import '../dgt_ready_check_screen.dart';

/// Issue #204 (dgt-ux): widget visual "Mi nivel DGT".
///
/// Gauge semicircular de 180 grados con 4 zonas (rojo / amarillo / verde
/// claro / verde) basado en el predictor v2 (`dgtPredictionProvider`).
///
/// Cubre los acceptance criteria:
///  - Custom paint con arco + zonas + flecha animada (TweenAnimationBuilder,
///    600ms easeOutCubic).
///  - Etiqueta debajo "Mi nivel: X% - [zona]".
///  - Subtexto "Basado en tus ultimas N sesiones".
///  - Loading skeleton (gris) + error chip "No disponible" sin romper hub.
///  - Tap navega a `DgtReadyCheckScreen` (predictor v2).
///  - Semantics label "Mi nivel DGT: X por ciento, [zona]".
///  - Cache 30min via `dgtLevelGaugeProvider`.

/// Zona del gauge segun el score esperado del predictor v2.
enum DgtGaugeZone {
  /// 0-50%: rojo, "Sin opciones".
  sinOpciones,

  /// 50-75%: amarillo, "Necesita estudio".
  necesitaEstudio,

  /// 75-90%: verde claro, "Cerca de aprobar".
  cercaDeAprobar,

  /// 90-100%: verde, "Listo para examen".
  listoParaExamen,
}

extension DgtGaugeZoneCopy on DgtGaugeZone {
  String get label {
    switch (this) {
      case DgtGaugeZone.sinOpciones:
        return 'Sin opciones';
      case DgtGaugeZone.necesitaEstudio:
        return 'Necesita estudio';
      case DgtGaugeZone.cercaDeAprobar:
        return 'Cerca de aprobar';
      case DgtGaugeZone.listoParaExamen:
        return 'Listo para examen';
    }
  }

  Color get color {
    switch (this) {
      case DgtGaugeZone.sinOpciones:
        return const Color(0xFFFF5C5C);
      case DgtGaugeZone.necesitaEstudio:
        return const Color(0xFFFFB74F);
      case DgtGaugeZone.cercaDeAprobar:
        return const Color(0xFF9CE37D);
      case DgtGaugeZone.listoParaExamen:
        return const Color(0xFF4FFFB0);
    }
  }
}

/// Mapeo de score (0..1) a zona segun los breakpoints del issue #204.
DgtGaugeZone dgtZoneFor(double score) {
  if (score >= 0.90) return DgtGaugeZone.listoParaExamen;
  if (score >= 0.75) return DgtGaugeZone.cercaDeAprobar;
  if (score >= 0.50) return DgtGaugeZone.necesitaEstudio;
  return DgtGaugeZone.sinOpciones;
}

/// Cache TTL del provider (30min segun spec). `probability` no cambia
/// drasticamente entre sesiones, evitamos refetch en cada rebuild del hub.
const Duration kDgtLevelGaugeTtl = Duration(minutes: 30);

/// Provider cacheado del predictor v2 para el gauge. Mantiene el ultimo
/// `DgtPrediction` valido en memoria durante [kDgtLevelGaugeTtl] y solo
/// re-pide al backend cuando el TTL expira o se invalida explicitamente
/// via `ref.invalidate`.
///
/// Aditivo: NO toca [dgtPredictionProvider] existente; consume su repo
/// directamente. Otros widgets siguen usando el provider original.
final dgtLevelGaugeProvider = FutureProvider<DgtPrediction>((ref) async {
  // Mantener viva la respuesta durante TTL incluso si nadie escucha,
  // para que el siguiente listener (re-entry al hub) la reciba sin
  // refetch.
  final link = ref.keepAlive();
  Timer? timer;
  ref.onDispose(() => timer?.cancel());
  ref.onCancel(() {
    timer?.cancel();
    timer = Timer(kDgtLevelGaugeTtl, link.close);
  });
  ref.onResume(() => timer?.cancel());

  final repo = ref.watch(dgtPredictionRepositoryProvider);
  return repo.fetchPrediction();
});

/// Widget "Mi nivel" para el Study Hub DGT.
class DgtLevelGauge extends ConsumerWidget {
  const DgtLevelGauge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dgtLevelGaugeProvider);
    return async.when(
      data: (p) => _DgtLevelGaugeContent(prediction: p),
      loading: () => const _DgtLevelGaugeSkeleton(),
      error: (_, _) => const _DgtLevelGaugeError(),
    );
  }
}

class _DgtLevelGaugeContent extends StatelessWidget {
  final DgtPrediction prediction;

  const _DgtLevelGaugeContent({required this.prediction});

  @override
  Widget build(BuildContext context) {
    final hasData = prediction.hasEnoughData;
    final score = (prediction.expectedScore ?? 0.0).clamp(0.0, 1.0);
    final zone = dgtZoneFor(score);
    final pct = (score * 100).round();
    final reviews = prediction.totalReviews;

    final title = hasData
        ? 'Mi nivel: $pct% - ${zone.label.toLowerCase()}'
        : 'Mi nivel: aun sin datos suficientes';
    final subtitle = hasData
        ? 'Basado en tus ultimas $reviews sesiones'
        : 'Haz un simulacro para ver tu nivel estimado';

    return Semantics(
      button: true,
      label: hasData
          ? 'Mi nivel DGT: $pct por ciento, ${zone.label}'
          : 'Mi nivel DGT: sin datos suficientes',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DgtReadyCheckScreen()),
          ),
          child: Ink(
            decoration: BoxDecoration(
              color: context.c.surfaceElevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: zone.color.withValues(alpha: hasData ? 0.55 : 0.2),
                width: 1.4,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _GaugePainterHost(
                  targetScore: hasData ? score : 0.0,
                  activeZone: hasData ? zone : null,
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainterHost extends StatelessWidget {
  final double targetScore;
  final DgtGaugeZone? activeZone;

  const _GaugePainterHost({required this.targetScore, required this.activeZone});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: targetScore),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return CustomPaint(
            painter: DgtLevelGaugePainter(
              score: value,
              activeZone: activeZone,
            ),
          );
        },
      ),
    );
  }
}

/// CustomPainter del gauge semicircular con 4 zonas + flecha.
@visibleForTesting
class DgtLevelGaugePainter extends CustomPainter {
  /// Score actual (0..1). Determina el angulo de la flecha.
  final double score;

  /// Zona activa para resaltarla (alpha mayor). `null` => loading/no datos
  /// (todas las zonas atenuadas, sin flecha).
  final DgtGaugeZone? activeZone;

  DgtLevelGaugePainter({required this.score, required this.activeZone});

  @override
  void paint(Canvas canvas, Size size) {
    // Issue #204: arco semicircular 180deg con 4 zonas. Geometria:
    // centro abajo-centro, radio = min(width/2, height) - margen.
    final padding = 12.0;
    final radius = math.min(size.width / 2, size.height) - padding;
    final center = Offset(size.width / 2, size.height - 4);
    final rect = Rect.fromCircle(center: center, radius: radius);

    const startAngle = math.pi; // 180 grados (izquierda).
    const sweep = math.pi; // 180 grados de arco.

    final zones = <(DgtGaugeZone, double, double)>[
      // (zona, fraccion_inicio, fraccion_fin) sobre el rango 0..1.
      (DgtGaugeZone.sinOpciones, 0.0, 0.50),
      (DgtGaugeZone.necesitaEstudio, 0.50, 0.75),
      (DgtGaugeZone.cercaDeAprobar, 0.75, 0.90),
      (DgtGaugeZone.listoParaExamen, 0.90, 1.0),
    ];

    for (final (zone, a, b) in zones) {
      final isActive = activeZone == zone;
      final paint = Paint()
        ..color = zone.color.withValues(
          alpha: activeZone == null ? 0.25 : (isActive ? 1.0 : 0.35),
        )
        ..strokeWidth = isActive ? 16 : 12
        ..strokeCap = StrokeCap.butt
        ..style = PaintingStyle.stroke;
      final zoneStart = startAngle + sweep * a;
      final zoneSweep = sweep * (b - a);
      canvas.drawArc(rect, zoneStart, zoneSweep, false, paint);
    }

    // Flecha indicadora solo si tenemos zona activa (datos).
    if (activeZone != null) {
      final clamped = score.clamp(0.0, 1.0);
      final angle = startAngle + sweep * clamped;
      final needleLen = radius - 6;
      final tip = Offset(
        center.dx + needleLen * math.cos(angle),
        center.dy + needleLen * math.sin(angle),
      );
      final needlePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(center, tip, needlePaint);

      // Pivote central.
      final hub = Paint()..color = Colors.white;
      canvas.drawCircle(center, 6, hub);
      final hubAccent = Paint()..color = activeZone!.color;
      canvas.drawCircle(center, 3.5, hubAccent);
    }
  }

  @override
  bool shouldRepaint(covariant DgtLevelGaugePainter old) {
    return old.score != score || old.activeZone != activeZone;
  }
}

class _DgtLevelGaugeSkeleton extends StatelessWidget {
  const _DgtLevelGaugeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mi nivel DGT: cargando',
      child: Container(
        decoration: BoxDecoration(
          color: context.c.surfaceElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: context.c.border,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          children: [
            SizedBox(
              height: 110,
              width: double.infinity,
              child: CustomPaint(
                painter: DgtLevelGaugePainter(
                  score: 0,
                  activeZone: null,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 12,
              width: 140,
              decoration: BoxDecoration(
                color: context.c.surfaceMuted,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 10,
              width: 100,
              decoration: BoxDecoration(
                color: context.c.surfaceMuted,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DgtLevelGaugeError extends StatelessWidget {
  const _DgtLevelGaugeError();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mi nivel DGT: no disponible',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.c.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.c.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.signal_wifi_off_rounded,
              size: 18,
              color: context.c.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Mi nivel: no disponible',
                style: TextStyle(
                  fontSize: 13,
                  color: context.c.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
