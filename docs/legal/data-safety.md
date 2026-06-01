# Memora — Formulario de Seguridad de los Datos (Data Safety) de Google Play

Este documento mapea, pregunta por pregunta, las respuestas que deben introducirse en la sección **Data Safety / Seguridad de los datos** de Google Play Console para la app **Memora** (`com.robertdev.memora`). Úsalo como guía al rellenar el formulario.

Fecha de referencia: 1 de junio de 2026.

---

## Resumen general

| Pregunta del formulario | Respuesta |
|---|---|
| ¿Tu app recopila o comparte alguno de los tipos de datos de usuario obligatorios? | **Sí, recopila datos.** |
| ¿Tu app comparte datos de usuario con terceros? | **No.** |
| ¿Todos los datos recopilados están cifrados en tránsito? | **Sí** (HTTPS). |
| ¿Proporcionas una forma de solicitar la eliminación de los datos? | **Sí**, in-app y mediante URL. |

---

## Tipos de datos recopilados

Para cada tipo de dato, Play pregunta: si se **recopila**, si se **comparte**, la **finalidad**, si es **opcional u obligatorio** y si se puede **eliminar**.

### 1. Información personal → Dirección de correo electrónico (Email address)

- **¿Se recopila?** Sí.
- **¿Se comparte?** No.
- **Finalidad (purposes):** *Account management* (Gestión de cuentas). Es el identificador de inicio de sesión.
- **¿Es obligatorio u opcional?** **Obligatorio** (se requiere para crear la cuenta y sincronizar).
- **¿Cifrado en tránsito?** Sí.
- **¿El usuario puede solicitar su eliminación?** Sí.

> Nota sobre la contraseña: la contraseña no se declara como tipo de dato compartido ni se almacena en claro; se guarda cifrada con bcrypt. En el formulario de Play la contraseña se asocia al tipo "Información personal" únicamente como credencial de acceso; no es un identificador publicitario ni se comparte.

### 2. Actividad en la app (App activity) → Progreso e historial de estudio

Incluye: historial de repasos, estadísticas de rendimiento, evolución semanal, logros/insignias y favoritos del modo DGT.

- **¿Se recopila?** Sí.
- **¿Se comparte?** No.
- **Finalidad (purposes):** *App functionality* (Funcionalidad de la app) y *Personalization* (Personalización). Permite sincronizar y mostrar tu progreso y estadísticas.
- **¿Es obligatorio u opcional?** Obligatorio para el funcionamiento de la sincronización.
- **¿Cifrado en tránsito?** Sí.
- **¿El usuario puede solicitar su eliminación?** Sí.

### 3. Contenido del usuario (User content / Other user-generated content) → Mazos y tarjetas

Incluye los mazos y las tarjetas que el usuario crea, importa o edita.

- **¿Se recopila?** Sí.
- **¿Se comparte?** No.
- **Finalidad (purposes):** *App functionality* (Funcionalidad de la app). Permite guardar y sincronizar el contenido de estudio del usuario.
- **¿Es obligatorio u opcional?** Obligatorio para guardar y sincronizar el contenido.
- **¿Cifrado en tránsito?** Sí.
- **¿El usuario puede solicitar su eliminación?** Sí.

---

## Prácticas de seguridad de los datos

- **¿Los datos están cifrados en tránsito?** **Sí.** Toda la comunicación con el servidor usa HTTPS.
- **¿Los usuarios pueden solicitar la eliminación de sus datos?** **Sí.**
  - **In-app:** Ajustes → Eliminar cuenta (borrado inmediato e irreversible de todos los datos).
  - **URL de solicitud de borrado:** `https://memora.a-robertdev.com/eliminar-cuenta`
- **¿La app sigue las políticas de Families?** No aplica de forma específica; la app es educativa y apta para todos los públicos.

---

## Lo que Memora NO hace (declaraciones negativas)

- **No vende datos personales** a terceros.
- **No comparte datos** con terceros con fines comerciales ni publicitarios.
- **No incluye SDK de publicidad de terceros.**
- **No incluye SDK de analítica de terceros** (sin Google Analytics, Firebase Analytics, Facebook SDK ni similares).
- **No recopila identificadores publicitarios** (Advertising ID).
- **No recopila** ubicación, contactos, fotos/vídeos del usuario, audio ni datos de salud.

---

## Enlaces de referencia para el formulario

- **Política de privacidad:** `https://memora.a-robertdev.com/privacidad`
- **Página de eliminación de cuenta:** `https://memora.a-robertdev.com/eliminar-cuenta`
- **Email de contacto:** robertruben98@gmail.com
