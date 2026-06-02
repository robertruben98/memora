# Ficha de Google Play — RutaB (es-ES)

> Idioma principal de la ficha: **Español (España) · es-ES**
> App ID: `com.robertdev.memora` · Versión: 2.6.0 (versionCode 31)

---

## Título de la app (máx. 30 caracteres)

```
RutaB: Test DGT 2026
```

(21 caracteres — dentro del límite de 30.)

---

## Descripción corta (máx. 80 caracteres)

```
Aprueba el test teórico DGT 2026 con repaso inteligente y simulacros reales.
```

(76 caracteres — dentro del límite de 80.)

---

## Descripción completa (máx. 4000 caracteres)

```
RutaB es tu app para aprobar el examen teórico de la DGT 2026 a la primera. Combina simulacros oficiales con repetición espaciada para que estudies menos horas y retengas más, repasando justo lo que más te cuesta.

Olvídate de leer el manual entero una y otra vez: RutaB aprende de tus fallos y te programa el repaso en el momento exacto en el que estás a punto de olvidar cada concepto. Así fijas las señales, las normas y las preguntas trampa sin perder tiempo en lo que ya dominas.

== POR QUÉ MEMORA ==

• Simulacros DGT 2026: practica con tests al estilo del examen real (30 preguntas, tiempo y fallos permitidos) y comprueba si estás listo para presentarte.
• Repetición espaciada (SRS): el sistema decide qué repasar cada día para que la información pase a tu memoria a largo plazo con el mínimo esfuerzo.
• Modo audio manos libres (TTS): escucha las preguntas y respuestas en voz alta mientras conduces, paseas o haces otra cosa. Estudia sin mirar la pantalla.
• Preguntas de percepción del riesgo (vídeo): nuevas preguntas con vídeo del examen 2026 para entrenar la anticipación al volante.
• Verdadero o Falso rápido: sesiones cortas de V/F para repasar conceptos clave en segundos cuando solo tienes un minuto libre.
• Recordatorio diario: programa una notificación para no romper tu racha de estudio y llegar al examen con la preparación completa.
• Estadísticas y evolución semanal: gráficas claras de tu progreso, aciertos por tema y cómo mejoras semana a semana.
• Insignias y logros: desbloquea recompensas por tu constancia y mantén la motivación hasta el día del examen.
• Comparte tu progreso con tu autoescuela (QR): genera un código QR con tu evolución para que tu profesor siga tu preparación.
• Copia de seguridad y restauración: guarda y recupera tu progreso cuando cambies de móvil. Tus datos viajan contigo.
• Modo oscuro: estudia de noche sin cansar la vista, con un diseño cuidado y cómodo.
• Gratis: empieza a prepararte ahora mismo, sin coste.

== CÓMO FUNCIONA ==

1. Practica por temas o lánzate a un simulacro completo.
2. RutaB detecta tus puntos débiles y crea tu plan de repaso.
3. Repasas cada día lo justo y necesario, también en modo audio.
4. Sigues tu evolución y, cuando estás listo, te presentas con confianza.

== IDEAL PARA ==

• Alumnos de autoescuela que preparan el carnet de coche (permiso B).
• Quien quiere recuperar puntos o repasar la normativa de circulación.
• Estudiar en cualquier momento: en el bus, en pausas o desde casa.

Prepárate para la DGT con un método que de verdad funciona. Descarga RutaB y aprueba el teórico 2026 a la primera.
```

(Aproximadamente 2.350 caracteres — muy por debajo del límite de 4000.)

---

## Categoría y clasificación

- **Categoría de la aplicación:** Educación
- **Tipo:** Aplicación (no juego)
- **Modelo de precios:** Gratis (sin compras integradas ni anuncios)

### Etiquetas / keywords sugeridas (ASO)

Usar de forma natural en título, descripción corta y completa (Google Play no tiene campo separado de keywords; el posicionamiento se basa en el texto de la ficha):

- test dgt
- examen dgt 2026
- teórico dgt
- autoescuela
- permiso b
- carnet de conducir
- test conducir
- señales de tráfico
- simulacro dgt
- repaso espaciado
- percepción del riesgo
- aprobar dgt

---

## Clasificación de contenido (Content rating)

Responder el cuestionario de la IARC en Play Console como **aplicación de referencia/educativa** sin contenido sensible:

