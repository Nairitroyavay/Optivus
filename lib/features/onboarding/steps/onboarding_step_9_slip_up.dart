import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/state/mock_app_state.dart';

class OnboardingStep9 extends ConsumerWidget {
  const OnboardingStep9({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(mockUserProfileProvider);
    const styles = [
      (
        'Forgiving',
        Icons.favorite_rounded,
        'Offer a tiny replacement and keep momentum.',
      ),
      (
        'Strict',
        Icons.gavel_rounded,
        'Call out misses clearly and protect non-negotiables.',
      ),
      (
        'Direct but kind',
        Icons.record_voice_over_rounded,
        'Be honest, then give the next action.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: OnboardingSectionTitle(
            title: 'Slip-up Handling',
            subtitle: 'Choose the comeback tone when you miss a task or habit.',
          ),
        ),
        Expanded(
          child: OnboardingScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          ...styles.map((style) {
            final selected =
                profile.slipUpStyle == style.$1 ||
                profile.slipUpStyle == style.$1.replaceAll(' ', '');
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OnboardingChoiceTile(
                title: style.$1,
                subtitle: style.$3,
                icon: style.$2,
                selected: selected,
                onTap: () {
                  ref
                      .read(mockUserProfileProvider.notifier)
                      .updateCoachPreferences(
                        slipUpStyle: style.$1 == 'Direct but kind'
                            ? 'DirectKind'
                            : style.$1,
                      );
                  ref
                      .read(mockOnboardingProvider.notifier)
                      .setStepDirty(9, true);
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
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  '${profile.coachName}: You slipped, but the next block is still available. Take the tiny version now and keep the identity alive.',
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
