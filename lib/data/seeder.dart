import 'package:drift/drift.dart' show InsertMode, Value;

import 'database/database.dart';

const _seedDecks = [
  _SeedDeck(
    id: 'seed-deck-1',
    name: 'Inglés - Verbos',
    colorHex: '#4F8AFF',
    iconName: 'translate_rounded',
  ),
  _SeedDeck(
    id: 'seed-deck-2',
    name: 'Geografía',
    colorHex: '#FF8A4F',
    iconName: 'public_rounded',
  ),
  _SeedDeck(
    id: 'seed-deck-3',
    name: 'Algoritmos',
    colorHex: '#4FFFB0',
    iconName: 'code_rounded',
  ),
  _SeedDeck(
    id: 'seed-deck-4',
    name: 'Aprendizaje',
    colorHex: '#FFD24F',
    iconName: 'psychology_rounded',
  ),
  _SeedDeck(
    id: 'seed-deck-5',
    name: 'Arte',
    colorHex: '#E04FFF',
    iconName: 'palette_rounded',
  ),
];

const _seedCards = [
  _SeedCard(
    id: 'seed-card-2',
    deckId: 'seed-deck-2',
    front: '¿Cuál es la capital de Mongolia?',
    back: 'Ulán Bator (Ulaanbaatar).',
  ),
  _SeedCard(
    id: 'seed-card-3',
    deckId: 'seed-deck-3',
    front: 'En Big-O, ¿complejidad de búsqueda binaria?',
    back: 'O(log n) — divide el espacio de búsqueda a la mitad en cada paso.',
  ),
  _SeedCard(
    id: 'seed-card-4',
    deckId: 'seed-deck-4',
    front: '¿Qué es la repetición espaciada?',
    back: 'Técnica de aprendizaje que aumenta los intervalos entre repasos de '
        'material ya aprendido para optimizar la memoria a largo plazo.',
  ),
  _SeedCard(
    id: 'seed-card-5',
    deckId: 'seed-deck-5',
    front: '¿Quién pintó "La noche estrellada"?',
    back: 'Vincent van Gogh, en 1889.',
  ),
];

// ---------------------------------------------------------------------------
// Mazos de inglés (idempotentes, se añaden si faltan)
// ---------------------------------------------------------------------------

const _englishDecks = [
  _SeedDeck(
    id: 'seed-en-vocab',
    name: 'Inglés - Vocabulario B2',
    colorHex: '#4F8AFF',
    iconName: 'translate_rounded',
  ),
  _SeedDeck(
    id: 'seed-en-phrasal',
    name: 'Inglés - Phrasal verbs',
    colorHex: '#7C5CFF',
    iconName: 'school_rounded',
  ),
  _SeedDeck(
    id: 'seed-en-expr',
    name: 'Inglés - Expresiones',
    colorHex: '#4FFFE9',
    iconName: 'history_edu_rounded',
  ),
];

