import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/errors/diagnostic_codes.dart';
import 'package:optivus/core/errors/recoverable_error.dart';
import 'package:optivus/core/router/app_router.dart';
import 'package:optivus/features/profile/models/profile_settings_models.dart';
import 'package:optivus/features/recovery/models/onboarding_recovery_models.dart';
import 'package:optivus/features/recovery/screens/onboarding_recovery_screen.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';

void main() {
  group('Group A Stress Tests: Multi-stage Idempotency & Failure Injection', () {
    test(
      'JobService resumes correctly when stage 1 and 2 are pre-completed',
      () async {
        final onboardingRepo = FakeOnboardingRepository();
        final profileRepo = FakeProfileRepository();
        final jobService = OnboardingCompletionJobService(
          onboardingRepository: onboardingRepo,
          profileRepository: profileRepo,
        );

        const uid = 'stress-resume-user';
        final draft = _completedDraft(uid);
        final bundle = OnboardingCompletionService.buildBundle(draft);
        await profileRepo.saveUserProfile(
          UserProfile.empty(uid: uid, email: 'test@example.com'),
        );

        // Save draft and bundle beforehand to simulate stages 1 & 2 done
        await onboardingRepo.saveDraft(draft);
        await onboardingRepo.saveCompletionBundle(bundle);

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

        final profile = await profileRepo.fetchUserProfile(uid);
        expect(profile?.onboardingCompleted, isTrue);
      },
    );

    test(
      'JobService handles injected failure during atomic routine projection',
      () async {
        final onboardingRepo = FakeOnboardingRepository();
        final profileRepo = FakeProfileRepository();
        final jobService = OnboardingCompletionJobService(
          onboardingRepository: onboardingRepo,
          profileRepository: profileRepo,
        );

        const uid = 'stress-fail-user';
        final draft = _completedDraft(uid);
        final bundle = OnboardingCompletionService.buildBundle(draft);
        await profileRepo.saveUserProfile(
          UserProfile.empty(uid: uid, email: 'test@example.com'),
        );

        // Inject failure on first attempt
        onboardingRepo.failNextCompletionBeforeCommit();

        await expectLater(
          jobService.runCompletionJob(
            uid: uid,
            finalDraft: draft,
            bundle: bundle,
          ),
          throwsA(isA<RoutineProjectionRetryRequiredException>()),
        );

        // Verify retry succeeds cleanly on second execution
        final completedJob = await jobService.runCompletionJob(
          uid: uid,
          finalDraft: draft,
          bundle: bundle,
        );

        expect(completedJob.status, equals(OnboardingJobStatus.completed));
        expect(
          completedJob.isStageCompleted(
            OnboardingCompletionStage.projectRoutines,
          ),
          isTrue,
        );
      },
    );

    test(
      'JobService retry preserves persisted stage progress after failure',
      () async {
        final onboardingRepo = _CountingOnboardingRepository();
        final profileRepo = FakeProfileRepository();
        final jobService = OnboardingCompletionJobService(
          onboardingRepository: onboardingRepo,
          profileRepository: profileRepo,
        );

        const uid = 'stress-resume-persisted-stage-user';
        final draft = _completedDraft(uid);
        final bundle = OnboardingCompletionService.buildBundle(draft);
        await profileRepo.saveUserProfile(
          UserProfile.empty(uid: uid, email: 'test@example.com'),
        );

        onboardingRepo.failNextCompletionBeforeCommit();
        await expectLater(
          jobService.runCompletionJob(
            uid: uid,
            finalDraft: draft,
            bundle: bundle,
          ),
          throwsA(isA<RoutineProjectionRetryRequiredException>()),
        );

        final completedJob = await jobService.runCompletionJob(
          uid: uid,
          finalDraft: draft,
          bundle: bundle,
        );

        expect(completedJob.status, equals(OnboardingJobStatus.completed));
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
        expect(onboardingRepo.saveFinalDraftImmediatelyCount, equals(1));
        expect(onboardingRepo.saveCompletionBundleCount, equals(1));
        expect(onboardingRepo.completeOnboardingCount, equals(2));
      },
    );

    test(
      'JobService fails habit stage when frontend hydration is required and reader is absent',
      () async {
        final onboardingRepo = FakeOnboardingRepository();
        final profileRepo = FakeProfileRepository();
        final jobService = OnboardingCompletionJobService(
          onboardingRepository: onboardingRepo,
          profileRepository: profileRepo,
          requireFrontendHydration: true,
        );

        const uid = 'stress-missing-reader-user';
        final draft = _completedDraft(uid);
        final bundle = OnboardingCompletionService.buildBundle(draft);

        await expectLater(
          jobService.runCompletionJob(
            uid: uid,
            finalDraft: draft,
            bundle: bundle,
          ),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  group('Group A Stress Tests: Recovery Fallback Tier Transitions', () {
    test('Tier 1 fallback rejects bundle with mismatched UID', () async {
      final onboardingRepo = FakeOnboardingRepository();
      final profileRepo = FakeProfileRepository();
      const uid = 'user-mismatched';
      const foreignUid = 'user-other';

      final draft = OnboardingDraft(
        uid: foreignUid,
      ).copyWith(onboardingCompleted: true);
      final bundle = OnboardingCompletionService.buildBundle(draft);
      // Save bundle under 'user-mismatched' key in repo, but inner bundle.uid is 'user-other'
      await onboardingRepo.saveCompletionBundle(bundle);

      final result = await OnboardingCompletionService.recoverCompletionState(
        uid: uid,
        onboardingRepository: onboardingRepo,
        profileRepository: profileRepo,
      );

      // Should bypass Tier 1 because bundle.uid != uid, and fall through to Tier 4
      expect(result.tier, equals(OnboardingRecoveryTier.tier4ResetRequired));
    });

    test(
      'Tier 2 rebuilds bundle with accurate schedule items from complex draft',
      () async {
        final onboardingRepo = FakeOnboardingRepository();
        final profileRepo = FakeProfileRepository();
        const uid = 'complex-draft-user';

        final draft = _completedDraft(uid).copyWith(
          goodHabits: [
            const GoodHabitDraft(
              id: 'gh-1',
              habitKey: 'reading',
              displayName: 'Read Books',
              durationMinutes: 30,
            ),
          ],
          badHabits: [
            const BadHabitDraft(
              id: 'bh-1',
              habitKey: 'junk_food',
              displayName: 'Junk Food',
              dailySpend: 15.0,
            ),
          ],
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
        expect(result.bundle, isNotNull);
        expect(result.bundle!.goodHabitTemplates.length, equals(1));
        expect(result.bundle!.badHabitCheckIns.length, equals(1));
        expect(result.bundle!.moneyGoal?.dailyTarget, equals(15.0));
      },
    );
  });

  group(
    'Group A Stress Tests: Routine Projection & Fingerprint Consistency',
    () {
      test(
        'RoutineOnboardingProjection generates stable deterministic fingerprint',
        () {
          const uid = 'fingerprint-user';
          final draft = OnboardingDraft(
            uid: uid,
          ).copyWith(onboardingCompleted: true);
          final bundle1 = OnboardingCompletionService.buildBundle(draft);
          final bundle2 = OnboardingCompletionService.buildBundle(draft);

          final plan1 = RoutineOnboardingProjection.build(bundle1);
          final plan2 = RoutineOnboardingProjection.build(bundle2);

          expect(plan1.fingerprint, equals(plan2.fingerprint));
          expect(plan1.fingerprint.length, equals(64)); // SHA256 hex string
        },
      );
    },
  );

  group('Group A Stress Tests: Router Redirection & Recovery UI', () {
    testWidgets(
      'Router routes needsAction to /onboarding/recovery rendering OnboardingRecoveryScreen',
      (tester) async {
        final profile =
            UserProfile.empty(
              uid: 'stress-failed-user',
              email: 'stress-failed@ex.com',
            ).copyWith(
              onboardingInputCompleted: true,
              onboardingProjectionStatus: 'failed',
            );

        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(
              (ref) => _FakeAuthNotifier(
                const AuthState(
                  user: AuthUser(
                    uid: 'stress-failed-user',
                    email: 'stress-failed@ex.com',
                    emailVerified: true,
                  ),
                  status: AuthFlowStatus.needsAction,
                  error: RecoverableError(
                    category: RecoverableErrorCategory.recoveryRequired,
                    publicMessage: 'Restoration failed during startup',
                    severity: RecoverableErrorSeverity.error,
                    isBlocking: true,
                    retryAction: RecoverableRetryAction.restartRecovery,
                    retrySafe: false,
                    diagnosticCode:
                        DiagnosticCodes.recoveryDurableStateConflict,
                  ),
                ),
              ),
            ),
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()..loadSeedData(profile),
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

        expect(find.byType(OnboardingRecoveryScreen), findsOneWidget);
      },
    );
  });
}

OnboardingDraft _completedDraft(String uid) {
  return OnboardingDraft(
    uid: uid,
    currentStep: OnboardingDraft.lastStepIndex,
    stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
    stepDirty: List<bool>.filled(OnboardingDraft.stepCount, false),
    stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
    onboardingCompleted: true,
    createdAt: DateTime.utc(2026, 8, 3),
    updatedAt: DateTime.utc(2026, 8, 3),
  );
}

class _CountingOnboardingRepository extends FakeOnboardingRepository {
  int saveDraftCount = 0;
  int saveCompletionBundleCount = 0;
  int completeOnboardingCount = 0;

  int saveFinalDraftImmediatelyCount = 0;

  @override
  Future<void> saveFinalDraftImmediately(OnboardingDraft draft) {
    saveFinalDraftImmediatelyCount++;
    return super.saveFinalDraftImmediately(draft);
  }

  @override
  Future<void> saveCompletionBundle(OnboardingCompletionBundle bundle) {
    saveCompletionBundleCount++;
    return super.saveCompletionBundle(bundle);
  }

  @override
  Future<RoutineProjectionResult> completeOnboarding({
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
  }) {
    completeOnboardingCount++;
    return super.completeOnboarding(finalDraft: finalDraft, bundle: bundle);
  }
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
