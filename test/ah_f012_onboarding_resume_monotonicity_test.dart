import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_resume_validator.dart';
import 'package:optivus/services/server_reconstructor.dart';
import 'package:optivus/services/session_destination_resolver.dart';

void main() {
  const uid = 'ah-f012-owner';

  group('AH-F012 canonical predecessor validation', () {
    test('currentStep 8 cannot skip durably invalid Step 3', () {
      final draft = _validDraftAt(
        uid,
        8,
        currentStep: 8,
      ).copyWith(bodyBasics: const BodyBasicsDraft(), incrementRevision: false);

      expect(validateOnboardingResume(draft).resumeStep, 3);
      expect(_classify(uid, draft), isA<ReconstructionIncomplete>());
      expect((_classify(uid, draft) as ReconstructionIncomplete).step, 3);
    });

    test('currentStep 3 does not hold valid predecessors behind Step 7', () {
      final draft = _validDraftAt(uid, 7, currentStep: 3).copyWith(
        baseTimeline: _validBaseTimeline().copyWith(
          skinCareSkipped: false,
          clearSkinCarePlanning: true,
        ),
        incrementRevision: false,
      );

      expect(validateOnboardingResume(draft).resumeStep, 7);
    });

    test('null decoded currentStep derives Step 7 from durable state', () {
      final map = _validDraftAt(uid, 7).toMap()..['currentStep'] = null;
      final decoded = OnboardingDraft.fromMap(map);

      expect(decoded.currentStep, 0);
      expect(validateOnboardingResume(decoded).resumeStep, 7);
    });

    test('extreme currentStep is ignored when Step 2 is incomplete', () {
      final map = _validDraftAt(uid, 2).toMap()..['currentStep'] = 999;
      final draft = OnboardingDraft.fromMap(map);

      expect(draft.currentStep, OnboardingDraft.lastStepIndex);
      expect(validateOnboardingResume(draft).resumeStep, 2);
    });

    test(
      'unknown string currentStep is harmless non-authoritative metadata',
      () {
        final map = _validDraftAt(uid, 7).toMap()
          ..['currentStep'] = 'legacy-unknown-step';
        final draft = OnboardingDraft.fromMap(map);

        expect(draft.currentStep, 0);
        expect(validateOnboardingResume(draft).resumeStep, 7);
      },
    );

    test('later Step 4 and 5 data cannot waive a Step 3 hole', () {
      final completed = List<bool>.generate(
        OnboardingDraft.stepCount,
        (step) => step < 6,
      )..[3] = false;
      final draft = _validDraftAt(uid, 6).copyWith(
        currentStep: 5,
        stepCompleted: completed,
        incrementRevision: false,
      );

      expect(validateOnboardingResume(draft).resumeStep, 3);
    });

    test('multiple invalid steps always return the earliest one', () {
      final validBase = _validBaseTimeline();
      final bothInvalid = _validDraftAt(uid, 6).copyWith(
        bodyBasics: const BodyBasicsDraft(),
        baseTimeline: validBase.copyWith(
          blocks: validBase.blocks
              .where((block) => block.section != 'eating')
              .toList(),
          clearMealPlanning: true,
        ),
        incrementRevision: false,
      );
      expect(validateOnboardingResume(bothInvalid).resumeStep, 3);

      final stepFiveOnly = bothInvalid.copyWith(
        bodyBasics: _validBody(),
        incrementRevision: false,
      );
      expect(validateOnboardingResume(stepFiveOnly).resumeStep, 5);
    });

    test('explicitly skipped optional skin care advances to Step 8', () {
      final draft = _validDraftAt(uid, 8);

      expect(draft.baseTimeline.skinCareSkipped, isTrue);
      expect(validateOnboardingResume(draft).resumeStep, 8);
    });
  });

  group('AH-F012 conditional role validation', () {
    test('student requires classes and ignores work', () {
      final draft = _roleDraft(
        uid,
        const LifeRoleDraft(
          lifeRole: LifeRoleDraft.studentKey,
          exerciseLevel: 'moderate',
          waterIntake: 'medium',
          stressLevel: 'medium',
          sleepQuality: 'good',
        ),
        const [_classBlock],
      );

      expect(validateOnboardingResume(draft).resumeStep, 5);
    });

    test('working requires work and ignores classes', () {
      final draft = _roleDraft(
        uid,
        const LifeRoleDraft(
          lifeRole: LifeRoleDraft.workingKey,
          workType: 'office',
          exerciseLevel: 'moderate',
          waterIntake: 'medium',
          stressLevel: 'medium',
          sleepQuality: 'good',
        ),
        const [_workBlock],
      );

      expect(validateOnboardingResume(draft).resumeStep, 5);
    });

    test('studentWorking requires both class and work schedules', () {
      const role = LifeRoleDraft(
        lifeRole: LifeRoleDraft.studentWorkingKey,
        workType: 'part_time',
        exerciseLevel: 'moderate',
        waterIntake: 'medium',
        stressLevel: 'medium',
        sleepQuality: 'good',
      );
      final missingWork = _roleDraft(uid, role, const [_classBlock]);
      final both = _roleDraft(uid, role, const [_classBlock, _workBlock]);

      expect(validateOnboardingResume(missingWork).resumeStep, 4);
      expect(validateOnboardingResume(both).resumeStep, 5);
    });

    test('business role requires work/business schedule', () {
      final missingWork = _roleDraft(
        uid,
        const LifeRoleDraft(
          lifeRole: LifeRoleDraft.businessKey,
          businessMode: 'fixed_business',
          exerciseLevel: 'moderate',
          waterIntake: 'medium',
          stressLevel: 'medium',
          sleepQuality: 'good',
        ),
        const [],
      );
      final withWork = _roleDraft(
        uid,
        const LifeRoleDraft(
          lifeRole: LifeRoleDraft.businessKey,
          businessMode: 'fixed_business',
          exerciseLevel: 'moderate',
          waterIntake: 'medium',
          stressLevel: 'medium',
          sleepQuality: 'good',
        ),
        const [_workBlock],
      );

      expect(validateOnboardingResume(missingWork).resumeStep, 4);
      expect(validateOnboardingResume(withWork).resumeStep, 5);
    });

    test('not_student_not_working skips class and work schedule requirement', () {
      final draft = _roleDraft(
        uid,
        const LifeRoleDraft(
          lifeRole: LifeRoleDraft.notStudentNotWorkingKey,
          exerciseLevel: 'moderate',
          waterIntake: 'medium',
          stressLevel: 'medium',
          sleepQuality: 'good',
        ),
        const [],
      );

      expect(validateOnboardingResume(draft).resumeStep, 5);
    });
  });

  group('AH-F012 optional vs required step requirement validation', () {
    test('bad habits optional skip passes but empty without skip stops at Step 8', () {
      final skipped = _validDraftAt(uid, 9).copyWith(
        badHabitsNotNow: true,
        badHabits: const [],
        incrementRevision: false,
      );
      final unselected = _validDraftAt(uid, 9).copyWith(
        badHabitsNotNow: false,
        badHabits: const [],
        incrementRevision: false,
      );

      expect(validateOnboardingResume(skipped).resumeStep, 9);
      expect(validateOnboardingResume(unselected).resumeStep, 8);
    });

    test('good habits optional skip passes but empty without skip stops at Step 9', () {
      final skipped = _validDraftAt(uid, 10).copyWith(
        goodHabitsNotNow: true,
        goodHabits: const [],
        incrementRevision: false,
      );
      final unselected = _validDraftAt(uid, 10).copyWith(
        goodHabitsNotNow: false,
        goodHabits: const [],
        incrementRevision: false,
      );

      expect(validateOnboardingResume(skipped).resumeStep, 10);
      expect(validateOnboardingResume(unselected).resumeStep, 9);
    });

    test('empty identity goals stops at Step 10', () {
      final draft = _validDraftAt(uid, 11).copyWith(
        identityGoals: const [],
        incrementRevision: false,
      );

      expect(validateOnboardingResume(draft).resumeStep, 10);
    });

    test('incomplete coach setup stops at Step 11', () {
      final draft = _validDraftAt(uid, 12).copyWith(
        coachSetup: const CoachSetupDraft(),
        incrementRevision: false,
      );

      expect(validateOnboardingResume(draft).resumeStep, 11);
    });

    test('missing slip up handling stops at Step 12', () {
      final draft = _validDraftAt(uid, 13).copyWith(
        clearSlipUpHandling: true,
        incrementRevision: false,
      );

      expect(validateOnboardingResume(draft).resumeStep, 12);
    });

    test('unconfirmed notifications preferences stops at Step 13', () {
      final draft = _validDraftAt(uid, 14).copyWith(
        notifications: const NotificationSetupDraft(preferencesConfirmed: false),
        incrementRevision: false,
      );

      expect(validateOnboardingResume(draft).resumeStep, 13);
    });
  });

  group('AH-F012 durable requirement interactions', () {
    test('missing height or weight blocks Body Basics without defaults', () {
      final missingHeight = _validDraftAt(uid, 4).copyWith(
        bodyBasics: const BodyBasicsDraft(
          ageRange: '25-34',
          weightKg: 70,
          gender: 'other',
        ),
        incrementRevision: false,
      );
      final missingWeight = _validDraftAt(uid, 4).copyWith(
        bodyBasics: const BodyBasicsDraft(
          ageRange: '25-34',
          heightCm: 170,
          gender: 'other',
        ),
        incrementRevision: false,
      );

      expect(validateOnboardingResume(missingHeight).resumeStep, 3);
      expect(validateOnboardingResume(missingWeight).resumeStep, 3);
      expect(missingHeight.bodyBasics.heightCm, isNull);
      expect(missingWeight.bodyBasics.weightKg, isNull);
    });

    test('explicit 170 cm and 70 kg are valid durable values', () {
      final draft = _validDraftAt(uid, 4).copyWith(
        bodyBasics: const BodyBasicsDraft(
          ageRange: '25-34',
          heightCm: 170,
          weightKg: 70,
          gender: 'other',
        ),
        incrementRevision: false,
      );

      expect(validateOnboardingResume(draft).resumeStep, 4);
    });

    test('durable uploaded skin asset passes with no local path', () {
      final base = _validBaseTimeline().copyWith(
        skinCareSkipped: false,
        skinCareSetupPath: 'no_products',
        skinCareProductPhotoAssetId: 'asset-1',
        skinCareProductPhotoR2Key: 'users/$uid/skin/asset-1.jpg',
        skinCareProductPhotoStatus: UploadedAssetStatus.uploaded.wireName,
      );
      final draft = _validDraftAt(
        uid,
        8,
      ).copyWith(baseTimeline: base, incrementRevision: false);

      expect(validateOnboardingResume(draft).resumeStep, 8);
    });

    test('local-only unuploaded image cannot satisfy server validation', () {
      const ignoredLocalPath = '/tmp/selected-but-not-uploaded.jpg';
      final draft = _validDraftAt(uid, 8).copyWith(
        baseTimeline: _validBaseTimeline().copyWith(
          skinCareSkipped: false,
          skinCareSetupPath: 'no_products',
        ),
        incrementRevision: false,
      );

      expect(ignoredLocalPath, isNotEmpty);
      expect(validateOnboardingResume(draft).resumeStep, 7);
    });

    test('failed save uses old server Step 3, not valid in-memory edit', () {
      final serverDraft = _validDraftAt(
        uid,
        4,
        currentStep: 8,
      ).copyWith(bodyBasics: const BodyBasicsDraft(), incrementRevision: false);
      final inMemoryDraft = serverDraft.copyWith(
        bodyBasics: _validBody(),
        incrementRevision: false,
      );

      expect(
        inMemoryDraft.validateStep(3, inMemoryDraft.stepCompleted),
        isNull,
      );
      expect(validateOnboardingResume(serverDraft).resumeStep, 3);
    });

    test('Firebase missing durable data is not filled by mock seed data', () {
      final serverDraft = _validDraftAt(
        uid,
        4,
      ).copyWith(bodyBasics: const BodyBasicsDraft(), incrementRevision: false);

      expect(validateOnboardingResume(serverDraft).resumeStep, 3);
      expect(serverDraft.bodyBasics.heightCm, isNull);
      expect(serverDraft.bodyBasics.weightKg, isNull);
    });
  });

  group('AH-F012 reconstruction boundaries and purity', () {
    test('cold warm relogin and zero-cache return the same server step', () {
      final draft = _validDraftAt(uid, 7, currentStep: 13).copyWith(
        baseTimeline: _validBaseTimeline().copyWith(
          skinCareSkipped: false,
          clearSkinCarePlanning: true,
        ),
        incrementRevision: false,
      );
      final results = <int>{};
      for (final mode in const ['cold', 'warm', 'relogin', 'zero-cache']) {
        expect(mode, isNotEmpty);
        results.add(validateOnboardingResume(draft).resumeStep);
      }

      expect(results, {7});
    });

    test('account switch validates only the target UID durable draft', () {
      final accountA = _validDraftAt('account-a', 8);
      final accountB = _validDraftAt(
        'account-b',
        4,
      ).copyWith(bodyBasics: const BodyBasicsDraft(), incrementRevision: false);

      expect(validateOnboardingResume(accountA).resumeStep, 8);
      expect(validateOnboardingResume(accountB).resumeStep, 3);
    });

    test('same input is deterministic and validation has no mutation', () {
      final draft = _validDraftAt(uid, 7, currentStep: -1);
      final before = draft.toMap();
      final first = validateOnboardingResume(draft);
      final second = validateOnboardingResume(draft);

      expect(first.resumeStep, second.resumeStep);
      expect(first.reason, second.reason);
      expect(first.diagnosticCode, second.diagnosticCode);
      expect(draft.toMap(), before);
    });

    test('unsupported schema remains typed AH-F007 Recovery', () {
      final draft = _validDraftAt(uid, 7).copyWith(
        storedSchemaVersion: OnboardingDraft.schemaVersion + 1,
        incrementRevision: false,
      );

      expect(
        (_classify(uid, draft) as ReconstructionRecovery).reason,
        ReconstructionRecoveryReason.schemaUnsupported,
      );
    });

    test('valid Finishing state is not downgraded by stale currentStep', () {
      final draft = _finalDraft(
        uid,
      ).copyWith(currentStep: 2, incrementRevision: false);
      final result = classifyServerReconstruction(
        ownerUid: uid,
        profile: _profile(uid, inputCompleted: true),
        draft: draft,
        completionBundle: _bundle(uid, draft),
        currentRun: const OnboardingCurrentRunSnapshot.none(),
      );

      expect(result, isA<ReconstructionFinishing>());
    });

    test('Completed user never reenters onboarding for stale currentStep', () {
      final draft = _finalDraft(
        uid,
      ).copyWith(currentStep: 1, incrementRevision: false);
      final job = _job(uid, draft);
      final result = classifyServerReconstruction(
        ownerUid: uid,
        profile: _profile(uid, inputCompleted: true, completed: true),
        draft: draft,
        completionBundle: _bundle(uid, draft),
        currentRun: OnboardingCurrentRunSnapshot(
          hasPointer: true,
          runId: job.jobId,
          ownerUid: uid,
          pointerSchemaVersion: 1,
          job: job,
        ),
      );

      expect(result, isA<ReconstructionCompleted>());
    });

    test('same-UID refresh maintains stable session destination without side effects', () {
      final draft = _validDraftAt(uid, 7, currentStep: 3).copyWith(
        baseTimeline: _validBaseTimeline().copyWith(
          skinCareSkipped: false,
          clearSkinCarePlanning: true,
        ),
        incrementRevision: false,
      );
      final profile = _profile(uid);

      final firstDest = resolveOnboardingSessionDestination(
        ownerUid: uid,
        profile: profile,
        draft: draft,
      );
      final secondDest = resolveOnboardingSessionDestination(
        ownerUid: uid,
        profile: profile,
        draft: draft,
      );

      expect(firstDest.kind, SessionDestinationKind.resumeOnboarding);
      expect(firstDest.resumeStep, 7);
      expect(secondDest.kind, SessionDestinationKind.resumeOnboarding);
      expect(secondDest.resumeStep, 7);
    });
  });
}

