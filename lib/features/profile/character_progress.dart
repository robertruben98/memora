import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';

/// Progreso del personaje calculado de los review_logs y schedules.
class CharacterProgress {
  final int totalXp;
  final int level;
  final int xpInLevel;       // xp acumulada DENTRO del nivel actual
  final int xpForNextLevel;  // xp necesaria para subir
  final int totalReviews;
  final int correctReviews;
  final int streakDays;
  final String title;        // "Sabio del Recuerdo"
  final String className;    // "Sabio Arcano"
  final List<DeckProgress> decks;

  const CharacterProgress({
    required this.totalXp,
    required this.level,
    required this.xpInLevel,
    required this.xpForNextLevel,
    required this.totalReviews,
    required this.correctReviews,
    required this.streakDays,
    required this.title,
    required this.className,
    required this.decks,
  });

  double get progressToNext => xpForNextLevel == 0
      ? 0
      : (xpInLevel / xpForNextLevel).clamp(0.0, 1.0);

  double get hitRate =>
      totalReviews == 0 ? 0 : correctReviews / totalReviews;

  static const empty = CharacterProgress(
    totalXp: 0,
    level: 1,
    xpInLevel: 0,
    xpForNextLevel: 100,
    totalReviews: 0,
    correctReviews: 0,
    streakDays: 0,
    title: 'Aprendiz Reencarnado',
    className: 'Estudiante del Otro Mundo',
    decks: [],
  );
}

class DeckProgress {
  final String deckId;
  final String name;
  final String iconName;
  final String colorHex;
  final int reviews;
  final int correct;
  final int level;

  const DeckProgress({
    required this.deckId,
    required this.name,
    required this.iconName,
    required this.colorHex,
    required this.reviews,
    required this.correct,
    required this.level,
  });

  double get hitRate => reviews == 0 ? 0 : correct / reviews;
}

/// XP curve: cada nivel requiere `100 * N` XP, acumulada `100 * N*(N+1)/2`.
/// Lv 1 → 100, Lv 2 → 300, Lv 5 → 1500, Lv 10 → 5500.
int _cumulativeXpForLevel(int level) =>
    100 * level * (level + 1) ~/ 2;

int _xpToReach(int level) => _cumulativeXpForLevel(level - 1);

int _levelFromXp(int xp) {
  // Resolver: 100 * L * (L+1) / 2 <= xp
  // L^2 + L - xp/50 <= 0  →  L <= (-1 + sqrt(1 + xp*8/100)) / 2
  if (xp <= 0) return 1;
  var lvl = 1;
  while (_cumulativeXpForLevel(lvl) <= xp) {
    lvl++;
  }
  return lvl;
}

String _titleForLevel(int level) {
  if (level >= 50) return 'Sabio del Akashic';
  if (level >= 30) return 'Maestro de Mil Vidas';
  if (level >= 20) return 'Cronista Inmortal';
  if (level >= 15) return 'Sabio del Recuerdo';
  if (level >= 10) return 'Erudito Errante';
  if (level >= 6) return 'Adepto del Saber Antiguo';
  if (level >= 3) return 'Estudiante del Otro Mundo';
  return 'Aprendiz Reencarnado';
}

String _classFromDeck(String? deckName) {
  if (deckName == null) return 'Estudiante Reencarnado';
  final n = deckName.toLowerCase();
  if (n.contains('inglés') ||
      n.contains('ingles') ||
      n.contains('idioma') ||
      n.contains('phrasal') ||
      n.contains('expresion')) {
    return 'Polígloto Errante';
  }
  if (n.contains('algorit') ||
      n.contains('código') ||
      n.contains('codigo') ||
      n.contains('program')) {
    return 'Sabio Arcano';
  }
  if (n.contains('arte') ||
      n.contains('música') ||
      n.contains('musica') ||
      n.contains('pintur')) {
    return 'Bardo Iluminado';
  }
  if (n.contains('geograf') ||
      n.contains('histor') ||
      n.contains('cultura')) {
    return 'Cronista del Tiempo';
  }
  if (n.contains('aprend') ||
      n.contains('psico') ||
      n.contains('filos')) {
    return 'Filósofo Astral';
  }
  return 'Estudiante Reencarnado';
}

