import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/core/errors/auth_error_mapper.dart';
import 'package:optivus/core/errors/diagnostic_codes.dart';
import 'package:optivus/core/errors/recoverable_error.dart';
import 'package:optivus/core/router/app_router.dart';
import 'package:optivus/core/utils/liquid_toast_manager.dart';
import 'package:optivus/features/coach/providers/coach_navigation_provider.dart';
import 'package:optivus/features/goals/providers/goals_navigation_provider.dart';
import 'package:optivus/features/home/models/home_mind_note.dart';
import 'package:optivus/features/home/providers/home_dashboard_provider.dart';
import 'package:optivus/features/home/providers/home_mind_note_provider.dart';
import 'package:optivus/features/home/providers/home_navigation_provider.dart';
import 'package:optivus/features/profile/providers/profile_navigation_provider.dart';
import 'package:optivus/features/profile/providers/profile_settings_provider.dart';
import 'package:optivus/features/recovery/services/recovery_retry_controller.dart';
import 'package:optivus/features/routine/providers/routine_navigation_provider.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/tracker/fitness/providers/fitness_provider.dart';
import 'package:optivus/features/tracker/providers/tracker_navigation_provider.dart';
import 'package:optivus/features/tracker/providers/tracker_settings_provider.dart';
import 'package:optivus/features/uploads/providers/onboarding_upload_interaction_provider.dart';
import 'package:optivus/features/routine/controllers/habit_systems_controller.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/permission_status.dart';
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/models/tracker_session_link.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/services/auth_session_reset_coordinator.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/session_destination_resolver.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_generation.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/region_settings_provider.dart';
import 'package:optivus/state/upload_state.dart';

