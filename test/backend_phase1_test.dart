import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/utils/password_policy.dart';
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/region_settings_repository.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/region_settings_provider.dart';
import 'package:optivus/services/device_country_service.dart';

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

  test('saved region outranks device detection during hydration', () async {
    final repository = FakeRegionSettingsRepository();
    await repository.saveRegionSettings(RegionSettings.india(userId: 'u1'));
    final notifier = RegionSettingsNotifier(
      repository,
      const _TestDeviceCountryService(
        DeviceCountry(
          countryCode: 'GB',
          countryName: 'United Kingdom',
          fromDeviceLocation: true,
        ),
      ),
    );

    await notifier.loadForUser('u1');

    expect(notifier.state.countryCode, 'IN');
    expect(notifier.state.currencyCode, 'INR');
    expect(notifier.state.source, RegionSource.userSaved);
  });

  test('device region is used only when no saved region exists', () async {
    final notifier = RegionSettingsNotifier(
      FakeRegionSettingsRepository(),
      const _TestDeviceCountryService(
        DeviceCountry(
          countryCode: 'IN',
          countryName: 'India',
          fromDeviceLocation: true,
        ),
      ),
    );

    await notifier.loadForUser('u1');

    expect(notifier.state.countryCode, 'IN');
    expect(notifier.state.source, RegionSource.deviceDetected);
  });

  test('late device permission refresh replaces only weak fallback', () async {
    final service = _MutableDeviceCountryService();
    final notifier = RegionSettingsNotifier(
      FakeRegionSettingsRepository(),
      service,
    );
    await notifier.loadForUser('u1');
    expect(notifier.state.source, RegionSource.localeFallback);

    service.result = const DeviceCountry(
      countryCode: 'IN',
      countryName: 'India',
      fromDeviceLocation: true,
    );
    final refreshed = await notifier.refreshFromDeviceIfAllowed();
    expect(refreshed.countryCode, 'IN');
    expect(refreshed.currencyCode, 'INR');
    expect(refreshed.source, RegionSource.deviceDetected);
  });

  test('late device refresh never overwrites explicit saved region', () async {
    final service = _MutableDeviceCountryService()
      ..result = const DeviceCountry(
        countryCode: 'IN',
        countryName: 'India',
        fromDeviceLocation: true,
      );
    final notifier = RegionSettingsNotifier(
      FakeRegionSettingsRepository(),
      service,
    );
    notifier.loadSettings(RegionSettings.unitedStates(userId: 'u1'));

    final refreshed = await notifier.refreshFromDeviceIfAllowed();
    expect(refreshed.countryCode, 'US');
    expect(refreshed.currencyCode, 'USD');
    expect(service.calls, 0);
  });

  test(
    'delayed device country detection completes and updates settings',
    () async {
      final completer = Completer<DeviceCountry?>();
      final service = _CompleterDeviceCountryService(completer);
      final notifier = RegionSettingsNotifier(
        FakeRegionSettingsRepository(),
        service,
      );
      await notifier.loadForUser('u1');
      expect(notifier.state.source, RegionSource.localeFallback);

      final future = notifier.refreshFromDeviceIfAllowed();
      expect(notifier.state.source, RegionSource.localeFallback);

      completer.complete(
        const DeviceCountry(
          countryCode: 'IN',
          countryName: 'India',
          fromDeviceLocation: true,
        ),
      );
      final refreshed = await future;
      expect(refreshed.countryCode, 'IN');
      expect(refreshed.currencyCode, 'INR');
      expect(refreshed.source, RegionSource.deviceDetected);
    },
  );

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

class _CompleterDeviceCountryService
    implements DeviceCountryService, PermissionAwareDeviceCountryService {
  final Completer<DeviceCountry?> completer;
  int calls = 0;

  _CompleterDeviceCountryService(this.completer);

  @override
  Future<DeviceCountry?> detectCountry() async {
    calls += 1;
    return null;
  }

  @override
  Future<DeviceCountry?> detectCountryIfPermissionGranted() async {
    calls += 1;
    return completer.future;
  }
}

class _TestDeviceCountryService implements DeviceCountryService {
  final DeviceCountry? result;
  const _TestDeviceCountryService(this.result);

  @override
  Future<DeviceCountry?> detectCountry() async => result;
}

class _MutableDeviceCountryService implements DeviceCountryService {
  DeviceCountry? result;
  int calls = 0;

  @override
  Future<DeviceCountry?> detectCountry() async {
    calls += 1;
    return result;
  }
}
