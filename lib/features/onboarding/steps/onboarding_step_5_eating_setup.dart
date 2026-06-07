import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/state/app_state.dart';

class OnboardingStep5 extends ConsumerWidget {
  const OnboardingStep5({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(mockOnboardingProvider).draft;
    final base = draft.baseTimeline;
    final path = base.eatingSetupPath;
    final blocks = base.confirmedBlocksForSection('eating');

    return OnboardingStepBody(
      title: 'Eating Setup',
      subtitle: 'Build a meal system from your menu or from body basics.',
      accent: OptivusColors.success,
      children: [
        if (base.eatingSetupStep == 0)
          _PathQuestion(path: path)
        else if (path == 'has_routine')
          _ExistingRoutineStep(step: base.eatingSetupStep, blocks: blocks)
        else
          _CreateRoutineStep(
            step: base.eatingSetupStep,
            base: base,
            blocks: blocks,
          ),
      ],
    );
  }
}

class _PathQuestion extends ConsumerWidget {
  final String? path;

  const _PathQuestion({required this.path});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void select(String value) {
      updateBaseTimelineDraft(
        ref,
        onboardingEatingStepIndex,
        (base) => base.copyWith(
          eatingSetupPath: value,
          eatingSetupStep: 0,
          clearMealPlanning: value == 'has_routine',
        ),
      );
    }

    return Column(
      children: [
        OnboardingChoiceTile(
          title: 'Yes, I have a routine/menu',
          subtitle: 'Upload it, review the AI draft, then apply meals.',
          icon: Icons.document_scanner_rounded,
          selected: path == 'has_routine',
          accent: OptivusColors.success,
          onTap: () => select('has_routine'),
        ),
        const SizedBox(height: 12),
        OnboardingChoiceTile(
          title: 'No, help me create one',
          subtitle:
              'Use body basics, exercise level, goal, and eating situation.',
          icon: Icons.auto_awesome_rounded,
          selected: path == 'create',
          accent: OptivusColors.brandAccent,
          onTap: () => select('create'),
        ),
      ],
    );
  }
}

class _ExistingRoutineStep extends StatelessWidget {
  final int step;
  final List<TimelineBlockDraft> blocks;

  const _ExistingRoutineStep({required this.step, required this.blocks});

  @override
  Widget build(BuildContext context) {
    if (step <= 1) {
      return const OnboardingUploadReviewCard(
        sectionLabel: onboardingSectionEating,
        title: 'Upload routine or menu',
        subtitle:
            'Use a clear photo of meal timings, mess menu, hostel menu, or home routine.',
        stepIndex: onboardingEatingStepIndex,
        accent: OptivusColors.success,
      );
    }
    if (step == 2) {
      return _EatingReview(blocks: blocks);
    }
    return _EatingSummary(blocks: blocks);
  }
}

class _CreateRoutineStep extends ConsumerWidget {
  final int step;
  final BaseTimelineDraft base;
  final List<TimelineBlockDraft> blocks;

  const _CreateRoutineStep({
    required this.step,
    required this.base,
    required this.blocks,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (step <= 1) return _GoalQuestion(base: base);
    if (step == 2) return _SituationQuestion(base: base);
    if (step == 3) return _DetailsQuestion(base: base);
    if (step == 4) return _EatingReview(blocks: blocks);
    return _EatingSummary(blocks: blocks);
  }
}

class _GoalQuestion extends ConsumerWidget {
  final BaseTimelineDraft base;

