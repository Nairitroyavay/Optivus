import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/state/mock_app_state.dart';
import 'package:optivus/widgets/animated_bot_avatar.dart';

class OnboardingStep8 extends ConsumerStatefulWidget {
  const OnboardingStep8({super.key});

  @override
  ConsumerState<OnboardingStep8> createState() => _OnboardingStep8State();
}

class _OnboardingStep8State extends ConsumerState<OnboardingStep8> {
  final _customCtrl = TextEditingController();
  static const coaches = ['Dad', 'Maa', 'Sensei', 'Coach', 'Custom'];
  static const styles = [
    'Supportive',
    'Tough Love',
    'Analytical',
    'Zen',
    'Motivational',
    'Friendly',
  ];

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(mockUserProfileProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: OnboardingSectionTitle(
            title: 'Coach Setup',
            subtitle:
                'Choose how your coach should sound during routine nudges.',
          ),
        ),
        Expanded(
          child: OnboardingScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          OnboardingGlassCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: coaches.map((coach) {
                final selected = coach == 'Custom'
                    ? !coaches
                          .where((c) => c != 'Custom')
                          .contains(profile.coachName)
                    : profile.coachName == coach;
                return OnboardingChip(
                  label: coach,
                  selected: selected,
                  onTap: () {
                    final next = coach == 'Custom'
                        ? (_customCtrl.text.trim().isEmpty
                              ? 'Coach'
                              : _customCtrl.text.trim())
                        : coach;
                    ref
                        .read(mockUserProfileProvider.notifier)
                        .updateCoachPreferences(coachName: next);
                    ref
                        .read(mockOnboardingProvider.notifier)
                        .setStepDirty(8, true);
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          OnboardingGlassCard(
            child: TextField(
              controller: _customCtrl,
              decoration: const InputDecoration(
                hintText: 'Custom coach name',
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (value) {
                if (value.trim().isEmpty) return;
                ref
                    .read(mockUserProfileProvider.notifier)
                    .updateCoachPreferences(coachName: value.trim());
                ref.read(mockOnboardingProvider.notifier).setStepDirty(8, true);
              },
            ),
          ),
          const SizedBox(height: 12),
          OnboardingGlassCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: styles
                  .map(
                    (style) => OnboardingChip(
                      label: style,
                      selected: profile.coachStyle == style,
                      accent: OptivusColors.aquaAccent,
                      onTap: () {
                        ref
                            .read(mockUserProfileProvider.notifier)
                            .updateCoachPreferences(coachStyle: style);
                        ref
                            .read(mockOnboardingProvider.notifier)
                            .setStepDirty(8, true);
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          OnboardingGlassCard(
            tint: OptivusColors.aquaAccent.withValues(alpha: 0.12),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Liquid ambient blob behind the avatar
                Positioned(
                  left: -10,
                  top: -10,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: OptivusColors.aquaAccent.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AnimatedBotAvatar(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${profile.coachName} preview',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: OptivusColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Good morning ${profile.displayName}. We start small, protect the timeline, and recover fast if anything slips.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: OptivusColors.textBody,
                              height: 1.5,
                            ),
                          ),
                        ], // end Column children
                      ), // end Column
                    ), // end Expanded
                  ], // end Row children
                ), // end Row
              ], // end Stack children
            ), // end Stack
          ), // end OnboardingGlassCard
        ], // end OnboardingScrollView inner Column children
      ), // end OnboardingScrollView inner Column
    ), // end OnboardingScrollView
  ), // end Expanded
], // end outer Column children
);
}
}
