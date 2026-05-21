# Memora - Arquitectura DGT

> Ultima revision: 2026-05. Mantener este documento corto (< 350 lineas) y
> referenciar issues clave en vez de detalles volatiles que cambian seguido.

## 1. Overview del pivot DGT

Memora nacio como una app de flashcards generica (decks, SM-2, sync). En
2026 pivoto a **preparacion del examen teorico de la DGT en Espana**: el
usuario estudia preguntas oficiales por temas, hace simulacros cronometrados
(30 preguntas / 30 minutos, ≤3 fallos para aprobar) y revisa sus debilidades.

El nucleo SM-2 + capa de sync siguen vivos (codigo en `lib/core/srs/`,
`lib/data/sync/`), pero el grueso de la UX nueva esta en
`lib/features/dgt/`. El Study Hub (`lib/features/study/`) actua como
"vitrina" de todas las features DGT, ensambladas via un registry declarativo.

Producto pivotado en 2 repos:

- **backend** (`memora` FastAPI, Python): provee preguntas oficiales,
  estadisticas agregadas, normativa, prediccion de examen, etc.
- **frontend** (este repo, Flutter): UI, simulacros, cache local, backup.

## 2. Frontend (Flutter)

### 2.1 Estructura de carpetas (`lib/`)

```
lib/
  main.dart                     # Bootstrap + ProviderScope + Hive/SP init
  core/                         # Algoritmos puros + tematizacion
    srs/                        # SM-2 (preserva del producto original)
    models/                     # Modelos compartidos (no DGT-only)
    logging/                    # Logger con redaccion PII
    theme/                      # Tema light/dark + tokens
    widgets/                    # Widgets reutilizables (no feature-specific)
  data/
    api/                        # Cliente HTTP autogenerado vs OpenAPI
    database/                   # Drift schema (decks, cards, reviews SM-2)
    local/                      # Caches livianas (SharedPreferences/Hive)
      dgt_questions_cache.dart  # Cache JSON de /dgt/questions (issue #45/#156)
    repositories/               # Acceso unificado a backend + cache
    backup/                     # Export/import JSON (issue #175)
    storage/                    # Adaptadores SharedPreferences/Hive/SecureStorage
    sync/                       # Push/pull diff vs backend (SRS clasico)
    seeder.dart                 # Seed inicial de decks demo (legacy)
  features/
    dgt/                        # ★ FEATURE PRINCIPAL (pivot 2026)
      dgt_exam_controller.dart  # Controller del simulacro (testeable sin UI)
      dgt_exam_screen.dart      # Pantalla simulacro (capa fina sobre controller)
      dgt_warmup_screen.dart    # Calentamiento previo simulacro
      dgt_topics_screen.dart    # Estudio por temas
      dgt_practice_screen.dart  # Practica libre
      dgt_failures_*.dart       # Reincidencias / errores frecuentes
      dgt_settings*.dart        # Preferencias DGT (estricto, sonido, etc)
      models/                   # Payloads DTO (backup, snapshots)
      services/                 # Servicios stateless (backup_service, reminder)
      widgets/                  # Subcomponentes DGT
    study/                      # ★ HUB que ensambla DGT en una pantalla
      widgets/
        dgt_tile_spec.dart      # Spec declarativo (registry pattern)
        dgt_section.dart        # Lee kDgtTileRegistry y renderiza
    home/ browse/ profile/      # Shell de la app, perfil, navegacion
    onboarding/ auth/           # Login + intro DGT
    cards/ decks/ learn/ review/ study/ stats/   # Legacy SM-2 (vivo)
    ai_gen/ quest/              # Features experimentales
    settings/ shell/            # Settings globales + drawer
```

Regla de oro: **lo DGT-especifico vive en `features/dgt/`**, la "presentacion"
y orquestacion de tiles vive en `features/study/`, y los modulos clasicos
de flashcards quedan intactos en sus features propias para no romper la
linea legacy.

### 2.2 Tile registry pattern (Study Hub)

Issue #148 (dgt-tech). Cada feature DGT nueva se expone al Study Hub como
una entrada declarativa en una lista, sin tocar el widget que las renderiza.

**Archivos:**
- `lib/features/study/widgets/dgt_tile_spec.dart` (la "forma" del tile)
- `lib/features/study/widgets/dgt_section.dart` (registry + render)

**Anadir tile = anadir una entrada al registry**, no tocar cascade de
`if/else`, no duplicar `InkWell`/`Container`/`Material`:

```dart
// dgt_section.dart
final List<DgtTileSpec> kDgtTileRegistry = [
  DgtTileSpec(
    title: 'Simulacro',
    subtitleBuilder: (ref) => '30 preguntas - 30 min',
    icon: Icons.timer,
    accentColor: Colors.indigo,
    variant: DgtTileVariant.hero,
    routeBuilder: (ctx) => const DgtWarmupScreen(),
  ),
  // ... mas tiles
];
```

El render itera el registry y aplica el `variant` (hero/primary/standard)
con su estilo visual correspondiente. `visibleWhen` permite ocultar tiles
condicionales (ej: "Reincidencias" solo si hay >=3 fallos).

