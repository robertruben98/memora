import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_settings.dart';

/// Issue #153 (dgt-ux): cubre el nuevo flag `showSubtopicTutorial` de
/// `DgtSettings`. Test puro — no toca la BBDD.
void main() {
  group('DgtSettings.showSubtopicTutorial', () {
    test('default ON (instalaciones nuevas)', () {
      expect(DgtSettings.defaults.showSubtopicTutorial, isTrue);
    });

    test('copyWith preserva valor cuando no se pasa', () {
      final original = DgtSettings.defaults.copyWith(
        showSubtopicTutorial: false,
      );
      final copy = original.copyWith(dailyGoal: 30);
      expect(copy.showSubtopicTutorial, isFalse);
      expect(copy.dailyGoal, 30);
    });

    test('copyWith permite togglear a OFF', () {
      final next = DgtSettings.defaults.copyWith(showSubtopicTutorial: false);
      expect(next.showSubtopicTutorial, isFalse);
      // Resto de campos intactos.
      expect(next.licenseType, DgtSettings.defaults.licenseType);
      expect(next.dailyGoal, DgtSettings.defaults.dailyGoal);
      expect(next.showExplanationOnFail,
          DgtSettings.defaults.showExplanationOnFail);
    });

    test('constructor explicito acepta false', () {
      const s = DgtSettings(
        licenseType: DgtLicenseType.b,
        examDate: null,
        dailyGoal: 20,
        showSubtopicTutorial: false,
      );
      expect(s.showSubtopicTutorial, isFalse);
    });
  });
}
