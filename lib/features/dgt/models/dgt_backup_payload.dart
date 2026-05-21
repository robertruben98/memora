/// Issue #175 (dgt-ux): payload de backup/restore local del progreso DGT.
///
/// Schema versionado para permitir migraciones futuras sin romper imports
/// antiguos. v1 incluye lo minimo que el usuario quiere proteger de un
/// reinstall: favoritas, fallos recientes, racha snapshot, fecha examen y
/// los dos historiales locales (simulacros + sprint).
///
/// La logica es PURA (sin Flutter, sin IO) para poder testearla con un solo
/// roundtrip JSON. Cualquier IO (SharedPreferences, file_picker, share_plus)
/// vive en `dgt_backup_service.dart`.
library;

/// Version actual del schema. Bump cuando cambie el shape de forma
/// incompatible. La logica de import lee `schemaVersion` antes de decidir
/// si puede mergear o tiene que rechazar el fichero.
const int kDgtBackupSchemaVersion = 1;

/// Resultado de validar un JSON crudo entrante.
enum DgtBackupValidationStatus {
  /// JSON valido y schemaVersion compatible (==1 por ahora).
  ok,

  /// JSON parsea pero schemaVersion ausente / no entero.
  missingSchemaVersion,

  /// schemaVersion entero pero distinto al soportado.
  incompatibleSchemaVersion,

  /// JSON no parsea (sintaxis o no es Map).
  malformed,
}

/// Snapshot exportable. Cada campo es opcional para tolerar exports parciales
/// (p.ej. un usuario que aun no hizo simulacros tendra `simulacros: []`, pero
/// no tendra `examDate`).
class DgtBackupPayload {
  /// Version del schema. Permite que `restore` rechace fichero incompatible.
  final int schemaVersion;

  /// Momento del export (UTC iso8601). Sirve para resolver "newest" en merge
  /// (ej. examDate: gana el payload mas reciente).
  final DateTime exportedAt;

  /// IDs de preguntas marcadas favoritas (orden no significativo).
  final List<String> favorites;

  /// Fallos recientes serializados como JSON crudo (lo que persiste
  /// `DgtFailuresRepository`). Se guardan tal cual para no acoplar al shape
  /// interno de `DgtQuestion` aqui.
  final List<Map<String, dynamic>> failures;

  /// Snapshot informativo de la racha calculada en el momento del export.
  /// No se restaura como state (la racha se recalcula a partir de fallos +
  /// daily quest). Solo se usa para mostrar "tenias N de racha" y para que
  /// el merge `max(streak)` sea trivial en tests/roundtrip.
  final int streakSnapshot;

  /// Fecha del examen DGT (iso8601 date-only, sin hora) o null si no fijada.
  final DateTime? examDate;

  /// Meta diaria de preguntas. Null si no se exportaron settings.
  final int? dailyGoal;

  /// Codigo del permiso (B/A/C/D). Null si no se exportaron settings.
  final String? licenseCode;

  /// Historial de simulacros DGT serializado crudo (lo que persiste
  /// `DgtExamHistoryRepository`).
  final List<Map<String, dynamic>> simulacros;

  /// Historial de sprints de 2min serializado crudo.
  final List<Map<String, dynamic>> sprints;

  const DgtBackupPayload({
    required this.schemaVersion,
    required this.exportedAt,
    required this.favorites,
    required this.failures,
    required this.streakSnapshot,
    required this.examDate,
    required this.dailyGoal,
    required this.licenseCode,
    required this.simulacros,
    required this.sprints,
  });

  /// Payload vacio, util para tests y para representar "no hay nada que
  /// exportar todavia". No es `const` porque `DateTime` no es const-evaluable
  /// en Dart, pero es semanticamente inmutable (los listados son const).
  static final DgtBackupPayload empty = DgtBackupPayload(
    schemaVersion: kDgtBackupSchemaVersion,
    exportedAt: DateTime.utc(1970),
    favorites: const <String>[],
    failures: const <Map<String, dynamic>>[],
    streakSnapshot: 0,
    examDate: null,
    dailyGoal: null,
    licenseCode: null,
    simulacros: const <Map<String, dynamic>>[],
    sprints: const <Map<String, dynamic>>[],
  );

  /// Resumen humano: "12 favoritas, 5 fallos, 3 simulacros, racha 4".
  /// Lo usa el modal de preview pre-import.
  String get summaryLabel {
    return '${favorites.length} favoritas, '
        '${failures.length} fallos, '
        '${simulacros.length} simulacros, '
        '${sprints.length} sprints, '
        'racha ${streakSnapshot}d';
  }

