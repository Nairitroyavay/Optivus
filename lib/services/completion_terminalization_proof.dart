import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/user_profile.dart';

class CompletionTerminalizationState {
  final bool hasPointer;
  final String? runId;
  final String? ownerUid;
  final int? pointerSchemaVersion;
  final String? pointerStatus;
  final String? sourceFingerprint;
  final int? draftRevision;
  final OnboardingCompletionJob? job;

  const CompletionTerminalizationState({
    required this.hasPointer,
    this.runId,
    this.ownerUid,
    this.pointerSchemaVersion,
    this.pointerStatus,
    this.sourceFingerprint,
    this.draftRevision,
    this.job,
  });
}

enum CompletionTerminalizationDisposition {
  eligible,
  alreadyTerminal,
  notEligible,
  recoveryRequired,
}

enum CompletionTerminalizationReason {
  none,
  ownerMismatch,
  runMismatch,
  currentRunMismatch,
  unsupportedSchema,
  incompatibleTerminalState,
  invalidFinalDraft,
  invalidCompletionBundle,
  incompleteVerification,
  invalidOutputAccounting,
  invalidProfileFinalization,
}

class CompletionTerminalizationProof {
  final CompletionTerminalizationDisposition disposition;
  final CompletionTerminalizationReason reason;

  const CompletionTerminalizationProof._(this.disposition, this.reason);

  const CompletionTerminalizationProof.eligible()
    : this._(
        CompletionTerminalizationDisposition.eligible,
        CompletionTerminalizationReason.none,
      );

  const CompletionTerminalizationProof.alreadyTerminal()
    : this._(
        CompletionTerminalizationDisposition.alreadyTerminal,
        CompletionTerminalizationReason.none,
      );

  const CompletionTerminalizationProof.notEligible(
    CompletionTerminalizationReason reason,
  ) : this._(CompletionTerminalizationDisposition.notEligible, reason);

  const CompletionTerminalizationProof.recoveryRequired(
    CompletionTerminalizationReason reason,
  ) : this._(CompletionTerminalizationDisposition.recoveryRequired, reason);

  bool get canTerminalize =>
      disposition == CompletionTerminalizationDisposition.eligible;

  static CompletionTerminalizationProof evaluate({
    required String authenticatedUid,
    required String expectedRunId,
    required UserProfile profile,
    required OnboardingDraft draft,
    required OnboardingCompletionBundle bundle,
    required CompletionTerminalizationState currentRun,
    required bool durableOutputsVerified,
  }) {
    final job = currentRun.job;
    if (profile.uid != authenticatedUid ||
        draft.uid != authenticatedUid ||
        bundle.uid != authenticatedUid ||
        currentRun.ownerUid != authenticatedUid ||
        (job != null && job.ownerUid != authenticatedUid)) {
      return const CompletionTerminalizationProof.recoveryRequired(
        CompletionTerminalizationReason.ownerMismatch,
      );
    }
    if (profile.schemaVersion != UserProfile.currentSchemaVersion ||
        draft.storedSchemaVersion != OnboardingDraft.schemaVersion ||
        bundle.version != OnboardingCompletionBundle.schemaVersion ||
        currentRun.pointerSchemaVersion != 1 ||
        (job != null &&
            job.schemaVersion !=
                OnboardingCompletionJob.currentSchemaVersion)) {
      return const CompletionTerminalizationProof.recoveryRequired(
        CompletionTerminalizationReason.unsupportedSchema,
      );
    }
    if (!currentRun.hasPointer ||
        job == null ||
        expectedRunId.isEmpty ||
        currentRun.runId != expectedRunId) {
      return const CompletionTerminalizationProof.recoveryRequired(
        CompletionTerminalizationReason.currentRunMismatch,
      );
    }
    if (job.jobId != expectedRunId || bundle.runId != expectedRunId) {
      return const CompletionTerminalizationProof.recoveryRequired(
        CompletionTerminalizationReason.runMismatch,
      );
    }
    if (currentRun.sourceFingerprint != job.sourceFingerprint ||
        currentRun.draftRevision != job.draftRevision) {
      return const CompletionTerminalizationProof.recoveryRequired(
        CompletionTerminalizationReason.currentRunMismatch,
      );
    }
    if (job.status == OnboardingJobStatus.fatalFailure ||
        (job.status == OnboardingJobStatus.completed &&
            job.stage != OnboardingCompletionStage.completed)) {
      return const CompletionTerminalizationProof.recoveryRequired(
        CompletionTerminalizationReason.incompatibleTerminalState,
      );
    }
    if (!_isFinalDraft(draft)) {
      return const CompletionTerminalizationProof.notEligible(
        CompletionTerminalizationReason.invalidFinalDraft,
      );
    }
    if (bundle.sourceFingerprint != draft.effectiveSourceFingerprint ||
        bundle.draftRevision != draft.revision ||
        job.sourceFingerprint != draft.effectiveSourceFingerprint ||
        job.draftRevision != draft.revision) {
      return const CompletionTerminalizationProof.notEligible(
        CompletionTerminalizationReason.invalidCompletionBundle,
      );
    }
    if (!_hasRequiredVerification(job)) {
      return const CompletionTerminalizationProof.notEligible(
        CompletionTerminalizationReason.incompleteVerification,
      );
    }
    if (!_hasExactOutputAccounting(job, bundle) || !durableOutputsVerified) {
      return const CompletionTerminalizationProof.notEligible(
        CompletionTerminalizationReason.invalidOutputAccounting,
      );
    }

    final runTerminal =
        job.status == OnboardingJobStatus.completed &&
        job.stage == OnboardingCompletionStage.completed &&
        job.completedAt != null;
    final pointerTerminal = currentRun.pointerStatus == 'completed';
    final profileTerminal =
        profile.onboardingCompleted &&
        profile.onboardingProjectionStatus == 'completed';
    if (runTerminal && pointerTerminal && profileTerminal) {
      return const CompletionTerminalizationProof.alreadyTerminal();
    }
    if (runTerminal && !profileTerminal) {
      return const CompletionTerminalizationProof.recoveryRequired(
        CompletionTerminalizationReason.invalidProfileFinalization,
      );
    }
    if (currentRun.pointerStatus != 'active' && !pointerTerminal) {
      return const CompletionTerminalizationProof.recoveryRequired(
        CompletionTerminalizationReason.incompatibleTerminalState,
      );
    }
    if (job.stage.index < OnboardingCompletionStage.finalizeProfile.index) {
      return const CompletionTerminalizationProof.notEligible(
        CompletionTerminalizationReason.incompleteVerification,
      );
    }
    return const CompletionTerminalizationProof.eligible();
  }

