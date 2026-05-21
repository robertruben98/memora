import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/database/database.dart';
import '../dgt_favorites_provider.dart';
import '../dgt_settings.dart';
import '../dgt_sprint_history_provider.dart';
import '../../study/dgt_exam_history.dart';
import '../models/dgt_backup_payload.dart';

/// Clave SharedPreferences donde [DgtFailuresRepository] guarda los fallos
/// recientes. Replicada aqui porque la repo la mantiene privada y queremos
/// leer/escribir el JSON crudo sin acoplarnos a su shape (que evolucionara).
const String _kDgtFailuresPrefsKey = 'dgt.failures.v1';

/// Issue #175 (dgt-ux): export/import de progreso DGT como JSON local.
///
/// Centraliza:
/// - lectura de TODOS los stores locales (favorites, failures, simulacros,
///   sprints, settings) para construir un [DgtBackupPayload].
/// - serializacion -> share via share_plus.
/// - lectura via file_picker -> merge -> escritura a stores.
///
/// La logica de merge es PURA y vive en [mergePayloads] (testeable sin Flutter).
class DgtBackupService {
  final MemoraDatabase _db;
  final Future<SharedPreferences> Function() _prefsLoader;

  DgtBackupService({
    required MemoraDatabase db,
    Future<SharedPreferences> Function()? prefsLoader,
  })  : _db = db,
        _prefsLoader = prefsLoader ?? SharedPreferences.getInstance;

  /// Lee todo el estado actual y construye un payload.
  Future<DgtBackupPayload> buildPayload({int streakSnapshot = 0}) async {
    final prefs = await _prefsLoader();

    // Favoritas.
    final favs = prefs.getStringList(kDgtFavoritesPrefsKey) ?? const <String>[];

    // Failures (raw JSON list).
    List<Map<String, dynamic>> failures = const <Map<String, dynamic>>[];
    final failuresRaw = prefs.getString(_kDgtFailuresPrefsKey);
    if (failuresRaw != null && failuresRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(failuresRaw);
        if (decoded is List) {
          failures = decoded
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList(growable: false);
        }
      } catch (_) {
        failures = const <Map<String, dynamic>>[];
      }
    }

