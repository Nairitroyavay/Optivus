import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_spacing.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/state/app_state.dart';

class OnboardingStep12 extends ConsumerWidget {
  const OnboardingStep12({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(mockOnboardingProvider).draft;
    final coachName = draft.coachSetup.coachName ?? 'Coach';
    const styles = [
      (
        'forgiving',
        'Forgiving',
        Icons.favorite_rounded,
        'Offer a tiny replacement and keep momentum.',
      ),
      (
        'strict',
        'Strict',
        Icons.gavel_rounded,
        'Call out misses clearly and protect non-negotiables.',
      ),
      (
        'direct_but_kind',
        'Direct but kind',
        Icons.record_voice_over_rounded,
        'Be honest, then give the next action.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: OptivusSpacing.onboardingHeaderPadding,
          child: OnboardingSectionTitle(
            title: 'Slip-up Handling',
            subtitle: 'Choose the comeback tone when you miss a task or habit.',
          ),
        ),
        Expanded(
          child: OnboardingScrollView(
            padding: OptivusSpacing.onboardingContentPadding,
            userScrollable: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...styles.map((style) {
                  final selected = draft.slipUpHandling == style.$1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OnboardingChoiceTile(
                      title: style.$2,
                      subtitle: style.$4,
                      icon: style.$3,
                      selected: selected,
                      onTap: () {
                        ref
                            .read(mockOnboardingProvider.notifier)
                            .updateDraft(
                              (current) => current.copyWith(
                                slipUpHandling: style.$1,
                                clearFinalPreview: true,
                              ),
                            );
                        ref
                            .read(mockOnboardingProvider.notifier)
                            .setStepDirty(12, true);
                      },
                    ),
                  );
                }),
                OnboardingGlassCard(
                  tint: OptivusColors.brandAccent.withValues(alpha: 0.08),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Comeback preview',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$coachName: You slipped, but the next block is still available. Take the tiny version now and keep the identity alive.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: OptivusColors.textBody,
                          height: 1.45,
                        ),
                      ),
                    ], // end OnboardingGlassCard Column children
                  ), // end OnboardingGlassCard Column
                ), // end OnboardingGlassCard
              ], // end OnboardingScrollView inner Column children
            ), // end OnboardingScrollView inner Column
          ), // end OnboardingScrollView
        ), // end Expanded
      ], // end outer Column children
    );
  }
}
