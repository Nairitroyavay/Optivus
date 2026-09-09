import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_spacing.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/onboarding/onboarding_step_id.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/services/nutrition_target_service.dart';
import 'package:optivus/state/app_state.dart';

class OnboardingStep3 extends ConsumerStatefulWidget {
  const OnboardingStep3({super.key});

  @override
  ConsumerState<OnboardingStep3> createState() => _OnboardingStep3State();
}

class _OnboardingStep3State extends ConsumerState<OnboardingStep3> {
  static const _minimumHeightCm = 120.0;
  static const _maximumHeightCm = 220.0;
  static const _minimumWeightKg = 40.0;
  static const _maximumWeightKg = 150.0;

  bool _isHeightMetric = true;
  bool _isWeightMetric = true;

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingStateProvider).draft;
    final body = draft.bodyBasics;
    final targets = const NutritionTargetService().calculate(
      ageRange: body.ageRange,
      heightCm: body.heightCm,
      weightKg: body.weightKg,
      gender: body.gender,
      exerciseLevel: draft.lifeRole.exerciseLevel,
    );
    final displayHeightCm =
        body.heightCm ?? (_minimumHeightCm + _maximumHeightCm) / 2;
    final displayWeightKg =
        body.weightKg ?? (_minimumWeightKg + _maximumWeightKg) / 2;
    final totalInches = displayHeightCm / 2.54;
    final feet = totalInches ~/ 12;
    final inches = (totalInches % 12).round();
    final lbs = displayWeightKg * 2.20462;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: OptivusSpacing.onboardingHeaderPadding,
          child: OnboardingSectionTitle(
            title: 'Body Basics',
            subtitle:
                'We use this to estimate metabolism, calories, and protein targets.',
          ),
        ),
        Expanded(
          child: OnboardingScrollView(
            padding: OptivusSpacing.onboardingContentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OnboardingGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gender',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      OnboardingLiquidSlider(
                        options: const [
                          'Male',
                          'Female',
                          'Non-binary',
                          'Prefer not to say',
                        ],
                        selectedValue: _genderLabel(body.gender),
                        onChanged: (value) {
                          _updateBody(
                            body
                                .copyWith(gender: _genderKey(value))
                                .withEstimates(),
                          );
                          ref
                              .read(onboardingStateProvider.notifier)
                              .setStepDirty(
                                OnboardingStepId.bodyBasics.index,
                                true,
                              );
                        },
                        accent: OptivusColors.brandAccent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                OnboardingGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Age Range',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      OnboardingLiquidSlider(
                        options: const [
                          '<18',
                          '18-24',
                          '25-34',
                          '35-44',
                          '45+',
                        ],
                        selectedValue: body.ageRange ?? '',
                        onChanged: (value) {
                          _updateBody(
                            body.copyWith(ageRange: value).withEstimates(),
                          );
                          ref
                              .read(onboardingStateProvider.notifier)
                              .setStepDirty(
                                OnboardingStepId.bodyBasics.index,
                                true,
                              );
                        },
                        accent: OptivusColors.brandAccent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SliderCard(
                  title: 'Height',
                  trailing: OnboardingUnitToggle(
                    key: const ValueKey('height-unit-toggle'),
                    option1: 'CM',
                    option2: 'FT',
                    isOption1: _isHeightMetric,
                    onChanged: (val) => setState(() => _isHeightMetric = val),
                  ),
                  valueLabel: _isHeightMetric
                      ? body.heightCm == null
                            ? 'Set cm'
                            : '${body.heightCm!.toInt()} cm'
                      : body.heightCm == null
                      ? 'Set ft'
                      : "$feet'$inches\"",
                  value: _isHeightMetric
                      ? displayHeightCm
                      : totalInches.clamp(48.0, 84.0),
                  min: _isHeightMetric ? _minimumHeightCm : 48,
                  max: _isHeightMetric ? _maximumHeightCm : 84,
                  onChanged: (value) {
                    _updateBody(
                      body
                          .copyWith(
                            heightCm: _isHeightMetric ? value : value * 2.54,
                          )
                          .withEstimates(),
                    );
                    ref
                        .read(onboardingStateProvider.notifier)
                        .setStepDirty(OnboardingStepId.bodyBasics.index, true);
                  },
                  sliderKey: const ValueKey('height-slider'),
                ),
                const SizedBox(height: 14),
                _SliderCard(
                  title: 'Weight',
                  trailing: OnboardingUnitToggle(
                    key: const ValueKey('weight-unit-toggle'),
                    option1: 'KG',
                    option2: 'LB',
                    isOption1: _isWeightMetric,
                    onChanged: (val) => setState(() => _isWeightMetric = val),
                  ),
                  valueLabel: _isWeightMetric
                      ? body.weightKg == null
                            ? 'Set kg'
                            : '${body.weightKg!.toInt()} kg'
                      : body.weightKg == null
                      ? 'Set lbs'
                      : '${lbs.round()} lbs',
                  value: _isWeightMetric
                      ? displayWeightKg
                      : lbs.clamp(88.0, 330.0),
                  min: _isWeightMetric ? _minimumWeightKg : 88,
                  max: _isWeightMetric ? _maximumWeightKg : 330,
                  onChanged: (value) {
                    _updateBody(
                      body
                          .copyWith(
                            weightKg: _isWeightMetric ? value : value / 2.20462,
                          )
                          .withEstimates(),
                    );
                    ref
                        .read(onboardingStateProvider.notifier)
                        .setStepDirty(OnboardingStepId.bodyBasics.index, true);
                  },
                  sliderKey: const ValueKey('weight-slider'),
                ),
                const SizedBox(height: 14),
                OnboardingGlassCard(
                  tint: OptivusColors.aquaAccent.withValues(alpha: 0.10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.analytics_rounded,
                            color: OptivusColors.brandAccent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Live Estimates',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _Estimate(
                            label: 'BMI estimate',
                            value: targets.bmi == null
                                ? '--'
                                : '${targets.bmi}',
                          ),
                          _Estimate(
                            label: 'Calorie estimate',
                            value: targets.estimatedMaintenanceCalories == null
                                ? '--'
                                : '${targets.estimatedMaintenanceCalories} kcal',
                          ),
                          _Estimate(
                            label: 'Protein estimate',
                            value: targets.proteinTarget == null
                                ? '--'
                                : '${targets.proteinTarget!.toInt()} g',
                          ),
                        ], // closes Row's children
                      ), // closes Row
                    ], // closes OnboardingGlassCard's inner Column's children
                  ), // closes inner Column
                ), // closes OnboardingGlassCard
              ], // closes OnboardingScrollView's inner Column's children
            ), // closes inner Column
          ), // closes OnboardingScrollView
        ), // closes Expanded
      ], // closes outer Column's children
    );
  }

  void _updateBody(BodyBasicsDraft body) {
    ref
        .read(onboardingStateProvider.notifier)
        .updateDraft(
          (current) =>
              current.copyWith(bodyBasics: body, clearFinalPreview: true),
        );
  }

  String _genderKey(String label) {
    return switch (label) {
      'Male' => 'male',
      'Female' => 'female',
      'Non-binary' => 'non_binary',
      'Prefer not to say' => 'prefer_not_to_say',
      _ => label.toLowerCase().replaceAll(' ', '_'),
    };
  }

  String _genderLabel(String? key) {
    return switch (key) {
      'male' => 'Male',
      'female' => 'Female',
      'non_binary' => 'Non-binary',
      'prefer_not_to_say' => 'Prefer not to say',
      _ => '',
    };
  }
}

class _SliderCard extends StatelessWidget {
  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final Widget? trailing;
  final Key? sliderKey;

  const _SliderCard({
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.trailing,
    this.sliderKey,
  });

  @override
  Widget build(BuildContext context) {
    final trailingWidget = trailing;

    return OnboardingGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              ?trailingWidget,
            ],
          ),
          OnboardingLiquidContinuousSlider(
            key: sliderKey,
            value: value,
            valueLabel: valueLabel,
            min: min,
            max: max,
            accent: OptivusColors.brandAccent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Estimate extends StatelessWidget {
  final String label;
  final String value;

  const _Estimate({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: OptivusColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: OptivusColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
