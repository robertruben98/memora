# Memora Play Store Release — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This plan is also the source of truth for the parallel Workflow execution.

**Goal:** Dejar Memora (app Flutter `com.robertdev.memora`) lista para publicar en Google Play, cubriendo firma, ofuscación, política de permisos, borrado de cuenta (backend+app), documentos legales y ficha de tienda.

**Architecture:** 7 workstreams sobre 2 repos. `memora` (Flutter) recibe: build/firma (A), permisos (B), UI borrado (C2), docs legales/ficha/runbook (D/E/F). `memora-backend` (FastAPI+asyncpg) recibe: endpoint de borrado (C1). Workstreams tocan archivos disjuntos → paralelizables.

**Tech Stack:** Flutter 3.38.9 / Dart 3.10.8; Gradle Kotlin DSL + R8; FastAPI + asyncpg (Postgres); flutter_local_notifications; Riverpod.

**Repos & ramas:**
- `memora` → rama `feature/play-store-release` (ya creada).
- `memora-backend` → crear rama feature propia (p.ej. `feature/account-deletion`); commits directos a develop bloqueados por hook.

**Commit rules (hooks del repo):** prefijo conventional (`feat|fix|chore|docs|...`), **sin** `Co-authored-by`, sin marcadores AI/🤖, ≤150 chars. Pre-commit corre `dart format` + `flutter analyze` sobre `.dart` staged.

**Flutter binary:** `/home/arobertdev/.flutter-sdk/bin/flutter` (no en PATH; exportar `PATH` antes de comandos flutter).

---

## File Structure

**memora (Flutter):**
- Modify `android/app/build.gradle.kts` — R8 + shrink.
- Create `android/app/proguard-rules.pro` — keep rules.
- Create `android/key.properties.example` — plantilla firma.
- Modify `android/app/src/main/AndroidManifest.xml` — quitar permisos exact-alarm, label.
- Modify `lib/features/dgt/dgt_weekly_report_scheduler.dart` — inexact.
- Modify `lib/features/dgt/dgt_reminder_service.dart` — inexact.
- Modify `lib/data/api/api_client.dart` — `deleteAccount()`.
- Modify `lib/features/auth/auth_state.dart` — exponer borrado/limpieza si hace falta.
- Modify `lib/features/settings/settings_screen.dart` — tile "Eliminar cuenta".
- Create `docs/PLAY_STORE_RELEASE.md` — runbook + checklist.
- Create `docs/legal/privacy-es.md`, `docs/legal/privacy-es.html`.
- Create `docs/legal/account-deletion.md`, `docs/legal/account-deletion.html`.
- Create `docs/legal/data-safety.md`.
- Create `docs/store/listing-es.md`.
- Create `docs/store/feature-graphic.html`.

**memora-backend (FastAPI):**
- Modify `app/main.py` — endpoint `DELETE /account`.

---

## WORKSTREAM A — Firma & build

### Task A1: ProGuard rules

**Files:** Create `android/app/proguard-rules.pro`

- [ ] **Step 1: Crear archivo** con este contenido exacto:

```proguard
# Flutter / embedding
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# flutter_local_notifications (Dexterous) — receivers vía reflexión + Gson
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepclassmembers class * { @com.google.gson.annotations.SerializedName <fields>; }

# sqlite3_flutter_libs / drift — librería nativa cargada por JNI
-keep class org.sqlite.** { *; }

# flutter_tts
-keep class com.tundralabs.fluttertts.** { *; }

# video_player (ExoPlayer/Media3)
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# Play Core (split install referenciado por Flutter, puede faltar)
-dontwarn com.google.android.play.core.**

# Genéricos seguros
-keepattributes SourceFile,LineNumberTable
-keep class * extends java.util.ListResourceBundle { protected java.lang.Object[][] getContents(); }
```

- [ ] **Step 2: Commit**

```bash
git add android/app/proguard-rules.pro
git commit -m "build(android): add proguard keep rules para R8"
```

