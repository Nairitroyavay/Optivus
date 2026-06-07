import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/onboarding/steps/onboarding_class_setup_timeline.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/state/app_state.dart';

class OnboardingStep4 extends ConsumerWidget {
  const OnboardingStep4({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(mockOnboardingProvider).draft;
    final base = draft.baseTimeline;
    final role = draft.lifeRole.lifeRole;
    final classesRequired =
        role == LifeRoleDraft.studentKey ||
        role == LifeRoleDraft.studentWorkingKey;
    final workRequired =
        role == LifeRoleDraft.workingKey ||
        role == LifeRoleDraft.studentWorkingKey ||
        role == LifeRoleDraft.businessKey;
    final classBlocks = base.confirmedBlocksForSection('classes');
    final workBlocks = base.confirmedBlocksForSection('job_work_business');

    if (classesRequired && base.classJobSetupStep <= 2) {
      return OnboardingClassSetupWidget(stepIndex: onboardingClassJobStepIndex);
    }

    if (workRequired &&
        (!classesRequired ||
            (base.classJobSetupStep >= 3 && base.classJobSetupStep <= 4))) {
      return OnboardingClassSetupWidget.work(
        stepIndex: onboardingClassJobStepIndex,
      );
    }

    return OnboardingStepBody(
      title: 'Classes & Job',
      subtitle: 'Set the fixed responsibilities Optivus must protect.',
      accent: OptivusColors.aquaAccent,
      children: [
        if (base.classJobSetupStep <= 0)
          _IntroCard(
            classesRequired: classesRequired,
            workRequired: workRequired,
            role: role,
          )
        else
          _SummaryCard(
            classesRequired: classesRequired,
            workRequired: workRequired,
            classBlocks: classBlocks,
            workBlocks: workBlocks,
          ),
      ],
    );
  }
}

class _IntroCard extends StatelessWidget {
  final bool classesRequired;
  final bool workRequired;
  final String? role;

  const _IntroCard({
    required this.classesRequired,
    required this.workRequired,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final noSetupNeeded = !classesRequired && !workRequired;
    return OnboardingGlassCard(
      tint: noSetupNeeded
          ? OptivusColors.success.withValues(alpha: 0.08)
          : OptivusColors.aquaAccent.withValues(alpha: 0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                noSetupNeeded
                    ? Icons.check_circle_outline_rounded
                    : Icons.event_available_rounded,
                color: noSetupNeeded
                    ? OptivusColors.success
                    : OptivusColors.aquaAccent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  noSetupNeeded
                      ? 'No class/work setup needed'
                      : 'Upload photo, then edit the timeline',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            noSetupNeeded
                ? 'Your selected role does not require fixed class or work blocks.'
                : 'Optivus will ask only for the schedule sections required by your role.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OnboardingChip(
                label: classesRequired ? 'Classes required' : 'Classes skipped',
                selected: classesRequired,
                icon: Icons.school_rounded,
                accent: OptivusColors.aquaAccent,
              ),
              OnboardingChip(
                label: workRequired ? 'Work required' : 'Work skipped',
                selected: workRequired,
                icon: Icons.work_rounded,
                accent: OptivusColors.brandAccent,
              ),
              if (role == LifeRoleDraft.businessKey)
                const OnboardingChip(
                  label: 'Business/freelance',
                  selected: true,
                  icon: Icons.storefront_rounded,
                  accent: OptivusColors.brandAccent,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final bool classesRequired;
  final bool workRequired;
  final List<TimelineBlockDraft> classBlocks;
  final List<TimelineBlockDraft> workBlocks;

  const _SummaryCard({
    required this.classesRequired,
    required this.workRequired,
    required this.classBlocks,
    required this.workBlocks,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnboardingGlassCard(
          tint: OptivusColors.success.withValues(alpha: 0.08),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: OptivusColors.success,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  !classesRequired && !workRequired
                      ? 'Class/work setup skipped for your role.'
                      : 'Fixed responsibilities are ready.',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.success,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (classesRequired)
          OnboardingMiniBlockList(
            title: 'Classes',
            blocks: classBlocks,
            accent: OptivusColors.aquaAccent,
            emptyLabel: 'No class blocks applied yet.',
          ),
        if (classesRequired && workRequired) const SizedBox(height: 12),
        if (workRequired)
          OnboardingMiniBlockList(
            title: 'Work',
            blocks: workBlocks,
            accent: OptivusColors.brandAccent,
            emptyLabel: 'No work blocks applied yet.',
          ),
      ],
    );
  }
}
