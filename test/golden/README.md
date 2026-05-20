# Golden tests Flutter (issue #132)

Tests de regresion visual para pantallas DGT criticas. Capturan un PNG de
referencia (`goldens/*.png`) y fallan si el render cambia entre runs.

## Cobertura actual

- `dgt_result_screen_test.dart` -> veredicto aprobado y suspenso (>=27/30
  vs <27/30, criterio DGT permiso B).
- `dgt_topic_stats_screen_test.dart` -> lista mix experto/intermedio/debil
  con un tema "Sin tocar" (issue #117), y estado empty.

## Regenerar goldens

Despues de un cambio visual *intencional* (rediseno, paleta, padding):

```bash
flutter test --update-goldens test/golden/
```

Verifica el PNG resultante antes de commitear:

```bash
git diff --stat test/golden/goldens/
```

Si solo cambia un PR de visual intencional, commit el `.png`. Si cambia
sin que tocaras esa pantalla -> es regresion, no actualices el golden,
arregla el codigo.

## CI

`.github/workflows/ci.yml` corre `flutter test` (sin `--update-goldens`).
Si los goldens difieren del PNG comiteado, el test falla y bloquea el PR.
El artefacto del diff queda en `test/golden/failures/` localmente para
debug (ese directorio esta gitignored).

## Tolerancia

`dgt_result_screen` usa `TolerantGoldenComparator(tolerance: 0.01)` -
margen 1% de pixel diff. Necesario porque `ConfettiWidget` (animado) no
se puede congelar 100% deterministicamente. Tolerancia sigue capturando
regresiones reales (>=2% pixel diff es cambio estructural). Otros tests
usan tolerancia default (0%).

## Helpers

`test/helpers/golden_helpers.dart`:
- `wrapForGolden(widget)` - MaterialApp con dark theme identico al runtime.
- `useGoldenSurface(tester)` - fija surface a 392x780 (movil medio).
- `TolerantGoldenComparator` - subclase de `LocalFileComparator` con tolerancia.