const _englishCards = <_SeedCard>[
  // ===== Mazo "Inglés - Verbos" (extension del seed-deck-1) =====
  _SeedCard(
    id: 'seed-card-1',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to thrive"?',
    back: 'Prosperar, florecer. Crecer con vigor.',
  ),
  _SeedCard(
    id: 'seed-en-verb-001',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to overwhelm"?',
    back: 'Abrumar, agobiar, desbordar.',
  ),
  _SeedCard(
    id: 'seed-en-verb-002',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to acknowledge"?',
    back: 'Reconocer (un hecho), admitir; confirmar la recepción de algo.',
  ),
  _SeedCard(
    id: 'seed-en-verb-003',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to undermine"?',
    back: 'Socavar, debilitar (la autoridad, confianza, etc.).',
  ),
  _SeedCard(
    id: 'seed-en-verb-004',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to enhance"?',
    back: 'Mejorar, potenciar, realzar.',
  ),
  _SeedCard(
    id: 'seed-en-verb-005',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to convey"?',
    back: 'Transmitir (un mensaje, idea, sentimiento).',
  ),
  _SeedCard(
    id: 'seed-en-verb-006',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to grasp"?',
    back: 'Agarrar; comprender (una idea).',
  ),
  _SeedCard(
    id: 'seed-en-verb-007',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to ponder"?',
    back: 'Reflexionar, sopesar, meditar sobre algo.',
  ),
  _SeedCard(
    id: 'seed-en-verb-008',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to yield"?',
    back: 'Ceder; producir, dar (rendimiento, frutos).',
  ),
  _SeedCard(
    id: 'seed-en-verb-009',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to encompass"?',
    back: 'Abarcar, englobar.',
  ),
  _SeedCard(
    id: 'seed-en-verb-010',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to entail"?',
    back: 'Implicar, conllevar, suponer.',
  ),
  _SeedCard(
    id: 'seed-en-verb-011',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to dwell on"?',
    back: 'Detenerse en, darle vueltas a (un tema, recuerdo).',
  ),
  _SeedCard(
    id: 'seed-en-verb-012',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to strive"?',
    back: 'Esforzarse, luchar (por conseguir algo).',
  ),
  _SeedCard(
    id: 'seed-en-verb-013',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to discern"?',
    back: 'Discernir, distinguir, percibir con claridad.',
  ),
  _SeedCard(
    id: 'seed-en-verb-014',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to mitigate"?',
    back: 'Mitigar, atenuar, suavizar.',
  ),
  _SeedCard(
    id: 'seed-en-verb-015',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to alleviate"?',
    back: 'Aliviar, calmar (dolor, sufrimiento, problema).',
  ),
  _SeedCard(
    id: 'seed-en-verb-016',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to foster"?',
    back: 'Fomentar, promover, criar (en acogida).',
  ),
  _SeedCard(
    id: 'seed-en-verb-017',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to seize"?',
    back: 'Agarrar, aprovechar (una oportunidad); incautar.',
  ),
  _SeedCard(
    id: 'seed-en-verb-018',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to endorse"?',
    back: 'Respaldar, apoyar, avalar (públicamente).',
  ),
  _SeedCard(
    id: 'seed-en-verb-019',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to outweigh"?',
    back: 'Pesar más que, superar en importancia.',
  ),
  _SeedCard(
    id: 'seed-en-verb-020',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to dwindle"?',
    back: 'Disminuir, menguar progresivamente.',
  ),
  _SeedCard(
    id: 'seed-en-verb-021',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to thrive on"?',
    back: 'Prosperar / crecerse con (algo: presión, retos).',
  ),
  _SeedCard(
    id: 'seed-en-verb-022',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to leverage"?',
    back: 'Aprovechar (un recurso, ventaja) para obtener algo.',
  ),
  _SeedCard(
    id: 'seed-en-verb-023',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to glance"?',
    back: 'Echar un vistazo rápido.',
  ),
  _SeedCard(
    id: 'seed-en-verb-024',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to gaze"?',
    back: 'Mirar fijamente (con admiración o ensimismamiento).',
  ),
  _SeedCard(
    id: 'seed-en-verb-025',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to resemble"?',
    back: 'Parecerse a, asemejarse.',
  ),
  _SeedCard(
    id: 'seed-en-verb-026',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to comply with"?',
    back: 'Cumplir con (normas, requisitos).',
  ),
  _SeedCard(
    id: 'seed-en-verb-027',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to cope with"?',
    back: 'Lidiar con, hacer frente a (situación difícil).',
  ),
  _SeedCard(
    id: 'seed-en-verb-028',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to bring about"?',
    back: 'Provocar, ocasionar, hacer que algo ocurra.',
  ),
  _SeedCard(
    id: 'seed-en-verb-029',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to undertake"?',
    back: 'Emprender, asumir (una tarea, responsabilidad).',
  ),
  _SeedCard(
    id: 'seed-en-verb-030',
    deckId: 'seed-deck-1',
    front: '¿Qué significa "to commend"?',
    back: 'Elogiar, encomiar; recomendar.',
  ),

  // ===== Mazo "Inglés - Vocabulario B2" =====
  _SeedCard(
    id: 'seed-en-vocab-001',
    deckId: 'seed-en-vocab',
    front: '"Cumbersome" significa…',
    back: 'Engorroso, aparatoso, difícil de manejar por su tamaño o complejidad.',
  ),
  _SeedCard(
    id: 'seed-en-vocab-002',
    deckId: 'seed-en-vocab',
    front: '"Dire" significa…',
    back: 'Grave, terrible, extremo (consecuencias dire = consecuencias graves).',
  ),
  _SeedCard(
    id: 'seed-en-vocab-003',
    deckId: 'seed-en-vocab',
    front: '"Quaint" significa…',
    back: 'Pintoresco, peculiar (con encanto antiguo).',
  ),
  _SeedCard(
    id: 'seed-en-vocab-004',
    deckId: 'seed-en-vocab',
    front: '"Daunting" significa…',
    back: 'Intimidante, desalentador (una tarea daunting).',
  ),
  _SeedCard(
    id: 'seed-en-vocab-005',
    deckId: 'seed-en-vocab',
    front: '"Compelling" significa…',
    back: 'Convincente, irresistible, que capta la atención.',
  ),
  _SeedCard(
    id: 'seed-en-vocab-006',
    deckId: 'seed-en-vocab',
    front: '"Resilient" significa…',
    back: 'Resiliente, capaz de recuperarse de adversidades.',
  ),
  _SeedCard(
    id: 'seed-en-vocab-007',
    deckId: 'seed-en-vocab',
    front: '"Ubiquitous" significa…',
    back: 'Omnipresente, que está en todas partes.',
  ),
  _SeedCard(
    id: 'seed-en-vocab-008',
    deckId: 'seed-en-vocab',
    front: '"Mundane" significa…',
    back: 'Mundano, rutinario, anodino.',
  ),
  _SeedCard(
    id: 'seed-en-vocab-009',
    deckId: 'seed-en-vocab',
    front: '"Tedious" significa…',
    back: 'Tedioso, aburrido por ser largo o monótono.',
  ),
  _SeedCard(
    id: 'seed-en-vocab-010',
    deckId: 'seed-en-vocab',
    front: '"Eager" significa…',
    back: 'Ansioso (en sentido positivo), impaciente por hacer algo.',
  ),
  _SeedCard(
    id: 'seed-en-vocab-011',
    deckId: 'seed-en-vocab',
    front: '"Reluctant" significa…',
    back: 'Reacio, poco dispuesto a hacer algo.',
  ),
  _SeedCard(
    id: 'seed-en-vocab-012',
    deckId: 'seed-en-vocab',
    front: '"Blunt" significa…',
    back: 'Sin filo, romo; (persona) directo, sin tacto.',
  ),
  _SeedCard(
    id: 'seed-en-vocab-013',
    deckId: 'seed-en-vocab',
    front: '"Mellow" significa…',
    back: 'Suave, tranquilo, relajado (música, persona, ambiente).',
  ),
  _SeedCard(
    id: 'seed-en-vocab-014',
    deckId: 'seed-en-vocab',
    front: '"Earnest" significa…',
    back: 'Serio, sincero, en serio (con buena intención).',
  ),
  _SeedCard(
    id: 'seed-en-vocab-015',
    deckId: 'seed-en-vocab',
    front: '"Lavish" significa…',
    back: 'Opulento, generoso en exceso, lujoso.',
  ),
  _SeedCard(
    id: 'seed-en-vocab-016',
    deckId: 'seed-en-vocab',
    front: '"Sheer" significa (adjetivo)…',
    back: 'Puro, mero (sheer luck = pura suerte); también: vertical, escarpado.',
  ),
  _SeedCard(
    id: 'seed-en-vocab-017',
    deckId: 'seed-en-vocab',
    front: '"Aloof" significa…',
    back: 'Distante, reservado, frío (en trato).',
  ),
  _SeedCard(
    id: 'seed-en-vocab-018',
    deckId: 'seed-en-vocab',
    front: '"Cautious" significa…',
    back: 'Cauto, prudente, cuidadoso.',
  ),
  _SeedCard(
    id: 'seed-en-vocab-019',
    deckId: 'seed-en-vocab',
    front: '"Sturdy" significa…',
    back: 'Robusto, sólido, resistente.',
  ),
  _SeedCard(
    id: 'seed-en-vocab-020',
    deckId: 'seed-en-vocab',
    front: '"Frail" significa…',
    back: 'Frágil, débil (especialmente persona mayor enferma).',
  ),
  _SeedCard(
    id: 'seed-en-vocab-021',
    deckId: 'seed-en-vocab',
    front: '"Vivid" significa…',
    back: 'Vívido, intenso (recuerdo, color, descripción).',
  ),
  _SeedCard(
    id: 'seed-en-vocab-022',
    deckId: 'seed-en-vocab',
    front: '"Bleak" significa…',
    back: 'Sombrío, desolado, poco prometedor.',
  ),
  _SeedCard(
    id: 'seed-en-vocab-023',
    deckId: 'seed-en-vocab',
    front: '"Lush" significa…',
    back: 'Exuberante, frondoso (vegetación); lujoso.',
  ),
  _SeedCard(
    id: 'seed-en-vocab-024',
    deckId: 'seed-en-vocab',
    front: '"Stark" significa…',
    back: 'Crudo, desnudo, marcado (un contraste stark).',
  ),
  _SeedCard(
    id: 'seed-en-vocab-025',
    deckId: 'seed-en-vocab',
    front: '"Subtle" significa…',
    back: 'Sutil, delicado, no obvio.',
  ),

  // ===== Mazo "Inglés - Phrasal verbs" =====
  _SeedCard(
    id: 'seed-en-phrasal-001',
    deckId: 'seed-en-phrasal',
    front: '"To put off" — significado y ejemplo',
    back: 'Posponer, aplazar.\nE.g. "Don\'t put off your homework."',
  ),
  _SeedCard(
    id: 'seed-en-phrasal-002',
    deckId: 'seed-en-phrasal',
    front: '"To come up with"',
    back: 'Idear, ocurrírsele a uno (una idea, plan).\n'
        'E.g. "She came up with a brilliant idea."',
  ),
  _SeedCard(
    id: 'seed-en-phrasal-003',
    deckId: 'seed-en-phrasal',
    front: '"To look forward to"',
    back: 'Esperar con ilusión (siempre seguido de -ing o sustantivo).\n'
        'E.g. "I look forward to seeing you."',
  ),
  _SeedCard(
    id: 'seed-en-phrasal-004',
    deckId: 'seed-en-phrasal',
    front: '"To break down"',
    back: '1) (máquina) averiarse. 2) (persona) derrumbarse emocionalmente.',
  ),
  _SeedCard(
    id: 'seed-en-phrasal-005',
    deckId: 'seed-en-phrasal',
    front: '"To get along with"',
    back: 'Llevarse bien con alguien.\n'
        'E.g. "I get along with my coworkers."',
  ),
  _SeedCard(
    id: 'seed-en-phrasal-006',
    deckId: 'seed-en-phrasal',
    front: '"To run out of"',
    back: 'Quedarse sin (algo).\nE.g. "We ran out of milk."',
  ),
  _SeedCard(
    id: 'seed-en-phrasal-007',
    deckId: 'seed-en-phrasal',
    front: '"To call off"',
    back: 'Cancelar (un evento, plan).\nE.g. "They called off the meeting."',
  ),
  _SeedCard(
    id: 'seed-en-phrasal-008',
    deckId: 'seed-en-phrasal',
    front: '"To figure out"',
    back: 'Resolver, entender, descifrar (cómo funciona algo).\n'
        'E.g. "I can\'t figure out this puzzle."',
  ),
  _SeedCard(
    id: 'seed-en-phrasal-009',
    deckId: 'seed-en-phrasal',
    front: '"To carry out"',
    back: 'Llevar a cabo, realizar (un plan, investigación).',
  ),
  _SeedCard(
    id: 'seed-en-phrasal-010',
    deckId: 'seed-en-phrasal',
    front: '"To bring up"',
    back: '1) Sacar a relucir (un tema). 2) Criar (a un niño).',
  ),
  _SeedCard(
    id: 'seed-en-phrasal-011',
    deckId: 'seed-en-phrasal',
    front: '"To turn down"',
    back: '1) Rechazar (oferta). 2) Bajar (volumen).',
  ),
  _SeedCard(
    id: 'seed-en-phrasal-012',
    deckId: 'seed-en-phrasal',
    front: '"To give up"',
    back: 'Rendirse, abandonar.\nE.g. "Don\'t give up!"',
  ),
  _SeedCard(
    id: 'seed-en-phrasal-013',
    deckId: 'seed-en-phrasal',
    front: '"To look up"',
    back: 'Buscar (información en diccionario, internet).\n'
        'E.g. "Look it up online."',
  ),
  _SeedCard(
    id: 'seed-en-phrasal-014',
    deckId: 'seed-en-phrasal',
    front: '"To work out"',
    back: '1) Resultar bien, salir bien. 2) Ejercitarse en el gimnasio.',
  ),
  _SeedCard(
    id: 'seed-en-phrasal-015',
    deckId: 'seed-en-phrasal',
    front: '"To pick up"',
    back: '1) Recoger. 2) Aprender (una habilidad de forma informal).',
  ),
  _SeedCard(
    id: 'seed-en-phrasal-016',
    deckId: 'seed-en-phrasal',
    front: '"To hold on"',
    back: 'Esperar (un momento), aguantar.\nE.g. "Hold on, I\'ll be right back."',
  ),
  _SeedCard(
    id: 'seed-en-phrasal-017',
    deckId: 'seed-en-phrasal',
    front: '"To set up"',
    back: 'Montar, configurar, establecer (un negocio, sistema).',
  ),
  _SeedCard(
    id: 'seed-en-phrasal-018',
    deckId: 'seed-en-phrasal',
    front: '"To take after"',
    back: 'Parecerse a (un familiar, en aspecto o carácter).\n'
        'E.g. "She takes after her mother."',
  ),
  _SeedCard(
    id: 'seed-en-phrasal-019',
    deckId: 'seed-en-phrasal',
    front: '"To bring about"',
    back: 'Provocar, ocasionar (un cambio, efecto).',
  ),
  _SeedCard(
    id: 'seed-en-phrasal-020',
    deckId: 'seed-en-phrasal',
    front: '"To go through"',
    back: '1) Pasar por (una experiencia difícil). 2) Revisar (documentos).',
  ),
  _SeedCard(
    id: 'seed-en-phrasal-021',
    deckId: 'seed-en-phrasal',
    front: '"To put up with"',
    back: 'Aguantar, soportar (algo molesto).\n'
        'E.g. "I can\'t put up with the noise."',
  ),
  _SeedCard(
    id: 'seed-en-phrasal-022',
    deckId: 'seed-en-phrasal',
    front: '"To run into"',
    back: 'Encontrarse por casualidad con alguien.\n'
        'E.g. "I ran into Tom yesterday."',
  ),
  _SeedCard(
    id: 'seed-en-phrasal-023',
    deckId: 'seed-en-phrasal',
    front: '"To come across"',
    back: 'Toparse con (encontrar por casualidad — algo o alguien).',
  ),
  _SeedCard(
    id: 'seed-en-phrasal-024',
    deckId: 'seed-en-phrasal',
    front: '"To make up"',
    back: '1) Inventar (excusa). 2) Reconciliarse. 3) Maquillarse.',
  ),
  _SeedCard(
    id: 'seed-en-phrasal-025',
    deckId: 'seed-en-phrasal',
    front: '"To take over"',
    back: 'Tomar el control, hacerse cargo (de empresa, tarea).',
  ),

  // ===== Mazo "Inglés - Expresiones" =====
  _SeedCard(
    id: 'seed-en-expr-001',
    deckId: 'seed-en-expr',
    front: '"It\'s a piece of cake"',
    back: 'Es pan comido / muy fácil.',
  ),
  _SeedCard(
    id: 'seed-en-expr-002',
    deckId: 'seed-en-expr',
    front: '"Break a leg"',
    back: '¡Mucha suerte! (especialmente antes de actuar; "rómpete una pierna").',
  ),
  _SeedCard(
    id: 'seed-en-expr-003',
    deckId: 'seed-en-expr',
    front: '"Hit the nail on the head"',
    back: 'Dar en el clavo, acertar exactamente.',
  ),
  _SeedCard(
    id: 'seed-en-expr-004',
    deckId: 'seed-en-expr',
    front: '"Once in a blue moon"',
    back: 'Muy de vez en cuando, raras veces.',
  ),
  _SeedCard(
    id: 'seed-en-expr-005',
    deckId: 'seed-en-expr',
    front: '"To cost an arm and a leg"',
    back: 'Costar un riñón, ser carísimo.',
  ),
  _SeedCard(
    id: 'seed-en-expr-006',
    deckId: 'seed-en-expr',
    front: '"To be on the same page"',
    back: 'Estar de acuerdo, en la misma sintonía.',
  ),
  _SeedCard(
    id: 'seed-en-expr-007',
    deckId: 'seed-en-expr',
    front: '"The ball is in your court"',
    back: 'Es tu turno, te toca a ti decidir.',
  ),
  _SeedCard(
    id: 'seed-en-expr-008',
    deckId: 'seed-en-expr',
    front: '"To beat around the bush"',
    back: 'Andarse con rodeos, no ir al grano.',
  ),
  _SeedCard(
    id: 'seed-en-expr-009',
    deckId: 'seed-en-expr',
    front: '"Spill the beans"',
    back: 'Soltar la sopa, revelar un secreto.',
  ),
  _SeedCard(
    id: 'seed-en-expr-010',
    deckId: 'seed-en-expr',
    front: '"Bite the bullet"',
    back: 'Tragar saliva, hacer algo desagradable inevitable.',
  ),
  _SeedCard(
    id: 'seed-en-expr-011',
    deckId: 'seed-en-expr',
    front: '"To cut corners"',
    back: 'Tomar atajos / hacer chapuzas para ahorrar tiempo o dinero.',
  ),
  _SeedCard(
    id: 'seed-en-expr-012',
    deckId: 'seed-en-expr',
    front: '"Out of the blue"',
    back: 'De la nada, de repente, sin previo aviso.',
  ),
  _SeedCard(
    id: 'seed-en-expr-013',
    deckId: 'seed-en-expr',
    front: '"To have a chip on one\'s shoulder"',
    back: 'Tener un resentimiento, estar a la defensiva.',
  ),
  _SeedCard(
    id: 'seed-en-expr-014',
    deckId: 'seed-en-expr',
    front: '"Better late than never"',
    back: 'Más vale tarde que nunca.',
  ),
  _SeedCard(
    id: 'seed-en-expr-015',
    deckId: 'seed-en-expr',
    front: '"To be under the weather"',
    back: 'Estar pachucho, no encontrarse bien.',
  ),
  _SeedCard(
    id: 'seed-en-expr-016',
    deckId: 'seed-en-expr',
    front: '"Speak of the devil"',
    back: 'Hablando del rey de Roma… (cuando aparece de quien hablabas).',
  ),
  _SeedCard(
    id: 'seed-en-expr-017',
    deckId: 'seed-en-expr',
    front: '"Pull yourself together"',
    back: 'Cálmate, contrólate, recompónte.',
  ),
  _SeedCard(
    id: 'seed-en-expr-018',
    deckId: 'seed-en-expr',
    front: '"It\'s not rocket science"',
    back: 'No es para tanto / no es tan complicado.',
  ),
  _SeedCard(
    id: 'seed-en-expr-019',
    deckId: 'seed-en-expr',
    front: '"To hit the books"',
    back: 'Ponerse a estudiar en serio.',
  ),
  _SeedCard(
    id: 'seed-en-expr-020',
    deckId: 'seed-en-expr',
    front: '"To call it a day"',
    back: 'Dejarlo por hoy, dar por terminada la jornada.',
  ),
];

