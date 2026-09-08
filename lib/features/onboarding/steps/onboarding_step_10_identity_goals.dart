import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_spacing.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/onboarding/onboarding_step_id.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/state/app_state.dart';

class OnboardingIdentityGoalsStep extends ConsumerStatefulWidget {
  const OnboardingIdentityGoalsStep({super.key});

  @override
  ConsumerState<OnboardingIdentityGoalsStep> createState() =>
      _OnboardingIdentityGoalsStepState();
}

class _OnboardingIdentityGoalsStepState
    extends ConsumerState<OnboardingIdentityGoalsStep> {
  final List<_IdentityGoal> _goals = [
    _IdentityGoal(
      'financially_free',
      'Financially Free',
      Icons.savings_rounded,
      'Money tracking + savings proof',
      const ['save_10_day', 'bad_habit_money_saved', 'weekly_money_review'],
    ),
    _IdentityGoal(
      'strong_body',
      'Strong Body',
      Icons.fitness_center_rounded,
      'Gym + protein + sleep',
      const ['workout', 'sleep_routine', 'protein_meal_reminder'],
    ),
    _IdentityGoal(
      'become_disciplined',
      'Become Disciplined',
      Icons.flag_rounded,
      'Routine anchors + slip-up recovery',
      const [
        'non_negotiable_task',
        'wake_sleep_consistency',
        'daily_completion_score',
      ],
    ),
    _IdentityGoal(
      'new_language',
      'New Language',
      Icons.translate_rounded,
      'Language practice block',
      const ['five_words_daily', 'language_practice', 'weekly_revision'],
    ),
    _IdentityGoal(
      'start_business',
      'Start Business',
      Icons.storefront_rounded,
      'Deep work + finance systems',
      const ['business_work', 'weekly_planning', 'project_tracker'],
    ),
    _IdentityGoal(
      'inner_peace',
      'Inner Peace',
      Icons.self_improvement_rounded,
      'Meditation + journaling',
      const ['meditation', 'journaling', 'doom_scrolling_control'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    final selected = ref
        .read(mockOnboardingProvider)
        .draft
        .identityGoals
        .map((goal) => goal.goalKey)
        .toSet();
    for (final goal in _goals) {
      goal.selected = selected.contains(goal.key);
    }
  }

  void _syncDraft() {
    final selected = _goals
        .where((goal) => goal.selected)
        .map(
          (goal) => IdentityGoalDraft(
            goalKey: goal.key,
            displayName: goal.title,
            systemKeys: goal.systemKeys,
          ),
        )
        .toList();
    ref
        .read(mockOnboardingProvider.notifier)
        .updateDraft(
          (draft) =>
              draft.copyWith(identityGoals: selected, clearFinalPreview: true),
        );
    ref
        .read(mockOnboardingProvider.notifier)
        .setStepDirty(OnboardingStepId.identityGoals.index, true);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _goals.where((goal) => goal.selected).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: OptivusSpacing.onboardingHeaderPadding,
          child: OnboardingSectionTitle(
            title: 'Long-Term Identity Goals',
            subtitle:
                'Choose identity outcomes. Optivus maps them into duplicate-safe systems.',
          ),
        ),
        Expanded(
          child: OnboardingScrollView(
            padding: OptivusSpacing.onboardingContentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._goals.map((goal) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OnboardingChoiceTile(
                      title: goal.title,
                      subtitle: goal.system,
                      icon: goal.icon,
                      selected: goal.selected,
                      onTap: () {
                        setState(() => goal.selected = !goal.selected);
                        _syncDraft();
                      },
                      expandedContent: goal.selected
                          ? Consumer(
                              builder: (context, ref, _) {
                                final skipped = ref
                                    .watch(mockOnboardingProvider)
                                    .draft
                                    .skippedDuplicateSystemKeys();
                                final isDuplicate = goal.systemKeys.any(
                                  (key) => skipped.contains(key),
                                );
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OnboardingChip(
                                      label: 'Mapped system',
                                      selected: true,
                                    ),
                                    if (isDuplicate)
                                      const OnboardingChip(
                                        label: 'Duplicate prevention active',
                                        selected: true,
                                        accent: OptivusColors.aquaAccent,
                                      ),
                                    ...goal.systemKeys
                                        .take(2)
                                        .map(
                                          (key) => OnboardingChip(
                                            label: identitySystemTitle(key),
                                            selected: true,
                                            accent: skipped.contains(key)
                                                ? OptivusColors.textSecondary
                                                : OptivusColors.success,
                                          ),
                                        ),
                                  ],
                                );
                              },
                            )
                          : null,
                    ),
                  );
                }),
                OnboardingGlassCard(
                  tint: OptivusColors.aquaAccent.withValues(alpha: 0.08),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mapped systems preview',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        selected.isEmpty
                            ? 'No identity systems selected yet.'
                            : selected
                                  .map(
                                    (goal) => '${goal.title}: ${goal.system}',
                                  )
                                  .join('\n'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: OptivusColors.textSecondary,
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

class _IdentityGoal {
  final String key;
  final String title;
  final IconData icon;
  final String system;
  final List<String> systemKeys;
  bool selected;

  _IdentityGoal(this.key, this.title, this.icon, this.system, this.systemKeys)
    : selected = false;
}
