import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/core/models/memora_card.dart';
import 'package:memora/features/review/feed_session_notifier.dart';

MemoraCard _card(String id) => MemoraCard(
      id: id,
      deckId: 'd',
      front: 'f-$id',
      back: 'b-$id',
      deck: 'D',
      deckIconName: 'style_rounded',
      deckColor: const Color(0xFF7C5CFF),
    );

void main() {
  group('FeedSessionNotifier', () {
    test('estado inicial: index=0, contadores=0, no completado', () {
      final n = FeedSessionNotifier([_card('a'), _card('b')]);
      expect(n.state.currentIndex, 0);
      expect(n.state.correctCount, 0);
      expect(n.state.incorrectCount, 0);
      expect(n.state.isCompleted, isFalse);
      expect(n.state.cards, hasLength(2));
    });

    test('registerAnswer(correct=true) incrementa correct', () {
      final n = FeedSessionNotifier([_card('a'), _card('b')]);
      n.registerAnswer(correct: true);
      expect(n.state.correctCount, 1);
      expect(n.state.incorrectCount, 0);
      expect(n.state.isCompleted, isFalse);
    });

    test('registerAnswer(correct=false) incrementa incorrect', () {
      final n = FeedSessionNotifier([_card('a'), _card('b')]);
      n.registerAnswer(correct: false);
      expect(n.state.correctCount, 0);
      expect(n.state.incorrectCount, 1);
      expect(n.state.isCompleted, isFalse);
    });

    test('cuando se responde la ultima card, isCompleted pasa a true', () {
      final n = FeedSessionNotifier([_card('a'), _card('b')]);
      n.setCurrentIndex(1); // estamos en la ultima
      n.registerAnswer(correct: true);
      expect(n.state.isCompleted, isTrue);
      expect(n.state.correctCount, 1);
    });

    test('sesion de una sola card se completa al primer answer', () {
      final n = FeedSessionNotifier([_card('a')]);
      n.registerAnswer(correct: false);
      expect(n.state.isCompleted, isTrue);
      expect(n.state.incorrectCount, 1);
    });

    test('setCurrentIndex actualiza el indice y es idempotente', () {
      final n = FeedSessionNotifier([_card('a'), _card('b'), _card('c')]);
      n.setCurrentIndex(2);
      expect(n.state.currentIndex, 2);

      final prevState = n.state;
      n.setCurrentIndex(2);
      // No deberia cambiar la referencia (early return)
      expect(identical(n.state, prevState), isTrue);
    });

    test('multiples respuestas acumulan correct e incorrect por separado', () {
      final n = FeedSessionNotifier(
        [_card('a'), _card('b'), _card('c'), _card('d')],
      );
      n.registerAnswer(correct: true);
      n.registerAnswer(correct: true);
      n.registerAnswer(correct: false);
      expect(n.state.correctCount, 2);
      expect(n.state.incorrectCount, 1);
      expect(n.state.isCompleted, isFalse);
    });

    test('copyWith respeta valores existentes cuando no se pasan', () {
      const s = FeedSessionState(
        cards: [],
        currentIndex: 3,
        correctCount: 7,
        incorrectCount: 2,
        isCompleted: true,
      );
      final s2 = s.copyWith(correctCount: 8);
      expect(s2.correctCount, 8);
      expect(s2.currentIndex, 3);
      expect(s2.incorrectCount, 2);
      expect(s2.isCompleted, isTrue);
    });
  });
}
