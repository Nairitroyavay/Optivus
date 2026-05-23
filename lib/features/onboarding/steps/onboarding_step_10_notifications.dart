import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/state/app_state.dart';

class OnboardingStep10 extends ConsumerStatefulWidget {
  const OnboardingStep10({super.key});

  @override
  ConsumerState<OnboardingStep10> createState() => _OnboardingStep10State();
}

class _OnboardingStep10State extends ConsumerState<OnboardingStep10> {
  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(mockOnboardingProvider).draft.notifications;
    final toggles = [
      (
        'Morning start',
        notifications.morningStartReminder,
        (bool value) => notifications.copyWith(morningStartReminder: value),
      ),
      (
        'Next task',
        notifications.nextTaskReminder,
        (bool value) => notifications.copyWith(nextTaskReminder: value),
      ),
      (
        'Eating',
        notifications.eatingReminder,
        (bool value) => notifications.copyWith(eatingReminder: value),
      ),
      (
        'Bad habit check-in',
        notifications.badHabitCheckInReminder,
        (bool value) => notifications.copyWith(badHabitCheckInReminder: value),
      ),
      (
        'Savings',
        notifications.savingsReminder,
        (bool value) => notifications.copyWith(savingsReminder: value),
      ),
      (
        'Night reflection',
        notifications.nightReflectionReminder,
        (bool value) => notifications.copyWith(nightReflectionReminder: value),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: OnboardingSectionTitle(
            title: 'Notifications',
            subtitle:
                'Mock reminder preferences only. No permission dialog is requested here.',
          ),
        ),
        Expanded(
          child: OnboardingScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...toggles.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OnboardingGlassCard(
                      selected: entry.$2,
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: entry.$2
                                  ? OptivusColors.brandAccent.withValues(
                                      alpha: 0.16,
                                    )
                                  : Colors.white.withValues(alpha: 0.36),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                            ),
                            child: Icon(
                              Icons.notifications_active_outlined,
                              color: entry.$2
                                  ? OptivusColors.brandAccent
                                  : OptivusColors.textSecondary,
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.$1,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Local onboarding preference',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: OptivusColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OnboardingLiquidToggle(
                            value: entry.$2,
                            onChanged: (value) {
                              ref
                                  .read(mockOnboardingProvider.notifier)
                                  .updateDraft(
                                    (draft) => draft.copyWith(
                                      notifications: entry.$3(value),
                                      clearFinalPreview: true,
                                    ),
                                  );
                              ref
                                  .read(mockOnboardingProvider.notifier)
                                  .setStepDirty(10, true);
                            },
                            accent: OptivusColors.brandAccent,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                OnboardingGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reminder intensity',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['Low', 'Medium', 'High']
                            .map(
                              (level) => OnboardingChip(
                                label: level,
                                selected:
                                    notifications.reminderIntensity ==
                                    level.toLowerCase(),
                                onTap: () {
                                  ref
                                      .read(mockOnboardingProvider.notifier)
                                      .updateDraft(
                                        (draft) => draft.copyWith(
                                          notifications: draft.notifications
                                              .copyWith(
                                                reminderIntensity: level
                                                    .toLowerCase(),
                                              ),
                                          clearFinalPreview: true,
                                        ),
                                      );
                                  ref
                                      .read(mockOnboardingProvider.notifier)
                                      .setStepDirty(10, true);
                                },
                                accent: OptivusColors.aquaAccent,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                OnboardingGlassCard(
                  tint: OptivusColors.aquaAccent.withValues(alpha: 0.08),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        color: OptivusColors.aquaAccent,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Mock permission card: notification access can be connected later from the real app shell.',
                          style: TextStyle(
                            fontSize: 12,
                            color: OptivusColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ], // end Row children
                  ), // end Row
                ), // end OnboardingGlassCard
              ], // end OnboardingScrollView inner Column children
            ), // end OnboardingScrollView inner Column
          ), // end OnboardingScrollView
        ), // end Expanded
      ], // end outer Column children
    );
  }
}
