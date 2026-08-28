import 'package:optivus/models/onboarding_draft.dart';

enum OnboardingStepRequirement {
  required,
  optional,
  conditionalRequired,
  excluded,
}

class OnboardingStepDefinition {
  final int step;
  final OnboardingStepRequirement requirement;
  final String requiredCondition;
  final bool skipAllowed;

  const OnboardingStepDefinition({
    required this.step,
    required this.requirement,
    required this.requiredCondition,
    this.skipAllowed = false,
  });
}

/// Transient state which deliberately does not become durable onboarding
/// completion. It only answers whether the current UI is ready to be saved.
class OnboardingStepRuntimeState {
  final bool asyncIdle;
  final bool saveIdle;

  /// Step 4 builds its reviewed class/work schedule in local providers before
  /// it is copied into the draft on an explicit Next tap. Null means the draft
  /// remains authoritative (for example, on a clean durable resume).
  final bool? classJobReviewReady;

  const OnboardingStepRuntimeState({
    this.asyncIdle = true,
    this.saveIdle = true,
    this.classJobReviewReady,
  });
}

class OnboardingStepReadiness {
  final OnboardingStepDefinition definition;
  final bool requiredInputsSatisfied;
  final bool validationPassed;
  final bool reviewCompleted;
  final bool asyncIdle;
  final bool saveIdle;
  final bool verifiedComplete;
  final String? validationMessage;

  const OnboardingStepReadiness({
    required this.definition,
    required this.requiredInputsSatisfied,
    required this.validationPassed,
    required this.reviewCompleted,
    required this.asyncIdle,
    required this.saveIdle,
    required this.verifiedComplete,
    required this.validationMessage,
  });

  /// Input ready + save ready. This never means that the next step is already
  /// unlocked; only [verifiedComplete] represents durable completion.
  bool get canRevealPrimary =>
      requiredInputsSatisfied &&
      validationPassed &&
      reviewCompleted &&
      asyncIdle;

  bool get canSubmit => canRevealPrimary && saveIdle;
}

OnboardingStepDefinition onboardingStepDefinition(int step) {
  return switch (step) {
    1 => const OnboardingStepDefinition(
      step: 1,
      requirement: OnboardingStepRequirement.required,
      requiredCondition: 'Patience Pledge explicitly accepted',
    ),
    2 => const OnboardingStepDefinition(
      step: 2,
      requirement: OnboardingStepRequirement.conditionalRequired,
      requiredCondition:
          'Role and lifestyle choices; work type or business mode when the selected role requires it',
    ),
    3 => const OnboardingStepDefinition(
      step: 3,
      requirement: OnboardingStepRequirement.required,
      requiredCondition: 'Valid age range, height, weight, and gender',
    ),
    4 => const OnboardingStepDefinition(
      step: 4,
      requirement: OnboardingStepRequirement.conditionalRequired,
      requiredCondition:
          'Class schedule for Student, work schedule for Working/Business, both for Student + Working, none for Not Student + Not Working',
    ),
    5 => const OnboardingStepDefinition(
      step: 5,
      requirement: OnboardingStepRequirement.required,
      requiredCondition: 'Structurally valid, confirmed weekly meal routine',
    ),
    6 => const OnboardingStepDefinition(
      step: 6,
      requirement: OnboardingStepRequirement.required,
      requiredCondition:
          'Valid sleep and bath blocks plus explicit fixed-schedule confirmation',
    ),
    7 => const OnboardingStepDefinition(
      step: 7,
      requirement: OnboardingStepRequirement.optional,
      requiredCondition: 'Valid reviewed skin-care routine, or explicit Skip',
      skipAllowed: true,
    ),
    8 => const OnboardingStepDefinition(
      step: 8,
      requirement: OnboardingStepRequirement.optional,
      requiredCondition: 'At least one bad habit, or explicit Not now',
      skipAllowed: true,
    ),
    9 => const OnboardingStepDefinition(
      step: 9,
      requirement: OnboardingStepRequirement.optional,
      requiredCondition: 'At least one good habit, or explicit Not now',
      skipAllowed: true,
    ),
    10 => const OnboardingStepDefinition(
      step: 10,
      requirement: OnboardingStepRequirement.required,
      requiredCondition: 'At least one identity goal',
    ),
    11 => const OnboardingStepDefinition(
      step: 11,
      requirement: OnboardingStepRequirement.required,
      requiredCondition: 'Explicit coach name and coaching style',
    ),
    12 => const OnboardingStepDefinition(
      step: 12,
      requirement: OnboardingStepRequirement.required,
      requiredCondition: 'Explicit slip-up recovery style',
    ),
    13 => const OnboardingStepDefinition(
      step: 13,
      requirement: OnboardingStepRequirement.required,
      requiredCondition:
          'App reminder preferences explicitly confirmed; Android permission is not required',
    ),
    14 => const OnboardingStepDefinition(
      step: 14,
      requirement: OnboardingStepRequirement.excluded,
      requiredCondition: 'Dedicated final review and completion pipeline',
    ),
    _ => OnboardingStepDefinition(
      step: step,
      requirement: OnboardingStepRequirement.excluded,
      requiredCondition: 'Outside the progressive Steps 1-13 contract',
    ),
  };
}