const _userA = AuthUser(
  uid: 'gate5-a',
  email: 'a@example.com',
  emailVerified: true,
);
const _userB = AuthUser(
  uid: 'gate5-b',
  email: 'b@example.com',
  emailVerified: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('canonical Auth session destination and router matrix', () {
    const authenticatedUid = 'gate5-user';
    final cases = <AuthFlowStatus, (SessionDestinationKind, String)>{
      AuthFlowStatus.loading: (SessionDestinationKind.resolving, '/loading'),
      AuthFlowStatus.signedOut: (SessionDestinationKind.signedOut, '/'),
      AuthFlowStatus.signedInEmailUnverified: (
        SessionDestinationKind.verifyEmail,
        '/verify-email',
      ),
      AuthFlowStatus.signedInOnboardingIncomplete: (
        SessionDestinationKind.freshOnboarding,
        '/onboarding',
      ),
      AuthFlowStatus.finishingOnboarding: (
        SessionDestinationKind.finishOnboarding,
        '/onboarding/finishing',
      ),
      AuthFlowStatus.signedInOnboardingComplete: (
        SessionDestinationKind.home,
        '/app?tab=0',
      ),
      AuthFlowStatus.reconnectRequired: (
        SessionDestinationKind.reconnect,
        '/onboarding/reconnect',
      ),
      AuthFlowStatus.needsAction: (
        SessionDestinationKind.needsAction,
        '/onboarding/needs-action',
      ),
    };

    for (final entry in cases.entries) {
      final signedOut = entry.key == AuthFlowStatus.signedOut;
      final state = AuthState(
        user: signedOut
            ? null
            : const AuthUser(uid: authenticatedUid, emailVerified: true),
        status: entry.key,
      );
      expect(state.sessionDestination.kind, entry.value.$1);
      expect(
        optivusAuthRedirect(authState: state, uri: Uri.parse('/login')),
        entry.value.$2 == '/' ? isNull : entry.value.$2,
      );
    }

    const resumeState = AuthState(
      user: AuthUser(uid: authenticatedUid, emailVerified: true),
      status: AuthFlowStatus.signedInOnboardingIncomplete,
      resumeStep: 7,
    );
    expect(
      resumeState.sessionDestination,
      isA<SessionDestination>().having(
        (value) => value.resumeStep,
        'resumeStep',
        7,
      ),
    );
  });

  test('destination presentation mapping round-trips semantically', () {
    const destinations = <SessionDestination>[
      SessionDestination.resolving(),
      SessionDestination.signedOut(),
      SessionDestination.verifyEmail(),
      SessionDestination.freshOnboarding(),
      SessionDestination.resumeOnboarding(6),
      SessionDestination.finishOnboarding(runId: 'run-5'),
      SessionDestination.home(),
      SessionDestination.reconnect(reasonCode: 'offline'),
      SessionDestination.needsAction('durable_conflict'),
    ];

    for (final destination in destinations) {
      final status = authFlowStatusForDestination(destination);
      final resolved = resolveAuthSessionDestination(
        status: status,
        userUid: destination.kind == SessionDestinationKind.signedOut
            ? null
            : 'gate5-user',
        resumeStep: destination.resumeStep,
        completionRunId: destination.runId,
        startupReasonCode: destination.reasonCode,
        reconstructionResult: null,
      );
      expect(resolved.kind, destination.kind);
      expect(resolved.resumeStep, destination.resumeStep);
      expect(resolved.runId, destination.runId);
      expect(resolved.reasonCode, destination.reasonCode);
    }
  });

  test('AuthErrorMapper parity exposes safe structured fields', () {
    final cases = <Object, String>{
      Exception('invalid-credential'): DiagnosticCodes.authInvalidCredentials,
      Exception('invalid-email'): DiagnosticCodes.authInvalidEmail,
      Exception('weak-password'): DiagnosticCodes.authWeakPassword,
      Exception('email-already-in-use'): DiagnosticCodes.authEmailInUse,
      Exception('account-exists-with-different-credential'):
          DiagnosticCodes.authAccountCollision,
      Exception('too-many-requests'): DiagnosticCodes.authRateLimited,
      Exception('user-disabled'): DiagnosticCodes.authUserDisabled,
      const SocketException('secret host'): DiagnosticCodes.networkUnavailable,
      TimeoutException('RAW_SECRET_TIMEOUT'): DiagnosticCodes.networkTimeout,
      Exception('invalid-user-token'): DiagnosticCodes.authSessionExpired,
      Exception('requires-recent-login'):
          DiagnosticCodes.authRequiresRecentLogin,
      Exception('RAW_SECRET_UNKNOWN'): DiagnosticCodes.authUnknown,
    };

    for (final entry in cases.entries) {
      final mapped = AuthErrorMapper.map(entry.key);
      expect(mapped.diagnosticCode, entry.value);
      expect(mapped.publicMessage, isNotEmpty);
      expect(mapped.publicMessage, isNot(contains('RAW_SECRET')));
      expect(mapped.toString(), isNot(contains('RAW_SECRET')));
      expect(mapped.retryAction, isA<RecoverableRetryAction>());
    }
  });

  test('Verify Email contextualizes raw and repository-mapped errors', () {
    final cases =
        <
          ({Object input, bool resend}),
          (String, RecoverableErrorCategory, RecoverableRetryAction, bool)
        >{
          (input: const SocketException('RAW_NETWORK_SECRET'), resend: false): (
            DiagnosticCodes.networkUnavailable,
            RecoverableErrorCategory.network,
            RecoverableRetryAction.retry,
            true,
          ),
          (
            input: AuthErrorMapper.map(Exception('network-request-failed')),
            resend: true,
          ): (
            DiagnosticCodes.networkUnavailable,
            RecoverableErrorCategory.network,
            RecoverableRetryAction.retry,
            true,
          ),
          (input: Exception('too-many-requests'), resend: false): (
            DiagnosticCodes.verifyEmailRateLimited,
            RecoverableErrorCategory.authentication,
            RecoverableRetryAction.none,
            false,
          ),
          (
            input: AuthErrorMapper.map(Exception('too-many-requests')),
            resend: true,
          ): (
            DiagnosticCodes.verifyEmailRateLimited,
            RecoverableErrorCategory.authentication,
            RecoverableRetryAction.none,
            false,
          ),
          (input: Exception('invalid-user-token'), resend: false): (
            DiagnosticCodes.verifyEmailSessionExpired,
            RecoverableErrorCategory.authentication,
            RecoverableRetryAction.reauthenticate,
            false,
          ),
          (
            input: AuthErrorMapper.map(Exception('auth-token-expired')),
            resend: true,
          ): (
            DiagnosticCodes.verifyEmailSessionExpired,
            RecoverableErrorCategory.authentication,
            RecoverableRetryAction.reauthenticate,
            false,
          ),
          (input: Exception('RAW_UNKNOWN_CHECK_SECRET'), resend: false): (
            DiagnosticCodes.verifyEmailCheckFailed,
            RecoverableErrorCategory.authentication,
            RecoverableRetryAction.retry,
            true,
          ),
          (
            input: AuthErrorMapper.map(Exception('RAW_UNKNOWN_RESEND_SECRET')),
            resend: true,
          ): (
            DiagnosticCodes.verifyEmailResendFailed,
            RecoverableErrorCategory.authentication,
            RecoverableRetryAction.retry,
            true,
          ),
        };

    for (final entry in cases.entries) {
      final mapped = AuthErrorMapper.mapVerifyEmailError(
        entry.key.input,
        isResend: entry.key.resend,
      );
      expect(mapped.diagnosticCode, entry.value.$1);
      expect(mapped.category, entry.value.$2);
      expect(mapped.retryAction, entry.value.$3);
      expect(mapped.retrySafe, entry.value.$4);
      expect(mapped.isBlocking, isTrue);
      expect(mapped.publicMessage, isNot(contains('RAW_')));
      if (mapped.diagnosticCode == DiagnosticCodes.verifyEmailSessionExpired) {
        expect(mapped.publicMessage.toLowerCase(), contains('sign in again'));
      }
    }
  });

  test(
    'A to B clears the six-area matrix before first B publication',
    () async {
      final repository = FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [
          optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.fake),
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      container.read(authProvider);
      repository.emitUserForTesting(_userA);
      await pumpEventQueue(times: 30);
      await _seedAccountAState(container);
      final generationA = container.read(authGenerationProvider);
      final completionServiceA = container.read(
        onboardingCompletionJobServiceProvider,
      );
      final uploadInteractionA = container.read(
        onboardingUploadInteractionProvider.notifier,
      );

      var observedB = false;
      final subscription = container.listen<AuthState>(authProvider, (_, next) {
        if (observedB || next.user?.uid != _userB.uid) return;
        observedB = true;
        _expectUserStateCleared(container);
        expect(
          container.read(authGenerationProvider),
          greaterThan(generationA),
        );
        expect(
          container.read(onboardingCompletionJobServiceProvider),
          isNot(same(completionServiceA)),
        );
        expect(
          container.read(onboardingUploadInteractionProvider.notifier),
          isNot(same(uploadInteractionA)),
        );
        expect(
          container.read(optivusBackendModeProvider),
          OptivusBackendMode.fake,
        );
      });
      addTearDown(subscription.close);

      repository.emitUserForTesting(_userB);
      await pumpEventQueue(times: 30);
      expect(observedB, isTrue);
      expect(container.read(authProvider).user?.uid, _userB.uid);
      expect(container.read(userProfileProvider).uid, _userB.uid);
      expect(container.read(onboardingStateProvider).draft.uid, _userB.uid);
    },
  );

  test('reset coordinator is the synchronous privacy boundary', () async {
    final repository = FakeAuthRepository();
    final container = _gate5Container(repository);
    addTearDown(container.dispose);
    repository.emitUserForTesting(_userA);
    await pumpEventQueue(times: 30);
    await _seedAccountAState(container);
    final generationA = container.read(authGenerationProvider);
    final completionServiceA = container.read(
      onboardingCompletionJobServiceProvider,
    );

    container.read(authSessionResetCoordinatorProvider).resetIdentityBoundary();

    _expectUserStateCleared(container);
    expect(container.read(authGenerationProvider), generationA + 1);
    expect(
      container.read(onboardingCompletionJobServiceProvider),
      isNot(same(completionServiceA)),
    );
    expect(container.read(optivusBackendModeProvider), OptivusBackendMode.fake);
  });

  test('successful sign out clears the complete matrix', () async {
    final repository = FakeAuthRepository();
    final container = _gate5Container(repository);
    addTearDown(container.dispose);
    repository.emitUserForTesting(_userA);
    await pumpEventQueue(times: 30);
    await _seedAccountAState(container);

    await container.read(authProvider.notifier).logout();

    expect(container.read(authProvider).status, AuthFlowStatus.signedOut);
    _expectUserStateCleared(container);
    expect(container.read(optivusBackendModeProvider), OptivusBackendMode.fake);
  });

  test('failed sign out preserves the complete A matrix', () async {
    final repository = FakeAuthRepository()..signOutShouldFail = true;
    final container = _gate5Container(repository);
    addTearDown(container.dispose);
    repository.emitUserForTesting(_userA);
    await pumpEventQueue(times: 30);
    await _seedAccountAState(container);
    final generationA = container.read(authGenerationProvider);

    await expectLater(
      container.read(authProvider.notifier).logout(),
      throwsA(isA<RecoverableError>()),
    );

    expect(container.read(authProvider).user?.uid, _userA.uid);
    expect(
      container.read(authProvider).errorMessage,
      contains('still signed in'),
    );
    _expectAccountAStatePresent(container);
    expect(container.read(authGenerationProvider), generationA);
  });

  test('same-UID refresh preserves the complete A matrix', () async {
    final repository = FakeAuthRepository();
    final container = _gate5Container(repository);
    addTearDown(container.dispose);
    repository.emitUserForTesting(_userA);
    await pumpEventQueue(times: 30);
    await _seedAccountAState(container);
    final generationA = container.read(authGenerationProvider);

    repository.emitUserForTesting(
      const AuthUser(
        uid: 'gate5-a',
        email: 'refreshed-a@example.com',
        emailVerified: true,
        providerIds: {'password', 'google.com'},
      ),
    );
    await pumpEventQueue(times: 10);

    _expectAccountAStatePresent(container);
    expect(container.read(authProvider).user?.email, 'refreshed-a@example.com');
    expect(container.read(authGenerationProvider), generationA);
  });

  test('late Account A async completion does not mutate Account B', () async {
    final repository = FakeAuthRepository();
    final onboardingRepo = FakeOnboardingRepository();
    final profileRepo = FakeProfileRepository();
    final container = ProviderContainer(
      overrides: [
        optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.fake),
        authRepositoryProvider.overrideWithValue(repository),
        onboardingRepositoryProvider.overrideWithValue(onboardingRepo),
        profileRepositoryProvider.overrideWithValue(profileRepo),
      ],
    );
    addTearDown(container.dispose);

    container.read(authProvider);
    repository.emitUserForTesting(_userA);
    await pumpEventQueue(times: 20);

    final genA = container.read(authGenerationProvider);

    // Save initial Account B state in repositories
    final initialBDraft = OnboardingDraft(uid: _userB.uid, currentStep: 2);
    await onboardingRepo.saveDraft(initialBDraft);
    final initialBProfile = UserProfile.empty(
      uid: _userB.uid,
    ).copyWith(displayName: 'User B Real');
    await profileRepo.saveUserProfile(initialBProfile);

    // Account switch A -> B occurs
    repository.emitUserForTesting(_userB);
    await pumpEventQueue(times: 20);

    final genB = container.read(authGenerationProvider);
    expect(genB, greaterThan(genA));
    expect(container.read(authProvider).user?.uid, _userB.uid);
    expect(container.read(userProfileProvider).uid, _userB.uid);

    // Now simulate late Account A completion arriving into repos
    await onboardingRepo.saveDraft(
      OnboardingDraft(uid: _userA.uid, currentStep: 8),
    );
    await profileRepo.saveUserProfile(
      UserProfile.empty(uid: _userA.uid).copyWith(displayName: 'Late User A'),
    );
    await pumpEventQueue(times: 20);

    // B state is not mutated by late A data
    expect(container.read(authProvider).user?.uid, _userB.uid);
    expect(container.read(userProfileProvider).uid, _userB.uid);
    expect(
      container.read(userProfileProvider).displayName,
      isNot('Late User A'),
    );
    expect(container.read(onboardingStateProvider).draft.uid, _userB.uid);
    expect(container.read(onboardingStateProvider).draft.currentStep, isNot(8));
    expect(
      container
          .read(routineNotifierProvider)
          .items
          .any((i) => i.userId == _userA.uid),
      isFalse,
    );
    expect(
      container
          .read(habitSystemsNotifierProvider)
          .systems
          .any((s) => s.ownerUid == _userA.uid),
      isFalse,
    );
    expect(container.read(uploadControllerProvider).uid, isNot(_userA.uid));
    expect(container.read(restoredUploadsProvider).uid, isNot(_userA.uid));
    expect(
      container.read(authProvider).sessionDestination.kind,
      isNot(SessionDestinationKind.signedOut),
    );
  });
}

