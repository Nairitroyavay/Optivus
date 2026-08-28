import 'package:optivus/models/onboarding_draft.dart';

enum OnboardingStepKind {
  introduction,
  requiredForm,
  interactiveWorkflow,
  optional,
  aiReview,
  finalReview,
}

class OnboardingStepReadiness {
  final OnboardingStepKind kind;
  final bool requiredInputsSatisfied;
  final bool validationPassed;
  final bool reviewCompleted;
  final bool asyncIdle;
  final bool saveIdle;

  const OnboardingStepReadiness({
    required this.kind,
    required this.requiredInputsSatisfied,
    required this.validationPassed,
    required this.reviewCompleted,
    required this.asyncIdle,
    required this.saveIdle,
  });

  bool get canRevealPrimary =>
      requiredInputsSatisfied &&
      validationPassed &&
      reviewCompleted &&
      asyncIdle;

  bool get canSubmit => canRevealPrimary && saveIdle;
}

OnboardingStepKind onboardingStepKind(int step) {
  return switch (step) {
    0 => OnboardingStepKind.introduction,
    4 || 5 || 6 => OnboardingStepKind.interactiveWorkflow,
    7 => OnboardingStepKind.aiReview,
    8 || 9 => OnboardingStepKind.optional,
    OnboardingDraft.lastStepIndex => OnboardingStepKind.finalReview,
    _ => OnboardingStepKind.requiredForm,
  };
}

OnboardingStepReadiness evaluateOnboardingStepReadiness({
  required OnboardingDraft draft,
  required int step,
  required List<bool> completedSteps,
  required bool asyncIdle,
  required bool saveIdle,
  bool? externalReviewCompleted,
}) {
  final kind = onboardingStepKind(step);
  final validationPassed = draft.validateStep(step, completedSteps) == null;
  final isIntroduction = kind == OnboardingStepKind.introduction;
  final isInteractiveWorkflow = kind == OnboardingStepKind.interactiveWorkflow;
  final reviewCompleted = kind == OnboardingStepKind.aiReview
      ? (externalReviewCompleted ?? validationPassed)
      : true;

  return OnboardingStepReadiness(
    kind: kind,
    requiredInputsSatisfied:
        isIntroduction || isInteractiveWorkflow || validationPassed,
    validationPassed:
        isIntroduction || isInteractiveWorkflow || validationPassed,
    reviewCompleted: isIntroduction || reviewCompleted,
    asyncIdle: asyncIdle,
    saveIdle: saveIdle,
  );
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