### Task A2: Activar R8 + shrink y enlazar proguard

**Files:** Modify `android/app/build.gradle.kts` (bloque `buildTypes.release`)

- [ ] **Step 1: Reemplazar el bloque release.** Estado actual:

```kotlin
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
```

Nuevo:

```kotlin
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
```

- [ ] **Step 2: Verificar build release enlaza (R8 no rompe).**

```bash
export PATH="/home/arobertdev/.flutter-sdk/bin:$PATH"
cd /home/arobertdev/code/apps/memora
flutter build apk --release 2>&1 | tail -30
```
Expected: `Built build/app/outputs/flutter-apk/app-release.apk`. Si hay `Missing class`/`ClassNotFound`, añadir `-keep`/`-dontwarn` a `proguard-rules.pro` (Task A1) y reconstruir. (Firma con debug si no hay keystore — OK para validar el enlace.)

- [ ] **Step 3: Commit**

```bash
git add android/app/build.gradle.kts
git commit -m "build(android): habilitar R8 minify + resource shrinking en release"
```

### Task A3: Plantilla key.properties + label launcher

**Files:** Create `android/key.properties.example`; Modify `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Crear `android/key.properties.example`:**

```properties
# Copia este archivo a android/key.properties y rellena con tus datos.
# android/key.properties está en .gitignore — NUNCA lo subas.
storePassword=CAMBIA_ESTO
keyPassword=CAMBIA_ESTO
keyAlias=upload
# Ruta absoluta al keystore generado con keytool (ver docs/PLAY_STORE_RELEASE.md)
storeFile=/home/arobertdev/keys/memora-upload-keystore.jks
```

- [ ] **Step 2: Cambiar label.** En `AndroidManifest.xml`, `android:label="memora"` → `android:label="Memora"`.

- [ ] **Step 3: Commit**

```bash
git add android/key.properties.example android/app/src/main/AndroidManifest.xml
git commit -m "build(android): plantilla key.properties y label de launcher 'Memora'"
```

---

## WORKSTREAM B — Permisos (alarmas inexactas)

### Task B1: Quitar permisos de alarma exacta

**Files:** Modify `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Eliminar estas 2 líneas:**

```xml
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
```
Mantener `INTERNET`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` y los `<receiver>`/`<queries>` existentes.

### Task B2: Schedulers a modo inexacto

**Files:** Modify `lib/features/dgt/dgt_weekly_report_scheduler.dart`, `lib/features/dgt/dgt_reminder_service.dart`

- [ ] **Step 1: `dgt_weekly_report_scheduler.dart` (~línea 145).** Cambiar `androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle` → `androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle`. Si existe un try/catch que reintenta en inexacto tras fallar exacto, dejar solo la llamada inexacta (una sola).

- [ ] **Step 2: `dgt_reminder_service.dart` (~línea 228).** Igual: `exactAllowWhileIdle` → `inexactAllowWhileIdle` y colapsar el try/catch exact-first a una sola llamada inexacta. Quitar cualquier `requestExactAlarmsPermission()` si existe.

- [ ] **Step 3: Verificar analyze + tests.**

```bash
export PATH="/home/arobertdev/.flutter-sdk/bin:$PATH"
cd /home/arobertdev/code/apps/memora
flutter analyze lib/features/dgt/ && flutter test test/ 2>&1 | tail -15
```
Expected: analyze sin errores; tests de scheduling/notif pasan. Si un test asertaba `exactAllowWhileIdle`, actualizarlo a `inexactAllowWhileIdle`.

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml lib/features/dgt/dgt_weekly_report_scheduler.dart lib/features/dgt/dgt_reminder_service.dart
git commit -m "fix(dgt): recordatorios con alarmas inexactas y quitar permisos sensibles"
```

---

## WORKSTREAM C — Borrado de cuenta (backend + app)

### Task C1: Backend `DELETE /account`

**Files:** Modify `memora-backend/app/main.py`

