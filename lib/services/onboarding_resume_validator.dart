import 'package:optivus/features/onboarding/onboarding_step_id.dart';
import 'package:optivus/models/onboarding_draft.dart';

enum OnboardingResumeValidationReason {
  durableCompletionNotRecorded,
  durableContractMigrationRequired,
  durableStepInvalid,
  readyForFinalReview,
}

enum DurableCompletionContractMigrationStatus {
  supported,
  migrationRequired,
  unsupportedNewerVersion,
}

class DurableCompletionContractMigrationValidation {
  final DurableCompletionContractMigrationStatus status;
  final int storedVersion;
  final int currentVersion;

  const DurableCompletionContractMigrationValidation({
    required this.status,
    required this.storedVersion,
    required this.currentVersion,
  });
}

/// Separately owns persisted completion receipt compatibility. This must not
/// be replaced with interactive screen validation.
DurableCompletionContractMigrationValidation
validateDurableCompletionContractMigration(
  OnboardingStepId stepId,
  OnboardingDraft draft,
) {
  final stored = stepId.index < draft.stepCompletionContractVersions.length
      ? draft.stepCompletionContractVersions[stepId.index]
      : 0;
  final current = stepId.durableCompletionContractVersion;
  final status = stored == current
      ? DurableCompletionContractMigrationStatus.supported
      : stored > current
      ? DurableCompletionContractMigrationStatus.unsupportedNewerVersion
      : DurableCompletionContractMigrationStatus.migrationRequired;
  return DurableCompletionContractMigrationValidation(
    status: status,
    storedVersion: stored,
    currentVersion: current,
  );
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

int durableAcknowledgedCompletionBoundary(OnboardingDraft draft) {
  var boundary = -1;
  for (var step = 0; step < OnboardingDraft.stepCount; step++) {
    if (step >= draft.stepCompleted.length || !draft.stepCompleted[step]) break;
    boundary = step;
  }
  return boundary;
}

Map<String, Object?> onboardingRestoreDiagnostics({
  required OnboardingDraft draft,
  required OnboardingResumeValidation validation,
  String uploadReconciliation = 'not_run',
  List<String> uploadReasonCodes = const [],
}) {
  return <String, Object?>{
    'schemaVersion': draft.storedSchemaVersion,
    'detectedTopology': draft.restoredStepLayout.name,
    'migrationAction': draft.storedSchemaVersion < OnboardingDraft.schemaVersion
        ? 'completion_contracts_v1_migrated'
        : 'none',
    'originalAcknowledgedCompletionBoundary':
        durableAcknowledgedCompletionBoundary(draft),
    'durableValidatorResult': validation.diagnosticCode,
    'uploadReconciliation': uploadReconciliation,
    if (uploadReasonCodes.isNotEmpty)
      'uploadReasonCodes': List<String>.unmodifiable(uploadReasonCodes),
    if (validation.reason !=
        OnboardingResumeValidationReason.readyForFinalReview)
      'affectedStep': validation.resumeStep,
    'finalResumeStep': validation.resumeStep,
    'reasonCode': validation.diagnosticCode,
    // Stable compatibility keys consumed by existing recovery UI/tests.
    'resumeStep': validation.resumeStep,
    'validThroughStep': validation.validThroughStep,
    'reason': validation.reason.name,
    'diagnosticCode': validation.diagnosticCode,
  };
}

/// Evaluates whether a durably saved onboarding step satisfies durable restore
/// invariants without depending on ephemeral target calculations or target drift.
/// Returns null if the step is valid to restore, or an auditable diagnostic code.
String? validateDurableStepRestore(int step, OnboardingDraft draft) {
  final stepId = OnboardingStepId.fromIndex(step);
  if (stepId == null) return 'step_${step}_unknown';

  final contract = validateDurableCompletionContractMigration(stepId, draft);
  switch (contract.status) {
    case DurableCompletionContractMigrationStatus.supported:
      break;
    case DurableCompletionContractMigrationStatus.migrationRequired:
      return 'step_${step}_completion_contract_migration_required';
    case DurableCompletionContractMigrationStatus.unsupportedNewerVersion:
      return 'step_${step}_completion_contract_unsupported';
  }

  switch (stepId) {
    case OnboardingStepId.welcome:
      return null;
    case OnboardingStepId.patience:
      return draft.patiencePledgeAccepted
          ? null
          : 'step_1_patience_pledge_missing';
    case OnboardingStepId.roleLifestyle:
      return _validateDurableRoleLifestyleV1(draft.lifeRole)
          ? null
          : 'step_2_role_lifestyle_invalid';
    case OnboardingStepId.bodyBasics:
      return _validateDurableBodyBasicsV1(draft.bodyBasics)
          ? null
          : 'step_3_body_basics_invalid';
    case OnboardingStepId.classesJob:
      return draft.baseTimeline.validateDurableClassesAndWorkRestoreV1(
        draft.lifeRole.lifeRole,
      );
    case OnboardingStepId.eating:
      return draft.baseTimeline.validateDurableEatingRestore();
    case OnboardingStepId.fixedSchedule:
      return draft.baseTimeline.validateDurableFixedScheduleRestoreV1();
    case OnboardingStepId.skinCare:
      return draft.baseTimeline.validateDurableSkinCareRestoreV1(draft.uid);
    case OnboardingStepId.badHabits:
      return _validateDurableBadHabitsV1(draft)
          ? null
          : 'step_8_bad_habits_invalid';
    case OnboardingStepId.goodHabits:
      return _validateDurableGoodHabitsV1(draft)
          ? null
          : 'step_9_good_habits_invalid';
    case OnboardingStepId.identityGoals:
      return draft.identityGoals.isNotEmpty &&
              draft.identityGoals.every(
                (goal) =>
                    goal.goalKey.trim().isNotEmpty &&
                    goal.displayName.trim().isNotEmpty,
              )
          ? null
          : 'step_10_identity_goals_invalid';
    case OnboardingStepId.coachSetup:
      return draft.coachSetup.coachName?.trim().isNotEmpty == true &&
              draft.coachSetup.coachStyle?.trim().isNotEmpty == true
          ? null
          : 'step_11_coach_setup_invalid';
    case OnboardingStepId.slipUp:
      return draft.slipUpHandling?.trim().isNotEmpty == true
          ? null
          : 'step_12_slip_up_invalid';
    case OnboardingStepId.notifications:
      return draft.notifications.preferencesConfirmed &&
              const {
                'low',
                'medium',
                'high',
              }.contains(draft.notifications.reminderIntensity)
          ? null
          : 'step_13_notifications_invalid';
    case OnboardingStepId.todayReady:
      return null;
  }
}

bool _validateDurableRoleLifestyleV1(LifeRoleDraft role) {
  final lifeRole = role.lifeRole;
  if (!const {
    LifeRoleDraft.studentKey,
    LifeRoleDraft.workingKey,
    LifeRoleDraft.studentWorkingKey,
    LifeRoleDraft.businessKey,
    LifeRoleDraft.notStudentNotWorkingKey,
  }.contains(lifeRole)) {
    return false;
  }
  if (role.needsWorkType && role.workType?.trim().isNotEmpty != true) {
    return false;
  }
  if (role.needsBusinessMode && role.businessMode?.trim().isNotEmpty != true) {
    return false;
  }
  return role.exerciseLevel?.trim().isNotEmpty == true &&
      role.waterIntake?.trim().isNotEmpty == true &&
      role.stressLevel?.trim().isNotEmpty == true &&
      role.sleepQuality?.trim().isNotEmpty == true;
}

bool _validateDurableBodyBasicsV1(BodyBasicsDraft body) {
  final height = body.heightCm;
  final weight = body.weightKg;
  return body.ageRange?.trim().isNotEmpty == true &&
      height != null &&
      height.isFinite &&
      height >= 120 &&
      height <= 220 &&
      weight != null &&
      weight.isFinite &&
      weight >= 40 &&
      weight <= 150 &&
      body.gender?.trim().isNotEmpty == true;
}

bool _validateDurableBadHabitsV1(OnboardingDraft draft) {
  if (draft.badHabitsNotNow) return true;
  return draft.badHabits.isNotEmpty &&
      draft.badHabits.every(
        (habit) =>
            habit.id.trim().isNotEmpty &&
            habit.habitKey.trim().isNotEmpty &&
            habit.displayName.trim().isNotEmpty &&
            habit.dailySpend >= 0 &&
            habit.lostTimeMinutes >= 0,
      );
}

bool _validateDurableGoodHabitsV1(OnboardingDraft draft) {
  if (draft.goodHabitsNotNow) return true;
  return draft.goodHabits.isNotEmpty &&
      draft.goodHabits.every(
        (habit) =>
            habit.id.trim().isNotEmpty &&
            habit.habitKey.trim().isNotEmpty &&
            habit.displayName.trim().isNotEmpty &&
            habit.durationMinutes > 0 &&
            habit.repeatDays.isNotEmpty &&
            habit.repeatDays.every((day) => day >= 1 && day <= 7),
      );
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
      final requiresMigration = restoreErr.endsWith(
        '_completion_contract_migration_required',
      );
      return OnboardingResumeValidation(
        resumeStep: step,
        validThroughStep: step - 1,
        reason: requiresMigration
            ? OnboardingResumeValidationReason.durableContractMigrationRequired
            : OnboardingResumeValidationReason.durableStepInvalid,
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
