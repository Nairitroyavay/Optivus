import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/features/recovery/models/onboarding_recovery_models.dart';
import 'package:optivus/features/recovery/services/diagnostic_bundle_service.dart';
import 'package:optivus/features/recovery/services/recovery_retry_controller.dart';
import 'package:optivus/features/recovery/widgets/partial_failure_status_banner.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/state/auth_state.dart';

class OnboardingRecoveryScreen extends ConsumerWidget {
  const OnboardingRecoveryScreen({super.key});

  String _userFriendlyFailureReason(OnboardingFailureReason? reason) {
    if (reason == null) return 'Setup Recovery Required';
    return switch (reason) {
      OnboardingFailureReason.missingDraftAndBundle => 'Missing Bundle & Draft',
      OnboardingFailureReason.missingBundle => 'Missing Bundle',
      OnboardingFailureReason.corruptedBundle => 'Corrupted Bundle',
      OnboardingFailureReason.projectionFailed => 'Projection Failed',
      OnboardingFailureReason.networkTimeout => 'Network Timeout',
      OnboardingFailureReason.projectionReceiptMismatch =>
        'Projection Receipt Mismatch',
      OnboardingFailureReason.habitsProjectionFailed =>
        'Habits Projection Failed',
      OnboardingFailureReason.unhandledException => 'Unhandled Error',
    };
  }

  Map<String, bool> _stageStatuses(OnboardingCompletionJob job) {
    return {
      for (final stage in PartialFailureStatusBanner.defaultStages)
        stage: job.stagesCompleted[stage] == true,
    };
  }

  String? _currentStage(OnboardingCompletionJob job) {
    return switch (job.stage) {
      OnboardingCompletionStage.init ||
      OnboardingCompletionStage.completed => null,
      _ => job.stage.name,
    };
  }

  Widget _buildJobProgressBanner({
    required BuildContext context,
    required WidgetRef ref,
    required RecoveryRetryState retryState,
    required AsyncValue<OnboardingCompletionJob?> jobState,
  }) {
    final resume = retryState.canRetry
        ? () {
            ref
                .read(recoveryRetryControllerProvider.notifier)
                .recordAttemptAndStartCooldown();
            ref.read(authProvider.notifier).retryBackendRestore();
          }
        : null;

    return jobState.when(
      data: (job) {
        if (job == null) {
          return PartialFailureStatusBanner(
            progressUnavailable: true,
            stageStatuses: const {},
            currentStage: null,
            projectedItemCount: null,
            failedItemCount: null,
            onResume: resume,
          );
        }
        return PartialFailureStatusBanner(
          stageStatuses: _stageStatuses(job),
          currentStage: _currentStage(job),
          projectedItemCount: null,
          failedItemCount: null,
          onResume: job.status == OnboardingJobStatus.completed ? null : resume,
        );
      },
      loading: () => const PartialFailureStatusBanner(
        progressUnavailable: true,
        stageStatuses: {},
        currentStage: null,
        projectedItemCount: null,
        failedItemCount: null,
      ),
      error: (error, stackTrace) => PartialFailureStatusBanner(
        progressUnavailable: true,
        stageStatuses: const {},
        currentStage: null,
        projectedItemCount: null,
        failedItemCount: null,
        onResume: resume,
      ),
    );
  }

  Future<void> _exportDiagnostics(BuildContext context, WidgetRef ref) async {
    final service = ref.read(diagnosticBundleServiceProvider);
    final jsonText = await service.exportDiagnosticBundleJson(read: ref.read);
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Diagnostic Bundle'),
        content: SingleChildScrollView(
          child: SelectableText(
            jsonText,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final retryState = ref.watch(recoveryRetryControllerProvider);
    final uid = authState.user?.uid;
    final jobState = uid == null
        ? const AsyncValue<OnboardingCompletionJob?>.data(null)
        : ref.watch(onboardingCompletionJobProvider(uid));

    final failureReason = authState.onboardingFailureReason;
    final actions = authState.recoveryActions.isNotEmpty
        ? authState.recoveryActions
        : const <OnboardingRecoveryAction>[RetryNetworkAction()];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Recovery'),
        actions: [
          TextButton.icon(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign Out'),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompactHeight = constraints.maxHeight < 600;
            final iconSize = isCompactHeight ? 40.0 : 64.0;
            final spacing = isCompactHeight ? 8.0 : 16.0;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.build_circle_outlined,
                        size: iconSize,
                        color: Colors.amber,
                      ),
                      SizedBox(height: spacing),
                      Text(
                        'Setup Verification Incomplete',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        authState.errorMessage ??
                            'Your setup preferences were saved, but background configuration needs to be completed.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Chip(
                          avatar: const Icon(Icons.info_outline, size: 16),
                          label: Text(
                            'Reason: ${_userFriendlyFailureReason(failureReason)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          backgroundColor: Colors.amber.shade100,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildJobProgressBanner(
                        context: context,
                        ref: ref,
                        retryState: retryState,
                        jobState: jobState,
                      ),

                      if (retryState.isCoolingDown) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Please wait ${retryState.cooldownSecondsRemaining}s before retrying...',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (retryState.maxAttemptsReached) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Max retry attempts reached. Please contact support or restart setup forms.',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      SizedBox(height: spacing * 1.5),

                      // Recovery Action List with Title & Description
                      ...actions.map((action) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    action.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    action.description,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.grey.shade700),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed:
                                        retryState.canRetry ||
                                            action
                                                is ResumeOnboardingAction
                                        ? () {
                                            if (action
                                                is! ResumeOnboardingAction) {
                                              ref
                                                  .read(
                                                    recoveryRetryControllerProvider
                                                        .notifier,
                                                  )
                                                  .recordAttemptAndStartCooldown();
                                            }
                                            ref
                                                .read(authProvider.notifier)
                                                .executeRecoveryAction(action);
                                          }
                                        : null,
                                    child: Text(action.label),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 16),

                      // Bottom Actions: Export Diagnostics & Sign Out
                      Wrap(
                        alignment: WrapAlignment.spaceEvenly,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _exportDiagnostics(context, ref),
                            icon: const Icon(Icons.bug_report, size: 16),
                            label: const Text('Diagnostics'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                ref.read(authProvider.notifier).logout(),
                            icon: const Icon(Icons.logout, size: 16),
                            label: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