Tablas con datos del usuario (sin FK cascade desde `users`, por eso borrado explícito y transaccional, orden hijo→padre): `review_logs`, `card_schedules`, `cards`, `decks`, `app_settings`, `dgt_bookmarks`, `dgt_question_reports`, y por último `users`.

- [ ] **Step 1: Añadir handler** (junto a los otros `@app.delete`, p.ej. tras `delete_deck`). Usar el estilo existente (`Depends(conn)`, `Depends(current_user)`):

```python
@app.delete("/account", status_code=204)
async def delete_account(
    c: asyncpg.Connection = Depends(conn),
    user_id: str = Depends(current_user),
):
    """Borra la cuenta y TODOS sus datos (RGPD / política Play).

    Borrado transaccional en orden hijo→padre porque las tablas de datos
    añadieron user_id como columna plana (sin FK cascade a users)."""
    async with c.transaction():
        await c.execute("DELETE FROM review_logs WHERE user_id = $1", user_id)
        await c.execute("DELETE FROM card_schedules WHERE user_id = $1", user_id)
        await c.execute("DELETE FROM cards WHERE user_id = $1", user_id)
        await c.execute("DELETE FROM decks WHERE user_id = $1", user_id)
        await c.execute("DELETE FROM app_settings WHERE user_id = $1", user_id)
        await c.execute("DELETE FROM dgt_bookmarks WHERE user_id = $1", user_id)
        await c.execute("DELETE FROM dgt_question_reports WHERE user_id = $1", user_id)
        await c.execute("DELETE FROM users WHERE id = $1", user_id)
    return None
```

- [ ] **Step 2: Verificar import/firmas.** Confirmar que `conn`, `current_user`, `asyncpg` ya están importados (lo están — patrón usado en `delete_deck`). Confirmar nombres de tabla `dgt_bookmarks` y `dgt_question_reports` contra `init/14-dgt-bookmarks.sql` y `init/13-dgt-reports.sql`; si alguna columna no es `user_id`, ajustar. Si hay otras tablas con `user_id` no listadas, añadir su DELETE.

- [ ] **Step 3: Smoke test import.**

```bash
cd /home/arobertdev/code/apps/memora-backend
python -c "import ast; ast.parse(open('app/main.py').read()); print('OK syntax')"
```
Expected: `OK syntax`. Si hay suite (`pytest`), correrla.

- [ ] **Step 4: Commit (en rama feature del backend).**

```bash
cd /home/arobertdev/code/apps/memora-backend
git checkout -b feature/account-deletion 2>/dev/null || git checkout feature/account-deletion
git add app/main.py
git commit -m "feat(account): endpoint DELETE /account con borrado transaccional de datos"
```

### Task C2: App — método API + UI borrado

**Files:** Modify `lib/data/api/api_client.dart`, `lib/features/settings/settings_screen.dart`

- [ ] **Step 1: `api_client.dart` — añadir método** (la clase ya tiene `delete(path)`):

```dart
  Future<void> deleteAccount() async {
    await delete('/account');
  }
```

- [ ] **Step 2: `settings_screen.dart` — añadir tile** "Eliminar cuenta" (solo si `authProvider.isLoggedIn`), al final del `ListView`, en rojo, con doble confirmación. Usar `authedApiClientProvider`/cliente con token existente y `authProvider.notifier.logout()`:

```dart
          if (ref.watch(authProvider).isLoggedIn)
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text('Eliminar cuenta',
                  style: TextStyle(color: Colors.redAccent)),
              subtitle: const Text(
                  'Borra tu cuenta y todos tus datos del servidor. Irreversible.'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('¿Eliminar tu cuenta?'),
                    content: const Text(
                        'Se borrarán permanentemente tu cuenta, mazos, '
                        'progreso y estadísticas del servidor. No se puede deshacer.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Eliminar',
                              style: TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                );
                if (ok != true) return;
                try {
                  await ref.read(authedApiClientProvider).deleteAccount();
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Cuenta eliminada')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('No se pudo eliminar: $e')));
                  }
                }
              },
            ),
```

