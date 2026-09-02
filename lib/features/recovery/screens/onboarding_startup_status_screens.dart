import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/presentation/step14_presentation_models.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/widgets/glass_logo.dart';

class FinishingOnboardingScreen extends ConsumerStatefulWidget {
  const FinishingOnboardingScreen({super.key});

  @override
  ConsumerState<FinishingOnboardingScreen> createState() =>
      _FinishingOnboardingScreenState();
}

class _FinishingOnboardingScreenState
    extends ConsumerState<FinishingOnboardingScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(authProvider.notifier).retryBackendRestore();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeJobNotifier = ref.watch(activeOnboardingCompletionJobProvider);
    final activeJob = activeJobNotifier.value;
    final currentStage = activeJob?.stage ?? OnboardingCompletionStage.validateInput;
    final jobStatus = activeJob?.status ?? OnboardingJobStatus.running;

    final stageProjections = CompletionStageProjection.projectAll(
      currentStage: currentStage,
      jobStatus: jobStatus,
    );

    return Scaffold(
      key: const ValueKey('step14-finishing'),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6E6B4), Color(0xFFFCF8EE), Colors.white],
            stops: [0, .46, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const GlassLogo(),
                    const SizedBox(height: 24),
                    const Text(
                      'Building your Optivus',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF171A22),
                        fontSize: 26,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "We're putting everything in place.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF5D6470),
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 28),
                    for (final stage in stageProjections) ...[
                      Row(
                        key: ValueKey('step14-finishing-stage-${stage.stageId.id}'),
                        children: [
                          _buildStageIcon(stage.status),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              stage.publicLabel,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: stage.status == CompletionStageStatus.active
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: stage.status == CompletionStageStatus.pending
                                    ? OptivusColors.textSecondary.withValues(alpha: 0.5)
                                    : OptivusColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStageIcon(CompletionStageStatus status) {
    return switch (status) {
      CompletionStageStatus.completed => const Icon(
          Icons.check_circle_rounded,
          size: 18,
          color: OptivusColors.success,
        ),
      CompletionStageStatus.active => Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: OptivusColors.brandAccent.withValues(alpha: 0.2),
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: OptivusColors.brandAccent,
              ),
            ),
          ),
        ),
      CompletionStageStatus.pending => Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: OptivusColors.textSecondary.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
        ),
      CompletionStageStatus.failed => const Icon(
          Icons.error_rounded,
          size: 18,
          color: OptivusColors.danger,
        ),
    };
  }
}

class OnboardingReconnectScreen extends ConsumerWidget {
  const OnboardingReconnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _StartupStatusLayout(
      title: 'We couldn’t reconnect yet',
      message:
          'Your saved setup has not been reset. Try again when you’re online.',
      primaryAction: FilledButton(
        onPressed: () => ref.read(authProvider.notifier).retryBackendRestore(),
        child: const Text('Try Again'),
      ),
      secondaryAction: TextButton(
        onPressed: () => ref.read(authProvider.notifier).logout(),
        child: const Text('Sign Out'),
      ),
    );
  }
}

class _StartupStatusLayout extends StatelessWidget {
  final String title;
  final String message;
  final Widget? primaryAction;
  final Widget? secondaryAction;

  const _StartupStatusLayout({
    required this.title,
    required this.message,
    this.primaryAction,
    this.secondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6E6B4), Color(0xFFFCF8EE), Colors.white],
            stops: [0, .46, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const GlassLogo(),
                    const SizedBox(height: 30),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF171A22),
                        fontSize: 28,
                        height: 1.08,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF5D6470),
                        fontSize: 15,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (primaryAction != null || secondaryAction != null) ...[
                      const SizedBox(height: 32),
                      ?primaryAction,
                      if (primaryAction != null && secondaryAction != null)
                        const SizedBox(height: 12),
                      ?secondaryAction,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
