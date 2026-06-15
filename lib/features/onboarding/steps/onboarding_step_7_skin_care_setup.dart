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
    final hasActivePath =
        base.skinCareSetupPath == 'has_products' ||
        base.skinCareSetupPath == 'no_products' ||
        base.skinCareSetupPath == 'skip' ||
        base.skinCareSkipped;
    final isChoice = base.skinCareSetupStep <= 0 || !hasActivePath;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SkinCareHeader(),
          const SizedBox(height: 18),
          Expanded(
            child: isChoice
                ? _SkinCareChoiceScreen(base: base)
                : _SkinCareSelectedModeScreen(base: base),
          ),
        ],
      ),
    );
  }
}

class _SkinCareHeader extends StatelessWidget {
  const _SkinCareHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Skin Care',
          style: TextStyle(
            fontSize: 26,
            height: 1.05,
            fontWeight: FontWeight.w900,
            color: OptivusColors.textPrimary,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Face and skin routine setup.',
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w700,
            color: OptivusColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SkinCareChoiceScreen extends ConsumerWidget {
  final BaseTimelineDraft base;

  const _SkinCareChoiceScreen({required this.base});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void select(String value) {
      ref.read(mockOnboardingProvider.notifier).clearValidation();
      updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) {
        final isSkip = value == 'skip';
        final switchedPath = base.skinCareSetupPath != value;
        final blocks = switchedPath && !isSkip
            ? base.blocks.where((b) => b.section != 'skin_care').toList()
            : base.blocks;
        return base.copyWith(
          blocks: blocks,
          skinCareSetupPath: value,
          skinCareSetupStep: 0,
          skinCareSkipped: isSkip,
        );
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SkinCarePathCard(
          title: 'I have products',
          subtitle: 'Type product names to build a routine.',
          icon: Icons.spa_rounded,
          accent: OptivusColors.roseAccent,
          selected:
              base.skinCareSetupPath == 'has_products' && !base.skinCareSkipped,
          onTap: () => select('has_products'),
        ),
        const SizedBox(height: 12),
        _SkinCarePathCard(
          title: 'Build routine for me',
          subtitle: 'Answer skin details to generate a routine.',
          icon: Icons.face_retouching_natural_rounded,
          accent: OptivusColors.purpleAccent,
          selected:
              base.skinCareSetupPath == 'no_products' && !base.skinCareSkipped,
          onTap: () => select('no_products'),
        ),
        const SizedBox(height: 12),
        _SkinCarePathCard(
          title: 'Skip',
          subtitle: 'Skin care will be skipped for now.',
          icon: Icons.skip_next_rounded,
          accent: OptivusColors.textSecondary,
          selected: base.skinCareSetupPath == 'skip' || base.skinCareSkipped,
          onTap: () => select('skip'),
        ),
      ],
    );
  }
}

class _SkinCarePathCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _SkinCarePathCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: OnboardingGlassCard(
        padding: const EdgeInsets.all(14),
        radius: 18,
        tint: selected
            ? accent.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.08),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: selected
                    ? accent.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.48),
                border: Border.all(
                  color: selected
                      ? accent.withValues(alpha: 0.62)
                      : Colors.white.withValues(alpha: 0.72),
                ),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkinCareSelectedModeScreen extends ConsumerWidget {
  final BaseTimelineDraft base;

  const _SkinCareSelectedModeScreen({required this.base});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (base.skinCareSkipped || base.skinCareSetupPath == 'skip') {
      return const _SkipModeScreen();
    }

    final blocks = base.confirmedBlocksForSection('skin_care');

    if (base.skinCareSetupPath == 'has_products') {
      return _HasProductsModeScreen(base: base, blocks: blocks);
    }

    return _NoProductsModeScreen(base: base, blocks: blocks);
  }
}

