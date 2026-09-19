import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/timeline/widgets/timeline_edit_sheet_shell.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_presentation_utils.dart';
import 'package:optivus/models/onboarding_draft.dart';

/// Modal sheet for editing or creating a meal block on the Base Timeline.
///
/// Fully supports true null clearing for mealSlot, mealCategory, calories,
/// protein, location, and notes via TimelineBlockDraft.copyWith.
class EatingMealEditSheet {
  static Future<bool?> show({
    required BuildContext context,
    required TimelineBlockDraft block,
    required Future<bool> Function(TimelineBlockDraft updated) onSave,
    VoidCallback? onDelete,
    Color accent = OptivusColors.roseAccent,
    bool? isNew,
    String? saveLabel,
  }) {
    final titleController = TextEditingController(text: block.title);
    final dishesController = TextEditingController(
      text: block.dishes.join('\n'),
    );
    final caloriesController = TextEditingController(
      text: block.calories != null ? block.calories.toString() : '',
    );
    final proteinController = TextEditingController(
      text: block.protein != null ? block.protein!.round().toString() : '',
    );
    final locationController = TextEditingController(
      text: block.location ?? '',
    );
    final notesController = TextEditingController(text: block.notes ?? '');

    var startMinute = block.startMinute;
    var endMinute = block.endMinute;
    var selectedSlot = block.mealSlot?.trim().toLowerCase();
    var currentCategory = block.mealCategory?.trim().toLowerCase();
    final selectedDays = Set<int>.from(
      block.repeatDays.where((day) => day >= 1 && day <= 7),
    );

    final effectiveIsNew =
        isNew ?? (block.id.startsWith('new-') || block.title.trim().isEmpty);

    const availableSlots = [
      ('breakfast', 'Breakfast'),
      ('morning_snack', 'Morning Snack'),
      ('lunch', 'Lunch'),
      ('afternoon_snack', 'Afternoon Snack'),
      ('dinner', 'Dinner'),
    ];

    return TimelineEditSheetShell.show<bool>(
      context: context,
      title: effectiveIsNew ? 'Add Meal' : 'Edit Meal',
      subtitle: effectiveIsNew
          ? 'Configure dishes, timing, and days for this meal'
          : 'Update meal name, dishes, timing, and nutrition',
      accent: accent,
      saveLabel: saveLabel ?? (effectiveIsNew ? 'Add meal' : 'Save'),
      onSave: () async {
        final title = titleController.text.trim();
        var dishes = dishesController.text
            .split('\n')
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty)
            .toList();

        if (title.isEmpty) {
          throw Exception('Meal name is required.');
        }
        if (dishes.isEmpty) {
          throw Exception('At least one dish is required.');
        }
        if (endMinute <= startMinute) {
          throw Exception('End time must be after start time.');
        }
        if (selectedDays.isEmpty) {
          throw Exception('Select at least one repeat day.');
        }

        final calText = caloriesController.text.trim();
        final rawCal = int.tryParse(calText);
        final clearCal = calText.isEmpty || rawCal == null || rawCal <= 0;

        final protText = proteinController.text.trim();
        final rawProt = double.tryParse(protText);
        final clearProt = protText.isEmpty || rawProt == null || rawProt <= 0;

        final locText = locationController.text.trim();
        final clearLoc = locText.isEmpty;

        final notesText = notesController.text.trim();
        final clearNotes = notesText.isEmpty;

        final clearSlot = selectedSlot == null || selectedSlot!.isEmpty;
        final String? finalCategory;
        if (currentCategory != null && currentCategory.isNotEmpty) {
          finalCategory = currentCategory;
        } else if (!clearSlot) {
          finalCategory = switch (selectedSlot!) {
            'breakfast' => 'breakfast',
            'lunch' => 'lunch',
            'dinner' => 'dinner',
            'morning_snack' || 'afternoon_snack' => 'snack',
            _ => selectedSlot,
          };
        } else {
          finalCategory = null;
        }

        final updated = block.copyWith(
          title: title,
          dishes: dishes,
          startMinute: startMinute,
          endMinute: endMinute,
          repeatDays: selectedDays.toList()..sort(),
          mealSlot: clearSlot ? null : selectedSlot,
          clearMealSlot: clearSlot,
          mealCategory: finalCategory,
          clearMealCategory: finalCategory == null,
          calories: clearCal ? null : rawCal.toDouble(),
          clearCalories: clearCal,
          protein: clearProt ? null : rawProt,
          clearProtein: clearProt,
          location: clearLoc ? null : locText,
          clearLocation: clearLoc,
          notes: clearNotes ? null : notesText,
          clearNotes: clearNotes,
        );

        return onSave(updated);
      },
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meal name
            TextField(
              key: const ValueKey('timeline-edit-meal-title-field'),
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Meal name',
                hintText: 'e.g. Breakfast, Post-workout meal',
              ),
            ),
            const SizedBox(height: 14),

