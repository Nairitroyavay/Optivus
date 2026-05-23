import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/state/mock_app_state.dart';

class OnboardingStep3 extends ConsumerStatefulWidget {
  const OnboardingStep3({super.key});

  @override
  ConsumerState<OnboardingStep3> createState() => _OnboardingStep3State();
}

class _OnboardingStep3State extends ConsumerState<OnboardingStep3> {
  bool _isHeightMetric = true;
  bool _isWeightMetric = true;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(mockUserProfileProvider);
    final totalInches = profile.height / 2.54;
    final feet = totalInches ~/ 12;
    final inches = (totalInches % 12).round();
    final lbs = profile.weight * 2.20462;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: OnboardingSectionTitle(
            title: 'Body Basics',
            subtitle:
                'We use this to estimate metabolism, calories, and protein targets.',
          ),
        ),
        Expanded(
          child: OnboardingScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

          OnboardingGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gender', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                OnboardingLiquidSlider(
                  options: const ['Male', 'Female', 'Non-binary', 'Prefer not to say'],
                  selectedValue: profile.gender,
                  onChanged: (value) {
                    ref
                        .read(mockUserProfileProvider.notifier)
                        .updateBodyBasics(gender: value);
                    ref
                        .read(mockOnboardingProvider.notifier)
                        .setStepDirty(3, true);
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
                  options: const ['<18', '18-24', '25-34', '35-44', '45+'],
                  selectedValue: profile.ageRange.replaceAll('–', '-'),
                  onChanged: (value) {
                    ref
                        .read(mockUserProfileProvider.notifier)
                        .updateBodyBasics(ageRange: value);
                    ref
                        .read(mockOnboardingProvider.notifier)
                        .setStepDirty(3, true);
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
              option1: 'CM',
              option2: 'FT',
              isOption1: _isHeightMetric,
              onChanged: (val) => setState(() => _isHeightMetric = val),
            ),
            valueLabel: _isHeightMetric
                ? '${profile.height.toInt()} cm'
                : "$feet'$inches\"",
            value: _isHeightMetric ? profile.height : totalInches.clamp(48.0, 84.0),
            min: _isHeightMetric ? 120 : 48,
            max: _isHeightMetric ? 220 : 84,
            onChanged: (value) {
              ref
                  .read(mockUserProfileProvider.notifier)
                  .updateBodyBasics(height: _isHeightMetric ? value : value * 2.54);
              ref.read(mockOnboardingProvider.notifier).setStepDirty(3, true);
            },
          ),
          const SizedBox(height: 14),
          _SliderCard(
            title: 'Weight',
            trailing: OnboardingUnitToggle(
              option1: 'KG',
              option2: 'LB',
              isOption1: _isWeightMetric,
              onChanged: (val) => setState(() => _isWeightMetric = val),
            ),
            valueLabel: _isWeightMetric
                ? '${profile.weight.toInt()} kg'
                : '${lbs.round()} lbs',
            value: _isWeightMetric ? profile.weight : lbs.clamp(88.0, 330.0),
            min: _isWeightMetric ? 40 : 88,
            max: _isWeightMetric ? 150 : 330,
            onChanged: (value) {
              ref
                  .read(mockUserProfileProvider.notifier)
                  .updateBodyBasics(
                    weight: _isWeightMetric ? value : value / 2.20462,
                  );
              ref.read(mockOnboardingProvider.notifier).setStepDirty(3, true);
            },
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
                      value: '${profile.bmiEstimate}',
                    ),
                    _Estimate(
                      label: 'Calorie estimate',
                      value: '${profile.calorieEstimate.toInt()} kcal',
                    ),
                    _Estimate(
                      label: 'Protein estimate',
                      value: '${profile.proteinEstimate.toInt()} g',
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
}

class _SliderCard extends StatelessWidget {
  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final Widget? trailing;

  const _SliderCard({
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              ?trailing,
            ],
          ),
          OnboardingLiquidContinuousSlider(
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
