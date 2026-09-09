import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/core/errors/recoverable_error.dart';
import 'package:optivus/features/home/providers/home_dashboard_provider.dart';
import 'package:optivus/features/routine/controllers/habit_systems_controller.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/tracker/fitness/providers/fitness_provider.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/conflict_acceptance.dart';
import 'package:optivus/models/goal_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/app_preferences_repository.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/conflict_acceptance_repository.dart';
import 'package:optivus/repositories/fake_habit_systems_repository.dart';
import 'package:optivus/repositories/habit_systems_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/repositories/region_settings_repository.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/server_reconstructor.dart';
import 'package:optivus/services/session_destination_resolver.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_generation.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/region_settings_provider.dart';
import 'package:optivus/state/upload_state.dart';
import 'package:optivus/state/verification_lifecycle_state.dart';
import 'package:optivus/views/screens/verify_email_screen.dart';

/// Controllable reconstruction source implementing [ServerReconstructionSource]
/// for deterministic async race and account-switch testing.
class CompleterServerReconstructionSource
    implements ServerReconstructionSource {
  final Map<String, Completer<ServerReconstructionSnapshot>> _completers = {};
  final List<String> loadCalls = [];
  final List<UserProfile> createdProfileShells = [];

  Completer<ServerReconstructionSnapshot> completerFor(String uid) {
    return _completers.putIfAbsent(
      uid,
      () => Completer<ServerReconstructionSnapshot>(),
    );
  }

  bool hasPendingLoad(String uid) =>
      _completers.containsKey(uid) && !_completers[uid]!.isCompleted;

  /// Resiliently pumps the event queue until [load] has been entered for [uid]
  /// and is awaiting completer resolution.
  Future<void> waitForPendingLoad(
    String uid, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final stopwatch = Stopwatch()..start();
    while (!hasPendingLoad(uid)) {
      if (stopwatch.elapsed > timeout) {
        throw TimeoutException(
          'Timed out waiting for pending load for $uid after ${stopwatch.elapsed}',
        );
      }
      await pumpEventQueue(times: 5);
    }
  }

  @override
  Future<ServerReconstructionSnapshot> load(
    String uid, {
    void Function(UserProfile? profile)? onProfileLoaded,
  }) async {
    loadCalls.add(uid);
    final snapshot = await completerFor(uid).future;
    onProfileLoaded?.call(snapshot.profile);
    return snapshot;
  }

  @override
  Future<void> createProfileShell(UserProfile profile) async {
    createdProfileShells.add(profile);
  }
}

class _TestConflictAcceptanceRepository
    implements ConflictAcceptanceRepository {
  @override
  Future<List<ConflictAcceptance>> fetchForOwner(String uid) async => const [];

  @override
  Future<void> upsert(String uid, ConflictAcceptance acceptance) async {}
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.repository, super.ref, AuthState initialState) {
    state = initialState;
  }
}

const _userA = AuthUser(
  uid: 'gate5-user-a',
  email: 'a@example.com',
  emailVerified: true,
);

const _userB = AuthUser(
  uid: 'gate5-user-b',
  email: 'b@example.com',
  emailVerified: true,
);

const _userUnverified = AuthUser(
  uid: 'gate5-user-unverified',
  email: 'unverified@example.com',
  emailVerified: false,
);

