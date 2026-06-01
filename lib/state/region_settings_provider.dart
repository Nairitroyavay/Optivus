import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/repositories/region_settings_repository.dart';

class RegionSettingsNotifier extends StateNotifier<RegionSettings> {
  final RegionSettingsRepository _repository;

  RegionSettingsNotifier(this._repository)
    : super(RegionSettings.defaultForUser('mock-user-123'));

  Future<void> loadForUser(String userId) async {
    state = await _repository.fetchRegionSettings(userId);
  }

  Future<void> save(RegionSettings settings) async {
    final updated = settings.copyWith(updatedAt: DateTime.now());
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
}

final regionSettingsProvider =
    StateNotifierProvider<RegionSettingsNotifier, RegionSettings>((ref) {
      return RegionSettingsNotifier(
        ref.watch(regionSettingsRepositoryProvider),
      );
    });
