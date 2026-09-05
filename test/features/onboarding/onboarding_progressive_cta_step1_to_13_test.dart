import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/onboarding_flow.dart';
import 'package:optivus/features/onboarding/onboarding_step_readiness.dart';
import 'package:optivus/features/recovery/models/onboarding_recovery_models.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/skin_care_product_draft.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';

class _FakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _FakeAuthNotifier([AuthState? initial])
    : super(
        initial ??
            const AuthState(
              user: AuthUser(
                uid: 'test-user',
                email: 'test@example.com',
                emailVerified: true,
                isAnonymous: false,
              ),
              status: AuthFlowStatus.signedInOnboardingIncomplete,
            ),
      );

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
  Future<void> signup(String name, String email, String password) async {}

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
  Future<void> executeRecoveryAction(OnboardingRecoveryAction action) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Onboarding Step Readiness Contract - Steps 1 to 13 Matrix', () {
    test('Step 1: Patience Pledge requirement', () {
      final incomplete = const OnboardingDraft();
      final accepted = const OnboardingDraft(patiencePledgeAccepted: true);

      final r1 = evaluateOnboardingStepReadiness(
        draft: incomplete,
        step: 1,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r1.canRevealPrimary, isFalse);
      expect(r1.definition.requirement, OnboardingStepRequirement.required);
      expect(r1.definition.skipAllowed, isFalse);

      final r2 = evaluateOnboardingStepReadiness(
        draft: accepted,
        step: 1,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r2.canRevealPrimary, isTrue);
    });

    test('Step 2: Role and lifestyle conditional requirements', () {
      // Empty draft -> incomplete
      var draft = const OnboardingDraft();
      var r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 2,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isFalse);

      // Student role selected without lifestyle inputs -> incomplete
      draft = draft.copyWith(
        lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
      );
      r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 2,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isFalse);

      // Student with all lifestyle inputs -> complete
      draft = draft.copyWith(
        lifeRole: const LifeRoleDraft(
          lifeRole: LifeRoleDraft.studentKey,
          exerciseLevel: 'moderate',
          waterIntake: '2_3_liters',
          stressLevel: 'medium',
          sleepQuality: 'good',
        ),
      );
      r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 2,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isTrue);

      // Change role to working without workType -> dynamic recomputation makes it incomplete
      draft = draft.copyWith(
        lifeRole: draft.lifeRole.copyWith(
          lifeRole: LifeRoleDraft.workingKey,
          clearWorkType: true,
        ),
      );
      r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 2,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isFalse);

      // Working with workType -> complete
      draft = draft.copyWith(
        lifeRole: draft.lifeRole.copyWith(workType: 'full_time'),
      );
      r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 2,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isTrue);
    });

    test('Step 3: Body Basics required details and validation ranges', () {
      var draft = const OnboardingDraft();
      var r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 3,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isFalse);

      // Age range only -> incomplete
      draft = draft.copyWith(
        bodyBasics: const BodyBasicsDraft(ageRange: '25-34'),
      );
      r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 3,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isFalse);

      // Invalid height/weight -> incomplete
      draft = draft.copyWith(
        bodyBasics: const BodyBasicsDraft(
          ageRange: '25-34',
          gender: 'male',
          heightCm: 0,
          weightKg: 70,
        ),
      );
      r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 3,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isFalse);

      // All valid fields -> complete
      draft = draft.copyWith(
        bodyBasics: const BodyBasicsDraft(
          ageRange: '25-34',
          gender: 'male',
          heightCm: 175,
          weightKg: 72,
        ),
      );
      r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 3,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isTrue);
    });

    test('Step 4: Classes & Job Timeline async/review lifecycle', () {
      final studentDraft = const OnboardingDraft(
        lifeRole: LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
      );

      // No timeline generated -> incomplete
      var r = evaluateOnboardingStepReadiness(
        draft: studentDraft,
        step: 4,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isFalse);

      // AI extracting/generating -> asyncIdle is false -> hidden
      r = evaluateOnboardingStepReadiness(
        draft: studentDraft,
        step: 4,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
        asyncIdle: false,
      );
      expect(r.canRevealPrimary, isFalse);

      // Valid class timeline generated and reviewed
      final readyStudentDraft = studentDraft.copyWith(
        baseTimeline: BaseTimelineDraft(
          blocks: [
            TimelineBlockDraft(
              id: 'c1',
              section: 'classes',
              title: 'Math',
              startMinute: 9 * 60,
              endMinute: 10 * 60,
              repeatDays: const [1, 2, 3, 4, 5],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        ),
      );
      r = evaluateOnboardingStepReadiness(
        draft: readyStudentDraft,
        step: 4,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
        asyncIdle: true,
      );
      expect(r.canRevealPrimary, isTrue);

      // Role requiring none (Not student + Not working) is immediately ready
      final noneRoleDraft = const OnboardingDraft(
        lifeRole: LifeRoleDraft(
          lifeRole: LifeRoleDraft.notStudentNotWorkingKey,
        ),
      );
      r = evaluateOnboardingStepReadiness(
        draft: noneRoleDraft,
        step: 4,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isTrue);
    });

    test('Step 5: Eating Setup confirmed routine requirements', () {
      var draft = const OnboardingDraft();
      var r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 5,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isFalse);

      // Path chosen but no confirmed eating blocks -> incomplete
      draft = draft.copyWith(
        baseTimeline: const BaseTimelineDraft(eatingSetupPath: 'create'),
      );
      r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 5,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isFalse);

      // Valid confirmed eating blocks -> complete
      final eatingBase = BaseTimelineDraft(
        eatingSetupPath: 'create',
        blocks: [
          TimelineBlockDraft(
            id: 'm1',
            section: 'eating',
            title: 'Breakfast',
            startMinute: 8 * 60,
            endMinute: 8 * 60 + 30,
            repeatDays: const [1, 2, 3, 4, 5, 6, 7],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
          TimelineBlockDraft(
            id: 'm2',
            section: 'eating',
            title: 'Lunch',
            startMinute: 13 * 60,
            endMinute: 13 * 60 + 30,
            repeatDays: const [1, 2, 3, 4, 5, 6, 7],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ],
      );
      draft = draft.copyWith(baseTimeline: eatingBase);
      r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 5,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isTrue);
    });

    test('Step 6: Fixed Schedule sleep & bath requirements', () {
      final draft = const OnboardingDraft().copyWith(
        baseTimeline: const BaseTimelineDraft().withRequiredFixedBlocks(),
      );
      final r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 6,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isTrue);

      // Invalid sleep (start == end) -> incomplete
      final invalidDraft = draft.copyWith(
        baseTimeline: draft.baseTimeline.copyWith(
          blocks: draft.baseTimeline.blocks.map((b) {
            if (b.id == BaseTimelineDraft.fixedSleepId) {
              return b.copyWith(startMinute: 600, endMinute: 600);
            }
            return b;
          }).toList(),
        ),
      );
      final rInvalid = evaluateOnboardingStepReadiness(
        draft: invalidDraft,
        step: 6,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(rInvalid.canRevealPrimary, isFalse);
    });

    test('Step 7: Skin Care optional skip vs. routine generation', () {
      var draft = const OnboardingDraft();
      var r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 7,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isFalse);

      // Explicit skip -> complete
      draft = draft.copyWith(
        baseTimeline: const BaseTimelineDraft(skinCareSkipped: true),
      );
      r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 7,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isTrue);
      expect(r.definition.skipAllowed, isTrue);

      // Has products mode with confirmed skin_care routine -> complete
      final skinCareBase = BaseTimelineDraft(
        skinCareSetupPath: 'has_products',
        skinCareProductNames: 'Cleanser\nMoisturizer',
        skinCareReviewedProducts: const [
          SkinCareDetectedProduct(name: 'Cleanser', category: 'cleanser'),
          SkinCareDetectedProduct(name: 'Moisturizer', category: 'moisturizer'),
        ],
        skinCareDesiredApplicationsPerDay: 2,
        blocks: [
          TimelineBlockDraft(
            id: 'sk1',
            section: 'skin_care',
            title: 'Morning Routine',
            startMinute: 8 * 60 + 30,
            endMinute: 8 * 60 + 45,
            repeatDays: const [1, 2, 3, 4, 5, 6, 7],
            skincareSteps: const ['Cleanser'],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
          TimelineBlockDraft(
            id: 'sk2',
            section: 'skin_care',
            title: 'Night Routine',
            startMinute: 22 * 60,
            endMinute: 22 * 60 + 15,
            repeatDays: const [1, 2, 3, 4, 5, 6, 7],
            skincareSteps: const ['Moisturizer'],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ],
      );
      final skinCareFingerprint = skinCareBase
          .computeSkinCareRoutineFingerprint();
      draft = draft.copyWith(
        baseTimeline: skinCareBase.copyWith(
          skinCareRoutineFingerprint: skinCareFingerprint,
          blocks: skinCareBase.blocks
              .map(
                (block) => block.copyWith(
                  provenanceSourceIds: [
                    'skin-care-generation:$skinCareFingerprint',
                  ],
                ),
              )
              .toList(growable: false),
        ),
      );
      r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 7,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isTrue);
    });

    test('Step 8 & 9: Bad and Good Habits optional selection or Not now', () {
      // Step 8: Bad habits
      var draft8 = const OnboardingDraft();
      var r8 = evaluateOnboardingStepReadiness(
        draft: draft8,
        step: 8,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r8.canRevealPrimary, isFalse);

      draft8 = draft8.copyWith(badHabitsNotNow: true);
      r8 = evaluateOnboardingStepReadiness(
        draft: draft8,
        step: 8,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r8.canRevealPrimary, isTrue);

      draft8 = const OnboardingDraft(
        badHabits: [
          BadHabitDraft(
            id: 'b1',
            habitKey: 'junk_food',
            displayName: 'Junk Food',
          ),
        ],
      );
      r8 = evaluateOnboardingStepReadiness(
        draft: draft8,
        step: 8,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r8.canRevealPrimary, isTrue);

      // Step 9: Good habits
      var draft9 = const OnboardingDraft();
      var r9 = evaluateOnboardingStepReadiness(
        draft: draft9,
        step: 9,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r9.canRevealPrimary, isFalse);

      draft9 = draft9.copyWith(goodHabitsNotNow: true);
      r9 = evaluateOnboardingStepReadiness(
        draft: draft9,
        step: 9,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r9.canRevealPrimary, isTrue);
    });

    test('Step 10: Identity goals minimum requirement', () {
      var draft = const OnboardingDraft();
      var r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 10,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isFalse);

      draft = draft.copyWith(
        identityGoals: const [
          IdentityGoalDraft(
            goalKey: 'disciplined',
            displayName: 'Become Disciplined',
            systemKeys: ['wake_sleep_consistency'],
          ),
        ],
      );
      r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 10,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isTrue);
    });

    test('Step 11: Coach Setup name and style', () {
      var draft = const OnboardingDraft();
      var r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 11,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isFalse);

      draft = draft.copyWith(
        coachSetup: const CoachSetupDraft(coachName: 'Coach'),
      );
      r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 11,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isFalse);

      draft = draft.copyWith(
        coachSetup: const CoachSetupDraft(
          coachName: 'Coach',
          coachStyle: 'supportive',
        ),
      );
      r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 11,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isTrue);
    });

    test('Step 12: Slip-up handling style', () {
      var draft = const OnboardingDraft();
      var r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 12,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isFalse);

      draft = draft.copyWith(slipUpHandling: 'forgiving');
      r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 12,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isTrue);
    });

    test('Step 13: Notification reminder preferences confirmation', () {
      var draft = const OnboardingDraft();
      var r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 13,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isFalse);

      draft = draft.copyWith(
        notifications: const NotificationSetupDraft(preferencesConfirmed: true),
      );
      r = evaluateOnboardingStepReadiness(
        draft: draft,
        step: 13,
        completedSteps: List.filled(OnboardingDraft.stepCount, false),
      );
      expect(r.canRevealPrimary, isTrue);
    });

    test('Step 14: Dedicated completion pipeline (excluded)', () {
      final def = onboardingStepDefinition(14);
      expect(def.requirement, OnboardingStepRequirement.excluded);
    });
  });

  group('Widget Tests: Progressive CTA Lifecycle & Invariant Regressions', () {
    testWidgets('Step 1: Checkbox toggling reveals and disables CTA stably', (
      tester,
    ) async {
      late MockOnboardingNotifier notifier;
      final draft = OnboardingDraft(
        currentStep: 1,
        stepCompleted: [true, for (int i = 1; i < 15; i++) false],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mockOnboardingProvider.overrideWith((_) {
              notifier = MockOnboardingNotifier()..loadSeedData(draft);
              return notifier;
            }),
            authProvider.overrideWith((ref) => _FakeAuthNotifier()),
            onboardingRepositoryProvider.overrideWithValue(
              FakeOnboardingRepository(),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: OnboardingFlow())),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initially on Step 1: Next CTA is hidden (opacity 0)
      final opacityFinder = find.byType(AnimatedOpacity);
      expect(opacityFinder, findsWidgets);
      final ctaOpacity = tester.widget<AnimatedOpacity>(opacityFinder.last);
      expect(ctaOpacity.opacity, 0.0);

      // Tap Pledge card to accept
      await tester.ensureVisible(find.text('I accept the first test.'));
      await tester.tap(find.text('I accept the first test.'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // CTA reveals (opacity 1.0)
      final revealedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity).last,
      );
      expect(revealedOpacity.opacity, 1.0);
      expect(find.text('Next Step'), findsOneWidget);

      // Uncheck Pledge card
      await tester.ensureVisible(find.text('First test accepted.'));
      await tester.tap(find.text('First test accepted.'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // CTA remains in stable position (opacity 1.0) but is disabled
      final disabledOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity).last,
      );
      expect(disabledOpacity.opacity, 1.0);

      // Re-accept and advance
      await tester.ensureVisible(find.text('I accept the first test.'));
      await tester.tap(find.text('I accept the first test.'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Next Step'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(notifier.state.draft.currentStep, 2);
      expect(notifier.state.draft.stepCompleted[1], isTrue);
    });

    testWidgets('Step 3 -> Step 4 Gate: Step 4 strictly blocked until saved', (
      tester,
    ) async {
      late MockOnboardingNotifier notifier;
      final completed = List.generate(15, (i) => i < 3); // 0, 1, 2 completed
      final draft = OnboardingDraft(
        currentStep: 3,
        stepCompleted: completed,
        bodyBasics: const BodyBasicsDraft(), // Incomplete
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mockOnboardingProvider.overrideWith((_) {
              notifier = MockOnboardingNotifier()..loadSeedData(draft);
              return notifier;
            }),
            authProvider.overrideWith((ref) => _FakeAuthNotifier()),
            onboardingRepositoryProvider.overrideWithValue(
              FakeOnboardingRepository(),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: OnboardingFlow())),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Cannot access Step 4 via indicator / dots
      expect(
        canAccessOnboardingStep(targetStep: 4, completedSteps: completed),
        isFalse,
      );
      expect(maxAccessibleOnboardingStep(completed), 3);
    });
  });
}
