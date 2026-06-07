import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/state/app_state.dart';

class OnboardingStep7 extends ConsumerWidget {
  const OnboardingStep7({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(mockOnboardingProvider).draft.baseTimeline;
    final blocks = base.confirmedBlocksForSection('skin_care');

    return OnboardingStepBody(
      title: 'Skin Care Setup',
      subtitle: 'Optional routine setup. Skip now or build a simple system.',
      accent: const Color(0xFF63B885),
      children: [
        if (base.skinCareSkipped)
          const _SkippedCard()
        else if (base.skinCareSetupStep == 0)
          _SkinPathQuestion(base: base)
        else if (base.skinCareSetupPath == 'has_products')
          _HasProductsPath(step: base.skinCareSetupStep, blocks: blocks)
        else
          _NoProductsPath(
            step: base.skinCareSetupStep,
            base: base,
            blocks: blocks,
          ),
      ],
    );
  }
}

class _SkinPathQuestion extends ConsumerWidget {
  final BaseTimelineDraft base;

  const _SkinPathQuestion({required this.base});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void select(String path) {
      updateBaseTimelineDraft(
        ref,
        onboardingSkinCareStepIndex,
        (base) => base.copyWith(
          skinCareSetupPath: path,
          skinCareSetupStep: 0,
          skinCareSkipped: false,
          clearSkinCarePlanning: path == 'has_products' ? false : false,
        ),
      );
    }

    return Column(
      children: [
        OnboardingChoiceTile(
          title: 'Yes, I have products',
          subtitle: 'Upload product photo or type names, then review routine.',
          icon: Icons.spa_rounded,
          selected: base.skinCareSetupPath == 'has_products',
          accent: const Color(0xFF63B885),
          onTap: () => select('has_products'),
        ),
        const SizedBox(height: 12),
        OnboardingChoiceTile(
          title: 'No',
          subtitle: 'Answer skin type, concerns, budget, and preference.',
          icon: Icons.face_retouching_natural_rounded,
          selected: base.skinCareSetupPath == 'no_products',
          accent: OptivusColors.brandAccent,
          onTap: () => select('no_products'),
        ),
        const SizedBox(height: 12),
        OnboardingChoiceTile(
          title: 'Skip skin care',
          subtitle: 'Skin care is optional and can be set later.',
          icon: Icons.skip_next_rounded,
          selected: false,
          accent: OptivusColors.success,
          onTap: () => updateBaseTimelineDraft(
            ref,
            onboardingSkinCareStepIndex,
            (base) =>
                base.copyWith(skinCareSkipped: true, skinCareSetupStep: 7),
          ),
        ),
      ],
    );
  }
}

class _HasProductsPath extends StatelessWidget {
  final int step;
  final List<TimelineBlockDraft> blocks;

  const _HasProductsPath({required this.step, required this.blocks});

  @override
  Widget build(BuildContext context) {
    if (step <= 1) return const _ProductInputStage();
    if (step == 2) return _SkinReview(blocks: blocks);
    return _SkinSummary(blocks: blocks);
  }
}

class _NoProductsPath extends StatelessWidget {
  final int step;
  final BaseTimelineDraft base;
  final List<TimelineBlockDraft> blocks;

  const _NoProductsPath({
    required this.step,
    required this.base,
    required this.blocks,
  });

  @override
  Widget build(BuildContext context) {
    if (step <= 1) return _FacePhotoStage(base: base);
    if (step == 2) return _SkinTypeStage(base: base);
    if (step == 3) return _ProblemsStage(base: base);
    if (step == 4) return _BudgetStage(base: base);
    if (step == 5) return _PreferenceStage(base: base);
    if (step == 6) return _SkinReview(blocks: blocks);
    return _SkinSummary(blocks: blocks);
  }
}

class _ProductInputStage extends ConsumerStatefulWidget {
  const _ProductInputStage();

  @override
  ConsumerState<_ProductInputStage> createState() => _ProductInputStageState();
}

