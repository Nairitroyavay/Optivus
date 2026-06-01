import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/profile/models/profile_settings_models.dart';
import 'package:optivus/repositories/firestore_paths.dart';

abstract class AppPreferencesRepository {
  Future<UserPreferences?> fetchAppPreferences(String uid);
  Future<void> saveAppPreferences(String uid, UserPreferences preferences);
}

class FakeAppPreferencesRepository implements AppPreferencesRepository {
  final Map<String, UserPreferences> _preferencesByUserId = {};

  @override
  Future<UserPreferences?> fetchAppPreferences(String uid) async {
    return _preferencesByUserId[uid] ?? const UserPreferences();
  }

  @override
  Future<void> saveAppPreferences(
    String uid,
    UserPreferences preferences,
  ) async {
    _preferencesByUserId[uid] = preferences;
  }
}

class FirestoreAppPreferencesRepository implements AppPreferencesRepository {
  final FirebaseFirestore _firestore;

  FirestoreAppPreferencesRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<UserPreferences?> fetchAppPreferences(String uid) async {
    final doc = await _firestore
        .doc(FirestoreUserPaths.appPreferences(uid))
        .get();
    final data = doc.data();
    return data == null ? null : UserPreferences.fromFirestoreMap(data);
  }

  @override
  Future<void> saveAppPreferences(String uid, UserPreferences preferences) {
    return _firestore.doc(FirestoreUserPaths.appPreferences(uid)).set({
      ...preferences.toFirestoreMap(),
      'uid': uid,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
  }
}

final appPreferencesRepositoryProvider = Provider<AppPreferencesRepository>((
  ref,
) {
  if (OptivusBackendConfig.useFirebase) {
    return FirestoreAppPreferencesRepository();
  }
  return FakeAppPreferencesRepository();
});
