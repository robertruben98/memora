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

  /// Constructor para tests / inyeccion (in-memory). Aditivo, no usado en
  /// runtime normal.
  MemoraDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // v1 -> v2: anadir columnas cardType y questionPayloadJson a Cards
          // (pivot DGT). Aditivo, sin perder filas existentes.
          if (from < 2) {
            await m.addColumn(cards, cards.cardType);
            await m.addColumn(cards, cards.questionPayloadJson);
          }
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