class _ProductInputStageState extends ConsumerState<_ProductInputStage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref
          .read(mockOnboardingProvider)
          .draft
          .baseTimeline
          .skinCareProductNames,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const OnboardingUploadReviewCard(
          sectionLabel: onboardingSectionSkinCare,
          title: 'Upload product photo',
          subtitle:
              'Use this if product names are visible. You can also type names below.',
          stepIndex: onboardingSkinCareStepIndex,
          accent: Color(0xFF63B885),
        ),
        const SizedBox(height: 12),
        OnboardingTextInputCard(
          controller: _controller,
          title: 'Or write product names',
          hint: 'Cleanser, moisturizer, sunscreen, serum...',
          accent: const Color(0xFF63B885),
          minLines: 3,
          onChanged: (value) => updateBaseTimelineDraft(
            ref,
            onboardingSkinCareStepIndex,
            (base) => base.copyWith(skinCareProductNames: value),
          ),
        ),
      ],
    );
  }
}

class _FacePhotoStage extends ConsumerWidget {
  final BaseTimelineDraft base;

  const _FacePhotoStage({required this.base});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        OnboardingGlassCard(
          tint: const Color(0xFFE9F8DA).withValues(alpha: 0.36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Face photo',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Optional. You can skip photo and use typed skin details.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OnboardingActionPill(
                    label: base.skinCareFacePhotoSkipped
                        ? 'Photo skipped'
                        : 'Skip photo',
                    icon: Icons.visibility_off_rounded,
                    accent: OptivusColors.success,
                    selected: base.skinCareFacePhotoSkipped,
                    compact: true,
                    onTap: () => updateBaseTimelineDraft(
                      ref,
                      onboardingSkinCareStepIndex,
                      (base) => base.copyWith(skinCareFacePhotoSkipped: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const OnboardingUploadReviewCard(
          sectionLabel: onboardingSectionSkinCare,
          title: 'Optional photo upload',
          subtitle:
              'If you upload, review will still be required before blocks are saved.',
          stepIndex: onboardingSkinCareStepIndex,
          accent: Color(0xFF63B885),
        ),
      ],
    );
  }
}

class _SkinTypeStage extends ConsumerWidget {
  final BaseTimelineDraft base;

  const _SkinTypeStage({required this.base});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SkinChipCard(
      title: 'Skin type',
      children:
          const [
                _Option('oily', 'Oily'),
                _Option('dry', 'Dry'),
                _Option('combination', 'Combination'),
                _Option('not_sure', 'Not sure'),
              ]
              .map(
                (option) => OnboardingChip(
                  label: option.label,
                  selected: base.skinCareSkinType == option.key,
                  accent: const Color(0xFF63B885),
                  onTap: () => updateBaseTimelineDraft(
                    ref,
                    onboardingSkinCareStepIndex,
                    (base) => base.copyWith(skinCareSkinType: option.key),
                  ),
                ),
              )
              .toList(),
    );
  }
}

class _ProblemsStage extends ConsumerWidget {
  final BaseTimelineDraft base;

  const _ProblemsStage({required this.base});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const problems = [
      _Option('pimples', 'Pimples/acne'),
      _Option('dark_spots', 'Dark spots'),
      _Option('tan', 'Tan'),
      _Option('dryness', 'Dryness'),
      _Option('oiliness', 'Oiliness'),
      _Option('none', 'None'),
    ];
    return _SkinChipCard(
      title: 'Problems',
      children: problems
          .map(
            (problem) => OnboardingChip(
              label: problem.label,
              selected: base.skinCareProblems.contains(problem.key),
              accent: const Color(0xFF63B885),
              onTap: () {
                final next = {...base.skinCareProblems};
                if (problem.key == 'none') {
                  next
                    ..clear()
                    ..add('none');
                } else {
                  next.remove('none');
                  next.contains(problem.key)
                      ? next.remove(problem.key)
                      : next.add(problem.key);
                }
                updateBaseTimelineDraft(
                  ref,
                  onboardingSkinCareStepIndex,
                  (base) => base.copyWith(skinCareProblems: next.toList()),
                );
              },
            ),
          )
          .toList(),
    );
  }
}

