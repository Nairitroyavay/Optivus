import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/widgets/cards/hard_block_card.dart';
import 'package:optivus/features/routine/widgets/cards/soft_block_card.dart';
import 'package:optivus/features/routine/widgets/cards/flexible_task_card.dart';
import 'package:optivus/features/routine/widgets/cards/tracker_task_card.dart';
import 'package:optivus/features/routine/widgets/cards/check_in_card.dart';
import 'package:optivus/features/routine/widgets/cards/money_task_card.dart';

/// Factory that builds the correct card widget based on RoutineBlockType.
class RoutineCardFactory {
  RoutineCardFactory._();

  /// Build the card widget, passing isNow for current-time highlighting.
  static Widget buildCard({
    required RoutineItem item,
    bool isNow = false,
    double? railHeight,
    bool isFront = true,
    bool hasOverlap = false,
    VoidCallback? onTap,
  }) {
    return switch (item.blockType) {
      RoutineBlockType.hardBlock => HardBlockCard(
        item: item,
        isNow: isNow,
        railHeight: railHeight,
        isFront: isFront,
        hasOverlap: hasOverlap,
        onTap: onTap,
      ),
      RoutineBlockType.softBlock => SoftBlockCard(
        item: item,
        isNow: isNow,
        railHeight: railHeight,
        isFront: isFront,
        hasOverlap: hasOverlap,
        onTap: onTap,
      ),
      RoutineBlockType.flexibleTask => FlexibleTaskCard(
        item: item,
        isNow: isNow,
        railHeight: railHeight,
        isFront: isFront,
        hasOverlap: hasOverlap,
        onTap: onTap,
      ),
      RoutineBlockType.trackerTask => TrackerTaskCard(
        item: item,
        isNow: isNow,
        railHeight: railHeight,
        isFront: isFront,
        hasOverlap: hasOverlap,
        onTap: onTap,
      ),
      RoutineBlockType.checkIn => CheckInCard(
        item: item,
        isNow: isNow,
        railHeight: railHeight,
        isFront: isFront,
        hasOverlap: hasOverlap,
        onTap: onTap,
      ),
      RoutineBlockType.moneyTask => MoneyTaskCard(
        item: item,
        isNow: isNow,
        railHeight: railHeight,
        isFront: isFront,
        hasOverlap: hasOverlap,
        onTap: onTap,
      ),
    };
  }

  /// Backward-compat entry point (old API).
  static Widget build(RoutineItem item, {VoidCallback? onTap}) {
    return buildCard(item: item, onTap: onTap);
  }

  /// Color for each block type — uses OptivusColors tokens, no raw hex.
  static Color colorForType(RoutineBlockType type) {
    return switch (type) {
      RoutineBlockType.hardBlock => OptivusColors.blockHard,
      RoutineBlockType.softBlock => OptivusColors.blockSoft,
      RoutineBlockType.flexibleTask => OptivusColors.blockFlex,
      RoutineBlockType.trackerTask => OptivusColors.blockTracker,
      RoutineBlockType.checkIn => OptivusColors.blockCheckIn,
      RoutineBlockType.moneyTask => OptivusColors.blockMoney,
    };
  }

  /// Exact formatted time string matching each block's presentation.
  static String formattedTimeString(RoutineItem item) {
    return switch (item.blockType) {
      RoutineBlockType.hardBlock =>
        item.isContinuation
            ? '${TimelineUtils.formatTimeRange(item.startMinute, item.endMinute)} • Continues from yesterday'
            : '${TimelineUtils.formatTimeRange(item.startMinute, item.endMinute)} • ${TimelineUtils.formatDuration(item.durationMinutes)} • ${item.blockTypeLabel}',
      RoutineBlockType.softBlock =>
        '${TimelineUtils.formatTimeRange(item.startMinute, item.endMinute)} • ${item.blockTypeLabel}',
      RoutineBlockType.flexibleTask =>
        '${TimelineUtils.formatTimeRange(item.startMinute, item.endMinute)} • ${TimelineUtils.formatDuration(item.durationMinutes)} • ${item.priorityLabel}',
      RoutineBlockType.trackerTask =>
        '${TimelineUtils.formatTimeRange(item.startMinute, item.endMinute)} • ${item.trackerType != TrackerType.none ? item.trackerType.name : item.blockTypeLabel}',
      RoutineBlockType.checkIn || RoutineBlockType.moneyTask =>
        '${TimelineUtils.formatMinute(item.startMinute)} • ${item.blockTypeLabel}',
    };
  }

