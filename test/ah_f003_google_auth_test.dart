import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/core/utils/auth_error_mapper.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/services/session_destination_resolver.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/views/screens/auth_choice_screen.dart';
import 'package:optivus/views/screens/login_screen.dart';

const _googleUser = AuthUser(
  uid: 'google-uid',
  email: 'google@example.com',
  displayName: 'Google Person',
  emailVerified: true,
  providerIds: {'google.com'},
);

void main() {
  group('official Google credential flow', () {
    test(
      'exchanges the acquired ID token through a Firebase credential',
      () async {
        final identity = _FakeGoogleIdentityClient('google-id-token');
        firebase_auth.OAuthCredential? exchangedCredential;
        final flow = FirebaseGoogleAuthenticationFlow(
          identityClient: identity,
          exchangeCredential: (credential) async {
            exchangedCredential = credential;
            return _googleUser;
          },
        );

        expect(await flow.signIn(), same(_googleUser));
        expect(identity.authenticateCalls, 1);
        expect(exchangedCredential?.providerId, 'google.com');
        expect(exchangedCredential?.idToken, 'google-id-token');
      },
    );

    test('cancellation never reaches Firebase credential exchange', () async {
      final identity = _FakeGoogleIdentityClient(null);
      var exchangeCalls = 0;
      final flow = FirebaseGoogleAuthenticationFlow(
        identityClient: identity,
        exchangeCredential: (_) async {
          exchangeCalls++;
          return _googleUser;
        },
      );

      expect(await flow.signIn(), isNull);
      expect(exchangeCalls, 0);
    });

    test('provider collision gives a safe explicit linking action', () {
      final mapped = mapGoogleAuthError(
        firebase_auth.FirebaseAuthException(
          code: 'account-exists-with-different-credential',
        ),
      );

      expect(mapped.reason, AuthFailureReason.accountCollision);
      expect(mapped.message, contains('original method'));
      expect(mapped.message, isNot(contains('credential-already-in-use')));
    });
  });

  group('shared notifier flow', () {
    test(
      'new Google user uses normal backend create and destination path',
      () async {
        final auth = _ControlledAuthRepository(() async => _googleUser);
        final profiles = _CountingProfileRepository();
        final onboarding = FakeOnboardingRepository();
        final container = _firebaseContainer(auth, profiles, onboarding);
        addTearDown(container.dispose);
        addTearDown(auth.dispose);
        await _settleInitialSignedOut(container, auth);

        expect(
          await container.read(authProvider.notifier).signInWithGoogle(),
          isTrue,
        );
        await pumpEventQueue(times: 30);

        final state = container.read(authProvider);
        final profile = await profiles.fetchUserProfile(_googleUser.uid);
        expect(state.status, AuthFlowStatus.signedInOnboardingIncomplete);
        expect(
          state.sessionDestination.kind,
          SessionDestinationKind.freshOnboarding,
        );
        expect(profile?.uid, _googleUser.uid);
        expect(profile?.email, _googleUser.email);
        expect(profile?.displayName, _googleUser.displayName);
        expect(profiles.saveCalls, 1);
      },
    );

    test(
      'returning Google user is loaded by UID without overwrite or duplicate',
      () async {
        final auth = _ControlledAuthRepository(() async => _googleUser);
        final profiles = _CountingProfileRepository();
        final existing = UserProfile.empty(
          uid: _googleUser.uid,
          email: 'durable@example.com',
          displayName: 'Durable Name',
        ).copyWith(onboardingStep: 4, updatedAt: DateTime.utc(2026, 8, 1));
        await profiles.saveUserProfile(existing);
        profiles.saveCalls = 0;
        final onboarding = FakeOnboardingRepository();
        await onboarding.saveDraft(_draftAtStep(_googleUser.uid, 4));
        final container = _firebaseContainer(auth, profiles, onboarding);
        addTearDown(container.dispose);
        addTearDown(auth.dispose);
        await _settleInitialSignedOut(container, auth);

        await container.read(authProvider.notifier).signInWithGoogle();
        await pumpEventQueue(times: 30);

        final state = container.read(authProvider);
        final loaded = await profiles.fetchUserProfile(_googleUser.uid);
        expect(state.status, AuthFlowStatus.signedInOnboardingIncomplete);
        expect(state.resumeStep, 4);
        expect(
          state.sessionDestination.kind,
          SessionDestinationKind.resumeOnboarding,
        );
        expect(loaded?.email, 'durable@example.com');
        expect(loaded?.displayName, 'Durable Name');
        expect(profiles.saveCalls, 0);
        expect(profiles.knownUids, {_googleUser.uid});
      },
    );

    test(
      'cancel resets loading, stays signed out, and permits retry',
      () async {
        var cancelled = true;
        final auth = _ControlledAuthRepository(
          () async => cancelled ? null : _googleUser,
        );
        final container = _fakeContainer(auth);
        addTearDown(container.dispose);
        addTearDown(auth.dispose);

        expect(
          await container.read(authProvider.notifier).signInWithGoogle(),
          isFalse,
        );
        expect(container.read(authProvider).status, AuthFlowStatus.signedOut);
        expect(container.read(authProvider).errorMessage, isNull);

        cancelled = false;
        expect(
          await container.read(authProvider.notifier).signInWithGoogle(),
          isTrue,
        );
        await pumpEventQueue(times: 30);
        expect(container.read(authProvider).user?.uid, _googleUser.uid);
        expect(auth.googleCalls, 2);
      },
    );

    test(
      'network failure resets loading and exposes a retryable safe error',
      () async {
        var shouldFail = true;
        final auth = _ControlledAuthRepository(() async {
          if (shouldFail) {
            throw const AuthFailureException(
              reason: AuthFailureReason.networkFailure,
              message: 'Network error. Check your connection and retry.',
            );
          }
          return null;
        });
        final container = _fakeContainer(auth);
        addTearDown(container.dispose);
        addTearDown(auth.dispose);

        await expectLater(
          container.read(authProvider.notifier).signInWithGoogle(),
          throwsA(isA<AuthFailureException>()),
        );
        expect(container.read(authProvider).isLoading, isFalse);
        expect(
          container.read(authProvider).failureReason,
          AuthFailureReason.networkFailure,
        );
        expect(container.read(authProvider).errorMessage, contains('retry'));

        shouldFail = false;
        expect(
          await container.read(authProvider.notifier).signInWithGoogle(),
          isFalse,
        );
        expect(auth.googleCalls, 2);
      },
    );

    test('rapid repeated taps start only one Google request', () async {
      final pending = Completer<AuthUser?>();
      final auth = _ControlledAuthRepository(() => pending.future);
      final container = _fakeContainer(auth);
      addTearDown(container.dispose);
      addTearDown(auth.dispose);

      final first = container.read(authProvider.notifier).signInWithGoogle();
      final second = container.read(authProvider.notifier).signInWithGoogle();
      expect(await second, isFalse);
      expect(auth.googleCalls, 1);
      pending.complete(null);
      expect(await first, isFalse);
      expect(container.read(authProvider).isLoading, isFalse);
    });

    test('Google provider bypasses password-only verification semantics', () {
      const unverifiedProviderFact = AuthUser(
        uid: 'google-provider-fact',
        emailVerified: false,
        providerIds: {'google.com'},
      );
      expect(
        AuthNotifier.statusFor(unverifiedProviderFact, false),
        AuthFlowStatus.signedInOnboardingIncomplete,
      );
    });

    test(
      'logout and a later Google login do not retain the prior owner',
      () async {
        var user = _googleUser;
        final auth = _ControlledAuthRepository(() async => user);
        final container = _fakeContainer(auth);
        addTearDown(container.dispose);
        addTearDown(auth.dispose);

        await container.read(authProvider.notifier).signInWithGoogle();
        await pumpEventQueue(times: 30);
        expect(container.read(authProvider).user?.uid, _googleUser.uid);
        await container.read(authProvider.notifier).logout();
        expect(container.read(authProvider).user, isNull);

        user = const AuthUser(
          uid: 'second-google-uid',
          emailVerified: true,
          providerIds: {'google.com'},
        );
        await container.read(authProvider.notifier).signInWithGoogle();
        await pumpEventQueue(times: 30);
        expect(container.read(authProvider).user?.uid, 'second-google-uid');
        expect(container.read(authProvider).user?.uid, isNot(_googleUser.uid));
      },
    );
  });

  group('auth entry screens', () {
    testWidgets('Auth Choice Google button invokes shared notifier action', (
      tester,
    ) async {
      final auth = _ControlledAuthRepository(() async => null);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(auth)],
          child: const MaterialApp(home: AuthChoiceScreen()),
        ),
      );

      await tester.tap(find.byKey(const Key('auth-choice-google')));
      await tester.pump();
      expect(auth.googleCalls, 1);
      expect(find.byType(AuthChoiceScreen), findsOneWidget);
    });

    testWidgets('Login Google button invokes the same notifier action', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = _ControlledAuthRepository(() async => null);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(auth)],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      await tester.tap(find.byKey(const Key('login-google')));
      await tester.pump();
      expect(auth.googleCalls, 1);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    test('Google UI contains no direct app or onboarding navigation', () {
      for (final path in [
        'lib/views/screens/auth_choice_screen.dart',
        'lib/views/screens/login_screen.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, isNot(contains("go('/app")));
        expect(source, isNot(contains("push('/app")));
        expect(source, isNot(contains("go('/onboarding")));
        expect(source, isNot(contains("push('/onboarding")));
      }
    });

    test(
      'fake repository keeps deterministic Google contract parity',
      () async {
        final repository = FakeAuthRepository();
        addTearDown(repository.signOut);
        final user = await repository.signInWithGoogle();
        expect(user?.uid, 'fake-google-user');
        expect(user?.providerId, 'google.com');
        expect(user?.emailVerified, isTrue);
      },
    );
  });
}

