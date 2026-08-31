import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/core/router/app_router.dart';
import 'package:optivus/core/utils/auth_error_mapper.dart';
import 'package:optivus/features/recovery/models/onboarding_recovery_models.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/server_reconstructor.dart';
import 'package:optivus/services/session_destination_resolver.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/views/screens/app_shell.dart';
import 'package:optivus/views/screens/loading_screen.dart';

void main() {
  const establishedUser = AuthUser(
    uid: 'established-a',
    email: 'before@example.com',
    displayName: 'Before',
    emailVerified: true,
  );

  group('AH-F008 Router redirect pure logic', () {
    test('A. cold unresolved auth still resolves to loading', () {
      final redirect = optivusAuthRedirect(
        authState: const AuthState(status: AuthFlowStatus.loading),
        userProfile: UserProfile.empty(uid: ''),
        uri: Uri.parse('/app?tab=2'),
      );

      expect(redirect, '/loading');
    });

    test('B. signed out route allows unauthenticated users without loading', () {
      final redirect = optivusAuthRedirect(
        authState: const AuthState(status: AuthFlowStatus.loading),
        userProfile: UserProfile.empty(uid: ''),
        uri: Uri.parse('/login'),
      );

      expect(redirect, isNull);
    });

    test('S. authoritative recovery overrides an authenticated URI', () {
      final redirect = optivusAuthRedirect(
        authState: const AuthState(
          user: establishedUser,
          status: AuthFlowStatus.needsAction,
          startupReasonCode: 'reconstruction_invalidDraft',
        ),
        userProfile: UserProfile.empty(uid: establishedUser.uid),
        uri: Uri.parse('/app?tab=4'),
      );

      expect(redirect, '/onboarding/needs-action');
    });

    test('reconnectRequired overrides an authenticated URI', () {
      final redirect = optivusAuthRedirect(
        authState: const AuthState(
          user: establishedUser,
          status: AuthFlowStatus.reconnectRequired,
          startupReasonCode: 'startup_timeout',
        ),
        userProfile: UserProfile.empty(uid: establishedUser.uid),
        uri: Uri.parse('/app?tab=2'),
      );

      expect(redirect, '/onboarding/reconnect');
    });
  });

  group('AH-F008 Tab and URI Preservation Widget Tests', () {
    testWidgets(
      'E, F, G, H, I, J, K: same-UID refresh preserves every supported tab (0..5) without loading',
      (tester) async {
        final harness = await _pumpEstablishedRouter(tester, establishedUser);
        final visited = <Uri>[];
        void recordLocation() {
          visited.add(harness.uri);
        }

        harness.router.routerDelegate.addListener(recordLocation);
        addTearDown(
          () => harness.router.routerDelegate.removeListener(recordLocation),
        );

        final supportedTabs = const [
          '/app?tab=0',
          '/app?tab=1',
          '/app?tab=2',
          '/app?tab=3',
          '/app?tab=4',
          '/app?tab=5',
        ];

        for (final location in supportedTabs) {
          await harness.go(tester, location);
          final before = Uri.parse(location);
          expect(harness.uri, before);

          // Benign token/metadata refresh 1
          harness.auth.refreshSameUid(
            const AuthUser(
              uid: 'established-a',
              email: 'refreshed@example.com',
              displayName: 'Refreshed metadata',
              emailVerified: true,
              providerIds: {'password'},
            ),
          );

          // Benign token/metadata refresh 2
          harness.auth.refreshSameUid(
            const AuthUser(
              uid: 'established-a',
              email: 'refreshed-again@example.com',
              displayName: 'Refreshed again',
              emailVerified: true,
              providerIds: {'password'},
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          expect(harness.uri, before);
          expect(find.byType(LoadingScreen), findsNothing);
          expect(find.byType(AppShell), findsOneWidget);
          expect(
            harness.container.read(appNavigationProvider),
            int.parse(before.queryParameters['tab']!),
          );
        }

        // Verify that /loading was never visited during refreshes
        expect(visited.where((uri) => uri.path == '/loading'), isEmpty);
        expect(harness.auth.state.user?.email, 'refreshed-again@example.com');
      },
    );

    testWidgets('L. query parameters survive a harmless same-session refresh', (
      tester,
    ) async {
      final harness = await _pumpEstablishedRouter(tester, establishedUser);
      const location = '/app?tab=2&source=notification&filter=all';
      await harness.go(tester, location);

      harness.auth.refreshSameUid(establishedUser);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(harness.uri, Uri.parse(location));
    });

    testWidgets('M. authenticated detail routes survive same-UID refresh', (
      tester,
    ) async {
      final harness = await _pumpEstablishedRouter(tester, establishedUser);

      // Tracker detail route
      await harness.go(tester, '/tracker/money');
      await tester.pump(const Duration(milliseconds: 50));
      expect(harness.uri, Uri.parse('/app?tab=2'));
      expect(harness.container.read(appNavigationProvider), 2);

      harness.auth.refreshSameUid(establishedUser);
      await tester.pump(const Duration(milliseconds: 50));
      expect(harness.uri, Uri.parse('/app?tab=2'));
      expect(harness.container.read(appNavigationProvider), 2);
      expect(find.byType(LoadingScreen), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);

      // Routine detail route
      await harness.go(tester, '/routine/classes');
      await tester.pump(const Duration(milliseconds: 50));
      expect(harness.uri, Uri.parse('/app?tab=1'));
      expect(harness.container.read(appNavigationProvider), 1);

      harness.auth.refreshSameUid(establishedUser);
      await tester.pump(const Duration(milliseconds: 50));
      expect(harness.uri, Uri.parse('/app?tab=1'));
      expect(harness.container.read(appNavigationProvider), 1);
      expect(find.byType(LoadingScreen), findsNothing);

      // Coach detail route
      await harness.go(tester, '/coach/history');
      await tester.pump(const Duration(milliseconds: 50));
      expect(harness.uri, Uri.parse('/app?tab=3'));
      expect(harness.container.read(appNavigationProvider), 3);

      harness.auth.refreshSameUid(establishedUser);
      await tester.pump(const Duration(milliseconds: 50));
      expect(harness.uri, Uri.parse('/app?tab=3'));
      expect(harness.container.read(appNavigationProvider), 3);
      expect(find.byType(LoadingScreen), findsNothing);

      // Goals detail route
      await harness.go(tester, '/goals/settings');
      await tester.pump(const Duration(milliseconds: 50));
      expect(harness.uri, Uri.parse('/app?tab=4'));
      expect(harness.container.read(appNavigationProvider), 4);

      harness.auth.refreshSameUid(establishedUser);
      await tester.pump(const Duration(milliseconds: 50));
      expect(harness.uri, Uri.parse('/app?tab=4'));
      expect(harness.container.read(appNavigationProvider), 4);
      expect(find.byType(LoadingScreen), findsNothing);

      // Profile detail route
      await harness.go(tester, '/profile/edit');
      await tester.pump(const Duration(milliseconds: 50));
      expect(harness.uri, Uri.parse('/app?tab=5'));
      expect(harness.container.read(appNavigationProvider), 5);

      harness.auth.refreshSameUid(establishedUser);
      await tester.pump(const Duration(milliseconds: 50));
      expect(harness.uri, Uri.parse('/app?tab=5'));
      expect(harness.container.read(appNavigationProvider), 5);
      expect(find.byType(LoadingScreen), findsNothing);
    });

    testWidgets('O. logout resets navigation and exits the authenticated route', (
      tester,
    ) async {
      final harness = await _pumpEstablishedRouter(tester, establishedUser);
      await harness.go(tester, '/app?tab=4');
      expect(harness.container.read(appNavigationProvider), 4);

      harness.container.read(appNavigationProvider.notifier).resetForSignedOut();
      await harness.auth.logout();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(harness.uri, Uri.parse('/'));
      expect(harness.container.read(appNavigationProvider), 0);
    });

    testWidgets('Q. account switch does not preserve the previous account URI', (
      tester,
    ) async {
      final harness = await _pumpEstablishedRouter(tester, establishedUser);
      await harness.go(tester, '/app?tab=4');

      final accountB = const AuthUser(uid: 'account-b', emailVerified: true);
      harness.auth.beginIdentitySwitch(accountB);
      harness.container.read(appNavigationProvider.notifier).resetForSignedOut();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(harness.uri, Uri.parse('/loading'));

      harness.auth.completeIdentitySwitch(accountB);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(harness.uri, Uri.parse('/app?tab=0'));
      expect(harness.container.read(appNavigationProvider), 0);
    });

    testWidgets('T. background / resume simulation preserves active route and tab', (
      tester,
    ) async {
      final harness = await _pumpEstablishedRouter(tester, establishedUser);
      await harness.go(tester, '/app?tab=3');
      expect(harness.uri, Uri.parse('/app?tab=3'));
      expect(harness.container.read(appNavigationProvider), 3);

      // Simulate app paused / resumed lifecycle with background token update
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      harness.auth.refreshSameUid(
        const AuthUser(
          uid: 'established-a',
          email: 'before@example.com',
          displayName: 'Before (token refreshed in bg)',
          emailVerified: true,
        ),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(harness.uri, Uri.parse('/app?tab=3'));
      expect(harness.container.read(appNavigationProvider), 3);
      expect(find.byType(LoadingScreen), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('U. repeated refresh stress test causes no route churn or loops', (
      tester,
    ) async {
      final harness = await _pumpEstablishedRouter(tester, establishedUser);
      await harness.go(tester, '/app?tab=2');
      final recordedLocations = <Uri>[];
      void onLocationChanged() => recordedLocations.add(harness.uri);

      harness.router.routerDelegate.addListener(onLocationChanged);
      addTearDown(
        () => harness.router.routerDelegate.removeListener(onLocationChanged),
      );

      // Emit 50 rapid same-UID events
      for (var i = 0; i < 50; i++) {
        harness.auth.refreshSameUid(
          AuthUser(
            uid: 'established-a',
            email: 'user$i@example.com',
            displayName: 'Burst Refresh #$i',
            emailVerified: true,
          ),
        );
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(harness.uri, Uri.parse('/app?tab=2'));
      expect(harness.container.read(appNavigationProvider), 2);
      expect(recordedLocations.where((uri) => uri.path == '/loading'), isEmpty);
      expect(
        recordedLocations.where(
          (uri) => uri.path == '/app' && uri.queryParameters['tab'] != '2',
        ),
        isEmpty,
      );
    });
  });

  group('AH-F008 Real AuthNotifier & Server Reconstruction Integration', () {
    test('B, C, N. Cold start / reinstall runs AH-F007 server reconstruction', () async {
      final authRepo = _StreamableAuthRepository();
      final reconstructor = _CountingServerReconstructor(
        result: _completedResult('uid-reconstruct'),
      );
      final profileRepo = _StubProfileRepository();
      final onboardingRepo = _StubOnboardingRepository();
      final completionService = _StubOnboardingCompletionJobService();

      final container = ProviderContainer(
        overrides: [
          optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.firebase),
          authRepositoryProvider.overrideWithValue(authRepo),
          serverReconstructorProvider.overrideWithValue(reconstructor),
          profileRepositoryProvider.overrideWithValue(profileRepo),
          onboardingRepositoryProvider.overrideWithValue(onboardingRepo),
          onboardingCompletionJobServiceProvider.overrideWithValue(completionService),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(authRepo.dispose);

      // Listen to authProvider to activate notifier
      container.listen(authProvider, (_, _) {});

      // Fresh cold authenticated user emitted
      authRepo.emit(
        const AuthUser(
          uid: 'uid-reconstruct',
          email: 'cold@example.com',
          emailVerified: true,
        ),
      );
      await pumpEventQueue(times: 20);

      // Reconstruction was called exactly once for cold start
      expect(reconstructor.reconstructCallCount, 1);
      expect(container.read(authProvider).status, AuthFlowStatus.signedInOnboardingComplete);
      expect(container.read(authProvider).sessionDestination.kind, SessionDestinationKind.home);
    });

    test('E, V. Same-UID refresh does NOT call server reconstructor', () async {
      final authRepo = _StreamableAuthRepository();
      final reconstructor = _CountingServerReconstructor(
        result: _completedResult('uid-same'),
      );
      final profileRepo = _StubProfileRepository();
      final onboardingRepo = _StubOnboardingRepository();
      final completionService = _StubOnboardingCompletionJobService();

      final container = ProviderContainer(
        overrides: [
          optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.firebase),
          authRepositoryProvider.overrideWithValue(authRepo),
          serverReconstructorProvider.overrideWithValue(reconstructor),
          profileRepositoryProvider.overrideWithValue(profileRepo),
          onboardingRepositoryProvider.overrideWithValue(onboardingRepo),
          onboardingCompletionJobServiceProvider.overrideWithValue(completionService),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(authRepo.dispose);

      container.listen(authProvider, (_, _) {});

      // Initial sign-in / hydration
      authRepo.emit(
        const AuthUser(
          uid: 'uid-same',
          email: 'initial@example.com',
          emailVerified: true,
        ),
      );
      await pumpEventQueue(times: 20);
      expect(reconstructor.reconstructCallCount, 1);

      // Same-UID token refresh
      authRepo.emit(
        const AuthUser(
          uid: 'uid-same',
          email: 'token-refreshed@example.com',
          displayName: 'Updated Name',
          emailVerified: true,
        ),
      );
      await pumpEventQueue(times: 20);

      // Reconstruction must NOT run again on same-UID refresh
      expect(reconstructor.reconstructCallCount, 1);
      expect(container.read(authProvider).user?.email, 'token-refreshed@example.com');
      expect(container.read(authProvider).status, AuthFlowStatus.signedInOnboardingComplete);
    });

    test('R. Email verification transition triggers authoritative reconstruction', () async {
      final authRepo = _StreamableAuthRepository();
      final reconstructor = _CountingServerReconstructor(
        result: _completedResult('uid-verify'),
      );
      final profileRepo = _StubProfileRepository();
      final onboardingRepo = _StubOnboardingRepository();
      final completionService = _StubOnboardingCompletionJobService();

      final container = ProviderContainer(
        overrides: [
          optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.firebase),
          authRepositoryProvider.overrideWithValue(authRepo),
          serverReconstructorProvider.overrideWithValue(reconstructor),
          profileRepositoryProvider.overrideWithValue(profileRepo),
          onboardingRepositoryProvider.overrideWithValue(onboardingRepo),
          onboardingCompletionJobServiceProvider.overrideWithValue(completionService),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(authRepo.dispose);

      container.listen(authProvider, (_, _) {});

      // Step 1: Unverified password user signs in
      authRepo.emit(
        const AuthUser(
          uid: 'uid-verify',
          email: 'unverified@example.com',
          emailVerified: false,
          providerIds: {'password'},
        ),
      );
      await pumpEventQueue(times: 20);
      expect(container.read(authProvider).status, AuthFlowStatus.signedInEmailUnverified);
      expect(container.read(authProvider).sessionDestination.kind, SessionDestinationKind.verifyEmail);
      expect(reconstructor.reconstructCallCount, 0);

      // Step 2: Firebase reloads and emailVerified becomes true
      authRepo.emit(
        const AuthUser(
          uid: 'uid-verify',
          email: 'unverified@example.com',
          emailVerified: true,
          providerIds: {'password'},
        ),
      );
      await pumpEventQueue(times: 20);

      // Reconstruction MUST run because email verification requirement changed
      expect(reconstructor.reconstructCallCount, 1);
      expect(container.read(authProvider).status, AuthFlowStatus.signedInOnboardingComplete);
      expect(container.read(authProvider).sessionDestination.kind, SessionDestinationKind.home);
    });

    test('P. Failed logout preserves authenticated state, reconstruction, and route', () async {
      final authRepo = _StreamableAuthRepository()..signOutShouldFail = true;
      final reconstructor = _CountingServerReconstructor(
        result: _completedResult('uid-logout-fail'),
      );
      final profileRepo = _StubProfileRepository();
      final onboardingRepo = _StubOnboardingRepository();
      final completionService = _StubOnboardingCompletionJobService();

      final container = ProviderContainer(
        overrides: [
          optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.firebase),
          authRepositoryProvider.overrideWithValue(authRepo),
          serverReconstructorProvider.overrideWithValue(reconstructor),
          profileRepositoryProvider.overrideWithValue(profileRepo),
          onboardingRepositoryProvider.overrideWithValue(onboardingRepo),
          onboardingCompletionJobServiceProvider.overrideWithValue(completionService),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(authRepo.dispose);

      container.listen(authProvider, (_, _) {});

      authRepo.emit(
        const AuthUser(
          uid: 'uid-logout-fail',
          email: 'stay@example.com',
          emailVerified: true,
        ),
      );
      await pumpEventQueue(times: 20);
      expect(container.read(authProvider).status, AuthFlowStatus.signedInOnboardingComplete);

      container.read(appNavigationProvider.notifier).goToTracker();
      expect(container.read(appNavigationProvider), 2);

      await expectLater(
        container.read(authProvider.notifier).logout(),
        throwsA(isA<AuthFailureException>()),
      );

      final state = container.read(authProvider);
      expect(state.user?.uid, 'uid-logout-fail');
      expect(state.status, AuthFlowStatus.signedInOnboardingComplete);
      expect(state.sessionDestination.kind, SessionDestinationKind.home);
      expect(state.errorMessage, contains('still signed in'));
      expect(container.read(appNavigationProvider), 2);
    });
  });
}

ReconstructionCompleted _completedResult(String uid) {
  final draft = OnboardingDraft(
    uid: uid,
    currentStep: OnboardingDraft.lastStepIndex,
    stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
    onboardingCompleted: true,
    patiencePledgeAccepted: true,
    lifeRole: const LifeRoleDraft(
      lifeRole: LifeRoleDraft.notStudentNotWorkingKey,
      exerciseLevel: 'moderate',
      waterIntake: 'medium',
      stressLevel: 'medium',
      sleepQuality: 'good',
    ),
    bodyBasics: const BodyBasicsDraft(
      ageRange: '25-34',
      heightCm: 175,
      weightKg: 70,
      gender: 'other',
    ),
    baseTimeline: const BaseTimelineDraft(),
  );
  final profile = UserProfile.empty(uid: uid).copyWith(
    onboardingCompleted: true,
    onboardingInputCompleted: true,
    onboardingProjectionStatus: 'completed',
  );
  final bundle = OnboardingCompletionBundle(
    uid: uid,
    runId: 'run-1',
    createdAt: DateTime.utc(2026, 8, 30),
    updatedAt: DateTime.utc(2026, 8, 30),
    userProfilePatch: const {},
    baseTimelineBlocks: const [],
    finalTimelineItems: const [],
    routineItemsForApp: const [],
    goodHabitTemplates: const [],
    badHabitCheckIns: const [],
    identityGoalSystems: const [],
    notificationPreferences: NotificationPreferences(),
    coachPreferences: CoachPreferences(),
    moneyGoal: null,
    uploadedAssetReferences: const [],
    warnings: const [],
    duplicateSystemKeysMerged: const [],
    sourceFingerprint: draft.effectiveSourceFingerprint,
    draftRevision: draft.revision,
  );
  return ReconstructionCompleted(
    ownerUid: uid,
    profile: profile,
    draft: draft,
    completionBundle: bundle,
  );
}

class _RouterHarness {
  const _RouterHarness(this.container, this.auth);

  final ProviderContainer container;
  final _MutableAuthNotifier auth;

  GoRouter get router => container.read(routerProvider);
  Uri get uri => router.routerDelegate.currentConfiguration.uri;

  Future<void> go(WidgetTester tester, String location) async {
    router.go(location);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<_RouterHarness> _pumpEstablishedRouter(
  WidgetTester tester,
  AuthUser user,
) async {
  final auth = _MutableAuthNotifier(
    AuthState(
      user: user,
      status: AuthFlowStatus.signedInOnboardingComplete,
      reconstructionResult: _completedResult(user.uid),
    ),
  );
  final profile = UserProfile.empty(
    uid: user.uid,
    email: user.email ?? '',
    displayName: user.displayName ?? '',
  ).copyWith(onboardingCompleted: true);
  final container = ProviderContainer(
    overrides: [
      authProvider.overrideWith((ref) => auth),
      mockUserProfileProvider.overrideWith(
        (ref) => MockUserProfileNotifier()..loadSeedData(profile),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, child) =>
            MaterialApp.router(routerConfig: ref.watch(routerProvider)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return _RouterHarness(container, auth);
}

class _MutableAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _MutableAuthNotifier(super.state);

  void refreshSameUid(AuthUser user) {
    assert(user.uid == state.user?.uid);
    state = state.copyWith(user: user);
  }

  void beginIdentitySwitch(AuthUser user) {
    state = AuthState(user: user, status: AuthFlowStatus.loadingBackendUser);
  }

  void completeIdentitySwitch(AuthUser user) {
    state = AuthState(
      user: user,
      status: AuthFlowStatus.signedInOnboardingComplete,
      reconstructionResult: _completedResult(user.uid),
    );
  }

  @override
  Future<void> logout() async {
    state = const AuthState(status: AuthFlowStatus.signedOut);
  }

  @override
  Future<void> acceptCanonicalOnboardingCompletion(AuthUser user) async {}
  @override
  Future<void> checkEmailVerification() async {}
  @override
  Future<void> executeRecoveryAction(OnboardingRecoveryAction action) async {}
  @override
  Future<void> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async {}
  @override
  Future<void> login(String email, String password) async {}
  @override
  Future<void> markOnboardingComplete(AuthUser user) async {}
  @override
  Future<void> markOnboardingIncomplete(AuthUser user) async {}
  @override
  Future<void> resendEmailVerification() async {}
  @override
  Future<void> retryBackendRestore() async {}
  @override
  Future<void> sendPasswordResetEmail(String email) async {}
  @override
  Future<void> signInAnonymously() async {}
  @override
  Future<bool> signInWithGoogle() async => false;
  @override
  Future<void> signup(String name, String email, String password) async {}
}

class _StreamableAuthRepository implements AuthRepository {
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _current;
  bool signOutShouldFail = false;

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  AuthUser? get currentUser => _current;

  void emit(AuthUser? user) {
    _current = user;
    _controller.add(user);
  }

  void dispose() {
    _controller.close();
  }

  @override
  Future<void> signOut() async {
    if (signOutShouldFail) {
      throw const AuthFailureException(
        message: 'Simulated sign out network failure',
        reason: AuthFailureReason.networkFailure,
      );
    }
    emit(null);
  }

  @override
  Future<String?> currentIdToken({bool forceRefresh = false}) async => 'token';

  @override
  Future<AuthUser?> reloadCurrentUser() async => _current;

  @override
  Future<AuthUser> signIn(String email, String password) async =>
      _current ?? AuthUser(uid: 'signed-in', email: email);

  @override
  Future<AuthUser?> signInWithGoogle() async => null;

  @override
  Future<AuthUser> signInAnonymously() async =>
      _current ?? const AuthUser(uid: 'anon-user', isAnonymous: true);

  @override
  Future<AuthUser> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async => AuthUser(uid: _current?.uid ?? 'linked-user', email: email, displayName: name);

  @override
  Future<AuthUser> signUp(String email, String password, {String? name}) async =>
      AuthUser(uid: 'signed-up', email: email, displayName: name);

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}
}

class _CountingServerReconstructor implements ServerReconstructor {
  final ReconstructionResult result;
  int reconstructCallCount = 0;

  _CountingServerReconstructor({required this.result});

  @override
  DateTime Function() get clock => DateTime.now;

  @override
  ServerReconstructionSource get source => throw UnimplementedError();

  @override
  Future<ReconstructionResult> reconstruct({
    required String uid,
    String email = '',
    String displayName = '',
    void Function(UserProfile? profile)? onProfileLoaded,
  }) async {
    reconstructCallCount++;
    if (onProfileLoaded != null) {
      onProfileLoaded(result.profile);
    }
    return result;
  }
}

class _StubProfileRepository extends FakeProfileRepository {
  @override
  Future<UserProfile?> fetchUserProfile(String uid) async =>
      UserProfile.empty(uid: uid).copyWith(onboardingCompleted: true);
}

class _StubOnboardingRepository extends FakeOnboardingRepository {}

class _StubOnboardingCompletionJobService extends OnboardingCompletionJobService {
  _StubOnboardingCompletionJobService()
      : super(
          onboardingRepository: FakeOnboardingRepository(),
          profileRepository: FakeProfileRepository(),
        );
}

