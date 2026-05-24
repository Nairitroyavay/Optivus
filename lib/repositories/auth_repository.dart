import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

/// A simple user model for authentication purposes.
class AuthUser {
  final String uid;
  final String? email;
  final String? displayName;

  const AuthUser({required this.uid, this.email, this.displayName});
}

/// Abstract repository interface for authentication.
abstract class AuthRepository {
  Stream<AuthUser?> get authStateChanges;

  Future<AuthUser> signIn(String email, String password);

  Future<AuthUser> signUp(String email, String password, {String? name});

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();
}

AuthUser _authUserFromFirebase(firebase_auth.User user) {
  return AuthUser(
    uid: user.uid,
    email: user.email,
    displayName: user.displayName,
  );
}

/// Fake implementation of [AuthRepository] for testing and UI development.
/// It uses local state and artificial delays.
class FakeAuthRepository implements AuthRepository {
  final _authStateController = StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;

  FakeAuthRepository() {
    // Start signed out.
    _authStateController.add(null);
  }

  @override
  Stream<AuthUser?> get authStateChanges => _authStateController.stream;

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
      );
    } else {
      // Normal fake sign in
      _currentUser = AuthUser(
        uid: 'fake-uid-${DateTime.now().millisecondsSinceEpoch}',
        email: normalizedEmail,
        displayName: normalizedEmail.split('@')[0],
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
    );

    _authStateController.add(_currentUser);
    return _currentUser!;
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
    _authStateController.add(null);
  }
}

class FirebaseAuthRepository implements AuthRepository {
  final firebase_auth.FirebaseAuth _auth;

  FirebaseAuthRepository({firebase_auth.FirebaseAuth? auth})
    : _auth = auth ?? firebase_auth.FirebaseAuth.instance;

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
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<void> signOut() {
    return _auth.signOut();
  }
}
