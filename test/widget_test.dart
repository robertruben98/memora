import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memora/main.dart';

void main() {
  testWidgets('Memora boots and shows app title', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MemoraApp()));
    expect(find.text('Memora'), findsOneWidget);
  });
}
