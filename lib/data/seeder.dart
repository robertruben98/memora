import 'database/database.dart';

/// Punto de entrada de seeding invocado en el arranque de la app.
///
/// RutaB se enfoca 100% en el teorico DGT. El contenido del temario DGT 2026
/// proviene del backend, por lo que el seeder local NO inserta ningun mazo ni
/// tarjeta generica (ingles, programacion, etc.). Se conserva la firma publica
/// para no romper a quien la invoca en el arranque.
Future<void> seedIfEmpty(MemoraDatabase db) async {
  // Sin contenido generico que sembrar. El teorico DGT viene del backend.
}
