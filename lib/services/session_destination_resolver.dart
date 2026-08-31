import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/services/onboarding_resume_validator.dart';
import 'package:optivus/services/server_reconstructor.dart';

enum SessionDestinationKind {
  resolving,
  signedOut,
  verifyEmail,
  freshOnboarding,
  resumeOnboarding,
  finishOnboarding,
  home,
  reconnect,
  needsAction,
}

class SessionDestination {
  final SessionDestinationKind kind;
  final int? resumeStep;
  final String? runId;
  final String? reasonCode;

  const SessionDestination._(
    this.kind, {
    this.resumeStep,
    this.runId,
    this.reasonCode,
  });

  const SessionDestination.resolving()
    : this._(SessionDestinationKind.resolving);
  const SessionDestination.signedOut()
    : this._(SessionDestinationKind.signedOut);
  const SessionDestination.verifyEmail()
    : this._(SessionDestinationKind.verifyEmail);
  const SessionDestination.freshOnboarding()
    : this._(SessionDestinationKind.freshOnboarding);
  const SessionDestination.resumeOnboarding(int step)
    : this._(SessionDestinationKind.resumeOnboarding, resumeStep: step);
  const SessionDestination.finishOnboarding({String? runId})
    : this._(SessionDestinationKind.finishOnboarding, runId: runId);
  const SessionDestination.home() : this._(SessionDestinationKind.home);
  const SessionDestination.reconnect({String? reasonCode})
    : this._(SessionDestinationKind.reconnect, reasonCode: reasonCode);
  const SessionDestination.needsAction(String reasonCode)
    : this._(SessionDestinationKind.needsAction, reasonCode: reasonCode);
}

/// The single destination mapping for an already reconstructed server session.
SessionDestination resolveReconstructionDestination(
  ReconstructionResult result,
) {
  return switch (result) {
    ReconstructionFresh() => const SessionDestination.freshOnboarding(),
    ReconstructionIncomplete(:final step) =>
      SessionDestination.resumeOnboarding(step),
    ReconstructionFinishing(:final runId) =>
      SessionDestination.finishOnboarding(runId: runId),
    ReconstructionCompleted() => const SessionDestination.home(),
    ReconstructionRecovery(:final reason) => SessionDestination.needsAction(
      'reconstruction_${reason.name}',
    ),
  };
}

bool hasMeaningfulOnboardingProgress(OnboardingDraft draft) {
  // Only a durably completed step proves that onboarding has started. An
  // empty draft, a viewed page, an edit/revision, or the legacy welcome marker
  // must not turn a newly-created account into a restore session.
  return draft.stepCompleted.any((value) => value);
}

bool isDurablyFinalOnboardingDraft(OnboardingDraft draft) {
  return draft.onboardingCompleted &&
      draft.stepCompleted.length == OnboardingDraft.stepCount &&
      draft.stepCompleted.every((value) => value) &&
      draft.uid.trim().isNotEmpty;
}

SessionDestination resolveOnboardingSessionDestination({
  required String ownerUid,
  required UserProfile profile,
  required OnboardingDraft? draft,
  OnboardingCompletionJob? completionJob,
}) {
  if (profile.uid != ownerUid) {
    return const SessionDestination.needsAction('profile_owner_mismatch');
  }
  if (draft != null && draft.uid != ownerUid) {
    return const SessionDestination.needsAction('draft_owner_mismatch');
  }
  if (completionJob != null && completionJob.ownerUid != ownerUid) {
    return const SessionDestination.needsAction(
      'completion_job_owner_mismatch',
    );
  }

  if (profile.onboardingCompleted) {
    return const SessionDestination.home();
  }

  if (draft == null) {
    final projectionIsPreCompletion =
        profile.onboardingProjectionStatus.isEmpty ||
        profile.onboardingProjectionStatus == 'none' ||
        profile.onboardingProjectionStatus == 'pending';
    if (!profile.onboardingInputCompleted &&
        projectionIsPreCompletion &&
        profile.onboardingStep <= 0 &&
        completionJob == null) {
      return const SessionDestination.freshOnboarding();
    }
    return const SessionDestination.needsAction(
      'durable_onboarding_state_missing',
    );
  }

  if (isDurablyFinalOnboardingDraft(draft)) {
    if (completionJob?.status == OnboardingJobStatus.fatalFailure) {
      return const SessionDestination.needsAction(
        'completion_job_needs_action',
      );
    }
    return SessionDestination.finishOnboarding(runId: completionJob?.jobId);
  }

  // A job can exist before its final draft has been durably persisted. In that
  // case the durable draft proves that Step 14 still needs user completion.
  if (profile.onboardingInputCompleted &&
      durableOnboardingResumeStep(draft) < OnboardingDraft.lastStepIndex) {
    return const SessionDestination.needsAction(
      'completion_flags_do_not_match_draft',
    );
  }

  final resumeStep = durableOnboardingResumeStep(draft);
  if (hasMeaningfulOnboardingProgress(draft) || completionJob != null) {
    return SessionDestination.resumeOnboarding(resumeStep);
  }
  return const SessionDestination.freshOnboarding();
}