- [ ] **Step 3: Resolver el provider del cliente autenticado.** Buscar el nombre real (`grep -n "ApiClient" lib/data/api/api_client.dart` → cerca de línea 132 hay un provider con token). Usar ese nombre en `ref.read(...)`. Si el provider es family/otro nombre, ajustar.

- [ ] **Step 4: Verificar.**

```bash
export PATH="/home/arobertdev/.flutter-sdk/bin:$PATH"
cd /home/arobertdev/code/apps/memora
flutter analyze lib/features/settings/ lib/data/api/
```
Expected: sin errores.

- [ ] **Step 5: Commit (rama memora).**

```bash
git add lib/data/api/api_client.dart lib/features/settings/settings_screen.dart
git commit -m "feat(account): UI 'Eliminar cuenta' en ajustes con doble confirmacion"
```

---

## WORKSTREAM D — Legal

### Task D1: Política de privacidad

**Files:** Create `docs/legal/privacy-es.md` y `docs/legal/privacy-es.html`

- [ ] **Step 1: `privacy-es.md`** con estas secciones (contenido real, no placeholders): Responsable (robertruben98@gmail.com); Fecha de vigencia 2026-06-01; Datos recogidos: (a) email — identificación/gestión de cuenta, (b) contraseña — almacenada **hasheada (bcrypt)**, nunca en claro, (c) contenido de estudio (mazos, tarjetas), (d) progreso/actividad de estudio (repasos, estadísticas, favoritos DGT); Finalidad: sincronizar tu progreso entre dispositivos y operar la app; Base legal: ejecución del servicio/consentimiento; Cifrado: todo el tráfico vía HTTPS; Terceros: **no** se usan SDK de publicidad ni de analítica de terceros; **no** se venden ni comparten datos; Conservación: hasta que borres la cuenta; Tus derechos: acceso, rectificación y borrado — el borrado se hace desde la app (Ajustes → Eliminar cuenta) o escribiendo al contacto; Notificaciones locales: la app programa recordatorios locales (no se envían datos a terceros); Cambios a esta política. Texto claro en español.

- [ ] **Step 2: `privacy-es.html`** — mismo contenido en HTML mínimo autocontenido (un `<style>` simple, legible en móvil) para publicar en `https://memora.a-robertdev.com/privacidad`.

- [ ] **Step 3: Commit**

```bash
git add docs/legal/privacy-es.md docs/legal/privacy-es.html
git commit -m "docs(legal): politica de privacidad ES (md + html web-ready)"
```

### Task D2: Data Safety + página de borrado

**Files:** Create `docs/legal/data-safety.md`, `docs/legal/account-deletion.md`, `docs/legal/account-deletion.html`

- [ ] **Step 1: `data-safety.md`** — respuestas mapeadas al formulario de Play Console (formato pregunta→respuesta):
  - ¿Recopila/comparte datos? Recopila, **no** comparte.
  - Personal info → **Email**: recopilado, finalidad *Account management*, obligatorio, cifrado en tránsito, eliminable.
  - App activity → progreso de estudio (repasos, stats): recopilado, *App functionality / personalization*, cifrado en tránsito, eliminable.
  - User content → mazos y tarjetas creados: recopilado, *App functionality*, cifrado en tránsito, eliminable.
  - ¿Datos cifrados en tránsito? **Sí** (HTTPS).
  - ¿El usuario puede pedir borrado? **Sí**, in-app (Ajustes → Eliminar cuenta) + URL: `https://memora.a-robertdev.com/eliminar-cuenta`.
  - ¿Se venden datos? **No**. ¿SDK de ads/analytics de terceros? **No**.

- [ ] **Step 2: `account-deletion.md` + `.html`** — página pública: cómo borrar la cuenta desde la app (Ajustes → Eliminar cuenta), qué datos se eliminan (cuenta, mazos, tarjetas, progreso, estadísticas, favoritos), que es inmediato e irreversible, y contacto alternativo (robertruben98@gmail.com) para borrado sin la app. HTML mínimo autocontenido para `…/eliminar-cuenta`.

