import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_spacing.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/onboarding/onboarding_step_id.dart';
import 'package:optivus/state/app_state.dart';

class OnboardingNotificationsStep extends ConsumerStatefulWidget {
  const OnboardingNotificationsStep({super.key});

  @override
  ConsumerState<OnboardingNotificationsStep> createState() =>
      _OnboardingNotificationsStepState();
}

class _OnboardingNotificationsStepState
    extends ConsumerState<OnboardingNotificationsStep> {
  @override
  Widget build(BuildContext context) {
    final notifications = ref
        .watch(onboardingStateProvider)
        .draft
        .notifications;
    final toggles = [
      (
        'Morning start',
        notifications.morningStartReminder,
        (bool value) => notifications.copyWith(
          morningStartReminder: value,
          preferencesConfirmed: false,
        ),
      ),
      (
        'Next task',
        notifications.nextTaskReminder,
        (bool value) => notifications.copyWith(
          nextTaskReminder: value,
          preferencesConfirmed: false,
        ),
      ),
      (
        'Eating',
        notifications.eatingReminder,
        (bool value) => notifications.copyWith(
          eatingReminder: value,
          preferencesConfirmed: false,
        ),
      ),
      (
        'Bad habit check-in',
        notifications.badHabitCheckInReminder,
        (bool value) => notifications.copyWith(
          badHabitCheckInReminder: value,
          preferencesConfirmed: false,
        ),
      ),
      (
        'Savings',
        notifications.savingsReminder,
        (bool value) => notifications.copyWith(
          savingsReminder: value,
          preferencesConfirmed: false,
        ),
      ),
      (
        'Night reflection',
        notifications.nightReflectionReminder,
        (bool value) => notifications.copyWith(
          nightReflectionReminder: value,
          preferencesConfirmed: false,
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: OptivusSpacing.onboardingHeaderPadding,
          child: OnboardingSectionTitle(
            title: 'Notifications',
            subtitle:
                'Set reminder preferences here. No system permission dialog is requested during onboarding.',
          ),
        ),
        Expanded(
          child: OnboardingScrollView(
            padding: OptivusSpacing.onboardingContentPadding,
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
                                  .read(onboardingStateProvider.notifier)
                                  .updateDraft(
                                    (draft) => draft.copyWith(
                                      notifications: entry.$3(value),
                                      clearFinalPreview: true,
                                    ),
                                  );
                              ref
                                  .read(onboardingStateProvider.notifier)
                                  .setStepDirty(
                                    OnboardingStepId.notifications.index,
                                    true,
                                  );
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
                                      .read(onboardingStateProvider.notifier)
                                      .updateDraft(
                                        (draft) => draft.copyWith(
                                          notifications: draft.notifications
                                              .copyWith(
                                                reminderIntensity: level
                                                    .toLowerCase(),
                                                preferencesConfirmed: false,
                                              ),
                                          clearFinalPreview: true,
                                        ),
                                      );
                                  ref
                                      .read(onboardingStateProvider.notifier)
                                      .setStepDirty(
                                        OnboardingStepId.notifications.index,
                                        true,
                                      );
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
                  tint: notifications.preferencesConfirmed
                      ? OptivusColors.success.withValues(alpha: 0.08)
                      : OptivusColors.brandAccent.withValues(alpha: 0.08),
                  child: Row(
                    children: [
                      Icon(
                        notifications.preferencesConfirmed
                            ? Icons.check_circle_outline_rounded
                            : Icons.rule_rounded,
                        color: notifications.preferencesConfirmed
                            ? OptivusColors.success
                            : OptivusColors.brandAccent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          notifications.preferencesConfirmed
                              ? 'Reminder preferences saved. Permission setup is now available.'
                              : 'Confirm app-level reminder preferences before permission setup.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: OptivusColors.textSecondary,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      OnboardingActionPill(
                        label: notifications.preferencesConfirmed
                            ? 'Confirmed'
                            : 'Confirm',
                        icon: Icons.check_rounded,
                        accent: notifications.preferencesConfirmed
                            ? OptivusColors.success
                            : OptivusColors.brandAccent,
                        compact: true,
                        selected: notifications.preferencesConfirmed,
                        onTap: () {
                          ref
                              .read(onboardingStateProvider.notifier)
                              .updateDraft(
                                (draft) => draft.copyWith(
                                  notifications: draft.notifications.copyWith(
                                    preferencesConfirmed: true,
                                  ),
                                  clearFinalPreview: true,
                                ),
                              );
                          ref
                              .read(onboardingStateProvider.notifier)
                              .setStepDirty(
                                OnboardingStepId.notifications.index,
                                true,
                              );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (notifications.preferencesConfirmed &&
                    !notifications.osPermissionGranted)
                  OnboardingGlassCard(
                    tint: OptivusColors.aquaAccent.withValues(alpha: 0.12),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.notifications_active_rounded,
                          size: 42,
                          color: OptivusColors.aquaAccent,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '"Optivus" Would Like to Send You Notifications',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Notifications may include alerts, sounds and icon badges. These can be configured in Settings.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: OptivusColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  ref
                                      .read(onboardingStateProvider.notifier)
                                      .updateDraft(
                                        (draft) => draft.copyWith(
                                          notifications: draft.notifications
                                              .copyWith(
                                                osPermissionGranted: false,
                                              ),
                                          clearFinalPreview: true,
                                        ),
                                      );
                                  ref
                                      .read(onboardingStateProvider.notifier)
                                      .setStepDirty(
                                        OnboardingStepId.notifications.index,
                                        true,
                                      );
                                },
                                child: const Text(
                                  'Don\'t Allow',
                                  style: TextStyle(
                                    color: OptivusColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  ref
                                      .read(onboardingStateProvider.notifier)
                                      .updateDraft(
                                        (draft) => draft.copyWith(
                                          notifications: draft.notifications
                                              .copyWith(
                                                osPermissionGranted: true,
                                              ),
                                          clearFinalPreview: true,
                                        ),
                                      );
                                  ref
                                      .read(onboardingStateProvider.notifier)
                                      .setStepDirty(
                                        OnboardingStepId.notifications.index,
                                        true,
                                      );
                                },
                                child: const Text(
                                  'Allow',
                                  style: TextStyle(
                                    color: OptivusColors.aquaAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (notifications.preferencesConfirmed &&
                    notifications.osPermissionGranted)
                  OnboardingGlassCard(
                    tint: OptivusColors.success.withValues(alpha: 0.08),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: OptivusColors.success,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Notification preference recorded. Real OS permission will be requested in the app shell.',
                            style: TextStyle(
                              fontSize: 12,
                              color: OptivusColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ), // end OnboardingScrollView inner Column
          ), // end OnboardingScrollView
        ), // end Expanded
      ], // end outer Column children
    );
  }
}
