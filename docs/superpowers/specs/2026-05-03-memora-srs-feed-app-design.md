# Memora — App de Aprendizaje con Repetición Espaciada (Feed Estilo Instagram/TikTok)

**Fecha:** 2026-05-03
**Estado:** Draft (pendiente de revisión por el usuario)
**Autor:** Robert + Claude (brainstorming session)

---

## 1. Resumen

Memora es una aplicación móvil Flutter para aprender **cualquier tema** mediante tarjetas de pregunta/respuesta presentadas en un **feed vertical scrollable** estilo Instagram/TikTok. Aplica un algoritmo de **repetición espaciada (SM-2)** para programar automáticamente cuándo vuelve a aparecer cada tarjeta: si aciertas, aparecerá menos frecuentemente; si fallas, aparecerá pronto otra vez.

A diferencia de Anki tradicional (una tarjeta a la vez con interfaz "fría"), Memora apuesta por una UX moderna que invita a estudiar como quien hace scroll en redes: rápido, fluido, adictivo en el buen sentido.

---

## 2. Objetivos y No-Objetivos

### Objetivos (MVP)
- Crear, organizar y editar tarjetas (front/back) en mazos.
- Soporte de **texto + imágenes** en las tarjetas.
- Modo de estudio **feed vertical** con swipe/tap para revelar respuesta.
- Algoritmo **SRS (SM-2)** que programa el repaso óptimo.
- Dos modos de estudio:
  - **Mazo individual** (concentrado en un tema).
  - **Feed global** (mezcla todas las tarjetas due — interleaving).
- Estadísticas básicas (streak, retención, actividad).
- Persistencia local (SQLite). Funciona offline.

### No-Objetivos (MVP)
- Multi-usuario, login, cuentas en la nube.
- Sincronización entre dispositivos.
- Audio en tarjetas.
- Generación con IA (LLM) — fase 2.
- Importación de PDFs / OCR — fase 2.
- Compartir mazos con otras personas — fase 2.
- Versión web/desktop — solo Android+iOS por ahora.

---

## 3. Stack Técnico

| Capa | Tecnología | Razón |
|------|------------|-------|
| Framework | **Flutter 3.x** | Multiplataforma, rendimiento nativo, ya instalado |
| Lenguaje | **Dart 3.x** | Estándar de Flutter |
| State management | **Riverpod 2.x** | Type-safe, testable, moderno |
| Base de datos | **Drift** (SQLite type-safe) | Migrations, queries tipadas, reactividad |
| Routing | **go_router** | Routing declarativo oficial |
| Persistencia ligera | **shared_preferences** | Settings simples |
| Imágenes | **image_picker** + almacenamiento local en `app_documents/` | Sin servidor |
| Animaciones | Flutter built-in + **flutter_animate** | UX fluida |
| Testing | **flutter_test** + **mocktail** | Estándar |

---

## 4. Arquitectura

### Diagrama de capas

```
┌─────────────────────────────────────────┐
│  UI Layer (Widgets + Riverpod consumers)│
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│  State Layer (Riverpod Notifiers)       │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│  Domain Layer                           │
│  - SrsAlgorithm (puro, sin deps)        │
│  - Models (Deck, Card, Schedule)        │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│  Data Layer                             │
│  - Repositories                         │
│  - Drift Database                       │
│  - File Storage (imágenes)              │
└─────────────────────────────────────────┘
```

### Estructura de carpetas (feature-first)

```
lib/
├── core/
│   ├── srs/                  # Algoritmo SM-2 (puro)
│   │   ├── srs_algorithm.dart
│   │   └── srs_result.dart
│   ├── theme/
│   │   ├── app_theme.dart
│   │   └── colors.dart
│   ├── widgets/              # Widgets compartidos
│   └── utils/
├── features/
│   ├── home/                 # Pantalla de mazos
│   │   ├── presentation/
│   │   └── application/      # Riverpod providers
│   ├── decks/
│   │   ├── presentation/
│   │   ├── application/
│   │   └── domain/
│   ├── cards/
│   │   ├── presentation/     # Editor de cards
│   │   └── application/
│   ├── review/               # ⭐ El feed de estudio
│   │   ├── presentation/
│   │   │   ├── review_feed_screen.dart
│   │   │   └── widgets/
│   │   │       ├── card_page.dart
│   │   │       ├── question_view.dart
│   │   │       └── answer_view.dart
│   │   └── application/
│   ├── stats/
│   └── settings/
├── data/
│   ├── database/
│   │   ├── database.dart      # Drift DB
│   │   ├── tables/            # Definiciones de tablas
│   │   └── daos/              # Data Access Objects
│   ├── repositories/
│   │   ├── deck_repository.dart
│   │   ├── card_repository.dart
│   │   └── review_repository.dart
│   └── storage/
│       └── image_storage.dart
├── routing/
│   └── app_router.dart
└── main.dart
```

