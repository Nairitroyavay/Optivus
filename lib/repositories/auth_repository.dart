import 'dart:async';

/// A simple user model for authentication purposes.
class AuthUser {
  final String uid;
  final String? email;
  final String? displayName;

  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
  });
}

/// Abstract repository interface for authentication.
abstract class AuthRepository {
  Stream<AuthUser?> get authStateChanges;
  
  Future<AuthUser> signIn(String email, String password);
  
  Future<AuthUser> signUp(String email, String password, {String? name});
  
  Future<void> sendPasswordResetEmail(String email);
  
  Future<void> signOut();
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

/// TODO: Real Firebase Implementation
///
/// This is a placeholder for the future implementation of [AuthRepository]
/// using Firebase Auth and Cloud Firestore.
/// 
/// It should be implemented in this file or a separate file later when Firebase
/// is connected. DO NOT use [FirebaseAuth.instance] in this task.
/*
class FirebaseAuthRepository implements AuthRepository {
  // final FirebaseAuth _auth;
  // final FirebaseFirestore _firestore;

  // ... Implement methods using Firebase Auth
}
*/
