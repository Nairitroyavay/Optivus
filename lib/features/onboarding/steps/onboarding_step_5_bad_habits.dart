import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/state/app_state.dart';

class OnboardingStep5 extends ConsumerStatefulWidget {
  const OnboardingStep5({super.key});

  @override
  ConsumerState<OnboardingStep5> createState() => _OnboardingStep5State();
}

class _OnboardingStep5State extends ConsumerState<OnboardingStep5> {
  final _customCtrl = TextEditingController();
  bool _notNow = false;
  final List<_BadHabit> _habits = [
    _BadHabit('Cigarettes', Icons.smoking_rooms_rounded, 80, 20),
    _BadHabit('Doom Scrolling', Icons.phone_android_rounded, 0, 120),
    _BadHabit('Junk Food', Icons.fastfood_rounded, 180, 15),
    _BadHabit('Procrastination', Icons.timer_off_rounded, 0, 90),
    _BadHabit('Alcohol', Icons.local_bar_rounded, 200, 45),
  ];

  @override
  void initState() {
    super.initState();
    final draft = ref.read(mockOnboardingProvider).draft;
    _notNow = draft.badHabitsNotNow;
    for (final saved in draft.badHabits) {
      final existingIndex = _habits.indexWhere(
        (habit) => _habitKey(habit.name) == saved.habitKey,
      );
      final target = existingIndex >= 0
          ? _habits[existingIndex]
          : _BadHabit(
              saved.displayName,
              Icons.star_border_rounded,
              saved.dailySpend,
              saved.lostTimeMinutes,
            );
      target
        ..selected = true
        ..spend = saved.dailySpend
        ..minutes = saved.lostTimeMinutes;
      if (existingIndex < 0) _habits.add(target);
    }
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  void _dirty() =>
      ref.read(mockOnboardingProvider.notifier).setStepDirty(5, true);

  void _syncDraft() {
    final selected = _notNow
        ? <BadHabitDraft>[]
        : _habits
              .where((habit) => habit.selected)
              .map(
                (habit) => BadHabitDraft(
                  id: 'bad-${_habitKey(habit.name)}',
                  habitKey: _habitKey(habit.name),
                  displayName: habit.name,
                  dailySpend: habit.spend,
                  lostTimeMinutes: habit.minutes,
                ),
              )
              .toList();
    ref
        .read(mockOnboardingProvider.notifier)
        .updateDraft(
          (draft) => draft.copyWith(
            badHabitsNotNow: _notNow,
            badHabits: selected,
            clearFinalPreview: true,
          ),
        );
  }

  void _addCustom() {
    final text = _customCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _habits.add(
        _BadHabit(text, Icons.star_border_rounded, 0, 30)..selected = true,
      );
      _customCtrl.clear();
      _notNow = false;
    });
    _syncDraft();
    _dirty();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _habits.where((habit) => habit.selected).toList();
    final spend = selected.fold<double>(0, (sum, habit) => sum + habit.spend);
    final minutes = selected.fold<int>(0, (sum, habit) => sum + habit.minutes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: OnboardingSectionTitle(
            title: 'Drop Bad Habits',
            subtitle: 'Select the loops Optivus should help you intercept.',
          ),
        ),
        Expanded(
          child: OnboardingScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OnboardingChoiceTile(
                  title: 'Not now',
                  subtitle: 'Skip bad habit setup for this onboarding pass.',
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
                        subtitle: habit.name == 'Cigarettes'
                            ? 'Daily spend and frequency can shape savings prompts.'
                            : habit.name == 'Doom Scrolling'
                            ? 'Time lost becomes a redirect trigger.'
                            : 'Track money/time friction and replacement actions.',
                        icon: habit.icon,
                        selected: habit.selected,
                        accent: OptivusColors.danger,
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
                            ? _habitSliders(habit)
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
                            hintText: 'Custom bad habit',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onSubmitted: (_) => _addCustom(),
                        ),
                      ),
                      OnboardingIconPill(
                        icon: Icons.check_rounded,
                        accent: OptivusColors.brandAccent,
                        tooltip: 'Add custom habit',
                        onTap: _addCustom,
                      ),
                    ],
                  ),
                ),
                if (selected.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  OnboardingGlassCard(
                    tint: OptivusColors.success.withValues(alpha: 0.10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _Stat(
                          label: 'Daily spend',
                          value: 'Rs ${spend.toInt()}',
                        ),
                        _Stat(
                          label: 'Monthly',
                          value: 'Rs ${(spend * 30).toInt()}',
                        ),
                        _Stat(label: 'Time lost', value: '${minutes}m/day'),
                      ],
                    ),
                  ),
                ], // closes if (selected.isNotEmpty) ...[
              ], // closes OnboardingScrollView's inner Column's children
            ), // closes inner Column
          ), // closes OnboardingScrollView
        ), // closes Expanded
      ], // closes outer Column's children
    );
  }

  Widget _habitSliders(_BadHabit habit) {
    final spendPercent = habit.spend / 1000;
    final spendColor = HSVColor.fromColor(
      OptivusColors.danger,
    ).withSaturation((0.2 + 0.8 * spendPercent).clamp(0.0, 1.0)).toColor();

    final minPercent = habit.minutes / 300;
    final minColor = HSVColor.fromColor(
      OptivusColors.brandAccent,
    ).withSaturation((0.2 + 0.8 * minPercent).clamp(0.0, 1.0)).toColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Daily spend',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: OptivusColors.textSecondary,
          ),
        ),
        OnboardingLiquidContinuousSlider(
          value: habit.spend,
          valueLabel: 'Rs ${habit.spend.toInt()}',
          min: 0,
          max: 1000,
          accent: spendColor,
          onChanged: (value) {
            setState(() => habit.spend = value);
            _syncDraft();
            _dirty();
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Doom/time lost',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: OptivusColors.textSecondary,
          ),
        ),
        OnboardingLiquidContinuousSlider(
          value: habit.minutes.toDouble(),
          valueLabel: '${habit.minutes} min',
          min: 0,
          max: 300,
          accent: minColor,
          onChanged: (value) {
            setState(() => habit.minutes = value.round());
            _syncDraft();
            _dirty();
          },
        ),
      ],
    );
  }
}

String _habitKey(String name) {
  return switch (name) {
    'Cigarettes' => 'cigarettes',
    'Doom Scrolling' => 'doom_scrolling',
    'Junk Food' => 'junk_food',
    'Procrastination' => 'procrastination',
    'Alcohol' => 'alcohol',
    _ => 'custom_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
  };
}

class _BadHabit {
  final String name;
  final IconData icon;
  double spend;
  int minutes;
  bool selected;

  _BadHabit(this.name, this.icon, this.spend, this.minutes) : selected = false;
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: OptivusColors.success,
            ),
          ),
        ],
      ),
    );
  }
}
