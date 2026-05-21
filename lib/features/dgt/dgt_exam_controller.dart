import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/dgt_repository.dart';
import 'dgt_result_screen.dart';

/// Issue #139 (dgt-tech): controlador puro para el simulacro DGT.
///
/// Encapsula timer + scoring + navegacion + flag toggling para que la UI
/// (`DgtExamScreen`) quede como una capa fina de presentacion y la logica
/// sea testeable unitariamente (sin `pumpWidget`).
///
/// Diseno:
/// - Extends `ChangeNotifier`: equivalente Riverpod ligero, suficiente para
///   notificar a la UI mediante `AnimatedBuilder`/`ListenableBuilder`.
/// - Sin dependencia de Flutter widgets ni de SharedPreferences: la
///   persistencia del snapshot (issue #133) y el push a `DgtResultScreen` se
///   orquestan desde la UI, que escucha `phase` y reacciona.
/// - El timer usa `Timer.periodic` interno pero acepta inyeccion de un
///   `clockTickFactory` opcional (no usado todavia; util para tests
///   deterministas).
///
/// Aditivo respecto al codigo previo: no cambia la UX visible. Los tests
/// del widget (`dgt_exam_screen_test.dart`) y E2E siguen pasando porque la
/// UI delega en este controller pero conserva el mismo arbol de widgets.

/// Fase del simulacro.
///
/// - [running]: timer activo, el usuario navega y responde.
/// - [submitted]: el examen se entrego (manualmente o por timeout).
/// - [aborted]: el simulacro se descarto (no usado todavia en UI; reservado
///   para el dialogo "Salir" del modo no-estricto).
enum DgtExamPhase { running, submitted, aborted }

/// Snapshot serializable del estado del controller. Sirve para que la UI
/// persista el progreso (issue #133) sin acoplarse a los campos internos.
class DgtExamControllerSnapshot {
  final List<DgtQuestion> questions;
  final Map<int, String> answers;
  final Set<int> flagged;
  final int currentIndex;
  final int remainingSeconds;
  final DateTime startedAt;
  final DgtExamPhase phase;

  const DgtExamControllerSnapshot({
    required this.questions,
    required this.answers,
    required this.flagged,
    required this.currentIndex,
    required this.remainingSeconds,
    required this.startedAt,
    required this.phase,
  });
}

class DgtExamController extends ChangeNotifier {
  /// Total de segundos del simulacro DGT permiso B: 30 minutos.
  static const int totalSeconds = 30 * 60;

  /// Si `true`, modo "Examen real" (issue #87): sin Anterior, sin flag, sin
  /// grid. El controller no aplica restricciones — solo lo expone para que
  /// la UI decida que widgets mostrar. La logica pura (scoring/navegacion)
  /// es identica en ambos modos; lo unico que el controller cambia segun
  /// strict es que `previous()` se ignora silenciosamente para evitar bugs
  /// si la UI accidentalmente lo llama.
  final bool strictMode;

  /// Instante en que se inicio el simulacro (para persistir en snapshot y
  /// auditar elapsed time).
  final DateTime startedAt;

  List<DgtQuestion> _questions;
  final Map<int, String> _answers = {};
  final Set<int> _flagged = {};
  int _currentIndex = 0;
  int _remainingSeconds;
  DgtExamPhase _phase = DgtExamPhase.running;
  Timer? _ticker;

  /// Construye el controller con preguntas ya cargadas. Si la lista esta
  /// vacia el controller queda en fase `running` con 0 preguntas; la UI
  /// debe manejar el caso "sin preguntas" antes de llamar `start()`.
  DgtExamController({
    required List<DgtQuestion> questions,
    this.strictMode = false,
    int? remainingSeconds,
    DateTime? startedAt,
    Map<int, String>? initialAnswers,
    Set<int>? initialFlagged,
    int initialIndex = 0,
    DgtExamPhase initialPhase = DgtExamPhase.running,
  })  : _questions = List<DgtQuestion>.unmodifiable(questions),
        _remainingSeconds = remainingSeconds ?? totalSeconds,
        startedAt = startedAt ?? DateTime.now(),
        _phase = initialPhase {
    if (initialAnswers != null) _answers.addAll(initialAnswers);
    if (initialFlagged != null) _flagged.addAll(initialFlagged);
    if (_questions.isEmpty) {
      _currentIndex = 0;
    } else {
      _currentIndex = initialIndex.clamp(0, _questions.length - 1);
    }
  }

