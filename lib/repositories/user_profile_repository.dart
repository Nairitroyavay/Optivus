import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/user_profile.dart';

abstract class UserProfileRepository {
  Future<UserProfile?> fetchProfile(String uid);
  Future<void> saveProfile(UserProfile profile);
  Future<void> patchProfile(String uid, Map<String, dynamic> patch);
}

class FakeUserProfileRepository implements UserProfileRepository {
  final Map<String, UserProfile> _profiles = {};

  @override
  Future<UserProfile?> fetchProfile(String uid) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _profiles[uid];
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _profiles[profile.uid] = profile;
  }

  @override
  Future<void> patchProfile(String uid, Map<String, dynamic> patch) async {
    await Future.delayed(const Duration(milliseconds: 400));
    // Mock patch
    if (_profiles.containsKey(uid)) {
      // In a real app this would merge the patch
    }
  }
}

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return FakeUserProfileRepository();
});
