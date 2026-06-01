# Memora — Runbook de publicación en Google Play

Guía end-to-end para firmar, compilar y publicar **Memora** (`com.robertdev.memora`,
título de tienda *Memora: Test DGT 2026*) en Google Play. Síguela en orden. Los
pasos marcados como *(una sola vez)* solo se hacen en la primera publicación.

> **Entorno de build local**
> - Flutter SDK: `/home/arobertdev/.flutter-sdk/bin` (no está en el `PATH`; hay que
>   exportarlo antes de cualquier comando `flutter`).
> - Flutter 3.38.9 / Dart 3.10.8.
> - El bloque de firma de `android/app/build.gradle.kts` carga `android/key.properties`
>   si existe; si no, firma con la clave de depuración (sirve para validar el enlace
>   de R8, **no** para publicar).
> - `android/key.properties`, `**/*.jks` y `**/*.keystore` están en `.gitignore`. **Nunca**
>   se suben al repositorio.

---

## 1. Generar el upload keystore *(una sola vez)*

La *upload key* es la clave con la que **tú** firmas los AAB que subes a Play. Con
**Play App Signing** (paso 6) Google re-firma la app con su propia clave; tu upload
key solo sirve para autenticar las subidas, así que si la pierdes se puede resetear
contactando con soporte. Aun así, **respáldala**.

```bash
mkdir -p ~/keys
keytool -genkey -v -keystore ~/keys/memora-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

- Responde a las preguntas (nombre, organización, etc.; pueden ser genéricas).
- Elige una contraseña fuerte para el **store** y otra para la **key** (puedes usar la
  misma para ambas; el `build.gradle.kts` admite las dos por separado).
- **Guarda ambas contraseñas en un gestor seguro** (no hay forma de recuperarlas).
- **Respalda el archivo `~/keys/memora-upload-keystore.jks`** en un sitio seguro
  (cifrado / fuera del equipo). Sin él no podrás firmar nuevas versiones (aunque con
  Play App Signing es recuperable vía soporte).

Verifica que el alias quedó bien:

```bash
keytool -list -v -keystore ~/keys/memora-upload-keystore.jks -alias upload
```

---

## 2. Crear `android/key.properties` *(una sola vez por equipo)*

Copia la plantilla y rellénala. **Nunca commitees este archivo** (ya está en `.gitignore`).

```bash
cd /home/arobertdev/code/apps/memora
cp android/key.properties.example android/key.properties
```

Edita `android/key.properties` con tus valores reales:

```properties
storePassword=TU_PASSWORD_DEL_STORE
keyPassword=TU_PASSWORD_DE_LA_KEY
keyAlias=upload
storeFile=/home/arobertdev/keys/memora-upload-keystore.jks
```

- `keyAlias` debe coincidir con el `-alias upload` usado en `keytool`.
- `storeFile` es la **ruta absoluta** al `.jks`.
- Comprueba que el archivo NO va a entrar en git:

  ```bash
  git check-ignore android/key.properties   # debe imprimir la ruta => está ignorado
  ```

---

## 3. Construir el AAB firmado para release

El App Bundle (`.aab`) es el formato que pide Play (de él Google genera APKs
optimizados por dispositivo). R8 (minify + shrink) ya está activado en el bloque
`release` de `android/app/build.gradle.kts`, con las reglas `proguard-rules.pro`.

```bash
export PATH="/home/arobertdev/.flutter-sdk/bin:$PATH"
cd /home/arobertdev/code/apps/memora
flutter pub get
flutter build appbundle --release
# salida: build/app/outputs/bundle/release/app-release.aab
```

Si R8 rompe el build con `Missing class` / `ClassNotFoundException`, añade el
`-keep` o `-dontwarn` correspondiente en `android/app/proguard-rules.pro` y vuelve a
compilar.

**Recomendado antes de subir:** prueba un APK release minificado en un dispositivo
real para descartar crashes por reglas de R8 demasiado agresivas (un AAB se reparte
en módulos y un fallo de ofuscación no siempre aparece en debug):

```bash
flutter build apk --release
# instala build/app/outputs/flutter-apk/app-release.apk en un móvil y prueba:
# - notificaciones / recordatorios DGT (flutter_local_notifications)
# - audio TTS (flutter_tts)
# - vídeos de percepción de riesgo (video_player / media3)
# - base de datos local (drift / sqlite)
```

---

## 4. Verificar librerías nativas y compatibilidad 16 KB (informativo)

Los dispositivos Android recientes (a partir de Android 15 en algunos OEM) usan
páginas de memoria de **16 KB**. Las `.so` deben estar alineadas a 16 KB. Flutter
3.38.9 y el toolchain NDK actual ya generan binarios alineados; este paso es solo
para inspeccionar qué librerías nativas viaja la app.

```bash
# listar las .so empaquetadas en el AAB
unzip -l build/app/outputs/bundle/release/app-release.aab | grep -E "\.so"
```

Comprobación opcional de alineación 16 KB de una `.so` concreta (requiere extraerla):

```bash
# extrae el AAB a un dir temporal y revisa el alineamiento del segmento LOAD
unzip -o build/app/outputs/bundle/release/app-release.aab -d /tmp/memora_aab >/dev/null
find /tmp/memora_aab -name "*.so" | while read so; do
  echo "== $so"
  # ALIGN debe ser >= 0x4000 (16384) para LOAD; con NDK moderno suele cumplirse
  readelf -lW "$so" 2>/dev/null | grep -E "LOAD" | head -1
