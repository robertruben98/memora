import 'package:flutter/material.dart';

class MemoraCard {
  final String id;
  final String deckId;
  final String front;
  final String back;
  final String? frontImagePath; // relativa: "card_images/xxx.jpg"
  final String? backImagePath;
  final String deck;
  final String deckIconName;
  final Color deckColor;
  // DGT issue #42: refuerzo didactico al fallar.
  // Campos opcionales y aditivos: no afectan a flujos existentes.
  final String? explanation;
  final String? normativaRef;
  final String? sourceUrl;

  const MemoraCard({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    this.frontImagePath,
    this.backImagePath,
    required this.deck,
    required this.deckIconName,
    required this.deckColor,
    this.explanation,
    this.normativaRef,
    this.sourceUrl,
  });

  MemoraCard copyWith({
    String? id,
    String? deckId,
    String? front,
    String? back,
    String? frontImagePath,
    String? backImagePath,
    String? deck,
    String? deckIconName,
    Color? deckColor,
    String? explanation,
    String? normativaRef,
    String? sourceUrl,
  }) {
    return MemoraCard(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      front: front ?? this.front,
      back: back ?? this.back,
      frontImagePath: frontImagePath ?? this.frontImagePath,
      backImagePath: backImagePath ?? this.backImagePath,
      deck: deck ?? this.deck,
      deckIconName: deckIconName ?? this.deckIconName,
      deckColor: deckColor ?? this.deckColor,
      explanation: explanation ?? this.explanation,
      normativaRef: normativaRef ?? this.normativaRef,
      sourceUrl: sourceUrl ?? this.sourceUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MemoraCard &&
        other.id == id &&
        other.deckId == deckId &&
        other.front == front &&
        other.back == back &&
        other.frontImagePath == frontImagePath &&
        other.backImagePath == backImagePath &&
        other.deck == deck &&
        other.deckIconName == deckIconName &&
        other.deckColor == deckColor &&
        other.explanation == explanation &&
        other.normativaRef == normativaRef &&
        other.sourceUrl == sourceUrl;
  }

  @override
  int get hashCode => Object.hash(
        id,
        deckId,
        front,
        back,
        frontImagePath,
        backImagePath,
        deck,
        deckIconName,
        deckColor,
        explanation,
        normativaRef,
        sourceUrl,
      );
}

class DeckSummary {
  final String id;
  final String name;
  final Color color;
  final String iconName;
  final int dueCount;
  final int totalCount;
  final List<MemoraCard> cards;
  final int createdAt;

  const DeckSummary({
    required this.id,
    required this.name,
    required this.color,
    required this.iconName,
    required this.dueCount,
    required this.totalCount,
    required this.cards,
    this.createdAt = 0,
  });

  DeckSummary copyWith({
    String? id,
    String? name,
    Color? color,
    String? iconName,
    int? dueCount,
    int? totalCount,
    List<MemoraCard>? cards,
    int? createdAt,
  }) {
    return DeckSummary(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      iconName: iconName ?? this.iconName,
      dueCount: dueCount ?? this.dueCount,
      totalCount: totalCount ?? this.totalCount,
      cards: cards ?? this.cards,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DeckSummary) return false;
    if (other.id != id ||
        other.name != name ||
        other.color != color ||
        other.iconName != iconName ||
        other.dueCount != dueCount ||
        other.totalCount != totalCount ||
        other.createdAt != createdAt) {
      return false;
    }
    if (other.cards.length != cards.length) return false;
    for (var i = 0; i < cards.length; i++) {
      if (other.cards[i] != cards[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        color,
        iconName,
        dueCount,
        totalCount,
        Object.hashAll(cards),
        createdAt,
      );
}
