import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_presentation_utils.dart';

class EatingPlanSettingsResult {
  final String? goal;
  final int mealsPerDay;
  final String? eatingMode;
  final String? foodType;
  final String? foodStyleCustomText;
  final int breakfastMinute;
  final int? extraSnackMinute;
  final int lunchMinute;
  final int? snackMinute;
  final int dinnerMinute;
  final int? targetCalories;
  final int? targetProtein;
  final bool shouldRegenerate;

  const EatingPlanSettingsResult({
    required this.goal,
    required this.mealsPerDay,
    required this.eatingMode,
    required this.foodType,
    required this.foodStyleCustomText,
    required this.breakfastMinute,
    required this.extraSnackMinute,
    required this.lunchMinute,
    required this.snackMinute,
    required this.dinnerMinute,
    required this.targetCalories,
    required this.targetProtein,
    required this.shouldRegenerate,
  });
}

class EatingPlanSettingsSheet extends StatefulWidget {
  final String title;
  final String regenerateActionLabel;
  final bool isNew;
  final String? initialGoal;
  final int? initialMealsPerDay;
  final String? initialEatingMode;
  final String? initialFoodType;
  final String? initialFoodStyleCustomText;
  final int? initialBreakfastMinute;
  final int? initialLunchMinute;
  final int? initialDinnerMinute;
  final int? initialSnackMinute;
  final int? initialExtraSnackMinute;
  final int? initialTargetCalories;
  final int? initialTargetProtein;
  final bool showRegenerateAction;

  const EatingPlanSettingsSheet({
    super.key,
    this.title = 'Build Balanced Meal Plan',
    this.regenerateActionLabel = 'Generate Balanced Plan',
    this.isNew = false,
    this.initialGoal,
    this.initialMealsPerDay,
    this.initialEatingMode,
    this.initialFoodType,
    this.initialFoodStyleCustomText,
    this.initialBreakfastMinute,
    this.initialLunchMinute,
    this.initialDinnerMinute,
    this.initialSnackMinute,
    this.initialExtraSnackMinute,
    this.initialTargetCalories,
    this.initialTargetProtein,
    this.showRegenerateAction = true,
  });

  static Future<EatingPlanSettingsResult?> show(
    BuildContext context, {
    String title = 'Build Balanced Meal Plan',
    String regenerateActionLabel = 'Generate Balanced Plan',
    bool isNew = false,
    String? initialGoal,
    int? initialMealsPerDay,
    String? initialEatingMode,
    String? initialFoodType,
    String? initialFoodStyleCustomText,
    int? initialBreakfastMinute,
    int? initialLunchMinute,
    int? initialDinnerMinute,
    int? initialSnackMinute,
    int? initialExtraSnackMinute,
    int? initialTargetCalories,
    int? initialTargetProtein,
    bool showRegenerateAction = true,
  }) {
    return showModalBottomSheet<EatingPlanSettingsResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OptivusColors.backgroundBottom,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => EatingPlanSettingsSheet(
        title: title,
        regenerateActionLabel: regenerateActionLabel,
        isNew: isNew,
        initialGoal: initialGoal,
        initialMealsPerDay: initialMealsPerDay,
        initialEatingMode: initialEatingMode,
        initialFoodType: initialFoodType,
        initialFoodStyleCustomText: initialFoodStyleCustomText,
        initialBreakfastMinute: initialBreakfastMinute,
        initialLunchMinute: initialLunchMinute,
        initialDinnerMinute: initialDinnerMinute,
        initialSnackMinute: initialSnackMinute,
        initialExtraSnackMinute: initialExtraSnackMinute,
        initialTargetCalories: initialTargetCalories,
        initialTargetProtein: initialTargetProtein,
        showRegenerateAction: showRegenerateAction,
      ),
    );
  }

  @override
  State<EatingPlanSettingsSheet> createState() =>
      _EatingPlanSettingsSheetState();
}

