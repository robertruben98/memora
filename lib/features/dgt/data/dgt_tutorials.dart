/// Issue #153 (dgt-ux): mini-tutoriales pre-quiz por subtopic.
///
/// Catalogo estatico de tarjetas concepto + ejemplo para subtopics DGT
/// comunes. Si el `topic_id` no esta presente se hace silent fallback
/// (no se muestra tutorial, se va directo al quiz).
///
/// Aditivo, sin estado, sin IO. Mantener PURA para tests rapidos.
library;

/// Una tarjeta de tutorial: concepto clave + ejemplo resuelto corto.
class DgtTutorial {
  /// Identificador del topic asociado (key del registro).
  final String topicId;

  /// Concepto clave del subtopic (1-2 oraciones).
  final String concept;

  /// Ejemplo resuelto, suele explicar el "porque" de la respuesta correcta.
  final String example;

  const DgtTutorial({
    required this.topicId,
    required this.concept,
    required this.example,
  });
}

/// Catalogo estatico de tutoriales por subtopic. Las keys siguen
/// la convencion del backend para [DgtTopic.id] (slug en minusculas).
///
/// El listado inicial cubre los bloques mas comunes que aterrizan en
/// `/dgt/topics`. Anadir nuevos topics aqui sin modificar codigo de UI.
const Map<String, DgtTutorial> kDgtTutorials = {
  'senales': DgtTutorial(
    topicId: 'senales',
    concept:
        'Las senales triangulares advierten de un peligro proximo. Las '
        'circulares con borde rojo PROHIBEN. Las circulares azules son '
        'obligaciones, no recomendaciones.',
    example:
        'Una senal triangular con un coche derrapando indica "pavimento '
        'deslizante". No prohibe nada, solo advierte: hay que reducir '
        'velocidad y aumentar la distancia de seguridad.',
  ),
  'normas': DgtTutorial(
    topicId: 'normas',
    concept:
        'La prioridad de paso se rige por (en orden): semaforo, agente, '
        'senal vertical, marcas viales, y por ultimo norma general '
        '(derecha en interseccion sin senalizar).',
    example:
        'En un cruce sin senales con un coche a tu derecha, debes ceder '
        'aunque tu llegues primero. La norma general manda cuando no hay '
        'otra fuente de prioridad.',
  ),
  'mecanica': DgtTutorial(
    topicId: 'mecanica',
    concept:
        'Los neumaticos con dibujo inferior a 1.6 mm son ilegales y '
        'peligrosos. El reglaje correcto de presion influye en consumo, '
        'desgaste y distancia de frenado.',
    example:
        'Si circulas con un neumatico de 1.2 mm de dibujo te exponen a '
        'sancion grave y multiplican la distancia de frenado en mojado. '
        'Hay que sustituirlo antes de superar 1.6 mm.',
  ),
  'seguridad': DgtTutorial(
    topicId: 'seguridad',
    concept:
        'El cinturon es obligatorio en TODAS las plazas, incluido el '
        'asiento trasero. Los menores que no superan los 135 cm deben '
        'viajar con sistema de retencion homologado.',
    example:
        'Si llevas a un nino de 8 anos que mide 130 cm, debe ir en '
        'asiento elevador con respaldo. Llevarlo solo con cinturon es '
        'infraccion grave.',
  ),
  'circulacion': DgtTutorial(
    topicId: 'circulacion',
    concept:
        'Circula por el carril mas a la derecha siempre que sea posible. '
        'Los carriles centrales o izquierdos son solo para adelantar, '
        'no para "cruzar mas rapido".',
    example:
        'En una autovia de 3 carriles vacios, ocupar el central de forma '
        'continuada es infraccion. Hay que volver al derecho una vez '
        'terminado el adelantamiento.',
  ),
  'velocidad': DgtTutorial(
    topicId: 'velocidad',
    concept:
        'En via urbana el limite general es 50 km/h, en travesia 50 km/h '
        'salvo senal, en carretera convencional 90 km/h y en autovia/'
        'autopista 120 km/h.',
    example:
        'En un carril urbano de unico sentido el limite por defecto '
        'desde 2022 es 30 km/h. Solo es 50 si hay 2+ carriles por '
        'sentido senalizados.',
  ),
  'alcohol': DgtTutorial(
    topicId: 'alcohol',
    concept:
        'Tasa general 0.5 g/L (0.25 aire). Conductor novel o profesional: '
        '0.3 g/L (0.15 aire). Tasa penal: 0.6 mg/L aire = delito.',
    example:
        'Un novel con 0.16 mg/L de aire ya esta por encima de su limite '
        '(0.15). Aunque un conductor experimentado pasaria, el novel '
        'comete infraccion muy grave con retirada de puntos.',
  ),
  'maniobras': DgtTutorial(
    topicId: 'maniobras',
    concept:
        'Antes de cualquier maniobra (cambio carril, giro, parada): '
        'observa, senaliza con tiempo y ejecuta. Nunca senalizar y '
        'maniobrar simultaneamente.',
    example:
        'Para cambiar al carril izquierdo: 1) espejo retro + lateral, '
        '2) intermitente, 3) confirmar que nadie acelera detras, '
        '4) cruzar. Saltarse el paso 1 es la causa #1 de colisiones '
        'laterales.',
  ),
  'documentacion': DgtTutorial(
    topicId: 'documentacion',
    concept:
        'Llevar SIEMPRE: permiso de conducir, permiso de circulacion, '
        'ITV en vigor y seguro obligatorio. Caducados = infraccion '
        'grave.',
    example:
        'Si el seguro caduca un domingo y el lunes te paran, te '
        'inmovilizan el vehiculo. La fecha de pago previa no exime: '
        'cuenta la cobertura efectiva.',
  ),
  'medio-ambiente': DgtTutorial(
    topicId: 'medio-ambiente',
    concept:
        'La etiqueta ambiental DGT determina el acceso a Zonas de Bajas '
        'Emisiones (ZBE). 0 emisiones > ECO > C > B > sin etiqueta '
        '(este ultimo restringido en grandes ciudades).',
    example:
        'Un diesel matriculado en 2005 sin etiqueta no puede entrar a '
        'Madrid Central salvo con permiso temporal. Hay que consultar '
        'la ZBE de cada ciudad antes del viaje.',
  ),
};

/// Devuelve el tutorial asociado al topic o `null` si no hay catalogo
/// definido para ese `topicId`. Lookup case-insensitive y tolerante a
/// guiones bajos/medios (homogeneiza naming entre backend y catalogo).
DgtTutorial? lookupDgtTutorial(String topicId) {
  if (topicId.isEmpty) return null;
  final normalized = topicId.trim().toLowerCase().replaceAll('_', '-');
  return kDgtTutorials[normalized];
}
