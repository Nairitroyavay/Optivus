import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/state/mock_app_state.dart';

class OnboardingStep2 extends ConsumerWidget {
  const OnboardingStep2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(mockUserProfileProvider);

    const roles = [
      {
        'name': 'Student / School / College',
        'icon': Icons.school_rounded,
        'desc': 'Classes enabled, job disabled',
      },
      {
        'name': 'Working Person',
        'icon': Icons.business_center_rounded,
        'desc': 'Classes disabled, job enabled',
      },
      {
        'name': 'Student + Working Person',
        'icon': Icons.dynamic_feed_rounded,
        'desc': 'Classes and job both enabled',
      },
      {
        'name': 'Business / Startup / Freelancer',
        'icon': Icons.storefront_rounded,
        'desc': 'Work/business timeline enabled',
      },
      {
        'name': 'Not Student + Not Working',
        'icon': Icons.self_improvement_rounded,
        'desc': 'Classes and job disabled',
      },
    ];

    final showWorkingExtras =
        profile.lifeRole == 'Working Person' ||
        profile.lifeRole == 'Student + Working Person';
    final showBusinessExtras =
        profile.lifeRole == 'Business / Startup / Freelancer';

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
            final name = role['name'] as String;
            final isSelected = profile.lifeRole == name;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OnboardingChoiceTile(
                title: name,
                subtitle: role['desc'] as String,
                icon: role['icon'] as IconData,
                selected: isSelected,
                onTap: () {
                  ref
                      .read(mockUserProfileProvider.notifier)
                      .updateLifestyleRole(name);
                  ref
                      .read(mockOnboardingProvider.notifier)
                      .setStepDirty(2, true);
                },
                expandedContent: isSelected
                    ? _RoleEffectSummary(roleName: name)
                    : null,
              ),
            );
          }),
          if (showWorkingExtras) ...[
            const SizedBox(height: 8),
            _ChipSection(
              title: 'Work Type',
              options: const [
                'Full-time',
                'Part-time',
                'Shift work',
                'Remote work',
                'Hybrid',
              ],
              selected: profile.workingExtra,
              onSelect: (value) {
                ref
                    .read(mockUserProfileProvider.notifier)
                    .updateProfile(profile.copyWith(workingExtra: value));
                ref.read(mockOnboardingProvider.notifier).setStepDirty(2, true);
              },
            ),
          ],
          if (showBusinessExtras) ...[
            const SizedBox(height: 8),
            _ChipSection(
              title: 'Business Schedule',
              options: const ['Fixed hours', 'Flexible work', 'Mixed'],
              selected: profile.businessMode,
              onSelect: (value) {
                ref
                    .read(mockUserProfileProvider.notifier)
                    .updateProfile(profile.copyWith(businessMode: value));
                ref.read(mockOnboardingProvider.notifier).setStepDirty(2, true);
              },
            ),
          ],
          const SizedBox(height: 18),
                _LifestyleSection(profile: profile),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RoleEffectSummary extends StatelessWidget {
  final String roleName;

  const _RoleEffectSummary({required this.roleName});

  @override
  Widget build(BuildContext context) {
    final classesEnabled =
        roleName == 'Student / School / College' ||
        roleName == 'Student + Working Person';
    final jobEnabled =
        roleName == 'Working Person' ||
        roleName == 'Student + Working Person' ||
        roleName == 'Business / Startup / Freelancer';

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
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _ChipSection({
    required this.title,
    required this.options,
    required this.selected,
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
                    label: option,
                    selected: selected == option,
                    onTap: () => onSelect(option),
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
  final dynamic profile;

  const _LifestyleSection({required this.profile});

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
              'Rarely',
              '1-2 days/week',
              '3-4 days/week',
              '5+ days/week',
            ],
            selected: profile.exerciseLevel,
            onSelect: (value) {
              ref
                  .read(mockUserProfileProvider.notifier)
                  .updateProfile(profile.copyWith(exerciseLevel: value));
              ref.read(mockOnboardingProvider.notifier).setStepDirty(2, true);
            },
          ),
          _SegmentRow(
            label: 'Water Intake',
            options: const ['Low', 'Medium', 'High'],
            selected: profile.waterIntake,
            onSelect: (value) {
              ref
                  .read(mockUserProfileProvider.notifier)
                  .updateProfile(profile.copyWith(waterIntake: value));
              ref.read(mockOnboardingProvider.notifier).setStepDirty(2, true);
            },
          ),
          _SegmentRow(
            label: 'Stress Level',
            options: const ['Low', 'Medium', 'High'],
            selected: profile.stressLevel,
            onSelect: (value) {
              ref
                  .read(mockUserProfileProvider.notifier)
                  .updateProfile(profile.copyWith(stressLevel: value));
              ref.read(mockOnboardingProvider.notifier).setStepDirty(2, true);
            },
          ),
          _SegmentRow(
            label: 'Sleep Quality',
            options: const ['Poor', 'Okay', 'Good'],
            selected: profile.sleepQuality,
            onSelect: (value) {
              ref
                  .read(mockUserProfileProvider.notifier)
                  .updateProfile(profile.copyWith(sleepQuality: value));
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
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _SegmentRow({
    required this.label,
    required this.options,
    required this.selected,
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
            options: options,
            selectedValue: selected,
            onChanged: onSelect,
          ),
        ],
      ),
    );
  }
}