  static bool _isFinalDraft(OnboardingDraft draft) {
    return draft.onboardingCompleted &&
        draft.currentStep == OnboardingDraft.lastStepIndex &&
        draft.stepCompleted.length == OnboardingDraft.stepCount &&
        draft.stepCompleted.every((value) => value);
  }

  static bool _hasRequiredVerification(OnboardingCompletionJob job) {
    for (final stage in OnboardingCompletionStage.values) {
      if (stage.index > OnboardingCompletionStage.verifyFrontendState.index) {
        break;
      }
      if (!job.isStageCompleted(stage)) return false;
    }
    return true;
  }

  static bool _hasExactOutputAccounting(
    OnboardingCompletionJob job,
    OnboardingCompletionBundle bundle,
  ) {
    bool exact(Iterable<String> left, Iterable<String> right) {
      final a = left.toSet();
      final b = right.toSet();
      return a.length == b.length && a.containsAll(b);
    }

    return job.failedRoutineIds.isEmpty &&
        job.failedHistoryIds.isEmpty &&
        job.failedHabitIds.isEmpty &&
        job.failedAcceptanceIds.isEmpty &&
        exact(job.expectedRoutineIds, bundle.expectedRoutineIds) &&
        exact(job.expectedHistoryIds, bundle.expectedHistoryIds) &&
        exact(job.expectedHabitIds, bundle.expectedHabitIds) &&
        exact(job.expectedAcceptanceIds, bundle.expectedAcceptanceIds) &&
        exact(job.expectedRoutineIds, {
          ...job.appliedRoutineIds,
          ...job.existingRoutineIds,
          ...job.repairedRoutineIds,
        }) &&
        exact(job.expectedHistoryIds, {
          ...job.appliedHistoryIds,
          ...job.existingHistoryIds,
          ...job.repairedHistoryIds,
        }) &&
        exact(job.expectedHabitIds, {
          ...job.appliedHabitIds,
          ...job.existingHabitIds,
          ...job.repairedHabitIds,
        }) &&
        exact(job.expectedAcceptanceIds, {
          ...job.appliedAcceptanceIds,
          ...job.existingAcceptanceIds,
          ...job.repairedAcceptanceIds,
        });
  }
}
