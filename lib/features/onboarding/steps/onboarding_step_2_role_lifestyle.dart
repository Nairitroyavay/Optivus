import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/state/app_state.dart';

class OnboardingStep2 extends ConsumerWidget {
  const OnboardingStep2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(mockOnboardingProvider).draft;
    final lifeRole = draft.lifeRole;
    final roleWarnings = draft.baseTimeline.roleChangeWarnings;

    const roles = [
      {
        'key': LifeRoleDraft.studentKey,
        'name': 'Student / School / College',
        'icon': Icons.school_rounded,
        'desc': 'Classes enabled, job disabled',
      },
      {
        'key': LifeRoleDraft.workingKey,
        'name': 'Working Person',
        'icon': Icons.business_center_rounded,
        'desc': 'Classes disabled, job enabled',
      },
      {
        'key': LifeRoleDraft.studentWorkingKey,
        'name': 'Student + Working Person',
        'icon': Icons.dynamic_feed_rounded,
        'desc': 'Classes and job both enabled',
      },
      {
        'key': LifeRoleDraft.businessKey,
        'name': 'Business / Startup / Freelancer',
        'icon': Icons.storefront_rounded,
        'desc': 'Work/business timeline enabled',
      },
      {
        'key': LifeRoleDraft.notStudentNotWorkingKey,
        'name': 'Not Student + Not Working',
        'icon': Icons.self_improvement_rounded,
        'desc': 'Classes and job disabled',
      },
    ];

