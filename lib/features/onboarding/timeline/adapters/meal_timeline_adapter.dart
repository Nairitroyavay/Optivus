import 'package:flutter/material.dart';
import '../../../../core/theme/optivus_colors.dart';
import '../../../../models/onboarding_draft.dart';
import '../../../routine/managers/base_timeline/widgets/base_timeline_domain_card.dart';
import '../../../routine/managers/base_timeline/widgets/eating_meal_edit_sheet.dart';
import '../models/timeline_entry.dart';
import '../models/timeline_style.dart';
import 'timeline_feature_adapter.dart';

/// Feature adapter for Meal schedule items.
class MealTimelineAdapter
    implements TimelineFeatureAdapter<TimelineBlockDraft> {
  final Color accent;
  final double contentWidth;
  final double textScale;

  const MealTimelineAdapter({
    this.accent = OptivusColors.roseAccent,
    this.contentWidth = 220.0,
    this.textScale = 1.0,
  });

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
          contentWidth: contentWidth,
          textScale: textScale,
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
    return EatingMealEditSheet.show(
      context: context,
      block: block,
      onSave: onSave,
      accent: accent,
    );
  }
}
