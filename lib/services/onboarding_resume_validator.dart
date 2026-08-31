import 'package:optivus/models/onboarding_draft.dart';

enum OnboardingResumeValidationReason {
  durableCompletionNotRecorded,
  durableStepInvalid,
  readyForFinalReview,
}

/// Auditable result of validating a durable onboarding snapshot in canonical
/// order. The persisted numeric `currentStep` deliberately is not an input.
class OnboardingResumeValidation {
  final int resumeStep;
  final int validThroughStep;
  final OnboardingResumeValidationReason reason;
  final String diagnosticCode;

  const OnboardingResumeValidation({
    required this.resumeStep,
    required this.validThroughStep,
    required this.reason,
    required this.diagnosticCode,
  });

  bool get readyForFinalReview =>
      reason == OnboardingResumeValidationReason.readyForFinalReview;
}

/// The single canonical resume-step determination contract.
///
/// This function is pure: it reads only the already-decoded durable draft and
/// performs no I/O, writes, provider access, clock reads, or route changes.
/// A step must both have a durable save acknowledgement and satisfy the same
/// domain validator used by the interactive onboarding flow. Steps are checked
/// from the beginning, so later data and `currentStep` cannot waive a hole.
OnboardingResumeValidation validateOnboardingResume(OnboardingDraft draft) {
  for (var step = 0; step < OnboardingDraft.lastStepIndex; step++) {
    final durablyCompleted =
        step < draft.stepCompleted.length && draft.stepCompleted[step];
    if (!durablyCompleted) {
      return OnboardingResumeValidation(
        resumeStep: step,
        validThroughStep: step - 1,
        reason: OnboardingResumeValidationReason.durableCompletionNotRecorded,
        diagnosticCode: 'step_${step}_save_not_acknowledged',
      );
    }

    if (draft.validateStep(step, draft.stepCompleted) != null) {
      return OnboardingResumeValidation(
        resumeStep: step,
        validThroughStep: step - 1,
        reason: OnboardingResumeValidationReason.durableStepInvalid,
        diagnosticCode: 'step_${step}_durable_state_invalid',
      );
    }
  }

  return const OnboardingResumeValidation(
    resumeStep: OnboardingDraft.lastStepIndex,
    validThroughStep: OnboardingDraft.lastStepIndex - 1,
    reason: OnboardingResumeValidationReason.readyForFinalReview,
    diagnosticCode: 'ready_for_final_review',
  );
}

/// Compatibility name retained for callers outside the reconstruction path.
/// All resume logic delegates to [validateOnboardingResume].
int durableOnboardingResumeStep(OnboardingDraft draft) =>
    validateOnboardingResume(draft).resumeStep;
