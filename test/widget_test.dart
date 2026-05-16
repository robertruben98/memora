import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/core/srs/study_settings.dart';

/// Widget test minimo. El smoke previo de `MemoraApp` requiere bootstrap del
/// `ProviderContainer` (path_provider, sqlite, sync de red) y rompe en CI.
/// Lo sustituimos por un test que verifica que el arbol de providers se
/// puede instanciar y los defaults son los esperados.
void main() {
  testWidgets('ProviderScope arranca con StudySettings por defecto',
      (tester) async {
    late StudySettings observed;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              observed = ref.watch(studySettingsProvider);
              return Text('Memora ${observed.newCardsPerDay}');
            },
          ),
        ),
      ),
    );

    expect(observed.newCardsPerDay, StudySettings.defaults.newCardsPerDay);
    expect(observed.maxReviewsPerDay, StudySettings.defaults.maxReviewsPerDay);
    expect(
      find.text('Memora ${StudySettings.defaults.newCardsPerDay}'),
      findsOneWidget,
    );
  });
}