class _SkipModeScreen extends StatelessWidget {
  const _SkipModeScreen();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnboardingGlassCard(
          tint: OptivusColors.textSecondary.withValues(alpha: 0.08),
          child: const Row(
            children: [
              Icon(Icons.skip_next_rounded, color: OptivusColors.textSecondary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Skin care will be skipped for now.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HasProductsModeScreen extends ConsumerStatefulWidget {
  final BaseTimelineDraft base;
  final List<TimelineBlockDraft> blocks;

  const _HasProductsModeScreen({required this.base, required this.blocks});

  @override
  ConsumerState<_HasProductsModeScreen> createState() =>
      _HasProductsModeScreenState();
}

class _HasProductsModeScreenState
    extends ConsumerState<_HasProductsModeScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.base.skinCareProductNames);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final generated = widget.blocks.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnboardingGlassCard(
          tint: OptivusColors.roseAccent.withValues(alpha: 0.06),
          padding: const EdgeInsets.all(12),
          radius: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'I have products',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              OnboardingTextInputCard(
                controller: _controller,
                title: 'Product names',
                hint: 'Cleanser, moisturizer, sunscreen...',
                accent: OptivusColors.roseAccent,
                minLines: 2,
                onChanged: (value) => updateBaseTimelineDraft(
                  ref,
                  onboardingSkinCareStepIndex,
                  (base) => base.copyWith(skinCareProductNames: value),
                ),
              ),
              const SizedBox(height: 12),
              OnboardingActionPill(
                label: 'Build skin routine',
                icon: Icons.auto_awesome_rounded,
                accent: OptivusColors.roseAccent,
                selected: true,
                onTap: () => _buildRoutine(ref, widget.base),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (generated)
          _SkinCareGeneratedSummaryRow(
            blocks: widget.blocks,
            accent: OptivusColors.roseAccent,
          )
        else
          const Spacer(),
      ],
    );
  }

  void _buildRoutine(WidgetRef ref, BaseTimelineDraft sourceBase) {
    ref.read(mockOnboardingProvider.notifier).clearValidation();
    updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) {
      final newBlocks = generatedSkinCareBlocks(
        sourceBase.copyWith(skinCareProductNames: _controller.text),
        DateTime.now(),
      );
      final nextBlocks =
          base.blocks.where((b) => b.section != 'skin_care').toList()
            ..addAll(newBlocks);
      return base.copyWith(
        blocks: nextBlocks,
        skinCareProductNames: _controller.text,
        skinCareSkipped: false,
      );
    });
  }
}

class _NoProductsModeScreen extends ConsumerWidget {
  final BaseTimelineDraft base;
  final List<TimelineBlockDraft> blocks;