Inspirado en el patron `app/seed_dgt_registry.py` del backend (ver 3.2).

### 2.3 Controllers extraidos (testeables)

Issue #139 (dgt-tech). La regla: **logica de estado fuera del widget**.

Ejemplo canonico: `DgtExamController` (`dgt_exam_controller.dart`).

- Extiende `ChangeNotifier`.
- Encapsula timer, scoring, navegacion entre preguntas, flag toggling.
- `DgtExamScreen` queda como capa fina: escucha el controller y pinta.
- Tests unitarios sin `pumpWidget`: se instancia el controller y se asserts
  sobre su estado y sus `notifyListeners()`.
- El snapshot (`DgtExamControllerSnapshot`) es serializable para que la UI
  persista progreso (issue #133) sin acoplarse a campos internos.

Otros controllers/providers siguen el mismo principio (`dgt_today_study_provider`,
`dgt_week_plan_provider`, `dgt_adaptive_goal_provider`, etc.): expuestos
como providers Riverpod, consumidos por widgets que solo leen y reaccionan.

### 2.4 Cache local + schema version handshake

Issue #45 + #156 (dgt-tech). El banco de preguntas pesa ~300KB y se accede
en cada arranque -> se cachea localmente con TTL y handshake de version.

**Storage:** `SharedPreferences` (suficiente <500KB; evita dep Hive solo
para esto). Claves:

```
dgt.cache.questions.v1.json         # JSON list de DgtQuestion.toJson
dgt.cache.questions.v1.ts_ms        # int (timestamp ms al guardar)
dgt.cache.questions.v1.limit        # int (limit con el que se fetcho)
dgt.cache.questions.schema_version  # int (version del shape persistido)
```

**Handshake:** la constante `kDgtCacheSchemaVersion` (en `dgt_questions_cache.dart`)
se bumpea cuando `DgtQuestion.fromJson` agrega campos populados por backend.
Al leer, si la version persistida difiere -> cache descartada como stale,
aunque el TTL de 7 dias no haya vencido. Asi los clientes auto-invalidan
sin esperar.

Otras claves Hive/SharedPreferences relevantes (no exhaustivo):

```
dgt.favorites.v1            # Lista de IDs de preguntas favoritas
dgt.failures.v1             # JSON con errores recientes (para reincidencia)
dgt.exam.snapshot.v1        # Progreso simulacro en curso (resume)
dgt.settings.v1             # Preferencias DGT (estricto, sonido, hora)
dgt.sprint.history.v1       # Historico de sprints rapidos
```

### 2.5 Backup / restore JSON

Issue #175 (dgt-ux). `DgtBackupService` (`features/dgt/services/`):

- **Export:** lee favorites + failures + simulacros + sprints + settings
  -> arma `DgtBackupPayload` -> serializa -> `share_plus` (compartir archivo).
- **Import:** `file_picker` -> parsea -> `mergePayloads()` (logica PURA y
  testeable) -> escribe a stores.

El merge no destruye: union de favorites, append de failures/sprints sin
duplicados por timestamp, last-write-wins en settings.

### 2.6 CI

`.github/workflows/ci.yml` corre en cada push/PR con jobs paralelos:

- **build:** `flutter analyze --fatal-infos` + `flutter test` (incluye
  golden tests de pantallas DGT clave).
- **apk-size-budget** (solo PR): build APK release arm64, compara contra
  `.github/apk-size-budget.txt`, falla si supera `baseline + tolerancia`,
  comenta delta en el PR.

Pre-commit local (`tool/hooks/pre-commit`, instalable con
`./tool/install-hooks.sh`): `dart format --set-exit-if-changed` +
`flutter analyze --fatal-infos` sobre archivos `.dart` staged. Objetivo <3s.

## 3. Backend (FastAPI - repo aparte)

> Repo: `robertruben98/memora` (subdir `backend/` o repo gemelo segun
> revision). Esta seccion documenta los patrones clave que el frontend
> consume, no es referencia exhaustiva del backend.

### 3.1 Endpoints DGT principales

```
GET  /dgt/questions?limit=...         # Banco de preguntas oficiales
GET  /dgt/topics                      # Taxonomia (temas + subtemas)
POST /dgt/exam/submit                 # Resultado simulacro (scoring + stats)
GET  /dgt/exam/predict                # Prediccion de aprobado
GET  /dgt/stats/cohort                # Comparacion vs cohorte
GET  /dgt/normativa/...               # Articulos referenciados por pregunta
GET  /dgt/video-questions             # Preguntas con video
GET  /dgt/tutorials                   # Tutoriales por subtema
```

Esquemas en `openapi.json` (consumidos por generador del frontend).

### 3.2 Registry seed pattern

Issue #ITER-39 (backend). El seed de preguntas se modulariza:

```
app/seed_dgt_registry.py              # Registry central: lista de seeders
app/seed_dgt_senales_2026.py          # Seed tema "senales"
app/seed_dgt_normativa_2026.py        # Seed tema "normativa"
app/seed_dgt_<topic>_2026.py          # Un archivo por tema/edicion
```

Anadir tema = anadir un seeder + registrarlo en `seed_dgt_registry.py`.
El runner (`alembic upgrade` o script de seed) recorre el registry y ejecuta
cada seeder de forma idempotente. Mismo principio que el tile registry del
frontend: **registro declarativo, render/ejecucion generica**.

### 3.3 Observability

- **Structured logs:** JSON line por request con `trace_id`, `span_id`,
  `path`, `status`, `duration_ms`. Sin PII.
- **W3C traceparent:** middleware lee/propaga el header `traceparent` para
  correlacionar con clientes (frontend lo envia desde `data/api/`).
- Logs van a stdout, los recoge `docker compose logs` y se ingestan en
  el agregador del VPS.

### 3.4 CI backend

- **Split jobs:** lint, typecheck (mypy), tests unit, tests integration
  corren en paralelo para que un fallo de lint no demore tests.
- **Dependabot:** PRs semanales de bumps con auto-merge si CI green y
  diff de minor/patch.
- **OpenAPI drift check:** job que regenera `openapi.json` y falla si
  difiere del checkeado -> obliga a commitear el spec sincronizado con
  el codigo (asi el cliente del frontend no se rompe silenciosamente).

## 4. Deployment

### 4.1 Backend -> VPS

```
SSH a robertdev@45.10.154.187
cd ~/memora-backend
git pull
docker compose up -d --build
```

`docker-compose.yml` orquesta backend FastAPI + Postgres + reverse proxy.
Pull-and-restart cubre 99% de los deploys; se evita force-rebuild salvo
cambios de Dockerfile/requirements.

### 4.2 Frontend (APK) -> CDN

`./deploy.sh` (en raiz de este repo):

1. `flutter build apk --release --split-per-abi` (arm64).
2. Copia APK a `/home/robertdev/apk-releases/` con timestamp + alias
   `memora-latest.apk`.
3. Regenera `index.html` con `_generate_index.py`.
4. Notifica al canal Telegram via bot (mensaje + sendDocument si <49MB).

URL publica: `https://apk.a-robertdev.com/<filename>.apk`.

## 5. Flujo del simulacro DGT (ASCII)

```
                    +-------------------+
                    |  Study Hub        |
                    |  (Tile registry)  |
                    +---------+---------+
                              | tap "Simulacro"
                              v
+-------------------+   warmup  +-------------------+
|  DgtWarmupScreen  +---------> |  DgtExamScreen    |
|  (resumen reglas, |   start   |  - 30 preguntas   |
|   countdown 5s)   |           |  - timer 30 min   |
+-------------------+           |  - flag / nav     |
                                |  - autosave       |
                                +---------+---------+
                                          | submit / timeout
                                          v
                                +-------------------+
                                | DgtResultScreen   |
                                | (score, aprobado, |
                                |  fallos por tema) |
                                +---------+---------+
                                          | tap "Revisar"
                                          v
                          +----------------------------+
                          | DgtSimulacroReviewScreen   |
                          | (Q por Q: tu resp / ok /   |
                          |  explicacion / normativa)  |
                          +-------------+--------------+
                                        | done
                                        v
                          +----------------------------+
                          | Stats agregados (cohorte,  |
                          | heatmap temas, prediccion) |
                          +----------------------------+
```

Datos colaterales: cada simulacro alimenta `dgt.failures.v1`,
`dgt.sprint.history.v1` y el snapshot de progreso global (alimenta
`DgtPreparationProvider`).

## 6. Para nuevos agentes / contribuidores

Antes de tocar codigo DGT:

1. Lee `lib/features/study/widgets/dgt_tile_spec.dart` y la lista
   `kDgtTileRegistry` en `dgt_section.dart`. Si tu feature es una entrada
   nueva del hub, **anade un spec, no un widget custom**.
2. Si tu feature tiene logica de estado (timer, scoring, navegacion),
   **extrae un controller** estilo `DgtExamController` y deja la pantalla
   como capa fina.
3. Si vas a cachear datos del backend localmente, **define un schema
   version** y agregalo al handshake; no asumas que la cache se invalida
   sola.
4. Si tu cambio toca el shape de `DgtQuestion` u otros DTOs, **bumpea
   `kDgtCacheSchemaVersion`** para auto-invalidar clientes.
5. Si anades assets pesados, prepara el bump de
   `.github/apk-size-budget.txt` en el mismo PR con justificacion.
6. Para el backend: nuevo tema -> nuevo `seed_dgt_<topic>_2026.py` +
   registrarlo en `app/seed_dgt_registry.py`. No edites seeders existentes
   salvo data fix puntual.

Issues clave de referencia (no exhaustivo):

- #45, #156 - cache local + schema version handshake.
- #133 - persistencia de progreso de simulacro.
- #139 - extraccion de controllers.
- #148 - tile registry pattern.
- #175 - backup/restore JSON.
- #194 - este documento.