---

## 5. Modelo de Datos

### Tabla `decks`
| Campo | Tipo | Notas |
|-------|------|-------|
| id | TEXT (UUID) PK | |
| name | TEXT NOT NULL | |
| description | TEXT | nullable |
| color_hex | TEXT | Color visual del mazo |
| icon_name | TEXT | Icono Material |
| created_at | INTEGER (timestamp) | |
| updated_at | INTEGER (timestamp) | |

### Tabla `cards`
| Campo | Tipo | Notas |
|-------|------|-------|
| id | TEXT (UUID) PK | |
| deck_id | TEXT FK → decks.id ON DELETE CASCADE | |
| front_text | TEXT NOT NULL | |
| back_text | TEXT NOT NULL | |
| front_image_path | TEXT | nullable, ruta relativa |
| back_image_path | TEXT | nullable, ruta relativa |
| created_at | INTEGER | |
| updated_at | INTEGER | |

### Tabla `card_schedules` (estado SRS)
| Campo | Tipo | Notas |
|-------|------|-------|
| card_id | TEXT PK FK → cards.id ON DELETE CASCADE | 1:1 con cards |
| ease_factor | REAL DEFAULT 2.5 | Min 1.3 |
| interval_days | INTEGER DEFAULT 0 | Días hasta próximo review |
| repetitions | INTEGER DEFAULT 0 | Cuántos repasos correctos consecutivos |
| state | TEXT | 'new' \| 'learning' \| 'reviewing' |
| next_review_date | INTEGER (timestamp) | |
| last_review_date | INTEGER | nullable |

### Tabla `review_logs` (historia para stats)
| Campo | Tipo | Notas |
|-------|------|-------|
| id | INTEGER PK AUTOINCREMENT | |
| card_id | TEXT FK | |
| reviewed_at | INTEGER (timestamp) | |
| result | TEXT | 'correct' \| 'incorrect' |
| previous_interval_days | INTEGER | |
| new_interval_days | INTEGER | |

### Tabla `settings` (key-value para ajustes)
| Campo | Tipo |
|-------|------|
| key | TEXT PK |
| value | TEXT |

Settings esperados: `new_cards_per_day`, `max_reviews_per_day`, `theme_mode`, `daily_streak_count`, `last_review_day`.

---

## 6. Algoritmo SRS (SM-2)

Como la UX usa **botones binarios** (Acerté / No acerté), mapeamos así:

| Acción usuario | quality (0–5) |
|----------------|---------------|
| ❌ No acerté | 1 |
| ✅ Acerté | 4 |

**Pseudocódigo:**

```dart
SrsResult compute({
  required double easeFactor,   // current
  required int repetitions,
  required int intervalDays,
  required int quality,         // 1 o 4
}) {
  late int newInterval;
  late int newReps;

  if (quality < 3) {
    // Fallo: reset
    newReps = 0;
    newInterval = 1;
  } else {
    // Acierto
    if (repetitions == 0) {
      newInterval = 1;
    } else if (repetitions == 1) {
      newInterval = 6;
    } else {
      newInterval = (intervalDays * easeFactor).round();
    }
    newReps = repetitions + 1;
  }

  // Actualizar ease factor
  final delta = 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02);
  final newEase = max(1.3, easeFactor + delta);

  // 'state' transitions
  String newState;
  if (quality < 3) {
    newState = 'learning';
  } else if (newReps < 2) {
    newState = 'learning';
  } else {
    newState = 'reviewing';
  }

  return SrsResult(
    easeFactor: newEase,
    repetitions: newReps,
    intervalDays: newInterval,
    nextReviewDate: today + newInterval days,
    state: newState,
  );
}
```

**Nota:** este algoritmo es **puro** (sin dependencias) y se testea con unit tests exhaustivos. Fácil de migrar a FSRS-4.5 en el futuro.

---

## 7. Pantallas y UX

### 7.1 Home — Lista de Mazos

