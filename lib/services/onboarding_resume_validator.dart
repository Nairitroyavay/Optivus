import 'package:optivus/features/onboarding/onboarding_step_id.dart';
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

/// Evaluates whether a durably saved onboarding step satisfies durable restore
/// invariants without depending on ephemeral target calculations or target drift.
/// Returns null if the step is valid to restore, or an auditable diagnostic code.
String? validateDurableStepRestore(int step, OnboardingDraft draft) {
  final stepId = OnboardingStepId.fromIndex(step);
  if (stepId == null) return 'step_${step}_unknown';

  switch (stepId) {
    case OnboardingStepId.welcome:
      return null;
    case OnboardingStepId.patience:
      return draft.patiencePledgeAccepted
          ? null
          : 'step_1_patience_pledge_missing';
    case OnboardingStepId.roleLifestyle:
      return draft.lifeRole.validate() == null
          ? null
          : 'step_2_role_lifestyle_invalid';
    case OnboardingStepId.bodyBasics:
      return draft.bodyBasics.validate() == null
          ? null
          : 'step_3_body_basics_invalid';
    case OnboardingStepId.classesJob:
      return draft.baseTimeline.validateClassesAndWorkForRole(
                draft.lifeRole.lifeRole,
              ) ==
              null
          ? null
          : 'step_4_classes_work_invalid';
    case OnboardingStepId.eating:
      return draft.baseTimeline.validateDurableEatingRestore();
    case OnboardingStepId.fixedSchedule:
      return draft.baseTimeline.validateFixedSchedule() == null
          ? null
          : 'step_6_fixed_schedule_invalid';
    case OnboardingStepId.skinCare:
      return draft.baseTimeline.validateSkinCareSetup(draft.uid) == null
          ? null
          : 'step_7_skin_care_invalid';
    case OnboardingStepId.badHabits:
      return (draft.badHabitsNotNow || draft.badHabits.isNotEmpty)
          ? null
          : 'step_8_bad_habits_invalid';
    case OnboardingStepId.goodHabits:
      return (draft.goodHabitsNotNow || draft.goodHabits.isNotEmpty)
          ? null
          : 'step_9_good_habits_invalid';
    case OnboardingStepId.identityGoals:
      return draft.identityGoals.isNotEmpty
          ? null
          : 'step_10_identity_goals_invalid';
    case OnboardingStepId.coachSetup:
      return draft.coachSetup.validate() == null
          ? null
          : 'step_11_coach_setup_invalid';
    case OnboardingStepId.slipUp:
      return draft.slipUpHandling != null ? null : 'step_12_slip_up_invalid';
    case OnboardingStepId.notifications:
      return draft.notifications.validate() == null
          ? null
          : 'step_13_notifications_invalid';
    case OnboardingStepId.todayReady:
      return null;
  }
}

/// The single canonical resume-step determination contract.
///
/// This function is pure: it reads only the already-decoded durable draft and
/// performs no I/O, writes, provider access, clock reads, or route changes.
/// A step must both have a durable save acknowledgement and satisfy the durable
/// restore invariants for that step. Steps are checked from the beginning, so
/// later data and `currentStep` cannot waive a hole.
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

    final restoreErr = validateDurableStepRestore(step, draft);
    if (restoreErr != null) {
      return OnboardingResumeValidation(
        resumeStep: step,
        validThroughStep: step - 1,
        reason: OnboardingResumeValidationReason.durableStepInvalid,
        diagnosticCode: restoreErr,
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