done
```

> Si alguna `.so` no estuviera alineada a 16 KB, se resolvería actualizando el AGP /
> NDK del proyecto. Con el stack actual no se espera acción aquí.

---

## 5. Crear cuenta de desarrollador y la app en Play Console *(una sola vez)*

1. **Cuenta de desarrollador**: alta en <https://play.google.com/console> con la
   cuenta Google `robertruben98@gmail.com`. Pago único de **25 USD**. Completa la
   verificación de identidad (puede tardar). Para cuentas personales, Google exige
   además un periodo de test cerrado con un mínimo de testers antes de poder pasar a
   producción — tenlo en cuenta en la planificación (ver paso 7).
2. **Crear app**: *Todas las apps → Crear app*.
   - Nombre de la app: `Memora: Test DGT 2026`.
   - Idioma predeterminado: **Español (España) – es-ES**.
   - Tipo: **App** (no juego).
   - Gratis o de pago: **Gratis** (no se puede cambiar a gratis después de marcarla de
     pago; al revés sí).
   - Acepta las declaraciones (políticas de desarrollador y leyes de exportación de
     EE. UU.).

---

## 6. Activar Play App Signing *(una sola vez)*

En *Configuración → Integridad de la app → Firma de apps de Google Play*:

- Deja activado **Play App Signing** (recomendado y, para apps nuevas, obligatorio).
- Modelo de claves: **subes tu upload key**; Google guarda y usa la *clave de firma de
  la app* para firmar los APK que reciben los usuarios.
- La primera vez que subas un AAB firmado con tu upload key (paso 7), Play registra
  esa clave automáticamente. No necesitas exportar la clave de firma.
- Anota en sitio seguro la huella **SHA-256** de la *upload key* y de la *clave de
  firma* que muestra Play (las necesitarás si algún día integras servicios Google que
  pidan certificados, p. ej. login social o Maps).

---

## 7. Rellenar la ficha y las declaraciones de la app

Fuentes de contenido en el repo:
`docs/legal/`, `docs/store/`.

| Sección de Play Console | De dónde sale | Notas |
| --- | --- | --- |
| **Ficha de Play Store** (título, desc. corta, desc. completa) | `docs/store/listing-es.md` | Título ≤30, desc. corta ≤80, completa ≤4000. |
| **Categoría** | `docs/store/listing-es.md` | **Educación**. |
| **Etiquetas / keywords** | `docs/store/listing-es.md` | DGT, autoescuela, test, carnet. |
| **Email de contacto** | `robertruben98@gmail.com` | Visible en la ficha. |
| **Política de privacidad (URL)** | `docs/legal/privacy-es.html` publicada | URL: `https://memora.a-robertdev.com/privacidad`. |
| **Seguridad de los datos (Data Safety)** | `docs/legal/data-safety.md` | Responde pregunta→respuesta tal cual. Resumen abajo. |
| **Borrado de cuenta (URL)** | `docs/legal/account-deletion.html` publicada | URL: `https://memora.a-robertdev.com/eliminar-cuenta`. |
| **Clasificación de contenido (Content rating)** | `docs/store/listing-es.md` | Cuestionario IARC: app educativa sin contenido sensible → ≈ PEGI 3 / Todos. |
| **Público objetivo y contenido** | — | Público objetivo: adultos (preparación carnet); sin diseño dirigido a menores. |
| **Anuncios** | — | **No** contiene anuncios. |
| **Assets gráficos** (icono 512×512, feature 1024×500, ≥2 screenshots) | `docs/store/listing-es.md` (sección Assets) + `docs/store/feature-graphic.html` | Ver specs en `listing-es.md`. |
| **Permisos sensibles** | — | **Nada que declarar**: ya NO se usan `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` (recordatorios pasados a alarmas inexactas). Permisos restantes (`INTERNET`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`) no requieren formulario de uso destacado. |
| **Target SDK** | `android/app/build.gradle.kts` (`targetSdkVersion` de Flutter, SDK 36) | Cumple el mínimo exigido por Play. |

**Resumen Data Safety (de `docs/legal/data-safety.md`):**
- Recopila datos: **Sí**. Comparte datos: **No**. Vende datos: **No**.
- *Email* → gestión de cuenta, obligatorio, cifrado en tránsito (HTTPS), eliminable.
- *Actividad de la app* (progreso/repasos/stats) → funcionalidad/personalización,
  cifrado en tránsito, eliminable.
- *Contenido del usuario* (mazos y tarjetas) → funcionalidad, cifrado en tránsito,
  eliminable.
- SDK de publicidad o analítica de terceros: **No**.
- El usuario puede solicitar el borrado de su cuenta: **Sí**, in-app
  (Ajustes → Eliminar cuenta) y vía URL pública de borrado.

> **Pre-requisito clave:** la URL de privacidad y la URL de borrado deben estar
> **publicadas y accesibles** antes de enviar la app a revisión. Publica los HTML de
> `docs/legal/privacy-es.html` y `docs/legal/account-deletion.html` en
> `memora.a-robertdev.com`.

---

## 8. Testing interno

1. *Pruebas → Pruebas internas → Crear versión*.
2. Sube `build/app/outputs/bundle/release/app-release.aab`.
3. Añade testers (lista de correos o grupo de Google). Comparte el enlace de
   participación.
4. Verifica en dispositivos reales:
   - Login/registro y **borrado de cuenta** (Ajustes → Eliminar cuenta) contra el
     **backend desplegado** (debe devolver 204 y cerrar sesión).
   - Recordatorios DGT (alarmas inexactas) y notificaciones.
   - Audio TTS, vídeos de percepción de riesgo, base de datos local, modo oscuro.
5. Si Play exige un periodo de test cerrado (cuentas personales), promueve a *Pruebas
   cerradas* con el número de testers requerido durante el plazo indicado antes de
   producción.

---

## 9. Producción

1. *Producción → Crear versión* → sube el AAB (o promociona el de testing).
2. Completa todas las secciones obligatorias (Play marca lo que falta).
3. **Rollout gradual** recomendado (p. ej. 10% → 50% → 100%) para detectar crashes
   en producción antes del despliegue total.
4. Envía a revisión. La primera revisión puede tardar varios días.

---

## CHECKLIST FINAL

Marca cada casilla antes de pasar a producción:

- [ ] Upload keystore generado (`~/keys/memora-upload-keystore.jks`) y **respaldado** en sitio seguro.
- [ ] Contraseñas del store y de la key guardadas en gestor seguro.
- [ ] `android/key.properties` creado en local y **confirmado ignorado** por git (`git check-ignore` lo lista).
- [ ] `flutter build appbundle --release` produce `build/app/outputs/bundle/release/app-release.aab` sin errores.
- [ ] R8/minify no provoca crashes: APK release probado en dispositivo real (notificaciones, TTS, vídeo, base de datos OK).
- [ ] `.so` empaquetadas revisadas (compatibilidad 16 KB, informativo).
- [ ] Cuenta de desarrollador creada y verificada (25 USD pagados).
- [ ] App creada en Play Console (`Memora: Test DGT 2026`, es-ES, gratis).
- [ ] **Play App Signing** activado (upload key registrada).
- [ ] Borrado de cuenta funciona end-to-end contra el **backend desplegado** (Ajustes → Eliminar cuenta → 204 + logout).
- [ ] Política de privacidad publicada y accesible en `https://memora.a-robertdev.com/privacidad`.
- [ ] Página de borrado de cuenta publicada y accesible en `https://memora.a-robertdev.com/eliminar-cuenta`.
- [ ] Formulario **Data Safety** enviado (de `docs/legal/data-safety.md`).
- [ ] **Clasificación de contenido** completada (≈ PEGI 3 / Todos).
- [ ] **Categoría** = Educación; email de contacto = `robertruben98@gmail.com`.
- [ ] Assets subidos: icono 512×512, feature graphic 1024×500, ≥2 screenshots de teléfono.
- [ ] **Target SDK 36** (cumple el mínimo de Play).
- [ ] Permisos limpios: sin `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`, sin anuncios, sin uso destacado que declarar.
- [ ] AAB subido a **testing interno** y validado por testers.
- [ ] (Cuenta personal) Periodo de **prueba cerrada** completado si Play lo exige.
- [ ] Versión de **producción** creada con rollout gradual y enviada a revisión.

---

## Apéndice — Build de AAB en GitHub Actions (OPCIONAL, no activado)

Alternativa al build local del paso 3. **Documentado, NO activar sin configurar los
secrets**. El workflow se dispararía al crear un tag `v*` (p. ej. `v1.0.0`), decodifica
el keystore desde un secret base64, genera `android/key.properties` en el runner y
compila el AAB firmado, subiéndolo como *artifact*.

**Preparar el secret del keystore (en local, una vez):**

```bash
# base64 sin saltos de línea del keystore para guardarlo como secret
base64 -w0 ~/keys/memora-upload-keystore.jks > /tmp/keystore.b64
# copia el contenido de /tmp/keystore.b64 al secret KEYSTORE_BASE64
gh secret set KEYSTORE_BASE64 < /tmp/keystore.b64
gh secret set STORE_PASSWORD  # te pedirá el valor
gh secret set KEY_PASSWORD
gh secret set KEY_ALIAS        # valor: upload
rm /tmp/keystore.b64
```

**Secrets requeridos** (Settings → Secrets and variables → Actions):
`KEYSTORE_BASE64`, `STORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`.

Crear `.github/workflows/release.yml` con este contenido para activarlo:

```yaml
name: Release AAB

# OPCIONAL: este workflow NO está activo en el repo. Para usarlo, crea
# .github/workflows/release.yml con este contenido y configura los secrets:
# KEYSTORE_BASE64, STORE_PASSWORD, KEY_PASSWORD, KEY_ALIAS.

on:
  push:
    tags:
      - 'v*'

jobs:
  build-aab:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Java
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: '3.38.9'
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Decode upload keystore from secret
        env:
          KEYSTORE_BASE64: ${{ secrets.KEYSTORE_BASE64 }}
        run: |
          echo "$KEYSTORE_BASE64" | base64 -d > "${{ runner.temp }}/upload-keystore.jks"

      - name: Write android/key.properties
        env:
          STORE_PASSWORD: ${{ secrets.STORE_PASSWORD }}
          KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
          KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
        run: |
          cat > android/key.properties <<EOF
          storePassword=${STORE_PASSWORD}
          keyPassword=${KEY_PASSWORD}
          keyAlias=${KEY_ALIAS}
          storeFile=${{ runner.temp }}/upload-keystore.jks
          EOF

      - name: Build signed AAB
        run: flutter build appbundle --release

      - name: Upload AAB artifact
        uses: actions/upload-artifact@v4
        with:
          name: app-release-aab
          path: build/app/outputs/bundle/release/app-release.aab
          if-no-files-found: error

      - name: Clean up secrets on runner
        if: always()
        run: |
          rm -f android/key.properties "${{ runner.temp }}/upload-keystore.jks"
```

> Notas:
> - El AAB se sube como *artifact*; la **subida a Play** sigue siendo manual (o se
>   automatiza aparte con `r0adkll/upload-google-play` + una service account de Play,
>   fuera del alcance de este snippet).
> - El paso final borra `key.properties` y el `.jks` del runner por higiene; en runners
>   efímeros de GitHub no es estrictamente necesario, pero es buena práctica.
> - `flutter-version: '3.38.9'` fija la versión usada en local; el CI existente
>   (`.github/workflows/ci.yml`) usa `channel: stable` sin fijar versión.
