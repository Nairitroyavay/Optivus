import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/router/app_router.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/services/session_destination_resolver.dart';
import 'package:optivus/services/onboarding_resume_validator.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/repositories/auth_repository.dart';

void main() {
  const owner = 'resume-owner';

  group('startup classification', () {
    test('fresh profile with no draft goes directly to Step 0', () {
      final result = resolveOnboardingSessionDestination(
        ownerUid: owner,
        profile: _profile(owner),
        draft: null,
      );

      expect(result.kind, SessionDestinationKind.freshOnboarding);
      expect(result.resumeStep, isNull);
    });

    test('newly-created untouched draft is still fresh', () {
      final result = resolveOnboardingSessionDestination(
        ownerUid: owner,
        profile: _profile(owner),
        draft: const OnboardingDraft(uid: owner),
      );

      expect(result.kind, SessionDestinationKind.freshOnboarding);
    });

    test('view/edit metadata alone cannot make a new account resumable', () {
      final result = resolveOnboardingSessionDestination(
        ownerUid: owner,
        profile: _profile(owner),
        draft: OnboardingDraft(
          uid: owner,
          currentStep: 7,
          revision: 9,
          welcomeSaved: true,
          stepDirty: List<bool>.filled(OnboardingDraft.stepCount, true),
        ),
      );

      expect(result.kind, SessionDestinationKind.freshOnboarding);
    });

    test('projection none and missing legacy data are not failures', () {
      final result = resolveOnboardingSessionDestination(
        ownerUid: owner,
        profile: _profile(owner, projectionStatus: 'none'),
        draft: null,
      );

      expect(result.kind, SessionDestinationKind.freshOnboarding);
    });

    test('failed projection does not turn partial input into recovery', () {
      final result = resolveOnboardingSessionDestination(
        ownerUid: owner,
        profile: _profile(owner, projectionStatus: 'failed'),
        draft: _draft(owner, firstIncompleteStep: 6),
      );

      expect(result.kind, SessionDestinationKind.resumeOnboarding);
      expect(result.resumeStep, 6);
    });

    test('a durable final draft resumes completion idempotently', () {
      final draft = _finalDraft(owner);
      final job = _job(owner, draft);
      final result = resolveOnboardingSessionDestination(
        ownerUid: owner,
        profile: _profile(
          owner,
          inputCompleted: true,
          projectionStatus: 'pending',
        ),
        draft: draft,
        completionJob: job,
      );

      expect(result.kind, SessionDestinationKind.finishOnboarding);
      expect(result.runId, job.jobId);
    });

    test('completed profile routes Home', () {
      final result = resolveOnboardingSessionDestination(
        ownerUid: owner,
        profile: _profile(
          owner,
          inputCompleted: true,
          projectionStatus: 'completed',
        ),
        draft: _finalDraft(owner),
      );

      expect(result.kind, SessionDestinationKind.home);
    });

    test('genuine owner mismatch routes Needs Action', () {
      final result = resolveOnboardingSessionDestination(
        ownerUid: owner,
        profile: _profile(owner),
        draft: _draft('another-owner', firstIncompleteStep: 3),
      );

      expect(result.kind, SessionDestinationKind.needsAction);
      expect(result.reasonCode, 'draft_owner_mismatch');
    });

    test('temporary network state is distinct from corruption', () {
      const auth = AuthState(status: AuthFlowStatus.reconnectRequired);
      expect(auth.sessionDestination.kind, SessionDestinationKind.reconnect);
    });
  });

  group('Step 0-14 durable resume matrix', () {
    for (
      var resumeStep = 0;
      resumeStep <= OnboardingDraft.lastStepIndex;
      resumeStep++
    ) {
      test(
        'first incomplete Step $resumeStep wins over viewed/cache state',
        () {
          final draft = _draft(
            owner,
            firstIncompleteStep: resumeStep,
            currentViewedStep: OnboardingDraft.lastStepIndex,
          );
          final result = resolveOnboardingSessionDestination(
            ownerUid: owner,
            profile: _profile(owner),
            draft: draft,
          );

          expect(
            result.kind,
            resumeStep == 0
                ? SessionDestinationKind.freshOnboarding
                : SessionDestinationKind.resumeOnboarding,
          );
          expect(result.resumeStep, resumeStep == 0 ? isNull : resumeStep);
          expect(durableOnboardingResumeStep(draft), resumeStep);
        },
      );
    }

    test('Step 3 incomplete can never resume Step 4', () {
      final draft = _draft(owner, firstIncompleteStep: 3, currentViewedStep: 4);
      expect(durableOnboardingResumeStep(draft), 3);
    });

    test('unsaved valid form state does not unlock a future step', () {
      final draft = _draft(owner, firstIncompleteStep: 3, currentViewedStep: 3)
          .copyWith(
            bodyBasics: const BodyBasicsDraft(
              ageRange: '25-34',
              heightCm: 175,
              weightKg: 70,
              gender: 'male',
            ),
            incrementRevision: false,
          );

      expect(durableOnboardingResumeStep(draft), 3);
    });

    for (final aiStep in const [4, 5, 7]) {
      test('AI Step $aiStep generated but unverified remains on that step', () {
        final draft = _draft(owner, firstIncompleteStep: aiStep);
        expect(durableOnboardingResumeStep(draft), aiStep);
      });
    }

    test('saved and verified step advances exactly once', () {
      final draft = _draft(owner, firstIncompleteStep: 8);
      expect(durableOnboardingResumeStep(draft), 8);
      expect(draft.stepCompleted[7], isTrue);
      expect(draft.stepCompleted[8], isFalse);
    });

    test(
      'downstream invalidation pulls resume back to earliest required work',
      () {
        final completed = List<bool>.filled(OnboardingDraft.stepCount, true)
          ..[4] = false
          ..[5] = false
          ..[14] = false;
        final draft = _draft(
          owner,
          firstIncompleteStep: OnboardingDraft.lastStepIndex,
          currentViewedStep: 13,
        ).copyWith(stepCompleted: completed, incrementRevision: false);

        expect(durableOnboardingResumeStep(draft), 4);
      },
    );
  });

  group('single-destination router', () {
    final profile = _profile(owner);
    const user = AuthUser(uid: owner, emailVerified: true);

    test(
      'fresh and resume destinations both enter onboarding without loops',
      () {
        for (final auth in const [
          AuthState(
            user: user,
            status: AuthFlowStatus.signedInOnboardingIncomplete,
          ),
          AuthState(
            user: user,
            status: AuthFlowStatus.signedInOnboardingIncomplete,
            resumeStep: 7,
          ),
        ]) {
          expect(
            optivusAuthRedirect(
              authState: auth,
              userProfile: profile,
              uri: Uri.parse('/app'),
            ),
            '/onboarding',
          );
          expect(
            optivusAuthRedirect(
              authState: auth,
              userProfile: profile,
              uri: Uri.parse('/onboarding'),
            ),
            isNull,
          );
        }
      },
    );

    test(
      'completion, reconnect, and needs-action each have one stable route',
      () {
        final cases = <AuthState, String>{
          const AuthState(
            user: user,
            status: AuthFlowStatus.finishingOnboarding,
          ): '/onboarding/finishing',
          const AuthState(user: user, status: AuthFlowStatus.reconnectRequired):
              '/onboarding/reconnect',
          const AuthState(user: user, status: AuthFlowStatus.needsAction):
              '/onboarding/needs-action',
        };

        for (final entry in cases.entries) {
          expect(
            optivusAuthRedirect(
              authState: entry.key,
              userProfile: profile,
              uri: Uri.parse('/onboarding'),
            ),
            entry.value,
          );
          expect(
            optivusAuthRedirect(
              authState: entry.key,
              userProfile: profile,
              uri: Uri.parse(entry.value),
            ),
            isNull,
          );
        }
      },
    );
  });
}

