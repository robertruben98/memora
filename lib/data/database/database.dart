import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/card_dao.dart';
import 'daos/deck_dao.dart';
import 'daos/review_log_dao.dart';
import 'daos/schedule_dao.dart';
import 'daos/settings_dao.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Decks, Cards, CardSchedules, ReviewLogs, AppSettings],
  daos: [DeckDao, CardDao, ScheduleDao, ReviewLogDao, SettingsDao],
)
class MemoraDatabase extends _$MemoraDatabase {
  MemoraDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbDir.path, 'memora.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

final databaseProvider = Provider<MemoraDatabase>((ref) {
  final db = MemoraDatabase();
  ref.onDispose(db.close);
  return db;
});