```
┌─────────────────────────────┐
│  Memora              ⚙️ 📊  │  ← AppBar
├─────────────────────────────┤
│                             │
│  ┌─────────────────────┐    │
│  │ 🌍 Estudiar todo    │    │  ← Botón destacado
│  │ 47 tarjetas due     │    │
│  └─────────────────────┘    │
│                             │
│  Mis Mazos                  │
│  ┌─────────────────────┐    │
│  │ 📘 Inglés - Verbos  │    │
│  │ 23 due · 156 total  │    │
│  └─────────────────────┘    │
│  ┌─────────────────────┐    │
│  │ 🧪 Química Orgánica │    │
│  │ 12 due · 80 total   │    │
│  └─────────────────────┘    │
│                             │
│                       (+)   │  ← FAB nuevo mazo
└─────────────────────────────┘
```

### 7.2 Feed de Estudio (⭐ pantalla principal)

`PageView` vertical (scroll vertical, una card = pantalla completa).

**Estado A — Pregunta visible:**
```
┌─────────────────────────────┐
│  ← 12 / 45            ⏸    │  ← progreso + pausa
├─────────────────────────────┤
│                             │
│                             │
│       ¿Qué significa        │
│         "to thrive"?        │
│                             │
│        [ tap para ver ]     │
│         ↓ ↓ ↓               │
│                             │
└─────────────────────────────┘
```

**Estado B — Respuesta revelada:**
```
┌─────────────────────────────┐
│  ← 12 / 45            ⏸    │
├─────────────────────────────┤
│   ¿Qué significa            │
│    "to thrive"?             │  ← pregunta arriba (compacta)
│                             │
│ ─────────────────────────── │
│                             │
│   Prosperar, florecer.      │  ← respuesta
│   Crecer con vigor.         │
│                             │
│ ┌─────────┐  ┌──────────┐  │
│ │ ❌ No   │  │ ✅ Sí    │  │  ← botones grandes
│ │ acerté  │  │ acerté   │  │
│ └─────────┘  └──────────┘  │
└─────────────────────────────┘
```

**Interacciones:**
- **Tap en card** o **swipe →** → revela respuesta (animación crossfade + slide).
- **Botón "✅ Sí acerté"** → guarda result `correct`, actualiza schedule SM-2, anima salida hacia arriba, muestra siguiente card.
- **Botón "❌ No acerté"** → guarda result `incorrect`, anima salida hacia arriba, siguiente card.
- **Haptic feedback** en cada tap de botón.
- **Swipe vertical manual**: permitido para "saltar" cards sin responder (no afecta SRS).

**Estado vacío** (no hay cards due):
```
┌─────────────────────────────┐
│                             │
│         🎉                  │
│   ¡Todo al día!             │
│                             │
│  No tienes tarjetas         │
│  pendientes ahora mismo.    │
│                             │
│  [ Aprender 5 nuevas ]      │
│  [ Volver al inicio ]       │
└─────────────────────────────┘
```

### 7.3 Editor de Tarjeta

Pantalla completa, accesible desde:
- FAB "+" en pantalla de mazo
- Editar (icono ✏️) en una card existente

```
┌─────────────────────────────┐
│  ← Nueva tarjeta      💾    │
├─────────────────────────────┤
│  Mazo: [ Inglés - Verbos ▾]│
│                             │
│  Pregunta (front)           │
│  ┌─────────────────────┐    │
│  │                     │    │
│  └─────────────────────┘    │
│  📷 Añadir imagen           │
│                             │
│  Respuesta (back)           │
│  ┌─────────────────────┐    │
│  │                     │    │
│  └─────────────────────┘    │
│  📷 Añadir imagen           │
│                             │
│  [ Guardar y crear otra ]  │
│  [ Guardar ]               │
└─────────────────────────────┘
```

### 7.4 Editor de Mazo

- Crear/editar nombre, descripción, color, icono.
- Lista de cards del mazo (con búsqueda).
- Estadísticas del mazo (cards new/learning/reviewing).
- Botón "Eliminar mazo" (con confirmación).

### 7.5 Estadísticas

- **Streak** actual (días consecutivos estudiando).
- **Total revisadas hoy / esta semana**.
- **Retención** (% de aciertos de los últimos 30 días).
- **Heatmap de actividad** (estilo GitHub) últimos 6 meses.
- **Distribución de cards por estado**: new/learning/reviewing.

### 7.6 Ajustes

- Cards nuevas por día (slider, default 10).
- Reviews máximos por día (slider, default 50).
- Tema (claro / oscuro / sistema). Default: oscuro.
- Backup: exportar todo a JSON (Share dialog del SO).
- Restore: importar JSON.
- Resetear progreso SRS (con confirmación doble).
- Acerca de / versión.