OnboardingStepReadiness evaluateOnboardingStepReadiness({
  required OnboardingDraft draft,
  required int step,
  required List<bool> completedSteps,
  List<bool> dirtySteps = const [],
  bool asyncIdle = true,
  bool saveIdle = true,
  bool? externalReviewCompleted,
  OnboardingStepRuntimeState? runtime,
}) {
  final definition = onboardingStepDefinition(step);
  final effectiveRuntime =
      runtime ??
      OnboardingStepRuntimeState(
        asyncIdle: asyncIdle,
        saveIdle: saveIdle,
        classJobReviewReady: externalReviewCompleted,
      );
  final completed =
      step >= 0 && step < completedSteps.length && completedSteps[step];
  final dirty = step >= 0 && step < dirtySteps.length && dirtySteps[step];
  final verifiedComplete = completed && !dirty;

  // Welcome and final review retain their existing dedicated CTA semantics.
  if (step == 0 || step == OnboardingDraft.lastStepIndex) {
    return OnboardingStepReadiness(
      definition: definition,
      requiredInputsSatisfied: true,
      validationPassed: true,
      reviewCompleted: true,
      asyncIdle: true,
      saveIdle: effectiveRuntime.saveIdle,
      verifiedComplete: verifiedComplete,
      validationMessage: null,
    );
  }

  final draftValidationMessage = draft.validateStep(step, completedSteps);
  var validationPassed = draftValidationMessage == null;
  String? validationMessage = draftValidationMessage;

  if (step == 4 && effectiveRuntime.classJobReviewReady != null) {
    validationPassed = effectiveRuntime.classJobReviewReady!;
    if (!validationPassed) {
      validationMessage =
          draftValidationMessage ??
          'Generate and review every schedule required for your role.';
    }
  }

  final reviewCompleted = switch (step) {
    4 || 5 || 7 => validationPassed,
    _ => true,
  };

  return OnboardingStepReadiness(
    definition: definition,
    requiredInputsSatisfied: validationPassed,
    validationPassed: validationPassed,
    reviewCompleted: reviewCompleted,
    asyncIdle: effectiveRuntime.asyncIdle,
    saveIdle: effectiveRuntime.saveIdle,
    verifiedComplete: verifiedComplete,
    validationMessage: validationMessage,
  );
}

bool shouldShowOnboardingPrimaryCta({
  required int step,
  required OnboardingStepReadiness readiness,
  required bool revealedDuringInteraction,
}) {
  if (step < 1 || step > 13) return true;
  return readiness.canRevealPrimary || revealedDuringInteraction;
}

int firstIncompleteOnboardingStep(List<bool> completedSteps) {
  for (var step = 0; step < OnboardingDraft.stepCount; step++) {
    if (step >= completedSteps.length || !completedSteps[step]) {
      return step;
    }
  }
  return OnboardingDraft.lastStepIndex;
}

int maxAccessibleOnboardingStep(List<bool> completedSteps) {
  return firstIncompleteOnboardingStep(
    completedSteps,
  ).clamp(0, OnboardingDraft.lastStepIndex);
}

bool canAccessOnboardingStep({
  required int targetStep,
  required List<bool> completedSteps,
}) {
  if (targetStep < 0 || targetStep > OnboardingDraft.lastStepIndex) {
    return false;
  }
  return targetStep <= maxAccessibleOnboardingStep(completedSteps);
}
