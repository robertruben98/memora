# memora

A new Flutter project.

## Arquitectura

Para una vision general del pivot DGT (registry pattern, controllers extraidos, cache schema handshake, backup/restore, CI y deployment) ver [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Setup local hooks

El repo incluye un `pre-commit` compartido en `tool/hooks/pre-commit` que corre
`dart format --set-exit-if-changed` y `flutter analyze --fatal-infos` **solo sobre
los archivos `.dart` staged** (objetivo <3s en una laptop tipica). Esto evita gastar
minutos de CI por errores de formato detectables en local.

Instalacion (una sola vez por clone):

```bash
./tool/install-hooks.sh
```

El script crea symlinks desde `.git/hooks/` hacia `tool/hooks/` (no copia, asi cualquier
actualizacion del hook llega via `git pull` sin reinstalar). Si ya tienes un hook custom
instalado te avisa y NO sobreescribe; usa `./tool/install-hooks.sh --force` si quieres
reemplazarlo.

Bypass de emergencia (no abusar):

```bash
SKIP_HOOKS=1 git commit -m "wip: ..."
```

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

## APK size budget

El workflow `Flutter CI` incluye un job `apk-size-budget` que **solo se ejecuta en pull requests** y vigila que el APK release no crezca silenciosamente.

Como funciona:

1. Compila `flutter build apk --release --target-platform android-arm64`.
2. Lee `.github/apk-size-budget.txt` (un numero en MB, ej. `60`).
3. Lee la env var `APK_SIZE_TOLERANCE_MB` (por defecto `2`).
4. Falla si el tamano real supera `baseline + tolerancia`.
5. Comenta en el PR el delta vs baseline (`+0.30 MB` / `-0.15 MB`).

### Como actualizar el baseline

Si una PR introduce un crecimiento **legitimo** (nuevo feature, asset necesario, dependencia justificada):

1. Mira el delta reportado en el comentario del bot en el PR (`+X.XX MB`).
2. Actualiza `.github/apk-size-budget.txt` con el nuevo numero en MB (entero o decimal).
3. Commitea en el mismo PR.
4. Explica brevemente en la descripcion del PR el motivo del crecimiento.

Asi mantenemos un numero de referencia para futuras optimizaciones y evitamos regresiones silenciosas de tamano.

## Licencia

Este proyecto está bajo una **Licencia de Código Compartido (Uso No Comercial)**. Queda permitido el uso personal, de aprendizaje y modificación con fines educativos no comerciales. Está estrictamente prohibida la redistribución comercial, reventa o explotación lucrativa del código o sus aplicaciones compiladas. Ver el archivo [LICENSE](LICENSE) para más detalles.
