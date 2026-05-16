# memora

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Testing

Run the full test suite locally:

```bash
flutter test
```

Layout de tests:

- `test/core/srs/`: unit tests del algoritmo SM-2.
- `test/data/repositories/`: tests de repositorios contra una base Drift en memoria (`NativeDatabase.memory()` via `MemoraDatabase.forTesting`).
- `test/features/review/`: tests de `StudyQueueBuilder` y `FeedSessionNotifier`.
- `test/helpers/`: utilidades compartidas (`FakeSyncService` no toca red, `newInMemoryDb()` instancia la DB en memoria).
- `test/widget_test.dart`: smoke test ligero del `ProviderScope`.

Los tests no requieren conexion a internet ni al backend: el `SyncService` se sustituye por un fake.
