import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';

class OnboardingStep7 extends StatefulWidget {
  const OnboardingStep7({super.key});

  @override
  State<OnboardingStep7> createState() => _OnboardingStep7State();
}

class _OnboardingStep7State extends State<OnboardingStep7> {
  final List<_IdentityGoal> _goals = [
    _IdentityGoal(
      'Financially Free',
      Icons.savings_rounded,
      'Money tracking + savings proof',
    ),
    _IdentityGoal(
      'Strong Body',
      Icons.fitness_center_rounded,
      'Gym + protein + sleep',
    ),
    _IdentityGoal(
      'Become Disciplined',
      Icons.flag_rounded,
      'Routine anchors + slip-up recovery',
    ),
    _IdentityGoal(
      'New Language',
      Icons.translate_rounded,
      'Language practice block',
    ),
    _IdentityGoal(
      'Start Business',
      Icons.storefront_rounded,
      'Deep work + finance systems',
    ),
    _IdentityGoal(
      'Inner Peace',
      Icons.self_improvement_rounded,
      'Meditation + journaling',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = _goals.where((goal) => goal.selected).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: OnboardingSectionTitle(
            title: 'Long-Term Identity Goals',
            subtitle:
                'Choose identity outcomes. Optivus maps them into duplicate-safe systems.',
          ),
        ),
        Expanded(
          child: OnboardingScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
                onTap: () => setState(() => goal.selected = !goal.selected),
                expandedContent: goal.selected
                    ? Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          OnboardingChip(
                            label: 'Mapped system',
                            selected: true,
                          ),
                          OnboardingChip(
                            label: 'Duplicate prevention',
                            selected: true,
                            accent: OptivusColors.aquaAccent,
                          ),
                        ],
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
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Text(
                  selected.isEmpty
                      ? 'No identity systems selected yet.'
                      : selected
                            .map((goal) => '${goal.title}: ${goal.system}')
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
  final String title;
  final IconData icon;
  final String system;
  bool selected;

  _IdentityGoal(this.title, this.icon, this.system) : selected = false;
}
