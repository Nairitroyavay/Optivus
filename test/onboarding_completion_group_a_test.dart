import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/router/app_router.dart';
import 'package:optivus/features/recovery/models/onboarding_recovery_models.dart';
import 'package:optivus/features/recovery/screens/onboarding_recovery_screen.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/models/user_model.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/repositories/routine_firestore_codec.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/features/profile/models/profile_settings_models.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';

void main() {
  group('Issue 1: Unsafe receipt early return', () {
    test(
      'FakeOnboardingRepository does not early-return noOp if draft/bundle are missing',
      () async {
        final db = FakeRoutineDatabase();
        final repo = FakeOnboardingRepository(routineDatabase: db);
        const uid = 'user-issue-1';
        final draft = OnboardingDraft(uid: uid).copyWith(
          onboardingCompleted: true,
          currentStep: OnboardingDraft.lastStepIndex,
        );
        final bundle = OnboardingCompletionService.buildBundle(draft);
        final plan = RoutineOnboardingProjection.build(bundle);

        // Inject receipt into db without saving draft or bundle in repo
        db.receiptsByUid[uid] = {plan.projectionId: plan.receipt};

        final result = await repo.completeOnboarding(
          finalDraft: draft,
          bundle: bundle,
        );

        expect(result.outcome, equals(RoutineProjectionOutcome.projected));
        expect(repo.savedCompletionBundle(uid), isNotNull);
      },
    );

    test(
      'FakeOnboardingRepository returns noOp when receipt, draft, and bundle all match and exist',
      () async {
        final db = FakeRoutineDatabase();
        final repo = FakeOnboardingRepository(routineDatabase: db);
        const uid = 'user-issue-1-valid';
        final draft = OnboardingDraft(uid: uid).copyWith(
          onboardingCompleted: true,
          currentStep: OnboardingDraft.lastStepIndex,
        );
        final bundle = OnboardingCompletionService.buildBundle(draft);

        final first = await repo.completeOnboarding(
          finalDraft: draft,
          bundle: bundle,
        );
        expect(first.outcome, equals(RoutineProjectionOutcome.projected));

        final second = await repo.completeOnboarding(
          finalDraft: draft,
          bundle: bundle,
        );
        expect(second.outcome, equals(RoutineProjectionOutcome.noOp));
      },
    );

    test(
      'FakeOnboardingRepository re-projects when receipt exists but fingerprint differs',
      () async {
        final db = FakeRoutineDatabase();
        final repo = FakeOnboardingRepository(routineDatabase: db);
        const uid = 'user-issue-1-reproject';
        final draft1 = OnboardingDraft(uid: uid).copyWith(
          onboardingCompleted: true,
          currentStep: OnboardingDraft.lastStepIndex,
        );
        final bundle1 = OnboardingCompletionService.buildBundle(draft1);

        final first = await repo.completeOnboarding(
          finalDraft: draft1,
          bundle: bundle1,
        );
        expect(first.outcome, equals(RoutineProjectionOutcome.projected));

        // Rebuild draft with different content so fingerprint changes
        final draft2 = draft1.copyWith(
          goodHabits: [
            const GoodHabitDraft(
              id: 'gh-diff',
              habitKey: 'reading',
              displayName: 'Read Daily',
            ),
          ],
        );
        final bundle2 = OnboardingCompletionService.buildBundle(draft2);

        final second = await repo.completeOnboarding(
          finalDraft: draft2,
          bundle: bundle2,
        );
        expect(second.outcome, equals(RoutineProjectionOutcome.projected));
      },
    );
  });

  group('Issue 2: Run-scoped projection ID construction', () {
    test(
      'RoutineOnboardingProjection constructs projectionId from slot and revision',
      () {
        final draft = OnboardingDraft(
          uid: 'user-issue-2',
        ).copyWith(onboardingCompleted: true);
        final bundle = OnboardingCompletionService.buildBundle(draft);

        final defaultPlan = RoutineOnboardingProjection.build(bundle);
        expect(
          defaultPlan.projectionId,
          equals('onboarding-${bundle.runId}-v1'),
        );
        expect(defaultPlan.receipt.slot, equals('onboarding-${bundle.runId}'));
        expect(defaultPlan.receipt.revision, equals(1));

        final customPlan = RoutineOnboardingProjection.build(
          bundle,
          slot: 'onboarding-custom',
          revision: 3,
        );
        expect(customPlan.projectionId, equals('onboarding-custom-v3'));
        expect(customPlan.receipt.slot, equals('onboarding-custom'));
        expect(customPlan.receipt.revision, equals(3));
        expect(customPlan.receipt.fingerprint, equals(customPlan.fingerprint));
      },
    );

    test(
      'RoutineProjectionReceiptFirestoreCodec serializes slot and revision correctly',
      () {
        final now = DateTime.now().toUtc();
        final receipt = RoutineProjectionReceipt(
          id: 'onboarding-custom-v2',
          ownerUid: 'user-issue-2',
          slot: 'onboarding-custom',
          revision: 2,
          sourceBundleSchemaVersion: 1,
          sourceBundleId: 'bundle-1',
          sourceBundleFingerprint: 'a' * 64,
          projectedItemIds: const ['item-1'],
          createdAt: now,
        );

        const codec = RoutineProjectionReceiptFirestoreCodec();
        final firestoreMap = codec.toFirestore(receipt);
        expect(firestoreMap['slot'], equals('onboarding-custom'));
        expect(firestoreMap['revision'], equals(2));

        final decoded = codec.fromFirestore(
          documentId: 'onboarding-custom-v2',
          data: firestoreMap,
        );
        expect(decoded.slot, equals('onboarding-custom'));
        expect(decoded.revision, equals(2));
      },
    );
  });

  group('Issue 3: Onboarding completion job tracking & service', () {
    test('FirestoreUserPaths includes onboardingCompletionJob path', () {
      expect(
        FirestoreUserPaths.onboardingCompletionJob('uid-123'),
        equals('users/uid-123/onboardingCompletionJobs/current'),
      );
    });

    test('OnboardingCompletionJob serializes and deserializes correctly', () {
      final now = DateTime.now();
      final job = OnboardingCompletionJob(
        jobId: 'current',
        uid: 'user-3',
        status: OnboardingJobStatus.inProgress,
        stage: OnboardingCompletionStage.projectRoutines,
        stagesCompleted: const {'persistDraft': true, 'persistBundle': true},
        retryCount: 1,
        createdAt: now,
        updatedAt: now,
      );

      final map = job.toMap();
      final restored = OnboardingCompletionJob.fromMap(map);
      expect(restored.jobId, equals('current'));
      expect(restored.uid, equals('user-3'));
      expect(restored.status, equals(OnboardingJobStatus.inProgress));
      expect(restored.stage, equals(OnboardingCompletionStage.projectRoutines));
      expect(
        restored.isStageCompleted(OnboardingCompletionStage.persistDraft),
        isTrue,
      );
      expect(
        restored.isStageCompleted(OnboardingCompletionStage.persistBundle),
        isTrue,
      );
      expect(
        restored.isStageCompleted(OnboardingCompletionStage.projectRoutines),
        isFalse,
      );
    });

    test(
      'OnboardingCompletionJobService executes stages idempotently to completion',
      () async {
        final onboardingRepo = FakeOnboardingRepository();
        final profileRepo = FakeProfileRepository();
        final jobService = OnboardingCompletionJobService(
          onboardingRepository: onboardingRepo,
          profileRepository: profileRepo,
        );

        const uid = 'user-job-3';
        final draft = OnboardingDraft(
          uid: uid,
          onboardingCompleted: true,
          currentStep: OnboardingDraft.lastStepIndex,
          stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
        );
        final bundle = OnboardingCompletionService.buildBundle(draft);
        await profileRepo.saveUserProfile(
          UserProfile.empty(uid: uid, email: 'test@example.com'),
        );

        final completedJob = await jobService.runCompletionJob(
          uid: uid,
          finalDraft: draft,
          bundle: bundle,
        );

        expect(completedJob.status, equals(OnboardingJobStatus.completed));
        expect(completedJob.stage, equals(OnboardingCompletionStage.completed));
        expect(
          completedJob.isStageCompleted(OnboardingCompletionStage.persistDraft),
          isTrue,
        );
        expect(
          completedJob.isStageCompleted(
            OnboardingCompletionStage.persistBundle,
          ),
          isTrue,
        );
        expect(
          completedJob.isStageCompleted(
            OnboardingCompletionStage.projectRoutines,
          ),
          isTrue,
        );
        expect(
          completedJob.isStageCompleted(
            OnboardingCompletionStage.updateProfile,
          ),
          isTrue,
        );

        final savedProfile = await profileRepo.fetchUserProfile(uid);
        expect(savedProfile, isNotNull);
        expect(savedProfile!.onboardingInputCompleted, isTrue);
        expect(savedProfile.onboardingProjectionStatus, equals('completed'));
        expect(savedProfile.onboardingCompleted, isTrue);
      },
    );
  });

  group('Issue 4: Profile fields & router alignment', () {
    test(
      'UserProfile and UserModel provide decoupled onboarding fields and getter',
      () {
        final profile = UserProfile(
          uid: 'u4',
          email: 'u4@ex.com',
          displayName: 'User 4',
          onboardingInputCompleted: true,
          onboardingProjectionStatus: 'pending',
        );
        expect(profile.onboardingInputCompleted, isTrue);
        expect(profile.onboardingProjectionStatus, equals('pending'));
        expect(profile.onboardingCompleted, isFalse);

        final completedProfile = profile.copyWith(
          onboardingProjectionStatus: 'completed',
        );
        expect(completedProfile.onboardingCompleted, isTrue);

        final now = DateTime.now();
        final userModel = UserModel(
          id: 'u4',
          email: 'u4@ex.com',
          createdAt: now,
          updatedAt: now,
          onboardingInputCompleted: true,
          onboardingProjectionStatus: 'failed',
        );
        expect(userModel.onboardingCompleted, isFalse);
      },
    );

    testWidgets(
      'Router directs onboardingInputCompleted = true & onboardingProjectionStatus = failed to /onboarding/recovery',
      (tester) async {
        final profile =
            UserProfile.empty(
              uid: 'failed-user',
              email: 'failed@ex.com',
            ).copyWith(
              onboardingInputCompleted: true,
              onboardingProjectionStatus: 'failed',
            );

        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(
              (ref) => _FakeAuthNotifier(
                AuthState(
                  user: const AuthUser(
                    uid: 'failed-user',
                    email: 'failed@ex.com',
                    emailVerified: true,
                  ),
                  status: AuthFlowStatus.backendRestoreFailed,
                  errorMessage: 'Projection pipeline failed',
                ),
              ),
            ),
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
              builder: (context, ref, child) {
                return MaterialApp.router(
                  routerConfig: ref.watch(routerProvider),
                );
              },
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // AuthState status is backendRestoreFailed, so router directs to /onboarding/recovery rendering OnboardingRecoveryScreen
        expect(find.byType(OnboardingRecoveryScreen), findsOneWidget);
      },
    );
  });

  group('Issue 5: 4-tier recovery fallback', () {
    test('recoverCompletionState executes Tier 1 when bundle exists', () async {
      final onboardingRepo = FakeOnboardingRepository();
      final profileRepo = FakeProfileRepository();
      const uid = 'tier-1-user';

      final draft = OnboardingDraft(
        uid: uid,
      ).copyWith(onboardingCompleted: true);
      final bundle = OnboardingCompletionService.buildBundle(draft);
      await onboardingRepo.saveCompletionBundle(bundle);

      final result = await OnboardingCompletionService.recoverCompletionState(
        uid: uid,
        onboardingRepository: onboardingRepo,
        profileRepository: profileRepo,
      );

      expect(result.tier, equals(OnboardingRecoveryTier.tier1BundleFound));
      expect(result.bundle?.uid, equals(uid));
    });

    test(
      'recoverCompletionState executes Tier 2 when draft exists but bundle is missing',
      () async {
        final onboardingRepo = FakeOnboardingRepository();
        final profileRepo = FakeProfileRepository();
        const uid = 'tier-2-user';

        final draft = OnboardingDraft(
          uid: uid,
          currentStep: OnboardingDraft.lastStepIndex,
          stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
          onboardingCompleted: true,
        );
        await onboardingRepo.saveDraft(draft);

        final result = await OnboardingCompletionService.recoverCompletionState(
          uid: uid,
          onboardingRepository: onboardingRepo,
          profileRepository: profileRepo,
        );

        expect(
          result.tier,
          equals(OnboardingRecoveryTier.tier2RebuiltFromDraft),
        );
        expect(result.bundle?.uid, equals(uid));
        expect(await onboardingRepo.fetchCompletionBundle(uid), isNotNull);
      },
    );

    test(
      'recoverCompletionState reports missing setup when only a profile exists',
      () async {
        final onboardingRepo = FakeOnboardingRepository();
        final profileRepo = FakeProfileRepository();
        const uid = 'tier-3-user';

        await profileRepo.saveUserProfile(UserProfile.empty(uid: uid));

        final result = await OnboardingCompletionService.recoverCompletionState(
          uid: uid,
          onboardingRepository: onboardingRepo,
          profileRepository: profileRepo,
        );

        expect(result.tier, equals(OnboardingRecoveryTier.missingSetup));
        expect(result.bundle, isNull);
        expect(result.draft, isNull);
        expect(await onboardingRepo.fetchDraft(uid), isNull);
      },
    );

    test(
      'recoverCompletionState reports missing setup when no artifacts exist',
      () async {
        final onboardingRepo = FakeOnboardingRepository();
        final profileRepo = FakeProfileRepository();
        const uid = 'tier-4-user';

        final result = await OnboardingCompletionService.recoverCompletionState(
          uid: uid,
          onboardingRepository: onboardingRepo,
          profileRepository: profileRepo,
        );

        expect(result.tier, equals(OnboardingRecoveryTier.missingSetup));
        expect(result.hasBundle, isFalse);
      },
    );
  });

  group('Issue 6: Typed recovery actions taxonomy', () {
    test(
      'OnboardingRecoveryAction concrete types specify label and actionId',
      () {
        const retry = RetryNetworkAction();
        expect(retry.actionId, equals('retry_network'));
        expect(retry.label, equals('Retry Connection'));

        const rebuild = RebuildBundleFromVerifiedDraftAction();
        expect(rebuild.actionId, equals('rebuild_bundle'));
        expect(rebuild.label, equals('Rebuild Setup Plan'));

        const restart = ResumeOnboardingAction();
        expect(restart.actionId, equals('resume_onboarding'));
        expect(restart.label, equals('Resume Setup'));
      },
    );

    test(
      'AuthState populates onboardingFailureReason and recoveryActions on error',
      () {
        const state = AuthState(
          status: AuthFlowStatus.backendRestoreFailed,
          errorMessage: 'Bundle missing',
          onboardingFailureReason: OnboardingFailureReason.missingBundle,
          recoveryActions: [
            RebuildBundleFromVerifiedDraftAction(),
            ResumeOnboardingAction(),
          ],
        );

        expect(
          state.onboardingFailureReason,
          equals(OnboardingFailureReason.missingBundle),
        );
        expect(state.recoveryActions.length, equals(2));
        expect(
          state.recoveryActions.first,
          isA<RebuildBundleFromVerifiedDraftAction>(),
        );
      },
    );
  });
}

class FakeProfileRepository implements ProfileRepository {
  final Map<String, UserProfile> _profiles = {};

  @override
  Future<UserProfile?> fetchUserProfile(String uid) async => _profiles[uid];

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    _profiles[profile.uid] = profile;
  }

  @override
  Future<UserProfileSettings> fetchProfileSettings(String uid) async =>
      const UserProfileSettings();

  @override
  Future<void> saveProfileSettings(
    String uid,
    UserProfileSettings settings,
  ) async {}
}

class _FakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _FakeAuthNotifier(super.state);

  @override
  Future<void> acceptCanonicalOnboardingCompletion(AuthUser user) async {}

  @override
  Future<void> checkEmailVerification() async {}

  @override
  Future<void> signInAnonymously() async {}

  @override
  Future<bool> signInWithGoogle() async => false;

  @override
  Future<void> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async {}

  @override
  Future<void> login(String email, String password) async {}

  @override
  Future<void> logout() async {}

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
  Future<void> signup(String name, String email, String password) async {}

  @override
  Future<void> executeRecoveryAction(OnboardingRecoveryAction action) async {}
}
