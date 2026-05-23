import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/state/mock_app_state.dart';

class OnboardingStep1 extends ConsumerWidget {
  const OnboardingStep1({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mockOnboardingProvider);

    return OnboardingScrollView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
      userScrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 18),
          Text(
            'The Spike vs. Compound Rule',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Most modern apps push instant high-intensity targets that cause rapid burnout. Optivus builds resilient habit compound engines. We target identity over extremes.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: OptivusColors.textBody),
          ),
          const SizedBox(height: 34),
          OnboardingGlassPanel(
            hasPins: true,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.48),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  child: const Icon(
                    Icons.hourglass_empty_rounded,
                    size: 32,
                    color: OptivusColors.brandAccent,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Patience Pledge',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'I agree to start with tiny steps, pivot schedules dynamically rather than skip them, and give my nervous system time to adapt.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    final isCompleted = state.stepCompleted[1];
                    ref
                        .read(mockOnboardingProvider.notifier)
                        .setStepCompleted(1, !isCompleted);
                    ref
                        .read(mockOnboardingProvider.notifier)
                        .setStepDirty(1, false);
                  },
                  child: OnboardingGlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    radius: 22,
                    selected: state.stepCompleted[1],
                    tint: state.stepCompleted[1]
                        ? OptivusColors.success.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.34),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          state.stepCompleted[1]
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: state.stepCompleted[1]
                              ? OptivusColors.success
                              : OptivusColors.brandAccent,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          state.stepCompleted[1]
                              ? 'Commitment Locked'
                              : 'I Pledge Commitment',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: state.stepCompleted[1]
                                    ? OptivusColors.success
                                    : OptivusColors.textPrimary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
