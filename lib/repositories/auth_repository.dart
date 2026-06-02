import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

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
      throw Exception('email-already-in-use');
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
  }

  @override
  Future<AuthUser> signUp(String email, String password, {String? name}) async {
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
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw firebase_auth.FirebaseAuthException(
        code: 'missing-user',
        message: 'No signed-in user for email verification.',
      );
    }
    await user.sendEmailVerification();
  }

  @override
  Future<AuthUser?> reloadCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed == null) return null;
    await refreshed.getIdToken(true);
    return _authUserFromFirebase(refreshed);
  }

  @override
  Future<String?> currentIdToken() async {
    final user = _auth.currentUser;
    return user?.getIdToken(true);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<void> signOut() {
    return _auth.signOut();
  }
}
