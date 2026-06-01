abstract class UsageAccessService {
  Future<bool> hasUsageAccess();
  Future<void> openUsageAccessSettings();
  Future<Map<String, int>> fetchDailyUsageMinutes();
}

abstract class LocationTrackingService {
  Future<bool> hasLocationPermission();
  Future<void> requestLocationPermission();
  Future<void> startRouteTracking(String activityId);
  Future<void> stopRouteTracking(String activityId);
}

abstract class HealthConnectService {
  Future<bool> isAvailable();
  Future<bool> hasRequiredPermissions();
  Future<void> requestPermissions();
  Future<Map<String, num>> fetchDailyHealthSummary(DateTime date);
}

abstract class NotificationPermissionService {
  Future<bool> hasNotificationPermission();
  Future<void> requestNotificationPermission();
  Future<void> openNotificationSettings();
}

abstract class MapboxConfigService {
  Future<bool> hasConfig();
  Future<String?> fetchPublicToken();
  Future<String?> fetchDefaultStyleId();
}

abstract class UpiIntentService {
  Future<bool> canOpenUpiIntent();
  Future<void> openSavingIntent({required double amount, required String note});
}

class LocaleDeviceSnapshot {
  final String countryCode;
  final String languageCode;

  const LocaleDeviceSnapshot({
    required this.countryCode,
    required this.languageCode,
  });
}

abstract class LocaleDeviceService {
  Future<LocaleDeviceSnapshot> fetchLocale();
}

abstract class TimezoneService {
  Future<String> fetchTimezone();
}

abstract class CurrencyRegionService {
  Future<String> suggestedCurrencyCode(String countryCode);
}

abstract class PaymentCapabilityService {
  Future<bool> canUseUpi(String countryCode);
  Future<List<String>> availablePaymentLabels(String countryCode);
}

class FakeUsageAccessService implements UsageAccessService {
  @override
  Future<Map<String, int>> fetchDailyUsageMinutes() async => const {};

  @override
  Future<bool> hasUsageAccess() async => false;

  @override
  Future<void> openUsageAccessSettings() async {
    // Future native plan: Android ACTION_USAGE_ACCESS_SETTINGS via platform channel.
  }
}

class FakeLocationTrackingService implements LocationTrackingService {
  @override
  Future<bool> hasLocationPermission() async => false;

  @override
  Future<void> requestLocationPermission() async {
    // Future native plan: permission_handler or platform channel.
  }

  @override
  Future<void> startRouteTracking(String activityId) async {
    // Future native plan: geolocator stream plus Mapbox route rendering.
  }

  @override
  Future<void> stopRouteTracking(String activityId) async {}
}

class FakeHealthConnectService implements HealthConnectService {
  @override
  Future<Map<String, num>> fetchDailyHealthSummary(DateTime date) async {
    return const {};
  }

  @override
  Future<bool> hasRequiredPermissions() async => false;

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> requestPermissions() async {
    // Future native plan: Health Connect plugin or Android platform channel.
  }
}

class FakeNotificationPermissionService
    implements NotificationPermissionService {
  @override
  Future<bool> hasNotificationPermission() async => false;

  @override
  Future<void> openNotificationSettings() async {
    // Future native plan: Android app notification settings intent.
  }

  @override
  Future<void> requestNotificationPermission() async {
    // Future package plan: permission_handler plus flutter_local_notifications.
  }
}

class FakeMapboxConfigService implements MapboxConfigService {
  @override
  Future<String?> fetchDefaultStyleId() async => null;

  @override
  Future<String?> fetchPublicToken() async => null;

  @override
  Future<bool> hasConfig() async => false;
}

class FakeUpiIntentService implements UpiIntentService {
  @override
  Future<bool> canOpenUpiIntent() async => false;

  @override
  Future<void> openSavingIntent({
    required double amount,
    required String note,
  }) async {
    // Future native plan: url_launcher or Android UPI intent channel.
  }
}

class FakeLocaleDeviceService implements LocaleDeviceService {
  @override
  Future<LocaleDeviceSnapshot> fetchLocale() async {
    return const LocaleDeviceSnapshot(countryCode: 'US', languageCode: 'en');
  }
}

class FakeTimezoneService implements TimezoneService {
  @override
  Future<String> fetchTimezone() async => 'America/New_York';
}

class FakeCurrencyRegionService implements CurrencyRegionService {
  @override
  Future<String> suggestedCurrencyCode(String countryCode) async {
    return switch (countryCode.toUpperCase()) {
      'IN' => 'INR',
      'JP' => 'JPY',
      'GB' => 'GBP',
      'EU' => 'EUR',
      _ => 'USD',
    };
  }
}

class FakePaymentCapabilityService implements PaymentCapabilityService {
  @override
  Future<bool> canUseUpi(String countryCode) async {
    return countryCode.toUpperCase() == 'IN';
  }

  @override
  Future<List<String>> availablePaymentLabels(String countryCode) async {
    if (await canUseUpi(countryCode)) {
      return const ['Manual confirmation', 'Cash', 'Bank transfer', 'UPI'];
    }
    return const ['Manual confirmation', 'Cash', 'Bank transfer'];
  }
}
