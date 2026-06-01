# Memora — Play Store Release Readiness (Design Spec)

- **Fecha:** 2026-06-01
- **Repos:** `memora` (Flutter app) + `memora-backend` (FastAPI + asyncpg/Postgres)
- **Objetivo:** dejar Memora lista para publicar en Google Play, cubriendo gates técnicos, de política y de ficha de tienda.
- **Entrega:** commits directos en `develop` (decisión del usuario). Ejecución vía Workflow paralelo (ultracode).

## Contexto actual (verificado)

| Item | Estado |
|---|---|
| Toolchain | Flutter 3.38.9 stable · Dart 3.10.8 |
| applicationId / namespace | `com.robertdev.memora` (inmutable tras publicar) |
| Versión | `2.6.0+31` (versionName 2.6.0 / versionCode 31) |
| SDK levels (default Flutter) | compileSdk=36, targetSdk=36, minSdk=24 → **cumple Play 2025 (target≥35) y 16 KB** |
| Firma release | `signingConfigs.release` existe pero gated por `key.properties` (ausente) → cae a debug. **No hay keystore de release.** |
| Minify / shrink | `isMinifyEnabled=false`, `isShrinkResources=false` → **off** |
| ProGuard | **No existe** `proguard-rules.pro` |
| Iconos / splash | `flutter_launcher_icons` + `flutter_native_splash` configurados (OK) |
| Launcher label | `android:label="memora"` (minúscula) |
| Red | HTTPS a `https://memora-api.a-robertdev.com` (sin cleartext) |
| Auth / PII | email + password (bcrypt) → JWT HS256; token en SharedPreferences |
| Datos sincronizados | decks, cards, card_schedules, review_logs, dgt_bookmarks, settings |
| Borrado de cuenta | **No existe** endpoint ni UI (requisito Play) |
| Permisos manifest | INTERNET, POST_NOTIFICATIONS, **SCHEDULE_EXACT_ALARM**, **USE_EXACT_ALARM**, RECEIVE_BOOT_COMPLETED |
| Notificaciones | `flutter_local_notifications` con `exactAllowWhileIdle` en 2 sitios (ya tienen fallback inexact) |
| Política privacidad / Data Safety / ficha | **No existen** |

## Decisiones tomadas

1. **Alcance:** completo — código + firma + legal + ficha + checklist.
2. **Nombre tienda:** `Memora: Test DGT 2026` (21 chars, ≤30).
3. **Recordatorios:** cambiar a alarmas **inexactas**; eliminar permisos sensibles.
4. **Firma/cuenta:** empezar de cero — generar keystore + guía Play Console + Play App Signing.
5. **Borrado de cuenta:** implementar backend + app.
6. **Git:** commits directos en `develop`.

## Workstreams

### A — Firma & build (código + acción del usuario)
- **A1** Documentar comando `keytool` para generar `upload-keystore.jks` (el usuario ejecuta y guarda contraseñas; nunca a git — ya gitignored).
- **A2** Crear `android/key.properties.example` (plantilla) + instrucciones de colocación.
- **A3** Activar R8: en `android/app/build.gradle.kts` release → `isMinifyEnabled=true`, `isShrinkResources=true`.
- **A4** Crear `android/app/proguard-rules.pro` con keep/dontwarn para: drift + sqlite3_flutter_libs, flutter_local_notifications (Dexterous), flutter_tts, video_player, file_picker, share_plus, image_picker. Verificar que `flutter build apk --release` enlaza sin romper.
- **A5** Cambiar launcher `android:label` `memora` → `Memora`.
- **A6** Verificación: SDK levels ya cumplen (target=36); no pinear salvo que el build lo exija. Confirmar 16 KB en runbook.

### B — Permisos (código, app)
- **B1** Quitar `SCHEDULE_EXACT_ALARM` y `USE_EXACT_ALARM` de `AndroidManifest.xml`. Mantener INTERNET, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED.
- **B2** `dgt_weekly_report_scheduler.dart:145` y `dgt_reminder_service.dart:228`: `AndroidScheduleMode.exactAllowWhileIdle` → `inexactAllowWhileIdle`. Simplificar el try/catch exact-first (ya no se pide permiso exacto). No romper tests de scheduling.