    final showWorkingExtras = lifeRole.needsWorkType;
    final showBusinessExtras = lifeRole.needsBusinessMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: OnboardingSectionTitle(
            title: 'Currently Who Are You?',
            subtitle:
                'This unlocks the right class, work, and lifestyle setup blocks.',
          ),
        ),
        Expanded(
          child: OnboardingScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...roles.map((role) {
                  final key = role['key'] as String;
                  final name = role['name'] as String;
                  final isSelected = lifeRole.lifeRole == key;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OnboardingChoiceTile(
                      title: name,
                      subtitle: role['desc'] as String,
                      icon: role['icon'] as IconData,
                      selected: isSelected,
                      onTap: () {
                        ref
                            .read(mockOnboardingProvider.notifier)
                            .updateLifeRoleSelection(key);
                      },
                      expandedContent: isSelected
                          ? _RoleEffectSummary(roleKey: key)
                          : null,
                    ),
                  );
                }),
                if (roleWarnings.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  OnboardingGlassCard(
                    tint: OptivusColors.warning.withValues(alpha: 0.10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: OptivusColors.warning,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            roleWarnings.join('\n'),
                            style: const TextStyle(
                              color: OptivusColors.textSecondary,
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (showWorkingExtras) ...[
                  const SizedBox(height: 8),
                  _ChipSection(
                    title: 'Work Type',
                    options: const [
                      _DraftOption('full_time', 'Full-time'),
                      _DraftOption('part_time', 'Part-time'),
                      _DraftOption('shift', 'Shift work'),
                      _DraftOption('remote', 'Remote work'),
                      _DraftOption('hybrid', 'Hybrid'),
                    ],
                    selectedKey: lifeRole.workType,
                    onSelect: (value) {
                      ref
                          .read(mockOnboardingProvider.notifier)
                          .updateDraft(
                            (current) => current.copyWith(
                              lifeRole: current.lifeRole.copyWith(
                                workType: value,
                              ),
                              clearFinalPreview: true,
                            ),
                          );
                      ref
                          .read(mockOnboardingProvider.notifier)
                          .setStepDirty(2, true);
                    },
                  ),
                ],
                if (showBusinessExtras) ...[
                  const SizedBox(height: 8),
                  _ChipSection(
                    title: 'Business Schedule',
                    options: const [
                      _DraftOption('fixed_business', 'Fixed hours'),
                      _DraftOption('flexible_business', 'Flexible work'),
                      _DraftOption('mixed_business', 'Mixed'),
                    ],
                    selectedKey: lifeRole.businessMode,
                    onSelect: (value) {
                      ref
                          .read(mockOnboardingProvider.notifier)
                          .updateDraft(
                            (current) => current.copyWith(
                              lifeRole: current.lifeRole.copyWith(
                                businessMode: value,
                              ),
                              baseTimeline: current.baseTimeline.copyWith(
                                businessMode: value,
                                clearRoleChangeWarnings: true,
                              ),
                              clearFinalPreview: true,
                            ),
                          );
                      ref
                          .read(mockOnboardingProvider.notifier)
                          .setStepDirty(2, true);
                    },
                  ),
                ],
                const SizedBox(height: 18),
                _LifestyleSection(lifeRole: lifeRole),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RoleEffectSummary extends StatelessWidget {
  final String roleKey;

  const _RoleEffectSummary({required this.roleKey});

  @override
  Widget build(BuildContext context) {
    final classesEnabled =
        roleKey == LifeRoleDraft.studentKey ||
        roleKey == LifeRoleDraft.studentWorkingKey;
    final jobEnabled =
        roleKey == LifeRoleDraft.workingKey ||
        roleKey == LifeRoleDraft.studentWorkingKey ||
        roleKey == LifeRoleDraft.businessKey;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OnboardingChip(
          label: classesEnabled ? 'Classes enabled' : 'Classes disabled',
          selected: classesEnabled,
          icon: Icons.school_rounded,
          accent: OptivusColors.aquaAccent,
        ),
        OnboardingChip(
          label: jobEnabled ? 'Job / Work enabled' : 'Job disabled',
          selected: jobEnabled,
          icon: Icons.work_rounded,
        ),
      ],
    );
  }
}

class _ChipSection extends StatelessWidget {
  final String title;
  final List<_DraftOption> options;
  final String? selectedKey;
  final ValueChanged<String> onSelect;

  const _ChipSection({
    required this.title,
    required this.options,
    required this.selectedKey,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map(
                  (option) => OnboardingChip(
                    label: option.label,
                    selected: selectedKey == option.key,
                    onTap: () => onSelect(option.key),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _LifestyleSection extends ConsumerWidget {
  final LifeRoleDraft lifeRole;

  const _LifestyleSection({required this.lifeRole});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OnboardingGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LIFESTYLE SNAPSHOT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          _SegmentRow(
            label: 'Exercise Level',
            options: const [
              _DraftOption('rarely', 'Rarely'),
              _DraftOption('1_2_days', '1-2 days/week'),
              _DraftOption('3_4_days', '3-4 days/week'),
              _DraftOption('5_plus_days', '5+ days/week'),
            ],
            selectedKey: lifeRole.exerciseLevel,
            onSelect: (value) {
              ref
                  .read(mockOnboardingProvider.notifier)
                  .updateDraft(
                    (current) => current.copyWith(
                      lifeRole: current.lifeRole.copyWith(exerciseLevel: value),
                      clearFinalPreview: true,
                    ),
                  );
              ref.read(mockOnboardingProvider.notifier).setStepDirty(2, true);
            },
          ),
          _SegmentRow(
            label: 'Water Intake',
            options: const [
              _DraftOption('low', 'Low'),
              _DraftOption('medium', 'Medium'),
              _DraftOption('high', 'High'),
            ],
            selectedKey: lifeRole.waterIntake,
            onSelect: (value) {
              ref
                  .read(mockOnboardingProvider.notifier)
                  .updateDraft(
                    (current) => current.copyWith(
                      lifeRole: current.lifeRole.copyWith(waterIntake: value),
                      clearFinalPreview: true,
                    ),
                  );
              ref.read(mockOnboardingProvider.notifier).setStepDirty(2, true);
            },
          ),
          _SegmentRow(
            label: 'Stress Level',
            options: const [
              _DraftOption('low', 'Low'),
              _DraftOption('medium', 'Medium'),
              _DraftOption('high', 'High'),
            ],
            selectedKey: lifeRole.stressLevel,
            onSelect: (value) {
              ref
                  .read(mockOnboardingProvider.notifier)
                  .updateDraft(
                    (current) => current.copyWith(
                      lifeRole: current.lifeRole.copyWith(stressLevel: value),
                      clearFinalPreview: true,
                    ),
                  );
              ref.read(mockOnboardingProvider.notifier).setStepDirty(2, true);
            },
          ),
          _SegmentRow(
            label: 'Sleep Quality',
            options: const [
              _DraftOption('poor', 'Poor'),
              _DraftOption('okay', 'Okay'),
              _DraftOption('good', 'Good'),
            ],
            selectedKey: lifeRole.sleepQuality,
            onSelect: (value) {
              ref
                  .read(mockOnboardingProvider.notifier)
                  .updateDraft(
                    (current) => current.copyWith(
                      lifeRole: current.lifeRole.copyWith(sleepQuality: value),
                      clearFinalPreview: true,
                    ),
                  );
              ref.read(mockOnboardingProvider.notifier).setStepDirty(2, true);
            },
          ),
        ],
      ),
    );
  }
}

class _SegmentRow extends StatelessWidget {
  final String label;
  final List<_DraftOption> options;
  final String? selectedKey;
  final ValueChanged<String> onSelect;

  const _SegmentRow({
    required this.label,
    required this.options,
    required this.selectedKey,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          OnboardingLiquidSlider(
            options: options.map((option) => option.label).toList(),
            selectedValue: _labelForKey(options, selectedKey),
            onChanged: (label) => onSelect(_keyForLabel(options, label)),
          ),
        ],
      ),
    );
  }
}

class _DraftOption {
  final String key;
  final String label;

  const _DraftOption(this.key, this.label);
}

String _labelForKey(List<_DraftOption> options, String? key) {
  for (final option in options) {
    if (option.key == key) return option.label;
  }
  return '';
}

String _keyForLabel(List<_DraftOption> options, String label) {
  for (final option in options) {
    if (option.label == label) return option.key;
  }
  return options.first.key;
}