class _BudgetStage extends ConsumerWidget {
  final BaseTimelineDraft base;

  const _BudgetStage({required this.base});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SkinChipCard(
      title: 'Budget',
      children:
          const [
                _Option('low', 'Low'),
                _Option('medium', 'Medium'),
                _Option('high', 'High'),
              ]
              .map(
                (option) => OnboardingChip(
                  label: option.label,
                  selected: base.skinCareBudget == option.key,
                  accent: const Color(0xFF63B885),
                  onTap: () => updateBaseTimelineDraft(
                    ref,
                    onboardingSkinCareStepIndex,
                    (base) => base.copyWith(skinCareBudget: option.key),
                  ),
                ),
              )
              .toList(),
    );
  }
}

class _PreferenceStage extends ConsumerWidget {
  final BaseTimelineDraft base;

  const _PreferenceStage({required this.base});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _SkinChipCard(
          title: 'Preference',
          children:
              const [
                    _Option('simple', 'Simple'),
                    _Option('minimal', 'Minimal'),
                    _Option('advanced', 'Advanced'),
                  ]
                  .map(
                    (option) => OnboardingChip(
                      label: option.label,
                      selected: base.skinCarePreference == option.key,
                      accent: const Color(0xFF63B885),
                      onTap: () => updateBaseTimelineDraft(
                        ref,
                        onboardingSkinCareStepIndex,
                        (base) => base.copyWith(skinCarePreference: option.key),
                      ),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 12),
        OnboardingGlassCard(
          tint: const Color(0xFFE9F8DA).withValues(alpha: 0.36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Suggested set',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                _suggestedSet(base).join('\n'),
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
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
}

class _SkinReview extends StatelessWidget {
  final List<TimelineBlockDraft> blocks;

  const _SkinReview({required this.blocks});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OnboardingGlassCard(
          tint: const Color(0xFFE9F8DA).withValues(alpha: 0.42),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Review skin care routine',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                blocks.isEmpty
                    ? 'Open review, approve/edit routine blocks, then apply.'
                    : 'Skin care blocks are saved from review.',
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
                accent: const Color(0xFF63B885),
                selected: true,
                onTap: () => openOnboardingImportReview(
                  context,
                  source: onboardingImportSourceForSection(
                    onboardingSectionSkinCare,
                  ),
                  autoRunAiOnLoad: false,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DayHintReview(blocks: blocks),
      ],
    );
  }
}

class _SkinSummary extends StatelessWidget {
  final List<TimelineBlockDraft> blocks;

  const _SkinSummary({required this.blocks});

  @override
  Widget build(BuildContext context) {
    return _DayHintReview(blocks: blocks);
  }
}

class _SkippedCard extends StatelessWidget {
  const _SkippedCard();

  @override
  Widget build(BuildContext context) {
    return OnboardingGlassCard(
      tint: OptivusColors.success.withValues(alpha: 0.08),
      child: const Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: OptivusColors.success,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Skin care skipped for now.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: OptivusColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHintReview extends StatelessWidget {
  final List<TimelineBlockDraft> blocks;

  const _DayHintReview({required this.blocks});

  @override
  Widget build(BuildContext context) {
    return OnboardingMiniBlockList(
      title: 'Skin care blocks',
      blocks: blocks,
      accent: const Color(0xFF63B885),
      emptyLabel: 'No skin care blocks applied yet.',
    );
  }
}

class _SkinChipCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SkinChipCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return OnboardingGlassCard(
      tint: const Color(0xFFE9F8DA).withValues(alpha: 0.38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

List<String> _suggestedSet(BaseTimelineDraft base) {
  final simple =
      base.skinCarePreference == 'simple' ||
      base.skinCarePreference == 'minimal';
  return [
    'Gentle cleanser',
    'Light moisturizer',
    'Sunscreen SPF 30',
    if (!simple && base.skinCareProblems.contains('pimples'))
      'Acne spot treatment',
    if (!simple && base.skinCareProblems.contains('dark_spots'))
      'Dark spot serum',
  ];
}

class _Option {
  final String key;
  final String label;

  const _Option(this.key, this.label);
}