  /// Construye el controller a partir de un snapshot persistido (issue #133).
  /// Si `secondsRemaining` es <= 0, el simulacro arranca ya en `submitted`.
  factory DgtExamController.fromSnapshot({
    required List<DgtQuestion> questions,
    required Map<int, String> answers,
    required Set<int> flagged,
    required int currentIndex,
    required int secondsRemaining,
    required DateTime startedAt,
    bool strictMode = false,
  }) {
    final phase =
        secondsRemaining <= 0 ? DgtExamPhase.submitted : DgtExamPhase.running;
    return DgtExamController(
      questions: questions,
      strictMode: strictMode,
      remainingSeconds: secondsRemaining < 0 ? 0 : secondsRemaining,
      startedAt: startedAt,
      initialAnswers: answers,
      initialFlagged: flagged,
      initialIndex: currentIndex,
      initialPhase: phase,
    );
  }

  // ---------------------------------------------------------------------------
  // Estado expuesto (read-only).
  // ---------------------------------------------------------------------------

  List<DgtQuestion> get questions => _questions;
  Map<int, String> get selectedAnswers => Map.unmodifiable(_answers);
  Set<int> get flaggedIndices => Set.unmodifiable(_flagged);
  int get currentIndex => _currentIndex;
  int get remainingSeconds => _remainingSeconds;
  DgtExamPhase get phase => _phase;
  bool get isRunning => _phase == DgtExamPhase.running;
  bool get isSubmitted => _phase == DgtExamPhase.submitted;
  int get answeredCount => _answers.length;
  int get totalQuestions => _questions.length;

  /// Pregunta actualmente mostrada, o null si no hay preguntas.
  DgtQuestion? get currentQuestion {
    if (_questions.isEmpty) return null;
    return _questions[_currentIndex];
  }

  /// Letra elegida para la pregunta indicada por `index`, o null si sin
  /// responder. Atajo: si no se pasa `index`, devuelve la del current.
  String? pickedAt([int? index]) {
    final i = index ?? _currentIndex;
    return _answers[i];
  }

  /// Si la pregunta `index` esta marcada con flag (ignorado en strict mode).
  bool isFlagged([int? index]) {
    final i = index ?? _currentIndex;
    return _flagged.contains(i);
  }

  // ---------------------------------------------------------------------------
  // Mutaciones (solo en phase=running).
  // ---------------------------------------------------------------------------

  /// Selecciona una respuesta para la pregunta actual. `letter` debe ser
  /// 'a' | 'b' | 'c'. Reemplaza la seleccion previa si la habia.
  ///
  /// No-op si phase != running, si la letra es invalida o si no hay
  /// preguntas. Idempotente para misma letra.
  void selectAnswer(String letter) {
    if (!isRunning || _questions.isEmpty) return;
    final l = letter.toLowerCase();
    if (l != 'a' && l != 'b' && l != 'c') return;
    if (_answers[_currentIndex] == l) return;
    _answers[_currentIndex] = l;
    notifyListeners();
  }

  /// Cambia el flag de la pregunta actual. En strict mode es no-op porque el
  /// modo simula examen real sin marcado.
  void toggleFlag() {
    if (!isRunning || _questions.isEmpty || strictMode) return;
    if (_flagged.contains(_currentIndex)) {
      _flagged.remove(_currentIndex);
    } else {
      _flagged.add(_currentIndex);
    }
    notifyListeners();
  }

  /// Avanza a la siguiente pregunta. No-op si ya esta en la ultima o si
  /// phase != running.
  void next() {
    if (!isRunning || _questions.isEmpty) return;
    if (_currentIndex >= _questions.length - 1) return;
    _currentIndex++;
    notifyListeners();
  }

  /// Vuelve a la pregunta anterior. No-op en strict mode (simula examen real
  /// donde no se puede revisar), si ya esta en la primera o si phase !=
  /// running.
  void previous() {
    if (!isRunning || _questions.isEmpty || strictMode) return;
    if (_currentIndex <= 0) return;
    _currentIndex--;
    notifyListeners();
  }