- ¿Contiene violencia? **No**
- ¿Contenido sexual? **No**
- ¿Lenguaje soez? **No**
- ¿Sustancias controladas / drogas / alcohol? **No**
- ¿Juego de azar / apuestas? **No**
- ¿Compras dentro de la app / contenido generado por usuarios compartido públicamente? **No** (el QR es para compartir progreso de forma puntual, no es contenido público).
- ¿Recopila o comparte ubicación? **No**.

Resultado esperado: **PEGI 3 / "Apta para todos los públicos"**.

---

## Datos de contacto y enlaces

- **Email de contacto del desarrollador:** robertruben98@gmail.com
- **Política de privacidad:** https://memora-api.a-robertdev.com/privacidad
- **Borrado de cuenta (URL pública):** https://memora-api.a-robertdev.com/eliminar-cuenta
- **Sitio web:** https://memora.a-robertdev.com

---

## Assets gráficos

Especificaciones oficiales de Google Play y cómo producir cada asset desde este repositorio.

### 1. Icono de alta resolución — 512 × 512 PNG (32 bits, con alfa)

Fuente: `assets/icon/icon.png` (ya es **1024 × 1024 PNG RGBA**). Solo hay que reescalarlo a 512 × 512.

```bash
# Opción A: ImageMagick (disponible en el entorno)
convert assets/icon/icon.png -resize 512x512 docs/store/play-icon-512.png

# Opción B: regenerar mipmaps del launcher (no produce el icono de tienda,
# pero asegura que el icono dentro de la app coincide con el de la ficha)
export PATH="/home/arobertdev/.flutter-sdk/bin:$PATH"
flutter pub run flutter_launcher_icons
```

> El fondo de marca del icono adaptativo es `#0E0E12` (ver `pubspec.yaml` → `flutter_launcher_icons`).

### 2. Gráfico de funciones (Feature graphic) — 1024 × 500 PNG o JPG (sin alfa)

Se genera capturando `docs/store/feature-graphic.html` con un navegador headless:

```bash
# Chromium-family disponible en el entorno: google-chrome-stable
google-chrome-stable --headless --disable-gpu --hide-scrollbars \
  --screenshot=docs/store/feature-graphic.png \
  --window-size=1024,500 \
  --default-background-color=00000000 \
  file:///home/arobertdev/code/apps/memora/docs/store/feature-graphic.html

# (Si se instala chromium, el comando equivalente es:)
# chromium --headless --screenshot --window-size=1024,500 docs/store/feature-graphic.html

# Play exige PNG/JPG sin canal alfa. Aplanar contra el fondo de marca:
convert docs/store/feature-graphic.png -background "#0E0E12" -flatten \
  docs/store/feature-graphic-final.png
```

### 3. Capturas de pantalla de teléfono — mínimo 2, hasta 8

Requisitos Play: PNG o JPG de 24 bits (sin alfa), lado mínimo 320 px, lado máximo 3840 px, relación entre 16:9 y 9:16. Capturar de la app corriendo en emulador o dispositivo:

```bash
export PATH="/home/arobertdev/.flutter-sdk/bin:$PATH"
cd /home/arobertdev/code/apps/memora

# Lanzar la app (emulador o dispositivo físico)
flutter run --release

# Capturar pantalla a pantalla con Flutter (mientras la app corre)
flutter screenshot --out=docs/store/shot-01.png
flutter screenshot --out=docs/store/shot-02.png
# ... repetir por cada pantalla

# Alternativa con adb (disponible en el entorno) sobre dispositivo conectado:
adb exec-out screencap -p > docs/store/shot-01.png
```

Pantallas recomendadas (mínimo 2; ideal 4-5):

1. Simulacro DGT en curso (pregunta con opciones).
2. Resultado del simulacro / pantalla de "Aprobado".
3. Estadísticas y evolución semanal (gráfica).
4. Insignias y logros desbloqueados.
5. Modo audio (TTS) o repaso por temas.

---

## Resumen para Play Console (copiar/pegar)

| Campo | Valor |
|---|---|
| Nombre de la app | RutaB: Test DGT 2026 |
| Idioma por defecto | Español (España) — es-ES |
| Descripción corta | Aprueba el test teórico DGT 2026 con repaso inteligente y simulacros reales. |
| Categoría | Educación |
| Tipo | App (gratis) |
| Email de contacto | robertruben98@gmail.com |
| Política de privacidad | https://memora-api.a-robertdev.com/privacidad |
| Clasificación | PEGI 3 / Apta para todos |
| Icono | 512×512 (desde `assets/icon/icon.png`) |
| Feature graphic | 1024×500 (desde `docs/store/feature-graphic.html`) |
| Capturas | ≥2 de teléfono |
