import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class RetryCompletionJobAction extends OnboardingRecoveryAction {
  const RetryCompletionJobAction()
    : super(
        actionId: 'retry_completion_job',
        label: 'Retry Setup',
        description:
            'Resume the onboarding completion process from where it left off.',
      );

  @override
  Future<void> execute(Ref ref, String uid) async {}
}

class RebuildBundleFromDraftAction extends OnboardingRecoveryAction {
  const RebuildBundleFromDraftAction()
    : super(
        actionId: 'rebuild_bundle_from_draft',
        label: 'Rebuild Setup Plan',
        description:
            'Reconstruct your onboarding plan from saved form inputs and retry.',
      );

  @override
  Future<void> execute(Ref ref, String uid) async {}
}



class RestartOnboardingInputAction extends OnboardingRecoveryAction {
  const RestartOnboardingInputAction()
    : super(
        actionId: 'restart_onboarding_input',
        label: 'Restart Setup Forms',
        description:
            'Reset onboarding input forms and re-enter your preferences.',
      );

  @override
  Future<void> execute(Ref ref, String uid) async {}
}

class ForceResyncProjectionsAction extends OnboardingRecoveryAction {
  const ForceResyncProjectionsAction()
    : super(
        actionId: 'force_resync_projections',
        label: 'Force Resync Projections',
        description:
            'Force resync routine and habit projections into Firestore.',
      );

  @override
  Future<void> execute(Ref ref, String uid) async {}
}