- [ ] **Step 3: Commit**

```bash
git add docs/legal/data-safety.md docs/legal/account-deletion.md docs/legal/account-deletion.html
git commit -m "docs(legal): data safety y pagina de borrado de cuenta"
```

---

## WORKSTREAM E — Ficha de tienda

### Task E1: Textos de ficha

**Files:** Create `docs/store/listing-es.md`

- [ ] **Step 1: Crear** con contenido real:
  - **Título** (≤30): `Memora: Test DGT 2026`
  - **Descripción corta** (≤80): redactar gancho DGT + repetición espaciada. Ej.: `Aprueba el test teórico DGT 2026 con repaso inteligente y simulacros reales.`
  - **Descripción completa** (≤4000): estructura con features REALES del repo (verificables): simulacros DGT 2026, repetición espaciada (SRS), modo audio (TTS) manos libres, preguntas de percepción de riesgo (vídeo), V/F rápido, recordatorio diario, estadísticas y evolución semanal, insignias/logros, compartir progreso con autoescuela (QR), backup/restore, modo oscuro, gratis. Incluir lista con viñetas y llamada a la acción. Tono español de España.
  - **Categoría**: Educación. **Etiquetas/keywords** sugeridas. **Content rating**: cuestionario → app educativa sin contenido sensible → ≈ PEGI 3 / Todos. **Email de contacto**: robertruben98@gmail.com. **URL privacidad**: `https://memora.a-robertdev.com/privacidad`.

- [ ] **Step 2: Commit**

```bash
git add docs/store/listing-es.md
git commit -m "docs(store): ficha de tienda ES (titulo, descripciones, categoria, rating)"
```

### Task E2: Specs de assets + feature graphic

**Files:** Create `docs/store/feature-graphic.html`; añadir sección de assets a `docs/store/listing-es.md`

- [ ] **Step 1: Sección "Assets gráficos" en `listing-es.md`** con specs Play y cómo producir cada uno:
  - Icono alta-res **512×512 PNG** (32-bit): exportar desde `assets/icon/icon.png` (redimensionar a 512). Comando: `flutter pub run flutter_launcher_icons` regenera mipmaps; para el icono de tienda usar `assets/icon/icon.png` escalado.
  - **Feature graphic 1024×500 PNG/JPG**: capturar `docs/store/feature-graphic.html` (ver Step 2).
  - **Screenshots de teléfono** (≥2, hasta 8; 16:9 o 9:16, lado mín 320, máx 3840): capturar de la app corriendo:
    ```bash
    export PATH="/home/arobertdev/.flutter-sdk/bin:$PATH"
    flutter run --release            # en emulador/dispositivo
    flutter screenshot --out=docs/store/shot-01.png    # repetir por pantalla
    # o: adb exec-out screencap -p > docs/store/shot-01.png
    ```
    Pantallas recomendadas: feed de repaso, simulacro DGT, resultado/aprobado, estadísticas, logros.

- [ ] **Step 2: `feature-graphic.html`** — página HTML de exactamente 1024×500 con fondo `#0E0E12` (brand), logo/nombre `Memora`, claim `Test DGT 2026 · Repaso inteligente`, estilo limpio. Para exportar a PNG: abrir en navegador a 1024×500 y captura, o `chromium --headless --screenshot --window-size=1024,500 docs/store/feature-graphic.html`. Documentar el comando dentro del HTML como comentario.

- [ ] **Step 3: Commit**

```bash
git add docs/store/feature-graphic.html docs/store/listing-es.md
git commit -m "docs(store): specs de assets y plantilla feature graphic 1024x500"
```

---

## WORKSTREAM F — Build & runbook

### Task F1: Runbook + checklist

**Files:** Create `docs/PLAY_STORE_RELEASE.md`

