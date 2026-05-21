import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/dgt_repository.dart';
import 'dgt_failures_repository.dart';

/// Origen / "bucket" de una pregunta en la sesion "Estudio de hoy".
///
/// Issue #167 (dgt-ux): cada pregunta sabe de que fuente vino para que el
/// resumen final pueda mostrar accuracy parcial por bucket.
enum DgtTodayBucket {
  /// 5 preguntas del tema mas debil (reusa `/dgt/quiz/weak-focus`, BE#93).
  weak,

  /// 5 errores recurrentes (reusa [DgtFailuresRepository], local).
  recurrent,

  /// 5 preguntas nuevas no vistas (reusa `/dgt/questions`).
  fresh,
}

/// Item de la sesion "Estudio de hoy": pregunta + bucket de origen.
class DgtTodayItem {
  final DgtQuestion question;
  final DgtTodayBucket bucket;

  const DgtTodayItem({required this.question, required this.bucket});
}

/// Resultado del armado de la sesion mixta. Mantiene desglose por bucket
/// para que el header de la pantalla pueda mostrar "X debil / Y recurrentes
/// / Z nuevas" antes de empezar.
class DgtTodayStudyResult {
  /// Las 15 preguntas (puede ser menos si fuentes agotadas y target tampoco
  /// alcanza con relleno). Orden: weak -> recurrent -> fresh.
  final List<DgtTodayItem> items;

  /// Conteo final por bucket (sumado == items.length).
  final int weakCount;
  final int recurrentCount;
  final int freshCount;

  /// Total objetivo (default 15). Si una fuente devuelve menos, las demas
  /// rellenan hasta este target respetando el orden weak->recurrent->fresh.
  final int target;

  /// Si el resultado no tiene NINGUNA pregunta (todas las fuentes agotadas
  /// + backend offline) la UI muestra empty state.
  bool get isEmpty => items.isEmpty;

  /// Total real (= items.length, util para no llamar .length en UI).
  int get total => items.length;

  const DgtTodayStudyResult({
    required this.items,
    required this.weakCount,
    required this.recurrentCount,
    required this.freshCount,
    required this.target,
  });

  /// Resultado vacio (todas las fuentes vacias / offline).
  static const DgtTodayStudyResult emptyDefault = DgtTodayStudyResult(
    items: <DgtTodayItem>[],
    weakCount: 0,
    recurrentCount: 0,
    freshCount: 0,
    target: 15,
  );
}

/// Args para [dgtTodayStudyProvider]. family-friendly: el caller puede pedir
/// un target distinto sin romper el contrato (default = 15 segun spec).
class DgtTodayStudyArgs {
  final int target;
  final int perBucket;

  const DgtTodayStudyArgs({this.target = 15, this.perBucket = 5});

  @override
  bool operator ==(Object other) =>
      other is DgtTodayStudyArgs &&
      other.target == target &&
      other.perBucket == perBucket;

  @override
  int get hashCode => Object.hash(target, perBucket);
}

