# Golden tests (issue #132)

Snapshots visuales de las pantallas criticas DGT para detectar regresiones
(overflow, color invertido, padding roto) que un test de widget normal no
captura.

## Que hay aqui

- `dgt_result_screen_test.dart`: veredicto aprobado/suspenso post-simulacro.
- `dgt_topic_stats_screen_test.dart`: lista de stats por tema (mix de
  niveles + estado empty).
- `goldens/`: imagenes PNG generadas. Se commitean al repo.

## Como ejecutar

```bash
# Verifica contra los goldens commiteados (lo que corre en CI).
flutter test test/golden/

# Regenera goldens tras un cambio visual intencionado.
flutter test --update-goldens test/golden/
```

## Cuando regenerar

Solo despues de un cambio visual deliberado (nueva paleta, refactor de
layout, ajuste de spacing). Revisar el diff de las imagenes en el PR antes
de mergear:

1. Hacer el cambio en `lib/features/dgt/*.dart`.
2. `flutter test --update-goldens test/golden/`.
3. `git diff --stat test/golden/goldens/` y abrir los PNG modificados.
4. Si los cambios coinciden con la intencion, commitear; si no, deshacer.

## Por que no usar `pumpAndSettle` en `dgt_result_screen`

La pantalla dispara un `ConfettiController` que emite frames indefinidamente
cuando el usuario aprueba. Usar `pumpAndSettle` cuelga el test. El helper
`pumpAfterConfetti` (en `test/helpers/golden_helpers.dart`) avanza el reloj
lo suficiente para que las particulas pierdan visibilidad sin esperar el
fin del stream.

## Plataforma

Los goldens se generan en CI (Linux) y deberian regenerarse desde Linux
para evitar diffs de antialiasing entre OS. Si trabajas en macOS y el
diff es solo ruido de fuente, regenera desde GitHub Actions o un contenedor
Linux.