- [ ] **Step 1: Crear runbook** con estos pasos concretos:
  1. **Generar upload keystore** (el usuario, una vez):
     ```bash
     mkdir -p ~/keys
     keytool -genkey -v -keystore ~/keys/memora-upload-keystore.jks \
       -keyalg RSA -keysize 2048 -validity 10000 -alias upload
     # responde a las preguntas y GUARDA las contraseñas en gestor seguro
     ```
  2. **Crear `android/key.properties`** copiando `key.properties.example` y rellenando (storePassword, keyPassword, keyAlias=upload, storeFile=ruta absoluta al .jks). NUNCA commitear.
  3. **Construir AAB firmado**:
     ```bash
     export PATH="/home/arobertdev/.flutter-sdk/bin:$PATH"
     cd /home/arobertdev/code/apps/memora
     flutter build appbundle --release
     # salida: build/app/outputs/bundle/release/app-release.aab
     ```
  4. **Verificar 16 KB / nativo** (informativo): `unzip -l build/app/outputs/bundle/release/app-release.aab | grep -E "\.so"`.
  5. **Play Console**: crear cuenta dev ($25 único), crear app (nombre `Memora: Test DGT 2026`, idioma es-ES, app, gratis), activar **Play App Signing** (subes la clave de subida; Google gestiona la de firma).
  6. **Rellenar**: Data Safety (usar `docs/legal/data-safety.md`), Política de privacidad (URL `…/privacidad`), Content rating (cuestionario, ver `listing-es.md`), Categoría Educación, ficha (de `listing-es.md`), assets (icono/feature/screenshots de `docs/store/`), público objetivo, declaración de permisos (ya NO hay exact-alarm → nada que justificar).
  7. **Testing interno** → subir AAB → testers → validar.
  8. **Producción**: rollout gradual.
  - **Checklist final** (casillas): keystore generado y respaldado · key.properties local · `flutter build appbundle --release` OK · R8 sin crashes (probar APK release en dispositivo) · borrado de cuenta funciona contra backend desplegado · privacidad publicada en URL · borrado publicado en URL · Data Safety enviado · screenshots+feature subidos · target SDK 36 (cumple) · permisos limpios.

- [ ] **Step 2: Commit**

```bash
git add docs/PLAY_STORE_RELEASE.md
git commit -m "docs(release): runbook end-to-end y checklist de publicacion Play Store"
```

### Task F2 (opcional): CI build de AAB

**Files:** (opcional) `.github/workflows/release.yml`

- [ ] **Step 1:** Documentar en `PLAY_STORE_RELEASE.md` un job de GitHub Actions que, en tag `v*`, decodifica el keystore desde secret base64, escribe `key.properties` y corre `flutter build appbundle --release`, subiendo el AAB como artifact. No activar sin secrets (`KEYSTORE_BASE64`, `STORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`). Solo dejar el snippet listo. (Skip si se prefiere build local.)

---

## Verificación global (al cerrar)

```bash
export PATH="/home/arobertdev/.flutter-sdk/bin:$PATH"
cd /home/arobertdev/code/apps/memora
flutter analyze            # 0 errores
flutter test               # verde (ajustar tests de schedule si asertaban exact)
flutter build apk --release   # R8 enlaza sin ClassNotFound
cd /home/arobertdev/code/apps/memora-backend
python -c "import ast; ast.parse(open('app/main.py').read()); print('OK')"
```

## Self-Review (cobertura spec → plan)
- A (firma/build): A1 proguard, A2 R8, A3 keystore+label, SDK ya cumple → ✓
- B (permisos): B1 manifest, B2 schedulers → ✓
- C (borrado): C1 backend, C2 app+UI, página web en D2 → ✓
- D (legal): D1 privacidad, D2 data-safety+borrado → ✓
- E (ficha): E1 textos, E2 assets+feature → ✓
- F (runbook): F1 runbook+checklist, F2 CI opcional → ✓
- Sin placeholders en código; prosa larga (privacidad/ficha) especificada por cláusulas/campos obligatorios.