  /// Total de items "valiosos" en el payload. Si es 0 el caller puede mostrar
  /// "el fichero no contiene progreso" en lugar de pedir confirmacion.
  int get totalItems =>
      favorites.length +
      failures.length +
      simulacros.length +
      sprints.length;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'exportedAt': exportedAt.toUtc().toIso8601String(),
        'favorites': favorites,
        'failures': failures,
        'streakSnapshot': streakSnapshot,
        'examDate': examDate?.toIso8601String(),
        'dailyGoal': dailyGoal,
        'licenseCode': licenseCode,
        'simulacros': simulacros,
        'sprints': sprints,
      };

  /// Intento de deserializar. Devuelve null si el shape es invalido. La
  /// validacion de schemaVersion se hace aparte con [validate] para que el
  /// caller pueda diferenciar "malformed" vs "incompatible" en el UI.
  static DgtBackupPayload? tryFromJson(Map<String, dynamic> j) {
    try {
      final schema = j['schemaVersion'];
      if (schema is! int) return null;
      final exportedRaw = j['exportedAt'];
      DateTime exportedAt = DateTime.utc(1970);
      if (exportedRaw is String) {
        exportedAt = DateTime.tryParse(exportedRaw)?.toUtc() ??
            DateTime.utc(1970);
      }
      final favs = _readStringList(j['favorites']);
      final fails = _readMapList(j['failures']);
      final sims = _readMapList(j['simulacros']);
      final sprs = _readMapList(j['sprints']);
      final streak = (j['streakSnapshot'] as num?)?.toInt() ?? 0;
      DateTime? examDate;
      final examRaw = j['examDate'];
      if (examRaw is String && examRaw.isNotEmpty) {
        examDate = DateTime.tryParse(examRaw);
      }
      final dailyGoal = (j['dailyGoal'] as num?)?.toInt();
      final license = j['licenseCode'] is String
          ? j['licenseCode'] as String
          : null;
      return DgtBackupPayload(
        schemaVersion: schema,
        exportedAt: exportedAt,
        favorites: favs,
        failures: fails,
        streakSnapshot: streak,
        examDate: examDate,
        dailyGoal: dailyGoal,
        licenseCode: license,
        simulacros: sims,
        sprints: sprs,
      );
    } catch (_) {
      return null;
    }
  }

  /// Valida el JSON crudo (Map ya parseado) y devuelve status. Util para que
  /// la UI muestre mensaje claro segun el caso (issue criterio: "Si
  /// schemaVersion incompatible: mensaje claro sin crash").
  static DgtBackupValidationStatus validate(Object? raw) {
    if (raw is! Map) return DgtBackupValidationStatus.malformed;
    final schema = raw['schemaVersion'];
    if (schema is! int) return DgtBackupValidationStatus.missingSchemaVersion;
    if (schema != kDgtBackupSchemaVersion) {
      return DgtBackupValidationStatus.incompatibleSchemaVersion;
    }
    return DgtBackupValidationStatus.ok;
  }
}

List<String> _readStringList(Object? raw) {
  if (raw is! List) return const <String>[];
  return raw.whereType<String>().toList(growable: false);
}

List<Map<String, dynamic>> _readMapList(Object? raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  final out = <Map<String, dynamic>>[];
  for (final e in raw) {
    if (e is Map) {
      out.add(Map<String, dynamic>.from(e));
    }
  }
  return out;
}

/// Merge segun la estrategia del issue:
/// - favorites: union (sin duplicados, orden no significativo)
/// - failures: union por id de pregunta (mantener entry con `failed_at_ms` mas
///   reciente cuando colisionan)
/// - streakSnapshot: max
/// - examDate: keep newest (gana el payload con `exportedAt` mas reciente)
/// - dailyGoal: keep newest (idem)
/// - licenseCode: keep newest (idem)
/// - simulacros: union por (date+correct+total) — sin duplicados exactos
/// - sprints: union por timestamp string — sin duplicados exactos
/// - exportedAt resultado: max(a, b)
DgtBackupPayload mergePayloads(DgtBackupPayload local, DgtBackupPayload incoming) {
  final favs = <String>{...local.favorites, ...incoming.favorites}.toList()
    ..sort();

  // Merge failures por id de pregunta -> mantener el de timestamp mas alto.
  final failuresById = <String, Map<String, dynamic>>{};
  void absorbFailures(List<Map<String, dynamic>> list) {
    for (final f in list) {
      final q = f['q'];
      if (q is! Map) continue;
      final id = q['id']?.toString();
      if (id == null || id.isEmpty) continue;
      final ts = (f['failed_at_ms'] as num?)?.toInt() ?? 0;
      final prev = failuresById[id];
      if (prev == null) {
        failuresById[id] = f;
      } else {
        final prevTs = (prev['failed_at_ms'] as num?)?.toInt() ?? 0;
        if (ts > prevTs) failuresById[id] = f;
      }
    }
  }
  absorbFailures(local.failures);
  absorbFailures(incoming.failures);
  final mergedFailures = failuresById.values.toList(growable: false);

  // Union por hash del Map serializado (estable porque las claves son las
  // mismas para entries del mismo origen).
  List<Map<String, dynamic>> unionByJson(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final m in [...a, ...b]) {
      final key = _stableKey(m);
      if (seen.add(key)) out.add(m);
    }
    return out;
  }

  final newer = incoming.exportedAt.isAfter(local.exportedAt) ? incoming : local;

  return DgtBackupPayload(
    schemaVersion: kDgtBackupSchemaVersion,
    exportedAt: incoming.exportedAt.isAfter(local.exportedAt)
        ? incoming.exportedAt
        : local.exportedAt,
    favorites: favs,
    failures: mergedFailures,
    streakSnapshot: local.streakSnapshot > incoming.streakSnapshot
        ? local.streakSnapshot
        : incoming.streakSnapshot,
    examDate: newer.examDate ?? local.examDate ?? incoming.examDate,
    dailyGoal: newer.dailyGoal ?? local.dailyGoal ?? incoming.dailyGoal,
    licenseCode: newer.licenseCode ?? local.licenseCode ?? incoming.licenseCode,
    simulacros: unionByJson(local.simulacros, incoming.simulacros),
    sprints: unionByJson(local.sprints, incoming.sprints),
  );
}

String _stableKey(Map<String, dynamic> m) {
  final keys = m.keys.toList()..sort();
  final buf = StringBuffer();
  for (final k in keys) {
    buf
      ..write(k)
      ..write('=')
      ..write(m[k])
      ..write('|');
  }
  return buf.toString();
}
