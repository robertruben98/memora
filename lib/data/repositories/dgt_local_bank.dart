import 'dgt_repository.dart';

/// Banco minimo de preguntas DGT permiso B usado como fallback cuando
/// el backend aun no expone GET /dgt/questions. Fuente: temario oficial
/// DGT.es 2026 (Reglamento General de Circulacion, Ley Trafico, etc).
const List<DgtQuestion> dgtLocalBank = [
  DgtQuestion(
    id: 'local-1',
    statement:
        'Al circular por una via interurbana, la velocidad maxima generica '
        'para un turismo es:',
    optionA: '90 km/h',
    optionB: '100 km/h',
    optionC: '120 km/h',
    correct: 'a',
    explanation:
        'En carretera convencional, el limite generico para turismos es '
        '90 km/h (Reglamento General de Circulacion, art. 48).',
    topic: 'Velocidades',
  ),
  DgtQuestion(
    id: 'local-2',
    statement:
        'La distancia minima lateral al adelantar a un ciclista en via '
        'interurbana es:',
    optionA: '1 metro',
    optionB: '1,5 metros',
    optionC: '2 metros',
    correct: 'b',
    explanation:
        'La separacion lateral minima al adelantar ciclistas es de '
        '1,5 m, reduciendo velocidad al menos 20 km/h sobre lo permitido.',
    topic: 'Adelantamiento',
  ),
  DgtQuestion(
    id: 'local-3',
    statement:
        'La tasa maxima de alcohol en sangre para un conductor novel es:',
    optionA: '0,5 g/l',
    optionB: '0,3 g/l',
    optionC: '0,0 g/l',
    correct: 'b',
    explanation:
        'Conductores noveles (menos de 2 anos de permiso): 0,3 g/l en '
        'sangre (0,15 mg/l en aire espirado).',
    topic: 'Alcohol y drogas',
  ),
  DgtQuestion(
    id: 'local-4',
    statement: 'Una linea continua amarilla en el borde de la calzada indica:',
    optionA: 'Prohibido aparcar pero permitido parar',
    optionB: 'Prohibido parar y estacionar',
    optionC: 'Carril reservado para autobuses',
    correct: 'b',
    explanation:
        'Linea amarilla continua: prohibida la parada y el estacionamiento.',
    topic: 'Senalizacion',
  ),
  DgtQuestion(
    id: 'local-5',
    statement: 'Antes de iniciar un adelantamiento debe comprobarse que:',
    optionA: 'Ningun vehiculo detras ha iniciado la misma maniobra',
    optionB: 'Solo es necesario mirar hacia adelante',
    optionC: 'El intermitente derecho esta activado',
    correct: 'a',
    explanation:
        'Es obligatorio cerciorarse de que nadie detras inicio el '
        'adelantamiento y de que hay espacio suficiente para reincorporarse.',
    topic: 'Adelantamiento',
  ),
  DgtQuestion(
    id: 'local-6',
    statement: 'En un STOP debe usted:',
    optionA: 'Reducir la velocidad y ceder el paso',
    optionB: 'Detenerse completamente y ceder el paso',
    optionC: 'Pasar si no viene nadie por la derecha',
    correct: 'b',
    explanation:
        'El STOP obliga a detencion total, independientemente de si hay o '
        'no otros vehiculos.',
    topic: 'Senalizacion',
  ),
  DgtQuestion(
    id: 'local-7',
    statement:
        'La distancia de seguridad recomendada con el vehiculo precedente '
        'equivale a:',
    optionA: 'La mitad de la velocidad en metros',
    optionB: 'El tiempo de reaccion de 2 segundos',
    optionC: 'Siempre 10 metros',
    correct: 'b',
    explanation:
        'La regla de los 2 segundos cubre el tiempo de reaccion medio del '
        'conductor.',
    topic: 'Seguridad activa',
  ),
  DgtQuestion(
    id: 'local-8',
    statement: 'Un peaton tiene preferencia sobre un vehiculo cuando:',
    optionA: 'Cruza por un paso de peatones',
    optionB: 'Cruza por cualquier sitio',
    optionC: 'Camina por la calzada',
    correct: 'a',
    explanation:
        'El peaton tiene prioridad solo en pasos de peatones senalizados '
        'y en aceras.',
    topic: 'Peatones',
  ),
  DgtQuestion(
    id: 'local-9',
    statement: 'En una glorieta, la prioridad la tienen los vehiculos que:',
    optionA: 'Van a entrar',
    optionB: 'Ya circulan por ella',
    optionC: 'Van a salir por la derecha',
    correct: 'b',
    explanation:
        'En las glorietas tienen prioridad los vehiculos que ya circulan '
        'por el anillo.',
    topic: 'Intersecciones',
  ),
  DgtQuestion(
    id: 'local-10',
    statement: 'El uso del cinturon de seguridad en asientos traseros es:',
    optionA: 'Recomendado',
    optionB: 'Obligatorio si el vehiculo lo lleva instalado',
    optionC: 'Solo obligatorio en autopista',
    correct: 'b',
    explanation:
        'El cinturon es obligatorio en todos los asientos en los que se '
        'haya instalado por fabrica.',
    topic: 'Seguridad activa',
  ),
  DgtQuestion(
    id: 'local-11',
    statement: 'La luz de cruce (corta) es obligatoria entre:',
    optionA: 'El amanecer y el ocaso',
    optionB: 'El ocaso y el amanecer y en tuneles',
    optionC: 'Solo en autopistas de noche',
    correct: 'b',
    explanation:
        'La luz de cruce es obligatoria desde el ocaso hasta el amanecer, '
        'en tuneles, pasos inferiores y condiciones de baja visibilidad.',
    topic: 'Alumbrado',
  ),
  DgtQuestion(
    id: 'local-12',
    statement: 'El triangulo invertido sin texto significa:',
    optionA: 'STOP',
    optionB: 'Ceda el paso',
    optionC: 'Calzada deslizante',
    correct: 'b',
    explanation:
        'Triangulo invertido (P-4 / R-1): ceda el paso al trafico de la '
        'via a la que se accede.',
    topic: 'Senalizacion',
  ),
  DgtQuestion(
    id: 'local-13',
    statement: 'En autopista la velocidad maxima generica para turismos es:',
    optionA: '110 km/h',
    optionB: '120 km/h',
    optionC: '130 km/h',
    correct: 'b',
    explanation:
        'Limite generico en autopista/autovia para turismos: 120 km/h.',
    topic: 'Velocidades',
  ),
  DgtQuestion(
    id: 'local-14',
    statement: 'La ITV de un turismo nuevo de uso privado se realiza:',
    optionA: 'A los 2 anos',
    optionB: 'A los 4 anos',
    optionC: 'A los 6 anos',
    correct: 'b',
    explanation:
        'Primera ITV de un turismo particular: a los 4 anos desde la '
        'matriculacion.',
    topic: 'Vehiculo',
  ),
  DgtQuestion(
    id: 'local-15',
    statement: 'Ante una ambulancia con sirena por detras debo:',
    optionA: 'Acelerar para apartarme rapido',
    optionB: 'Facilitar el paso aproximandome al borde derecho',
    optionC: 'Detenerme en mitad del carril',
    correct: 'b',
    explanation:
        'Hay que facilitar el paso a vehiculos prioritarios sin maniobras '
        'bruscas, aproximandose al borde derecho.',
    topic: 'Prioridad',
  ),
  DgtQuestion(
    id: 'local-16',
    statement: 'Los neumaticos deben tener una profundidad minima de:',
    optionA: '1,6 mm',
    optionB: '2,5 mm',
    optionC: '4 mm',
    correct: 'a',
    explanation:
        'La profundidad minima legal del dibujo del neumatico es '
        '1,6 mm en toda la banda de rodadura principal.',
    topic: 'Vehiculo',
  ),
  DgtQuestion(
    id: 'local-17',
    statement: 'El uso del telefono movil al volante:',
    optionA: 'Esta permitido si se usa manos libres con auriculares',
    optionB: 'Solo esta permitido sin auriculares y manos libres integrado',
    optionC: 'Esta permitido si la llamada es corta',
    correct: 'b',
    explanation:
        'Solo se permite manos libres siempre que no implique uso de '
        'cascos o auriculares.',
    topic: 'Distracciones',
  ),
  DgtQuestion(
    id: 'local-18',
    statement: 'En una via con dos carriles por sentido, debe circular:',
    optionA: 'Por el carril que prefiera',
    optionB: 'Por el de la derecha, salvo para adelantar',
    optionC: 'Por el del centro',
    correct: 'b',
    explanation:
        'Norma general: circular por el carril situado mas a la derecha, '
        'usando los otros solo para adelantar o cambiar de direccion.',
    topic: 'Circulacion',
  ),
  DgtQuestion(
    id: 'local-19',
    statement:
        'La senal de prohibido el paso (circular con fondo blanco y aspa) '
        'prohibe:',
    optionA: 'Solo a vehiculos pesados',
    optionB: 'A todo tipo de vehiculos',
    optionC: 'Solo en horario nocturno',
    correct: 'b',
    explanation:
        'La senal R-100 prohibe la entrada a toda clase de vehiculos.',
    topic: 'Senalizacion',
  ),
  DgtQuestion(
    id: 'local-20',
    statement: 'Si me encuentro con una linea continua blanca puedo:',
    optionA: 'Cruzarla para adelantar',
    optionB: 'No cruzarla salvo causa justificada',
    optionC: 'Cruzarla si no viene nadie',
    correct: 'b',
    explanation:
        'La linea continua no debe cruzarse salvo casos justificados '
        '(emergencia, obstaculo).',
    topic: 'Senalizacion',
  ),
  DgtQuestion(
    id: 'local-21',
    statement: 'El permiso B permite conducir vehiculos de hasta:',
    optionA: '3.500 kg de MMA',
    optionB: '4.250 kg de MMA',
    optionC: '5.000 kg de MMA',
    correct: 'a',
    explanation:
        'Permiso B: vehiculos hasta 3.500 kg de MMA y hasta 9 plazas '
        'incluido conductor.',
    topic: 'Permisos',
  ),
  DgtQuestion(
    id: 'local-22',
    statement: 'En caso de accidente con heridos, lo primero que debe hacer es:',
    optionA: 'Mover a los heridos para liberar la via',
    optionB: 'Proteger el lugar y avisar a emergencias',
    optionC: 'Tomar fotos de los danos',
    correct: 'b',
    explanation:
        'Protocolo PAS: Proteger, Avisar (112), Socorrer. Nunca mover '
        'heridos salvo riesgo vital.',
    topic: 'Accidentes',
  ),
  DgtQuestion(
    id: 'local-23',
    statement: 'En carretera con niebla densa debo:',
    optionA: 'Encender luces largas para ver mejor',
    optionB: 'Encender luces de cruce y antiniebla',
    optionC: 'Apagar las luces para no deslumbrar',
    correct: 'b',
    explanation:
        'Las largas producen una pantalla blanca por reflexion. Usar '
        'cruce y antiniebla delantera (y trasera si la visibilidad es muy '
        'reducida).',
    topic: 'Alumbrado',
  ),
  DgtQuestion(
    id: 'local-24',
    statement: 'Esta prohibido el estacionamiento de un vehiculo en:',
    optionA: 'Aparcamientos delimitados con linea blanca',
    optionB: 'Pasos de peatones y a menos de 5 m de una interseccion',
    optionC: 'Zonas azules pagando el ticket',
    correct: 'b',
    explanation:
        'No se puede estacionar en pasos de peatones, ciclistas, ni a '
        'menos de 5 m de una interseccion.',
    topic: 'Estacionamiento',
  ),
  DgtQuestion(
    id: 'local-25',
    statement: 'El permiso de conducir B tiene una vigencia inicial de:',
    optionA: '5 anos',
    optionB: '10 anos hasta los 65',
    optionC: 'Indefinida',
    correct: 'b',
    explanation:
        'Permiso B: 10 anos hasta los 65 anos; despues, renovacion cada '
        '5 anos.',
    topic: 'Permisos',
  ),
  DgtQuestion(
    id: 'local-26',
    statement: 'En un paso a nivel sin barreras debo:',
    optionA: 'Detenerme siempre y mirar a ambos lados',
    optionB: 'Pasar a velocidad alta para librarlo rapido',
    optionC: 'No detenerme si las luces estan apagadas',
    correct: 'a',
    explanation:
        'En pasos a nivel sin barreras debe extremarse la precaucion, '
        'reduciendo y mirando antes de cruzar.',
    topic: 'Intersecciones',
  ),
  DgtQuestion(
    id: 'local-27',
    statement: 'Una glorieta turbo se caracteriza por:',
    optionA: 'No tener prioridad definida',
    optionB: 'Carriles que dirigen al conductor a la salida correcta',
    optionC: 'Permitir adelantar por la derecha siempre',
    correct: 'b',
    explanation:
        'La glorieta turbo guia con carriles separados a cada salida, '
        'reduciendo conflictos en la circulacion interna.',
    topic: 'Intersecciones',
  ),
  DgtQuestion(
    id: 'local-28',
    statement: 'La sancion por conducir sin cinturon en via interurbana es:',
    optionA: '80 euros sin retirada de puntos',
    optionB: '200 euros y retirada de 3 puntos',
    optionC: '500 euros y retirada de 6 puntos',
    correct: 'b',
    explanation:
        'Conducir sin cinturon o sistema de retencion infantil: 200 euros '
        'y 3 puntos.',
    topic: 'Sanciones',
  ),
  DgtQuestion(
    id: 'local-29',
    statement:
        'Frente a un ciclista que circula por arcen estrecho, debo:',
    optionA: 'Tocar el claxon para que se aparte',
    optionB: 'Reducir velocidad y mantener separacion lateral de 1,5 m',
    optionC: 'Adelantar sin separacion, ya esta en el arcen',
    correct: 'b',
    explanation:
        'Aunque circule por arcen, se mantiene la regla de 1,5 m de '
        'separacion lateral al adelantar.',
    topic: 'Adelantamiento',
  ),
  DgtQuestion(
    id: 'local-30',
    statement: 'El sistema ABS sirve para:',
    optionA: 'Reducir el consumo de combustible',
    optionB: 'Evitar el bloqueo de las ruedas al frenar fuerte',
    optionC: 'Mejorar la potencia del motor',
    correct: 'b',
    explanation:
        'El ABS (Antilock Braking System) impide el bloqueo de las ruedas '
        'durante una frenada brusca, manteniendo el control direccional.',
    topic: 'Vehiculo',
  ),
];
