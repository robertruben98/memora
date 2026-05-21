/// Catalogo estatico de tutoriales pre-quiz DGT (issue #153 dgt-ux).
///
/// Por que un mapa en Dart y no `assets/dgt_tutorials.json`:
///   - El proyecto NO usa todavia `rootBundle.loadString` en ningun otro
///     sitio (grep limpio en `lib/`). Anadir esa dependencia obliga a
///     registrar el asset en `pubspec.yaml`, lo que el script de build de
///     CI compila y volveria a registrar como AssetManifest. Mantener
///     contenido inline evita ese acople, hace los tests sincronos y
///     deja la puerta abierta a mover a JSON cuando haya 3+ catalogos
///     similares.
///   - Contenido pequeno (texto plano por subtopic): no justifica file IO.
///
/// Forma del registro:
///   - `concept`: 1-2 frases con el concepto clave del subtopic.
///   - `example`: ejemplo resuelto breve, redactado como pregunta-respuesta
///     para reforzar el patron del banco DGT.
///
/// Convencion de keys: SLUG del topic. Coincide con `DgtTopic.id` que el
/// repo expone (`(j['id'] ?? j['slug'] ?? j['name'] ?? '').toString()`).
///
/// Aditivo y silent fallback: si un topic_id no aparece aqui,
/// `lookupDgtTutorial` devuelve null y la pantalla de tutoriales NO se
/// muestra (el flujo salta directo al quiz). No introducir excepciones.
library;

/// Tutorial breve mostrado antes del batch de preguntas.
class DgtTutorial {
  /// Concepto clave del subtopic.
  final String concept;

  /// Ejemplo resuelto (formato pregunta-respuesta corto).
  final String example;

  const DgtTutorial({required this.concept, required this.example});
}

/// Catalogo inicial. Cobertura: 5 subtopics frecuentes en autoescuelas.
/// Cualquier otro topic cae en silent fallback.
///
/// IMPORTANTE para tests/regresion: las keys aqui SON ESTABLES — referencias
/// externas (analytics, contenido editorial) las usan como pivot.
const Map<String, DgtTutorial> dgtTutorialsCatalog = {
  'senales': DgtTutorial(
    concept:
        'Las senales se clasifican por color y forma. Triangulo rojo: peligro. '
        'Circulo rojo: prohibicion. Circulo azul: obligacion. Cuadrado o '
        'rectangulo azul: indicacion.',
    example:
        'Triangulo con linea ondulada -> peligro por pavimento deslizante.',
  ),
  'normas': DgtTutorial(
    concept:
        'La velocidad maxima depende de la via, no solo del vehiculo. En via '
        'urbana general es 50 km/h, y en travesias se aplica la limitacion '
        'urbana salvo senalizacion expresa.',
    example: 'Travesia sin senal de velocidad -> 50 km/h por defecto.',
  ),
  'mecanica': DgtTutorial(
    concept:
        'Antes de salir, revisa neumaticos (presion y dibujo), niveles '
        '(aceite, refrigerante, frenos) y luces. El testigo rojo siempre '
        'implica parar; el ambar avisa, pero no obliga a detenerse.',
    example:
        'Testigo ambar de inyeccion encendido -> seguir y revisar lo antes '
        'posible, no es parada inmediata.',
  ),
  'seguridad': DgtTutorial(
    concept:
        'El cinturon y el sistema de retencion son obligatorios para todos '
        'los ocupantes. Los menores de 135 cm deben usar sistema homologado y '
        'viajar en plazas traseras, salvo excepciones.',
    example:
        'Nino de 130 cm en asiento delantero sin SRI -> infraccion grave.',
  ),
  'circulacion': DgtTutorial(
    concept:
        'En interseccion sin senalizar tiene preferencia el que llega por la '
        'derecha. Glorieta: prioridad para el que ya esta dentro.',
    example:
        'Dos vehiculos llegan a la vez a cruce sin senales -> cede el de la '
        'izquierda.',
  ),
};

/// Lookup case-insensitive del catalogo. Acepta espacios y guiones bajos
/// como separadores (el backend a veces devuelve "senales" vs "Senales").
/// Devuelve null si no hay tutorial -> silent fallback en UI.
DgtTutorial? lookupDgtTutorial(String? topicId) {
  if (topicId == null || topicId.isEmpty) return null;
  final key = topicId.trim().toLowerCase().replaceAll(' ', '_');
  return dgtTutorialsCatalog[key];
}
