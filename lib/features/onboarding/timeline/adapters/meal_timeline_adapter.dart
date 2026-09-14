import 'package:flutter/material.dart';
import '../../../../core/theme/optivus_colors.dart';
import '../../../../models/onboarding_draft.dart';
import '../../../routine/managers/base_timeline/widgets/base_timeline_domain_card.dart';
import '../../../routine/utils/timeline_utils.dart';
import '../models/timeline_entry.dart';
import '../models/timeline_style.dart';
import '../widgets/timeline_edit_sheet_shell.dart';
import 'timeline_feature_adapter.dart';

/// Feature adapter for Meal schedule items.
class MealTimelineAdapter
    implements TimelineFeatureAdapter<TimelineBlockDraft> {
  final Color accent;

  const MealTimelineAdapter({this.accent = OptivusColors.roseAccent});

  @override
  List<TimelineEntry> toEntries(TimelineBlockDraft block) {
    return [
      TimelineEntry(
        id: block.id,
        sourceId: block.id,
        startMinute: block.startMinute,
        endMinute: block.endMinute,
        repeatDays: block.repeatDays,
        title: _displayTitle(block),
        subtitle: block.dishes.isNotEmpty ? block.dishes.first : null,
        category: TimelineCategory.meal,
        isEditable: true,
        adapterKey: 'eating',
        minHeight: BaseTimelineDomainCard.minimumHeight(
          block,
          BaseTimelineCardDomain.eating,
        ),
      ),
    ];
  }

  @override
  TimelineEntryStyle styleForEntry(TimelineEntry entry) {
    return TimelineEntryStyle(
      accentColor: accent,
      icon: _iconForTitle(entry.title),
      badgeLabel: 'Meal',
      tags: entry.subtitle != null ? [entry.subtitle!] : const [],
    );
  }

  @override
  Future<void> onEditRequested(
    BuildContext context,
    TimelineEntry entry,
    VoidCallback onUpdated,
  ) async {}

  static String _displayTitle(TimelineBlockDraft block) {
    if (block.title.isNotEmpty &&
        block.title.toLowerCase() != 'meal' &&
        block.title.toLowerCase() != 'eating') {
      return block.title;
    }
    return switch (block.mealCategory?.toLowerCase()) {
      'breakfast' => 'Breakfast',
      'lunch' => 'Lunch',
      'dinner' => 'Dinner',
      'snack' => 'Snack',
      _ => block.title.isNotEmpty ? block.title : 'Meal',
    };
  }

  static IconData _iconForTitle(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('breakfast')) return Icons.wb_sunny_rounded;
    if (lower.contains('lunch')) return Icons.lunch_dining_rounded;
    if (lower.contains('dinner')) return Icons.dinner_dining_rounded;
    if (lower.contains('snack')) return Icons.cookie_rounded;
    return Icons.restaurant_rounded;
  }

  static Future<bool?> showMealEditSheet({
    required BuildContext context,
    required TimelineBlockDraft block,
    required Future<bool> Function(TimelineBlockDraft updated) onSave,
    Color accent = OptivusColors.roseAccent,
  }) {
    final titleController = TextEditingController(text: _displayTitle(block));
    final dishesController = TextEditingController(
      text: block.dishes.join('\n'),
    );
    var startMinute = block.startMinute;
    var endMinute = block.endMinute;
    final selectedDays = Set<int>.from(
      block.repeatDays.where((day) => day >= 1 && day <= 7),
    );

    return TimelineEditSheetShell.show<bool>(
      context: context,
      title: 'Edit Meal',
      subtitle: 'Update the meal name, dishes, and time',
      accent: accent,
      onSave: () async {
        final title = titleController.text.trim();
        final dishes = dishesController.text
            .split('\n')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false);
        if (title.isEmpty) throw Exception('Meal name is required.');
        if (dishes.isEmpty) throw Exception('Add at least one dish.');
        if (endMinute <= startMinute) {
          throw Exception('End time must be after start time.');
        }
        if (selectedDays.isEmpty) {
          throw Exception('Select at least one repeat day.');
        }
        return onSave(
          block.copyWith(
            title: title,
            dishes: dishes,
            startMinute: startMinute,
            endMinute: endMinute,
            repeatDays: selectedDays.toList()..sort(),
          ),
        );
      },
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('timeline-edit-meal-title-field'),
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Meal name'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('timeline-edit-meal-dishes-field'),
              controller: dishesController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Dishes (one per line)',
              ),
            ),
            const SizedBox(height: 12),
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
                      'Start: ${TimelineUtils.formatMinute(startMinute)}',
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
                      'End: ${TimelineUtils.formatMinute(endMinute)}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'REPEAT DAYS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textSecondary,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(7, (index) {
                final day = index + 1;
                final selected = selectedDays.contains(day);
                return FilterChip(
                  label: Text(
                    const [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun',
                    ][index],
                  ),
                  selected: selected,
                  selectedColor: accent.withValues(alpha: .25),
                  onSelected: (value) => setSheetState(() {
                    if (value) {
                      selectedDays.add(day);
                    } else {
                      selectedDays.remove(day);
                    }
                  }),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