  /// Class details string (professor, course, type, section).
  static String? classDetailsString(RoutineItem item) {
    final parts = [
      if (item.professor != null && item.professor!.trim().isNotEmpty)
        item.professor!.trim(),
      if (item.courseCode != null && item.courseCode!.trim().isNotEmpty)
        item.courseCode!.trim(),
      if (item.classType != null && item.classType!.trim().isNotEmpty)
        item.classType!.trim(),
      if (item.sectionLabel != null && item.sectionLabel!.trim().isNotEmpty)
        item.sectionLabel!.trim(),
    ].join(' • ');
    return parts.isEmpty ? null : parts;
  }

  /// Formatted nutrition string (calories + protein).
  static String? nutritionString(RoutineItem item) {
    final parts = <String>[];
    if (item.caloriesEstimate != null) {
      parts.add('${item.caloriesEstimate!.toInt()} kcal');
    }
    if (item.proteinEstimate != null) {
      parts.add('${item.proteinEstimate!.toInt()}g protein');
    }
    return parts.isEmpty ? null : parts.join(' • ');
  }

  /// Whether mealSlot provides distinct value from title.
  static bool shouldShowMealSlot(RoutineItem item) {
    final slot = item.mealSlot?.trim();
    if (slot == null || slot.isEmpty) return false;
    return slot.toLowerCase() != item.title.trim().toLowerCase();
  }

  /// Whether mealCategory provides distinct value from title and mealSlot.
  static bool shouldShowMealCategory(RoutineItem item) {
    final category = item.mealCategory?.trim();
    if (category == null || category.isEmpty) return false;
    final catLower = category.toLowerCase();
    if (catLower == 'meal') return false;
    if (catLower == item.title.trim().toLowerCase()) return false;
    final slotLower = item.mealSlot?.trim().toLowerCase();
    if (slotLower != null && catLower == slotLower) return false;
    return true;
  }

  /// Whether skincareSlotLabel provides distinct value from title.
  static bool shouldShowSkincareSlot(RoutineItem item) {
    final slot = item.skincareSlotLabel?.trim();
    if (slot == null || slot.isEmpty) return false;
    return slot.toLowerCase() != item.title.trim().toLowerCase();
  }

