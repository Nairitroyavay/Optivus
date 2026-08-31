import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/profile/models/profile_settings_models.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/firestore_paths.dart';

abstract class ProfileRepository {
  Future<UserProfile?> fetchUserProfile(String uid);
  Future<UserProfileSettings> fetchProfileSettings(String uid);
  Future<void> saveUserProfile(UserProfile profile);
  Future<void> saveProfileSettings(String uid, UserProfileSettings settings);
}

abstract class PermissionStatusRepository {
  Future<List<PermissionStatusModel>> fetchPermissions(String uid);
  Future<void> savePermission(String uid, PermissionStatusModel permission);
}

abstract class ConnectedServicesRepository {
  Future<List<ConnectedServiceStatusModel>> fetchServices(String uid);
  Future<void> saveService(String uid, ConnectedServiceStatusModel service);
}

abstract class DataControlRepository {
  Future<DataExportRequestModel?> fetchLatestExportRequest(String uid);
  Future<void> saveExportRequest(String uid, DataExportRequestModel request);
  Future<DeletionRequestModel> fetchDeletionRequest(String uid);
  Future<void> saveDeletionRequest(String uid, DeletionRequestModel request);
}

class FakeProfileRepository implements ProfileRepository {
  final Map<String, UserProfile> _profiles = {};
  final Map<String, UserProfileSettings> _settings = {};

  @override
  Future<UserProfile?> fetchUserProfile(String uid) async {
    return _profiles[uid];
  }

  @override
  Future<UserProfileSettings> fetchProfileSettings(String uid) async {
    return _settings[uid] ?? const UserProfileSettings();
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    _profiles[profile.uid] = profile;
  }

  @override
  Future<void> saveProfileSettings(
    String uid,
    UserProfileSettings settings,
  ) async {
    _settings[uid] = settings;
  }
}

class FirestoreProfileRepository implements ProfileRepository {
  final FirebaseFirestore? _injectedFirestore;

  FirestoreProfileRepository({FirebaseFirestore? firestore})
    : _injectedFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  @override
  Future<UserProfile?> fetchUserProfile(String uid) async {
    final doc = await _firestore.doc(FirestoreUserPaths.user(uid)).get();
    final data = doc.data();
    return data == null ? null : UserProfile.fromFirestoreMap(data);
  }

  @override
  Future<UserProfileSettings> fetchProfileSettings(String uid) async {
    final doc = await _firestore.doc(FirestoreUserPaths.profile(uid)).get();
    final data = doc.data();
    if (data == null) return const UserProfileSettings();
    return UserProfileSettings.fromFirestoreMap(data);
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) {
    return _firestore
        .doc(FirestoreUserPaths.user(profile.uid))
        .set(profile.toFirestoreMap(), SetOptions(merge: true));
  }

  @override
  Future<void> saveProfileSettings(
    String uid,
    UserProfileSettings settings,
  ) async {
    final reference = _firestore.doc(FirestoreUserPaths.profile(uid));
    final existing = await reference.get();
    final existingCreatedAt = existing.data()?['createdAt'];
    final now = DateTime.now();
    await reference.set(
      settings.toFirestoreMap(
        ownerUid: uid,
        createdAt: existingCreatedAt is Timestamp
            ? existingCreatedAt.toDate()
            : now,
        updatedAt: now,
      ),
    );
  }
}

class FakePermissionStatusRepository implements PermissionStatusRepository {
  final Map<String, List<PermissionStatusModel>> _permissions = {};

  @override
  Future<List<PermissionStatusModel>> fetchPermissions(String uid) async {
    return _permissions[uid] ?? ProfileSettingsStateDefaults.permissions;
  }

  @override
  Future<void> savePermission(
    String uid,
    PermissionStatusModel permission,
  ) async {
    final current = [...await fetchPermissions(uid)];
    current.removeWhere((item) => item.type == permission.type);
    current.add(permission);
    _permissions[uid] = current;
  }
}

class FakeConnectedServicesRepository implements ConnectedServicesRepository {
  final Map<String, List<ConnectedServiceStatusModel>> _services = {};

  @override
  Future<List<ConnectedServiceStatusModel>> fetchServices(String uid) async {
    return _services[uid] ?? ProfileSettingsStateDefaults.services;
  }

  @override
  Future<void> saveService(
    String uid,
    ConnectedServiceStatusModel service,
  ) async {
    final current = [...await fetchServices(uid)];
    current.removeWhere((item) => item.type == service.type);
    current.add(service);
    _services[uid] = current;
  }
}

