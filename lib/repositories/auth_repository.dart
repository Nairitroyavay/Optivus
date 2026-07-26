import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:optivus/core/utils/auth_error_mapper.dart';

/// A simple user model for authentication purposes.
class AuthUser {
  final String uid;
  final String? email;
  final String? displayName;
  final bool emailVerified;
  final bool isAnonymous;
  final String providerId;

  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.emailVerified = false,
    this.isAnonymous = false,
    this.providerId = 'password',
  });
}

/// Abstract repository interface for authentication.
abstract class AuthRepository {
  Stream<AuthUser?> get authStateChanges;

  AuthUser? get currentUser;

  Future<AuthUser> signIn(String email, String password);

  Future<AuthUser> signUp(String email, String password, {String? name});

  Future<AuthUser> signInAnonymously();

  Future<AuthUser> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  });

  Future<void> sendEmailVerification();

  Future<AuthUser?> reloadCurrentUser();

  Future<String?> currentIdToken();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();
}

AuthUser _authUserFromFirebase(firebase_auth.User user) {
  final providerId = user.providerData.isNotEmpty
      ? user.providerData.first.providerId
      : 'password';

  return AuthUser(
    uid: user.uid,
    email: user.email,
    displayName: user.displayName,
    emailVerified: user.emailVerified,
    isAnonymous: user.isAnonymous,
    providerId: providerId,
  );
}

/// Fake implementation of [AuthRepository] for testing and UI development.
/// It uses local state and artificial delays.
class FakeAuthRepository implements AuthRepository {
  final _authStateController = StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;
  bool _verificationEmailSent = false;

  FakeAuthRepository() {
    // Start signed out.
    _authStateController.add(null);
  }

  @override
  Stream<AuthUser?> get authStateChanges => _authStateController.stream;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Future<AuthUser> signIn(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    final normalizedEmail = email.trim();

    // Dev account check
    if (normalizedEmail == 'test@optivus.dev' && password == 'test1234') {
      _currentUser = AuthUser(
        uid: 'dev-user-12345',
        email: normalizedEmail,
        displayName: 'Dev Test',
        emailVerified: true,
      );
    } else {
      _currentUser = AuthUser(
        uid: 'fake-uid-${DateTime.now().millisecondsSinceEpoch}',
        email: normalizedEmail,
        displayName: null,
        emailVerified: true,
      );
    }

    _authStateController.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<AuthUser> signUp(String email, String password, {String? name}) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    final normalizedEmail = email.trim();

    if (normalizedEmail.toLowerCase() == 'test@optivus.dev') {
      throw mapAuthError(Exception('email-already-in-use'));
    }

    _currentUser = AuthUser(
      uid: 'fake-uid-${DateTime.now().millisecondsSinceEpoch}',
      email: normalizedEmail,
      displayName: name?.trim(),
      emailVerified: false,
    );

    _authStateController.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<AuthUser> signInAnonymously() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUser = AuthUser(
      uid: 'anon-uid-${DateTime.now().millisecondsSinceEpoch}',
      email: null,
      displayName: 'Guest',
      emailVerified: true,
      isAnonymous: true,
      providerId: 'anonymous',
    );
    _authStateController.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<AuthUser> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final user = _currentUser;
    if (user == null || !user.isAnonymous) {
      throw const AuthFailureException(
        reason: AuthFailureReason.unknown,
        message: 'No anonymous user is currently signed in to link.',
      );
    }
    final normalizedEmail = email.trim();
    if (normalizedEmail.toLowerCase() == 'test@optivus.dev') {
      throw mapAuthError(Exception('email-already-in-use'));
    }
    _currentUser = AuthUser(
      uid: user.uid,
      email: normalizedEmail,
      displayName: name?.trim() ?? user.displayName,
      emailVerified: false,
      isAnonymous: false,
      providerId: 'password',
    );
    _authStateController.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<void> sendEmailVerification() async {
    await Future.delayed(const Duration(milliseconds: 250));
    _verificationEmailSent = true;
  }

  @override
  Future<AuthUser?> reloadCurrentUser() async {
    await Future.delayed(const Duration(milliseconds: 250));
    final user = _currentUser;
    if (user == null) return null;
    if (_verificationEmailSent && !user.emailVerified) {
      _currentUser = AuthUser(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        emailVerified: true,
        isAnonymous: user.isAnonymous,
        providerId: user.providerId,
      );
      _authStateController.add(_currentUser);
    }
    return _currentUser;
  }

  @override
  Future<String?> currentIdToken() async {
    await Future.delayed(const Duration(milliseconds: 80));
    return _currentUser == null ? null : 'fake-firebase-id-token';
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    // Simulated success
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = null;
    _verificationEmailSent = false;
    _authStateController.add(null);
  }
}

class FirebaseAuthRepository implements AuthRepository {
  final firebase_auth.FirebaseAuth _auth;

