/// Issue #110 (dgt-content): pildoras didacticas pre-quiz.
///
/// Map estatico de topic_id -> contenido normativo clave que se muestra ANTES
/// de entrar a practica de tema critico. Reduce frustracion en bloques con
/// alta tasa de fallo (primeros auxilios, distancia, alcohol, adelantamiento,
/// glorietas).
///
/// Persistencia: SharedPreferences key `dgt:pill:seen:<topic_id>` (true=ya vista).
/// Mostrar 1 vez por sesion por tema. Si no hay pildora definida para el
/// topic_id no se muestra nada (comportamiento actual).
///
/// Aditivo: no toca DgtPracticeScreen flow ni simulacro cronometrado.
library;

class DgtTopicPill {
  /// Titulo corto del tema.
  final String title;

  /// Icono representativo (emoji o codepoint Material).
  final String emoji;

  /// 3-5 bullets con la normativa clave.
  final List<String> bullets;

  /// Mnemotecnia opcional (ej. "PAS = Proteger-Avisar-Socorrer").
  final String? mnemonic;

  const DgtTopicPill({
    required this.title,
    required this.emoji,
    required this.bullets,
    this.mnemonic,
  });
}

/// SharedPreferences key prefix.
const String kDgtPillSeenPrefix = 'dgt:pill:seen:';

/// Mapa topic_id -> pildora. IDs alineados con `kDgtSectionsLocal` y los
/// topic_id que devuelve el backend.
const Map<String, DgtTopicPill> kDgtTopicPills = {
  'primeros-auxilios': DgtTopicPill(
    title: 'Primeros auxilios',
    emoji: '🚑',
    bullets: [
      'Protocolo PAS: Proteger la zona, Avisar al 112, Socorrer (en ese orden).',
      'Nunca socorrer si la zona no esta protegida (triangulos + chaleco).',
      'No mover heridos salvo riesgo inminente (incendio, vuelco).',
      'Hemorragias: presion directa con gasa limpia, elevar extremidad sin fractura.',
      'No quitar el casco a motoristas salvo necesidad de reanimacion.',
    ],
    mnemonic: 'PAS = Proteger - Avisar - Socorrer',
  ),
  'normas': DgtTopicPill(
    title: 'Distancia de seguridad y adelantamiento',
    emoji: '📏',
    bullets: [
      'Regla de los 2 segundos en seco, 4 segundos en mojado.',
      'A 100 km/h, 2 segundos = ~56 metros.',
      'Adelantamiento por la izquierda; prohibido en curvas sin visibilidad y cambios de rasante.',
      'Adelantar a ciclistas: 1.5 m laterales + reducir 20 km/h, puedes invadir continua si es seguro.',
      'No adelantar en pasos de peatones ni intersecciones.',
    ],
    mnemonic: '2s seco / 4s mojado',
  ),
  'alcohol-drogas': DgtTopicPill(
    title: 'Alcohol y drogas',
    emoji: '🍷',
    bullets: [
      'Conductor general: 0,5 g/L sangre (0,25 mg/L aire).',
      'Noveles (<2 anos carnet) y profesionales: 0,3 g/L (0,15 mg/L).',
      'Superar 0,60 mg/L en aire o negativa a la prueba = DELITO penal.',
      'Drogas: cualquier presencia es infraccion muy grave.',
      'Alcohol multiplica x2 el riesgo de accidente a tasa 0,5 g/L.',
    ],
    mnemonic: 'Novel 0,3 / Resto 0,5 / Delito 0,60 aire',
  ),
  'prioridad': DgtTopicPill(
    title: 'Glorietas y prioridad',
    emoji: '🔄',
    bullets: [
      'En glorieta tiene prioridad quien YA circula dentro del anillo.',
      'Quien se incorpora cede el paso aunque circulen lento.',
      'En interseccion sin senales: preferencia por la derecha.',
      'Vehiculos prioritarios con senales luminosas/acusticas tienen prioridad absoluta.',
      'Peatones en paso de cebra y ciclistas en grupo formado tienen preferencia.',
    ],
    mnemonic: 'Dentro manda, fuera cede',
  ),
  'velocidad': DgtTopicPill(
    title: 'Limites de velocidad',
    emoji: '🚗',
    bullets: [
      'Autopista/autovia turismo: 120 km/h (minimo 60 km/h).',
      'Carretera convencional: 90 km/h.',
      'Travesia y zona urbana: 50 km/h (calle 1 carril/sentido: 30).',
      'Adaptar siempre a condiciones (niebla, lluvia) aunque sea menor al limite.',
      'Exceso >50% Y al menos 60 km/h sobre limite = delito.',
    ],
    mnemonic: '120 / 90 / 50 / 30',
  ),
};

/// Devuelve la pildora asociada a un topic_id, o null si no hay definida.
DgtTopicPill? pillForTopic(String topicId) => kDgtTopicPills[topicId];
