import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/dgt_adaptive_goal_provider.dart';
import 'package:memora/features/dgt/dgt_settings.dart';

/// Issue #107 (dgt-ux): tests para meta diaria adaptativa.
/// Cubre el calculo PURO `computeAdaptiveGoal` y el helper de cooldown
/// `isDgtAdaptiveBannerDismissed`. No toca SharedPreferences directamente.
void main() {
  group('computeAdaptiveGoal', () {
    DgtSettings buildSettings({DateTime? examDate, int dailyGoal = 20}) {
      return DgtSettings(
        licenseType: DgtLicenseType.b,
        examDate: examDate,
        dailyGoal: dailyGoal,
      );
    }

    test('sin examDate -> sin banner', () {
      final now = DateTime(2026, 1, 1);
      final r = computeAdaptiveGoal(
        settings: buildSettings(examDate: null),
        totalAnswered: 0,
        now: now,
      );
      expect(r.shouldShowBanner, isFalse);
      expect(r.suggested, isNull);
      expect(r.daysToExam, isNull);
    });

    test('examen ya pasado -> sin banner', () {
      final now = DateTime(2026, 1, 10);
      final exam = DateTime(2026, 1, 5);
      final r = computeAdaptiveGoal(
        settings: buildSettings(examDate: exam),
        totalAnswered: 100,
        now: now,
      );
      expect(r.shouldShowBanner, isFalse);
      expect(r.daysToExam, lessThanOrEqualTo(0));
    });

    test('atrasado (suggested > current*1.25) -> banner accelerar', () {
      final now = DateTime(2026, 1, 1);
      // 10 dias para examen, 0 respondidas, target=600 -> suggested=60.
      // current=20 -> ratio=3 > 1.25 -> banner ON.
      final exam = DateTime(2026, 1, 11);
      final r = computeAdaptiveGoal(
        settings: buildSettings(examDate: exam, dailyGoal: 20),
        totalAnswered: 0,
        now: now,
      );
      expect(r.shouldShowBanner, isTrue);
      expect(r.mustAccelerate, isTrue);
      expect(r.suggested, 60);
      expect(r.daysToExam, 10);
    });

    test('en rango (desfase <=25%) -> sin banner', () {
      final now = DateTime(2026, 1, 1);
      // 30 dias, ya respondio 100, restante=500 -> suggested=ceil(500/30)=17
      // current=20 -> ratio=0.85 (ni acelerar ni sobrado).
      final exam = DateTime(2026, 1, 31);
      final r = computeAdaptiveGoal(
        settings: buildSettings(examDate: exam, dailyGoal: 20),
        totalAnswered: 100,
        now: now,
      );
      expect(r.shouldShowBanner, isFalse);
      expect(r.mustAccelerate, isNull);
    });

    test('vas sobrado (suggested < current*0.5) -> banner relajado', () {
      final now = DateTime(2026, 1, 1);
      // 90 dias, ya respondio 500, restante=100 -> suggested=ceil(100/90)=2
      // pero clamp a min=5. current=40 -> 5/40=0.125 < 0.5 -> banner ON.
      final exam = DateTime(2026, 4, 1);
      final r = computeAdaptiveGoal(
        settings: buildSettings(examDate: exam, dailyGoal: 40),
        totalAnswered: 500,
        now: now,
      );
      expect(r.shouldShowBanner, isTrue);
      expect(r.mustAccelerate, isFalse);
      expect(r.suggested, kDgtAdaptiveMinSuggested);
    });

    test('cobertura completada -> banner solo si current muy alto', () {
      final now = DateTime(2026, 1, 1);
      final exam = DateTime(2026, 1, 31);
      // totalAnswered >= target -> suggested = min (5). Banner si goal > 10.
      final highGoal = computeAdaptiveGoal(
        settings: buildSettings(examDate: exam, dailyGoal: 30),
        totalAnswered: kDgtAdaptiveTargetCoverage,
        now: now,
      );
      expect(highGoal.shouldShowBanner, isTrue);
      expect(highGoal.mustAccelerate, isFalse);
      expect(highGoal.suggested, kDgtAdaptiveMinSuggested);

      final lowGoal = computeAdaptiveGoal(
        settings: buildSettings(examDate: exam, dailyGoal: 8),
        totalAnswered: kDgtAdaptiveTargetCoverage,
        now: now,
      );
      expect(lowGoal.shouldShowBanner, isFalse);
    });

    test('suggested cap a kDgtAdaptiveMaxSuggested', () {
      final now = DateTime(2026, 1, 1);
      // 1 dia, target completo -> raw=600/1=600. Clamp a max=100.
      final exam = DateTime(2026, 1, 2);
      final r = computeAdaptiveGoal(
        settings: buildSettings(examDate: exam, dailyGoal: 20),
        totalAnswered: 0,
        now: now,
      );
      expect(r.suggested, kDgtAdaptiveMaxSuggested);
      expect(r.shouldShowBanner, isTrue);
      expect(r.mustAccelerate, isTrue);
    });

    test('coverageRatio se calcula clamp [0,1]', () {
      final now = DateTime(2026, 1, 1);
      final exam = DateTime(2026, 1, 31);
      final r = computeAdaptiveGoal(
        settings: buildSettings(examDate: exam),
        totalAnswered: kDgtAdaptiveTargetCoverage * 2,
        now: now,
      );
      expect(r.coverageRatio, 1.0);
    });
  });

  group('isDgtAdaptiveBannerDismissed', () {
    test('null dismissedAt -> no dismissed', () {
      final now = DateTime(2026, 1, 1);
      expect(
        isDgtAdaptiveBannerDismissed(dismissedAt: null, now: now),
        isFalse,
      );
    });

    test('dentro de cooldown (<24h) -> dismissed', () {
      final now = DateTime(2026, 1, 1, 12, 0);
      final dismissed = DateTime(2026, 1, 1, 0, 0);
      expect(
        isDgtAdaptiveBannerDismissed(dismissedAt: dismissed, now: now),
        isTrue,
      );
    });

    test('fuera de cooldown (>=24h) -> no dismissed', () {
      final now = DateTime(2026, 1, 2, 0, 1);
      final dismissed = DateTime(2026, 1, 1, 0, 0);
      expect(
        isDgtAdaptiveBannerDismissed(dismissedAt: dismissed, now: now),
        isFalse,
      );
    });
  });
}
