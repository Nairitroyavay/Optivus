import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/notification_preferences.dart';

abstract class NotificationPreferencesRepository {
  Future<NotificationPreferences?> fetchPreferences(String uid);
  Future<void> savePreferences(String uid, NotificationPreferences prefs);
}

class FakeNotificationPreferencesRepository
    implements NotificationPreferencesRepository {
  final Map<String, NotificationPreferences> _prefs = {};

  @override
  Future<NotificationPreferences?> fetchPreferences(String uid) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _prefs[uid];
  }

  @override
  Future<void> savePreferences(
    String uid,
    NotificationPreferences prefs,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _prefs[uid] = prefs;
  }
}

final notificationPreferencesRepositoryProvider =
    Provider<NotificationPreferencesRepository>((ref) {
      return FakeNotificationPreferencesRepository();
    });
