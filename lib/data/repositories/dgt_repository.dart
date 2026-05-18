import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import 'dgt_local_bank.dart';

/// Pregunta DGT multi-choice (a/b/c).
class DgtQuestion {
  final String id;
  final String statement;
  final String? imageUrl;
  final String optionA;
  final String optionB;
  final String optionC;

  /// Letra correcta: 'a' | 'b' | 'c'.
  final String correct;
  final String? explanation;
  final String? topic;

  const DgtQuestion({
    required this.id,
    required this.statement,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.correct,
    this.imageUrl,
    this.explanation,
    this.topic,
  });

  factory DgtQuestion.fromJson(Map<String, dynamic> j) {
    return DgtQuestion(
      id: (j['id'] ?? '').toString(),
      statement: (j['statement'] ?? '').toString(),
      imageUrl: j['image_url'] as String?,
      optionA: (j['option_a'] ?? '').toString(),
      optionB: (j['option_b'] ?? '').toString(),
      optionC: (j['option_c'] ?? '').toString(),
      correct: (j['correct'] ?? 'a').toString().toLowerCase(),
      explanation: j['explanation'] as String?,
      topic: j['topic'] as String?,
    );
  }
}

class DgtRepository {
  final ApiClient _api;
  DgtRepository(this._api);

  /// Intenta GET /dgt/questions?limit=N. Si el endpoint no existe, usa
  /// banco local fallback ([dgtLocalBank]).
  Future<List<DgtQuestion>> fetchExamQuestions({int limit = 30}) async {
    try {
      final res = await _api.get('/dgt/questions', query: {'limit': '$limit'});
      if (res is List) {
        return res
            .map((e) => DgtQuestion.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (res is Map && res['questions'] is List) {
        return (res['questions'] as List)
            .map((e) => DgtQuestion.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Backend aun no expone /dgt/questions. Cae a fallback local.
    }
    return dgtLocalBank.take(limit).toList();
  }
}

final dgtRepositoryProvider = Provider<DgtRepository>((ref) {
  return DgtRepository(ref.watch(apiClientProvider));
});