OnboardingDraft _validDraftAtStep(String uid, int step) {
  final completed = List<bool>.filled(OnboardingDraft.stepCount, false);
  for (var index = 0; index < step; index++) {
    completed[index] = true;
  }
  const base = BaseTimelineDraft(
    eatingSetupPath: 'skip',
    eatingMode: 'flat',
    shouldPlanMeals: false,
    skinCareSkipped: true,
    blocks: [
      TimelineBlockDraft(
        id: BaseTimelineDraft.fixedSleepId,
        section: 'fixed',
        title: 'Sleep',
        startMinute: 1380,
        endMinute: 420,
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.hardBlockKey,
        crossesMidnight: true,
      ),
      TimelineBlockDraft(
        id: BaseTimelineDraft.fixedBathId,
        section: 'fixed',
        title: 'Bath',
        startMinute: 430,
        endMinute: 460,
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
      TimelineBlockDraft(
        id: 'meal',
        section: 'eating',
        title: 'Lunch',
        startMinute: 720,
        endMinute: 750,
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
    ],
  );
  return OnboardingDraft(
    uid: uid,
    currentStep: step,
    stepCompleted: completed,
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
    baseTimeline: base,
  );
}

OnboardingDraft _finalDraft(String uid) {
  return _validDraftAtStep(uid, OnboardingDraft.lastStepIndex).copyWith(
    currentStep: OnboardingDraft.lastStepIndex,
    stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
    onboardingCompleted: true,
    incrementRevision: false,
  );
}

ServerReconstructionSnapshot _incompleteSnapshot({
  required String uid,
  required String displayName,
  int step = 3,
}) {
  final draft = _validDraftAtStep(uid, step);
  final profile = UserProfile.empty(uid: uid).copyWith(
    displayName: displayName,
    createdAt: DateTime.utc(2026, 8, 30),
    updatedAt: DateTime.utc(2026, 8, 30),
  );
  return ServerReconstructionSnapshot(
    profile: profile,
    draft: draft,
    completionBundle: null,
    currentRun: const OnboardingCurrentRunSnapshot.none(),
  );
}

ServerReconstructionSnapshot _completedSnapshot({
  required String uid,
  required String displayName,
}) {
  final draft = _finalDraft(uid);
  final bundle = OnboardingCompletionBundle(
    uid: uid,
    runId: 'run-$uid',
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
  final profile = UserProfile.empty(uid: uid).copyWith(
    displayName: displayName,
    onboardingCompleted: true,
    createdAt: DateTime.utc(2026, 8, 30),
    updatedAt: DateTime.utc(2026, 8, 30),
  );
  return ServerReconstructionSnapshot(
    profile: profile,
    draft: draft,
    completionBundle: bundle,
    currentRun: const OnboardingCurrentRunSnapshot.none(),
  );
}

ProviderContainer _buildReconstructionContainer({
  required CompleterServerReconstructionSource source,
  required FakeAuthRepository authRepository,
  RoutineRepository? routineRepository,
  HabitSystemsRepository? habitSystemsRepository,
}) {
  return ProviderContainer(
    overrides: [
      optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.firebase),
      authRepositoryProvider.overrideWithValue(authRepository),
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      appPreferencesRepositoryProvider.overrideWithValue(
        FakeAppPreferencesRepository(),
      ),
      regionSettingsRepositoryProvider.overrideWithValue(
        FakeRegionSettingsRepository(),
      ),
      uploadedAssetRepositoryProvider.overrideWithValue(
        FakeUploadedAssetRepository(),
      ),
      routineRepositoryProvider.overrideWithValue(
        routineRepository ?? FakeRoutineRepository(),
      ),
      routineHistoryRepositoryProvider.overrideWithValue(
        FakeRoutineHistoryRepository(),
      ),
      routineTransactionRepositoryProvider.overrideWith((ref) {
        return FakeRoutineTransactionRepository(
          routineRepository: ref.read(routineRepositoryProvider),
          historyRepository: ref.read(routineHistoryRepositoryProvider),
        );
      }),
      conflictAcceptanceRepositoryProvider.overrideWithValue(
        _TestConflictAcceptanceRepository(),
      ),
      habitSystemsRepositoryProvider.overrideWithValue(
        habitSystemsRepository ?? FakeHabitSystemsRepository(),
      ),
      serverReconstructorProvider.overrideWithValue(
        ServerReconstructor(source: source),
      ),
      reconstructionRetryPolicyProvider.overrideWithValue(
        const ReconstructionRetryPolicy(retryDelays: [Duration.zero]),
      ),
    ],
  )..read(authProvider);
}

void _seedAccountAState(ProviderContainer container, String uidA) {
  container
      .read(userProfileProvider.notifier)
      .loadSeedData(
        UserProfile.empty(uid: uidA).copyWith(displayName: 'Private A'),
      );
  container.read(mockGoalProvider.notifier).replaceWith([
    GoalModel(
      id: 'goal-a',
      identityTitle: 'Private A Goal',
      purposeStatement: 'Private A Purpose',
      dailyProof: GoalProof(
        id: 'proof-a',
        title: 'Proof A',
        tinyVersion: 'tiny',
        normalVersion: 'normal',
        strongVersion: 'strong',
      ),
    ),
  ]);
  container.read(routineNotifierProvider.notifier).toggleFullDay(true);
  container.read(homeDashboardProvider.notifier).cycleNowNextState();
  container.read(fitnessCenterProvider.notifier).startSelectedActivity();
  container
      .read(regionSettingsProvider.notifier)
      .loadSettings(RegionSettings.forCountry(userId: uidA, countryCode: 'GB'));
}

void _expectNoAccountAData(ProviderContainer container, String uidA) {
  expect(container.read(userProfileProvider).uid, isNot(uidA));
  expect(container.read(userProfileProvider).displayName, isNot('Private A'));
  expect(
    container.read(userProfileProvider).displayName,
    isNot('Stale Account A'),
  );
  expect(container.read(onboardingStateProvider).draft.uid, isNot(uidA));
  expect(
    container.read(routineNotifierProvider).items.any((i) => i.userId == uidA),
    isFalse,
  );
  expect(
    container
        .read(habitSystemsNotifierProvider)
        .systems
        .any((s) => s.ownerUid == uidA),
    isFalse,
  );
  expect(container.read(uploadControllerProvider).uid, isNot(uidA));
  expect(container.read(restoredUploadsProvider).uid, isNot(uidA));
  expect(container.read(regionSettingsProvider).userId, isNot(uidA));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gate 5 Phase 3: Real Auth Reconstruction Race & Async Isolation (R5)', () {
    test(
      'TEST A: late Account A reconstruction completion cannot mutate Account B (resumeOnboarding)',
      () async {
        final source = CompleterServerReconstructionSource();
        final authRepo = FakeAuthRepository();
        final container = _buildReconstructionContainer(
          source: source,
          authRepository: authRepo,
        );
        addTearDown(container.dispose);

        // 1. Emit authenticated Account A.
        authRepo.emitUserForTesting(_userA);
        await source.waitForPendingLoad(_userA.uid);

        // Assert A's load call has started and is pending.
        expect(source.hasPendingLoad(_userA.uid), isTrue);
        expect(source.loadCalls, [_userA.uid]);

        final genA = container.read(authGenerationProvider);

        // 2. Seed clearly identifiable Account A state.
        _seedAccountAState(container, _userA.uid);
        expect(container.read(userProfileProvider).displayName, 'Private A');
        expect(container.read(mockGoalProvider), isNotEmpty);
        expect(container.read(routineNotifierProvider).showFullDay, isTrue);

        // 3. Emit authenticated Account B while A's Future remains pending.
        authRepo.emitUserForTesting(_userB);
        await source.waitForPendingLoad(_userB.uid);

        // 4. Assert synchronous identity boundary cleared A before B becomes usable.
        final genB = container.read(authGenerationProvider);
        expect(
          genB,
          greaterThan(genA),
          reason: 'authGeneration must increment on identity boundary',
        );
        expect(container.read(userProfileProvider).uid, isNot(_userA.uid));
        expect(
          container.read(userProfileProvider).displayName,
          isNot('Private A'),
        );
        expect(container.read(mockGoalProvider), isEmpty);
        expect(container.read(routineNotifierProvider).showFullDay, isFalse);
        expect(container.read(homeDashboardProvider).nowNextAction, isNull);
        expect(container.read(fitnessCenterProvider).activeActivity, isNull);
        expect(
          container.read(regionSettingsProvider).userId,
          isNot(_userA.uid),
        );

        // 5. B's reconstruction is now in flight and pending.
        expect(source.hasPendingLoad(_userB.uid), isTrue);

        // 6. Complete B's reconstruction with B-owned state.
        final snapshotB = _incompleteSnapshot(
          uid: _userB.uid,
          displayName: 'User B Real',
          step: 3,
        );
        source.completerFor(_userB.uid).complete(snapshotB);
        await pumpEventQueue(times: 30);

        // 7. Verify B reached its final SessionDestination.
        expect(container.read(authProvider).user?.uid, _userB.uid);
        expect(
          container.read(authProvider).sessionDestination.kind,
          SessionDestinationKind.resumeOnboarding,
        );
        expect(container.read(authProvider).sessionDestination.resumeStep, 3);
        expect(container.read(userProfileProvider).uid, _userB.uid);
        expect(container.read(userProfileProvider).displayName, 'User B Real');
        expect(container.read(onboardingStateProvider).draft.uid, _userB.uid);
        expect(container.read(onboardingStateProvider).draft.currentStep, 3);

        // 8. ONLY NOW complete A's old reconstruction Future.
        final snapshotA = _incompleteSnapshot(
          uid: _userA.uid,
          displayName: 'Stale Account A',
          step: 8,
        );
        source.completerFor(_userA.uid).complete(snapshotA);
        await pumpEventQueue(times: 30);

        // 9. Assert A's late resolution was completely discarded.
        expect(container.read(authProvider).user?.uid, _userB.uid);
        expect(
          container.read(authProvider).sessionDestination.kind,
          SessionDestinationKind.resumeOnboarding,
        );
        expect(container.read(authProvider).sessionDestination.resumeStep, 3);
        expect(container.read(authGenerationProvider), genB);
        expect(container.read(userProfileProvider).uid, _userB.uid);
        expect(container.read(userProfileProvider).displayName, 'User B Real');
        expect(container.read(onboardingStateProvider).draft.uid, _userB.uid);
        expect(container.read(onboardingStateProvider).draft.currentStep, 3);
        expect(container.read(authProvider).error, isNull);
        expect(
          container.read(authProvider).reconstructionResult?.ownerUid,
          _userB.uid,
        );
        _expectNoAccountAData(container, _userA.uid);
      },
    );

    test(
      'TEST A (Home destination): late Account A completion cannot mutate Account B at Home',
      () async {
        final source = CompleterServerReconstructionSource();
        final authRepo = FakeAuthRepository();
        final container = _buildReconstructionContainer(
          source: source,
          authRepository: authRepo,
        );
        addTearDown(container.dispose);

        // Emit Account A.
        authRepo.emitUserForTesting(_userA);
        await source.waitForPendingLoad(_userA.uid);
        expect(source.hasPendingLoad(_userA.uid), isTrue);

        // Emit Account B.
        authRepo.emitUserForTesting(_userB);
        await source.waitForPendingLoad(_userB.uid);
        expect(source.hasPendingLoad(_userB.uid), isTrue);

        // Complete B with completed snapshot (destination Home).
        final snapshotB = _completedSnapshot(
          uid: _userB.uid,
          displayName: 'User B Complete',
        );
        source.completerFor(_userB.uid).complete(snapshotB);
        await pumpEventQueue(times: 30);

        expect(container.read(authProvider).user?.uid, _userB.uid);
        expect(
          container.read(authProvider).sessionDestination.kind,
          SessionDestinationKind.home,
        );
        expect(
          container.read(authProvider).status,
          AuthFlowStatus.signedInOnboardingComplete,
        );
        expect(
          container.read(userProfileProvider).displayName,
          'User B Complete',
        );

        // Complete old A with completed snapshot.
        final snapshotA = _completedSnapshot(
          uid: _userA.uid,
          displayName: 'Stale A Complete',
        );
        source.completerFor(_userA.uid).complete(snapshotA);
        await pumpEventQueue(times: 30);

        // Account B remains strictly active at Home.
        expect(container.read(authProvider).user?.uid, _userB.uid);
        expect(
          container.read(authProvider).sessionDestination.kind,
          SessionDestinationKind.home,
        );
        expect(
          container.read(authProvider).status,
          AuthFlowStatus.signedInOnboardingComplete,
        );
        expect(
          container.read(userProfileProvider).displayName,
          'User B Complete',
        );
        _expectNoAccountAData(container, _userA.uid);
      },
    );

    test(
      'TEST A (Error isolation): late Account A error cannot publish into Account B',
      () async {
        final source = CompleterServerReconstructionSource();
        final authRepo = FakeAuthRepository();
        final container = _buildReconstructionContainer(
          source: source,
          authRepository: authRepo,
        );
        addTearDown(container.dispose);

        // Emit Account A.
        authRepo.emitUserForTesting(_userA);
        await source.waitForPendingLoad(_userA.uid);
        expect(source.hasPendingLoad(_userA.uid), isTrue);

        // Emit Account B.
        authRepo.emitUserForTesting(_userB);
        await source.waitForPendingLoad(_userB.uid);

        // Complete B with valid snapshot.
        final snapshotB = _incompleteSnapshot(
          uid: _userB.uid,
          displayName: 'User B Valid',
          step: 5,
        );
        source.completerFor(_userB.uid).complete(snapshotB);
        await pumpEventQueue(times: 30);

        expect(container.read(authProvider).user?.uid, _userB.uid);
        expect(container.read(authProvider).error, isNull);

        // Complete A with an error.
        source
            .completerFor(_userA.uid)
            .completeError(
              const ReconstructionBootstrapException(
                reason: ReconstructionBootstrapFailureReason.backendUnavailable,
                diagnosticCode: 'simulated_a_failure',
              ),
            );
        await pumpEventQueue(times: 30);

        // Assert no A error is published to Account B.
        expect(container.read(authProvider).user?.uid, _userB.uid);
        expect(container.read(authProvider).error, isNull);
        expect(
          container.read(authProvider).sessionDestination.kind,
          SessionDestinationKind.resumeOnboarding,
        );
      },
    );

    test(
      'TEST B: late Account A reconstruction completion cannot resurrect state after sign-out',
      () async {
        final source = CompleterServerReconstructionSource();
        final authRepo = FakeAuthRepository();
        final container = _buildReconstructionContainer(
          source: source,
          authRepository: authRepo,
        );
        addTearDown(container.dispose);

        // 1. Emit Account A and let reconstruction start.
        authRepo.emitUserForTesting(_userA);
        await source.waitForPendingLoad(_userA.uid);
        expect(source.hasPendingLoad(_userA.uid), isTrue);

        // 2. Sign out while A's load is pending.
        await container.read(authProvider.notifier).logout();

        // 3. Assert synchronous reset occurred.
        expect(container.read(authProvider).status, AuthFlowStatus.signedOut);
        expect(container.read(authProvider).user, isNull);
        expect(
          container.read(authProvider).sessionDestination.kind,
          SessionDestinationKind.signedOut,
        );
        expect(container.read(userProfileProvider).uid, isNot(_userA.uid));
        expect(
          container.read(onboardingStateProvider).draft.uid,
          isNot(_userA.uid),
        );

        // 4. Complete old A Future now.
        final snapshotA = _completedSnapshot(
          uid: _userA.uid,
          displayName: 'Resurrected A',
        );
        source.completerFor(_userA.uid).complete(snapshotA);
        await pumpEventQueue(times: 30);

        // 5. Assert: still signedOut, no state returned, no error, no destination change.
        expect(container.read(authProvider).status, AuthFlowStatus.signedOut);
        expect(container.read(authProvider).user, isNull);
        expect(
          container.read(authProvider).sessionDestination.kind,
          SessionDestinationKind.signedOut,
        );
        expect(container.read(authProvider).error, isNull);
        expect(container.read(authProvider).reconstructionResult, isNull);
        _expectNoAccountAData(container, _userA.uid);
      },
    );

    test(
      'TEST B (Error isolation): late Account A error cannot publish after sign-out',
      () async {
        final source = CompleterServerReconstructionSource();
        final authRepo = FakeAuthRepository();
        final container = _buildReconstructionContainer(
          source: source,
          authRepository: authRepo,
        );
        addTearDown(container.dispose);

        // 1. Emit Account A.
        authRepo.emitUserForTesting(_userA);
        await source.waitForPendingLoad(_userA.uid);
        expect(source.hasPendingLoad(_userA.uid), isTrue);

        // 2. Sign out while pending.
        await container.read(authProvider.notifier).logout();
        expect(container.read(authProvider).status, AuthFlowStatus.signedOut);

        // 3. Complete A with an error.
        source
            .completerFor(_userA.uid)
            .completeError(
              const ReconstructionBootstrapException(
                reason: ReconstructionBootstrapFailureReason.backendUnavailable,
                diagnosticCode: 'simulated_a_failure_after_logout',
              ),
            );
        await pumpEventQueue(times: 30);

        // 4. Still cleanly signed out.
        expect(container.read(authProvider).status, AuthFlowStatus.signedOut);
        expect(container.read(authProvider).user, isNull);
        expect(container.read(authProvider).error, isNull);
      },
    );

    test(
      'TEST C: failed logout preserves Account A state and renders typed RecoverableError',
      () async {
        final source = CompleterServerReconstructionSource();
        final authRepo = FakeAuthRepository();
        final container = _buildReconstructionContainer(
          source: source,
          authRepository: authRepo,
        );
        addTearDown(container.dispose);

        // 1. Fully hydrate Account A.
        authRepo.emitUserForTesting(_userA);
        await source.waitForPendingLoad(_userA.uid);
        expect(source.hasPendingLoad(_userA.uid), isTrue);

        final snapshotA = _completedSnapshot(
          uid: _userA.uid,
          displayName: 'Private A',
        );
        source.completerFor(_userA.uid).complete(snapshotA);
        await pumpEventQueue(times: 30);

        expect(container.read(authProvider).user?.uid, _userA.uid);
        expect(
          container.read(authProvider).sessionDestination.kind,
          SessionDestinationKind.home,
        );
        expect(container.read(userProfileProvider).displayName, 'Private A');

        // Seed additional mutable A state.
        _seedAccountAState(container, _userA.uid);
        final generationA = container.read(authGenerationProvider);

        // 2. Configure sign-out to throw a failure.
        authRepo.signOutShouldFail = true;

        // 3. Attempt logout().
        await expectLater(
          container.read(authProvider.notifier).logout(),
          throwsA(isA<RecoverableError>()),
        );

        // 4. Assert: Account A remains current, no identity reset, generation unchanged,
        // and AuthState.error is typed RecoverableError with safe public message.
        expect(container.read(authProvider).user?.uid, _userA.uid);
        expect(container.read(authGenerationProvider), generationA);
        expect(container.read(userProfileProvider).displayName, 'Private A');
        expect(container.read(userProfileProvider).uid, _userA.uid);
        expect(container.read(mockGoalProvider), isNotEmpty);
        expect(container.read(routineNotifierProvider).showFullDay, isTrue);

        final authError = container.read(authProvider).error;
        expect(authError, isNotNull);
        expect(authError, isA<RecoverableError>());
        expect(authError!.publicMessage, contains('still signed in'));

        // 5. Verify the verification lifecycle controller accepts and renders this typed error.
        final lifecycleController = container.read(
          verificationLifecycleProvider.notifier,
        );
        lifecycleController.showAccountError(authError);
        final lifecycleState = container.read(verificationLifecycleProvider);
        expect(lifecycleState.error, authError);
        expect(
          lifecycleState.error?.publicMessage,
          "We couldn't sign you out. You are still signed in. Please try again.",
        );
      },
    );

    testWidgets(
      'TEST C (Presentation): Verify Email screen renders typed logout failure without raw leakage',
      (tester) async {
        tester.view.physicalSize = const Size(1179, 2556);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final authRepo = FakeAuthRepository()..signOutShouldFail = true;

        const initialAuthState = AuthState(
          user: _userUnverified,
          status: AuthFlowStatus.signedInEmailUnverified,
          verificationEmailSendStatus: VerificationEmailSendStatus.sent,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              optivusBackendModeProvider.overrideWithValue(
                OptivusBackendMode.firebase,
              ),
              authRepositoryProvider.overrideWithValue(authRepo),
              authProvider.overrideWith(
                (ref) => _TestAuthNotifier(authRepo, ref, initialAuthState),
              ),
              userProfileProvider.overrideWith(
                (ref) => UserProfileNotifier()
                  ..loadSeedData(
                    UserProfile.empty(
                      uid: _userUnverified.uid,
                      email: _userUnverified.email ?? '',
                    ),
                  ),
              ),
            ],
            child: const MaterialApp(home: VerifyEmailScreen()),
          ),
        );
        await tester.pump();

        expect(find.text('Verify your email'), findsOneWidget);

        // Tap Sign out button.
        final signOutBtn = find.byKey(const Key('verify-email-sign-out'));
        expect(signOutBtn, findsOneWidget);
        await tester.ensureVisible(signOutBtn);
        await tester.tap(signOutBtn);
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();

        // Assert the typed message is displayed.
        expect(
          find.text(
            "We couldn't sign you out. You are still signed in. Please try again.",
          ),
          findsOneWidget,
        );
        // Assert no raw exception or technical string leaked.
        expect(find.textContaining('Exception'), findsNothing);
        expect(find.textContaining('network-request-failed'), findsNothing);
      },
    );

    test(
      'TEST D: same-UID refresh preserves session without privacy reset or reconstruction restart',
      () async {
        final source = CompleterServerReconstructionSource();
        final authRepo = FakeAuthRepository();
        final container = _buildReconstructionContainer(
          source: source,
          authRepository: authRepo,
        );
        addTearDown(container.dispose);

        // 1. Emit Account A and complete reconstruction.
        authRepo.emitUserForTesting(_userA);
        await source.waitForPendingLoad(_userA.uid);
        expect(source.hasPendingLoad(_userA.uid), isTrue);

        final snapshotA = _incompleteSnapshot(
          uid: _userA.uid,
          displayName: 'User A Stable',
          step: 4,
        );
        source.completerFor(_userA.uid).complete(snapshotA);
        await pumpEventQueue(times: 30);

        // Verify hydrated.
        expect(container.read(authProvider).user?.uid, _userA.uid);
        expect(
          container.read(authProvider).sessionDestination.kind,
          SessionDestinationKind.resumeOnboarding,
        );
        expect(container.read(authProvider).sessionDestination.resumeStep, 4);
        expect(
          container.read(userProfileProvider).displayName,
          'User A Stable',
        );

        // Seed navigation and projection state.
        container.read(appNavigationProvider.notifier).goToProfile();
        expect(container.read(appNavigationProvider), 5);

        // 2. Record generation and load calls before refresh.
        final genBefore = container.read(authGenerationProvider);
        final loadCallsBefore = source.loadCalls.length;
        expect(loadCallsBefore, 1);

        // 3. Emit updated AuthUser with SAME UID (e.g. token refresh, updated email/providers).
        const updatedUserA = AuthUser(
          uid: 'gate5-user-a',
          email: 'refreshed-a@example.com',
          displayName: 'User A Refreshed',
          emailVerified: true,
          providerIds: {'password', 'google.com'},
        );
        authRepo.emitUserForTesting(updatedUserA);
        await pumpEventQueue(times: 30);

        // 4. Assert:
        // - No privacy reset (generation unchanged).
        expect(
          container.read(authGenerationProvider),
          genBefore,
          reason: 'authGeneration must not increment on same-UID refresh',
        );
        // - Reconstruction was NOT restarted (loadCalls unchanged).
        expect(
          source.loadCalls.length,
          loadCallsBefore,
          reason:
              'Reconstruction load() must NOT be re-invoked on same-UID refresh',
        );
        // - Navigation tab preserved (not reset to 0).
        expect(
          container.read(appNavigationProvider),
          5,
          reason: 'appNavigation must not reset on same-UID refresh',
        );
        // - User facts updated in place.
        expect(
          container.read(authProvider).user?.email,
          'refreshed-a@example.com',
        );
        expect(
          container.read(authProvider).user?.providerIds,
          contains('google.com'),
        );
        // - Established destination preserved.
        expect(
          container.read(authProvider).sessionDestination.kind,
          SessionDestinationKind.resumeOnboarding,
        );
        expect(container.read(authProvider).sessionDestination.resumeStep, 4);
        // - Projections and profile remain intact.
        expect(container.read(userProfileProvider).uid, _userA.uid);
        expect(
          container.read(userProfileProvider).displayName,
          'User A Stable',
        );
        expect(container.read(onboardingStateProvider).draft.uid, _userA.uid);
        expect(container.read(onboardingStateProvider).draft.currentStep, 4);
      },
    );
  });
}