ProviderContainer _gate5Container(FakeAuthRepository repository) {
  return ProviderContainer(
    overrides: [
      optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.fake),
      authRepositoryProvider.overrideWithValue(repository),
    ],
  )..read(authProvider);
}

Future<void> _seedAccountAState(ProviderContainer container) async {
  container
      .read(userProfileProvider.notifier)
      .loadSeedData(
        UserProfile.empty(uid: _userA.uid).copyWith(displayName: 'Private A'),
      );
  container.read(profileSettingsProvider.notifier).toggleDeleteScope('A-only');
  container.read(homeDashboardProvider.notifier).cycleNowNextState();
  container
      .read(homeMindNoteProvider.notifier)
      .addNote(
        'Private A note',
        MindNoteType.overthinking,
        MindNoteIntensity.high,
      );
  container.read(routineNotifierProvider.notifier).toggleFullDay(true);
  container.read(mockRoutineProvider.notifier).loadSeedData();
  container.read(mockTrackerProvider.notifier).loadSeedData();
  container.read(fitnessCenterProvider.notifier).startSelectedActivity();
  container.read(trackerSettingsProvider.notifier).activateTracker('Nutrition');
  container.read(mockCoachProvider.notifier).loadSeedData();
  container
      .read(mockCoachPreferencesProvider.notifier)
      .updatePreferences(CoachPreferences(name: 'Private A Coach'));
  container.read(mockGoalProvider.notifier).loadSeedData();
  container
      .read(onboardingStateProvider.notifier)
      .loadSeedData(OnboardingDraft(uid: _userA.uid, currentStep: 7));
  await container
      .read(restoredUploadsProvider.notifier)
      .hydrate(uid: _userA.uid);
  await container
      .read(uploadControllerProvider.notifier)
      .startUpload(
        uid: _userA.uid,
        purpose: UploadedAssetPurpose.profilePhoto,
        sourceFeature: 'gate5-test',
      );
  container.read(onboardingUploadInteractionProvider);
  container
      .read(regionSettingsProvider.notifier)
      .loadSettings(
        RegionSettings.forCountry(userId: _userA.uid, countryCode: 'GB'),
      );
  container.read(appNavigationProvider.notifier).goToProfile();
  container.read(homeDetailViewRequestProvider.notifier).state =
      const HomeDetailTarget.mission();
  container.read(trackerDetailViewRequestProvider.notifier).state =
      TrackerDetailTarget.view(TrackerDetailView.fitness);
  container.read(profileDetailViewRequestProvider.notifier).state =
      const ProfileDetailTarget(view: ProfileDetailView.editProfile);
  container.read(routineDetailViewRequestProvider.notifier).state =
      const RoutineDetailTarget(view: RoutineDetailView.routineSettings);
  container.read(coachDetailViewRequestProvider.notifier).state =
      CoachDetailView.coachSettings;
  container.read(goalsDetailViewRequestProvider.notifier).state =
      const GoalsDetailTarget(view: GoalsDetailView.weeklyReview);
  container
      .read(recoveryRetryControllerProvider.notifier)
      .recordAttemptAndStartCooldown();
  container.read(toastQueueProvider.notifier).showToast('Private A toast');
  container
      .read(trackerSessionLinksProvider.notifier)
      .upsert(
        const TrackerSessionLink(
          routineTaskId: 'task-a',
          trackerType: 'workout',
        ),
      );
  container.read(mockMindNoteProvider.notifier).loadSeedData();
  container
      .read(mockNotificationPreferencesProvider.notifier)
      .updatePreferences(NotificationPreferences(morningStart: true));
  container
      .read(mockPermissionProvider.notifier)
      .toggleNotificationPermission();
  container.read(aiRoutineSuggestionsEnabledProvider.notifier).state = false;
  container.read(conflictResolverEnabledProvider.notifier).state = false;
  container.read(routineNotificationsEnabledProvider.notifier).state = false;
}

