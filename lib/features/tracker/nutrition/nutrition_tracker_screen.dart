import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/routine/providers/routine_navigation_provider.dart';
import 'package:optivus/features/tracker/widgets/tracker_components.dart';
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/models/tracker_models.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/region_settings_provider.dart';

class NutritionTrackerScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const NutritionTrackerScreen({super.key, required this.onBack});

  @override
  ConsumerState<NutritionTrackerScreen> createState() =>
      _NutritionTrackerScreenState();
}

class _NutritionTrackerScreenState
    extends ConsumerState<NutritionTrackerScreen> {
  MealSource _source = MealSource.home;
  final _manualMeal = TextEditingController();
  final _calories = TextEditingController(text: '450');
  final _protein = TextEditingController(text: '24');

  @override
  void dispose() {
    _manualMeal.dispose();
    _calories.dispose();
    _protein.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(mockTrackerProvider).nutritionLogs;
    final region = ref.watch(regionSettingsProvider);
    final doneCount = logs.where((log) => log.done).length;
    final calories = logs.fold<double>(
      0,
      (sum, log) => sum + (log.done ? log.estimatedCalories : 0),
    );
    final protein = logs.fold<double>(
      0,
      (sum, log) => sum + (log.done ? log.estimatedProtein : 0),
    );

    return LiquidDetailScaffold(
      eyebrow: 'Tracker',
      title: 'Nutrition',
      subtitle: 'Meals, source, estimates, and Routine eating links.',
      accentColor: OptivusColors.trackerAccent,
      onBack: widget.onBack,
      children: [
        TrackerGlassCard(
          padding: const EdgeInsets.all(22),
          radius: 28,
          opacity: 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Today meals',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.sub,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$doneCount / 4 done',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  LiquidPill(
                    label: '${calories.toStringAsFixed(0)} kcal',
                    color: OptivusColors.roseAccent,
                  ),
                  LiquidPill(
                    label: '${protein.toStringAsFixed(0)}g protein',
                    color: OptivusColors.success,
                  ),
                  LiquidPill(
                    label: _sourceLabel(_source, region),
                    color: OptivusColors.trackerAccent,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LiquidDetailSection(
          title: 'Meal source',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MealSource.values.map((source) {
                return GestureDetector(
                  onTap: () => setState(() => _source = source),
                  child: LiquidPill(
                    label: _sourceLabel(source, region),
                    color: OptivusColors.trackerAccent,
                    filled: _source == source,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              _sourceHelp(region),
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textSecondary,
              ),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Meal check-ins',
          children: MealType.values.map(_mealRow).toList(),
        ),
        LiquidDetailSection(
          title: 'Add manual meal',
          children: [
            TextField(
              controller: _manualMeal,
              decoration: _decoration('Meal name or dishes'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _calories,
                    keyboardType: TextInputType.number,
                    decoration: _decoration('Calories'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _protein,
                    keyboardType: TextInputType.number,
                    decoration: _decoration('Protein g'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _NutritionAction(
              label: 'Save as snack',
              color: OptivusColors.trackerAccent,
              onTap: () => _logMeal(MealType.snacks, done: true),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Weekly consistency',
          children: [
            SizedBox(
              height: 86,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [0.75, 0.5, 1.0, 0.75, 0.8, 0.6, 0.9]
                    .map(
                      (value) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FractionallySizedBox(
                            heightFactor: value,
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              decoration: BoxDecoration(
                                color: OptivusColors.success,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Routine link',
          children: [
            LiquidActionRow(
              icon: Icons.restaurant_rounded,
              title: 'Open Routine Eating Setup',
              subtitle:
                  'Eating times stay owned by Routine. Nutrition owns meal logs.',
              accentColor: OptivusColors.roseAccent,
              onTap: () {
                ref.read(appNavigationProvider.notifier).goToRoutine();
                ref
                    .read(routineDetailViewRequestProvider.notifier)
                    .state = const RoutineDetailTarget(
                  view: RoutineDetailView.eatingSetup,
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  String _sourceHelp(RegionSettings region) {
    return switch (_source) {
      MealSource.home =>
        'Home eating shows time and done state by default. Estimates stay optional.',
      MealSource.hostel || MealSource.pg || MealSource.mess =>
        region.foodVocabularyMode == FoodVocabularyMode.india
            ? 'Hostel, PG, and mess modes can show dishes from an imported mess sheet when available.'
            : 'Dorm, cafeteria, and dining hall modes can show imported meal-plan dishes when available.',
      MealSource.flat =>
        region.foodVocabularyMode == FoodVocabularyMode.india
            ? 'Flat or staying-alone mode can show AI meal plan estimates in the backend pass.'
            : 'Shared apartment or studio mode can show meal plan estimates in the backend pass.',
      MealSource.mixed =>
        'Mixed mode keeps source per meal so backend can preserve context.',
    };
  }

  String _sourceLabel(MealSource source, RegionSettings region) {
    if (region.foodVocabularyMode == FoodVocabularyMode.india) {
      return switch (source) {
        MealSource.home => 'Home',
        MealSource.hostel => 'Hostel',
        MealSource.pg => 'PG',
        MealSource.mess => 'Mess',
        MealSource.flat => 'Flat / rented room',
        MealSource.mixed => 'Mixed',
      };
    }
    if (region.foodVocabularyMode == FoodVocabularyMode.japan) {
      return switch (source) {
        MealSource.home => 'Home',
        MealSource.hostel => 'Dorm',
        MealSource.pg => 'Apartment',
        MealSource.mess => 'Cafeteria',
        MealSource.flat => 'Convenience store / outside',
        MealSource.mixed => 'Mixed',
      };
    }
    return switch (source) {
      MealSource.home => 'Home',
      MealSource.hostel => 'Dorm / Hostel',
      MealSource.pg => 'Shared apartment',
      MealSource.mess => 'Cafeteria / Dining hall',
      MealSource.flat => 'Alone / Studio',
      MealSource.mixed => 'Mixed',
    };
  }

  Widget _mealRow(MealType meal) {
    final logs = ref.watch(mockTrackerProvider).nutritionLogs;
    NutritionLog? existing;
    for (final log in logs) {
      if (log.mealType == meal) existing = log;
    }
    return LiquidActionRow(
      icon: Icons.restaurant_outlined,
      title: _mealLabel(meal),
      subtitle: existing == null
          ? 'Not logged'
          : '${existing.estimatedCalories.toStringAsFixed(0)} kcal, ${existing.estimatedProtein.toStringAsFixed(0)}g protein',
      accentColor: existing?.done == true
          ? OptivusColors.success
          : OptivusColors.trackerAccent,
      trailing: _NutritionAction(
        label: existing?.done == true ? 'Done' : 'Mark done',
        color: existing?.done == true
            ? OptivusColors.success
            : OptivusColors.trackerAccent,
        compact: true,
        onTap: () => _logMeal(meal, done: true),
      ),
    );
  }

  String _mealLabel(MealType meal) {
    return switch (meal) {
      MealType.breakfast => 'Breakfast',
      MealType.lunch => 'Lunch',
      MealType.snacks => 'Snacks',
      MealType.dinner => 'Dinner',
    };
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.72),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _logMeal(MealType meal, {required bool done}) {
    final now = DateTime.now();
    ref
        .read(mockTrackerProvider.notifier)
        .upsertNutritionLog(
          NutritionLog(
            id: 'meal-${meal.name}-${_dateKey(now)}',
            mealType: meal,
            loggedAt: now,
            dateKey: _dateKey(now),
            done: done,
            estimatedCalories: double.tryParse(_calories.text) ?? 0,
            estimatedProtein: double.tryParse(_protein.text) ?? 0,
            source: _source,
            dishes: _manualMeal.text.trim().isEmpty
                ? _defaultDishes(meal)
                : [_manualMeal.text.trim()],
          ),
        );
  }

  List<String> _defaultDishes(MealType meal) {
    return switch (meal) {
      MealType.breakfast => const ['Breakfast plate'],
      MealType.lunch => const ['Lunch plate'],
      MealType.snacks => const ['Snack'],
      MealType.dinner => const ['Dinner plate'],
    };
  }
}

class _NutritionAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  const _NutritionAction({
    required this.label,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 11 : 16,
          vertical: compact ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
