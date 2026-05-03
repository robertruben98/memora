import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../database/database.dart';

/// Sincronización con el backend Postgres.
/// El servidor es la fuente de verdad; el Drift local es un cache.
class SyncService {
  final ApiClient _api;
  final MemoraDatabase _db;

  SyncService(this._api, this._db);

  /// Vuelca el estado del servidor al Drift local. Borra y reemplaza.
  Future<void> bootstrapFromServer() async {
    final data = await _api.get('/sync') as Map<String, dynamic>;

    await _db.transaction(() async {
      await _db.delete(_db.reviewLogs).go();
      await _db.delete(_db.cardSchedules).go();
      await _db.delete(_db.cards).go();
      await _db.delete(_db.decks).go();
      await _db.delete(_db.appSettings).go();

      for (final raw in (data['decks'] as List)) {
        final d = raw as Map<String, dynamic>;
        await _db.into(_db.decks).insert(
              DecksCompanion.insert(
                id: d['id'] as String,
                name: d['name'] as String,
                description: Value(d['description'] as String?),
                colorHex: Value(d['color_hex'] as String? ?? '#7C5CFF'),
                iconName: Value(d['icon_name'] as String? ?? 'style_rounded'),
                createdAt: (d['created_at'] as num).toInt(),
                updatedAt: (d['updated_at'] as num).toInt(),
              ),
            );
      }
      for (final raw in (data['cards'] as List)) {
        final c = raw as Map<String, dynamic>;
        await _db.into(_db.cards).insert(
              CardsCompanion.insert(
                id: c['id'] as String,
                deckId: c['deck_id'] as String,
                frontText: c['front_text'] as String,
                backText: c['back_text'] as String,
                frontImagePath: Value(c['front_image_path'] as String?),
                backImagePath: Value(c['back_image_path'] as String?),
                createdAt: (c['created_at'] as num).toInt(),
                updatedAt: (c['updated_at'] as num).toInt(),
              ),
            );
      }
      for (final raw in (data['schedules'] as List)) {
        final s = raw as Map<String, dynamic>;
        await _db.into(_db.cardSchedules).insert(
              CardSchedulesCompanion.insert(
                cardId: s['card_id'] as String,
                easeFactor: Value((s['ease_factor'] as num).toDouble()),
                intervalDays: Value((s['interval_days'] as num).toInt()),
                repetitions: Value((s['repetitions'] as num).toInt()),
                state: Value(s['state'] as String),
                nextReviewDate: (s['next_review_date'] as num).toInt(),
                lastReviewDate: Value((s['last_review_date'] as num?)?.toInt()),
              ),
            );
      }
      for (final raw in (data['review_logs'] as List)) {
        final l = raw as Map<String, dynamic>;
        await _db.into(_db.reviewLogs).insert(
              ReviewLogsCompanion.insert(
                cardId: l['card_id'] as String,
                reviewedAt: (l['reviewed_at'] as num).toInt(),
                result: l['result'] as String,
                previousIntervalDays:
                    (l['previous_interval_days'] as num).toInt(),
                newIntervalDays: (l['new_interval_days'] as num).toInt(),
              ),
            );
      }
      for (final raw in (data['settings'] as List)) {
        final s = raw as Map<String, dynamic>;
        await _db.into(_db.appSettings).insert(
              AppSettingsCompanion.insert(
                key: s['key'] as String,
                value: s['value'] as String,
              ),
            );
      }
    });
  }

  // ------ Decks ------

  Future<void> upsertDeck({
    required String id,
    required String name,
    String? description,
    required String colorHex,
    required String iconName,
  }) async {
    await _api.put('/decks/$id', {
      'id': id,
      'name': name,
      'description': description,
      'color_hex': colorHex,
      'icon_name': iconName,
    });
  }

  Future<void> deleteDeck(String id) async {
    await _api.delete('/decks/$id');
  }

  // ------ Cards ------

  Future<void> upsertCard({
    required String id,
    required String deckId,
    required String frontText,
    required String backText,
    String? frontImagePath,
    String? backImagePath,
  }) async {
    await _api.put('/cards/$id', {
      'id': id,
      'deck_id': deckId,
      'front_text': frontText,
      'back_text': backText,
      'front_image_path': frontImagePath,
      'back_image_path': backImagePath,
    });
  }

  Future<void> deleteCard(String id) async {
    await _api.delete('/cards/$id');
  }

  // ------ Reviews ------

  /// Devuelve la respuesta del servidor con el schedule actualizado.
  Future<Map<String, dynamic>> recordReview({
    required String cardId,
    required bool correct,
    required int nowMs,
  }) async {
    final res = await _api.post('/reviews', {
      'card_id': cardId,
      'correct': correct,
      'now_ms': nowMs,
    });
    return res as Map<String, dynamic>;
  }

  // ------ Settings ------

  Future<void> putSetting(String key, String value) async {
    await _api.put('/settings/$key', {'value': value});
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    ref.watch(apiClientProvider),
    ref.watch(databaseProvider),
  );
});
