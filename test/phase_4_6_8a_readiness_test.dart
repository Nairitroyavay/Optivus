import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/utils/auth_form_readiness.dart';
import 'package:optivus/features/onboarding/onboarding_step_readiness.dart';
import 'package:optivus/models/onboarding_draft.dart';

void main() {
  group('auth progressive CTA readiness', () {
    test('login is hidden for empty, email-only, and password-only state', () {
      expect(isLoginFormReady(email: '', password: ''), isFalse);
      expect(
        isLoginFormReady(email: 'person@example.com', password: ''),
        isFalse,
      );
      expect(isLoginFormReady(email: '', password: 'legacy'), isFalse);
    });

    test('login accepts a basic email and any non-empty legacy password', () {
      expect(
        isLoginFormReady(email: 'person@example.com', password: 'x'),
        isTrue,
      );
      expect(isLoginFormReady(email: 'not-an-email', password: 'x'), isFalse);
    });

    test('signup remains hidden until every required value is valid', () {
      expect(
        isSignupFormReady(
          name: '',
          email: 'person@example.com',
          password: 'Strong1!',
          confirmation: 'Strong1!',
        ),
        isFalse,
      );
      expect(
        isSignupFormReady(
          name: 'Test User',
          email: 'person@example.com',
          password: 'Strong1!',
          confirmation: 'different',
        ),
        isFalse,
      );
      expect(
        isSignupFormReady(
          name: 'Test User',
          email: 'person@example.com',
          password: 'Strong1!',
          confirmation: 'Strong1!',
        ),
        isTrue,
      );
    });
  });

  group('durable onboarding step gate', () {
    test('Step 1 Next is hidden until the pledge is accepted', () {
      final incomplete = evaluateOnboardingStepReadiness(
        draft: const OnboardingDraft(),
        step: 1,
        completedSteps: List<bool>.filled(OnboardingDraft.stepCount, false),
        asyncIdle: true,
        saveIdle: true,
      );
      final accepted = evaluateOnboardingStepReadiness(
        draft: const OnboardingDraft(patiencePledgeAccepted: true),
        step: 1,
        completedSteps: List<bool>.filled(OnboardingDraft.stepCount, false),
        asyncIdle: true,
        saveIdle: true,
      );

      expect(incomplete.canRevealPrimary, isFalse);
      expect(accepted.canRevealPrimary, isTrue);
    });

    test('Step 2 primary CTA is unavailable before required choices', () {
      final readiness = evaluateOnboardingStepReadiness(
        draft: const OnboardingDraft(),
        step: 2,
        completedSteps: List<bool>.filled(OnboardingDraft.stepCount, false),
        asyncIdle: true,
        saveIdle: true,
      );

      expect(readiness.canRevealPrimary, isFalse);
      expect(readiness.canSubmit, isFalse);
    });

    test('Step 4 is inaccessible while Step 3 is incomplete', () {
      final completed = List<bool>.filled(OnboardingDraft.stepCount, false)
        ..[0] = true
        ..[1] = true
        ..[2] = true;

      expect(maxAccessibleOnboardingStep(completed), 3);
      expect(
        canAccessOnboardingStep(targetStep: 4, completedSteps: completed),
        isFalse,
      );
    });

    test('viewed/current/cached future state cannot widen the gate', () {
      final completed = List<bool>.filled(OnboardingDraft.stepCount, false)
        ..[0] = true
        ..[1] = true
        ..[2] = true;

      for (final bypassTarget in [4, 5, 8, OnboardingDraft.lastStepIndex]) {
        expect(
          canAccessOnboardingStep(
            targetStep: bypassTarget,
            completedSteps: completed,
          ),
          isFalse,
        );
      }
    });

    test('verified completion unlocks only the immediate next step', () {
      final completed = List<bool>.filled(OnboardingDraft.stepCount, false)
        ..[0] = true
        ..[1] = true
        ..[2] = true
        ..[3] = true;

      expect(
        canAccessOnboardingStep(targetStep: 4, completedSteps: completed),
        isTrue,
      );
      expect(
        canAccessOnboardingStep(targetStep: 5, completedSteps: completed),
        isFalse,
      );
    });

    test('out-of-range progress-indicator targets are rejected', () {
      final completed = List<bool>.filled(OnboardingDraft.stepCount, true);
      expect(
        canAccessOnboardingStep(targetStep: -1, completedSteps: completed),
        isFalse,
      );
      expect(
        canAccessOnboardingStep(
          targetStep: OnboardingDraft.stepCount,
          completedSteps: completed,
        ),
        isFalse,
      );
    });
  });
}
