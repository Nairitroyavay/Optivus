import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/tracker/providers/tracker_navigation_provider.dart';
import 'package:optivus/features/tracker/providers/tracker_settings_provider.dart';
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/state/region_settings_provider.dart';

class TrackerActivationScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final String trackerType;
  final String? badHabitType;
  final ValueChanged<TrackerDetailTarget> onActivated;

  const TrackerActivationScreen({
    super.key,
    required this.onBack,
    required this.trackerType,
    this.badHabitType,
    required this.onActivated,
  });

  @override
  ConsumerState<TrackerActivationScreen> createState() =>
      _TrackerActivationScreenState();
}

class _TrackerActivationScreenState
    extends ConsumerState<TrackerActivationScreen> {
  late final TextEditingController _dailyCost;
  late final TextEditingController _checkInTime;
  String _primaryChoice = '';
  String _secondaryChoice = '';

  @override
  void initState() {
    super.initState();
    final config = _TrackerActivationConfig.forType(
      widget.trackerType,
      ref.read(regionSettingsProvider),
    );
    _dailyCost = TextEditingController(text: config.defaultDailyCost);
    _checkInTime = TextEditingController(text: config.defaultCheckInTime);
    _primaryChoice = config.primaryOptions.first;
    _secondaryChoice = config.secondaryOptions.first;
  }

  @override
  void dispose() {
    _dailyCost.dispose();
    _checkInTime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _TrackerActivationConfig.forType(
      widget.trackerType,
      ref.watch(regionSettingsProvider),
    );

    return LiquidDetailScaffold(
      eyebrow: 'Tracker setup',
      title: '${config.icon} ${config.title}',
      subtitle: 'Reusable setup flow for backend-ready tracker activation.',
      accentColor: OptivusColors.trackerAccent,
      onBack: widget.onBack,
      children: [
        LiquidDetailSection(
          title: 'What it measures',
          children: [
            _BodyText(config.measures),
            const SizedBox(height: 12),
            _InfoGrid(
              items: {
                'Why it helps': config.whyItHelps,
                'Required data': config.requiredData,
                'Optional permissions': config.optionalPermissions,
              },
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Setup questions',
          children: [
            _QuestionBlock(
              label: config.primaryQuestion,
              options: config.primaryOptions,
              selected: _primaryChoice,
              onSelected: (value) => setState(() => _primaryChoice = value),
            ),
            const SizedBox(height: 14),
            _QuestionBlock(
              label: config.secondaryQuestion,
              options: config.secondaryOptions,
              selected: _secondaryChoice,
              onSelected: (value) => setState(() => _secondaryChoice = value),
            ),
            if (config.showDailyCost) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _dailyCost,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('Daily cost estimate'),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _checkInTime,
              decoration: _inputDecoration('Check-in time'),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Backend handoff',
          children: const [
            _BodyText(
              'Firestore persistence connects in backend pass. This flow already produces stable activation fields: trackerType, setup answers, check-in time, cost, permissions, and active order.',
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _ActivationButton(
                label: 'Cancel',
                color: OptivusColors.textSecondary,
                outlined: true,
                onTap: widget.onBack,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActivationButton(
                label: 'Activate',
                color: OptivusColors.trackerAccent,
                onTap: () {
                  ref
                      .read(trackerSettingsProvider.notifier)
                      .activateTracker(config.title);
                  widget.onActivated(config.detailTarget);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.72),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: OptivusColors.trackerAccent),
      ),
    );
  }
}

class _TrackerActivationConfig {
  final String title;
  final String icon;
  final String measures;
  final String whyItHelps;
  final String requiredData;
  final String optionalPermissions;
  final String primaryQuestion;
  final List<String> primaryOptions;
  final String secondaryQuestion;
  final List<String> secondaryOptions;
  final bool showDailyCost;
  final String defaultDailyCost;
  final String defaultCheckInTime;
  final TrackerDetailTarget detailTarget;

  const _TrackerActivationConfig({
    required this.title,
    required this.icon,
    required this.measures,
    required this.whyItHelps,
    required this.requiredData,
    required this.optionalPermissions,
    required this.primaryQuestion,
    required this.primaryOptions,
    required this.secondaryQuestion,
    required this.secondaryOptions,
    required this.showDailyCost,
    required this.defaultDailyCost,
    required this.defaultCheckInTime,
    required this.detailTarget,
  });

  static _TrackerActivationConfig forType(
    String rawType,
    RegionSettings region,
  ) {
    final type = rawType.toLowerCase();
    if (type.contains('smoking')) {
      return _badHabit('Smoking', 'No. of cigarettes / cravings / money saved');
    }
    if (type.contains('alcohol')) {
      return _badHabit('Alcohol', 'Avoided days, craving moments, relapses');
    }
    if (type.contains('junk')) {
      return _badHabit('Junk Food', 'Cravings, avoided spend, relapse meals');
    }
    if (type.contains('custom bad')) {
      return _badHabit('Custom Bad Habit', 'Custom check-ins and relapse risk');
    }
    if (type.contains('sleep')) {
      return _TrackerActivationConfig(
        title: 'Sleep',
        icon: 'Zz',
        measures: 'Sleep start, wake time, duration, and perceived quality.',
        whyItHelps:
            'Sleep informs Routine load, Coach recovery advice, Body score, Mind score, and Goals capacity.',
        requiredData: 'Target sleep time, wake time, and manual logs.',
        optionalPermissions: 'Health Connect later for detected sleep.',
        primaryQuestion: 'Target sleep time',
        primaryOptions: const ['10:30 PM', '11:00 PM', '12:00 AM'],
        secondaryQuestion: 'Tracking mode',
        secondaryOptions: const ['Manual', 'Health Connect later'],
        showDailyCost: false,
        defaultDailyCost: '',
        defaultCheckInTime: '7:30 AM',
        detailTarget: TrackerDetailTarget.view(TrackerDetailView.sleep),
      );
    }
    if (type.contains('nutrition')) {
      return _TrackerActivationConfig(
        title: 'Nutrition',
        icon: 'Meal',
        measures: 'Meal completion, calories estimate, protein estimate.',
        whyItHelps:
            'Nutrition connects onboarding body basics, Routine eating blocks, and weekly Body consistency.',
        requiredData: 'Meal source and meal done state.',
        optionalPermissions:
            'Meal-plan import and AI meal suggestions can connect later.',
        primaryQuestion: 'Eating source',
        primaryOptions: _nutritionSourceOptions(region),
        secondaryQuestion: 'Default tracking',
        secondaryOptions: const [
          'Done only',
          'Calories estimate',
          'Protein estimate',
        ],
        showDailyCost: false,
        defaultDailyCost: '',
        defaultCheckInTime: 'After meals',
        detailTarget: TrackerDetailTarget.view(TrackerDetailView.nutrition),
      );
    }
    if (type.contains('focus')) {
      return _TrackerActivationConfig(
        title: 'Focus Timer',
        icon: 'Focus',
        measures: 'Deep work sessions, breaks, and linked routine tasks.',
        whyItHelps:
            'Focus is a Life OS pillar and helps Coach understand distraction risk from Screen Time.',
        requiredData: 'Default timer mode and routine link preference.',
        optionalPermissions: 'Usage Access improves distraction risk later.',
        primaryQuestion: 'Default mode',
        primaryOptions: const ['25/5', '45/10', 'Custom'],
        secondaryQuestion: 'Routine link',
        secondaryOptions: const ['Link to Routine tasks', 'Standalone'],
        showDailyCost: false,
        defaultDailyCost: '',
        defaultCheckInTime: 'Start of work block',
        detailTarget: TrackerDetailTarget.view(TrackerDetailView.focusTimer),
      );
    }
    if (type.contains('reading')) {
      return _generic('Reading', 'Pages, minutes, and consistency.');
    }
    if (type.contains('language')) {
      return _generic('Language Learning', 'Practice time and streak.');
    }
    if (type.contains('skill')) {
      return _generic(
        'Skill Practice',
        'Daily skill reps and project practice.',
      );
    }
    if (type.contains('skin')) {
      return _generic('Skin Care', 'Morning and night routine completion.');
    }
    return _generic(
      rawType.trim().isEmpty ? 'Custom' : rawType,
      'Custom tracker logs.',
    );
  }

  static List<String> _nutritionSourceOptions(RegionSettings region) {
    if (region.foodVocabularyMode == FoodVocabularyMode.india) {
      return const [
        'Home',
        'Hostel',
        'PG',
        'Flat / rented room',
        'Mess',
        'Staying alone',
        'Mixed',
      ];
    }
    if (region.foodVocabularyMode == FoodVocabularyMode.japan) {
      return const [
        'Home',
        'Dorm',
        'Apartment',
        'Cafeteria',
        'Convenience store / outside food',
        'Mixed',
      ];
    }
    return const [
      'Home',
      'Dorm / Hostel',
      'Shared apartment',
      'Alone / Studio',
      'Cafeteria / Dining hall',
      'Meal plan',
      'Outside food / Restaurant',
      'Mixed',
    ];
  }

  static _TrackerActivationConfig _badHabit(String title, String measures) {
    final type = title.toLowerCase().replaceAll(' ', '_');
    return _TrackerActivationConfig(
      title: title,
      icon: 'Stop',
      measures: measures,
      whyItHelps:
          'Bad habit tracking converts avoided behavior into recovery proof, Coach context, and optional Money System savings.',
      requiredData: 'Daily cost, trigger, goal, and check-in time.',
      optionalPermissions: 'Notifications later for check-in reminders.',
      primaryQuestion: 'Goal',
      primaryOptions: const ['Reduce', 'Quit', 'Track only'],
      secondaryQuestion: 'Typical trigger',
      secondaryOptions: const ['Stress', 'Boredom', 'Social', 'After meals'],
      showDailyCost: true,
      defaultDailyCost: '120',
      defaultCheckInTime: '8:30 PM',
      detailTarget: TrackerDetailTarget(
        view: TrackerDetailView.badHabit,
        trackerType: title,
        badHabitType: type,
      ),
    );
  }

  static _TrackerActivationConfig _generic(String title, String measures) {
    return _TrackerActivationConfig(
      title: title,
      icon: 'Track',
      measures: measures,
      whyItHelps:
          'This tracker gives Optivus another structured signal for Routine, Goals, Coach, and Home summaries.',
      requiredData: 'Frequency, check-in time, and completion state.',
      optionalPermissions: 'Native permission connects in backend/native pass.',
      primaryQuestion: 'Frequency',
      primaryOptions: const ['Daily', 'Weekdays', 'Custom'],
      secondaryQuestion: 'Default proof',
      secondaryOptions: const ['Done', 'Minutes', 'Count'],
      showDailyCost: false,
      defaultDailyCost: '',
      defaultCheckInTime: '8:00 PM',
      detailTarget: TrackerDetailTarget.view(TrackerDetailView.none),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final Map<String, String> items;

  const _InfoGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.entries
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(child: _BodyText(entry.value)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _QuestionBlock extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const _QuestionBlock({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: OptivusColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final active = selected == option;
            return GestureDetector(
              onTap: () => onSelected(option),
              child: LiquidPill(
                label: option,
                color: OptivusColors.trackerAccent,
                filled: active,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _BodyText extends StatelessWidget {
  final String text;

  const _BodyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w700,
        color: OptivusColors.textSecondary,
      ),
    );
  }
}

class _ActivationButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  const _ActivationButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: outlined ? Colors.white.withValues(alpha: 0.48) : color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: outlined ? color : Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
