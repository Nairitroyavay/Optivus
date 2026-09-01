import 'package:flutter/material.dart';
import '../../../../core/theme/optivus_colors.dart';
import 'timeline_entry.dart';

/// Visual presentation styling for a timeline entry.
@immutable
class TimelineEntryStyle {
  /// Base accent color for the block container and border.
  final Color accentColor;

  /// Optional icon displayed on the block.
  final IconData? icon;

  /// Optional detail tags (e.g. dishes, products, steps, room).
  final List<String> tags;

  /// Optional formatted time range label (e.g. "9:00 AM - 10:30 AM").
  final String? timeRangeLabel;

  /// Optional semantic badge label (e.g. "Breakfast", "Work", "Lecture").
  final String? badgeLabel;

  const TimelineEntryStyle({
    required this.accentColor,
    this.icon,
    this.tags = const [],
    this.timeRangeLabel,
    this.badgeLabel,
  });

  /// Default styling for a given category if not customized.
  factory TimelineEntryStyle.defaultForCategory(TimelineCategory category) {
    return switch (category) {
      TimelineCategory.classes => const TimelineEntryStyle(
        accentColor: OptivusColors.aquaAccent,
        icon: Icons.school_rounded,
        badgeLabel: 'Class',
      ),
      TimelineCategory.work => const TimelineEntryStyle(
        accentColor: OptivusColors.brandAccent,
        icon: Icons.work_rounded,
        badgeLabel: 'Work',
      ),
      TimelineCategory.meal => const TimelineEntryStyle(
        accentColor: OptivusColors.roseAccent,
        icon: Icons.restaurant_rounded,
        badgeLabel: 'Meal',
      ),
      TimelineCategory.fixed => const TimelineEntryStyle(
        accentColor: OptivusColors.purpleAccent,
        icon: Icons.event_rounded,
        badgeLabel: 'Fixed',
      ),
      TimelineCategory.skinCare => const TimelineEntryStyle(
        accentColor: OptivusColors.roseAccent,
        icon: Icons.spa_rounded,
        badgeLabel: 'Skin Care',
      ),
      TimelineCategory.other => const TimelineEntryStyle(
        accentColor: OptivusColors.purpleAccent,
        icon: Icons.schedule_rounded,
      ),
    };
  }
}
