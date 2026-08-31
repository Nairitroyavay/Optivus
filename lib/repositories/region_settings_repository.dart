import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/repositories/firestore_paths.dart';

abstract class RegionSettingsRepository {
  Future<RegionSettings?> fetchRegionSettings(String userId);
  Future<void> saveRegionSettings(RegionSettings settings);
}

class FakeRegionSettingsRepository implements RegionSettingsRepository {
  final Map<String, RegionSettings> _settingsByUserId = {};

  @override
  Future<RegionSettings?> fetchRegionSettings(String userId) async {
    return _settingsByUserId[userId] ?? RegionSettings.defaultForUser(userId);
  }

  @override
  Future<void> saveRegionSettings(RegionSettings settings) async {
    _settingsByUserId[settings.userId] = settings;
  }
}

class FirestoreRegionSettingsRepository implements RegionSettingsRepository {
  final FirebaseFirestore? _injectedFirestore;

  FirestoreRegionSettingsRepository({FirebaseFirestore? firestore})
    : _injectedFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  @override
  Future<RegionSettings?> fetchRegionSettings(String userId) async {
    final doc = await _firestore
        .doc(FirestoreUserPaths.regionSettings(userId))
        .get();
    final data = doc.data();
    return data == null ? null : RegionSettings.fromFirestoreMap(data);
  }

  @override
  Future<void> saveRegionSettings(RegionSettings settings) {
    return _firestore
        .doc(FirestoreUserPaths.regionSettings(settings.userId))
        .set(settings.toFirestoreMap());
  }
}

final regionSettingsRepositoryProvider = Provider<RegionSettingsRepository>((
  ref,
) {
  return ref
      .watch(fakeBackendPolicyProvider)
      .selectBackend(
        firebase: FirestoreRegionSettingsRepository.new,
        fake: FakeRegionSettingsRepository.new,
      );
});