### C — Borrado de cuenta (backend + app) — política Play
- **C1 backend:** `DELETE /account` autenticado en `app/main.py` (estilo `@app.delete`). En una transacción asyncpg borra todas las filas con `user_id` del usuario (decks, cards, card_schedules, review_logs, dgt_bookmarks, settings) y finalmente la fila en `users`. Inspeccionar esquema real para cubrir todas las tablas y respetar FKs. Devolver 200/204.
- **C2 app:** tile "Eliminar cuenta" en perfil/ajustes → diálogo de confirmación (doble) → `ApiClient.deleteAccount()` → al éxito: logout (`AuthNotifier`), limpiar SharedPreferences y datos locales, volver a login/onboarding. Solo visible si `isLoggedIn`.
- **C3 web:** página pública de borrado (`docs/legal/account-deletion`) describiendo el método in-app + qué datos se borran + contacto. Para hospedar en `memora.a-robertdev.com/eliminar-cuenta`.

### D — Legal (entregables; el usuario hospeda)
- **D1** Política de privacidad en español (`docs/legal/privacy-es.md` + `privacy-es.html` web-ready). Cubre: datos recogidos (email, password hasheado, contenido de estudio, progreso/actividad), finalidad, base legal, HTTPS/cifrado en tránsito, **sin** SDKs de publicidad/tracking de terceros, retención, derecho de borrado + cómo, contacto (`robertruben98@gmail.com`), responsable, fecha.
- **D2** Respuestas del formulario **Data Safety** (`docs/legal/data-safety.md`) mapeadas a Play Console: Email (gestión de cuenta, obligatorio, no compartido), User content (mazos/cards), App activity (progreso de estudio). Cifrado en tránsito = sí. Datos vendidos/compartidos = no. Borrado disponible = sí (in-app + URL).

### E — Ficha de tienda (entregables; screenshots los captura el usuario)
- **E1** `docs/store/listing-es.md`: título `Memora: Test DGT 2026`, descripción corta (≤80), descripción completa (≤4000; enfoque DGT 2026 + repetición espaciada + features reales del repo), categoría **Educación**, content rating (≈PEGI 3 / Todos), datos de contacto.
- **E2** Specs de assets gráficos + cómo producirlos:
  - Icono 512×512 (export de `assets/icon/icon.png`).
  - Feature graphic 1024×500: plantilla `docs/store/feature-graphic.html` para capturar a PNG.
  - ≥2 screenshots de teléfono: comandos `flutter`/`adb` para capturarlos desde la app corriendo.

### F — Build & runbook (docs/código)
- **F1** `docs/PLAY_STORE_RELEASE.md`: runbook end-to-end — generar keystore → `key.properties` → `flutter build appbundle --release` → Play App Signing → crear app en Console → testing interno → producción. Incluir checklist final y enlaces a D/E.
- **F2** (Opcional) Job CI que construya AAB firmado en tag, con secrets del keystore. Documentado pero no activado sin secrets.

## Verificación
- `flutter analyze` (binario en `/home/arobertdev/.flutter-sdk/bin/flutter`).
- `flutter test` (no romper tests de notificaciones/scheduling/auth).
- `flutter build apk --release` enlaza con R8 + proguard sin `ClassNotFound`/`missing_rules`.
- Backend: el endpoint de borrado compila y borra en transacción (test si hay suite).

## Plan de ejecución
Workflow paralelo: A, B, D, E, F tocan archivos disjuntos → paralelos. C toca backend+app (2 archivos) → paralelo con el resto. Worktree isolation para los agentes que mutan código. Verificación adversarial por workstream. Commits directos en `develop` al cerrar.

## Fuera de alcance
- iOS / App Store (config solo Android).
- Crash reporting / analytics SDK (no se añade; mantiene "sin tracking" para Data Safety).
- Capturar screenshots reales y crear el arte del feature graphic (se entregan specs + plantillas; los produce el usuario).
- Cambiar `applicationId` o esquema de versión.
