import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  /// Starts the native Google flow. A null result means the user cancelled.
  Future<AuthUser?> signInWithGoogle();

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
  final providerIds = user.providerData
      .map((provider) => provider.providerId)
      .toSet();
  // A Firebase account can expose more than one linked provider. Prefer the
  // trusted Google provider so a Google-authenticated account is never treated
  // as an unverified password-only account because of provider list ordering.
  final providerId = providerIds.contains('google.com')
      ? 'google.com'
      : providerIds.contains('password')
      ? 'password'
      : (providerIds.isNotEmpty ? providerIds.first : 'password');

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
  Future<AuthUser?> signInWithGoogle() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUser = const AuthUser(
      uid: 'fake-google-user',
      email: 'google.user@example.com',
      displayName: 'Google User',
      emailVerified: true,
      providerId: 'google.com',
    );
    _authStateController.add(_currentUser);
    return _currentUser;
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

/// Small injectable boundary around the official native Google SDK.
abstract class GoogleIdentityClient {
  /// Returns a Google ID token, or null when the account chooser is cancelled.
  Future<String?> authenticate();

  Future<void> signOut();
}

class NativeGoogleIdentityClient implements GoogleIdentityClient {
  final GoogleSignIn _googleSignIn;
  static Future<void>? _sharedInitialization;

  NativeGoogleIdentityClient({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  Future<void> _ensureInitialized() {
    // google_sign_in 7.x requires initialize to be invoked exactly once.
    return _sharedInitialization ??= _googleSignIn.initialize();
  }

  @override
  Future<String?> authenticate() async {
    try {
      await _ensureInitialized();
      if (!_googleSignIn.supportsAuthenticate()) {
        throw const AuthFailureException(
          reason: AuthFailureReason.unknown,
          message: 'Google sign-in is unavailable on this device.',
        );
      }
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthFailureException(
          reason: AuthFailureReason.invalidToken,
          message: 'Google sign-in could not be completed. Please try again.',
        );
      }
      return idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw AuthFailureException(
        reason: error.code == GoogleSignInExceptionCode.interrupted
            ? AuthFailureReason.networkFailure
            : AuthFailureReason.unknown,
        message: error.code == GoogleSignInExceptionCode.interrupted
            ? 'Google sign-in was interrupted. Please try again.'
            : 'Google sign-in could not be completed. Please try again.',
        originalError: error,
      );
    }
  }

  @override
  Future<void> signOut() async {
    await _ensureInitialized();
    await _googleSignIn.signOut();
  }
}

typedef GoogleCredentialExchange =
    Future<AuthUser> Function(firebase_auth.OAuthCredential credential);

/// Acquires a Google ID token and exchanges it for a Firebase-owned identity.
/// Keeping this boundary injectable makes OAuth deterministic in unit tests
/// without bypassing the real production credential construction.
class FirebaseGoogleAuthenticationFlow {
  final GoogleIdentityClient _identityClient;
  final GoogleCredentialExchange _exchangeCredential;

  FirebaseGoogleAuthenticationFlow({
    required GoogleIdentityClient identityClient,
    required GoogleCredentialExchange exchangeCredential,
  }) : _identityClient = identityClient,
       _exchangeCredential = exchangeCredential;

  Future<AuthUser?> signIn() async {
    try {
      final idToken = await _identityClient.authenticate();
      if (idToken == null) return null;
      final credential = firebase_auth.GoogleAuthProvider.credential(
        idToken: idToken,
      );
      return await _exchangeCredential(credential);
    } catch (error) {
      throw mapGoogleAuthError(error);
    }
  }
}

class FirebaseAuthRepository implements AuthRepository {
  final firebase_auth.FirebaseAuth _auth;
  final GoogleIdentityClient _googleIdentityClient;
  late final FirebaseGoogleAuthenticationFlow _googleAuthenticationFlow;

  FirebaseAuthRepository({
    firebase_auth.FirebaseAuth? auth,
    GoogleIdentityClient? googleIdentityClient,
  }) : _auth = auth ?? firebase_auth.FirebaseAuth.instance,
       _googleIdentityClient =
           googleIdentityClient ?? NativeGoogleIdentityClient() {
    _googleAuthenticationFlow = FirebaseGoogleAuthenticationFlow(
      identityClient: _googleIdentityClient,
      exchangeCredential: _exchangeGoogleCredential,
    );
  }

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
  Future<AuthUser?> signInWithGoogle() {
    return _googleAuthenticationFlow.signIn();
  }

  Future<AuthUser> _exchangeGoogleCredential(
    firebase_auth.OAuthCredential googleCredential,
  ) async {
    final credential = await _auth.signInWithCredential(googleCredential);
    final user = credential.user;
    if (user == null) {
      throw firebase_auth.FirebaseAuthException(
        code: 'missing-user',
        message: 'Firebase Google sign-in did not return a user.',
      );
    }
    return _authUserFromFirebase(user);
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
      return await user?.getIdToken(true);
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
    final hadGoogleProvider =
        _auth.currentUser?.providerData.any(
          (provider) => provider.providerId == 'google.com',
        ) ??
        false;
    try {
      await _auth.signOut();
    } catch (e) {
      throw mapAuthError(e);
    }
    if (hadGoogleProvider) {
      try {
        await _googleIdentityClient.signOut();
      } catch (error) {
        // Firebase is already signed out. Keep local logout authoritative and
        // log only the error type; Google/OAuth token values are never logged.
        debugPrint(
          'Google sign-out cleanup failed safely (${error.runtimeType}).',
        );
      }
    }
  }
}

AuthFailureException mapGoogleAuthError(Object error) {
  if (error is AuthFailureException) return error;
  if (error is firebase_auth.FirebaseAuthException) {
    if (error.code == 'account-exists-with-different-credential' ||
        error.code == 'credential-already-in-use') {
      return AuthFailureException(
        reason: AuthFailureReason.accountCollision,
        message:
            'An account already exists with this email. Sign in with your original method to continue; it cannot be merged from Google sign-in.',
        originalError: error,
      );
    }
    final mapped = mapAuthError(error);
    if (mapped.reason != AuthFailureReason.unknown &&
        error.code != 'invalid-credential') {
      return mapped;
    }
  }
  return AuthFailureException(
    reason: AuthFailureReason.unknown,
    message: 'Google sign-in could not be completed. Please try again.',
    originalError: error,
  );
}