---

## 8. Flujo de Estudio (estado del feed)

```
1. Usuario abre app → Home
2. Tap "Estudiar todo" o un mazo concreto
3. App calcula la cola:
   a. Cards con next_review_date <= hoy (due reviews)
   b. + hasta N cards nuevas (donde N = setting "new_cards_per_day")
   c. Mezcladas (interleaving): orden = shuffle(due ∪ new)
   d. Limitadas por setting "max_reviews_per_day"
4. Render PageView con la cola
5. Por cada card:
   - Mostrar pregunta
   - Esperar tap/swipe → mostrar respuesta
   - Esperar respuesta usuario (Acerté / No acerté)
   - Llamar a SrsAlgorithm.compute(...)
   - Persistir nuevo schedule + log
   - Avanzar PageController.nextPage()
6. Al terminar la cola → pantalla "Todo al día"
7. Actualizar streak si es la primera sesión del día
```

---

## 9. Diseño Visual

- **Material 3** (color schemes generados a partir de seed color).
- **Tema oscuro por defecto** (mejor para feed, bajo consumo OLED).
- **Tipografía:** sistema (San Francisco / Roboto), tamaños generosos.
- **Bordes redondeados** (radius 16-24) en cards.
- **Animaciones:** todas con `Curves.easeOutCubic`, duración ~300ms.
- **Haptic feedback:** ligero en tap, medio en botones de respuesta.
- **Cada mazo tiene un color**: la card en el feed tiene un acento sutil (borde o fondo gradient muy leve) con ese color, para dar contexto sin distraer.

---

## 10. Plan de Implementación (alto nivel)

> El detalle se desarrollará en el plan de implementación con la skill `writing-plans` después de aprobar este spec.

### Fase 1 — MVP funcional (4-6 semanas equivalente)
1. Setup proyecto Flutter + Riverpod + Drift + go_router.
2. Definición de tablas Drift + migraciones iniciales.
3. Core: algoritmo SM-2 + tests unitarios.
4. Repositorios (Deck, Card, Review).
5. CRUD de mazos (UI + state).
6. CRUD de cards sin imágenes (UI + state).
7. Feed de estudio funcional con datos mockeados.
8. Conectar feed con repositorios reales.
9. Persistencia de schedules + review logs.
10. Pantalla de stats básicas.
11. Settings.
12. Soporte de imágenes en cards.

### Fase 2 — Pulido y exportación
13. Backup/restore JSON.
14. Heatmap de actividad.
15. Animaciones y haptics finos.
16. Empty states y onboarding.
17. Iconos y branding.
18. Build de release Android (APK firmado).

### Fase 3 — Post-MVP (futuro)
19. Generación con IA (Claude API / OpenAI).
20. Importación de texto/PDF.
21. Audio en cards.
22. Sync entre dispositivos (Supabase / self-hosted).
23. Algoritmo FSRS-4.5.
24. iOS build + App Store.

---

## 11. Testing

- **Unit tests** para `SrsAlgorithm` (cobertura ≥ 95%, casos: primer acierto, primer fallo, fallo después de varios aciertos, ease floor, etc.).
- **Repository tests** con DB en memoria.
- **Widget tests** para `CardPage`, `ReviewFeedScreen`, editores.
- **Integration test** del flujo completo: crear mazo → crear cards → estudiar → verificar persistencia.

---

## 12. Riesgos y Decisiones Pendientes

| Riesgo / Decisión | Mitigación |
|-------------------|------------|
| Nombre "Memora" puede estar registrado | Verificar en Play Store + dominios. Cambiar si conflicto. |
| Soporte tablet | MVP solo móvil; layouts responsive en fase 2. |
| Markdown / rich text en cards | MVP solo texto plano; añadir Markdown render en fase 2. |
| Imágenes pueden inflar storage | Comprimir al añadir (max 1024px lado mayor, JPEG q85). |
| Algoritmo SM-2 vs FSRS | SM-2 para MVP por simplicidad y battle-tested. Migración a FSRS = trabajo localizado en `core/srs/`. |
| Performance del feed con muchas cards | `PageView.builder` lazy + paginación de la cola. |

---

## 13. Métricas de Éxito (uso personal)

- Crear y mantener mazos sin fricción (< 30s para añadir una card).
- Estudiar al menos 5 días/semana usando el feed.
- Retención > 85% en cards `reviewing` después de 1 mes.
- App estable (sin crashes) en uso diario.
