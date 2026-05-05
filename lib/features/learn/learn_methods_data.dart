// Catálogo curado de métodos de aprendizaje.
import 'package:flutter/material.dart';

class LearnCategory {
  final String title;
  final String emoji;
  final Color accent;
  final List<LearnMethod> methods;

  const LearnCategory({
    required this.title,
    required this.emoji,
    required this.accent,
    required this.methods,
  });
}

class LearnMethod {
  final String name;
  final String emoji;
  final String tagline;
  final String body;
  final String? source;
  final String? memoraNote;
  final EvidenceLevel evidence;

  const LearnMethod({
    required this.name,
    required this.emoji,
    required this.tagline,
    required this.body,
    required this.evidence,
    this.source,
    this.memoraNote,
  });
}

enum EvidenceLevel {
  high('Evidencia alta', Color(0xFF4FFFB0)),
  medium('Evidencia moderada', Color(0xFFFFD24F)),
  low('Tradicional', Color(0xFF7C5CFF)),
  myth('Mito desmentido', Color(0xFFFF4F6B));

  final String label;
  final Color color;
  const EvidenceLevel(this.label, this.color);
}

const learnCategories = <LearnCategory>[
  // ========== 1. Cómo funciona la memoria ==========
  LearnCategory(
    title: 'Cómo funciona la memoria',
    emoji: '🧠',
    accent: Color(0xFF7C5CFF),
    methods: [
      LearnMethod(
        name: 'Curva del olvido',
        emoji: '📉',
        tagline: 'Sin repaso, olvidas el 70% en 24h. Es exponencial.',
        body:
            'Hermann Ebbinghaus (1885) descubrió que la memoria decae '
            'exponencialmente. Recordamos el ~100% justo después de '
            'aprender, ~58% una hora después y solo ~33% al día siguiente.\n\n'
            'Cada vez que repasas justo antes de olvidar, la curva se '
            'aplana: la próxima vez tardas más en olvidar. Es la base '
            'matemática de todo SRS.',
        source: 'Ebbinghaus 1885',
        evidence: EvidenceLevel.high,
        memoraNote:
            'Memora calcula el "next review date" para que veas la '
            'tarjeta justo antes de que la olvides.',
      ),
      LearnMethod(
        name: 'Repetición espaciada (SRS)',
        emoji: '⏳',
        tagline: 'Repasos en intervalos crecientes son ~2x más eficientes '
            'que masivos.',
        body:
            'En vez de estudiar 10 veces seguidas (cramming), espacias '
            'los repasos: día 1, día 3, día 7, día 17… Los intervalos se '
            'expanden cada vez que aciertas y se reinician si fallas.\n\n'
            'Algoritmos: SM-2 (Anki, Memora actual), FSRS (más moderno, '
            'usa ML para predecir tu olvido individual).',
        source: 'Pimsleur 1967, Wozniak 1990',
        evidence: EvidenceLevel.high,
        memoraNote:
            'Memora usa SM-2 con quality binario (Acerté=4, No acerté=1). '
            'Curva: 1d → 6d → 15d → 38d → 95d con ease 2.5.',
      ),
      LearnMethod(
        name: 'Active Recall (Testing Effect)',
        emoji: '🎯',
        tagline: 'Producir la respuesta de memoria > releer apuntes.',
        body:
            'Roediger & Karpicke (2006): tras leer un texto, hacer un '
            'test fue 2x más eficaz para retener una semana después que '
            'releer. El esfuerzo de recuperar la info la fija en la '
            'memoria a largo plazo.\n\n'
            'Por eso un test es estudiar — no solo medir.',
        source: 'Roediger & Karpicke 2006',
        evidence: EvidenceLevel.high,
        memoraNote:
            'Cada vez que ves "front" y dices la respuesta antes de '
            'revelar, estás haciendo active recall.',
      ),
      LearnMethod(
        name: 'Interleaving (intercalado)',
        emoji: '🔀',
        tagline: 'Mezclar temas en una sesión > estudiar bloques cerrados.',
        body:
            'Estudiar A,A,A,B,B,B,C,C,C parece más eficiente pero rinde '
            'peor que A,B,C,A,B,C,A,B,C en pruebas posteriores. La mezcla '
            'fuerza al cerebro a discriminar entre conceptos similares.\n\n'
            'Especialmente potente en matemáticas, idiomas y categorías '
            'visuales.',
        source: 'Rohrer & Taylor 2007',
        evidence: EvidenceLevel.high,
        memoraNote:
            'El modo "Estudiar todo" mezcla tarjetas de todos tus mazos. '
            'Lo verás más difícil al principio — eso es lo que toca.',
      ),
      LearnMethod(
        name: 'Distributed Practice',
        emoji: '📅',
        tagline: '20 min al día > 2 horas el domingo.',
        body:
            'Cepeda et al (2008, meta-análisis de 254 estudios): la '
            'misma cantidad de tiempo distribuida en sesiones cortas '
            'separadas produce mejor retención que masiva.\n\n'
            'Regla: cuanto más tarde quieras recordar algo, más espaciados '
            'tus repasos.',
        source: 'Cepeda et al 2008',
        evidence: EvidenceLevel.high,
        memoraNote:
            'La quest diaria de Memora te empuja a sesiones cortas y '
            'frecuentes. La racha refuerza el hábito.',
      ),
      LearnMethod(
        name: 'Generation Effect',
        emoji: '✍️',
        tagline: 'Generar la respuesta tú es mejor que verla escrita.',
        body:
            'Slamecka & Graf (1978): si lees "frío - caliente" recordarás '
            'menos que si te dan "frío - c___" y completas.\n\n'
            'Forzarte a producir activa redes cerebrales que solo leer '
            'no toca.',
        source: 'Slamecka & Graf 1978',
        evidence: EvidenceLevel.high,
        memoraNote:
            'Cuando intentas recordar la respuesta antes de pulsar "Ver '
            'respuesta", estás generando. No mires por reflejo — espera.',
      ),
    ],
  ),

  // ========== 2. Sesión de estudio ==========
  LearnCategory(
    title: 'En cada sesión',
    emoji: '⏱️',
    accent: Color(0xFFFF8A4F),
    methods: [
      LearnMethod(
        name: 'Pomodoro',
        emoji: '🍅',
        tagline: '25 min foco + 5 min descanso. Repite 4. Pausa larga.',
        body:
            'Francesco Cirillo, años 80. La fricción de empezar se reduce '
            'a "solo 25 minutos". Las pausas evitan fatiga mental.\n\n'
            'Variaciones: 50/10 (Deep Work), 90 min (ciclos ultradianos).',
        source: 'Cirillo 1980s',
        evidence: EvidenceLevel.medium,
      ),
      LearnMethod(
        name: 'Deep Work',
        emoji: '🎧',
        tagline: 'Bloques largos sin notificaciones ni cambios de tarea.',
        body:
            'Cal Newport: el cambio de contexto es caro (residue cognitivo). '
            'Una sesión de 2h sin móvil produce más que 4h fragmentadas.\n\n'
            'Pre-requisito: silenciar notificaciones, cerrar pestañas, modo '
            'avión si hace falta.',
        source: 'Newport 2016',
        evidence: EvidenceLevel.medium,
      ),
      LearnMethod(
        name: 'Deliberate Practice',
        emoji: '🎯',
        tagline: 'Práctica con objetivo concreto + feedback inmediato.',
        body:
            'Anders Ericsson: lo que distingue a un experto no son las '
            'horas totales, sino las horas de práctica deliberada — '
            'siempre en el límite de tu habilidad, con feedback rápido '
            'y enfoque en corregir errores específicos.\n\n'
            'No es "tocar la guitarra una hora": es "tocar este compás '
            'difícil 50 veces hasta que salga limpio".',
        source: 'Ericsson 1993',
        evidence: EvidenceLevel.high,
        memoraNote:
            'En Memora: mira tu retención, identifica los mazos con '
            'menor % acierto, dedícales más sesiones cortas.',
      ),
      LearnMethod(
        name: 'Pareto / Regla 80-20',
        emoji: '🔑',
        tagline: '20% del contenido te da el 80% del valor.',
        body:
            'No todo el material vale lo mismo. En idiomas, las 1000 '
            'palabras más frecuentes cubren el 80% del habla. En '
            'programación, dominar arrays/maps/recursión cubre el 80% '
            'de problemas comunes.\n\n'
            'Empieza por lo de mayor frecuencia/utilidad. Lo raro lo '
            'aprendes después.',
        evidence: EvidenceLevel.medium,
      ),
    ],
  ),

  // ========== 3. Mnemónicas ==========
  LearnCategory(
    title: 'Técnicas mnemónicas',
    emoji: '🏛️',
    accent: Color(0xFFE04FFF),
    methods: [
      LearnMethod(
        name: 'Method of Loci (Palacio de la memoria)',
        emoji: '🏰',
        tagline: 'Asocias items con lugares de un sitio que conoces bien.',
        body:
            'Cicerón ya lo usaba en el siglo I a.C. Recorres mentalmente '
            'tu casa colocando una imagen vívida de cada cosa que quieres '
            'recordar en cada habitación.\n\n'
            'Los actuales campeones mundiales de memoria lo usan para '
            'memorizar miles de dígitos o el orden de una baraja.',
        source: 'Cicerón, De Oratore',
        evidence: EvidenceLevel.high,
      ),
      LearnMethod(
        name: 'Chunking (agrupar)',
        emoji: '🧩',
        tagline: 'La memoria de trabajo guarda ~7 ítems. Agrupa para entrar más.',
        body:
            'Miller (1956): "The magical number seven plus or minus two". '
            '5551234 cuesta más que 555-12-34. Un experto de ajedrez no '
            'memoriza 32 piezas: ve 5-6 patrones (estructuras de peones, '
            'baterías, etc).\n\n'
            'Aprender = ir agrupando piezas pequeñas en bloques más '
            'grandes y significativos.',
        source: 'Miller 1956',
        evidence: EvidenceLevel.high,
      ),
      LearnMethod(
        name: 'Mnemónicos / acrónimos',
        emoji: '🔤',
        tagline: 'Reduces info a una palabra que recuerdas fácil.',
        body:
            'PEMDAS para orden de operaciones, NEWS para los puntos '
            'cardinales, "MRS GREN" para las características de seres '
            'vivos.\n\n'
            'Funciona porque conviertes algo abstracto en un gancho '
            'fonético memorable.',
        evidence: EvidenceLevel.medium,
      ),
      LearnMethod(
        name: 'Dual Coding',
        emoji: '🖼️',
        tagline: 'Texto + imagen activa 2 redes neurales = doble retención.',
        body:
            'Allan Paivio (1971): la información codificada en palabras '
            'Y en imágenes se recuerda mejor que solo en uno.\n\n'
            'Por eso los esquemas, diagramas y mapas mentales funcionan. '
            'Y por qué las flashcards con imagen retienen más.',
        source: 'Paivio 1971',
        evidence: EvidenceLevel.high,
        memoraNote:
            'Añade imágenes a tus tarjetas (botón "Añadir imagen" en el '
            'editor). Especialmente útil en idiomas, anatomía y mapas.',
      ),
      LearnMethod(
        name: 'Cloze deletion',
        emoji: '🕳️',
        tagline: 'Frases con huecos: "París es la capital de ___"',
        body:
            'Tarjeta donde escondes una palabra clave en una oración con '
            'contexto. Mantienes la frase entera (que da pistas '
            'gramaticales y semánticas) pero te fuerzas a recordar el '
            'núcleo.\n\n'
            'Especialmente fuerte para idiomas y conceptos definicionales.',
        evidence: EvidenceLevel.high,
      ),
    ],
  ),

  // ========== 4. Comprensión profunda ==========
  LearnCategory(
    title: 'Comprensión profunda',
    emoji: '💡',
    accent: Color(0xFF4FFFB0),
    methods: [
      LearnMethod(
        name: 'Técnica Feynman',
        emoji: '👨‍🏫',
        tagline: 'Explica el tema como si enseñaras a un niño.',
        body:
            '4 pasos:\n'
            '1. Elige un concepto y escríbelo en lo alto de una hoja.\n'
            '2. Explícalo en lenguaje sencillo, sin jerga.\n'
            '3. Identifica lo que no sabes explicar — ese es el agujero.\n'
            '4. Vuelve a la fuente, aprende esa parte, simplifica más.\n\n'
            'Si no puedes explicarlo simple, no lo entiendes.',
        source: 'Richard Feynman',
        evidence: EvidenceLevel.medium,
      ),
      LearnMethod(
        name: 'Self-explanation',
        emoji: '🤔',
        tagline: 'Cuéntate a ti mismo por qué cada paso es cierto.',
        body:
            'Chi (1989): los estudiantes que se autoexplicaban mientras '
            'leían (¿por qué este paso? ¿cómo conecta con lo anterior?) '
            'aprendían significativamente más.\n\n'
            'Activamente, no como mera lectura.',
        source: 'Chi 1989',
        evidence: EvidenceLevel.high,
      ),
      LearnMethod(
        name: 'Protégé effect',
        emoji: '🎓',
        tagline: 'Enseñar a alguien (o a una IA) consolida tu memoria.',
        body:
            'Estudios con "teachable agents" (programas tutorables) '
            'muestran que el rol de profesor produce mejor retención '
            'que el rol de estudiante. Tienes que organizar la info '
            'para que alguien más la entienda.\n\n'
            'Truco práctico: explícale a un chat de IA o a un amigo '
            'lo que estás aprendiendo.',
        source: 'Bargh & Schul 1980',
        evidence: EvidenceLevel.medium,
      ),
      LearnMethod(
        name: 'Elaborative interrogation',
        emoji: '❓',
        tagline: 'Pregúntate "¿por qué?" y "¿cómo?" mientras estudias.',
        body:
            'Pressley et al (1992): añadir "¿por qué tiene sentido esto?" '
            'a cada hecho que aprendes lo conecta con lo que ya sabes y '
            'lo hace memorable.\n\n'
            'Convierte hechos aislados en una red.',
        source: 'Pressley 1992',
        evidence: EvidenceLevel.high,
      ),
      LearnMethod(
        name: 'Bloom\'s Taxonomy',
        emoji: '🪜',
        tagline: 'Niveles cognitivos: recordar < entender < aplicar < crear.',
        body:
            'Benjamin Bloom (1956). Una jerarquía:\n'
            '1. Recordar (lista de palabras)\n'
            '2. Entender (explicar con tus palabras)\n'
            '3. Aplicar (usar en problema nuevo)\n'
            '4. Analizar (dividir en partes y relacionarlas)\n'
            '5. Evaluar (juzgar mérito)\n'
            '6. Crear (componer algo original)\n\n'
            'Si quieres dominar algo, sube los escalones — no te quedes '
            'en recordar.',
        source: 'Bloom 1956',
        evidence: EvidenceLevel.medium,
      ),
    ],
  ),

  // ========== 5. Sistemas SRS modernos ==========
  LearnCategory(
    title: 'Algoritmos modernos',
    emoji: '🤖',
    accent: Color(0xFF4F8AFF),
    methods: [
      LearnMethod(
        name: 'SM-2',
        emoji: '⚙️',
        tagline: 'El clásico de SuperMemo y Anki.',
        body:
            'Wozniak 1990. Cada tarjeta tiene un "ease factor" (default '
            '2.5) y se programa según calidad de respuesta:\n'
            '- Acierto: nuevo intervalo = anterior × ease\n'
            '- Fallo: reset a 1 día, ease baja\n\n'
            'Simple, robusto, base de la mayoría de apps de SRS.',
        source: 'Wozniak 1990',
        evidence: EvidenceLevel.high,
        memoraNote: 'Es lo que usa Memora actualmente.',
      ),
      LearnMethod(
        name: 'FSRS',
        emoji: '🧬',
        tagline: 'Free Spaced Repetition Scheduler. Modelo ML.',
        body:
            'Modelo de 3 parámetros (stability, difficulty, retrievability) '
            'entrenado con tu historial real. Más preciso al programar '
            'repasos; reduce overlearning y subaprovechamiento.\n\n'
            'Hoy es el algoritmo recomendado oficialmente en Anki.',
        source: 'Ye Jiarui 2022',
        evidence: EvidenceLevel.high,
        memoraNote:
            'Posible upgrade futuro de Memora — sustituye SM-2 sin '
            'romper interfaz.',
      ),
      LearnMethod(
        name: 'Sistema Leitner',
        emoji: '📦',
        tagline: 'El abuelo de los SRS, físico, con 5 cajas.',
        body:
            'Sebastian Leitner 1972. Cinco cajas: caja 1 = repasar diario, '
            '2 = cada 3 días, 3 = semanal, 4 = quincenal, 5 = mensual. Si '
            'aciertas avanzas; si fallas vuelves a la 1.\n\n'
            'Mucho más burdo que SM-2 pero ilustra la idea de manera '
            'tangible.',
        source: 'Leitner 1972',
        evidence: EvidenceLevel.medium,
      ),
    ],
  ),

  // ========== 6. Mitos ==========
  LearnCategory(
    title: 'Mitos a evitar',
    emoji: '⚠️',
    accent: Color(0xFFFF4F6B),
    methods: [
      LearnMethod(
        name: 'Estilos de aprendizaje (VARK)',
        emoji: '🚫',
        tagline: '"Soy visual" / "soy auditivo": no hay evidencia.',
        body:
            'La idea de que cada persona aprende mejor en un canal '
            '(visual, auditivo, kinestésico…) ha sido desmentida en '
            'múltiples meta-análisis.\n\n'
            'Lo que importa es la naturaleza del contenido, no del '
            'estudiante. Geografía → mapa. Pronunciación → audio. '
            'Anatomía → imagen. Eso para todos.',
        source: 'Pashler et al 2008 (revisión)',
        evidence: EvidenceLevel.myth,
      ),
      LearnMethod(
        name: 'Releer y subrayar como técnica principal',
        emoji: '🖍️',
        tagline: 'Da sensación de aprender; produce muy poco aprendizaje.',
        body:
            'Dunlosky et al (2013) clasificaron 10 técnicas de estudio. '
            'Releer y subrayar quedaron en lo más bajo de eficacia. La '
            'fluidez al releer (que reconozcas las palabras) crea la '
            '"ilusión de competencia": crees que sabes pero no podrías '
            'reproducirlo.\n\n'
            'Lo eficaz: cerrar el libro y testarte.',
        source: 'Dunlosky 2013',
        evidence: EvidenceLevel.myth,
      ),
      LearnMethod(
        name: 'Cramming la noche antes',
        emoji: '🌙',
        tagline: 'Funciona para el examen. Olvidas todo en una semana.',
        body:
            'Estudiar masivo te da memoria a corto plazo pero la '
            'consolidación a largo plazo requiere espaciamiento + sueño. '
            'Cramming = inversión perdida si quieres recordar de aquí '
            'a meses.\n\n'
            'Si igual lo haces para un examen, estudia espaciado los días '
            'anteriores y deja la última noche para repaso ligero + '
            'dormir bien.',
        evidence: EvidenceLevel.myth,
      ),
    ],
  ),
];
