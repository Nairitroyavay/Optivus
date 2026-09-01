import 'package:flutter/material.dart';
import '../../../../core/theme/optivus_colors.dart';
import '../../../../models/onboarding_draft.dart';
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
        minHeight: 72.0 + block.dishes.length * 40.0,
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
        return onSave(
          block.copyWith(
            title: title,
            dishes: dishes,
            startMinute: startMinute,
            endMinute: endMinute,
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
          ],
        ),
      ),
    );
  }

  /// Opens the details sheet for a meal timeline item.
  static Future<void> showMealDetailsSheet({
    required BuildContext context,
    required TimelineBlockDraft block,
    Color accent = OptivusColors.roseAccent,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_iconForTitle(_displayTitle(block)), color: accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _displayTitle(block),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: OptivusColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  TimelineUtils.formatTimeRange(
                    block.startMinute,
                    block.endMinute,
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OptivusColors.textSecondary,
                  ),
                ),
                if (block.dishes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'MENU / DISHES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: accent,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final dish in block.dishes)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            dish,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: OptivusColors.textPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
