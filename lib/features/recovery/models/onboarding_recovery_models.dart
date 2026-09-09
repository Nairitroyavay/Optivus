import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/features/onboarding/onboarding_step_id.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/services/onboarding_resume_validator.dart';
export 'package:optivus/services/onboarding_completion_service.dart'
    show OnboardingRecoveryTier;

abstract class OnboardingRecoveryAction {
  final String actionId;
  final String label;
  final String description;

  const OnboardingRecoveryAction({
    required this.actionId,
    required this.label,
    required this.description,
  });

  Future<void> execute(
    Ref ref,
    String uid,
    OnboardingRecoveryOperations operations,
  );
}

class OnboardingRecoveryOperations {
  final Future<void> Function() retryBackendRestore;
  final Future<void> Function() markOnboardingIncomplete;
  final Future<void> Function() signOut;

  const OnboardingRecoveryOperations({
    required this.retryBackendRestore,
    required this.markOnboardingIncomplete,
    required this.signOut,
  });
}

class RetryNetworkAction extends OnboardingRecoveryAction {
  const RetryNetworkAction()
    : super(
        actionId: 'retry_network',
        label: 'Retry Connection',
        description: 'Retry the last operation after a network failure.',
      );

  @override
  Future<void> execute(
    Ref ref,
    String uid,
    OnboardingRecoveryOperations operations,
  ) async {
    await operations.retryBackendRestore();
  }
}

class ResumeOnboardingAction extends OnboardingRecoveryAction {
  const ResumeOnboardingAction()
    : super(
        actionId: 'resume_onboarding',
        label: 'Resume Setup',
        description: 'Resume onboarding from the last valid step.',
      );

  @override
  Future<void> execute(
    Ref ref,
    String uid,
    OnboardingRecoveryOperations operations,
  ) async {
    final draft = await ref.read(onboardingRepositoryProvider).fetchDraft(uid);
    if (draft == null) {
      throw StateError('No onboarding draft is available to resume.');
    }
    if (draft.uid != uid) {
      throw StateError('Onboarding draft owner mismatch.');
    }
    if (draft.onboardingCompleted) {
      throw StateError('A completed onboarding draft cannot be resumed.');
    }
    final stepToResume = validateOnboardingResume(draft).resumeStep;
    final updatedDraft = draft.copyWith(
      currentStep: stepToResume,
      onboardingCompleted: false,
    );
    await ref.read(onboardingRepositoryProvider).saveDraft(updatedDraft);
    await operations.markOnboardingIncomplete();
  }
}

class ResumeProjectionAction extends OnboardingRecoveryAction {
  const ResumeProjectionAction()
    : super(
        actionId: 'resume_projection',
        label: 'Resume Building Plan',
        description: 'Resume projecting routines and habits.',
      );

  @override
  Future<void> execute(
    Ref ref,
    String uid,
    OnboardingRecoveryOperations operations,
  ) async {
    await operations.retryBackendRestore();
  }
}

class RepairProjectionAction extends OnboardingRecoveryAction {
  const RepairProjectionAction()
    : super(
        actionId: 'repair_projection',
        label: 'Repair Plan',
        description: 'Repair missing or corrupted routines.',
      );

  @override
  Future<void> execute(
    Ref ref,
    String uid,
    OnboardingRecoveryOperations operations,
  ) async {
    await operations.retryBackendRestore();
  }
}

class RebuildBundleFromVerifiedDraftAction extends OnboardingRecoveryAction {
  const RebuildBundleFromVerifiedDraftAction()
    : super(
        actionId: 'rebuild_bundle',
        label: 'Rebuild Setup Plan',
        description: 'Reconstruct your onboarding plan from saved inputs.',
      );

  @override
  Future<void> execute(
    Ref ref,
    String uid,
    OnboardingRecoveryOperations operations,
  ) async {
    final repo = ref.read(onboardingRepositoryProvider);
    final draft = await repo.fetchDraft(uid);
    if (draft == null) {
      throw StateError('No onboarding draft is available to rebuild.');
    }
    if (draft.uid != uid) {
      throw StateError('Onboarding draft owner mismatch.');
    }
    final firstMissingStep = draft.stepCompleted.indexOf(false);
    final isDraftValid =
        draft.onboardingCompleted &&
        firstMissingStep == -1 &&
        draft.validateStep(
              OnboardingStepId.todayReady.index,
              draft.stepCompleted,
            ) ==
            null;
    if (isDraftValid) {
      final bundle = OnboardingCompletionService.buildBundle(draft);
      await repo.saveCompletionBundle(bundle);
      final readbackBundle = await repo.fetchCompletionBundle(uid);
      if (readbackBundle == null ||
          readbackBundle.uid != uid ||
          readbackBundle.version != bundle.version ||
          readbackBundle.sourceFingerprint != bundle.sourceFingerprint ||
          readbackBundle.draftRevision != draft.revision) {
        throw StateError(
          'Completion bundle read-back verification failed during recovery.',
        );
      }
      await operations.retryBackendRestore();
      return;
    }
    if (draft.onboardingCompleted) {
      throw StateError('Completed draft failed recovery verification.');
    }
    await const ResumeOnboardingAction().execute(ref, uid, operations);
  }
}

class ResetSetupSafelyAction extends OnboardingRecoveryAction {
  const ResetSetupSafelyAction()
    : super(
        actionId: 'reset_setup_safely',
        label: 'Start Over',
        description: 'Reset onboarding completely while keeping your account.',
      );

  @override
  Future<void> execute(
    Ref ref,
    String uid,
    OnboardingRecoveryOperations operations,
  ) async {
    await operations.markOnboardingIncomplete();
  }
}

class SignOutAction extends OnboardingRecoveryAction {
  const SignOutAction()
    : super(
        actionId: 'sign_out_recovery',
        label: 'Sign Out',
        description: 'Sign out and try again.',
      );

  @override
  Future<void> execute(
    Ref ref,
    String uid,
    OnboardingRecoveryOperations operations,
  ) async {
    await operations.signOut();
  }
}