  /// Pre-measures exact height required for full-detail rich card content
  /// based on available width, text scaling, and specific item attributes.
  static double measureHeight(
    BuildContext context,
    double width,
    RoutineItem item,
  ) {
    final scaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    // Card padding is 12 left + 12 right = 24.
    final contentWidth = math.max(40.0, width - 24.0);
    // In header row: 18px icon + 7px gap = 25px.
    final titleWidth = math.max(20.0, contentWidth - 25.0);

    double measure(
      String text,
      TextStyle style, {
      double? customWidth,
      int? maxLines,
    }) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: textDirection,
        textScaler: scaler,
        maxLines: maxLines,
      )..layout(maxWidth: customWidth ?? contentWidth);
      return painter.height;
    }

    double measureWrap(
      List<String> items,
      TextStyle textStyle,
      EdgeInsets chipPadding,
      double spacing,
      double runSpacing,
    ) {
      if (items.isEmpty) return 0;
      var currentLineWidth = 0.0;
      var lineCount = 1;
      var maxChipHeight = 0.0;
      final maxChipWidth = math.max(40.0, contentWidth - 4.0);
      for (final text in items) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: textStyle),
          textDirection: textDirection,
          textScaler: scaler,
          maxLines: 2,
        )..layout(maxWidth: maxChipWidth - chipPadding.horizontal);
        final chipWidth = math.min(
          maxChipWidth,
          painter.width + chipPadding.horizontal,
        );
        maxChipHeight = math.max(
          maxChipHeight,
          painter.height + chipPadding.vertical,
        );
        if (currentLineWidth > 0 &&
            currentLineWidth + spacing + chipWidth > contentWidth) {
          lineCount++;
          currentLineWidth = chipWidth;
        } else {
          currentLineWidth += (currentLineWidth > 0 ? spacing : 0) + chipWidth;
        }
      }
      return lineCount * maxChipHeight + (lineCount - 1) * runSpacing;
    }

    const titleStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w900,
      height: 1.2,
    );
    const timeStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      height: 1.2,
    );
    const detailStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.25,
    );
    const headingStyle = TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.8,
      height: 1.2,
    );
    const chipTextStyle = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      height: 1.25,
    );

    var height = 0.0;

    // Header row: 18px icon + 7px gap + Title
    final titleH = measure(item.title, titleStyle, customWidth: titleWidth);
    height += math.max(18.0, titleH);

    // Time row: 5px gap + time
    final timeText = item.startMinute == item.endMinute
        ? TimelineUtils.formatMinute(item.startMinute)
        : '${TimelineUtils.formatMinute(item.startMinute)} – ${TimelineUtils.formatMinute(item.endMinute)}';
    final timeH = measure(timeText, timeStyle);
    height += 5.0 + timeH;

    // Continuation
    final continuation = item.isContinuation
        ? 'Continued from yesterday'
        : ((item.crossesMidnight ||
                  item.endsNextDay ||
                  item.endMinute <= item.startMinute)
              ? 'Continues tomorrow'
              : null);
    if (continuation != null) {
      height += 6.0 + measure(continuation, detailStyle);
    }

    // Location
    if (item.location != null && item.location!.trim().isNotEmpty) {
      height += 6.0 + measure(item.location!.trim(), detailStyle);
    }

    // Class details
    final classInfo = classDetailsString(item);
    if (classInfo != null) {
      height += 6.0 + measure(classInfo, detailStyle);
    }

    // In-tracker progress badge
    if (item.status == RoutineStatus.inTracker) {
      height += 6.0 + measure('In progress in Tracker', detailStyle);
    }

    // Tracker details / type
    if (item.trackerType != TrackerType.none) {
      height += 6.0 + measure(item.trackerType.name, detailStyle);
    }

    // Eating
    final isEating = item.category == RoutineCategory.eating;
    if (isEating || item.dishes != null || item.mealSlot != null) {
      if (shouldShowMealSlot(item)) {
        height += 6.0 + measure(item.mealSlot!.trim(), detailStyle);
      }
      if (shouldShowMealCategory(item)) {
        height += 6.0 + measure(item.mealCategory!.trim(), detailStyle);
      }
      final nutrition = nutritionString(item);
      if (nutrition != null) {
        final pillTextH = measure(
          nutrition,
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        );
        height += 8.0 + (pillTextH + 10.0);
      }
      if (item.dishes != null && item.dishes!.isNotEmpty) {
        final cleanDishes = item.dishes!
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty)
            .toList();
        if (cleanDishes.isNotEmpty) {
          height +=
              6.0 +
              measureWrap(
                cleanDishes,
                chipTextStyle,
                const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                6.0,
                6.0,
              );
        }
      }
    }

    // Skincare
    final isSkinCare = item.category == RoutineCategory.skinCare;
    if (isSkinCare ||
        item.steps != null ||
        item.skincareProducts != null ||
        item.skincareSlotLabel != null) {
      if (shouldShowSkincareSlot(item)) {
        height += 6.0 + measure(item.skincareSlotLabel!.trim(), detailStyle);
      }
      final steps = item.displaySteps;
      if (steps != null && steps.isNotEmpty) {
        height += 8.0 + measure('STEPS', headingStyle);
        for (var i = 0; i < steps.length; i++) {
          if (steps[i].trim().isNotEmpty) {
            height +=
                3.0 + measure('${i + 1}. ${steps[i].trim()}', detailStyle);
          }
        }
      }
      if (item.skincareProducts != null && item.skincareProducts!.isNotEmpty) {
        height += 8.0 + measure('PRODUCTS', headingStyle);
        for (final p in item.skincareProducts!) {
          if (p.trim().isNotEmpty) {
            height += 3.0 + measure('• ${p.trim()}', detailStyle);
          }
        }
      }
      if (item.skincareMissingItems != null &&
          item.skincareMissingItems!.isNotEmpty) {
        height +=
            8.0 +
            measure(
              'MISSING',
              const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
                height: 1.2,
              ),
            );
        for (final m in item.skincareMissingItems!) {
          if (m.trim().isNotEmpty) {
            height +=
                3.0 +
                measure(
                  '⚠ ${m.trim()}',
                  const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                );
          }
        }
      }
    }

    // Subtasks
    if (item.subtasks != null && item.subtasks!.isNotEmpty) {
      height +=
          8.0 + measure('SUBTASKS (${item.subtasks!.length})', headingStyle);
      for (final s in item.subtasks!) {
        final textH = measure(s, detailStyle, customWidth: contentWidth - 21.0);
        height += 4.0 + math.max(16.0, textH);
      }
    }

    // Notes
    if (item.notes != null && item.notes!.trim().isNotEmpty) {
      height += 6.0 + measure(item.notes!.trim(), detailStyle);
    }

    // Three Primary Actions footer (min 44px, scaling with textScaler)
    final actionTextPainter = TextPainter(
      text: const TextSpan(
        text: 'Start',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
      textDirection: textDirection,
      textScaler: scaler,
    )..layout();
    final actionButtonHeight = math.max(44.0, actionTextPainter.height + 16.0);
    height += 8.0 + actionButtonHeight;

    // Card padding (12 top + 12 bottom = 24) + subpixel rounding tolerance (2.0)
    return math.max(88.0, height + 24.0 + 2.0);
  }
}
