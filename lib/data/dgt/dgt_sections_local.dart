/// Contenido teorico hardcoded para modo Estudio por Secciones DGT.
///
/// 13 secciones (topics) alineadas con el temario oficial DGT. Cada seccion
/// expone una lista de conceptos clave. Un concepto es texto explicativo
/// (NO pregunta multi-choice): titulo + parrafo + ejemplo opcional.
///
/// El [id] de cada seccion intenta coincidir con los topic_id usados en el
/// backend para preguntas (cuando exista), de forma que "Practicar este tema"
/// pueda enlazar al modo practica existente.
library;

class DgtConcept {
  final String title;
  final String body;
  final String? example;

  const DgtConcept({
    required this.title,
    required this.body,
    this.example,
  });
}

class DgtSection {
  final String id;
  final String name;
  final String description;
  final List<DgtConcept> concepts;

  const DgtSection({
    required this.id,
    required this.name,
    required this.description,
    required this.concepts,
  });
}

/// 13 secciones DGT con contenido teorico inicial (3-5 conceptos cada una).
const List<DgtSection> kDgtSectionsLocal = [
  DgtSection(
    id: 'senales',
    name: 'Senales de circulacion',
    description: 'Tipos, formas, colores y jerarquia entre senales.',
    concepts: [
      DgtConcept(
        title: 'Jerarquia de senales',
        body:
            'Cuando dos indicaciones se contradicen prevalece el orden: agente '
            'de circulacion, semaforo, senal circunstancial, senal vertical y '
            'por ultimo marcas viales.',
        example:
            'Si el semaforo esta en verde pero el agente ordena detenerse, '
            'debes parar: el agente prevalece sobre el semaforo.',
      ),
      DgtConcept(
        title: 'Senales de prioridad',
        body:
            'Indican el orden de paso en intersecciones. Las mas comunes son '
            'stop (octogonal roja), ceda el paso (triangular invertida) y '
            'calzada con prioridad (rombo amarillo).',
        example:
            'Ante una senal de stop debes detenerte completamente aunque no '
            'haya trafico cruzando.',
      ),
      DgtConcept(
        title: 'Senales de prohibicion y restriccion',
        body:
            'Circulares con borde rojo. Imponen una prohibicion como entrada '
            'prohibida, velocidad maxima, adelantamiento prohibido o '
            'limitacion de masa.',
        example:
            'Una senal circular con "80" en rojo prohibe superar los 80 km/h.',
      ),
      DgtConcept(
        title: 'Senales de obligacion',
        body:
            'Circulares azules. Imponen una accion: direccion obligatoria, '
            'uso obligatorio de cadenas, velocidad minima, carril obligatorio.',
        example:
            'Una flecha blanca recta sobre fondo azul circular obliga a '
            'continuar de frente.',
      ),
      DgtConcept(
        title: 'Marcas viales',
        body:
            'Lineas y simbolos pintados en la calzada. Las longitudinales '
            'continuas no se pueden cruzar; las discontinuas si. Las amarillas '
            'son temporales (obras) y prevalecen sobre las blancas.',
        example:
            'Una linea blanca discontinua permite adelantar; una continua no.',
      ),
    ],
  ),
  DgtSection(
    id: 'normas',
    name: 'Normas generales de circulacion',
    description: 'Reglas de comportamiento en via, posicion y velocidad.',
    concepts: [
      DgtConcept(
        title: 'Posicion en la calzada',
        body:
            'Como norma general se circula por el carril mas a la derecha. '
            'Los carriles izquierdos se usan para adelantar o cuando los de '
            'la derecha estan ocupados.',
        example:
            'En autopista de 3 carriles, si circulas a 90 km/h sin ningun '
            'vehiculo a tu derecha, debes regresar al carril derecho.',
      ),
      DgtConcept(
        title: 'Cambio de carril e intermitentes',
        body:
            'Toda maniobra que altere la trayectoria exige advertir con '
            'antelacion mediante luz indicadora de direccion. No se cambia '
            'de carril sobre marca continua.',
        example:
            'Para incorporarse a una autovia se senaliza, se observa el '
            'angulo muerto y se acelera hasta la velocidad del trafico.',
      ),
      DgtConcept(
        title: 'Distancia de seguridad',
        body:
            'Debe permitir detener el vehiculo sin colisionar con el de '
            'delante en caso de frenazo. Como referencia practica, la regla '
            'de los 2 segundos sobre seco y 4 segundos sobre mojado.',
        example:
            'A 100 km/h recorres unos 28 metros por segundo: 2 segundos '
            'son aproximadamente 56 metros.',
      ),
      DgtConcept(
        title: 'Adelantamiento',
        body:
            'Se realiza por la izquierda salvo que el conductor delantero '
            'haya senalizado giro a la izquierda. Prohibido en cambios de '
            'rasante, curvas sin visibilidad y pasos de peatones.',
        example:
            'En una curva sin visibilidad NO puedes adelantar aunque la '
            'marca vial sea discontinua.',
      ),
    ],
  ),
  DgtSection(
    id: 'prioridad',
    name: 'Prioridad de paso',
    description: 'Quien pasa primero en cruces, glorietas y situaciones especiales.',
    concepts: [
      DgtConcept(
        title: 'Regla general en interseccion sin senales',
        body:
            'Tiene preferencia el vehiculo que se aproxima por la derecha. '
            'Aplica cuando ninguna senal o marca regula el cruce.',
        example:
            'En un cruce sin senales, si llegan dos coches al mismo tiempo, '
            'pasa primero el que viene por la derecha del otro.',
      ),
      DgtConcept(
        title: 'Glorietas',
        body:
            'Tiene preferencia el vehiculo que ya circula por el anillo de '
            'la rotonda. Quien se incorpora debe ceder el paso.',
        example:
            'Antes de entrar a la glorieta cedes el paso aunque el coche '
            'ya dentro circule lento.',
      ),
      DgtConcept(
        title: 'Vehiculos prioritarios',
        body:
            'Ambulancia, policia, bomberos y proteccion civil en servicio '
            'urgente tienen prioridad absoluta cuando usan senales '
            'luminosas y/o acusticas.',
        example:
            'Si oyes la sirena de una ambulancia detras debes facilitar '
            'el paso, incluso saltando un semaforo en rojo si es seguro.',
      ),
      DgtConcept(
        title: 'Peatones y ciclistas',
        body:
            'Peatones en paso de cebra y ciclistas en carril bici o en '
            'grupo formado tienen preferencia sobre el resto del trafico.',
        example:
            'Si un peaton esta cruzando un paso de cebra, debes detenerte '
            'completamente hasta que termine el cruce.',
      ),
    ],
  ),
  DgtSection(
    id: 'velocidad',
    name: 'Velocidad',
    description: 'Limites genericos, factores que la moderan y sanciones.',
    concepts: [
      DgtConcept(
        title: 'Limites genericos en turismo',
        body:
            'Autopista y autovia: 120 km/h. Carretera convencional: 90 km/h. '
            'Travesia: 50 km/h. Zona urbana: 50 km/h salvo via 30 (calle un '
            'solo carril por sentido).',
        example:
            'En una calle urbana de un unico carril por sentido el limite '
            'es 30 km/h aunque no haya senal.',
      ),
      DgtConcept(
        title: 'Velocidad adecuada',
        body:
            'El conductor debe adaptar la velocidad a las condiciones de '
            'la via, trafico, visibilidad y meteorologia, aunque sea '
            'inferior al limite generico.',
        example:
            'Con niebla densa en autovia debes reducir bien por debajo de '
            '120 km/h aunque el limite no haya cambiado.',
      ),
      DgtConcept(
        title: 'Velocidad minima',
        body:
            'En autopista y autovia la velocidad minima es 60 km/h salvo '
            'senalizacion. Circular muy despacio sin causa justificada es '
            'sancionable.',
        example:
            'Si circulas a 40 km/h en autovia sin avería ni emergencia, '
            'puedes ser multado por entorpecer la circulacion.',
      ),
      DgtConcept(
        title: 'Exceso de velocidad',
        body:
            'Las sanciones varian segun el limite y el exceso. Superar el '
            'limite mas de un 50 por ciento (y al menos 60 km/h) es delito '
            'contra la seguridad vial.',
        example:
            'Circular a 200 km/h por una autovia limitada a 120 es delito.',
      ),
    ],
  ),
  DgtSection(
    id: 'alcohol-drogas',
    name: 'Alcohol y drogas',
    description: 'Tasas legales, efectos y sanciones por consumo.',
    concepts: [
      DgtConcept(
        title: 'Tasas legales de alcohol',
        body:
            'Conductor general: 0,5 g/L en sangre o 0,25 mg/L en aire '
            'espirado. Noveles (menos de 2 anos de carnet) y profesionales: '
            '0,3 g/L o 0,15 mg/L.',
        example:
            'Un novel con 0,4 g/L de alcohol en sangre ya esta cometiendo '
            'una infraccion aunque ese nivel sea legal para un veterano.',
      ),
      DgtConcept(
        title: 'Efectos del alcohol',
        body:
            'Aumenta el tiempo de reaccion, reduce el campo visual, da falsa '
            'sensacion de seguridad y dificulta calcular distancias y '
            'velocidades.',
        example:
            'Con tasa 0,5 g/L el riesgo de accidente se multiplica por 2 '
            'aproximadamente respecto a un conductor sobrio.',
      ),
      DgtConcept(
        title: 'Drogas',
        body:
            'La presencia de cualquier droga toxica o estupefaciente en el '
            'organismo del conductor esta prohibida, salvo medicamentos '
            'bajo prescripcion compatible con la conduccion.',
        example:
            'Conducir tras consumir cannabis, aunque no se note efecto, '
            'es infraccion muy grave.',
      ),
      DgtConcept(
        title: 'Sanciones',
        body:
            'Multas, retirada de puntos y, si supera 0,60 mg/L en aire o '
            'hay negativa a la prueba, delito penal con pena de prision o '
            'trabajos en beneficio de la comunidad.',
        example:
            'Negarse a soplar en un control es delito de desobediencia y '
            'puede acarrear hasta un ano de prision.',
      ),
    ],
  ),
  DgtSection(
    id: 'seguridad-activa',
    name: 'Seguridad activa',
    description: 'Sistemas que ayudan a evitar el accidente.',
    concepts: [
      DgtConcept(
        title: 'ABS',
        body:
            'El sistema antibloqueo de frenos impide que las ruedas se '
            'bloqueen al frenar fuerte, permitiendo seguir dirigiendo el '
            'vehiculo mientras se frena al maximo.',
        example:
            'En una frenada de emergencia con ABS debes pisar el freno a '
            'fondo y mantenerlo, sin bombear.',
      ),
      DgtConcept(
        title: 'ESP / control de estabilidad',
        body:
            'Detecta perdida de adherencia y frena ruedas individuales '
            'para devolver el vehiculo a su trayectoria.',
        example:
            'En una curva tomada demasiado rapido en mojado el ESP puede '
            'evitar el subviraje o derrape.',
      ),
      DgtConcept(
        title: 'Iluminacion',
        body:
            'Es seguridad activa porque permite ver y ser visto. Faros, '
            'pilotos y luz de gas-oleo deben estar en perfecto estado y '
            'limpios.',
        example:
            'Conducir con un faro fundido por la noche es infraccion y '
            'multiplica el riesgo.',
      ),
      DgtConcept(
        title: 'Neumaticos',
        body:
            'Profundidad minima legal 1,6 mm en la banda de rodadura. La '
            'presion debe ajustarse a carga y velocidad recomendada por '
            'el fabricante.',
        example:
            'Con neumaticos por debajo de 1,6 mm la distancia de frenada '
            'en mojado se duplica facilmente.',
      ),
    ],
  ),
  DgtSection(
    id: 'seguridad-pasiva',
    name: 'Seguridad pasiva',
    description: 'Elementos que minimizan danos cuando el accidente ocurre.',
    concepts: [
      DgtConcept(
        title: 'Cinturon de seguridad',
        body:
            'Obligatorio para todos los ocupantes en todos los asientos. '
            'Reduce hasta un 50 por ciento la mortalidad en colision.',
        example:
            'A 50 km/h sin cinturon, el cuerpo impacta contra el salpicadero '
            'con la fuerza de una caida desde 10 metros.',
      ),
      DgtConcept(
        title: 'Airbag',
        body:
            'Complemento del cinturon (no sustituto). Se infla y desinfla '
            'en milisegundos para amortiguar el impacto de cabeza y torax.',
        example:
            'Sin cinturon, el airbag puede provocar lesiones mas graves '
            'que las que evita.',
      ),
      DgtConcept(
        title: 'Sistemas de retencion infantil (SRI)',
        body:
            'Menores de 135 cm deben viajar siempre en SRI homologado '
            'adecuado a su talla y peso, preferentemente en asiento '
            'trasero.',
        example:
            'Un nino de 7 anos y 125 cm debe usar elevador con respaldo '
            'aunque mida casi lo mismo que un adulto bajo.',
      ),
      DgtConcept(
        title: 'Reposacabezas',
        body:
            'Bien regulado evita el latigazo cervical en colisiones por '
            'alcance. El borde superior debe quedar a la altura de la '
            'parte superior de la cabeza.',
        example:
            'Si el reposacabezas queda a la altura del cuello, en un '
            'impacto trasero protege poco y puede agravar lesiones.',
      ),
    ],
  ),
  DgtSection(
    id: 'mecanica',
    name: 'Mecanica y mantenimiento',
    description: 'Conocimientos basicos del vehiculo y sus revisiones.',
    concepts: [
      DgtConcept(
        title: 'Motor: aceite y refrigerante',
        body:
            'Revisar el nivel en frio y sobre superficie plana. Aceite por '
            'debajo del minimo o refrigerante muy bajo pueden gripar el '
            'motor.',
        example:
            'Si el testigo de presion de aceite se enciende debes detener '
            'el vehiculo lo antes posible.',
      ),
      DgtConcept(
        title: 'Frenos',
        body:
            'El liquido de frenos absorbe humedad y se cambia cada 2 anos '
            'aproximadamente. Pastillas y discos se inspeccionan en cada '
            'revision.',
        example:
            'Pedal de freno largo o esponjoso indica aire en el circuito '
            'o falta de liquido: revision inmediata.',
      ),
      DgtConcept(
        title: 'Bateria',
        body:
            'Alimenta los componentes electricos. Una bateria descargada '
            'impide arrancar y, en mas de 5 anos, suele pedir reemplazo.',
        example:
            'Si al girar la llave oyes un click pero no arranca, '
            'probablemente la bateria esta descargada.',
      ),
      DgtConcept(
        title: 'ITV',
        body:
            'Inspeccion Tecnica de Vehiculos obligatoria. Turismo nuevo: '
            'primera ITV a los 4 anos; despues cada 2 anos hasta los 10 '
            'anos; luego anual.',
        example:
            'Circular con ITV caducada es infraccion grave y la aseguradora '
            'puede no cubrir un accidente.',
      ),
    ],
  ),
  DgtSection(
    id: 'conduccion-segura',
    name: 'Conduccion segura y eficiente',
    description: 'Tecnicas para conducir con seguridad y bajo consumo.',
    concepts: [
      DgtConcept(
        title: 'Vision y anticipacion',
        body:
            'Mirar lejos, abarcar todo el campo visual y observar con '
            'frecuencia espejos. Anticipar maniobras de otros usuarios '
            'reduce frenadas bruscas.',
        example:
            'Si ves luces de freno 3 coches por delante, levantas el pie '
            'antes de que el de delante frene.',
      ),
      DgtConcept(
        title: 'Conduccion eficiente',
        body:
            'Cambiar pronto a marcha alta, mantener velocidad constante, '
            'usar la inercia y evitar acelerones reduce hasta un 20 por '
            'ciento de consumo.',
        example:
            'Circular en 5a a 80 km/h consume bastante menos que en 4a '
            'a la misma velocidad.',
      ),
      DgtConcept(
        title: 'Fatiga',
        body:
            'Reduce la atencion y aumenta el tiempo de reaccion. Se '
            'recomienda parar cada 2 horas o 200 km.',
        example:
            'En viajes largos, una pausa de 15-20 minutos cada 2 horas '
            'mejora notablemente la atencion.',
      ),
      DgtConcept(
        title: 'Distracciones',
        body:
            'Usar el movil al volante multiplica por entre 4 y 9 el riesgo '
            'de accidente. Esta prohibido sostenerlo aunque sea con manos '
            'libres mal usado.',
        example:
            'Escribir un mensaje a 90 km/h equivale a recorrer 100 metros '
            'sin mirar la carretera.',
      ),
    ],
  ),
  DgtSection(
    id: 'maniobras',
    name: 'Maniobras especiales',
    description: 'Marcha atras, estacionamiento, cambios de sentido.',
    concepts: [
      DgtConcept(
        title: 'Marcha atras',
        body:
            'Maniobra excepcional y corta. Prohibida en autopista y autovia. '
            'En vias urbanas solo para completar otra maniobra (por ejemplo '
            'aparcar).',
        example:
            'Si te pasas la salida de la autopista NO puedes dar marcha '
            'atras: continua hasta la siguiente salida.',
      ),
      DgtConcept(
        title: 'Cambio de sentido',
        body:
            'Solo en lugar habilitado. Prohibido en cambios de rasante, '
            'curvas sin visibilidad, tuneles, puentes y pasos a nivel.',
        example:
            'Para cambiar de sentido en travesia debes hacerlo donde la '
            'marca lo permita y con buena visibilidad.',
      ),
      DgtConcept(
        title: 'Estacionamiento',
        body:
            'Prohibido a menos de 5 m de un cruce, en paso de peatones, '
            'sobre acera, en carril bici, en parada de bus o impidiendo '
            'maniobras.',
        example:
            'Aparcar a 3 metros de un paso de cebra es infraccion aunque '
            'no haya senal de prohibido.',
      ),
      DgtConcept(
        title: 'Parada vs estacionamiento',
        body:
            'Parada: hasta 2 minutos sin abandonar el vehiculo, para subir '
            'o bajar pasajeros o carga. Estacionamiento: cualquier '
            'inmovilizacion superior.',
        example:
            'Detenerte 5 minutos en doble fila aunque permanezcas dentro '
            'del coche ya cuenta como estacionar mal.',
      ),
    ],
  ),
  DgtSection(
    id: 'primeros-auxilios',
    name: 'Primeros auxilios',
    description: 'Protocolo PAS y actuacion ante accidente.',
    concepts: [
      DgtConcept(
        title: 'Protocolo PAS',
        body:
            'Proteger la zona del accidente, Avisar al 112 y Socorrer a '
            'las victimas, en ese orden. Nunca socorrer si la zona no '
            'esta protegida.',
        example:
            'Antes de bajar a auxiliar pones triangulos y chaleco; luego '
            'llamas al 112; luego ayudas a los heridos.',
      ),
      DgtConcept(
        title: 'Llamada al 112',
        body:
            'Indicar lugar exacto (punto kilometrico y sentido), numero '
            'de vehiculos implicados, numero de heridos y estado aparente '
            '(consciencia, sangrado).',
        example:
            'Decir "km 47 de la A-7, sentido Valencia, 2 coches, 3 '
            'heridos conscientes" agiliza la respuesta.',
      ),
      DgtConcept(
        title: 'No mover heridos',
        body:
            'No se debe mover a un herido salvo riesgo inminente (incendio, '
            'vuelco, posicion peligrosa). Se mantiene caliente y se vigila '
            'su respiracion.',
        example:
            'A un motorista caido en el carril NO le quitas el casco a '
            'menos que sea imprescindible para reanimarlo.',
      ),
      DgtConcept(
        title: 'Hemorragias',
        body:
            'Se controla con presion directa sobre la herida con gasa o '
            'pano limpio. Elevar la extremidad si no hay fractura. Torniquete '
            'solo en ultima instancia.',
        example:
            'Si un herido sangra mucho por una pierna, presionas la herida '
            'y elevas la pierna, sin retirar la gasa si se empapa.',
      ),
    ],
  ),
  DgtSection(
    id: 'documentacion',
    name: 'Documentacion y administracion',
    description: 'Permisos, seguro, ficha tecnica y obligaciones.',
    concepts: [
      DgtConcept(
        title: 'Permiso de conducir',
        body:
            'Documento obligatorio. Hay distintas clases (B turismo, A moto, '
            'C camion, D autobus). El permiso B se obtiene a partir de '
            'los 18 anos.',
        example:
            'Con permiso B puedes conducir motos de hasta 125 cc en '
            'territorio nacional tras 3 anos con el carnet.',
      ),
      DgtConcept(
        title: 'Permiso de circulacion y ficha tecnica',
        body:
            'El permiso de circulacion acredita la titularidad. La ficha '
            'tecnica (ITV) recoge caracteristicas, reformas e inspecciones '
            'del vehiculo.',
        example:
            'Si vendes el coche debes notificar el cambio de titularidad '
            'a Trafico para no responder de futuras multas.',
      ),
      DgtConcept(
        title: 'Seguro obligatorio',
        body:
            'Todo vehiculo a motor debe tener seguro de responsabilidad '
            'civil. Sin el, el conductor responde con su patrimonio en '
            'caso de dano a terceros.',
        example:
            'Circular sin seguro es infraccion muy grave: multa fuerte e '
            'inmovilizacion del vehiculo.',
      ),
      DgtConcept(
        title: 'Permiso por puntos',
        body:
            'Cada conductor parte con 12 puntos (8 si es novel). Las '
            'infracciones graves y muy graves restan puntos; perderlos '
            'todos supone retirada del permiso.',
        example:
            'Hablar por movil con la mano resta 6 puntos; superar el '
            'limite de velocidad 51-60 km/h resta 6 puntos.',
      ),
    ],
  ),
  DgtSection(
    id: 'otros-usuarios',
    name: 'Otros usuarios de la via',
    description: 'Peatones, ciclistas, motociclistas y vehiculos especiales.',
    concepts: [
      DgtConcept(
        title: 'Peatones',
        body:
            'Por aceras o en su defecto por arcen, en sentido contrario al '
            'trafico. En via interurbana sin acera ni arcen, por la izquierda '
            'lo mas pegados al borde posible.',
        example:
            'De noche fuera de poblado, el peaton debe llevar prenda '
            'reflectante para ser visto a 150 metros.',
      ),
      DgtConcept(
        title: 'Ciclistas',
        body:
            'Tienen prioridad en carril bici y al circular en grupo en '
            'paralelo cuando van por la calzada. El adelantamiento al '
            'ciclista se hace dejando al menos 1,5 m laterales y reduciendo '
            'a 20 km/h por debajo del limite si es necesario.',
        example:
            'Para adelantar a un ciclista en una carretera limitada a '
            '90 km/h puedes invadir el carril contrario incluso con linea '
            'continua si no hay peligro.',
      ),
      DgtConcept(
        title: 'Motociclistas',
        body:
            'Vulnerables por su menor estabilidad y exposicion. Casco '
            'obligatorio para conductor y pasajero. Pueden circular entre '
            'carriles solo cuando la normativa local lo autorice.',
        example:
            'En atasco urbano, un motorista que adelanta entre carriles '
            'lo hace bajo su responsabilidad: respetalo y no abras la '
            'puerta sin mirar.',
      ),
      DgtConcept(
        title: 'Vehiculos lentos y agricolas',
        body:
            'Tractores, ciclomotores y vehiculos especiales circulan a '
            'velocidad reducida. Suelen tener obligacion de senalizar y '
            'apartarse para facilitar adelantamientos.',
        example:
            'Un tractor que circula a 30 km/h en carretera debe usar el '
            'arcen si es transitable para que adelantemos.',
      ),
    ],
  ),
  DgtSection(
    id: 'equipamiento',
    name: 'Equipamiento obligatorio',
    description: 'Elementos que el vehiculo debe llevar y su uso correcto.',
    concepts: [
      DgtConcept(
        title: 'Senalizacion de emergencia: triangulos y V-16',
        body:
            'Para senalizar el vehiculo inmovilizado se usan dos triangulos '
            'de preemergencia (uno delante y otro detras). Desde 2026 la luz '
            'de emergencia V-16 conectada (con geolocalizacion a DGT 3.0) '
            'sustituye a los triangulos y evita bajar a la calzada.',
        example:
            'En autovia, si te quedas parado, colocar la V-16 en el techo '
            'desde dentro del coche es mas seguro que salir a poner '
            'triangulos.',
      ),
      DgtConcept(
        title: 'Chaleco reflectante',
        body:
            'Es obligatorio llevar al menos un chaleco reflectante homologado '
            'en el habitaculo (no en el maletero) y ponerselo antes de salir '
            'del vehiculo cuando se circula o se realizan tareas en la '
            'calzada o el arcen.',
        example:
            'Antes de bajar a colocar la senalizacion en carretera debes '
            'ponerte el chaleco, no despues de haber salido del coche.',
      ),
      DgtConcept(
        title: 'Rueda de repuesto y herramientas',
        body:
            'El vehiculo debe poder reparar un pinchazo: rueda de repuesto '
            '(o de galleta) con gato y llave, o bien un kit antipinchazos '
            'cuando el fabricante lo sustituye. Conviene revisar su presion '
            'periodicamente.',
        example:
            'Si llevas rueda de galleta, su velocidad maxima suele estar '
            'limitada a 80 km/h y solo debe usarse hasta el taller.',
      ),
      DgtConcept(
        title: 'Documentos obligatorios',
        body:
            'Hay que llevar permiso de conducir en vigor, permiso de '
            'circulacion, ficha tecnica (tarjeta ITV) y justificante del '
            'seguro obligatorio. Pueden presentarse en formato digital '
            'cuando la normativa lo admite.',
        example:
            'En un control, no poder acreditar el permiso de circulacion '
            'del vehiculo es una infraccion sancionable.',
      ),
      DgtConcept(
        title: 'Extintor (cuando aplica)',
        body:
            'El turismo particular no esta obligado a llevar extintor, pero '
            'si lo estan determinados vehiculos como autobuses, camiones, '
            'transporte de mercancias peligrosas y vehiculos de mas de 3.500 '
            'kg, segun su reglamentacion.',
        example:
            'Un camion de transporte de mercancias peligrosas (ADR) debe '
            'llevar extintores revisados y en vigor; un turismo no.',
      ),
    ],
  ),
];