ProviderContainer _fakeContainer(_ControlledAuthRepository auth) {
  return ProviderContainer(
    overrides: [
      optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.fake),
      authRepositoryProvider.overrideWithValue(auth),
    ],
  )..read(authProvider);
}

ProviderContainer _firebaseContainer(
  _ControlledAuthRepository auth,
  ProfileRepository profiles,
  OnboardingRepository onboarding,
) {
  return ProviderContainer(
    overrides: [
      optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.firebase),
      authRepositoryProvider.overrideWithValue(auth),
      profileRepositoryProvider.overrideWithValue(profiles),
      onboardingRepositoryProvider.overrideWithValue(onboarding),
    ],
  )..read(authProvider);
}

Future<void> _settleInitialSignedOut(
  ProviderContainer container,
  _ControlledAuthRepository auth,
) async {
  auth.emit(null);
  await pumpEventQueue(times: 5);
  expect(container.read(authProvider).status, AuthFlowStatus.signedOut);
}

OnboardingDraft _draftAtStep(String uid, int step) {
  final completed = List<bool>.filled(OnboardingDraft.stepCount, false);
  for (var index = 0; index < step; index++) {
    completed[index] = true;
  }
  return OnboardingDraft(
    uid: uid,
    currentStep: step,
    stepCompleted: completed,
    stepDirty: List<bool>.filled(OnboardingDraft.stepCount, false),
    stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 2),
  );
}