void _expectUserStateCleared(ProviderContainer container) {
  expect(container.read(userProfileProvider).uid, isNot(_userA.uid));
  expect(container.read(profileSettingsProvider).selectedDeleteScopes, isEmpty);
  expect(container.read(homeDashboardProvider).nowNextAction, isNull);
  expect(container.read(homeMindNoteProvider), isEmpty);
  expect(container.read(routineNotifierProvider).showFullDay, isFalse);
  expect(container.read(mockRoutineProvider), isEmpty);
  expect(container.read(mockTrackerProvider).trackerSessions, isEmpty);
  expect(container.read(fitnessCenterProvider).activeActivity, isNull);
  expect(
    container.read(trackerSettingsProvider).activeTrackers['Nutrition'],
    isFalse,
  );
  expect(container.read(mockCoachProvider), isEmpty);
  expect(container.read(mockCoachPreferencesProvider).name, 'Coach');
  expect(container.read(mockGoalProvider), isEmpty);
  expect(container.read(onboardingStateProvider).draft.uid, isNot(_userA.uid));
  expect(container.read(restoredUploadsProvider).uid, isNull);
  expect(container.read(uploadControllerProvider).uid, isNull);
  expect(container.read(regionSettingsProvider).userId, 'signed-out');
  expect(container.read(appNavigationProvider), 0);
  expect(
    container.read(homeDetailViewRequestProvider).view,
    HomeDetailView.none,
  );
  expect(
    container.read(trackerDetailViewRequestProvider).view,
    TrackerDetailView.none,
  );
  expect(
    container.read(profileDetailViewRequestProvider).view,
    ProfileDetailView.none,
  );
  expect(
    container.read(routineDetailViewRequestProvider).view,
    RoutineDetailView.none,
  );
  expect(container.read(coachDetailViewRequestProvider), CoachDetailView.none);
  expect(
    container.read(goalsDetailViewRequestProvider).view,
    GoalsDetailView.none,
  );
  expect(container.read(recoveryRetryControllerProvider).attemptCount, 0);
  expect(container.read(toastQueueProvider).current, isNull);
  expect(container.read(trackerSessionLinksProvider), isEmpty);
  expect(container.read(mockMindNoteProvider), isEmpty);
  expect(
    container.read(mockNotificationPreferencesProvider).morningStart,
    isFalse,
  );
  expect(
    container.read(mockPermissionProvider).notifications,
    PermissionConnectionState.notConnected,
  );
  expect(container.read(aiRoutineSuggestionsEnabledProvider), isTrue);
  expect(container.read(conflictResolverEnabledProvider), isTrue);
  expect(container.read(routineNotificationsEnabledProvider), isTrue);
}

