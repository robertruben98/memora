# memora

**Learn anything with spaced repetition — in a feed.** A Flutter study app that turns
decks of cards into an endless, swipeable feed and schedules every review with a
proper spaced-repetition algorithm, so the cards you're about to forget resurface
exactly when you need them.

## Highlights

- **SM-2 scheduling engine** — a clean, pure-Dart implementation of the SuperMemo 2
  algorithm (`lib/core/srs/`) with **zero Flutter or database dependencies**, so the
  scheduling logic is unit-testable in isolation and portable. Written to migrate to
  FSRS-4.5 without touching the rest of the app.
- **Feed-first UX** — reviews are presented as a continuous feed rather than a modal
  drill, lowering the friction of daily practice.
- **AI card generation** — generate cards for any topic on the fly (`features/ai_gen/`),
  so building a deck doesn't mean typing hundreds of cards by hand.
- **Local-first** — all data lives on-device in SQLite via **Drift**; the app works
  offline and syncs/exports on demand.
- **Deck management** — create, browse, import and share decks; import/export via file
  pickers and the native share sheet.

## Architecture

Feature-first, clean-architecture layout:

```
lib/
├── core/          # framework-agnostic building blocks
│   ├── srs/       # SM-2 spaced-repetition algorithm (pure Dart)
│   ├── models/    # domain models
│   ├── theme/     # design tokens & theming
│   └── widgets/   # shared UI primitives
├── data/          # Drift database, repositories, persistence
├── features/      # one folder per feature (decks, cards, study, review,
│                  # quest, stats, browse, ai_gen, onboarding, auth,
│                  # profile, settings, home, shell)
└── main.dart
```

**Stack:** Flutter · [Riverpod](https://riverpod.dev) (state) ·
[Drift](https://drift.simonbinder.eu) (typed local SQLite) · `image_picker` ·
`file_picker` · `share_plus` · `http`.

## Getting started

```bash
flutter pub get
dart run build_runner build   # generate Drift code
flutter run
```

Requires the Flutter SDK. See the [Flutter install guide](https://docs.flutter.dev/get-started/install).

## Status

Active personal project. The spaced-repetition core is the deliberate focus: an
algorithm kept independent of the UI and storage so it can be tested, reasoned about,
and swapped (SM-2 → FSRS) cleanly.

## License

MIT © Robert Ruben
