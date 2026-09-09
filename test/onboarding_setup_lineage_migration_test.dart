import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/profile/models/profile_settings_models.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_run_identity.dart';
import 'package:optivus/services/onboarding_setup_lineage_migration_coordinator.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/services/server_reconstructor.dart';

void main() {
  const uid = 'migration-test-user';

  late _InMemoryProfileRepository profileRepo;
  late _InMemoryOnboardingRepository onboardingRepo;
  late OnboardingCompletionMemoryStore memoryStore;
  late OnboardingCompletionJobService jobService;
  late OnboardingSetupLineageMigrationCoordinator migrationCoordinator;
  late RepositoryServerReconstructionSource source;
  late ServerReconstructor reconstructor;

  setUp(() {
    profileRepo = _InMemoryProfileRepository();
    onboardingRepo = _InMemoryOnboardingRepository();
    memoryStore = OnboardingCompletionMemoryStore();
    jobService = OnboardingCompletionJobService(
      profileRepository: profileRepo,
      onboardingRepository: onboardingRepo,
      memoryStore: memoryStore,
    );
    migrationCoordinator = OnboardingSetupLineageMigrationCoordinator(
      firestore: null,
      profileRepository: profileRepo,
      onboardingRepository: onboardingRepo,
      jobService: jobService,
    );
    source = RepositoryServerReconstructionSource(
      profileRepository: profileRepo,
      onboardingRepository: onboardingRepo,
      completionJobService: jobService,
    );
    reconstructor = ServerReconstructor(
      source: source,
      migrationCoordinator: migrationCoordinator,
    );
  });

  group('OnboardingSetupLineageMigrationCoordinator - shouldMigrate', () {
    test('returns false when profile is null', () {
      final snapshot = ServerReconstructionSnapshot(
        profile: null,
        draft: null,
        completionBundle: null,
        currentRun: const OnboardingCurrentRunSnapshot(hasPointer: false),
      );
      expect(migrationCoordinator.shouldMigrate(snapshot), isFalse);
    });

    test('returns false when onboarding is already completed', () {
      final snapshot = ServerReconstructionSnapshot(
        profile: UserProfile.empty(uid: uid).copyWith(
          onboardingCompleted: true,
          setupLineageVersion: 0,
        ),
        draft: null,
        completionBundle: null,
        currentRun: const OnboardingCurrentRunSnapshot(hasPointer: false),
      );
      expect(migrationCoordinator.shouldMigrate(snapshot), isFalse);
    });

    test('returns false when both profile and draft already have current lineage', () {
      final snapshot = ServerReconstructionSnapshot(
        profile: UserProfile.empty(uid: uid).copyWith(
          setupLineageVersion: UserProfile.currentSetupLineageVersion,
        ),
        draft: _validDraftAtStep(
          uid,
          3,
          setupGeneration: 1,
          setupLineageVersion: OnboardingDraft.currentSetupLineageVersion,
        ),
        completionBundle: null,
        currentRun: const OnboardingCurrentRunSnapshot(hasPointer: false),
      );
      expect(migrationCoordinator.shouldMigrate(snapshot), isFalse);
    });

    test('returns false when draft is already a final completed draft', () {
      final finalDraft = _finalDraft(uid, setupGeneration: 0, setupLineageVersion: 0);
      final snapshot = ServerReconstructionSnapshot(
        profile: UserProfile.empty(uid: uid).copyWith(setupLineageVersion: 0),
        draft: finalDraft,
        completionBundle: null,
        currentRun: const OnboardingCurrentRunSnapshot(hasPointer: false),
      );
      expect(migrationCoordinator.shouldMigrate(snapshot), isFalse);
    });

    test('returns true when profile has legacy lineage (0) and draft is partial', () {
      final snapshot = ServerReconstructionSnapshot(
        profile: UserProfile.empty(uid: uid).copyWith(setupLineageVersion: 0),
        draft: _validDraftAtStep(uid, 3, setupGeneration: 0, setupLineageVersion: 0),
        completionBundle: null,
        currentRun: const OnboardingCurrentRunSnapshot(hasPointer: false),
      );
      expect(migrationCoordinator.shouldMigrate(snapshot), isTrue);
    });

    test('returns true when draft has legacy lineage (0) even if profile was bumped', () {
      final snapshot = ServerReconstructionSnapshot(
        profile: UserProfile.empty(uid: uid).copyWith(
          setupLineageVersion: UserProfile.currentSetupLineageVersion,
        ),
        draft: _validDraftAtStep(uid, 2, setupGeneration: 0, setupLineageVersion: 0),
        completionBundle: null,
        currentRun: const OnboardingCurrentRunSnapshot(hasPointer: false),
      );
      expect(migrationCoordinator.shouldMigrate(snapshot), isTrue);
    });
  });

  group('Migration Coordinator - Physical Defect Resolution', () {
    test(
      'Form A: Incomplete draft with stale run pointer migrates and resumes at Step 3 (no Recovery)',
      () async {
        // Setup legacy state that triggered the physical device failure
        final profile = UserProfile.empty(uid: uid).copyWith(
          setupLineageVersion: 0,
          currentSetupGeneration: 0,
          onboardingCompleted: false,
          onboardingStep: 3,
        );
        await profileRepo.saveUserProfile(profile);

        final draft = _validDraftAtStep(
          uid,
          3,
          setupGeneration: 0,
          setupLineageVersion: 0,
          revision: 3,
        );
        await onboardingRepo.saveDraft(draft);

        // Put stale completion run pointer in memory
        memoryStore.currentRunIds[uid] = 'stale-run-legacy';
        memoryStore.currentRunStatuses[uid] = 'active';
        memoryStore.jobs['$uid:stale-run-legacy'] = OnboardingCompletionJob(
          jobId: 'stale-run-legacy',
          ownerUid: uid,
          status: OnboardingJobStatus.retryableFailure,
          stage: OnboardingCompletionStage.validateInput,
          draftRevision: 15,
          sourceFingerprint: 'stale-legacy-fp',
          setupGeneration: 0,
          setupLineageVersion: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Execute reconstruct
        final result = await reconstructor.reconstruct(uid: uid);

        // Must succeed as ReconstructionIncomplete at Step 3
        expect(result, isA<ReconstructionIncomplete>());
        final incomplete = result as ReconstructionIncomplete;
        expect(incomplete.step, 3);
        expect(incomplete.profile.setupLineageVersion, 1);
        expect(incomplete.profile.currentSetupGeneration, 1);
        expect(incomplete.draft.setupLineageVersion, 1);
        expect(incomplete.draft.setupGeneration, 1);
        expect(incomplete.draft.stepCompleted[0], isTrue);
        expect(incomplete.draft.stepCompleted[1], isTrue);
        expect(incomplete.draft.stepCompleted[2], isTrue);

        // Check persisted data
        final updatedProfile = await profileRepo.fetchUserProfile(uid);
        expect(updatedProfile!.setupLineageVersion, 1);
        expect(updatedProfile.currentSetupGeneration, 1);

        final updatedDraft = await onboardingRepo.fetchDraft(uid);
        expect(updatedDraft!.setupLineageVersion, 1);
        expect(updatedDraft.setupGeneration, 1);
        expect(updatedDraft.currentStep, 3);
      },
    );

    test('Form B: Fresh pre-lineage account migrates and returns ReconstructionFresh', () async {
      final profile = UserProfile.empty(uid: uid).copyWith(
        setupLineageVersion: 0,
        currentSetupGeneration: 0,
        onboardingCompleted: false,
        onboardingStep: 0,
      );
      await profileRepo.saveUserProfile(profile);

      final result = await reconstructor.reconstruct(uid: uid);

      expect(result, isA<ReconstructionFresh>());
      expect(result.profile.setupLineageVersion, 1);
      expect(result.profile.currentSetupGeneration, 1);

      final updatedProfile = await profileRepo.fetchUserProfile(uid);
      expect(updatedProfile!.setupLineageVersion, 1);
      expect(updatedProfile.currentSetupGeneration, 1);
    });

    test(
      'Draft Content Integrity: Step data and answers preserved 100% during migration',
      () async {
        final profile = UserProfile.empty(uid: uid).copyWith(
          setupLineageVersion: 0,
          currentSetupGeneration: 0,
          onboardingCompleted: false,
        );
        await profileRepo.saveUserProfile(profile);

        final draft = _validDraftAtStep(
          uid,
          7,
          setupGeneration: 0,
          setupLineageVersion: 0,
          revision: 5,
        ).copyWith(
          lifeRole: const LifeRoleDraft(
            lifeRole: 'student',
            exerciseLevel: 'vigorous',
            waterIntake: 'high',
            stressLevel: 'low',
            sleepQuality: 'excellent',
          ),
          bodyBasics: const BodyBasicsDraft(
            ageRange: '20-24',
            heightCm: 185,
            weightKg: 80,
            gender: 'female',
          ),
          badHabits: const [
            BadHabitDraft(
              id: 'bh1',
              habitKey: 'late_eating',
              displayName: 'Late eating',
            ),
          ],
          goodHabits: const [
            GoodHabitDraft(
              id: 'gh1',
              habitKey: 'read_daily',
              displayName: 'Daily reading',
            ),
          ],
        );
        await onboardingRepo.saveDraft(draft);

        final result = await reconstructor.reconstruct(uid: uid);

        expect(result, isA<ReconstructionIncomplete>());
        final incomplete = result as ReconstructionIncomplete;
        expect(incomplete.draft.setupLineageVersion, 1);
        expect(incomplete.draft.setupGeneration, 1);
        expect(incomplete.draft.lifeRole.lifeRole, 'student');
        expect(incomplete.draft.lifeRole.exerciseLevel, 'vigorous');
        expect(incomplete.draft.bodyBasics.heightCm, 185);
        expect(incomplete.draft.bodyBasics.weightKg, 80);
        expect(incomplete.draft.bodyBasics.gender, 'female');
        expect(incomplete.draft.badHabits.length, 1);
        expect(incomplete.draft.badHabits.first.habitKey, 'late_eating');
        expect(incomplete.draft.goodHabits.length, 1);
        expect(incomplete.draft.goodHabits.first.habitKey, 'read_daily');
      },
    );

    test('Migration idempotency: running migration multiple times is stable', () async {
      final profile = UserProfile.empty(uid: uid).copyWith(
        setupLineageVersion: 0,
        currentSetupGeneration: 0,
        onboardingCompleted: false,
      );
      await profileRepo.saveUserProfile(profile);
      final draft = _validDraftAtStep(uid, 3, setupGeneration: 0, setupLineageVersion: 0);
      await onboardingRepo.saveDraft(draft);

      final firstResult = await reconstructor.reconstruct(uid: uid);
      expect(firstResult, isA<ReconstructionIncomplete>());
      expect(firstResult.profile.setupLineageVersion, 1);
      expect(firstResult.profile.currentSetupGeneration, 1);

      // Second reconstruct call
      final secondResult = await reconstructor.reconstruct(uid: uid);
      expect(secondResult, isA<ReconstructionIncomplete>());
      expect(secondResult.profile.setupLineageVersion, 1);
      expect(secondResult.profile.currentSetupGeneration, 1);
      expect(
        (secondResult as ReconstructionIncomplete).draft.setupGeneration,
        1,
      );
    });

    test(
      'True Same-Lineage Mismatch: Returns ReconstructionRecovery(completion_run_input_mismatch)',
      () {
        // Modern generation 1, lineage 1
        final profile = UserProfile.empty(uid: uid).copyWith(
          currentSetupGeneration: 1,
          setupLineageVersion: 1,
        );
        final draft = _validDraftAtStep(
          uid,
          3,
          setupGeneration: 1,
          setupLineageVersion: 1,
          revision: 2,
        );
        // Active run claims SAME generation (1) and SAME lineage (1), but mismatched revision (5)
        final job = OnboardingCompletionJob(
          jobId: 'corrupt-same-lineage-run',
          ownerUid: uid,
          draftRevision: 5,
          sourceFingerprint: 'corrupt-same-lineage-fp',
          setupGeneration: 1,
          setupLineageVersion: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final run = OnboardingCurrentRunSnapshot(
          hasPointer: true,
          runId: 'corrupt-same-lineage-run',
          ownerUid: uid,
          pointerSchemaVersion: 1,
          pointerStatus: 'active',
          sourceFingerprint: 'corrupt-same-lineage-fp',
          draftRevision: 5,
          setupGeneration: 1,
          setupLineageVersion: 1,
          job: job,
        );

        final result = classifyServerReconstruction(
          ownerUid: uid,
          profile: profile,
          draft: draft,
          completionBundle: null,
          currentRun: run,
        );

        expect(result, isA<ReconstructionRecovery>());
        expect(
          (result as ReconstructionRecovery).diagnostics['code'],
          'completion_run_input_mismatch',
        );
      },
    );

    test('Completed legacy account is not migrated and returns ReconstructionCompleted', () async {
      final profile = UserProfile.empty(uid: uid).copyWith(
        onboardingCompleted: true,
        setupLineageVersion: 0,
        currentSetupGeneration: 0,
      );
      await profileRepo.saveUserProfile(profile);

      final draft = _finalDraft(uid, setupGeneration: 0, setupLineageVersion: 0);
      await onboardingRepo.saveDraft(draft);

      final bundle = _bundleForDraft(
        draft,
        setupGeneration: 0,
        setupLineageVersion: 0,
        runId: 'run-legacy-completed',
      );
      await onboardingRepo.saveCompletionBundle(bundle);

      memoryStore.currentRunIds[uid] = 'run-legacy-completed';
      memoryStore.currentRunStatuses[uid] = 'completed';
      memoryStore.jobs['$uid:run-legacy-completed'] = OnboardingCompletionJob(
        jobId: 'run-legacy-completed',
        ownerUid: uid,
        status: OnboardingJobStatus.completed,
        stage: OnboardingCompletionStage.completed,
        draftRevision: draft.revision,
        sourceFingerprint: draft.effectiveSourceFingerprint,
        setupGeneration: 0,
        setupLineageVersion: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await reconstructor.reconstruct(uid: uid);
      expect(result, isA<ReconstructionCompleted>());
      expect(result.profile.setupLineageVersion, 0); // Not mutated!
    });
  });
}

OnboardingDraft _validDraftAtStep(
  String uid,
  int targetStep, {
  int setupGeneration = 0,
  int setupLineageVersion = 0,
  int revision = 1,
}) {
  final stepCompleted = List<bool>.filled(OnboardingDraft.stepCount, false);
  for (int i = 0; i < targetStep; i++) {
    stepCompleted[i] = true;
  }
  return OnboardingDraft(
    uid: uid,
    currentStep: targetStep,
    stepCompleted: stepCompleted,
    setupGeneration: setupGeneration,
    setupLineageVersion: setupLineageVersion,
    revision: revision,
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
      gender: 'male',
    ),
    badHabitsNotNow: true,
    goodHabitsNotNow: true,
    baseTimeline: const BaseTimelineDraft(
      eatingSetupPath: 'skip',
      eatingMode: 'flat',
      shouldPlanMeals: false,
      skinCareSkipped: true,
    ).withRequiredFixedBlocks(),
  );
}

OnboardingDraft _finalDraft(
  String uid, {
  int setupGeneration = 0,
  int setupLineageVersion = 0,
}) {
  final stepCompleted = List<bool>.filled(OnboardingDraft.stepCount, true);
  return OnboardingDraft(
    uid: uid,
    currentStep: OnboardingDraft.lastStepIndex,
    onboardingCompleted: true,
    stepCompleted: stepCompleted,
    setupGeneration: setupGeneration,
    setupLineageVersion: setupLineageVersion,
    revision: 15,
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
      gender: 'male',
    ),
    badHabitsNotNow: true,
    goodHabitsNotNow: true,
    baseTimeline: const BaseTimelineDraft(
      eatingSetupPath: 'skip',
      eatingMode: 'flat',
      shouldPlanMeals: false,
      skinCareSkipped: true,
    ).withRequiredFixedBlocks(),
  );
}

OnboardingCompletionBundle _bundleForDraft(
  OnboardingDraft draft, {
  required int setupGeneration,
  int setupLineageVersion = 0,
  String? runId,
}) {
  final now = DateTime.now();
  return OnboardingCompletionBundle(
    uid: draft.uid,
    runId: runId ??
        stableOnboardingRunId(
          ownerUid: draft.uid,
          sourceFingerprint: draft.effectiveSourceFingerprint,
          draftRevision: draft.revision,
        ),
    createdAt: now,
    updatedAt: now,
    setupGeneration: setupGeneration,
    setupLineageVersion: setupLineageVersion,
    sourceFingerprint: draft.effectiveSourceFingerprint,
    draftRevision: draft.revision,
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
  );
}

class _InMemoryProfileRepository implements ProfileRepository {
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

class _InMemoryOnboardingRepository implements OnboardingRepository {
  final Map<String, OnboardingDraft> _drafts = {};
  final Map<String, OnboardingCompletionBundle> _bundles = {};

  @override
  Future<OnboardingDraft?> fetchDraft(String uid) async => _drafts[uid];

  @override
  Future<void> saveDraft(OnboardingDraft draft) async {
    _drafts[draft.uid] = draft;
  }

  @override
  Future<void> flushPendingDraftSave() async {}

  @override
  Future<void> saveFinalDraftImmediately(OnboardingDraft draft) async {
    _drafts[draft.uid] = draft;
  }

  @override
  Future<OnboardingCompletionBundle?> fetchCompletionBundle(String uid) async =>
      _bundles[uid];

  @override
  Future<void> saveCompletionBundle(OnboardingCompletionBundle bundle) async {
    _bundles[bundle.uid] = bundle;
  }

  @override
  Future<RoutineProjectionResult> completeOnboarding({
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
  }) async {
    await saveDraft(finalDraft);
    _bundles[bundle.uid] = bundle;
    return RoutineProjectionResult(
      outcome: RoutineProjectionOutcome.projected,
      receipt: RoutineOnboardingProjection.build(bundle).receipt,
    );
  }

  @override
  void dispose() {}
}