class FakeDataControlRepository implements DataControlRepository {
  final Map<String, DataExportRequestModel> _exports = {};
  final Map<String, DeletionRequestModel> _deletions = {};

  @override
  Future<DataExportRequestModel?> fetchLatestExportRequest(String uid) async {
    return _exports[uid];
  }

  @override
  Future<void> saveExportRequest(
    String uid,
    DataExportRequestModel request,
  ) async {
    _exports[uid] = request;
  }

  @override
  Future<DeletionRequestModel> fetchDeletionRequest(String uid) async {
    return _deletions[uid] ?? const DeletionRequestModel();
  }

  @override
  Future<void> saveDeletionRequest(
    String uid,
    DeletionRequestModel request,
  ) async {
    _deletions[uid] = request;
  }
}

class UnavailableFirebaseProfileSupportRepository
    implements
        PermissionStatusRepository,
        ConnectedServicesRepository,
        DataControlRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw const FirebaseFeatureUnavailableException('Profile support data');
  }
}

class ProfileSettingsStateDefaults {
  static final permissions = ProfileSettingsStateSeed.permissions;
  static final services = ProfileSettingsStateSeed.services;
}

class ProfileSettingsStateSeed {
  static const permissions = [
    PermissionStatusModel(
      type: ProfilePermissionType.notifications,
      status: ProfileConnectionStatus.notConnected,
      lastChecked: 'Native check pending',
      liveCheckCapable: false,
    ),
    PermissionStatusModel(
      type: ProfilePermissionType.usageAccess,
      status: ProfileConnectionStatus.notConnected,
      lastChecked: 'Native check pending',
      liveCheckCapable: false,
    ),
    PermissionStatusModel(
      type: ProfilePermissionType.location,
      status: ProfileConnectionStatus.notConnected,
      lastChecked: 'Native check pending',
      liveCheckCapable: false,
    ),
    PermissionStatusModel(
      type: ProfilePermissionType.healthConnect,
      status: ProfileConnectionStatus.notConnected,
      lastChecked: 'Native check pending',
      liveCheckCapable: false,
    ),
    PermissionStatusModel(
      type: ProfilePermissionType.cameraPhotos,
      status: ProfileConnectionStatus.notConnected,
      lastChecked: 'Native check pending',
      liveCheckCapable: false,
    ),
    PermissionStatusModel(
      type: ProfilePermissionType.microphone,
      status: ProfileConnectionStatus.notConnected,
      lastChecked: 'Native check pending',
      liveCheckCapable: false,
    ),
  ];

  static const services = [
    ConnectedServiceStatusModel(
      type: ConnectedServiceType.cloudflareR2,
      status: ProfileConnectionStatus.notConfigured,
      lastChecked: 'Not configured',
    ),
    ConnectedServiceStatusModel(
      type: ConnectedServiceType.mapbox,
      status: ProfileConnectionStatus.notConfigured,
      lastChecked: 'Not configured',
    ),
    ConnectedServiceStatusModel(
      type: ConnectedServiceType.healthConnect,
      status: ProfileConnectionStatus.notConnected,
      lastChecked: 'Not checked',
    ),
    ConnectedServiceStatusModel(
      type: ConnectedServiceType.androidUsageAccess,
      status: ProfileConnectionStatus.notConnected,
      lastChecked: 'Not checked',
    ),
    ConnectedServiceStatusModel(
      type: ConnectedServiceType.cloudflareWorkers,
      status: ProfileConnectionStatus.notConfigured,
      lastChecked: 'Not configured',
    ),
  ];
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ref
      .watch(fakeBackendPolicyProvider)
      .selectBackend(
        firebase: FirestoreProfileRepository.new,
        fake: FakeProfileRepository.new,
      );
});

final permissionStatusRepositoryProvider = Provider<PermissionStatusRepository>(
  (ref) {
    return ref
        .watch(fakeBackendPolicyProvider)
        .selectBackend(
          firebase: UnavailableFirebaseProfileSupportRepository.new,
          fake: FakePermissionStatusRepository.new,
        );
  },
);

final connectedServicesRepositoryProvider =
    Provider<ConnectedServicesRepository>((ref) {
      return ref
          .watch(fakeBackendPolicyProvider)
          .selectBackend(
            firebase: UnavailableFirebaseProfileSupportRepository.new,
            fake: FakeConnectedServicesRepository.new,
          );
    });

final dataControlRepositoryProvider = Provider<DataControlRepository>((ref) {
  return ref
      .watch(fakeBackendPolicyProvider)
      .selectBackend(
        firebase: UnavailableFirebaseProfileSupportRepository.new,
        fake: FakeDataControlRepository.new,
      );
});
