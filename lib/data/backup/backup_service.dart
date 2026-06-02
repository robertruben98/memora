import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database.dart';

class BackupService {
  static const _formatVersion = 1;
  final MemoraDatabase _db;

  BackupService(this._db);

  Future<String> exportToJson() async {
    final decks = await _db.deckDao.getAllDecks();
    final cards = await _db.cardDao.getAllCards();
    final allCardIds = cards.map((c) => c.id).toList();
    final schedulesMap =
        await _db.scheduleDao.getSchedulesByCardIds(allCardIds);
    final logs = await _db.reviewLogDao.getRecentLogs(limit: 50000);
    final settings = await (_db.select(_db.appSettings)).get();

    final payload = {
      'format': 'memora-backup',
      'version': _formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'decks': decks
          .map((d) => {
                'id': d.id,
                'name': d.name,
                'description': d.description,
                'colorHex': d.colorHex,
                'iconName': d.iconName,
                'createdAt': d.createdAt,
                'updatedAt': d.updatedAt,
              })
          .toList(),
      'cards': cards
          .map((c) => {
                'id': c.id,
                'deckId': c.deckId,
                'frontText': c.frontText,
                'backText': c.backText,
                'frontImagePath': c.frontImagePath,
                'backImagePath': c.backImagePath,
                'createdAt': c.createdAt,
                'updatedAt': c.updatedAt,
              })
          .toList(),
      'schedules': schedulesMap.values
          .map((s) => {
                'cardId': s.cardId,
                'easeFactor': s.easeFactor,
                'intervalDays': s.intervalDays,
                'repetitions': s.repetitions,
                'state': s.state,
                'nextReviewDate': s.nextReviewDate,
                'lastReviewDate': s.lastReviewDate,
              })
          .toList(),
      'reviewLogs': logs
          .map((l) => {
                'id': l.id,
                'cardId': l.cardId,
                'reviewedAt': l.reviewedAt,
                'result': l.result,
                'previousIntervalDays': l.previousIntervalDays,
                'newIntervalDays': l.newIntervalDays,
              })
          .toList(),
      'settings':
          settings.map((s) => {'key': s.key, 'value': s.value}).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<File> _writeTempBackup(String json) async {
    final tmpDir = await getTemporaryDirectory();
    final ts = DateTime.now();
    final stamp =
        '${ts.year}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}-'
        '${ts.hour.toString().padLeft(2, '0')}${ts.minute.toString().padLeft(2, '0')}';
    final file = File(p.join(tmpDir.path, 'memora-backup-$stamp.json'));
    await file.writeAsString(json);
    return file;
  }

  /// Genera backup, lo guarda en /tmp y abre el share sheet del SO.
  Future<ShareResult> exportAndShare() async {
    final json = await exportToJson();
    final file = await _writeTempBackup(json);
    return Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Backup de RutaB',
      text: 'Backup de tus mazos y progreso de RutaB.',
    );
  }

  /// Abre el file picker para escoger un .json y restaura.
  /// `replace=true` borra todo antes de insertar; `false` fusiona
  /// con insertOrIgnore (cards/decks) y upsert (schedules/settings).
  /// Devuelve null si el usuario cancela.
  Future<BackupImportResult?> importFromFilePicker({
    required bool replace,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return null;
    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    return importFromJson(content, replace: replace);
  }

  Future<BackupImportResult> importFromJson(
    String json, {
    required bool replace,
  }) async {
    final dynamic raw;
    try {
      raw = jsonDecode(json);
    } catch (e) {
      throw const FormatException('JSON inválido');
    }
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Formato no reconocido (esperaba un objeto)');
    }
    if (raw['format'] != 'memora-backup') {
      throw const FormatException(
          'Este archivo no es un backup de RutaB válido');
    }
    final version = raw['version'];
    if (version is! num || version.toInt() != _formatVersion) {
      throw FormatException(
        'Versión de backup incompatible (esperaba $_formatVersion, '
        'encontró ${version ?? 'ninguna'}).',
      );
    }
    final decks = _requireList(raw, 'decks');
    final cards = _requireList(raw, 'cards');
    final schedules = _requireList(raw, 'schedules');
    final logs = _requireList(raw, 'reviewLogs');
    final settings = _requireList(raw, 'settings');

    await _db.transaction(() async {
      if (replace) {
        await _db.delete(_db.reviewLogs).go();
        await _db.delete(_db.cardSchedules).go();
        await _db.delete(_db.cards).go();
        await _db.delete(_db.decks).go();
        await _db.delete(_db.appSettings).go();
      }

      for (final d in decks) {
        await _db.into(_db.decks).insert(
              DecksCompanion.insert(
                id: d['id'] as String,
                name: d['name'] as String,
                description: Value(d['description'] as String?),
                colorHex: Value(d['colorHex'] as String? ?? '#7C5CFF'),
                iconName: Value(d['iconName'] as String? ?? 'style_rounded'),
                createdAt: (d['createdAt'] as num).toInt(),
                updatedAt: (d['updatedAt'] as num).toInt(),
              ),
              mode: replace ? InsertMode.insert : InsertMode.insertOrIgnore,
            );
      }
      for (final c in cards) {
        await _db.into(_db.cards).insert(
              CardsCompanion.insert(
                id: c['id'] as String,
                deckId: c['deckId'] as String,
                frontText: c['frontText'] as String,
                backText: c['backText'] as String,
                frontImagePath: Value(c['frontImagePath'] as String?),
                backImagePath: Value(c['backImagePath'] as String?),
                createdAt: (c['createdAt'] as num).toInt(),
                updatedAt: (c['updatedAt'] as num).toInt(),
              ),
              mode: replace ? InsertMode.insert : InsertMode.insertOrIgnore,
            );
      }
      for (final s in schedules) {
        await _db.into(_db.cardSchedules).insert(
              CardSchedulesCompanion.insert(
                cardId: s['cardId'] as String,
                easeFactor:
                    Value((s['easeFactor'] as num?)?.toDouble() ?? 2.5),
                intervalDays: Value((s['intervalDays'] as num?)?.toInt() ?? 0),
                repetitions: Value((s['repetitions'] as num?)?.toInt() ?? 0),
                state: Value(s['state'] as String? ?? 'new'),
                nextReviewDate: (s['nextReviewDate'] as num).toInt(),
                lastReviewDate: Value(
                    (s['lastReviewDate'] as num?)?.toInt()),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
      for (final l in logs) {
        await _db.into(_db.reviewLogs).insert(
              ReviewLogsCompanion.insert(
                cardId: l['cardId'] as String,
                reviewedAt: (l['reviewedAt'] as num).toInt(),
                result: l['result'] as String,
                previousIntervalDays:
                    (l['previousIntervalDays'] as num).toInt(),
                newIntervalDays: (l['newIntervalDays'] as num).toInt(),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
      for (final st in settings) {
        await _db.into(_db.appSettings).insert(
              AppSettingsCompanion.insert(
                key: st['key'] as String,
                value: st['value'] as String,
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    });

    return BackupImportResult(
      decks: decks.length,
      cards: cards.length,
      schedules: schedules.length,
      logs: logs.length,
      settings: settings.length,
    );
  }

  /// Lee `raw[key]` esperando una lista (sección del backup).
  ///
  /// - Si la clave falta o es `null`, devuelve una lista vacía (sección
  ///   opcional/ausente válida).
  /// - Si la clave existe pero el valor NO es una `List`, lanza
  ///   [FormatException] con un mensaje claro, en lugar de tragarse el
  ///   error y devolver una lista vacía silenciosamente.
  List<dynamic> _requireList(Map<String, dynamic> raw, String key) {
    final value = raw[key];
    if (value == null) return const [];
    if (value is! List) {
      throw FormatException(
        'Backup corrupto: la sección "$key" debería ser una lista '
        'pero es ${value.runtimeType}.',
      );
    }
    return value.cast<dynamic>();
  }
}

class BackupImportResult {
  final int decks;
  final int cards;
  final int schedules;
  final int logs;
  final int settings;

  const BackupImportResult({
    required this.decks,
    required this.cards,
    required this.schedules,
    required this.logs,
    required this.settings,
  });
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(databaseProvider));
});