class _EatingPlanSettingsSheetState extends State<EatingPlanSettingsSheet> {
  late String _goal;
  late int _mealsPerDay;
  String? _eatingMode;
  String? _foodType;
  late TextEditingController _customStyleController;
  late int _breakfastMinute;
  late int _lunchMinute;
  late int _dinnerMinute;
  late int _snackMinute;
  late int _extraSnackMinute;
  late TextEditingController _caloriesController;
  late TextEditingController _proteinController;
  bool _showNutritionOverrides = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _showNutritionOverrides =
        (widget.initialTargetCalories != null &&
            widget.initialTargetCalories! > 0) ||
        (widget.initialTargetProtein != null &&
            widget.initialTargetProtein! > 0);
    _goal = (widget.initialGoal?.isNotEmpty == true)
        ? widget.initialGoal!.toLowerCase()
        : 'maintain';
    _mealsPerDay = widget.initialMealsPerDay ?? 3;
    _eatingMode = (widget.initialEatingMode?.isNotEmpty == true)
        ? widget.initialEatingMode!.toLowerCase()
        : (widget.isNew ? 'balanced' : null);
    _foodType = (widget.initialFoodType?.isNotEmpty == true)
        ? widget.initialFoodType!.toLowerCase()
        : (widget.isNew ? 'mixed' : null);
    _customStyleController = TextEditingController(
      text: widget.initialFoodStyleCustomText ?? '',
    );
    _breakfastMinute = widget.initialBreakfastMinute ?? 480;
    _lunchMinute = widget.initialLunchMinute ?? 780;
    _dinnerMinute = widget.initialDinnerMinute ?? 1230;
    _snackMinute = widget.initialSnackMinute ?? 1020;
    _extraSnackMinute = widget.initialExtraSnackMinute ?? 660;
    _caloriesController = TextEditingController(
      text: widget.initialTargetCalories != null
          ? widget.initialTargetCalories.toString()
          : '',
    );
    _proteinController = TextEditingController(
      text: widget.initialTargetProtein != null
          ? widget.initialTargetProtein.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _customStyleController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_eatingMode == 'custom' && _customStyleController.text.trim().isEmpty) {
      return 'Please describe your custom food style.';
    }

    if (_breakfastMinute < 0 || _breakfastMinute > 1439) {
      return 'Breakfast time must be within a valid day range.';
    }
    if (_lunchMinute < 0 || _lunchMinute > 1439) {
      return 'Lunch time must be within a valid day range.';
    }
    if (_dinnerMinute < 0 || _dinnerMinute > 1439) {
      return 'Dinner time must be within a valid day range.';
    }

    if (_mealsPerDay == 3) {
      if (_lunchMinute <= _breakfastMinute) {
        return 'Lunch must be scheduled after breakfast.';
      }
      if (_lunchMinute - _breakfastMinute < 120) {
        return 'Meals must be scheduled at least 2 hours apart.';
      }
      if (_dinnerMinute <= _lunchMinute) {
        return 'Dinner must be scheduled after lunch.';
      }
      if (_dinnerMinute - _lunchMinute < 120) {
        return 'Meals must be scheduled at least 2 hours apart.';
      }
    } else if (_mealsPerDay == 4) {
      if (_lunchMinute <= _breakfastMinute || _lunchMinute - _breakfastMinute < 120) {
        return 'Lunch must be scheduled at least 2 hours after breakfast.';
      }
      if (_snackMinute <= _lunchMinute || _snackMinute - _lunchMinute < 120) {
        return 'Snack must be scheduled at least 2 hours after lunch.';
      }
      if (_dinnerMinute <= _snackMinute || _dinnerMinute - _snackMinute < 120) {
        return 'Dinner must be scheduled at least 2 hours after snack.';
      }
    } else if (_mealsPerDay == 5) {
      if (_extraSnackMinute <= _breakfastMinute || _extraSnackMinute - _breakfastMinute < 120) {
        return 'Morning snack must be scheduled at least 2 hours after breakfast.';
      }
      if (_lunchMinute <= _extraSnackMinute || _lunchMinute - _extraSnackMinute < 120) {
        return 'Lunch must be scheduled at least 2 hours after morning snack.';
      }
      if (_snackMinute <= _lunchMinute || _snackMinute - _lunchMinute < 120) {
        return 'Afternoon snack must be scheduled at least 2 hours after lunch.';
      }
      if (_dinnerMinute <= _snackMinute || _dinnerMinute - _snackMinute < 120) {
        return 'Dinner must be scheduled at least 2 hours after afternoon snack.';
      }
    }

