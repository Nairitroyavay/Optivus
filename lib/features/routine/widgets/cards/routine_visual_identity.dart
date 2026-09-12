import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/models/routine_item.dart';

@immutable
class RoutineVisualIdentity {
  final Color accent;
  final IconData icon;
  final String shortLabel;

  const RoutineVisualIdentity({
    required this.accent,
    required this.icon,
    required this.shortLabel,
  });
}

/// Single resolver for front cards, exposed back cards, time text, and rails.
class RoutineVisualIdentityResolver {
  const RoutineVisualIdentityResolver._();

  static RoutineVisualIdentity resolve(RoutineItem item) {
    final accent = _accent(item);
    return RoutineVisualIdentity(
      accent: accent,
      icon: _icon(item),
      shortLabel: _shortLabel(item),
    );
  }

  static bool isVerifiedGeneratedSourceNote(RoutineItem item) {
    if (item.source != RoutineSource.onboarding ||
        item.onboardingProjectionId == null ||
        item.onboardingSourceItemId == null) {
      return false;
    }
    return switch (item.notes?.trim()) {
      'identity_system' => item.category == RoutineCategory.identity,
      'merged_habit_system' ||
      'good_habit' => item.category == RoutineCategory.habit,
      'bad_habit_check_in' => item.category == RoutineCategory.badHabit,
      'money' || 'money_task' => item.category == RoutineCategory.finance,
      _ => false,
    };
  }

  static Color _accent(RoutineItem item) {
    final key = item.onboardingVisualStyleKey?.trim();
    if (item.source == RoutineSource.onboarding && key != null) {
      final parts = key.split(':');
      final ordinal = parts.length == 2 ? int.tryParse(parts[1]) : null;
      if (parts.first == 'class' && ordinal != null) {
        final colors = ScheduleSetupConfig.classSetup.colorCycle;
        return colors[ordinal % colors.length];
      }
      if (parts.first == 'work' && ordinal != null) {
        final colors = ScheduleSetupConfig.workSetup.colorCycle;
        return colors[ordinal % colors.length];
      }
      if (key == 'eating:default' || key == 'skin:has-products') {
        return OptivusColors.roseAccent;
      }
      if (key == 'fixed:default' ||
          key == 'skin:no-products' ||
          key == 'skin:default') {
        return key == 'skin:default'
            ? OptivusColors.roseAccent
            : OptivusColors.purpleAccent;
      }
    }
    return switch (item.blockType) {
      RoutineBlockType.hardBlock => OptivusColors.blockHard,
      RoutineBlockType.softBlock => OptivusColors.blockSoft,
      RoutineBlockType.flexibleTask => OptivusColors.blockFlex,
      RoutineBlockType.trackerTask => OptivusColors.blockTracker,
      RoutineBlockType.checkIn => OptivusColors.blockCheckIn,
      RoutineBlockType.moneyTask => OptivusColors.blockMoney,
    };
  }

  static IconData _icon(RoutineItem item) {
    switch (item.category) {
      case RoutineCategory.classBlock:
        return Icons.school_rounded;
      case RoutineCategory.job:
        return Icons.business_center_rounded;
      case RoutineCategory.eating:
        final meal = '${item.mealSlot ?? ''} ${item.mealCategory ?? ''}'
            .toLowerCase();
        if (meal.contains('breakfast')) return Icons.wb_sunny_rounded;
        if (meal.contains('lunch')) return Icons.lunch_dining_rounded;
        if (meal.contains('dinner')) return Icons.dinner_dining_rounded;
        if (meal.contains('snack')) return Icons.cookie_rounded;
        return Icons.restaurant_rounded;
      case RoutineCategory.skinCare:
        return Icons.spa_rounded;
      case RoutineCategory.sleep:
        return Icons.bedtime_rounded;
      case RoutineCategory.finance:
        return Icons.attach_money_rounded;
      default:
        break;
    }
    if (item.blockType == RoutineBlockType.trackerTask) {
      return Icons.track_changes_rounded;
    }
    if (item.blockType == RoutineBlockType.checkIn) {
      return Icons.check_circle_outline_rounded;
    }
    if (item.blockType == RoutineBlockType.moneyTask) {
      return Icons.attach_money_rounded;
    }
    if (item.baseTimelineSection == 'fixed') {
      final title = item.title.toLowerCase();
      if (title.contains('commute') || title.contains('travel')) {
        return Icons.directions_transit_rounded;
      }
      if (title.contains('bath') || title.contains('shower')) {
        return Icons.bathtub_rounded;
      }
      return Icons.event_rounded;
    }
    return item.blockType == RoutineBlockType.flexibleTask
        ? Icons.assignment_rounded
        : Icons.event_rounded;
  }

  static String _shortLabel(RoutineItem item) {
    String? sourceLabel;
    if (item.category == RoutineCategory.classBlock) {
      sourceLabel = item.courseCode;
    } else if (item.category == RoutineCategory.job) {
      final normalized = item.title.trim().toLowerCase();
      sourceLabel = normalized.contains('office')
          ? 'Office'
          : normalized.contains('work') || normalized.contains('job')
          ? 'Work'
          : null;
    } else if (item.category == RoutineCategory.eating) {
      sourceLabel = item.mealSlot ?? item.mealCategory;
    } else if (item.category == RoutineCategory.skinCare) {
      sourceLabel = 'Skin Care';
    } else if (item.blockType == RoutineBlockType.trackerTask) {
      sourceLabel = 'Tracker';
    } else if (item.blockType == RoutineBlockType.checkIn) {
      sourceLabel = 'Check-In';
    }
    final candidate =
        (sourceLabel != null
            ? sourceLabel.trim()
            : item.title.trim().length <= 18
            ? item.title.trim()
            : null) ??
        item.title.trim();
    return _humanize(candidate.isEmpty ? item.category.name : candidate);
  }

  static String _humanize(String value) {
    final words = value
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'));
    return words
        .where((word) => word.isNotEmpty)
        .map(
          (word) => RegExp(r'\d').hasMatch(word)
              ? word.toUpperCase()
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}
