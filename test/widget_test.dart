import 'package:flutter_test/flutter_test.dart';

import 'package:memora/main.dart';

void main() {
  testWidgets('Memora boots and shows home', (tester) async {
    await tester.pumpWidget(const MemoraApp());
    expect(find.text('Memora'), findsOneWidget);
    expect(find.text('Estudiar todo'), findsOneWidget);
  });
}
