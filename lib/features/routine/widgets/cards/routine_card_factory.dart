import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/routine_item.dart';
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

  /// Pre-measures exact height required for full-detail rich card content
  /// based on available width, text scaling, and specific item attributes.
  static double measureHeight(
    BuildContext context,
    double width,
    RoutineItem item,
  ) {
    final scaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    // Card padding is 14 left + 14 right = 28. Accent bar is 3.5 + 10 margin = 13.5. Total horizontal = ~42.
    final contentWidth = math.max(40.0, width - 44.0);
    final titleWidth = math.max(20.0, contentWidth - 54.0);

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
      return math.max(16.0, painter.height);
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
      for (final text in items) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: textStyle),
          textDirection: textDirection,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        final chipWidth = painter.width + chipPadding.horizontal + 4.0;
        maxChipHeight = math.max(
          maxChipHeight,
          painter.height + chipPadding.vertical + 4.0,
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
      fontSize: 14.5,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
      height: 1.25,
    );
    const detailStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.25,
    );
    const headingStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.6,
      height: 1.2,
    );
    const chipStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w600);

    var height = 0.0;

    // Header row: Emoji container (42px) + Title & time range
    final titleH = measure(
      item.title,
      titleStyle,
      customWidth: titleWidth,
      maxLines: 2,
    );
    final timeH = measure(
      'Time range • duration • type',
      detailStyle,
      customWidth: titleWidth,
      maxLines: 1,
    );
    final headerH = math.max(44.0, titleH + 4.0 + timeH);
    height += headerH;

    // Continuation
    if (item.isContinuation) {
      height += 6.0 + measure('Continues from yesterday', detailStyle);
    }

    // Location
    if (item.location != null && item.location!.trim().isNotEmpty) {
      height += 6.0 + measure(item.location!.trim(), detailStyle);
    }

    // Class details
    if (item.professor != null ||
        item.courseCode != null ||
        item.classType != null ||
        item.sectionLabel != null) {
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
      if (parts.isNotEmpty) {
        height += 6.0 + measure(parts, detailStyle);
      }
    }

    // In-tracker progress badge
    if (item.status == RoutineStatus.inTracker) {
      height += 6.0 + measure('In progress in Tracker', detailStyle);
    }

    // Eating
    final isEating = item.category == RoutineCategory.eating;
    if (isEating || item.dishes != null) {
      if (item.mealSlot != null &&
          item.mealSlot!.trim().isNotEmpty &&
          item.mealSlot!.trim().toLowerCase() !=
              item.title.trim().toLowerCase()) {
        height += 6.0 + measure(item.mealSlot!.trim(), detailStyle);
      }
      if (item.caloriesEstimate != null || item.proteinEstimate != null) {
        height += 8.0 + measure('0000 kcal • 00g protein', detailStyle) + 6.0;
      }
      if (item.dishes != null && item.dishes!.isNotEmpty) {
        final cleanDishes = item.dishes!
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty)
            .toList();
        if (cleanDishes.isNotEmpty) {
          height +=
              8.0 +
              measureWrap(
                cleanDishes,
                chipStyle,
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                6.0,
                4.0,
              );
        }
      }
    }

    // Skincare
    final isSkinCare = item.category == RoutineCategory.skinCare;
    if (isSkinCare || item.steps != null) {
      final steps = item.displaySteps;
      if (steps != null && steps.isNotEmpty) {
        height += 8.0 + measure('STEPS', headingStyle) + 4.0;
        for (final s in steps) {
          if (s.trim().isNotEmpty) {
            height += 3.0 + math.max(18.0, measure(s.trim(), detailStyle));
          }
        }
      }
      if (item.skincareProducts != null && item.skincareProducts!.isNotEmpty) {
        height += 8.0 + measure('PRODUCTS', headingStyle) + 4.0;
        for (final p in item.skincareProducts!) {
          if (p.trim().isNotEmpty) {
            height += 2.0 + math.max(18.0, measure(p.trim(), detailStyle));
          }
        }
      }
    }

    // Subtasks
    if (item.subtasks != null && item.subtasks!.isNotEmpty) {
      height +=
          8.0 +
          measure('SUBTASKS (${item.subtasks!.length})', headingStyle) +
          4.0;
      for (final s in item.subtasks!) {
        height +=
            3.0 +
            math.max(
              22.0,
              measure(
                s,
                detailStyle,
                customWidth: contentWidth - 24.0,
                maxLines: 2,
              ),
            );
      }
    }

    // Notes
    if (item.notes != null && item.notes!.trim().isNotEmpty) {
      height += 6.0 + measure(item.notes!.trim(), detailStyle, maxLines: 2);
    }

    // Three Primary Actions footer
    final actionHeight = contentWidth < 210.0 ? 76.0 : 38.0;
    height += 8.0 + actionHeight;

    // Card padding (14 top + 14 bottom = 28) + extra safety cushion (20)
    const verticalPadding = 28.0 + 20.0;

    return math.max(88.0, height + verticalPadding);
  }
}