UserProfile _profile(
  String uid, {
  bool inputCompleted = false,
  String projectionStatus = 'none',
}) {
  return UserProfile.empty(uid: uid).copyWith(
    onboardingInputCompleted: inputCompleted,
    onboardingProjectionStatus: projectionStatus,
  );
}

OnboardingDraft _draft(
  String uid, {
  required int firstIncompleteStep,
  int? currentViewedStep,
}) {
  final completed = List<bool>.generate(
    OnboardingDraft.stepCount,
    (step) => step < firstIncompleteStep,
  );
  return OnboardingDraft(
    uid: uid,
    currentStep: currentViewedStep ?? firstIncompleteStep,
    welcomeSaved: true,
    stepCompleted: completed,
    stepDirty: List<bool>.filled(OnboardingDraft.stepCount, false),
    stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
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
    baseTimeline: const BaseTimelineDraft(
      eatingSetupPath: 'skip',
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
    ),
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

OnboardingDraft _finalDraft(String uid) {
  return OnboardingDraft(
    uid: uid,
    currentStep: OnboardingDraft.lastStepIndex,
    welcomeSaved: true,
    onboardingCompleted: true,
    stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
    stepDirty: List<bool>.filled(OnboardingDraft.stepCount, false),
    stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
  );
}

OnboardingCompletionJob _job(String uid, OnboardingDraft draft) {
  final now = DateTime.utc(2026, 8, 28);
  return OnboardingCompletionJob(
    jobId: 'resume-run',
    ownerUid: uid,
    status: OnboardingJobStatus.running,
    stage: OnboardingCompletionStage.persistBundle,
    sourceFingerprint: draft.effectiveSourceFingerprint,
    draftRevision: draft.revision,
    createdAt: now,
    updatedAt: now,
  );
}