  FirebaseAuthRepository({firebase_auth.FirebaseAuth? auth})
    : _auth = auth ?? firebase_auth.FirebaseAuth.instance;

  @override
  AuthUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : _authUserFromFirebase(user);
  }

  @override
  Stream<AuthUser?> get authStateChanges {
    return _auth.authStateChanges().map((user) {
      return user == null ? null : _authUserFromFirebase(user);
    });
  }

  @override
  Future<AuthUser> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw firebase_auth.FirebaseAuthException(
          code: 'missing-user',
          message: 'Firebase sign-in did not return a user.',
        );
      }
      return _authUserFromFirebase(user);
    } catch (e) {
      throw mapAuthError(e);
    }
  }

  @override
  Future<AuthUser> signUp(String email, String password, {String? name}) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw firebase_auth.FirebaseAuthException(
          code: 'missing-user',
          message: 'Firebase sign-up did not return a user.',
        );
      }
      final trimmedName = name?.trim();
      if (trimmedName != null && trimmedName.isNotEmpty) {
        await user.updateDisplayName(trimmedName);
        await user.reload();
        final refreshed = _auth.currentUser;
        return refreshed == null
            ? _authUserFromFirebase(user)
            : _authUserFromFirebase(refreshed);
      }
      return _authUserFromFirebase(user);
    } catch (e) {
      throw mapAuthError(e);
    }
  }

  @override
  Future<AuthUser> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      final user = credential.user;
      if (user == null) {
        throw firebase_auth.FirebaseAuthException(
          code: 'missing-user',
          message: 'Firebase anonymous sign-in did not return a user.',
        );
      }
      return _authUserFromFirebase(user);
    } catch (e) {
      throw mapAuthError(e);
    }
  }

  @override
  Future<AuthUser> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw firebase_auth.FirebaseAuthException(
          code: 'missing-user',
          message: 'No anonymous user is currently signed in to link.',
        );
      }
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );
      final result = await user.linkWithCredential(credential);
      final linkedUser = result.user ?? _auth.currentUser!;
      final trimmedName = name?.trim();
      if (trimmedName != null && trimmedName.isNotEmpty) {
        await linkedUser.updateDisplayName(trimmedName);
        await linkedUser.reload();
      }
      final refreshed = _auth.currentUser ?? linkedUser;
      return _authUserFromFirebase(refreshed);
    } catch (e) {
      throw mapAuthError(e);
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw firebase_auth.FirebaseAuthException(
          code: 'missing-user',
          message: 'No signed-in user for email verification.',
        );
      }
      await user.sendEmailVerification();
    } catch (e) {
      throw mapAuthError(e);
    }
  }

  @override
  Future<AuthUser?> reloadCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      await user.reload();
      final refreshed = _auth.currentUser;
      if (refreshed == null) return null;
      await refreshed.getIdToken(true);
      return _authUserFromFirebase(refreshed);
    } catch (e) {
      throw mapAuthError(e);
    }
  }

  @override
  Future<String?> currentIdToken() async {
    try {
      final user = _auth.currentUser;
      return user?.getIdToken(true);
    } catch (e) {
      throw mapAuthError(e);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      throw mapAuthError(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw mapAuthError(e);
    }
  }
}