const _classBlock = TimelineBlockDraft(
  id: 'class-1',
  section: 'classes',
  title: 'Class',
  startMinute: 540,
  endMinute: 600,
  repeatDays: [1],
  blockType: TimelineBlockDraft.hardBlockKey,
);

const _workBlock = TimelineBlockDraft(
  id: 'work-1',
  section: 'job_work_business',
  title: 'Work',
  startMinute: 600,
  endMinute: 660,
  repeatDays: [2],
  blockType: TimelineBlockDraft.hardBlockKey,
);

BodyBasicsDraft _validBody() => const BodyBasicsDraft(
  ageRange: '25-34',
  heightCm: 175,
  weightKg: 70,
  gender: 'other',
);

BaseTimelineDraft _validBaseTimeline() => const BaseTimelineDraft(
  eatingSetupPath: 'create',
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

OnboardingDraft _validDraftAt(String uid, int step, {int? currentStep}) {
  return OnboardingDraft(
    uid: uid,
    currentStep: currentStep ?? step,
    welcomeSaved: true,
    stepCompleted: List<bool>.generate(
      OnboardingDraft.stepCount,
      (index) => index < step,
    ),
    patiencePledgeAccepted: true,
    lifeRole: const LifeRoleDraft(
      lifeRole: LifeRoleDraft.notStudentNotWorkingKey,
      exerciseLevel: 'moderate',
      waterIntake: 'medium',
      stressLevel: 'medium',
      sleepQuality: 'good',
    ),
    bodyBasics: _validBody(),
    baseTimeline: _validBaseTimeline(),
    badHabitsNotNow: true,
    goodHabitsNotNow: true,
    identityGoals: const [
      IdentityGoalDraft(
        goalKey: 'healthy',
        displayName: 'Healthy person',
        systemKeys: [],
      ),
    ],
    coachSetup: const CoachSetupDraft(
      coachName: 'Nova',
      coachStyle: 'supportive',
    ),
    slipUpHandling: 'restart_small',
    notifications: const NotificationSetupDraft(preferencesConfirmed: true),
  );
}

OnboardingDraft _roleDraft(
  String uid,
  LifeRoleDraft role,
  List<TimelineBlockDraft> roleBlocks,
) {
  final base = _validBaseTimeline();
  return _validDraftAt(uid, 5).copyWith(
    lifeRole: role,
    baseTimeline: base.copyWith(blocks: [...base.blocks, ...roleBlocks]),
    incrementRevision: false,
  );
}

OnboardingDraft _finalDraft(String uid) =>
    _validDraftAt(uid, OnboardingDraft.lastStepIndex).copyWith(
      stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
      onboardingCompleted: true,
      incrementRevision: false,
    );

UserProfile _profile(
  String uid, {
  bool inputCompleted = false,
  bool completed = false,
}) => UserProfile.empty(uid: uid).copyWith(
  onboardingInputCompleted: inputCompleted,
  onboardingCompleted: completed,
  onboardingProjectionStatus: completed ? 'completed' : 'pending',
);

ReconstructionResult _classify(String uid, OnboardingDraft draft) =>
    classifyServerReconstruction(
      ownerUid: uid,
      profile: _profile(uid),
      draft: draft,
      completionBundle: null,
      currentRun: const OnboardingCurrentRunSnapshot.none(),
    );

OnboardingCompletionBundle _bundle(String uid, OnboardingDraft draft) =>
    OnboardingCompletionBundle(
      uid: uid,
      runId: 'run-f012',
      createdAt: DateTime.utc(2026, 8, 31),
      updatedAt: DateTime.utc(2026, 8, 31),
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

OnboardingCompletionJob _job(String uid, OnboardingDraft draft) =>
    OnboardingCompletionJob(
      jobId: 'run-f012',
      ownerUid: uid,
      status: OnboardingJobStatus.completed,
      stage: OnboardingCompletionStage.completed,
      sourceFingerprint: draft.effectiveSourceFingerprint,
      draftRevision: draft.revision,
      createdAt: DateTime.utc(2026, 8, 31),
      updatedAt: DateTime.utc(2026, 8, 31),
    );
