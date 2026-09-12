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
import 'package:optivus/features/routine/widgets/cards/routine_card_presentation.dart';

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
    final defaultStyle = DefaultTextStyle.of(context).style;
    final contentWidth = math.max(
      40.0,
      width - RoutineCardPresentation.cardHorizontalPaddingTotal,
    );
    // In header row: 18px icon + 7px gap = 25px.
    final titleWidth = math.max(
      20.0,
      contentWidth -
          (RoutineCardPresentation.headerIconSize +
              RoutineCardPresentation.headerIconGap),
    );

    double measure(
      String text,
      TextStyle style, {
      double? customWidth,
      int? maxLines,
    }) {
      final effectiveStyle = defaultStyle.merge(style);
      final painter = TextPainter(
        text: TextSpan(text: text, style: effectiveStyle),
        textDirection: textDirection,
        textScaler: scaler,
        maxLines: maxLines,
      )..layout(maxWidth: customWidth ?? contentWidth);
      return painter.height;
    }

    const titleStyle = RoutineCardPresentation.titleStyle;
    const timeStyle = RoutineCardPresentation.timeStyle;
    const detailStyle = RoutineCardPresentation.detailStyle;
    const headingStyle = RoutineCardPresentation.headingStyle;

    var height = 0.0;

    // Header row: 18px icon + 7px gap + Title
    final titleH = measure(item.title, titleStyle, customWidth: titleWidth);
    height += math.max(RoutineCardPresentation.headerIconSize, titleH);

    // Time row: 5px gap + time
    final timeText = item.startMinute == item.endMinute
        ? TimelineUtils.formatMinute(item.startMinute)
        : '${TimelineUtils.formatMinute(item.startMinute)} – ${TimelineUtils.formatMinute(item.endMinute)}';
    final timeH = measure(timeText, timeStyle);
    height += RoutineCardPresentation.headerToTimeGap + timeH;

    // Continuation
    final continuation = item.isContinuation
        ? 'Continued from yesterday'
        : ((item.crossesMidnight ||
                  item.endsNextDay ||
                  item.endMinute <= item.startMinute)
              ? 'Continues tomorrow'
              : null);
    if (continuation != null) {
      height += RoutineCardPresentation.continuationGap +
          measure(continuation, detailStyle);
    }

    // Location
    if (item.location != null && item.location!.trim().isNotEmpty) {
      height += RoutineCardPresentation.locationGap +
          measure(item.location!.trim(), detailStyle);
    }

    // Class details
    final classInfo = classDetailsString(item);
    if (classInfo != null) {
      height += RoutineCardPresentation.classInfoGap +
          measure(classInfo, detailStyle);
    }

    // In-tracker progress badge
    if (item.status == RoutineStatus.inTracker) {
      height += RoutineCardPresentation.trackerBadgeGap +
          measure('In progress in Tracker', detailStyle);
    }

    // Tracker details / type
    if (item.trackerType != TrackerType.none) {
      height += RoutineCardPresentation.trackerTypeGap +
          measure(item.trackerType.name, detailStyle);
    }

    // Eating
    final isEating = item.category == RoutineCategory.eating;
    if (isEating || item.dishes != null || item.mealSlot != null) {
      if (shouldShowMealSlot(item)) {
        height += RoutineCardPresentation.mealSlotGap +
            measure(item.mealSlot!.trim(), detailStyle);
      }
      if (shouldShowMealCategory(item)) {
        height += RoutineCardPresentation.mealCategoryGap +
            measure(item.mealCategory!.trim(), detailStyle);
      }
      final nutrition = nutritionString(item);
      if (nutrition != null) {
        final pillTextH = measure(
          nutrition,
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        );
        height += RoutineCardPresentation.nutritionPillGap +
            (pillTextH + 10.0);
      }
      if (item.dishes != null && item.dishes!.isNotEmpty) {
        final cleanDishes = item.dishes!
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty)
            .toList();
        if (cleanDishes.isNotEmpty) {
          final dishesH = RoutineCardPresentation.measureWrapRowByRow(
            items: cleanDishes,
            textStyle: defaultStyle.merge(RoutineCardPresentation.dishTextStyle),
            chipPadding: RoutineCardPresentation.dishPadding,
            spacing: RoutineCardPresentation.dishSpacing,
            runSpacing: RoutineCardPresentation.dishRunSpacing,
            contentWidth: contentWidth,
            textScaler: scaler,
            textDirection: textDirection,
          );
          height += RoutineCardPresentation.dishesWrapGap + dishesH;
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
        height += RoutineCardPresentation.skinSlotGap +
            measure(item.skincareSlotLabel!.trim(), detailStyle);
      }
      final steps = item.displaySteps;
      if (steps != null && steps.isNotEmpty) {
        height += RoutineCardPresentation.skinStepsHeadingGap +
            measure('STEPS', headingStyle);
        for (var i = 0; i < steps.length; i++) {
          if (steps[i].trim().isNotEmpty) {
            height += RoutineCardPresentation.skinStepItemGap +
                measure('${i + 1}. ${steps[i].trim()}', detailStyle);
          }
        }
      }
      if (item.skincareProducts != null && item.skincareProducts!.isNotEmpty) {
        height += RoutineCardPresentation.skinProductsHeadingGap +
            measure('PRODUCTS', headingStyle);
        for (final p in item.skincareProducts!) {
          if (p.trim().isNotEmpty) {
            height += RoutineCardPresentation.skinProductItemGap +
                measure(p.trim(), detailStyle);
          }
        }
      }
      if (item.skincareMissingItems != null &&
          item.skincareMissingItems!.isNotEmpty) {
        height += RoutineCardPresentation.skinMissingHeadingGap +
            measure(
              'MISSING',
              RoutineCardPresentation.missingHeadingStyle,
            );
        for (final m in item.skincareMissingItems!) {
          if (m.trim().isNotEmpty) {
            height += RoutineCardPresentation.skinMissingItemGap +
                measure(
                  '⚠ ${m.trim()}',
                  RoutineCardPresentation.missingDetailStyle,
                );
          }
        }
      }
    }

    // Subtasks
    if (item.subtasks != null && item.subtasks!.isNotEmpty) {
      height += RoutineCardPresentation.subtasksHeadingGap +
          measure('SUBTASKS (${item.subtasks!.length})', headingStyle);
      for (final s in item.subtasks!) {
        final textH = measure(
          s,
          detailStyle,
          customWidth: contentWidth - 21.0,
        );
        height += RoutineCardPresentation.subtaskItemGap +
            math.max(16.0, textH);
      }
    }

    // Notes
    if (item.notes != null && item.notes!.trim().isNotEmpty) {
      height += RoutineCardPresentation.notesGap +
          measure(item.notes!.trim(), detailStyle);
    }

    // Three Primary Actions footer (min 44px, scaling with textScaler)
    final actionTextPainter = TextPainter(
      text: TextSpan(
        text: 'Start',
        style: defaultStyle.merge(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
      textDirection: textDirection,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final actionButtonHeight = math.max(
      44.0,
      math.max(14.0, actionTextPainter.height) + 16.0 + 2.8,
    );
    height += RoutineCardPresentation.actionsFooterGap + actionButtonHeight;

    // Card padding (12 top + 12 bottom = 24) + subpixel rounding tolerance (2.0)
    return math.max(
      RoutineCardPresentation.cardMinInteractiveHeight,
      height +
          RoutineCardPresentation.cardVerticalPaddingTotal +
          RoutineCardPresentation.cardSubpixelTolerance,
    );
  }
}
