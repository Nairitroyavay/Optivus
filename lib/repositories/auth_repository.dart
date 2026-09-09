import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:optivus/core/errors/auth_error_mapper.dart';
import 'package:optivus/core/errors/recoverable_error.dart';

/// A simple user model for authentication purposes.
class AuthUser {
  final String uid;
  final String? email;
  final String? displayName;
  final bool emailVerified;
  final bool isAnonymous;

  /// Every provider currently linked to this Firebase UID.
  ///
  /// Provider ordering is deliberately discarded because Firebase does not
  /// define `providerData` order as an identity or authorization contract.
  final Set<String> providerIds;

  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.emailVerified = false,
    this.isAnonymous = false,
    this.providerIds = const {'password'},
  });

  bool get hasPasswordProvider => providerIds.contains('password');
  bool get hasGoogleProvider => providerIds.contains('google.com');

  /// Password-only accounts require Firebase email verification. A linked
  /// Google provider is a supported Firebase verification fact, so mixed
  /// provider accounts are not classified by whichever provider appears first.
  bool get needsEmailVerification =>
      hasPasswordProvider && !hasGoogleProvider && !emailVerified;

  /// Deterministic legacy display value. Security and routing decisions must
  /// use [providerIds] and the explicit provider helpers above.
  @Deprecated('Use providerIds and explicit provider-membership helpers.')
  String get providerId {
    if (hasGoogleProvider) return 'google.com';
    if (hasPasswordProvider) return 'password';
    if (isAnonymous) return 'anonymous';
    final sortedProviders = providerIds.toList(growable: false)..sort();
    return sortedProviders.isEmpty ? 'password' : sortedProviders.first;
  }
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

/// Optional, non-critical Firebase profile enrichment.
///
/// Account creation and email-verification delivery deliberately do not depend
/// on this capability. Keeping it separate prevents profile metadata work from
/// delaying the first verification email.
abstract interface class AuthProfileEnrichmentRepository {
  Future<void> updateDisplayName({
    required String uid,
    required String displayName,
  });
}

AuthUser _authUserFromFirebase(firebase_auth.User user) {
  return authUserFromProviderFacts(
    uid: user.uid,
    email: user.email,
    displayName: user.displayName,
    emailVerified: user.emailVerified,
    isAnonymous: user.isAnonymous,
    providerIds: user.providerData.map((provider) => provider.providerId),
  );
}

/// Pure provider-data mapping used by Firebase and deterministic unit tests.
@visibleForTesting
AuthUser authUserFromProviderFacts({
  required String uid,
  String? email,
  String? displayName,
  bool emailVerified = false,
  bool isAnonymous = false,
  Iterable<String> providerIds = const <String>[],
}) {
  return AuthUser(
    uid: uid,
    email: email,
    displayName: displayName,
    emailVerified: emailVerified,
    isAnonymous: isAnonymous,
    providerIds: Set<String>.unmodifiable(providerIds),
  );
}

/// Fake implementation of [AuthRepository] for testing and UI development.
/// It uses local state and artificial delays.
class FakeAuthRepository implements AuthRepository {
  final _authStateController = StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;
  bool _verificationEmailSent = false;
  bool signOutShouldFail = false;

  FakeAuthRepository() {
    // Start signed out.
    _authStateController.add(null);
  }

  @override
  Stream<AuthUser?> get authStateChanges => _authStateController.stream;

  @override
  AuthUser? get currentUser => _currentUser;

  /// Deterministic auth-listener control for provider, refresh, and UID-switch
  /// tests without live Firebase.
  @visibleForTesting
  void emitUserForTesting(AuthUser? user) {
    _currentUser = user;
    _authStateController.add(user);
  }

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
      providerIds: {'google.com'},
    );
    _authStateController.add(_currentUser);
    return _currentUser;
  }

  @override
  Future<AuthUser> signUp(String email, String password, {String? name}) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    final normalizedEmail = email.trim();

    if (normalizedEmail.toLowerCase() == 'test@optivus.dev') {
      throw AuthErrorMapper.map(Exception('email-already-in-use'));
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
      providerIds: const {'anonymous'},
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
      throw AuthErrorMapper.map(Exception('missing-user'));
    }
    final normalizedEmail = email.trim();
    if (normalizedEmail.toLowerCase() == 'test@optivus.dev') {
      throw AuthErrorMapper.map(Exception('email-already-in-use'));
    }
    _currentUser = AuthUser(
      uid: user.uid,
      email: normalizedEmail,
      displayName: name?.trim() ?? user.displayName,
      emailVerified: false,
      isAnonymous: false,
      providerIds: const {'password'},
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
        providerIds: user.providerIds,
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
    if (signOutShouldFail) {
      throw AuthErrorMapper.map(Exception('network-request-failed'));
    }
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
        throw AuthErrorMapper.map(Exception('google-sign-in-unavailable'));
      }
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw AuthErrorMapper.map(Exception('auth-token-expired'));
      }
      return idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw error.code == GoogleSignInExceptionCode.interrupted
          ? AuthErrorMapper.map(Exception('network-request-failed'))
          : AuthErrorMapper.map(error);
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

class FirebaseAuthRepository
    implements AuthRepository, AuthProfileEnrichmentRepository {
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
    // Firebase userChanges includes auth, token-refresh, reload, and user
    // metadata notifications. AuthNotifier deliberately treats a same-UID
    // notification with unchanged verification requirements as an in-place
    // metadata refresh, so these broader events never require navigation
    // teardown or a second server reconstruction.
    return _auth.userChanges().map((user) {
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
      throw AuthErrorMapper.map(e);
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
      if (kDebugMode) {
        debugPrint(
          '[EmailVerificationRepository] stage=account_create_started',
        );
      }
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
      if (kDebugMode) {
        debugPrint(
          '[EmailVerificationRepository] stage=account_create_success',
        );
      }
      return _authUserFromFirebase(user);
    } catch (e) {
      throw AuthErrorMapper.map(e);
    }
  }

  @override
  Future<void> updateDisplayName({
    required String uid,
    required String displayName,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.uid != uid) {
        throw firebase_auth.FirebaseAuthException(
          code: 'missing-user',
          message: 'The original signed-in user is no longer available.',
        );
      }
      await user.updateDisplayName(displayName);
    } catch (e) {
      throw AuthErrorMapper.map(e);
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
      throw AuthErrorMapper.map(e);
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
      throw AuthErrorMapper.map(e);
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
      if (kDebugMode) {
        debugPrint('[EmailVerificationRepository] stage=before_firebase_send');
      }
      await user.sendEmailVerification();
      if (kDebugMode) {
        debugPrint('[EmailVerificationRepository] stage=firebase_send_success');
      }
    } catch (e) {
      if (kDebugMode) {
        final mapped = AuthErrorMapper.map(e);
        debugPrint(
          '[EmailVerificationRepository] stage=firebase_send_failure code=${mapped.diagnosticCode}',
        );
      }
      throw AuthErrorMapper.map(e);
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
      return _authUserFromFirebase(refreshed);
    } catch (e) {
      throw AuthErrorMapper.map(e);
    }
  }

  @override
  Future<String?> currentIdToken() async {
    try {
      final user = _auth.currentUser;
      return await user?.getIdToken(true);
    } catch (e) {
      throw AuthErrorMapper.map(e);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      throw AuthErrorMapper.map(e);
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
      throw AuthErrorMapper.map(e);
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

RecoverableError mapGoogleAuthError(Object error) => AuthErrorMapper.map(error);
