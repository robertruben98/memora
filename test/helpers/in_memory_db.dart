import 'package:drift/native.dart';
import 'package:memora/data/database/database.dart';

/// Crea una `MemoraDatabase` en memoria para tests, evitando file IO.
MemoraDatabase newInMemoryDb() {
  return MemoraDatabase.forTesting(NativeDatabase.memory());
}