  const _NoProductsModeScreen({required this.base, required this.blocks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final generated = blocks.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: OnboardingGlassCard(
            tint: OptivusColors.purpleAccent.withValues(alpha: 0.06),
            padding: const EdgeInsets.all(12),
            radius: 18,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Build routine for me',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  _SkinCareChipGroup(
                    label: 'Skin Type',
                    children: [
                      for (final option in const [
                        _SkinOption('oily', 'Oily'),
                        _SkinOption('dry', 'Dry'),
                        _SkinOption('combination', 'Combination'),
                        _SkinOption('not_sure', 'Not sure'),
                      ])
                        _SkinCarePreferenceChip(
                          label: option.label,
                          selected: base.skinCareSkinType == option.key,
                          accent: OptivusColors.purpleAccent,
                          onTap: () => updateBaseTimelineDraft(
                            ref,
                            onboardingSkinCareStepIndex,
                            (base) => base.copyWith(
                              skinCareSkinType: option.key,
                              skinCareSkipped: false,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _SkinCareChipGroup(
                    label: 'Concerns',
                    children: [
                      for (final option in const [
                        _SkinOption('pimples', 'Acne'),
                        _SkinOption('dark_spots', 'Spots'),
                        _SkinOption('tan', 'Tan'),
                        _SkinOption('dryness', 'Dryness'),
                        _SkinOption('oiliness', 'Oiliness'),
                        _SkinOption('none', 'None'),
                      ])
                        _SkinCarePreferenceChip(
                          label: option.label,
                          selected: base.skinCareProblems.contains(option.key),
                          accent: OptivusColors.purpleAccent,
                          onTap: () {
                            final next = {...base.skinCareProblems};
                            if (option.key == 'none') {
                              next
                                ..clear()
                                ..add('none');
                            } else {
                              next.remove('none');
                              next.contains(option.key)
                                  ? next.remove(option.key)
                                  : next.add(option.key);
                            }
                            updateBaseTimelineDraft(
                              ref,
                              onboardingSkinCareStepIndex,
                              (base) => base.copyWith(
                                skinCareProblems: next.toList(),
                                skinCareSkipped: false,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _SkinCareChipGroup(
                    label: 'Budget',
                    children: [
                      for (final option in const [
                        _SkinOption('low', 'Low'),
                        _SkinOption('medium', 'Medium'),
                        _SkinOption('high', 'High'),
                      ])
                        _SkinCarePreferenceChip(
                          label: option.label,
                          selected: base.skinCareBudget == option.key,
                          accent: OptivusColors.purpleAccent,
                          onTap: () => updateBaseTimelineDraft(
                            ref,
                            onboardingSkinCareStepIndex,
                            (base) => base.copyWith(
                              skinCareBudget: option.key,
                              skinCareSkipped: false,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _SkinCareChipGroup(
                    label: 'Preference',
                    children: [
                      for (final option in const [
                        _SkinOption('simple', 'Simple'),
                        _SkinOption('minimal', 'Minimal'),
                        _SkinOption('advanced', 'Advanced'),
                      ])
                        _SkinCarePreferenceChip(
                          label: option.label,
                          selected: base.skinCarePreference == option.key,
                          accent: OptivusColors.purpleAccent,
                          onTap: () => updateBaseTimelineDraft(
                            ref,
                            onboardingSkinCareStepIndex,
                            (base) => base.copyWith(
                              skinCarePreference: option.key,
                              skinCareSkipped: false,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OnboardingActionPill(
                    label: 'Build skin routine',
                    icon: Icons.auto_awesome_rounded,
                    accent: OptivusColors.purpleAccent,
                    selected: true,
                    onTap: () {
                      ref
                          .read(mockOnboardingProvider.notifier)
                          .clearValidation();
                      final newBlocks = generatedSkinCareBlocks(
                        base,
                        DateTime.now(),
                      );
                      updateBaseTimelineDraft(
                        ref,
                        onboardingSkinCareStepIndex,
                        (base) {
                          final nextBlocks =
                              base.blocks
                                  .where((b) => b.section != 'skin_care')
                                  .toList()
                                ..addAll(newBlocks);
                          return base.copyWith(
                            blocks: nextBlocks,
                            skinCareSkipped: false,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (generated)
          _SkinCareGeneratedSummaryRow(
            blocks: blocks,
            accent: OptivusColors.purpleAccent,
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }
}

class _SkinCareGeneratedSummaryRow extends ConsumerWidget {
  final List<TimelineBlockDraft> blocks;
  final Color accent;

  const _SkinCareGeneratedSummaryRow({
    required this.blocks,
    required this.accent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnboardingGlassCard(
            tint: accent.withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            radius: 20,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Routine built',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ),
                OnboardingActionPill(
                  label: 'Rebuild',
                  icon: Icons.refresh_rounded,
                  accent: accent,
                  compact: true,
                  onTap: () => updateBaseTimelineDraft(
                    ref,
                    onboardingSkinCareStepIndex,
                    (base) => base.copyWith(
                      blocks: base.blocks
                          .where((b) => b.section != 'skin_care')
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: OnboardingMiniBlockList(
                title: 'Skin care routine',
                blocks: blocks,
                accent: accent,
                emptyLabel: 'No blocks generated.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkinCareChipGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _SkinCareChipGroup({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: OptivusColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}

class _SkinCarePreferenceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _SkinCarePreferenceChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? accent
                : OptivusColors.textSecondary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            color: selected ? Colors.white : OptivusColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _SkinOption {
  final String key;
  final String label;

  const _SkinOption(this.key, this.label);
}