  /// Salta a la pregunta `index`. No-op si fuera de rango o phase != running.
  /// En strict mode tampoco permite saltos hacia atras (no <_currentIndex)
  /// porque la UI no expone grid pero defendemos por seguridad.
  void goTo(int index) {
    if (!isRunning || _questions.isEmpty) return;
    if (index < 0 || index >= _questions.length) return;
    if (strictMode && index < _currentIndex) return;
    if (index == _currentIndex) return;
    _currentIndex = index;
    notifyListeners();
  }

  /// Decrementa el timer en 1 segundo. Si llega a 0, entrega automaticamente
  /// el simulacro (phase -> submitted). Idempotente si phase != running.
  ///
  /// La UI puede llamar `tick()` desde un `Timer.periodic` propio o bien
  /// llamar `startTimer()` para que el controller gestione su propio ticker.
  void tick() {
    if (!isRunning) return;
    if (_remainingSeconds <= 0) {
      _remainingSeconds = 0;
      _phase = DgtExamPhase.submitted;
      _ticker?.cancel();
      _ticker = null;
      notifyListeners();
      return;
    }
    _remainingSeconds--;
    if (_remainingSeconds <= 0) {
      _phase = DgtExamPhase.submitted;
      _ticker?.cancel();
      _ticker = null;
    }
    notifyListeners();
  }

  /// Arranca el ticker interno (1 tick/seg). No-op si ya hay ticker o si
  /// phase != running. Idempotente: llamar 2 veces no crea 2 timers.
  void startTimer() {
    if (!isRunning) return;
    if (_ticker != null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  /// Para el ticker sin cambiar phase (util si la UI quiere usar su propio
  /// timer source o pausar para tests). El estado del simulacro permanece.
  void stopTimer() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// Entrega el examen manualmente. Computa el resultado y deja la fase en
  /// `submitted`. Idempotente: si ya estaba submitted/aborted devuelve el
  /// resultado calculado en ese momento.
  DgtExamResult submit() {
    if (_phase == DgtExamPhase.submitted) {
      return buildResult();
    }
    _phase = DgtExamPhase.submitted;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
    return buildResult();
  }

  /// Descarta el simulacro sin entregar. Sirve para el dialogo "Salir" del
  /// modo no-estricto. Idempotente.
  void abort() {
    if (_phase == DgtExamPhase.submitted) return;
    _phase = DgtExamPhase.aborted;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Scoring.
  // ---------------------------------------------------------------------------

  /// Construye el resultado del examen a partir del estado actual. Las
  /// preguntas sin responder se cuentan como falladas (criterio oficial
  /// DGT). Puede llamarse antes de `submit()` para previsualizar score.
  DgtExamResult buildResult() {
    int correct = 0;
    final wrong = <DgtAnswerReview>[];
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final picked = _answers[i];
      final ok = picked != null && picked == q.correct;
      if (ok) {
        correct++;
      } else {
        wrong.add(DgtAnswerReview(question: q, picked: picked));
      }
    }
    return DgtExamResult(
      total: _questions.length,
      correct: correct,
      wrong: wrong,
      elapsedSeconds: totalSeconds - _remainingSeconds,
      strictMode: strictMode,
    );
  }

  /// Lista de IDs de preguntas falladas (sin responder cuenta como fallo).
  /// Sirve para `dgtFailuresRepository.recordFailures` desde la UI sin
  /// reconstruir el result.
  List<DgtQuestion> failedQuestions() {
    final out = <DgtQuestion>[];
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final picked = _answers[i];
      if (picked == null || picked != q.correct) {
        out.add(q);
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Snapshot.
  // ---------------------------------------------------------------------------

  /// Vuelca el estado actual a un snapshot serializable. La UI lo usa para
  /// persistir progreso (issue #133) tras cada mutacion relevante.
  DgtExamControllerSnapshot toSnapshot() {
    return DgtExamControllerSnapshot(
      questions: _questions,
      answers: Map<int, String>.from(_answers),
      flagged: Set<int>.from(_flagged),
      currentIndex: _currentIndex,
      remainingSeconds: _remainingSeconds,
      startedAt: startedAt,
      phase: _phase,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }
}
