import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/region_settings.dart';

abstract class RegionSettingsRepository {
  Future<RegionSettings> fetchRegionSettings(String userId);
  Future<void> saveRegionSettings(RegionSettings settings);
}

class FakeRegionSettingsRepository implements RegionSettingsRepository {
  final Map<String, RegionSettings> _settingsByUserId = {};

  @override
  Future<RegionSettings> fetchRegionSettings(String userId) async {
    return _settingsByUserId[userId] ?? RegionSettings.defaultForUser(userId);
  }

  @override
  Future<void> saveRegionSettings(RegionSettings settings) async {
    _settingsByUserId[settings.userId] = settings;
  }
}

final regionSettingsRepositoryProvider = Provider<RegionSettingsRepository>((
  ref,
) {
  return FakeRegionSettingsRepository();
});
