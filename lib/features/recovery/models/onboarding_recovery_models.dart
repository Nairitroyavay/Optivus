import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/state/auth_state.dart';
export 'package:optivus/services/onboarding_completion_service.dart'
    show OnboardingRecoveryTier;

enum OnboardingFailureReason {
  networkTimeout,
  missingBundle,
  missingDraftAndBundle,
  corruptedBundle,
  projectionFailed,
  projectionReceiptMismatch,
  habitsProjectionFailed,
  unhandledException,
}

abstract class OnboardingRecoveryAction {
  final String actionId;
  final String label;
  final String description;

  const OnboardingRecoveryAction({
    required this.actionId,
    required this.label,
    required this.description,
  });

  Future<void> execute(Ref ref, String uid);
}

class RetryNetworkAction extends OnboardingRecoveryAction {
  const RetryNetworkAction()
    : super(
        actionId: 'retry_network',
        label: 'Retry Connection',
        description: 'Retry the last operation after a network failure.',
      );

  @override
  Future<void> execute(Ref ref, String uid) async {
    await ref.read(authProvider.notifier).retryBackendRestore();
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
  Future<void> execute(Ref ref, String uid) async {
    final draft = await ref.read(onboardingRepositoryProvider).fetchDraft(uid);
    if (draft != null) {
      final firstMissingStep = draft.stepCompleted.indexOf(false);
      final stepToResume = firstMissingStep != -1
          ? firstMissingStep
          : (draft.currentStep < OnboardingDraft.lastStepIndex
                ? draft.currentStep
                : 0);
      final updatedDraft = draft.copyWith(
        currentStep: stepToResume,
        onboardingCompleted: false,
      );
      await ref.read(onboardingRepositoryProvider).saveDraft(updatedDraft);
    }
    final user = ref.read(authProvider).user;
    if (user != null && user.uid == uid) {
      await ref.read(authProvider.notifier).markOnboardingIncomplete(user);
    }
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
  Future<void> execute(Ref ref, String uid) async {
    await ref.read(authProvider.notifier).retryBackendRestore();
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
  Future<void> execute(Ref ref, String uid) async {
    await ref.read(authProvider.notifier).retryBackendRestore();
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
  Future<void> execute(Ref ref, String uid) async {
    final repo = ref.read(onboardingRepositoryProvider);
    final draft = await repo.fetchDraft(uid);
    if (draft != null) {
      final firstMissingStep = draft.stepCompleted.indexOf(false);
      final isDraftValid =
          draft.onboardingCompleted &&
          firstMissingStep == -1 &&
          draft.validateStep(14, draft.stepCompleted) == null;
      if (isDraftValid) {
        final bundle = OnboardingCompletionService.buildBundle(draft);
        await repo.saveCompletionBundle(bundle);
        
        final readbackBundle = await repo.fetchCompletionBundle(uid);
        if (readbackBundle == null || readbackBundle.version != bundle.version) {
          throw StateError('Completion bundle read-back verification failed during recovery.');
        }
        await ref.read(authProvider.notifier).retryBackendRestore();
        return;
      }
    }
    // Fallback if not valid
    await const ResumeOnboardingAction().execute(ref, uid);
  }
}

class MigrateLegacySetupAction extends OnboardingRecoveryAction {
  const MigrateLegacySetupAction()
    : super(
        actionId: 'migrate_legacy_setup',
        label: 'Update Setup Data',
        description: 'Migrate older setup data to the current version.',
      );

  @override
  Future<void> execute(Ref ref, String uid) async {
    await const ResetSetupSafelyAction().execute(ref, uid);
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
  Future<void> execute(Ref ref, String uid) async {
    final user = ref.read(authProvider).user;
    if (user != null && user.uid == uid) {
      await ref.read(authProvider.notifier).markOnboardingIncomplete(user);
    }
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
  Future<void> execute(Ref ref, String uid) async {
    await ref.read(authProvider.notifier).logout();
  }
}