    // Sprint history (raw JSON list).
    List<Map<String, dynamic>> sprints = const <Map<String, dynamic>>[];
    final sprintsRaw = prefs.getString(kDgtSprintHistoryPrefsKey);
    if (sprintsRaw != null && sprintsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(sprintsRaw);
        if (decoded is List) {
          sprints = decoded
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList(growable: false);
        }
      } catch (_) {
        sprints = const <Map<String, dynamic>>[];
      }
    }

    // Simulacros history (raw JSON list).
    List<Map<String, dynamic>> simulacros = const <Map<String, dynamic>>[];
    final simRaw = prefs.getString(kDgtExamHistoryPrefsKey);
    if (simRaw != null && simRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(simRaw);
        if (decoded is List) {
          simulacros = decoded
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList(growable: false);
        }
      } catch (_) {
        simulacros = const <Map<String, dynamic>>[];
      }
    }

    // Settings (license / examDate / dailyGoal). Best-effort.
    String? licenseCode;
    DateTime? examDate;
    int? dailyGoal;
    try {
      final license = await _db.settingsDao.getValue(kDgtLicenseTypeKey);
      final exam = await _db.settingsDao.getValue(kDgtExamDateKey);
      final goal = await _db.settingsDao.getValue(kDgtDailyGoalKey);
      licenseCode = license;
      examDate = (exam == null || exam.isEmpty) ? null : DateTime.tryParse(exam);
      dailyGoal = int.tryParse(goal ?? '');
    } catch (_) {
      // best-effort: dejamos campos null si no podemos leer settings.
    }

    return DgtBackupPayload(
      schemaVersion: kDgtBackupSchemaVersion,
      exportedAt: DateTime.now().toUtc(),
      favorites: favs,
      failures: failures,
      streakSnapshot: streakSnapshot,
      examDate: examDate,
      dailyGoal: dailyGoal,
      licenseCode: licenseCode,
      simulacros: simulacros,
      sprints: sprints,
    );
  }

  /// Exporta el payload a un fichero temporal y lo comparte via share_plus.
  /// Devuelve el path del fichero (util en tests).
  Future<String> exportAndShare({int streakSnapshot = 0}) async {
    final payload = await buildPayload(streakSnapshot: streakSnapshot);
    final json = const JsonEncoder.withIndent('  ').convert(payload.toJson());
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/memora-dgt-progreso-$stamp.json');
    await file.writeAsString(json);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Progreso DGT memora',
      text: 'Backup de mi progreso DGT (${payload.summaryLabel}).',
    );
    return file.path;
  }

  /// Abre file_picker, lee el JSON y devuelve el payload + status de
  /// validacion. NO escribe nada todavia (eso lo hace [applyMerge] tras
  /// confirmacion en UI).
  Future<DgtBackupReadResult> pickAndRead() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) {
      return const DgtBackupReadResult.cancelled();
    }
    final f = picked.files.first;
    String content;
    try {
      if (f.bytes != null) {
        content = utf8.decode(f.bytes!, allowMalformed: false);
      } else if (f.path != null) {
        content = await File(f.path!).readAsString();
      } else {
        return const DgtBackupReadResult.error('Archivo vacio o ilegible');
      }
    } catch (_) {
      return const DgtBackupReadResult.error('No se pudo leer el archivo');
    }
    return parseRaw(content);
  }

  /// Parse + validate a partir de string crudo. Pure (testable sin file_picker).
  static DgtBackupReadResult parseRaw(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const DgtBackupReadResult.error('JSON invalido o corrupto');
    }
    final status = DgtBackupPayload.validate(decoded);
    switch (status) {
      case DgtBackupValidationStatus.malformed:
        return const DgtBackupReadResult.error(
            'El archivo no tiene la estructura esperada');
      case DgtBackupValidationStatus.missingSchemaVersion:
        return const DgtBackupReadResult.error(
            'Falta schemaVersion en el archivo');
      case DgtBackupValidationStatus.incompatibleSchemaVersion:
        return const DgtBackupReadResult.error(
            'Version de backup no compatible con esta app');
      case DgtBackupValidationStatus.ok:
        break;
    }
    final parsed = DgtBackupPayload.tryFromJson(
        Map<String, dynamic>.from(decoded as Map));
    if (parsed == null) {
      return const DgtBackupReadResult.error(
          'No se pudieron extraer datos del archivo');
    }
    return DgtBackupReadResult.ok(parsed);
  }

  /// Aplica un payload entrante: lee estado local actual, mergea y persiste.
  /// Devuelve el payload final ya mergeado para que la UI muestre summary.
  Future<DgtBackupPayload> applyMerge(DgtBackupPayload incoming) async {
    final current = await buildPayload();
    final merged = mergePayloads(current, incoming);

    final prefs = await _prefsLoader();

    // Favorites: union -> setStringList.
    await prefs.setStringList(
      kDgtFavoritesPrefsKey,
      merged.favorites.toList(growable: false),
    );

    // Failures: dump JSON raw bajo la misma key que usa el repo.
    if (merged.failures.isEmpty) {
      await prefs.remove(_kDgtFailuresPrefsKey);
    } else {
      await prefs.setString(_kDgtFailuresPrefsKey, jsonEncode(merged.failures));
    }

    // Sprint history.
    if (merged.sprints.isEmpty) {
      await prefs.remove(kDgtSprintHistoryPrefsKey);
    } else {
      await prefs.setString(
        kDgtSprintHistoryPrefsKey,
        jsonEncode(merged.sprints),
      );
    }

    // Simulacros history.
    if (merged.simulacros.isEmpty) {
      await prefs.remove(kDgtExamHistoryPrefsKey);
    } else {
      await prefs.setString(
        kDgtExamHistoryPrefsKey,
        jsonEncode(merged.simulacros),
      );
    }

    // Settings (license / dailyGoal / examDate) -> tabla settings via dao.
    try {
      if (merged.licenseCode != null && merged.licenseCode!.isNotEmpty) {
        await _db.settingsDao.setValue(kDgtLicenseTypeKey, merged.licenseCode!);
      }
      if (merged.dailyGoal != null) {
        await _db.settingsDao.setValue(
          kDgtDailyGoalKey,
          merged.dailyGoal!.toString(),
        );
      }
      if (merged.examDate != null) {
        await _db.settingsDao.setValue(
          kDgtExamDateKey,
          merged.examDate!.toIso8601String(),
        );
      }
    } catch (_) {
      // best-effort
    }

    return merged;
  }
}

/// Resultado tipado de leer un fichero del file picker. Sealed-like via flag.
class DgtBackupReadResult {
  final DgtBackupPayload? payload;
  final String? errorMessage;
  final bool cancelled;

  const DgtBackupReadResult.ok(DgtBackupPayload p)
      : payload = p,
        errorMessage = null,
        cancelled = false;

  const DgtBackupReadResult.error(String msg)
      : payload = null,
        errorMessage = msg,
        cancelled = false;

  const DgtBackupReadResult.cancelled()
      : payload = null,
        errorMessage = null,
        cancelled = true;

  bool get isOk => payload != null;
}

/// Provider del servicio. No usa estado riverpod en si — solo expone la
/// instancia configurada con la DB de la app.
final dgtBackupServiceProvider = Provider<DgtBackupService>((ref) {
  return DgtBackupService(db: ref.watch(databaseProvider));
});
