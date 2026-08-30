import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/utils/password_policy.dart';
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/region_settings_repository.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/region_settings_provider.dart';

void main() {
  group('password policy', () {
    test('accepts Nairit@123', () {
      expect(isOptivusPasswordValid('Nairit@123'), isTrue);
    });

    test('rejects no uppercase', () {
      expect(isOptivusPasswordValid('nairit@123'), isFalse);
    });

    test('rejects no number', () {
      expect(isOptivusPasswordValid('Nairit@abc'), isFalse);
    });

    test('rejects no special char', () {
      expect(isOptivusPasswordValid('Nairit123'), isFalse);
    });
  });

  group('auth flow status', () {
    test('unverified password user is email unverified', () {
      const user = AuthUser(
        uid: 'u1',
        email: 'person@example.com',
        emailVerified: false,
        providerIds: {'password'},
      );

      expect(
        AuthNotifier.statusFor(user, false),
        AuthFlowStatus.signedInEmailUnverified,
      );
    });

    test('verified user with onboarding false is onboarding incomplete', () {
      const user = AuthUser(
        uid: 'u1',
        email: 'person@example.com',
        emailVerified: true,
        providerIds: {'password'},
      );

      expect(
        AuthNotifier.statusFor(user, false),
        AuthFlowStatus.signedInOnboardingIncomplete,
      );
    });

    test('verified user with onboarding true is onboarding complete', () {
      const user = AuthUser(
        uid: 'u1',
        email: 'person@example.com',
        emailVerified: true,
        providerIds: {'password'},
      );

      expect(
        AuthNotifier.statusFor(user, true),
        AuthFlowStatus.signedInOnboardingComplete,
      );
    });
  });

  test('region payment guard blocks India UPI outside India', () async {
    final repository = FakeRegionSettingsRepository();
    final notifier = RegionSettingsNotifier(repository);
    final invalid = RegionSettings.unitedStates(
      userId: 'u1',
    ).copyWith(paymentRegion: PaymentRegion.indiaUpi);

    await notifier.save(invalid);

    final saved = await repository.fetchRegionSettings('u1');
    expect(saved!.countryCode, 'US');
    expect(saved.paymentRegion, isNot(PaymentRegion.indiaUpi));
  });

  test('Firestore path strings remain correct', () {
    expect(FirestoreUserPaths.profile('abc'), 'users/abc/profile/main');
    expect(
      FirestoreUserPaths.regionSettings('abc'),
      'users/abc/settings/regionLocalization',
    );
    expect(
      FirestoreUserPaths.appPreferences('abc'),
      'users/abc/settings/appPreferences',
    );
  });
}
