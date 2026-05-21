import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/api/api_client.dart';
import 'package:memora/data/repositories/dgt_repository.dart';
import 'package:memora/features/dgt/dgt_favorites_provider.dart';
import 'package:memora/features/dgt/dgt_favorites_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue #188 (dgt-ux): tests del filtro por topic en [DgtFavoritesScreen].
///
/// Cubre:
/// - Chips horizontales renderizan "Todos" + topics distintos presentes en
///   favoritas (ordenados alfa).
/// - Default seleccionada chip "Todos", muestra todas las preguntas.
/// - Tap en chip de topic filtra la lista in-memory.
/// - Tap en topic con 0 preguntas reales no aplica (no se ofrece chip).
/// - Empty state cuando el filtro deja 0 resultados.
/// - Contador "N pregunta(s)" se actualiza al cambiar filtro.

DgtQuestion _q(String id, {String? topic}) => DgtQuestion(
      id: id,
      statement: 'Enunciado $id',
      optionA: 'A $id',
      optionB: 'B $id',
      optionC: 'C $id',
      correct: 'a',
      topic: topic,
    );

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://test.invalid', token: 'fake');
}

/// Repo de test que devuelve un set fijo de preguntas sin tocar la red.
class _FakeDgtRepo extends DgtRepository {
  final List<DgtQuestion> all;
  _FakeDgtRepo(this.all) : super(_FakeApi());

  @override
  Future<List<DgtQuestion>> fetchExamQuestions({
    int limit = 30,
    bool forceRefresh = false,
  }) async =>
      all;
}

Future<void> _pump(
  WidgetTester tester, {
  required List<DgtQuestion> bank,
  required Set<String> favoriteIds,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    kDgtFavoritesPrefsKey: favoriteIds.toList(),
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dgtRepositoryProvider.overrideWithValue(_FakeDgtRepo(bank)),
      ],
      child: const MaterialApp(home: DgtFavoritesScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('DgtFavoritesScreen filtro por topic (issue #188)', () {
    testWidgets('renderiza chips "Todos" + topics distintos (orden alfa)',
        (tester) async {
      final bank = [
        _q('q1', topic: 'Senales'),
        _q('q2', topic: 'Normas'),
        _q('q3', topic: 'Mecanica'),
        _q('q4', topic: 'Senales'),
      ];
      await _pump(
        tester,
        bank: bank,
        favoriteIds: {'q1', 'q2', 'q3', 'q4'},
      );

      // Chip "Todos" siempre presente.
      expect(find.byKey(const ValueKey('topic-chip-__all__')), findsOneWidget);
      // 3 topics distintos.
      expect(find.byKey(const ValueKey('topic-chip-Senales')), findsOneWidget);
      expect(find.byKey(const ValueKey('topic-chip-Normas')), findsOneWidget);
      expect(find.byKey(const ValueKey('topic-chip-Mecanica')), findsOneWidget);
      // Solo 1 chip "Senales" aunque haya 2 favoritas con ese topic
      // (las 2 favoritas muestran el topic en el subtitle, asi que
      // hay 3 widgets con texto "Senales" en total: 1 chip + 2 tiles).
      expect(find.text('Senales'), findsNWidgets(3));
    });

    testWidgets('default "Todos" muestra todas las preguntas favoritas',
        (tester) async {
      final bank = [
        _q('q1', topic: 'Senales'),
        _q('q2', topic: 'Normas'),
      ];
      await _pump(tester, bank: bank, favoriteIds: {'q1', 'q2'});

      expect(find.text('Enunciado q1'), findsOneWidget);
      expect(find.text('Enunciado q2'), findsOneWidget);
      // Contador refleja total.
      expect(
        find.byKey(const ValueKey('favorites-counter')),
        findsOneWidget,
      );
      expect(find.text('2 preguntas'), findsOneWidget);
    });

    testWidgets('tap chip de topic filtra lista a ese topic', (tester) async {
      final bank = [
        _q('q1', topic: 'Senales'),
        _q('q2', topic: 'Normas'),
        _q('q3', topic: 'Senales'),
      ];
      await _pump(tester, bank: bank, favoriteIds: {'q1', 'q2', 'q3'});

      // Antes del tap: las 3 preguntas visibles.
      expect(find.text('Enunciado q1'), findsOneWidget);
      expect(find.text('Enunciado q2'), findsOneWidget);
      expect(find.text('Enunciado q3'), findsOneWidget);
      expect(find.text('3 preguntas'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('topic-chip-Senales')));
      await tester.pumpAndSettle();

      // q1 y q3 (Senales) visibles, q2 (Normas) NO.
      expect(find.text('Enunciado q1'), findsOneWidget);
      expect(find.text('Enunciado q3'), findsOneWidget);
      expect(find.text('Enunciado q2'), findsNothing);
      expect(find.text('2 preguntas'), findsOneWidget);
    });

    testWidgets('volver a "Todos" restaura lista completa', (tester) async {
      final bank = [
        _q('q1', topic: 'Senales'),
        _q('q2', topic: 'Normas'),
      ];
      await _pump(tester, bank: bank, favoriteIds: {'q1', 'q2'});

      await tester.tap(find.byKey(const ValueKey('topic-chip-Senales')));
      await tester.pumpAndSettle();
      expect(find.text('Enunciado q2'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('topic-chip-__all__')));
      await tester.pumpAndSettle();
      expect(find.text('Enunciado q1'), findsOneWidget);
      expect(find.text('Enunciado q2'), findsOneWidget);
      expect(find.text('2 preguntas'), findsOneWidget);
    });

    testWidgets('preguntas sin topic no generan chip pero aparecen en "Todos"',
        (tester) async {
      final bank = [
        _q('q1', topic: 'Senales'),
        _q('q2'), // sin topic
      ];
      await _pump(tester, bank: bank, favoriteIds: {'q1', 'q2'});

      expect(find.byKey(const ValueKey('topic-chip-Senales')), findsOneWidget);
      // En "Todos" ambas aparecen.
      expect(find.text('Enunciado q1'), findsOneWidget);
      expect(find.text('Enunciado q2'), findsOneWidget);
    });
  });
}
