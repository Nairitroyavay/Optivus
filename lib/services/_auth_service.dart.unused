// lib/services/auth_service.dart
//
// AuthService manages user authentication state (Sign In, Sign Up, Sign Out, Password Reset).
// During signup, the initial user document is created directly in Cloud Firestore.
// Relies on Firebase Auth and Cloud Firestore.

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user != null) {
      await _ensureUserDocument(user);
    }

    return credential;
  }

  Future<UserCredential> signUp(
    String email,
    String password, {
    String? name,
    String? timezone,
  }) async {
    final normalizedEmail = email.trim();
    final credential = await _auth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );
    final user = credential.user;
    if (user != null) {
      final now = DateTime.now();
      final normalizedName = name?.trim();
      final resolvedName =
          normalizedName?.isEmpty == true ? null : normalizedName;

      // Update Firebase Auth display name.
      if (resolvedName != null) {
        await user.updateDisplayName(resolvedName);
      }

      final userModel = UserModel(
        id: user.uid,
        email: normalizedEmail,
        displayName: resolvedName,
        timezone: timezone ?? now.timeZoneName,
        createdAt: now,
        updatedAt: now,
        hasCompletedOnboarding: false,
        onboardingStep: 0,
        schemaVersion: 1,
        lastDayClosed: null,
        coachName: null,
        coachStyle: null,
        accountabilityMode: null,
        notificationSettings: const NotificationSettings(),
      );

      // Direct document creation, bypassing complex event pipelines.
      final docRef = _firestore.collection('users').doc(user.uid);
      await docRef.set(userModel.toFirestore());
      debugPrint('User signed up: ${user.uid}, email: ${userModel.email}');
    }
    return credential;
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> _ensureUserDocument(User user) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final snap = await ref.get();
    final data = snap.data();
    final now = DateTime.now();
    final existingCreatedAt = data?['createdAt'];
    final currentNotificationSettings = data?['notificationSettings'];

    final defaults = <String, dynamic>{
      'uid': user.uid,
      'email': data?['email'] ?? user.email ?? '',
      'displayName': data?['displayName'] ?? user.displayName,
      'createdAt': existingCreatedAt ?? Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': data?['schemaVersion'] ?? 1,
      'timezone': data?['timezone'] ?? now.timeZoneName,
      'hasCompletedOnboarding': data?['hasCompletedOnboarding'] ?? false,
      'onboardingStep': data?['onboardingStep'] ?? 0,
      'lastDayClosed': data?['lastDayClosed'],
      'coachName': data?['coachName'],
      'coachStyle': data?['coachStyle'],
      'accountabilityMode': data?['accountabilityMode'],
      'notificationSettings': currentNotificationSettings is Map
          ? Map<String, dynamic>.from(currentNotificationSettings)
          : const NotificationSettings().toMap(),
    };

    await ref.set(defaults, SetOptions(merge: true));
  }
}