class _ControlledAuthRepository implements AuthRepository {
  final Future<AuthUser?> Function() _googleHandler;
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;
  int googleCalls = 0;

  _ControlledAuthRepository(this._googleHandler);

  void emit(AuthUser? user) {
    _currentUser = user;
    _controller.add(user);
  }

  void dispose() => _controller.close();

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Future<AuthUser?> signInWithGoogle() async {
    googleCalls++;
    final user = await _googleHandler();
    if (user != null) emit(user);
    return user;
  }

  @override
  Future<AuthUser> signIn(String email, String password) async =>
      throw UnimplementedError();

  @override
  Future<AuthUser> signUp(
    String email,
    String password, {
    String? name,
  }) async => throw UnimplementedError();

  @override
  Future<AuthUser> signInAnonymously() async => throw UnimplementedError();

  @override
  Future<AuthUser> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async => throw UnimplementedError();

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<AuthUser?> reloadCurrentUser() async => _currentUser;

  @override
  Future<String?> currentIdToken() async =>
      _currentUser == null ? null : 'test-token';

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signOut() async => emit(null);
}

class _FakeGoogleIdentityClient implements GoogleIdentityClient {
  final String? token;
  int authenticateCalls = 0;

  _FakeGoogleIdentityClient(this.token);

  @override
  Future<String?> authenticate() async {
    authenticateCalls++;
    return token;
  }

  @override
  Future<void> signOut() async {}
}

class _CountingProfileRepository extends FakeProfileRepository {
  int saveCalls = 0;
  final Set<String> knownUids = {};

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    saveCalls++;
    knownUids.add(profile.uid);
    await super.saveUserProfile(profile);
  }
}
