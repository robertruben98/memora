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
  });
}

class DeckSummary {
  final String id;
  final String name;
  final Color color;
  final String iconName;
  final int dueCount;
  final int totalCount;
  final List<MemoraCard> cards;

  const DeckSummary({
    required this.id,
    required this.name,
    required this.color,
    required this.iconName,
    required this.dueCount,
    required this.totalCount,
    required this.cards,
  });
}