Future<void> seedIfEmpty(MemoraDatabase db) async {
  final existing = await db.deckDao.getAllDecks();
  if (existing.isEmpty) {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.batch((b) {
      for (final d in _seedDecks) {
        b.insert(
          db.decks,
          DecksCompanion.insert(
            id: d.id,
            name: d.name,
            colorHex: Value(d.colorHex),
            iconName: Value(d.iconName),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      for (final c in _seedCards) {
        b.insert(
          db.cards,
          CardsCompanion.insert(
            id: c.id,
            deckId: c.deckId,
            frontText: c.front,
            backText: c.back,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    });
  }
  // Siempre intentar seed inglés (idempotente).
  await _seedEnglishContent(db);
}

Future<void> _seedEnglishContent(MemoraDatabase db) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.batch((b) {
    for (final d in _englishDecks) {
      b.insert(
        db.decks,
        DecksCompanion.insert(
          id: d.id,
          name: d.name,
          colorHex: Value(d.colorHex),
          iconName: Value(d.iconName),
          createdAt: now,
          updatedAt: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
    for (final c in _englishCards) {
      b.insert(
        db.cards,
        CardsCompanion.insert(
          id: c.id,
          deckId: c.deckId,
          frontText: c.front,
          backText: c.back,
          createdAt: now,
          updatedAt: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
  });
}

class _SeedDeck {
  final String id;
  final String name;
  final String colorHex;
  final String iconName;

  const _SeedDeck({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.iconName,
  });
}

class _SeedCard {
  final String id;
  final String deckId;
  final String front;
  final String back;

  const _SeedCard({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
  });
}