    return null;
  }

  void _submit({required bool regenerate}) {
    final err = _validate();
    if (err != null) {
      setState(() {
        _validationError = err;
      });
      return;
    }

    final rawCal = int.tryParse(_caloriesController.text.trim());
    final rawProt = int.tryParse(_proteinController.text.trim());

    final result = EatingPlanSettingsResult(
      goal: _goal,
      mealsPerDay: _mealsPerDay,
      eatingMode: regenerate ? (_eatingMode ?? 'balanced') : _eatingMode,
      foodType: regenerate ? (_foodType ?? 'mixed') : _foodType,
      foodStyleCustomText: _eatingMode == 'custom'
          ? _customStyleController.text.trim()
          : null,
      breakfastMinute: _breakfastMinute,
      extraSnackMinute: _mealsPerDay == 5 ? _extraSnackMinute : null,
      lunchMinute: _lunchMinute,
      snackMinute: (_mealsPerDay == 4 || _mealsPerDay == 5) ? _snackMinute : null,
      dinnerMinute: _dinnerMinute,
      targetCalories: (rawCal != null && rawCal > 0) ? rawCal : null,
      targetProtein: (rawProt != null && rawProt > 0) ? rawProt : null,
      shouldRegenerate: regenerate,
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.90;

    return SafeArea(
      bottom: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: OptivusColors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: OptivusColors.roseAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: OptivusColors.roseAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: OptivusColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Configure goals, cuisine, meals per day, and timing',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: OptivusColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_validationError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: OptivusColors.danger.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: OptivusColors.danger.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: OptivusColors.danger,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _validationError!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: OptivusColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Settings body
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Goal
                      _buildHeader('Goal'),
                      const SizedBox(height: 6),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'lose', label: Text('Lose')),
                          ButtonSegment(value: 'maintain', label: Text('Maintain')),
                          ButtonSegment(value: 'gain', label: Text('Gain')),
                        ],
                        selected: {_goal},
                        onSelectionChanged: (s) {
                          setState(() {
                            _goal = s.first;
                            _validationError = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Meals per day
                      _buildHeader('Meals per Day'),
                      const SizedBox(height: 6),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 3, label: Text('3 meals')),
                          ButtonSegment(value: 4, label: Text('4 meals')),
                          ButtonSegment(value: 5, label: Text('5 meals')),
                        ],
                        selected: {_mealsPerDay},
                        onSelectionChanged: (s) {
                          setState(() {
                            _mealsPerDay = s.first;
                            _validationError = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Food Culture / Eating Mode
                      _buildHeader('Food Culture & Style'),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ('balanced', 'Balanced'),
                          ('mediterranean', 'Mediterranean'),
                          ('india', 'Indian Cuisine'),
                          ('high_protein', 'High Protein'),
                          ('custom', 'Custom Style'),
                        ].map((item) {
                          final isSel = _eatingMode == item.$1;
                          return ChoiceChip(
                            label: Text(item.$2),
                            selected: isSel,
                            selectedColor: OptivusColors.roseAccent.withValues(alpha: 0.18),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                              color: isSel ? OptivusColors.roseAccent : OptivusColors.textSecondary,
                            ),
                            onSelected: (sel) {
                              if (sel) {
                                setState(() {
                                  _eatingMode = item.$1;
                                  _validationError = null;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),

                      if (_eatingMode == 'custom') ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _customStyleController,
                          decoration: const InputDecoration(
                            labelText: 'Describe Custom Food Style',
                            hintText: 'e.g. Keto-friendly, Asian stir-fries, plant-forward',
                          ),
                          onChanged: (_) {
                            if (_validationError != null) {
                              setState(() => _validationError = null);
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Dietary Preference
                      _buildHeader('Dietary Preference'),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ('mixed', 'Mixed / Any'),
                          ('veg', 'Vegetarian'),
                          ('vegan', 'Vegan'),
                          ('eggetarian', 'Eggetarian'),
                          ('non_veg', 'Non-Vegetarian'),
                        ].map((item) {
                          final isSel = _foodType == item.$1;
                          return ChoiceChip(
                            label: Text(item.$2),
                            selected: isSel,
                            selectedColor: OptivusColors.roseAccent.withValues(alpha: 0.18),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                              color: isSel ? OptivusColors.roseAccent : OptivusColors.textSecondary,
                            ),
                            onSelected: (sel) {
                              if (sel) {
                                setState(() {
                                  _foodType = item.$1;
                                  _validationError = null;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Preferred Meal Times
                      _buildHeader('Preferred Meal Times (Spacing ≥ 2h)'),
                      const SizedBox(height: 8),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: OptivusColors.borderSubtle),
                        ),
                        leading: const Icon(Icons.wb_sunny_rounded, color: OptivusColors.roseAccent),
                        title: const Text('Breakfast'),
                        trailing: Text(
                          EatingPresentationUtils.formatTime(_breakfastMinute),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: _breakfastMinute ~/ 60,
                              minute: _breakfastMinute % 60,
                            ),
                          );
                          if (picked != null) {
                            setState(() {
                              _breakfastMinute = picked.hour * 60 + picked.minute;
                              _validationError = null;
                            });
                          }
                        },
                      ),
                      if (_mealsPerDay == 5) ...[
                        const SizedBox(height: 8),
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: OptivusColors.borderSubtle),
                          ),
                          leading: const Icon(Icons.cookie_rounded, color: OptivusColors.roseAccent),
                          title: const Text('Morning Snack'),
                          trailing: Text(
                            EatingPresentationUtils.formatTime(_extraSnackMinute),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: _extraSnackMinute ~/ 60,
                                minute: _extraSnackMinute % 60,
                              ),
                            );
                            if (picked != null) {
                              setState(() {
                                _extraSnackMinute = picked.hour * 60 + picked.minute;
                                _validationError = null;
                              });
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: 8),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: OptivusColors.borderSubtle),
                        ),
                        leading: const Icon(Icons.lunch_dining_rounded, color: OptivusColors.roseAccent),
                        title: const Text('Lunch'),
                        trailing: Text(
                          EatingPresentationUtils.formatTime(_lunchMinute),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: _lunchMinute ~/ 60,
                              minute: _lunchMinute % 60,
                            ),
                          );
                          if (picked != null) {
                            setState(() {
                              _lunchMinute = picked.hour * 60 + picked.minute;
                              _validationError = null;
                            });
                          }
                        },
                      ),
                      if (_mealsPerDay == 4 || _mealsPerDay == 5) ...[
                        const SizedBox(height: 8),
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: OptivusColors.borderSubtle),
                          ),
                          leading: const Icon(Icons.cookie_rounded, color: OptivusColors.roseAccent),
                          title: const Text('Afternoon Snack'),
                          trailing: Text(
                            EatingPresentationUtils.formatTime(_snackMinute),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: _snackMinute ~/ 60,
                                minute: _snackMinute % 60,
                              ),
                            );
                            if (picked != null) {
                              setState(() {
                                _snackMinute = picked.hour * 60 + picked.minute;
                                _validationError = null;
                              });
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: 8),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: OptivusColors.borderSubtle),
                        ),
                        leading: const Icon(Icons.dinner_dining_rounded, color: OptivusColors.roseAccent),
                        title: const Text('Dinner'),
                        trailing: Text(
                          EatingPresentationUtils.formatTime(_dinnerMinute),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: _dinnerMinute ~/ 60,
                              minute: _dinnerMinute % 60,
                            ),
                          );
                          if (picked != null) {
                            setState(() {
                              _dinnerMinute = picked.hour * 60 + picked.minute;
                              _validationError = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Optional Nutrition Targets
                      _buildHeader('Target Nutrition (Optional Overrides)'),
                      const SizedBox(height: 8),
                      if (!_showNutritionOverrides)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: const Text(
                            'Customize calorie & protein targets',
                            style: TextStyle(fontSize: 12),
                          ),
                          onPressed: () =>
                              setState(() => _showNutritionOverrides = true),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _caloriesController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Daily Calories (kcal)',
                                  hintText: 'Auto-calculated',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _proteinController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Daily Protein (g)',
                                  hintText: 'Auto-calculated',
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),

                      // Bottom Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => _submit(regenerate: false),
                              child: const Text('Save Settings'),
                            ),
                          ),
                          if (widget.showRegenerateAction) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: OptivusColors.roseAccent,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  widget.regenerateActionLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                onPressed: () => _submit(regenerate: true),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: OptivusColors.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}
