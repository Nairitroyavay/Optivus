import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_spacing.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/onboarding/onboarding_step_id.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/state/app_state.dart';

class OnboardingGoodHabitsStep extends ConsumerStatefulWidget {
  const OnboardingGoodHabitsStep({super.key});

  @override
  ConsumerState<OnboardingGoodHabitsStep> createState() =>
      _OnboardingGoodHabitsStepState();
}

class _OnboardingGoodHabitsStepState
    extends ConsumerState<OnboardingGoodHabitsStep> {
  final _customCtrl = TextEditingController();
  bool _notNow = false;
  final List<_GoodHabit> _habits = [
    _GoodHabit('Gym', Icons.fitness_center_rounded, [
      'Strength',
      'Cardio',
      'Mobility',
    ]),
    _GoodHabit('Skill Practice', Icons.build_rounded, [
      'Coding',
      'Exam study',
      'Language',
      'Design',
      'Writing',
      'Business skill',
      'Editing',
      'Custom skill',
    ]),
    _GoodHabit('Reading', Icons.menu_book_rounded, [
      'Self-growth book',
      'Class subject',
      'Fiction',
      'Spiritual/calm reading',
      'Custom',
    ]),
    _GoodHabit('Meditation', Icons.self_improvement_rounded, [
      'Breathing',
      'Mindfulness',
      'Zen',
    ]),
    _GoodHabit('Journaling', Icons.edit_note_rounded, [
      'Gratitude',
      'Reflection',
      'Planner',
    ]),
    _GoodHabit('Language Learning', Icons.translate_rounded, [
      'English',
      'Hindi',
      'Bengali',
      'Japanese',
      'German',
      'Spanish',
      'French',
      'Korean',
      'Chinese',
      'Custom',
    ]),
  ];

  @override
  void initState() {
    super.initState();
    final draft = ref.read(onboardingStateProvider).draft;
    _notNow = draft.goodHabitsNotNow;
    for (final saved in draft.goodHabits) {
      final existingIndex = _habits.indexWhere(
        (habit) => _habitKey(habit.name) == saved.habitKey,
      );
      final target = existingIndex >= 0
          ? _habits[existingIndex]
          : _GoodHabit(saved.displayName, Icons.star_border_rounded, [
              saved.customSubtype ?? 'Custom',
            ]);
      target
        ..selected = true
        ..category = _subtypeLabel(saved.subtypeKey) ?? target.category
        ..duration = _durationLabel(saved.durationMinutes)
        ..frequency = _frequencyLabel(saved.frequency)
        ..bestTime = _bestTimeLabel(saved.bestTime)
        ..priority = _priorityLabel(saved.priority);
      if (existingIndex < 0) _habits.add(target);
    }
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  void _dirty() => ref
      .read(onboardingStateProvider.notifier)
      .setStepDirty(OnboardingStepId.goodHabits.index, true);

  void _syncDraft() {
    final selected = _notNow
        ? <GoodHabitDraft>[]
        : _habits
              .where((habit) => habit.selected)
              .map(
                (habit) => GoodHabitDraft(
                  id: 'good-${_habitKey(habit.name)}',
                  habitKey: _habitKey(habit.name),
                  displayName: habit.name,
                  subtypeKey: _subtypeKey(habit.category),
                  durationMinutes:
                      habit.duration == 'Custom' &&
                          habit.customDurationMinutes != null
                      ? habit.customDurationMinutes!
                      : _durationMinutes(habit.duration),
                  frequency: _frequencyKey(habit.frequency),
                  bestTime: _bestTimeKey(habit.bestTime),
                  priority: _priorityKey(habit.priority),
                  repeatDays: _repeatDaysForFrequency(habit.frequency),
                ),
              )
              .toList();
    ref
        .read(onboardingStateProvider.notifier)
        .updateDraft(
          (draft) => draft.copyWith(
            goodHabitsNotNow: _notNow,
            goodHabits: selected,
            clearFinalPreview: true,
          ),
        );
  }

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
      _notNow = false;
    });
    _syncDraft();
    _dirty();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: OptivusSpacing.onboardingHeaderPadding,
          child: OnboardingSectionTitle(
            title: 'Build Good Habits',
            subtitle: 'Pick the systems that will replace low-value loops.',
          ),
        ),
        Expanded(
          child: OnboardingScrollView(
            padding: OptivusSpacing.onboardingContentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OnboardingChoiceTile(
                  title: 'Not now',
                  subtitle: 'Skip good habit setup for this onboarding pass.',
                  icon: Icons.check_circle_outline_rounded,
                  selected: _notNow,
                  accent: OptivusColors.success,
                  onTap: () {
                    setState(() {
                      _notNow = !_notNow;
                      if (_notNow) {
                        for (final habit in _habits) {
                          habit.selected = false;
                        }
                      }
                    });
                    _syncDraft();
                    _dirty();
                  },
                ),
                const SizedBox(height: 12),
                ..._habits.map((habit) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Opacity(
                      opacity: _notNow ? 0.42 : 1,
                      child: OnboardingChoiceTile(
                        title: habit.name,
                        subtitle:
                            'Duration, frequency, best time, and priority are local draft preferences.',
                        icon: habit.icon,
                        selected: habit.selected,
                        accent: OptivusColors.aquaAccent,
                        onTap: _notNow
                            ? null
                            : () {
                                setState(
                                  () => habit.selected = !habit.selected,
                                );
                                if (habit.selected) _notNow = false;
                                _syncDraft();
                                _dirty();
                              },
                        expandedContent: habit.selected
                            ? _expandedHabit(habit)
                            : null,
                      ),
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
                    _syncDraft();
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
            _metaOptions(
              'Duration',
              const ['5 min', '15 min', '30 min', '45 min', 'Custom'],
              habit.duration,
              (value) => setState(() => habit.duration = value),
            ),
            if (habit.duration == 'Custom')
              _customNumberInput(
                'Mins',
                habit.customDurationMinutes?.toString() ?? '',
                (val) {
                  setState(
                    () => habit.customDurationMinutes = int.tryParse(val),
                  );
                  _syncDraft();
                  _dirty();
                },
              ),
            _metaOptions(
              'Frequency',
              const ['Daily', 'Weekdays', '3 days/week', 'Custom'],
              habit.frequency,
              (value) => setState(() => habit.frequency = value),
            ),
            _metaOptions(
              'Best time',
              const ['Morning', 'Afternoon', 'Evening', 'Night', 'Anytime'],
              habit.bestTime,
              (value) => setState(() => habit.bestTime = value),
            ),
            _metaOptions(
              'Priority',
              const ['Must do', 'Good to do'],
              habit.priority,
              (value) => setState(() => habit.priority = value),
            ),
          ],
        ),
      ],
    );
  }

  Widget _customNumberInput(
    String hint,
    String initialValue,
    Function(String) onChanged,
  ) {
    return Container(
      width: 80,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.44)),
      ),
      child: Center(
        child: TextField(
          controller: TextEditingController(text: initialValue)
            ..selection = TextSelection.collapsed(offset: initialValue.length),
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: hint,
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _metaOptions(
    String label,
    List<String> options,
    String value,
    VoidCallbackSetter onSelect,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.44)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: options
                .map(
                  (option) => OnboardingChip(
                    label: option,
                    selected: value == option,
                    accent: OptivusColors.brandAccent,
                    onTap: () {
                      onSelect(option);
                      _syncDraft();
                      _dirty();
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

typedef VoidCallbackSetter = void Function(String value);

class _GoodHabit {
  final String name;
  final IconData icon;
  final List<String> categories;
  bool selected;
  String category;
  String duration = '15 min';
  int? customDurationMinutes;
  String frequency = 'Daily';
  String bestTime = 'Anytime';
  String priority = 'Good to do';

  _GoodHabit(this.name, this.icon, this.categories, [this.selected = false])
    : category = categories.first;
}

String _habitKey(String name) {
  return switch (name) {
    'Gym' => GoodHabitDraft.gymKey,
    'Skill Practice' => GoodHabitDraft.skillPracticeKey,
    'Reading' => GoodHabitDraft.readingKey,
    'Meditation' => GoodHabitDraft.meditationKey,
    'Journaling' => GoodHabitDraft.journalingKey,
    'Language Learning' => GoodHabitDraft.languageLearningKey,
    _ => GoodHabitDraft.customKey,
  };
}

String _subtypeKey(String label) {
  return label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
}

String? _subtypeLabel(String? key) {
  if (key == null) return null;
  return key
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

int _durationMinutes(String label) {
  return switch (label) {
    '5 min' => 5,
    '15 min' => 15,
    '30 min' => 30,
    '45 min' => 45,
    _ => 20,
  };
}

String _durationLabel(int minutes) {
  return switch (minutes) {
    5 => '5 min',
    15 => '15 min',
    30 => '30 min',
    45 => '45 min',
    _ => 'Custom',
  };
}

String _frequencyKey(String label) {
  return switch (label) {
    'Weekdays' => 'weekdays',
    '3 days/week' => '3_days_week',
    'Custom' => 'custom',
    _ => 'daily',
  };
}

String _frequencyLabel(String key) {
  return switch (key) {
    'weekdays' => 'Weekdays',
    '3_days_week' => '3 days/week',
    'custom' => 'Custom',
    _ => 'Daily',
  };
}

String _bestTimeKey(String label) {
  return label.toLowerCase().replaceAll(' ', '_');
}

String _bestTimeLabel(String key) {
  return key
      .split('_')
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _priorityKey(String label) {
  return label == 'Must do' ? GoodHabitDraft.mustDoPriority : 'good_to_do';
}

String _priorityLabel(String key) {
  return key == GoodHabitDraft.mustDoPriority ? 'Must do' : 'Good to do';
}

List<int> _repeatDaysForFrequency(String label) {
  return switch (label) {
    'Weekdays' => const [1, 2, 3, 4, 5],
    '3 days/week' => const [1, 3, 5],
    _ => const [1, 2, 3, 4, 5, 6, 7],
  };
}