int _streakFromLogs(List<int> dayKeys) {
  if (dayKeys.isEmpty) return 0;
  final unique = dayKeys.toSet();
  final today = DateTime.now();
  var cursor = DateTime(today.year, today.month, today.day);
  var key = _dayKey(cursor);
  if (!unique.contains(key)) {
    cursor = cursor.subtract(const Duration(days: 1));
    key = _dayKey(cursor);
  }
  var streak = 0;
  while (unique.contains(key)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
    key = _dayKey(cursor);
  }
  return streak;
}

int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

final characterProgressProvider =
    FutureProvider<CharacterProgress>((ref) async {
  final db = ref.watch(databaseProvider);
  final logs = await db.reviewLogDao.getRecentLogs(limit: 50000);
  final allDecks = await db.deckDao.getAllDecks();

  // Stats globales
  int correct = 0;
  int total = 0;
  final dayKeys = <int>[];
  final perDeck = <String, _DeckAcc>{};
  for (final l in logs) {
    total++;
    if (l.result == 'correct') correct++;
    final dt = DateTime.fromMillisecondsSinceEpoch(l.reviewedAt);
    dayKeys.add(_dayKey(DateTime(dt.year, dt.month, dt.day)));
    // Need to resolve deck of this card. Map cardId -> deckId via cards table.
  }

  // Para mapear cardId -> deckId hacemos una sola consulta de cards.
  final cards = await db.cardDao.getAllCards();
  final cardToDeck = {for (final c in cards) c.id: c.deckId};

  for (final l in logs) {
    final deckId = cardToDeck[l.cardId];
    if (deckId == null) continue;
    final acc = perDeck.putIfAbsent(deckId, _DeckAcc.new);
    acc.reviews++;
    if (l.result == 'correct') acc.correct++;
  }

  // XP: aciertos 10pt, fallos 3pt. Bonus por streak: 5pt por día.
  final streak = _streakFromLogs(dayKeys);
  final totalXp = correct * 10 + (total - correct) * 3 + streak * 5;
  final level = _levelFromXp(totalXp);
  final xpAtCurrentLevelStart = _xpToReach(level);
  final xpForNextLevel =
      _cumulativeXpForLevel(level) - xpAtCurrentLevelStart;
  final xpInLevel = totalXp - xpAtCurrentLevelStart;

  // Mazo dominante (más reviews) define la clase.
  String? topDeckName;
  int topReviews = -1;
  final deckProgressList = <DeckProgress>[];
  final decksById = {for (final d in allDecks) d.id: d};
  for (final entry in perDeck.entries) {
    final deck = decksById[entry.key];
    if (deck == null) continue;
    if (entry.value.reviews > topReviews) {
      topReviews = entry.value.reviews;
      topDeckName = deck.name;
    }
    final deckXp = entry.value.correct * 10 + (entry.value.reviews - entry.value.correct) * 3;
    deckProgressList.add(
      DeckProgress(
        deckId: deck.id,
        name: deck.name,
        iconName: deck.iconName,
        colorHex: deck.colorHex,
        reviews: entry.value.reviews,
        correct: entry.value.correct,
        level: _levelFromXp(deckXp),
      ),
    );
  }
  // Mazos sin reviews aún (para mostrar lista completa)
  for (final d in allDecks) {
    if (perDeck.containsKey(d.id)) continue;
    deckProgressList.add(
      DeckProgress(
        deckId: d.id,
        name: d.name,
        iconName: d.iconName,
        colorHex: d.colorHex,
        reviews: 0,
        correct: 0,
        level: 1,
      ),
    );
  }
  deckProgressList.sort((a, b) => b.reviews.compareTo(a.reviews));

  return CharacterProgress(
    totalXp: totalXp,
    level: level,
    xpInLevel: xpInLevel,
    xpForNextLevel: xpForNextLevel,
    totalReviews: total,
    correctReviews: correct,
    streakDays: streak,
    title: _titleForLevel(level),
    className: _classFromDeck(topDeckName),
    decks: deckProgressList,
  );
});

class _DeckAcc {
  int reviews = 0;
  int correct = 0;
}
