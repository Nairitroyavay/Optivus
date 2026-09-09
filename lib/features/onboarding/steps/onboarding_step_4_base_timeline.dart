import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step4_unified.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/state/app_state.dart';

class OnboardingStep4 extends ConsumerWidget {
  const OnboardingStep4({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingStateProvider).draft;
    final role = draft.lifeRole.lifeRole;
    final classesRequired =
        role == LifeRoleDraft.studentKey ||
        role == LifeRoleDraft.studentWorkingKey;
    final workRequired =
        role == LifeRoleDraft.workingKey ||
        role == LifeRoleDraft.studentWorkingKey ||
        role == LifeRoleDraft.businessKey;

    // No setup needed for this role — show a simple message.
    if (!classesRequired && !workRequired) {
      return OnboardingStepBody(
        title: 'Classes & Job',
        subtitle: 'No class or work schedule is needed for this role.',
        accent: OptivusColors.aquaAccent,
        children: [
          OnboardingGlassCard(
            tint: OptivusColors.success.withValues(alpha: 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: OptivusColors.success,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No class/work setup needed',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: OptivusColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your selected role does not require fixed class or '
                  'work blocks.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: OptivusColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Classes/work required — show the unified upload+timeline flow.
    return const OnboardingStep4Unified();
  }
}