            // Slot selector chips
            const Text(
              'MEAL SLOT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: availableSlots.map((slot) {
                final isSelected = selectedSlot == slot.$1;
                return FilterChip(
                  label: Text(slot.$2),
                  selected: isSelected,
                  selectedColor: accent.withValues(alpha: 0.18),
                  checkmarkColor: accent,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? accent : OptivusColors.textSecondary,
                  ),
                  onSelected: (selected) {
                    setSheetState(() {
                      selectedSlot = selected ? slot.$1 : null;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Dishes field
            TextField(
              key: const ValueKey('timeline-edit-meal-dishes-field'),
              controller: dishesController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Dishes & Items (one per line)',
                hintText: 'Oatmeal\nBerries\nAlmond butter',
              ),
            ),
            const SizedBox(height: 14),

            // Nutrition estimates
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('eating-edit-meal-calories'),
                    controller: caloriesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Calories (kcal)',
                      hintText: 'Optional',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const ValueKey('eating-edit-meal-protein'),
                    controller: proteinController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Protein (g)',
                      hintText: 'Optional',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Timing buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: startMinute ~/ 60,
                          minute: startMinute % 60,
                        ),
                      );
                      if (picked != null) {
                        setSheetState(
                          () => startMinute = picked.hour * 60 + picked.minute,
                        );
                      }
                    },
                    child: Text(
                      'Start: ${EatingPresentationUtils.formatTime(startMinute)}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: endMinute ~/ 60,
                          minute: endMinute % 60,
                        ),
                      );
                      if (picked != null) {
                        setSheetState(
                          () => endMinute = picked.hour * 60 + picked.minute,
                        );
                      }
                    },
                    child: Text(
                      'End: ${EatingPresentationUtils.formatTime(endMinute)}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Repeat Days
            const Text(
              'REPEAT DAYS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    label: Text(
                      const [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun',
                      ][day - 1],
                    ),
                    selected: selectedDays.contains(day),
                    selectedColor: accent.withValues(alpha: 0.18),
                    checkmarkColor: accent,
                    labelStyle: TextStyle(
                      fontWeight: selectedDays.contains(day)
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: selectedDays.contains(day)
                          ? accent
                          : OptivusColors.textSecondary,
                    ),
                    onSelected: (selected) {
                      setSheetState(() {
                        if (selected) {
                          selectedDays.add(day);
                        } else {
                          selectedDays.remove(day);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Location field
            TextField(
              key: const ValueKey('eating-edit-meal-location'),
              controller: locationController,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                hintText: 'e.g. Home, Office, Campus dining',
              ),
            ),
            const SizedBox(height: 14),

            // Notes field
            TextField(
              key: const ValueKey('eating-edit-meal-notes'),
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes & Reminders (optional)',
                hintText: 'e.g. Prep night before, take vitamins',
              ),
            ),

            // Delete meal action
            if (onDelete != null && !effectiveIsNew) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: OptivusColors.danger,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete this Meal'),
                  onPressed: () {
                    showDialog<bool>(
                      context: context,
                      builder: (dlgCtx) => AlertDialog(
                        title: const Text('Delete Meal?'),
                        content: Text(
                          'Are you sure you want to remove "${titleController.text.trim()}" from your eating schedule?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dlgCtx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: OptivusColors.danger,
                            ),
                            onPressed: () => Navigator.pop(dlgCtx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    ).then((confirmed) {
                      if (confirmed == true && sheetContext.mounted) {
                        Navigator.pop(sheetContext);
                        onDelete();
                      }
                    });
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
