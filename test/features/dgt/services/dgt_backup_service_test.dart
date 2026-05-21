import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/models/dgt_backup_payload.dart';
import 'package:memora/features/dgt/services/dgt_backup_service.dart';

void main() {
  group('DgtBackupPayload', () {
    test('roundtrip JSON conserva todos los campos relevantes', () {
      final original = DgtBackupPayload(
        schemaVersion: kDgtBackupSchemaVersion,
        exportedAt: DateTime.utc(2026, 5, 21, 10),
        favorites: const ['q1', 'q2', 'q3'],
        failures: const [
          {
            'q': {
              'id': 'qA',
              'statement': '?',
              'image_url': null,
              'option_a': 'a',
              'option_b': 'b',
              'option_c': 'c',
              'correct': 'a',
              'explanation': 'pq',
              'topic': 'T1',
            },
            'failed_at_ms': 1000,
          },
        ],
        streakSnapshot: 5,
        examDate: DateTime.utc(2026, 6, 15),
        dailyGoal: 30,
        licenseCode: 'B',
        simulacros: const [
          {
            'date': '2026-05-01T10:00:00.000Z',
            'correct': 27,
            'total': 30,
            'time_used_seconds': 900,
            'passed': true,
          },
        ],
        sprints: const [
          {'ts': '2026-05-21T08:00:00.000Z', 'total': 10, 'correct': 8, 'seconds_used': 90},
        ],
      );

      final json = jsonEncode(original.toJson());
      final decoded = jsonDecode(json);
      expect(DgtBackupPayload.validate(decoded), DgtBackupValidationStatus.ok);
      final restored = DgtBackupPayload.tryFromJson(
        Map<String, dynamic>.from(decoded as Map),
      );
      expect(restored, isNotNull);
      expect(restored!.schemaVersion, kDgtBackupSchemaVersion);
      expect(restored.favorites, ['q1', 'q2', 'q3']);
      expect(restored.failures.length, 1);
      expect(restored.failures.first['failed_at_ms'], 1000);
      expect(restored.streakSnapshot, 5);
      expect(restored.examDate, DateTime.utc(2026, 6, 15));
      expect(restored.dailyGoal, 30);
      expect(restored.licenseCode, 'B');
      expect(restored.simulacros.length, 1);
      expect(restored.sprints.length, 1);
      expect(restored.exportedAt.toUtc(),
          DateTime.utc(2026, 5, 21, 10));
    });

    test('validate detecta schemaVersion incompatible', () {
      final raw = {'schemaVersion': 99, 'favorites': []};
      expect(
        DgtBackupPayload.validate(raw),
        DgtBackupValidationStatus.incompatibleSchemaVersion,
      );
    });

    test('validate detecta schemaVersion ausente', () {
      final raw = {'favorites': []};
      expect(
        DgtBackupPayload.validate(raw),
        DgtBackupValidationStatus.missingSchemaVersion,
      );
    });

    test('validate detecta payload malformado (no es Map)', () {
      expect(
        DgtBackupPayload.validate('lol'),
        DgtBackupValidationStatus.malformed,
      );
      expect(
        DgtBackupPayload.validate([1, 2, 3]),
        DgtBackupValidationStatus.malformed,
      );
    });

    test('summaryLabel incluye conteos clave', () {
      final p = DgtBackupPayload(
        schemaVersion: kDgtBackupSchemaVersion,
        exportedAt: DateTime.utc(2026, 5, 21),
        favorites: const ['a', 'b'],
        failures: const [
          {'q': {'id': '1'}, 'failed_at_ms': 1},
        ],
        streakSnapshot: 7,
        examDate: null,
        dailyGoal: null,
        licenseCode: null,
        simulacros: const [],
        sprints: const [],
      );
      expect(p.summaryLabel, contains('2 favoritas'));
      expect(p.summaryLabel, contains('1 fallos'));
      expect(p.summaryLabel, contains('racha 7d'));
    });
  });

  group('mergePayloads', () {
    DgtBackupPayload mk({
      DateTime? at,
      List<String> favs = const [],
      List<Map<String, dynamic>> failures = const [],
      int streak = 0,
      DateTime? examDate,
      int? dailyGoal,
      String? license,
      List<Map<String, dynamic>> sims = const [],
      List<Map<String, dynamic>> sprints = const [],
    }) {
      return DgtBackupPayload(
        schemaVersion: kDgtBackupSchemaVersion,
        exportedAt: at ?? DateTime.utc(2026, 1, 1),
        favorites: favs,
        failures: failures,
        streakSnapshot: streak,
        examDate: examDate,
        dailyGoal: dailyGoal,
        licenseCode: license,
        simulacros: sims,
        sprints: sprints,
      );
    }

    test('favoritas se unifican sin duplicados', () {
      final a = mk(favs: ['q1', 'q2']);
      final b = mk(favs: ['q2', 'q3']);
      final merged = mergePayloads(a, b);
      expect(merged.favorites.toSet(), {'q1', 'q2', 'q3'});
    });

    test('fallos: misma pregunta -> gana el de timestamp mas reciente', () {
      final old = {
        'q': {'id': 'X'},
        'failed_at_ms': 1000,
      };
      final fresh = {
        'q': {'id': 'X'},
        'failed_at_ms': 5000,
      };
      final merged = mergePayloads(mk(failures: [old]), mk(failures: [fresh]));
      expect(merged.failures.length, 1);
      expect(merged.failures.first['failed_at_ms'], 5000);
    });

    test('streak: gana max', () {
      final merged = mergePayloads(
        mk(streak: 3),
        mk(streak: 9),
      );
      expect(merged.streakSnapshot, 9);
    });

    test('examDate / dailyGoal / license: gana el payload mas reciente', () {
      final older = mk(
        at: DateTime.utc(2026, 1, 1),
        examDate: DateTime.utc(2026, 7, 1),
        dailyGoal: 20,
        license: 'B',
      );
      final newer = mk(
        at: DateTime.utc(2026, 5, 1),
        examDate: DateTime.utc(2026, 8, 15),
        dailyGoal: 50,
        license: 'A',
      );
      final merged = mergePayloads(older, newer);
      expect(merged.examDate, DateTime.utc(2026, 8, 15));
      expect(merged.dailyGoal, 50);
      expect(merged.licenseCode, 'A');
    });

    test('keep newest cae al campo del otro si el mas reciente lo trae null',
        () {
      final older = mk(
        at: DateTime.utc(2026, 1, 1),
        examDate: DateTime.utc(2026, 7, 1),
        dailyGoal: 20,
        license: 'B',
      );
      final newer = mk(at: DateTime.utc(2026, 5, 1)); // sin examDate ni nada
      final merged = mergePayloads(older, newer);
      expect(merged.examDate, DateTime.utc(2026, 7, 1));
      expect(merged.dailyGoal, 20);
      expect(merged.licenseCode, 'B');
    });

    test('simulacros y sprints se unifican sin duplicados exactos', () {
      final s = {
        'date': '2026-05-01T10:00:00.000Z',
        'correct': 27,
        'total': 30,
        'time_used_seconds': 900,
        'passed': true,
      };
      final merged = mergePayloads(mk(sims: [s]), mk(sims: [s, {...s, 'correct': 28}]));
      expect(merged.simulacros.length, 2);
    });

    test('exportedAt resultado = max(a,b)', () {
      final a = mk(at: DateTime.utc(2026, 1, 1));
      final b = mk(at: DateTime.utc(2026, 6, 1));
      final merged = mergePayloads(a, b);
      expect(merged.exportedAt, DateTime.utc(2026, 6, 1));
    });
  });

  group('DgtBackupService.parseRaw', () {
    test('error en JSON corrupto', () {
      final r = DgtBackupService.parseRaw('not json');
      expect(r.isOk, isFalse);
      expect(r.errorMessage, isNotNull);
    });

    test('error en schema incompatible', () {
      final r = DgtBackupService.parseRaw(jsonEncode({
        'schemaVersion': 99,
        'favorites': <String>[],
      }));
      expect(r.isOk, isFalse);
      expect(r.errorMessage, contains('compatible'));
    });

    test('ok roundtrip via parseRaw', () {
      final original = DgtBackupPayload(
        schemaVersion: kDgtBackupSchemaVersion,
        exportedAt: DateTime.utc(2026, 5, 21),
        favorites: const ['q1'],
        failures: const [],
        streakSnapshot: 2,
        examDate: DateTime.utc(2026, 6, 1),
        dailyGoal: 30,
        licenseCode: 'B',
        simulacros: const [],
        sprints: const [],
      );
      final r = DgtBackupService.parseRaw(jsonEncode(original.toJson()));
      expect(r.isOk, isTrue);
      expect(r.payload!.favorites, ['q1']);
      expect(r.payload!.licenseCode, 'B');
      expect(r.payload!.examDate, DateTime.utc(2026, 6, 1));
    });

    test('error si el JSON no es Map', () {
      final r = DgtBackupService.parseRaw('[1,2,3]');
      expect(r.isOk, isFalse);
    });
  });
}
