import 'package:drift/drift.dart';

@DataClassName('DeckRow')
class Decks extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().nullable()();
  TextColumn get colorHex => text().withDefault(const Constant('#7C5CFF'))();
  TextColumn get iconName =>
      text().withDefault(const Constant('style_rounded'))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CardRow')
class Cards extends Table {
  TextColumn get id => text()();
  TextColumn get deckId =>
      text().references(Decks, #id, onDelete: KeyAction.cascade)();
  TextColumn get frontText => text()();
  TextColumn get backText => text()();
  TextColumn get frontImagePath => text().nullable()();
  TextColumn get backImagePath => text().nullable()();
  // DGT pivot prep (schema v2): cardType permite distinguir flashcard vs
  // dgt_question. questionPayloadJson guarda payload tipado (multi-choice,
  // explicacion, normativa). NULL/'flashcard' preserva el comportamiento actual.
  TextColumn get cardType => text().withDefault(const Constant('flashcard'))();
  TextColumn get questionPayloadJson => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CardScheduleRow')
class CardSchedules extends Table {
  TextColumn get cardId =>
      text().references(Cards, #id, onDelete: KeyAction.cascade)();
  RealColumn get easeFactor => real().withDefault(const Constant(2.5))();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  TextColumn get state => text().withDefault(const Constant('new'))();
  IntColumn get nextReviewDate => integer()();
  IntColumn get lastReviewDate => integer().nullable()();

  @override
  Set<Column> get primaryKey => {cardId};
}

@DataClassName('ReviewLogRow')
class ReviewLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get cardId =>
      text().references(Cards, #id, onDelete: KeyAction.cascade)();
  IntColumn get reviewedAt => integer()();
  TextColumn get result => text()();
  IntColumn get previousIntervalDays => integer()();
  IntColumn get newIntervalDays => integer()();
}

@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