  const _GoalQuestion({required this.base});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const goals = [
      _Option('gain_weight', 'Gain weight'),
      _Option('build_muscle', 'Build muscle'),
      _Option('lose_fat', 'Lose fat'),
      _Option('maintain', 'Maintain'),
      _Option('eat_healthier', 'Eat healthier'),
    ];
    return _ChipCard(
      title: 'Goal',
      subtitle: 'This shapes calories, protein, and meal emphasis.',
      children: goals
          .map(
            (goal) => OnboardingChip(
              label: goal.label,
              selected: base.mealPlanningGoal == goal.key,
              accent: OptivusColors.success,
              onTap: () => updateBaseTimelineDraft(
                ref,
                onboardingEatingStepIndex,
                (base) => base.copyWith(mealPlanningGoal: goal.key),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SituationQuestion extends ConsumerWidget {
  final BaseTimelineDraft base;

  const _SituationQuestion({required this.base});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const situations = [
      _Option('home', 'Home'),
      _Option('hostel_mess_pg', 'Hostel/Mess/PG'),
      _Option('self_cook', 'Self cook'),
      _Option('mixed', 'Mixed'),
    ];
    return _ChipCard(
      title: 'Eating situation',
      subtitle: 'Optivus uses this to keep the routine realistic.',
      children: situations
          .map(
            (situation) => OnboardingChip(
              label: situation.label,
              selected: base.eatingMode == situation.key,
              accent: OptivusColors.success,
              onTap: () => updateBaseTimelineDraft(
                ref,
                onboardingEatingStepIndex,
                (base) => base.copyWith(eatingMode: situation.key),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DetailsQuestion extends ConsumerWidget {
  final BaseTimelineDraft base;

  const _DetailsQuestion({required this.base});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selfCook = base.eatingMode == 'self_cook';
    if (selfCook) {
      return Column(
        children: [
          _ChipCard(
            title: 'Food preference',
            subtitle: 'Choose the base preference for generated meals.',
            children:
                const [
                      _Option('veg', 'Veg'),
                      _Option('egg', 'Egg'),
                      _Option('non_veg', 'Non-veg'),
                    ]
                    .map(
                      (option) => OnboardingChip(
                        label: option.label,
                        selected: base.foodType == option.key,
                        accent: OptivusColors.success,
                        onTap: () => updateBaseTimelineDraft(
                          ref,
                          onboardingEatingStepIndex,
                          (base) => base.copyWith(foodType: option.key),
                        ),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 12),
          _ChipCard(
            title: 'Budget',
            subtitle: 'Keep the routine within your daily context.',
            children:
                const [
                      _Option('low', 'Low'),
                      _Option('medium', 'Medium'),
                      _Option('high', 'High'),
                    ]
                    .map(
                      (option) => OnboardingChip(
                        label: option.label,
                        selected: base.mealBudget == option.key,
                        accent: OptivusColors.success,
                        onTap: () => updateBaseTimelineDraft(
                          ref,
                          onboardingEatingStepIndex,
                          (base) => base.copyWith(mealBudget: option.key),
                        ),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 12),
          _ChipCard(
            title: 'Cooking skill',
            subtitle: 'Beginner routines avoid complicated prep.',
            children:
                const [
                      _Option('beginner', 'Beginner'),
                      _Option('normal', 'Normal'),
                      _Option('advanced', 'Advanced'),
                    ]
                    .map(
                      (option) => OnboardingChip(
                        label: option.label,
                        selected: base.cookingAbility == option.key,
                        accent: OptivusColors.success,
                        onTap: () => updateBaseTimelineDraft(
                          ref,
                          onboardingEatingStepIndex,
                          (base) => base.copyWith(cookingAbility: option.key),
                        ),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 12),
          _ChipCard(
            title: 'Meals per day',
            subtitle: 'Optivus will create the review draft from this.',
            children:
                const [
                      _Option('2', '2'),
                      _Option('3', '3'),
                      _Option('4', '4'),
                      _Option('5', '5'),
                    ]
                    .map(
                      (option) => OnboardingChip(
                        label: option.label,
                        selected: base.mealsPerDay?.toString() == option.key,
                        accent: OptivusColors.success,
                        onTap: () => updateBaseTimelineDraft(
                          ref,
                          onboardingEatingStepIndex,
                          (base) => base.copyWith(
                            mealsPerDay: int.tryParse(option.key),
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],
      );
    }

    return Column(
      children: [
        OnboardingTimeTile(
          title: 'Breakfast time',
          subtitle: 'Set the usual first meal window.',
          minute: base.breakfastMinute ?? 8 * 60,
          icon: Icons.free_breakfast_rounded,
          accent: OptivusColors.success,
          onChanged: (value) => updateBaseTimelineDraft(
            ref,
            onboardingEatingStepIndex,
            (base) => base.copyWith(breakfastMinute: value),
          ),
        ),
        const SizedBox(height: 12),
        OnboardingTimeTile(
          title: 'Lunch time',
          subtitle: 'Set the usual midday meal window.',
          minute: base.lunchMinute ?? 13 * 60,
          icon: Icons.restaurant_rounded,
          accent: OptivusColors.success,
          onChanged: (value) => updateBaseTimelineDraft(
            ref,
            onboardingEatingStepIndex,
            (base) => base.copyWith(lunchMinute: value),
          ),
        ),
        const SizedBox(height: 12),
        OnboardingTimeTile(
          title: 'Dinner time',
          subtitle: 'Set the usual night meal window.',
          minute: base.dinnerMinute ?? 20 * 60,
          icon: Icons.dinner_dining_rounded,
          accent: OptivusColors.success,
          onChanged: (value) => updateBaseTimelineDraft(
            ref,
            onboardingEatingStepIndex,
            (base) => base.copyWith(dinnerMinute: value),
          ),
        ),
        const SizedBox(height: 12),
        OnboardingTimeTile(
          title: 'Optional snack',
          subtitle: 'Use this only if snacks are part of your routine.',
          minute: base.snackMinute ?? 17 * 60,
          icon: Icons.local_cafe_rounded,
          accent: OptivusColors.brandAccent,
          onChanged: (value) => updateBaseTimelineDraft(
            ref,
            onboardingEatingStepIndex,
            (base) => base.copyWith(snackMinute: value),
          ),
        ),
      ],
    );
  }
}

class _EatingReview extends StatelessWidget {
  final List<TimelineBlockDraft> blocks;

  const _EatingReview({required this.blocks});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OnboardingGlassCard(
          tint: OptivusColors.success.withValues(alpha: 0.08),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Review eating draft',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                blocks.isEmpty
                    ? 'Open review, approve/edit meals, then apply.'
                    : 'Eating blocks are saved from review.',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              OnboardingActionPill(
                label: blocks.isEmpty ? 'Open review' : 'Reopen review',
                icon: Icons.rate_review_rounded,
                accent: OptivusColors.success,
                selected: true,
                onTap: () => openOnboardingImportReview(
                  context,
                  source: onboardingImportSourceForSection(
                    onboardingSectionEating,
                  ),
                  autoRunAiOnLoad: false,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OnboardingMiniBlockList(
          title: 'Eating blocks',
          blocks: blocks,
          accent: OptivusColors.success,
          emptyLabel: 'No reviewed meal blocks yet.',
        ),
      ],
    );
  }
}

class _EatingSummary extends StatelessWidget {
  final List<TimelineBlockDraft> blocks;

  const _EatingSummary({required this.blocks});

  @override
  Widget build(BuildContext context) {
    return OnboardingMiniBlockList(
      title: 'Eating summary',
      blocks: blocks,
      accent: OptivusColors.success,
      emptyLabel: 'No eating blocks applied yet.',
    );
  }
}

class _ChipCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _ChipCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingGlassCard(
      tint: OptivusColors.success.withValues(alpha: 0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

class _Option {
  final String key;
  final String label;

  const _Option(this.key, this.label);
}