void _expectAccountAStatePresent(ProviderContainer container) {
  expect(container.read(userProfileProvider).displayName, 'Private A');
  expect(container.read(profileSettingsProvider).selectedDeleteScopes, {
    'A-only',
  });
  expect(container.read(homeDashboardProvider).nowNextAction, isNotNull);
  expect(container.read(homeMindNoteProvider), isNotEmpty);
  expect(container.read(routineNotifierProvider).showFullDay, isTrue);
  expect(container.read(mockRoutineProvider), isNotEmpty);
  expect(container.read(mockTrackerProvider).trackerSessions, isNotEmpty);
  expect(container.read(fitnessCenterProvider).activeActivity, isNotNull);
  expect(
    container.read(trackerSettingsProvider).activeTrackers['Nutrition'],
    isTrue,
  );
  expect(container.read(mockCoachProvider), isNotEmpty);
  expect(container.read(mockCoachPreferencesProvider).name, 'Private A Coach');
  expect(container.read(mockGoalProvider), isNotEmpty);
  expect(container.read(onboardingStateProvider).draft.uid, _userA.uid);
  expect(container.read(restoredUploadsProvider).uid, _userA.uid);
  expect(container.read(uploadControllerProvider).uid, _userA.uid);
  expect(container.read(regionSettingsProvider).userId, _userA.uid);
  expect(container.read(appNavigationProvider), 5);
  expect(
    container.read(homeDetailViewRequestProvider).view,
    HomeDetailView.missionDetail,
  );
  expect(
    container.read(trackerDetailViewRequestProvider).view,
    TrackerDetailView.fitness,
  );
  expect(
    container.read(profileDetailViewRequestProvider).view,
    ProfileDetailView.editProfile,
  );
  expect(
    container.read(routineDetailViewRequestProvider).view,
    RoutineDetailView.routineSettings,
  );
  expect(
    container.read(coachDetailViewRequestProvider),
    CoachDetailView.coachSettings,
  );
  expect(
    container.read(goalsDetailViewRequestProvider).view,
    GoalsDetailView.weeklyReview,
  );
  expect(container.read(recoveryRetryControllerProvider).attemptCount, 1);
  expect(
    container.read(toastQueueProvider).current?.message,
    'Private A toast',
  );
  expect(container.read(trackerSessionLinksProvider), isNotEmpty);
  expect(container.read(mockMindNoteProvider), isNotEmpty);
  expect(
    container.read(mockNotificationPreferencesProvider).morningStart,
    isTrue,
  );
  expect(
    container.read(mockPermissionProvider).notifications,
    PermissionConnectionState.mockConnected,
  );
  expect(container.read(aiRoutineSuggestionsEnabledProvider), isFalse);
  expect(container.read(conflictResolverEnabledProvider), isFalse);
  expect(container.read(routineNotificationsEnabledProvider), isFalse);
}
