import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/repositories/region_settings_repository.dart';
import 'package:optivus/services/device_country_service.dart';

class RegionSettingsNotifier extends StateNotifier<RegionSettings> {
  final RegionSettingsRepository _repository;
  final DeviceCountryService _deviceCountryService;

  RegionSettingsNotifier(
    this._repository, [
    DeviceCountryService? deviceCountryService,
  ]) : _deviceCountryService =
           deviceCountryService ?? const GeolocatorDeviceCountryService(),
       super(RegionSettings.defaultForUser(''));

  Future<void> loadForUser(String userId) async {
    RegionSettings? saved;
    try {
      saved = await _repository.fetchRegionSettings(userId);
    } catch (_) {
      // Region localization must not prevent an authenticated session from
      // reconstructing; the safe fallback remains available below.
    }
    if (saved != null) {
      state = saved.copyWith(userId: userId);
      return;
    }

    DeviceCountry? detected;
    try {
      detected = await _deviceCountryService.detectCountry();
    } catch (_) {
      detected = null;
    }
    if (detected != null && detected.fromDeviceLocation) {
      state = RegionSettings.forCountry(
        userId: userId,
        countryCode: detected.countryCode,
        countryName: detected.countryName,
        source: RegionSource.deviceDetected,
      );
      return;
    }
    state = RegionSettings.defaultForUser(userId);
  }

  /// Refreshes weak region authority from an already-authorized device
  /// location. Explicit and legacy user-saved choices are never overwritten.
  Future<RegionSettings> refreshFromDeviceIfAllowed() async {
    final before = state;
    if (before.source == RegionSource.userSaved) return before;
    DeviceCountry? detected;
    try {
      detected = _deviceCountryService is PermissionAwareDeviceCountryService
          ? await (_deviceCountryService as PermissionAwareDeviceCountryService)
                .detectCountryIfPermissionGranted()
          : await _deviceCountryService.detectCountry();
    } catch (_) {
      detected = null;
    }
    if (state.userId != before.userId ||
        state.source == RegionSource.userSaved ||
        detected == null ||
        !detected.fromDeviceLocation) {
      return state;
    }
    state = RegionSettings.forCountry(
      userId: before.userId,
      countryCode: detected.countryCode,
      countryName: detected.countryName,
      source: RegionSource.deviceDetected,
    );
    return state;
  }

  void loadSettings(RegionSettings settings) {
    state = settings;
  }

  void resetForSignedOut() {
    state = RegionSettings.defaultForUser('signed-out');
  }

  Future<void> save(RegionSettings settings) async {
    final updated = _guardPaymentRegion(
      settings,
    ).copyWith(updatedAt: DateTime.now(), source: RegionSource.userSaved);
    state = updated;
    await _repository.saveRegionSettings(updated);
  }

  Future<void> applyCountryPreset(String countryName) async {
    final userId = state.userId;
    final preset = switch (countryName) {
      'India' => RegionSettings.india(userId: userId),
      'United States' => RegionSettings.unitedStates(userId: userId),
      'Japan' => RegionSettings.japan(userId: userId),
      'United Kingdom' => RegionSettings.unitedKingdom(userId: userId),
      'Europe' => RegionSettings.europe(userId: userId),
      _ => RegionSettings.other(userId: userId),
    };
    await save(preset.copyWith(createdAt: state.createdAt));
  }

  RegionSettings _guardPaymentRegion(RegionSettings settings) {
    final available = settings.countryCode == 'IN'
        ? const [
            PaymentRegion.manualOnly,
            PaymentRegion.indiaUpi,
            PaymentRegion.global,
          ]
        : const [PaymentRegion.manualOnly, PaymentRegion.global];
    if (available.contains(settings.paymentRegion)) return settings;
    return settings.copyWith(paymentRegion: available.first);
  }
}

final regionSettingsProvider =
    StateNotifierProvider<RegionSettingsNotifier, RegionSettings>((ref) {
      return RegionSettingsNotifier(
        ref.watch(regionSettingsRepositoryProvider),
        ref.watch(deviceCountryServiceProvider),
      );
    });