/// Issue #167 (dgt-ux): builder de sesion "Estudio de hoy" auto-curada.
///
/// Combina 3 fuentes en este orden de prioridad:
///   1. weak-focus quiz (`/dgt/quiz/weak-focus`, BE#93)
///   2. errores recurrentes (DgtFailuresRepository local)
///   3. preguntas nuevas (`/dgt/questions` filtrando ya respondidas via
///      seen-id set)
///
/// Reglas:
///   - Target = 15 (5+5+5) por defecto.
///   - Si una fuente devuelve MENOS de `perBucket`, la siguiente fuente
///     rellena hasta `target` respetando el orden.
///   - Si TODO falla / offline / sin historial: devuelve `emptyDefault`
///     (la UI muestra empty state, no quiz).
///   - Dedup por questionId entre buckets (evita misma pregunta en weak y
///     fresh si el banco la repite).
///
/// El provider devuelve un Future para que la pantalla pueda mostrar
/// loading + empty state sin StatefulWidget extra.
Future<DgtTodayStudyResult> buildTodayStudySession({
  required DgtRepository repo,
  required DgtFailuresRepository failuresRepo,
  required Set<String> seenIds,
  int target = 15,
  int perBucket = 5,
}) async {
  final picked = <DgtTodayItem>[];
  final usedIds = <String>{};
  var weakCount = 0;
  var recurrentCount = 0;
  var freshCount = 0;

  void addIfRoom(DgtQuestion q, DgtTodayBucket bucket) {
    if (picked.length >= target) return;
    if (usedIds.contains(q.id)) return;
    usedIds.add(q.id);
    picked.add(DgtTodayItem(question: q, bucket: bucket));
    switch (bucket) {
      case DgtTodayBucket.weak:
        weakCount++;
        break;
      case DgtTodayBucket.recurrent:
        recurrentCount++;
        break;
      case DgtTodayBucket.fresh:
        freshCount++;
        break;
    }
  }

  // 1) Bucket weak (5 preguntas del tema mas debil).
  try {
    final weak = await repo.fetchWeakFocusQuiz(n: perBucket.clamp(4, 50));
    for (final q in weak.questions.take(perBucket)) {
      addIfRoom(q, DgtTodayBucket.weak);
    }
  } catch (_) {
    // Fuente weak no disponible: continuamos con las demas.
  }

  // 2) Bucket recurrent (5 errores recurrentes locales, mas reciente primero).
  try {
    final failures = await failuresRepo.recentFailures();
    for (final f in failures) {
      if (recurrentCount >= perBucket) break;
      addIfRoom(f.question, DgtTodayBucket.recurrent);
    }
  } catch (_) {
    // Repo local fallo (raro: SharedPreferences). Seguimos.
  }

  // 3) Bucket fresh (rellena hasta target con preguntas no vistas).
  final remaining = target - picked.length;
  if (remaining > 0) {
    try {
      // Pedimos un buffer mayor (3x) para tener margen tras filtrar seen.
      final freshLimit = (remaining * 3).clamp(remaining, 50);
      final pool = await repo.fetchExamQuestions(limit: freshLimit);
      for (final q in pool) {
        if (picked.length >= target) break;
        // Filtra ya vistas / ya picked por id.
        if (seenIds.contains(q.id)) continue;
        addIfRoom(q, DgtTodayBucket.fresh);
      }
      // Si despues de filtrar seen aun falta: aceptamos vistas (degrada
      // antes que devolver sesion incompleta -- spec: target=15 siempre que
      // haya banco suficiente).
      if (picked.length < target) {
        for (final q in pool) {
          if (picked.length >= target) break;
          addIfRoom(q, DgtTodayBucket.fresh);
        }
      }
    } catch (_) {
      // Backend offline: ya tenemos lo que tenemos. Si sigue 0 -> empty.
    }
  }

  return DgtTodayStudyResult(
    items: List.unmodifiable(picked),
    weakCount: weakCount,
    recurrentCount: recurrentCount,
    freshCount: freshCount,
    target: target,
  );
}

/// Provider del [DgtFailuresRepository] usado por el provider de hoy.
/// Reusa el provider existente para coherencia con [dgt_failures_review_screen].

/// Riverpod FutureProvider que envuelve [buildTodayStudySession]. Tests
/// pueden override `dgtRepositoryProvider` y `dgtFailuresRepositoryProvider`.
///
/// `seenIds` se mantiene client-side: por defecto un Set vacio (sin tracking
/// global). Cuando aparezca un endpoint `/dgt/users/me/answered-ids` se
/// podra inyectar aqui sin tocar la pantalla.
final dgtTodayStudyProvider =
    FutureProvider.autoDispose<DgtTodayStudyResult>((ref) async {
  final repo = ref.watch(dgtRepositoryProvider);
  final failuresRepo = ref.watch(dgtFailuresRepositoryProvider);
  return buildTodayStudySession(
    repo: repo,
    failuresRepo: failuresRepo,
    seenIds: const <String>{},
  );
});
