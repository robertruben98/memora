import 'package:flutter/material.dart';

class DeckVisuals {
  static const palette = <String>[
    '#7C5CFF', // violet
    '#4F8AFF', // blue
    '#4FFFB0', // green
    '#FFD24F', // amber
    '#FF8A4F', // orange
    '#FF4F6B', // red
    '#E04FFF', // pink
    '#4FFFE9', // teal
    '#A8FF4F', // lime
    '#9E9E9E', // gray
  ];

  static const icons = <DeckIconOption>[
    DeckIconOption('style_rounded', Icons.style_rounded),
    DeckIconOption('translate_rounded', Icons.translate_rounded),
    DeckIconOption('public_rounded', Icons.public_rounded),
    DeckIconOption('code_rounded', Icons.code_rounded),
    DeckIconOption('psychology_rounded', Icons.psychology_rounded),
    DeckIconOption('palette_rounded', Icons.palette_rounded),
    DeckIconOption('school_rounded', Icons.school_rounded),
    DeckIconOption('fitness_center_rounded', Icons.fitness_center_rounded),
    DeckIconOption('restaurant_rounded', Icons.restaurant_rounded),
    DeckIconOption('music_note_rounded', Icons.music_note_rounded),
    DeckIconOption('science_rounded', Icons.science_rounded),
    DeckIconOption('history_edu_rounded', Icons.history_edu_rounded),
  ];

  static IconData iconFor(String name) {
    for (final i in icons) {
      if (i.name == name) return i.icon;
    }
    return Icons.style_rounded;
  }

  static Color colorFromHex(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    final value = int.parse(cleaned, radix: 16);
    if (cleaned.length == 6) {
      return Color(0xFF000000 | value);
    }
    return Color(value);
  }
}

class DeckIconOption {
  final String name;
  final IconData icon;

  const DeckIconOption(this.name, this.icon);
}
