import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/memora_card.dart';

class FeedSessionState {
  final List<MemoraCard> cards;
  final int currentIndex;
  final int correctCount;
  final int incorrectCount;
  final bool isCompleted;

  const FeedSessionState({
    required this.cards,
    this.currentIndex = 0,
    this.correctCount = 0,
    this.incorrectCount = 0,
    this.isCompleted = false,
  });

  FeedSessionState copyWith({
    List<MemoraCard>? cards,
    int? currentIndex,
    int? correctCount,
    int? incorrectCount,
    bool? isCompleted,
  }) {
    return FeedSessionState(
      cards: cards ?? this.cards,
      currentIndex: currentIndex ?? this.currentIndex,
      correctCount: correctCount ?? this.correctCount,
      incorrectCount: incorrectCount ?? this.incorrectCount,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class FeedSessionNotifier extends StateNotifier<FeedSessionState> {
  FeedSessionNotifier(List<MemoraCard> cards)
      : super(FeedSessionState(cards: cards));

  void registerAnswer({required bool correct}) {
    final newCorrect = state.correctCount + (correct ? 1 : 0);
    final newIncorrect = state.incorrectCount + (correct ? 0 : 1);
    final isLast = state.currentIndex >= state.cards.length - 1;
    state = state.copyWith(
      correctCount: newCorrect,
      incorrectCount: newIncorrect,
      isCompleted: isLast,
    );
  }

  void setCurrentIndex(int index) {
    if (index == state.currentIndex) return;
    state = state.copyWith(currentIndex: index);
  }
}

final feedSessionProvider = StateNotifierProvider.autoDispose
    .family<FeedSessionNotifier, FeedSessionState, List<MemoraCard>>(
  (ref, cards) => FeedSessionNotifier(cards),
);
