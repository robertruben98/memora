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

const _programmingDecks = [
  _SeedDeck(
    id: 'seed-prog',
    name: 'Programación',
    colorHex: '#4FFFB0',
    iconName: 'code_rounded',
  ),
];

const _programmingCards = <_SeedCard>[
  // ===== Complejidad / Big-O =====
  _SeedCard(
    id: 'seed-prog-001',
    deckId: 'seed-prog',
    front: '¿Qué es Big-O?',
    back: 'Notación que describe cómo crece el tiempo (o memoria) de un '
        'algoritmo en función del tamaño de la entrada, ignorando constantes.',
  ),
  _SeedCard(
    id: 'seed-prog-002',
    deckId: 'seed-prog',
    front: 'Complejidad de búsqueda lineal',
    back: 'O(n). Recorrer el array elemento a elemento.',
  ),
  _SeedCard(
    id: 'seed-prog-003',
    deckId: 'seed-prog',
    front: 'Complejidad de búsqueda binaria',
    back: 'O(log n). Requiere array ordenado; divide el rango a la mitad '
        'en cada paso.',
  ),
  _SeedCard(
    id: 'seed-prog-004',
    deckId: 'seed-prog',
    front: 'Complejidad de Quicksort (promedio y peor caso)',
    back: 'Promedio O(n log n). Peor caso O(n²) cuando el pivote siempre es '
        'el mínimo o máximo.',
  ),
  _SeedCard(
    id: 'seed-prog-005',
    deckId: 'seed-prog',
    front: 'Complejidad de Mergesort',
    back: 'O(n log n) en todos los casos. Usa O(n) extra de memoria.',
  ),
  _SeedCard(
    id: 'seed-prog-006',
    deckId: 'seed-prog',
    front: 'Complejidad amortizada de push en un dynamic array',
    back: 'O(1) amortizado. Aunque algunas inserciones cuestan O(n) por la '
        'realocación, el coste promedio es constante.',
  ),
  _SeedCard(
    id: 'seed-prog-007',
    deckId: 'seed-prog',
    front: 'Complejidad de operaciones en hash table (promedio)',
    back: 'O(1) en promedio para insert/get/delete. O(n) en peor caso por '
        'colisiones.',
  ),
  _SeedCard(
    id: 'seed-prog-008',
    deckId: 'seed-prog',
    front: '¿Qué significa que un algoritmo sea O(2^n)?',
    back: 'Tiempo exponencial: dobla con cada nuevo elemento. Inviable para '
        'n grande. Típico en backtracking o subconjuntos.',
  ),

  // ===== Estructuras de datos =====
  _SeedCard(
    id: 'seed-prog-010',
    deckId: 'seed-prog',
    front: 'Diferencia entre array y linked list',
    back: 'Array: acceso O(1) por índice, inserción/borrado O(n). '
        'Linked list: acceso O(n), inserción/borrado en extremo O(1).',
  ),
  _SeedCard(
    id: 'seed-prog-011',
    deckId: 'seed-prog',
    front: '¿Qué es una pila (stack)?',
    back: 'Estructura LIFO: el último en entrar es el primero en salir. '
        'Operaciones push/pop en O(1).',
  ),
  _SeedCard(
    id: 'seed-prog-012',
    deckId: 'seed-prog',
    front: '¿Qué es una cola (queue)?',
    back: 'Estructura FIFO: el primero en entrar es el primero en salir. '
        'Operaciones enqueue/dequeue en O(1).',
  ),
  _SeedCard(
    id: 'seed-prog-013',
    deckId: 'seed-prog',
    front: '¿Qué es un hash map?',
    back: 'Estructura clave→valor que usa una función hash para indexar. '
        'Acceso promedio O(1).',
  ),
  _SeedCard(
    id: 'seed-prog-014',
    deckId: 'seed-prog',
    front: '¿Qué es un árbol binario de búsqueda (BST)?',
    back: 'Árbol binario donde cada nodo izquierdo es menor y el derecho '
        'mayor. Búsqueda O(log n) si está balanceado.',
  ),
  _SeedCard(
    id: 'seed-prog-015',
    deckId: 'seed-prog',
    front: '¿Qué es un heap (montículo)?',
    back: 'Árbol binario casi completo donde el padre es mayor (max-heap) o '
        'menor (min-heap) que sus hijos. Inserción y extracción O(log n).',
  ),
  _SeedCard(
    id: 'seed-prog-016',
    deckId: 'seed-prog',
    front: '¿Qué es un grafo dirigido vs no dirigido?',
    back: 'Dirigido: las aristas tienen sentido (A→B). No dirigido: las '
        'aristas son bidireccionales (A—B).',
  ),
  _SeedCard(
    id: 'seed-prog-017',
    deckId: 'seed-prog',
    front: '¿Qué es un trie?',
    back: 'Árbol prefix-tree usado para almacenar strings. Cada arista '
        'representa un carácter. Búsqueda O(longitud del string).',
  ),
  _SeedCard(
    id: 'seed-prog-018',
    deckId: 'seed-prog',
    front: '¿Qué es un set?',
    back: 'Colección de elementos únicos sin orden garantizado. Operaciones '
        'add/contains/remove O(1) si está implementado con hash.',
  ),
  _SeedCard(
    id: 'seed-prog-019',
    deckId: 'seed-prog',
    front: '¿Qué es una deque (double-ended queue)?',
    back: 'Cola doble: permite insertar y extraer por ambos extremos en O(1).',
  ),
  _SeedCard(
    id: 'seed-prog-020',
    deckId: 'seed-prog',
    front: 'Diferencia entre BFS y DFS',
    back: 'BFS (anchura) usa cola, explora nivel por nivel. '
        'DFS (profundidad) usa pila/recursión, explora rama hasta el final.',
  ),

  // ===== Algoritmos =====
  _SeedCard(
    id: 'seed-prog-030',
    deckId: 'seed-prog',
    front: '¿Qué es la programación dinámica?',
    back: 'Técnica que resuelve problemas dividiéndolos en subproblemas y '
        'almacenando los resultados (memoización) para evitar recomputarlos.',
  ),
  _SeedCard(
    id: 'seed-prog-031',
    deckId: 'seed-prog',
    front: 'Diferencia entre top-down y bottom-up en DP',
    back: 'Top-down: recursión + memoización (lazy). '
        'Bottom-up: tabulación iterativa desde casos base.',
  ),
  _SeedCard(
    id: 'seed-prog-032',
    deckId: 'seed-prog',
    front: 'Algoritmo de Dijkstra: ¿qué resuelve?',
    back: 'Camino más corto desde un nodo origen a todos los demás en un '
        'grafo con pesos no negativos. Complejidad O((V+E) log V) con heap.',
  ),
  _SeedCard(
    id: 'seed-prog-033',
    deckId: 'seed-prog',
    front: '¿Qué es two-pointers?',
    back: 'Patrón con dos índices que recorren la estructura. Útil en '
        'arrays ordenados (búsqueda de pares, sliding window).',
  ),
  _SeedCard(
    id: 'seed-prog-034',
    deckId: 'seed-prog',
    front: '¿Qué es sliding window?',
    back: 'Técnica que mantiene una "ventana" móvil sobre un array para '
        'calcular agregados sin recomputar todo cada paso.',
  ),
  _SeedCard(
    id: 'seed-prog-035',
    deckId: 'seed-prog',
    front: '¿Qué es backtracking?',
    back: 'Búsqueda exhaustiva que explora opciones y deshace cuando llega '
        'a un callejón sin salida. Típico en sudoku, N-reinas, permutaciones.',
  ),
  _SeedCard(
    id: 'seed-prog-036',
    deckId: 'seed-prog',
    front: '¿Qué es un algoritmo greedy?',
    back: 'Algoritmo que toma la decisión localmente óptima en cada paso '
        'esperando que conduzca al óptimo global. No siempre funciona.',
  ),
  _SeedCard(
    id: 'seed-prog-037',
    deckId: 'seed-prog',
    front: '¿Qué hace el algoritmo de Floyd para detectar ciclos?',
    back: 'Tortuga y liebre: dos punteros, uno avanza 1 y otro 2 pasos. '
        'Si hay ciclo, se encuentran. Detecta ciclos en O(n) con O(1) memoria.',
  ),
  _SeedCard(
    id: 'seed-prog-038',
    deckId: 'seed-prog',
    front: 'Algoritmo de Kahn: ¿qué resuelve?',
    back: 'Ordenamiento topológico de un DAG (grafo dirigido acíclico). '
        'Usa BFS y grados de entrada.',
  ),

  // ===== POO =====
  _SeedCard(
    id: 'seed-prog-050',
    deckId: 'seed-prog',
    front: '¿Qué es encapsulación?',
    back: 'Ocultar el estado interno de un objeto y exponer solo una '
        'interfaz pública controlada.',
  ),
  _SeedCard(
    id: 'seed-prog-051',
    deckId: 'seed-prog',
    front: '¿Qué es herencia?',
    back: 'Mecanismo por el que una clase deriva propiedades y métodos de '
        'otra (clase padre).',
  ),
  _SeedCard(
    id: 'seed-prog-052',
    deckId: 'seed-prog',
    front: '¿Qué es polimorfismo?',
    back: 'Capacidad de tratar objetos de distintas clases a través de una '
        'interfaz común. Ej: misma llamada, distinto comportamiento.',
  ),
  _SeedCard(
    id: 'seed-prog-053',
    deckId: 'seed-prog',
    front: '¿Qué es composición vs herencia?',
    back: 'Composición: un objeto contiene otros (has-a). '
        'Herencia: una clase es un tipo de otra (is-a). '
        'Generalmente preferir composición.',
  ),
  _SeedCard(
    id: 'seed-prog-054',
    deckId: 'seed-prog',
    front: 'Principios SOLID — letra S',
    back: 'Single Responsibility: una clase debe tener una sola razón para '
        'cambiar.',
  ),
  _SeedCard(
    id: 'seed-prog-055',
    deckId: 'seed-prog',
    front: 'Principios SOLID — letra O',
    back: 'Open/Closed: el código debe estar abierto a extensión pero '
        'cerrado a modificación.',
  ),
  _SeedCard(
    id: 'seed-prog-056',
    deckId: 'seed-prog',
    front: 'Principios SOLID — letra L',
    back: 'Liskov Substitution: subtipos deben ser sustituibles por sus '
        'tipos base sin alterar la corrección.',
  ),
  _SeedCard(
    id: 'seed-prog-057',
    deckId: 'seed-prog',
    front: 'Principios SOLID — letras I y D',
    back: 'I = Interface Segregation (interfaces pequeñas y específicas). '
        'D = Dependency Inversion (depender de abstracciones, no de '
        'implementaciones).',
  ),

  // ===== Patrones de diseño =====
  _SeedCard(
    id: 'seed-prog-070',
    deckId: 'seed-prog',
    front: 'Patrón Singleton',
    back: 'Garantiza que una clase tenga una única instancia y proporciona '
        'un punto de acceso global. Anti-patrón en muchos casos modernos.',
  ),
  _SeedCard(
    id: 'seed-prog-071',
    deckId: 'seed-prog',
    front: 'Patrón Factory',
    back: 'Centraliza la creación de objetos. El cliente pide una instancia '
        'sin conocer la clase concreta que se construye.',
  ),
  _SeedCard(
    id: 'seed-prog-072',
    deckId: 'seed-prog',
    front: 'Patrón Observer',
    back: 'Define una dependencia 1-a-N: cuando un objeto cambia, notifica '
        'a todos sus observadores. Base de eventos y pub/sub.',
  ),
  _SeedCard(
    id: 'seed-prog-073',
    deckId: 'seed-prog',
    front: 'Patrón Strategy',
    back: 'Encapsula algoritmos intercambiables en clases distintas y '
        'permite seleccionar el comportamiento en tiempo de ejecución.',
  ),
  _SeedCard(
    id: 'seed-prog-074',
    deckId: 'seed-prog',
    front: 'Patrón Decorator',
    back: 'Añade comportamiento a un objeto envolviéndolo dinámicamente, '
        'sin modificar la clase original.',
  ),
  _SeedCard(
    id: 'seed-prog-075',
    deckId: 'seed-prog',
    front: 'Patrón Adapter',
    back: 'Convierte la interfaz de una clase en otra que el cliente '
        'espera. Permite que clases incompatibles colaboren.',
  ),
  _SeedCard(
    id: 'seed-prog-076',
    deckId: 'seed-prog',
    front: 'Patrón Repository',
    back: 'Abstrae el acceso a datos detrás de una interfaz tipo colección. '
        'El dominio no sabe si los datos están en BD, API o memoria.',
  ),
  _SeedCard(
    id: 'seed-prog-077',
    deckId: 'seed-prog',
    front: 'Patrón Builder',
    back: 'Construye un objeto complejo paso a paso. Útil cuando hay muchos '
        'parámetros opcionales.',
  ),

  // ===== Conceptos generales =====
  _SeedCard(
    id: 'seed-prog-090',
    deckId: 'seed-prog',
    front: '¿Qué es la recursión?',
    back: 'Técnica donde una función se llama a sí misma con un caso más '
        'pequeño hasta llegar a un caso base.',
  ),
  _SeedCard(
    id: 'seed-prog-091',
    deckId: 'seed-prog',
    front: '¿Qué es un closure?',
    back: 'Función que captura variables de su contexto léxico y mantiene '
        'acceso a ellas aunque ejecute fuera de ese ámbito.',
  ),
  _SeedCard(
    id: 'seed-prog-092',
    deckId: 'seed-prog',
    front: '¿Qué es una función pura?',
    back: 'Función que (1) dado el mismo input devuelve el mismo output y '
        '(2) no produce efectos secundarios.',
  ),
  _SeedCard(
    id: 'seed-prog-093',
    deckId: 'seed-prog',
    front: 'Diferencia entre síncrono y asíncrono',
    back: 'Síncrono: el código se ejecuta en orden, bloquea hasta terminar. '
        'Asíncrono: la operación se delega y el flujo continúa; el '
        'resultado llega después.',
  ),
  _SeedCard(
    id: 'seed-prog-094',
    deckId: 'seed-prog',
    front: '¿Qué es una promise/future?',
    back: 'Objeto que representa el resultado eventual de una operación '
        'asíncrona. Tiene estados pending, fulfilled, rejected.',
  ),
  _SeedCard(
    id: 'seed-prog-095',
    deckId: 'seed-prog',
    front: 'Diferencia entre proceso e hilo (thread)',
    back: 'Proceso: instancia independiente con su propia memoria. '
        'Hilo: unidad de ejecución dentro de un proceso, comparte memoria '
        'con otros hilos del mismo proceso.',
  ),
  _SeedCard(
    id: 'seed-prog-096',
    deckId: 'seed-prog',
    front: '¿Qué es un race condition?',
    back: 'Bug que ocurre cuando el resultado depende del orden en que se '
        'ejecutan operaciones concurrentes sobre estado compartido.',
  ),
  _SeedCard(
    id: 'seed-prog-097',
    deckId: 'seed-prog',
    front: '¿Qué es un deadlock?',
    back: 'Situación en que dos o más hilos quedan bloqueados esperando '
        'recursos que el otro tiene, sin poder progresar.',
  ),
  _SeedCard(
    id: 'seed-prog-098',
    deckId: 'seed-prog',
    front: 'Inmutabilidad — ¿por qué importa?',
    back: 'Estructuras inmutables son thread-safe, predecibles y '
        'comparables por valor. Reducen bugs en código concurrente.',
  ),
  _SeedCard(
    id: 'seed-prog-099',
    deckId: 'seed-prog',
    front: '¿Qué es DRY?',
    back: 'Don\'t Repeat Yourself: cada pieza de conocimiento debe tener '
        'una representación única en el sistema.',
  ),
  _SeedCard(
    id: 'seed-prog-100',
    deckId: 'seed-prog',
    front: '¿Qué es YAGNI?',
    back: 'You Aren\'t Gonna Need It: no añadas funcionalidad hasta que '
        'realmente sea necesaria.',
  ),
  _SeedCard(
    id: 'seed-prog-101',
    deckId: 'seed-prog',
    front: '¿Qué es KISS?',
    back: 'Keep It Simple, Stupid: prefiere la solución más simple posible.',
  ),

  // ===== Git =====
  _SeedCard(
    id: 'seed-prog-120',
    deckId: 'seed-prog',
    front: 'Diferencia entre git merge y git rebase',
    back: 'Merge: une ramas creando un commit de merge (preserva historia). '
        'Rebase: reescribe los commits de la rama sobre otra (historia lineal).',
  ),
  _SeedCard(
    id: 'seed-prog-121',
    deckId: 'seed-prog',
    front: '¿Qué hace git stash?',
    back: 'Guarda los cambios locales en un stack temporal y deja el '
        'directorio limpio. Recuperable con git stash pop.',
  ),
  _SeedCard(
    id: 'seed-prog-122',
    deckId: 'seed-prog',
    front: '¿Qué es git cherry-pick?',
    back: 'Aplica un commit específico de otra rama a la actual.',
  ),
  _SeedCard(
    id: 'seed-prog-123',
    deckId: 'seed-prog',
    front: 'git reset --soft vs --mixed vs --hard',
    back: 'Soft: mueve HEAD, deja staging y working tree. '
        'Mixed: mueve HEAD, descarta staging, conserva working tree. '
        'Hard: descarta todo (peligroso).',
  ),
  _SeedCard(
    id: 'seed-prog-124',
    deckId: 'seed-prog',
    front: '¿Qué es un fast-forward merge?',
    back: 'Cuando la rama destino no tiene commits nuevos: el merge solo '
        'avanza el puntero, sin crear commit de merge.',
  ),
  _SeedCard(
    id: 'seed-prog-125',
    deckId: 'seed-prog',
    front: 'Diferencia entre git pull y git fetch',
    back: 'Fetch: descarga commits remotos pero no toca tu rama actual. '
        'Pull: fetch + merge (o rebase) en tu rama actual.',
  ),
  _SeedCard(
    id: 'seed-prog-126',
    deckId: 'seed-prog',
    front: '¿Qué hace git revert vs git reset?',
    back: 'Revert: crea un nuevo commit que deshace cambios (seguro en '
        'historia compartida). Reset: mueve el HEAD hacia atrás (modifica '
        'historia).',
  ),
  _SeedCard(
    id: 'seed-prog-127',
    deckId: 'seed-prog',
    front: '¿Qué es .gitignore?',
    back: 'Archivo que lista patrones de archivos/carpetas que git debe '
        'ignorar (no trackear ni commitear).',
  ),

  // ===== Bases de datos =====
  _SeedCard(
    id: 'seed-prog-150',
    deckId: 'seed-prog',
    front: '¿Qué significa ACID?',
    back: 'Atomicity, Consistency, Isolation, Durability. Propiedades de '
        'transacciones en BD relacionales.',
  ),
  _SeedCard(
    id: 'seed-prog-151',
    deckId: 'seed-prog',
    front: 'Diferencia entre INNER JOIN y LEFT JOIN',
    back: 'INNER: solo devuelve filas con coincidencia en ambas tablas. '
        'LEFT: devuelve todas las filas de la izquierda + las coincidentes '
        'de la derecha (NULL si no hay match).',
  ),
  _SeedCard(
    id: 'seed-prog-152',
    deckId: 'seed-prog',
    front: '¿Qué es un índice en BD?',
    back: 'Estructura auxiliar (típicamente B-tree) que acelera búsquedas '
        'sobre una columna a costa de espacio extra y escrituras más lentas.',
  ),
  _SeedCard(
    id: 'seed-prog-153',
    deckId: 'seed-prog',
    front: '¿Qué es la normalización?',
    back: 'Proceso de organizar tablas para reducir redundancia y '
        'dependencias. Niveles 1NF, 2NF, 3NF.',
  ),
  _SeedCard(
    id: 'seed-prog-154',
    deckId: 'seed-prog',
    front: 'SQL vs NoSQL — caso de uso típico',
    back: 'SQL: datos estructurados con relaciones, transacciones ACID, '
        'queries complejas. NoSQL: gran escala, schema flexible, lecturas '
        'sencillas.',
  ),
  _SeedCard(
    id: 'seed-prog-155',
    deckId: 'seed-prog',
    front: '¿Qué es N+1 query problem?',
    back: 'Anti-patrón: hacer 1 query para obtener N registros y luego N '
        'queries adicionales para datos relacionados. Solución: JOIN o '
        'eager loading.',
  ),

  // ===== Web / HTTP =====
  _SeedCard(
    id: 'seed-prog-180',
    deckId: 'seed-prog',
    front: 'Métodos HTTP idempotentes',
    back: 'GET, PUT, DELETE, HEAD, OPTIONS. POST y PATCH no lo son por '
        'definición.',
  ),
  _SeedCard(
    id: 'seed-prog-181',
    deckId: 'seed-prog',
    front: 'Status code 401 vs 403',
    back: '401 Unauthorized: no autenticado. '
        '403 Forbidden: autenticado pero sin permisos.',
  ),
  _SeedCard(
    id: 'seed-prog-182',
    deckId: 'seed-prog',
    front: '¿Qué es REST?',
    back: 'Estilo de arquitectura para APIs basado en recursos identificados '
        'por URLs, manipulados con métodos HTTP estándar y representaciones '
        'sin estado.',
  ),
  _SeedCard(
    id: 'seed-prog-183',
    deckId: 'seed-prog',
    front: 'Diferencia entre PUT y PATCH',
    back: 'PUT: reemplaza el recurso completo. '
        'PATCH: modifica parcialmente solo los campos enviados.',
  ),
  _SeedCard(
    id: 'seed-prog-184',
    deckId: 'seed-prog',
    front: '¿Qué es CORS?',
    back: 'Cross-Origin Resource Sharing: política que controla qué '
        'orígenes pueden hacer requests desde un navegador a otro dominio.',
  ),
  _SeedCard(
    id: 'seed-prog-185',
    deckId: 'seed-prog',
    front: 'JWT — ¿qué es y cómo se compone?',
    back: 'JSON Web Token. Tres partes separadas por puntos: header, '
        'payload y firma. Self-contained, firmado pero NO encriptado por '
        'defecto.',
  ),

  // ===== Sistemas / red =====
  _SeedCard(
    id: 'seed-prog-200',
    deckId: 'seed-prog',
    front: 'Diferencia entre TCP y UDP',
    back: 'TCP: orientado a conexión, fiable, ordenado, con control de '
        'flujo. UDP: sin conexión, sin garantías, pero rápido y ligero.',
  ),
  _SeedCard(
    id: 'seed-prog-201',
    deckId: 'seed-prog',
    front: '¿Qué hace DNS?',
    back: 'Traduce nombres de dominio (ej: google.com) a direcciones IP '
        '(ej: 142.250.x.x).',
  ),
  _SeedCard(
    id: 'seed-prog-202',
    deckId: 'seed-prog',
    front: '¿Qué es un load balancer?',
    back: 'Componente que distribuye tráfico entrante entre varios '
        'servidores para balancear carga y aumentar disponibilidad.',
  ),
  _SeedCard(
    id: 'seed-prog-203',
    deckId: 'seed-prog',
    front: '¿Qué es horizontal vs vertical scaling?',
    back: 'Vertical: añadir más recursos (CPU/RAM) a una máquina. '
        'Horizontal: añadir más máquinas. Horizontal escala mejor pero '
        'requiere arquitectura distribuida.',
  ),
  _SeedCard(
    id: 'seed-prog-204',
    deckId: 'seed-prog',
    front: '¿Qué es CAP theorem?',
    back: 'En un sistema distribuido solo puedes garantizar 2 de 3: '
        'Consistency, Availability, Partition tolerance.',
  ),

  // ===== Seguridad =====
  _SeedCard(
    id: 'seed-prog-220',
    deckId: 'seed-prog',
    front: '¿Qué es SQL injection?',
    back: 'Vulnerabilidad donde un atacante inserta SQL malicioso a través '
        'de inputs. Mitigación: prepared statements, ORM con bind params.',
  ),
  _SeedCard(
    id: 'seed-prog-221',
    deckId: 'seed-prog',
    front: '¿Qué es XSS?',
    back: 'Cross-Site Scripting: inyección de JS malicioso en una página. '
        'Mitigación: escape de HTML al renderizar contenido del usuario.',
  ),
  _SeedCard(
    id: 'seed-prog-222',
    deckId: 'seed-prog',
    front: '¿Qué es CSRF?',
    back: 'Cross-Site Request Forgery: engañar al navegador para enviar '
        'requests autenticadas a otra app. Mitigación: tokens CSRF, '
        'SameSite cookies.',
  ),
  _SeedCard(
    id: 'seed-prog-223',
    deckId: 'seed-prog',
    front: 'Diferencia entre hashing y encriptación',
    back: 'Hashing: unidireccional, no reversible (passwords). '
        'Encriptación: reversible con la clave correcta (datos en tránsito '
        'o reposo).',
  ),
  _SeedCard(
    id: 'seed-prog-224',
    deckId: 'seed-prog',
    front: '¿Por qué se usa salt al hashear contraseñas?',
    back: 'Para evitar ataques con rainbow tables. El salt hace que '
        'passwords idénticas produzcan hashes distintos.',
  ),

  // ===== Lenguajes específicos =====
  _SeedCard(
    id: 'seed-prog-240',
    deckId: 'seed-prog',
    front: 'JS — diferencia entre let, const y var',
    back: 'let: scope de bloque, mutable. const: scope de bloque, no '
        'reasignable. var: scope de función, hoisting, evitar.',
  ),
  _SeedCard(
    id: 'seed-prog-241',
    deckId: 'seed-prog',
    front: 'JS — diferencia entre == y ===',
    back: '==: compara con coerción de tipos (puede dar resultados raros). '
        '===: compara estricto sin coerción. Usa siempre ===.',
  ),
  _SeedCard(
    id: 'seed-prog-242',
    deckId: 'seed-prog',
    front: 'JS — ¿qué es event loop?',
    back: 'Mecanismo single-threaded que procesa la call stack y, cuando '
        'está vacía, saca tareas de la cola (microtasks/macrotasks) para '
        'ejecutarlas.',
  ),
  _SeedCard(
    id: 'seed-prog-243',
    deckId: 'seed-prog',
    front: 'Python — ¿qué es el GIL?',
    back: 'Global Interpreter Lock: mutex que solo permite ejecutar un '
        'thread Python a la vez. Limita paralelismo CPU-bound; no afecta '
        'a I/O.',
  ),
  _SeedCard(
    id: 'seed-prog-244',
    deckId: 'seed-prog',
    front: 'Python — list vs tuple',
    back: 'List: mutable, más métodos, []. '
        'Tuple: inmutable, hashable, (). Tuples más eficientes para datos '
        'que no cambian.',
  ),
  _SeedCard(
    id: 'seed-prog-245',
    deckId: 'seed-prog',
    front: 'Dart/Flutter — ¿qué es un Widget?',
    back: 'Descripción inmutable de una porción de UI. Se reconstruye '
        'cuando su estado o entorno cambian.',
  ),
  _SeedCard(
    id: 'seed-prog-246',
    deckId: 'seed-prog',
    front: 'Diferencia entre StatelessWidget y StatefulWidget',
    back: 'Stateless: UI fija dada su configuración. '
        'Stateful: UI que cambia con el tiempo (mantiene estado mutable '
        'en su State).',
  ),
  _SeedCard(
    id: 'seed-prog-247',
    deckId: 'seed-prog',
    front: 'TypeScript — ¿qué es never?',
    back: 'Tipo que representa valores que nunca ocurren. Ej: función que '
        'lanza excepción o bucle infinito; rama imposible.',
  ),
  _SeedCard(
    id: 'seed-prog-248',
    deckId: 'seed-prog',
    front: 'TypeScript — diferencia entre interface y type',
    back: 'Interface: extensible vía declaration merging y extends. '
        'Type: alias más flexible (uniones, intersecciones, tipos primitivos).',
  ),
  _SeedCard(
    id: 'seed-prog-249',
    deckId: 'seed-prog',
    front: 'Rust — ¿qué es ownership?',
    back: 'Sistema de Rust: cada valor tiene un único dueño. Cuando el '
        'dueño sale de scope, el valor se libera. Garantiza memoria segura '
        'sin GC.',
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
  // Siempre intentar seed adicional (idempotente).
  await _seedAdditionalContent(db);
}

Future<void> _seedAdditionalContent(MemoraDatabase db) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final allDecks = [..._englishDecks, ..._programmingDecks];
  final allCards = [..._englishCards, ..._programmingCards];
  await db.batch((b) {
    for (final d in allDecks) {
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
    for (final c in allCards) {
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
