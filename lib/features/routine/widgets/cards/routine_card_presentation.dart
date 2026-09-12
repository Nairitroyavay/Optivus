import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

/// Centralized presentation constants and layout simulation for Routine timeline cards.
///
/// Shared identically between rendering ([RoutineRichTimelineCard]) and
/// height measurement ([RoutineCardFactory.measureHeight]) to guarantee zero drift.
class RoutineCardPresentation {
  RoutineCardPresentation._();

  // Card padding and chrome frame (12*2 padding + 1.6*2 border = 27.2)
  static const cardPadding = EdgeInsets.all(12);
  static const double cardHorizontalPaddingTotal = 27.2;
  static const double cardVerticalPaddingTotal = 27.2;
  static const double cardSubpixelTolerance = 2.0;
  static const double cardMinInteractiveHeight = 88.0;

  // Header row
  static const double headerIconSize = 18.0;
  static const double headerIconGap = 7.0;
  static const double headerToTimeGap = 5.0;

  // Typography
  static const titleStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w900,
    color: OptivusColors.textPrimary,
    height: 1.2,
  );

  static const timeStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );

  static const detailStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: OptivusColors.textPrimary,
    height: 1.25,
  );

  // Section headings (matches Step 14: 9.5px w900, letterSpacing 0.7, height 1.2)
  static const headingStyle = TextStyle(
    fontSize: 9.5,
    fontWeight: FontWeight.w900,
    color: OptivusColors.textSecondary,
    letterSpacing: 0.7,
    height: 1.2,
  );

  static const missingHeadingStyle = TextStyle(
    fontSize: 9.5,
    fontWeight: FontWeight.w900,
    color: OptivusColors.warning,
    letterSpacing: 0.7,
    height: 1.2,
  );

  static const missingDetailStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: OptivusColors.warning,
    height: 1.25,
  );

  // Dish chips (matches Step 14: 10px w700, white 0.9, 8px h, 3px v padding)
  static const dishTextStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: OptivusColors.textPrimary,
  );

  static const dishPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 3);
  static const double dishSpacing = 6.0;
  static const double dishRunSpacing = 6.0;
  static final dishBorderRadius = BorderRadius.circular(6);
  static const dishBorderColor = Color(0xFFD4D7E2);
  static final dishBgColor = Colors.white.withValues(alpha: 0.9);

  // Vertical rhythm gaps (matches Step 14)
  static const double continuationGap = 6.0;
  static const double locationGap = 8.0;
  static const double classInfoGap = 6.0;
  static const double trackerBadgeGap = 6.0;
  static const double trackerTypeGap = 6.0;
  static const double mealSlotGap = 6.0;
  static const double mealCategoryGap = 6.0;
  static const double nutritionPillGap = 8.0;
  static const double dishesWrapGap = 6.0;

  static const double skinSlotGap = 6.0;
  static const double skinStepsHeadingGap = 9.0;
  static const double skinStepItemGap = 3.0;
  static const double skinProductsHeadingGap = 9.0;
  static const double skinProductItemGap = 3.0;
  static const double skinMissingHeadingGap = 9.0;
  static const double skinMissingItemGap = 3.0;

  static const double subtasksHeadingGap = 8.0;
  static const double subtaskItemGap = 4.0;
  static const double notesGap = 6.0;
  static const double actionsFooterGap = 8.0;

  /// Accurately simulates Flutter's [Wrap] widget row-by-row layout
  /// to measure total height when dish names can wrap to arbitrary lines.
  static double measureWrapRowByRow({
    required List<String> items,
    required TextStyle textStyle,
    required EdgeInsets chipPadding,
    required double spacing,
    required double runSpacing,
    required double contentWidth,
    required TextScaler textScaler,
    required TextDirection textDirection,
  }) {
    if (items.isEmpty) return 0.0;
    const dishBorderHorizontal = 2.0;
    const dishBorderVertical = 2.0;
    final maxChipWidth = contentWidth;
    final textMaxWidth = math.max(
      10.0,
      maxChipWidth - chipPadding.horizontal - dishBorderHorizontal,
    );

    var totalHeight = 0.0;
    var currentRowWidth = 0.0;
    var currentRowHeight = 0.0;
    var rowCount = 0;

    for (final text in items) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout(maxWidth: textMaxWidth);

      final chipWidth = math.min(
        maxChipWidth,
        painter.width + chipPadding.horizontal + dishBorderHorizontal,
      );
      final chipHeight =
          painter.height + chipPadding.vertical + dishBorderVertical;

      if (currentRowWidth > 0 &&
          currentRowWidth + spacing + chipWidth > contentWidth + 0.001) {
        // Finalize current row
        totalHeight += currentRowHeight + (rowCount > 0 ? runSpacing : 0.0);
        rowCount++;
        currentRowWidth = chipWidth;
        currentRowHeight = chipHeight;
      } else {
        currentRowWidth += (currentRowWidth > 0 ? spacing : 0.0) + chipWidth;
        currentRowHeight = math.max(currentRowHeight, chipHeight);
      }
    }

    if (currentRowHeight > 0) {
      totalHeight += currentRowHeight + (rowCount > 0 ? runSpacing : 0.0);
    }

    return totalHeight;
  }
}
