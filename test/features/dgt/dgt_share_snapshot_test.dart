import 'package:flutter_test/flutter_test.dart';
import 'package:memora/features/dgt/services/dgt_share_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue #182 (dgt-ux): tests del servicio de snapshot publico para
/// compartir progreso con autoescuela.
///
/// Cubre:
/// - Determinismo del token (mismo uid+dia => mismo token).
/// - Rotacion diaria (uid igual, dia distinto => token distinto).
/// - Persistencia del uid en SharedPreferences.
/// - Deeplink formateado `memora://share/dgt/<token>`.
/// - `buildHumanText` no contiene "email" ni datos sensibles.

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('computeShareToken', () {
    test('mismo uid + mismo dia => mismo token (determinista)', () {
      final t1 = computeShareToken('uid-abc', DateTime(2026, 5, 21));
      final t2 = computeShareToken('uid-abc', DateTime(2026, 5, 21, 23, 59));
      expect(t1, t2);
      expect(t1.length, 16);
    });

    test('mismo uid + dia distinto => token distinto (rota a diario)', () {
      final t1 = computeShareToken('uid-abc', DateTime(2026, 5, 21));
      final t2 = computeShareToken('uid-abc', DateTime(2026, 5, 22));
      expect(t1, isNot(t2));
    });

    test('uid distinto + mismo dia => token distinto', () {
      final t1 = computeShareToken('uid-A', DateTime(2026, 5, 21));
      final t2 = computeShareToken('uid-B', DateTime(2026, 5, 21));
      expect(t1, isNot(t2));
    });

    test('token es solo hex de 16 chars', () {
      final t = computeShareToken('uid-xyz', DateTime(2026, 1, 1));
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(t), isTrue);
    });
  });

  group('resolveShareUid', () {
    test('genera uid nuevo si no existe', () async {
      final uid = await resolveShareUid();
      expect(uid, isNotEmpty);
    });

    test('persistente: dos llamadas devuelven el mismo uid', () async {
      final uid1 = await resolveShareUid();
      final uid2 = await resolveShareUid();
      expect(uid1, uid2);
    });
  });

  group('DgtShareSnapshot', () {
    test('deeplink formateado memora://share/dgt/<token>', () {
      final snap = DgtShareSnapshot(
        token: 'abc123',
        currentStreak: 5,
        monthlyAnswered: 120,
        generatedAt: DateTime(2026, 5, 21),
      );
      expect(snap.deeplink, 'memora://share/dgt/abc123');
    });

    test('hasPrediction es false si expectedScorePct null', () {
      final snap = DgtShareSnapshot(
        token: 'x',
        currentStreak: 0,
        monthlyAnswered: 0,
        generatedAt: DateTime(2026, 5, 21),
      );
      expect(snap.hasPrediction, isFalse);
    });

    test('buildHumanText con prediccion incluye %, racha y deeplink', () {
      final snap = DgtShareSnapshot(
        token: 'tok123',
        expectedScorePct: 87.4,
        currentStreak: 12,
        monthlyAnswered: 250,
        weakestTopicId: 'senales',
        weakestTopicAccuracyPct: 55.0,
        examDate: DateTime(2026, 7, 10),
        generatedAt: DateTime(2026, 5, 21),
      );
      final text = snap.buildHumanText();
      expect(text, contains('87%'));
      expect(text, contains('12 dias'));
      expect(text, contains('250'));
      expect(text, contains('senales'));
      expect(text, contains('2026-07-10'));
      expect(text, contains('memora://share/dgt/tok123'));
    });

    test('buildHumanText sin prediccion muestra "datos insuficientes"', () {
      final snap = DgtShareSnapshot(
        token: 'tok',
        currentStreak: 0,
        monthlyAnswered: 0,
        generatedAt: DateTime(2026, 5, 21),
      );
      expect(snap.buildHumanText(), contains('insuficientes'));
    });

    test('buildHumanText NO incluye email ni datos sensibles', () {
      final snap = DgtShareSnapshot(
        token: 'tok',
        expectedScorePct: 80.0,
        currentStreak: 3,
        monthlyAnswered: 50,
        generatedAt: DateTime(2026, 5, 21),
      );
      final text = snap.buildHumanText().toLowerCase();
      expect(text.contains('@'), isFalse, reason: 'no debe incluir email');
      expect(text.contains('password'), isFalse);
      expect(text.contains('token auth'), isFalse);
    });
  });
}
