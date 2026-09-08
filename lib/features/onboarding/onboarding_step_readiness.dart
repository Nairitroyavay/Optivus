import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/features/onboarding/onboarding_step_id.dart';

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

  /// Step 5 requires the review stage (stage 2) to be active with confirmed
  /// meal routine blocks before Next Step is revealed. Null means the draft
  /// validation remains authoritative.
  final bool? eatingReviewReady;

  const OnboardingStepRuntimeState({
    this.asyncIdle = true,
    this.saveIdle = true,
    this.classJobReviewReady,
    this.eatingReviewReady,
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
  final stepId = OnboardingStepId.fromIndex(step);
  return switch (stepId) {
    OnboardingStepId.patience => OnboardingStepDefinition(
      step: OnboardingStepId.patience.index,
      requirement: OnboardingStepRequirement.required,
      requiredCondition: 'Patience Pledge explicitly accepted',
    ),
    OnboardingStepId.roleLifestyle => OnboardingStepDefinition(
      step: OnboardingStepId.roleLifestyle.index,
      requirement: OnboardingStepRequirement.conditionalRequired,
      requiredCondition:
          'Role and lifestyle choices; work type or business mode when the selected role requires it',
    ),
    OnboardingStepId.bodyBasics => OnboardingStepDefinition(
      step: OnboardingStepId.bodyBasics.index,
      requirement: OnboardingStepRequirement.required,
      requiredCondition: 'Valid age range, height, weight, and gender',
    ),
    OnboardingStepId.classesJob => OnboardingStepDefinition(
      step: OnboardingStepId.classesJob.index,
      requirement: OnboardingStepRequirement.conditionalRequired,
      requiredCondition:
          'Class schedule for Student, work schedule for Working/Business, both for Student + Working, none for Not Student + Not Working',
    ),
    OnboardingStepId.eating => OnboardingStepDefinition(
      step: OnboardingStepId.eating.index,
      requirement: OnboardingStepRequirement.required,
      requiredCondition: 'Structurally valid, confirmed weekly meal routine',
    ),
    OnboardingStepId.fixedSchedule => OnboardingStepDefinition(
      step: OnboardingStepId.fixedSchedule.index,
      requirement: OnboardingStepRequirement.required,
      requiredCondition:
          'Valid sleep and bath blocks plus explicit fixed-schedule confirmation',
    ),
    OnboardingStepId.skinCare => OnboardingStepDefinition(
      step: OnboardingStepId.skinCare.index,
      requirement: OnboardingStepRequirement.optional,
      requiredCondition: 'Valid reviewed skin-care routine, or explicit Skip',
      skipAllowed: true,
    ),
    OnboardingStepId.badHabits => OnboardingStepDefinition(
      step: OnboardingStepId.badHabits.index,
      requirement: OnboardingStepRequirement.optional,
      requiredCondition: 'At least one bad habit, or explicit Not now',
      skipAllowed: true,
    ),
    OnboardingStepId.goodHabits => OnboardingStepDefinition(
      step: OnboardingStepId.goodHabits.index,
      requirement: OnboardingStepRequirement.optional,
      requiredCondition: 'At least one good habit, or explicit Not now',
      skipAllowed: true,
    ),
    OnboardingStepId.identityGoals => OnboardingStepDefinition(
      step: OnboardingStepId.identityGoals.index,
      requirement: OnboardingStepRequirement.required,
      requiredCondition: 'At least one identity goal',
    ),
    OnboardingStepId.coachSetup => OnboardingStepDefinition(
      step: OnboardingStepId.coachSetup.index,
      requirement: OnboardingStepRequirement.required,
      requiredCondition: 'Explicit coach name and coaching style',
    ),
    OnboardingStepId.slipUp => OnboardingStepDefinition(
      step: OnboardingStepId.slipUp.index,
      requirement: OnboardingStepRequirement.required,
      requiredCondition: 'Explicit slip-up recovery style',
    ),
    OnboardingStepId.notifications => OnboardingStepDefinition(
      step: OnboardingStepId.notifications.index,
      requirement: OnboardingStepRequirement.required,
      requiredCondition:
          'App reminder preferences explicitly confirmed; Android permission is not required',
    ),
    OnboardingStepId.todayReady => OnboardingStepDefinition(
      step: OnboardingStepId.todayReady.index,
      requirement: OnboardingStepRequirement.excluded,
      requiredCondition: 'Dedicated final review and completion pipeline',
    ),
    OnboardingStepId.welcome || null => OnboardingStepDefinition(
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
  final stepId = OnboardingStepId.fromIndex(step);
  if (stepId == OnboardingStepId.welcome ||
      stepId == OnboardingStepId.todayReady) {
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

  if (stepId == OnboardingStepId.classesJob &&
      effectiveRuntime.classJobReviewReady != null) {
    validationPassed = effectiveRuntime.classJobReviewReady!;
    if (!validationPassed) {
      validationMessage =
          draftValidationMessage ??
          'Generate and review every schedule required for your role.';
    }
  }

  if (stepId == OnboardingStepId.eating &&
      effectiveRuntime.eatingReviewReady != null) {
    validationPassed = effectiveRuntime.eatingReviewReady!;
    if (!validationPassed) {
      validationMessage =
          draftValidationMessage ??
          'Generate and review your weekly meal routine.';
    }
  }

  final reviewCompleted = switch (stepId) {
    OnboardingStepId.classesJob ||
    OnboardingStepId.eating ||
    OnboardingStepId.skinCare => validationPassed,
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
  final stepId = OnboardingStepId.fromIndex(step);
  if (stepId == null ||
      stepId == OnboardingStepId.welcome ||
      stepId == OnboardingStepId.todayReady) {
    return true;
  }
  if (stepId == OnboardingStepId.classesJob ||
      stepId == OnboardingStepId.eating) {
    return readiness.canRevealPrimary;
  }
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
