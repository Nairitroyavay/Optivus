import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/state/mock_app_state.dart';

class OnboardingStep6 extends ConsumerStatefulWidget {
  const OnboardingStep6({super.key});

  @override
  ConsumerState<OnboardingStep6> createState() => _OnboardingStep6State();
}

class _OnboardingStep6State extends ConsumerState<OnboardingStep6> {
  final _customCtrl = TextEditingController();
  final List<_GoodHabit> _habits = [
    _GoodHabit('Gym', Icons.fitness_center_rounded, [
      'Strength',
      'Cardio',
      'Mobility',
    ], true),
    _GoodHabit('Skill Practice', Icons.build_rounded, [
      'Coding',
      'Design',
      'Music',
      'Writing',
    ]),
    _GoodHabit('Reading', Icons.menu_book_rounded, [
      'Non-fiction',
      'Fiction',
      'Research',
    ], true),
    _GoodHabit('Meditation', Icons.self_improvement_rounded, [
      'Breathing',
      'Mindfulness',
      'Zen',
    ], true),
    _GoodHabit('Journaling', Icons.edit_note_rounded, [
      'Gratitude',
      'Reflection',
      'Planner',
    ]),
    _GoodHabit('Language Learning', Icons.translate_rounded, [
      'Spanish',
      'French',
      'Japanese',
      'German',
    ]),
  ];

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  void _dirty() =>
      ref.read(mockOnboardingProvider.notifier).setStepDirty(6, true);

  void _addCustom() {
    final text = _customCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _habits.add(
        _GoodHabit(text, Icons.star_border_rounded, [
          'General',
          'Specific',
        ], true),
      );
      _customCtrl.clear();
    });
    _dirty();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: OnboardingSectionTitle(
            title: 'Build Good Habits',
            subtitle: 'Pick the systems that will replace low-value loops.',
          ),
        ),
        Expanded(
          child: OnboardingScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          ..._habits.map((habit) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OnboardingChoiceTile(
                title: habit.name,
                subtitle:
                    'Duration, frequency, best time, and priority are set as mock local preferences.',
                icon: habit.icon,
                selected: habit.selected,
                accent: OptivusColors.aquaAccent,
                onTap: () {
                  setState(() => habit.selected = !habit.selected);
                  _dirty();
                },
                expandedContent: habit.selected ? _expandedHabit(habit) : null,
              ),
            );
          }),
          OnboardingGlassCard(
            child: Row(
              children: [
                const Icon(
                  Icons.add_circle_outline_rounded,
                  color: OptivusColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _customCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Custom good habit',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addCustom(),
                  ),
                ),
                OnboardingIconPill(
                  icon: Icons.check_rounded,
                  accent: OptivusColors.aquaAccent,
                  tooltip: 'Add custom habit',
                  onTap: _addCustom,
                ),
              ],
            ),
          ),
        ], // end OnboardingScrollView Column children
      ), // end OnboardingScrollView Column
    ), // end OnboardingScrollView
  ), // end Expanded
], // end outer Column children
);
}

  Widget _expandedHabit(_GoodHabit habit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: habit.categories
              .map(
                (category) => OnboardingChip(
                  label: category,
                  selected: habit.category == category,
                  onTap: () {
                    setState(() => habit.category = category);
                    _dirty();
                  },
                  accent: OptivusColors.aquaAccent,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _metaChip('Duration', habit.duration),
            _metaChip('Frequency', habit.frequency),
            _metaChip('Best time', habit.bestTime),
            _metaChip('Priority', habit.priority),
          ],
        ),
      ],
    );
  }

  Widget _metaChip(String label, String value) {
    return OnboardingChip(
      label: '$label: $value',
      selected: true,
      accent: OptivusColors.brandAccent,
    );
  }
}

class _GoodHabit {
  final String name;
  final IconData icon;
  final List<String> categories;
  bool selected;
  String category;
  String duration = '30m';
  String frequency = 'Daily';
  String bestTime = 'Morning';
  String priority = 'Medium';

  _GoodHabit(this.name, this.icon, this.categories, [this.selected = false])
    : category = categories.first;
}
