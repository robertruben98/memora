import 'package:http/http.dart' as http;
import 'package:memora/data/api/api_client.dart';
import 'package:memora/data/database/database.dart';
import 'package:memora/data/sync/sync_service.dart';

/// SyncService de pruebas: no toca red.
/// Permite inyectar la respuesta de `recordReview` para los tests SRS.
class FakeSyncService extends SyncService {
  FakeSyncService(MemoraDatabase db)
      : super(
          ApiClient(baseUrl: 'http://test', token: 'test', client: _NoopHttpClient()),
          db,
        );

  /// Resultado que se devuelve desde recordReview. Por defecto un schedule
  /// "aprendido" con 1 dia de intervalo.
  Map<String, dynamic> nextReviewResponse = {
    'interval_days': 1,
    'repetitions': 1,
    'ease_factor': 2.5,
    'state': 'learning',
    'next_review_date': 0,
  };

  final List<Map<String, dynamic>> recordedReviews = [];
  final List<String> upsertedCardIds = [];
  final List<String> deletedCardIds = [];

  @override
  Future<void> bootstrapFromServer() async {}

  @override
  Future<void> upsertDeck({
    required String id,
    required String name,
    String? description,
    required String colorHex,
    required String iconName,
  }) async {}

  @override
  Future<void> deleteDeck(String id) async {}

  @override
  Future<void> upsertCard({
    required String id,
    required String deckId,
    required String frontText,
    required String backText,
    String? frontImagePath,
    String? backImagePath,
  }) async {
    upsertedCardIds.add(id);
  }

  @override
  Future<void> deleteCard(String id) async {
    deletedCardIds.add(id);
  }

  @override
  Future<Map<String, dynamic>> recordReview({
    required String cardId,
    required bool correct,
    required int nowMs,
  }) async {
    recordedReviews.add({
      'card_id': cardId,
      'correct': correct,
      'now_ms': nowMs,
    });
    return Map<String, dynamic>.from(nextReviewResponse);
  }

  @override
  Future<void> putSetting(String key, String value) async {}
}

class _NoopHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw StateError(
      'FakeSyncService no debe llamar al http.Client real en tests.',
    );
  }
}
