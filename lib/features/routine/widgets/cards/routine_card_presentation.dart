import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/routine_item.dart';

/// Centralized presentation constants and layout simulation for Routine timeline cards.
///
/// Shared identically between rendering ([RoutineRichTimelineCard]) and
/// height measurement ([RoutineCardFactory.measureHeight]) to guarantee zero drift.
class RoutineCardPresentation {
  RoutineCardPresentation._();

  // Card padding: TimelineCardChrome has padding: EdgeInsets.all(12) and
  // decoration: BoxDecoration(border: Border.all(width: 1.6)).
  // In Flutter's Container.build (package:flutter/src/widgets/container.dart:290),
  // effectivePadding = padding.add(decoration.padding), adding border.dimensions.
  // Content constraints are therefore parent - 27.2px horizontal and parent - 27.2px vertical.
  static const cardPadding = EdgeInsets.all(12);
  static const double cardHorizontalPaddingTotal = 27.2;
  static const double cardVerticalPaddingTotal = 27.2;

  /// Subpixel rounding tolerance (2.0px) for Flutter TextPainter line-height rounding.
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

  // Nutrition pill (8px h, 4px v padding + 1px border => 10px v total contribution)
  static const nutritionPadding = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 4,
  );
  static const nutritionTextStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
  );
  static const double nutritionBorderTotal = 2.0;

  // Dish chips (matches Step 14: 10px w700, white 0.9, 8px h, 3px v padding + 1px border)
  static const dishTextStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: OptivusColors.textPrimary,
  );
  static const dishPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 3);
  static final dishBorderRadius = BorderRadius.circular(6);
  static const dishBorderColor = Color(0xFFD4D7E2);
  static final dishBgColor = Colors.white.withValues(alpha: 0.9);

  // Vertical rhythm gaps (matches Step 14: 8px continuation)
  static const double continuationGap = 8.0;
  static const double locationGap = 8.0;
  static const double classInfoGap = 6.0;
  static const double trackerBadgeGap = 6.0;
  static const double trackerTypeGap = 6.0;

  static const double mealSlotGap = 6.0;
  static const double mealCategoryGap = 6.0;
  static const double nutritionPillGap = 8.0;
  static const double dishesWrapGap = 6.0;
  static const double dishSpacing = 6.0;
  static const double dishRunSpacing = 6.0;

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

  // Actions footer geometry & shared layout policy
  static const double actionGap = 6.0;
  static const double actionButtonPaddingHorizontal = 6.0;
  static const double actionButtonPaddingVertical = 8.0;
  static const double actionButtonBorderWidth = 1.0;
  static const double actionButtonMinHeight = 44.0;
  static const actionLabelStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
  );

  /// Deterministic action layout policy shared between rendering and height measurement.
  ///
  /// Normal width cards (where actions fit in a single row) render
  /// a single horizontal Row of Expanded buttons.
  /// Narrow overlapping front-cards or large accessibility scales fallback to a
  /// deliberate 2x2 grid (for 4 actions) or a non-truncating stacked layout.
  static RoutineCardActionLayout resolveRoutineCardActionLayout({
    required double availableWidth,
    required TextScaler textScaler,
    required TextDirection textDirection,
    List<String> labels = const ['Start', 'Done', 'Move', 'Skip'],
    int actionCount = 4,
  }) {
    if (actionCount <= 1) return RoutineCardActionLayout.horizontal;

    // 1. First test whether all actions fit in a single horizontal row
    final totalGaps = (actionCount - 1) * actionGap;
    final buttonWidth = (availableWidth - totalGaps) / actionCount.toDouble();
    final maxInnerWidth =
        buttonWidth -
        (2 * actionButtonPaddingHorizontal) -
        (2 * actionButtonBorderWidth);

    bool allFitHorizontal = maxInnerWidth > 0;
    if (allFitHorizontal) {
      for (final label in labels) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: actionLabelStyle),
          textDirection: textDirection,
          textScaler: textScaler,
          maxLines: 1,
        )..layout();

        if (painter.width > maxInnerWidth) {
          allFitHorizontal = false;
          break;
        }
      }
    }

    if (allFitHorizontal) {
      return RoutineCardActionLayout.horizontal;
    }

    // 2. For 4 actions, test if they fit in a clean 2x2 grid
    if (actionCount == 4) {
      final gridButtonWidth = (availableWidth - actionGap) / 2.0;
      final maxInnerWidthGrid =
          gridButtonWidth -
          (2 * actionButtonPaddingHorizontal) -
          (2 * actionButtonBorderWidth);

      if (maxInnerWidthGrid > 0) {
        bool allFitGrid = true;
        for (final label in labels) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: actionLabelStyle),
            textDirection: textDirection,
            textScaler: textScaler,
            maxLines: 1,
          )..layout();

          if (painter.width > maxInnerWidthGrid) {
            allFitGrid = false;
            break;
          }
        }
        if (allFitGrid) {
          return RoutineCardActionLayout.grid2x2;
        }
      }
    }

    // 3. Fallback to stacked if horizontal and grid2x2 do not fit
    return RoutineCardActionLayout.stacked;
  }

  /// Calculates the exact height of the routine action footer.
  /// Shared identically between rendering and height measurement.
  static double actionFooterHeight(
    RoutineCardActionLayout actionLayout, {
    int actionCount = 4,
    bool isTerminal = false,
    bool canUndo = false,
    double singleButtonHeight = RoutineCardPresentation.actionButtonMinHeight,
  }) {
    if (isTerminal || canUndo) {
      if (!canUndo) {
        return singleButtonHeight;
      }
      return switch (actionLayout) {
        RoutineCardActionLayout.horizontal ||
        RoutineCardActionLayout.grid2x2 => singleButtonHeight,
        RoutineCardActionLayout.stacked =>
          (singleButtonHeight * 2) + RoutineCardPresentation.actionGap,
      };
    }
    if (actionCount <= 1) {
      return singleButtonHeight;
    }
    return switch (actionLayout) {
      RoutineCardActionLayout.horizontal => singleButtonHeight,
      RoutineCardActionLayout.grid2x2 =>
        (singleButtonHeight * 2) + RoutineCardPresentation.actionGap,
      RoutineCardActionLayout.stacked =>
        (actionCount * singleButtonHeight) +
            (RoutineCardPresentation.actionGap * (actionCount - 1)),
    };
  }

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
    const chipBorderTotal = 2.0;
    final maxChipWidth = contentWidth;
    final textMaxWidth = math.max(
      10.0,
      maxChipWidth - chipPadding.horizontal - chipBorderTotal,
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
        painter.width + chipPadding.horizontal + chipBorderTotal,
      );
      final chipHeight =
          painter.height + chipPadding.vertical + chipBorderTotal;

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

/// Layout mode for routine card footer primary actions.
enum RoutineCardActionLayout { horizontal, grid2x2, stacked }

enum RoutineCardActionType {
  start,
  openTracker,
  startTracker,
  saveMoney,
  checkIn,
  done,
  move,
  skip,
  stop,
  undo,
  countdown,
  terminalBadge,
}

@immutable
class RoutineCardActionConfig {
  final String label;
  final RoutineCardActionType type;
  final bool isPrimary;

  const RoutineCardActionConfig({
    required this.label,
    required this.type,
    this.isPrimary = false,
  });
}

@immutable
class RoutineCardActionSet {
  final List<RoutineCardActionConfig> actions;

  const RoutineCardActionSet(this.actions);

  int get count => actions.length;
  List<String> get labels => actions.map((a) => a.label).toList();

  static RoutineCardActionSet resolve({
    required RoutineItem item,
    required RoutineStatus effectiveStatus,
    required bool isTrackerActive,
    required bool hasGenericCountdown,
    required bool canUndo,
  }) {
    final isTerminal =
        effectiveStatus == RoutineStatus.completed ||
        effectiveStatus == RoutineStatus.skipped ||
        effectiveStatus == RoutineStatus.missed ||
        item.isCompleted;

    if (isTerminal) {
      final terminalLabel = effectiveStatus == RoutineStatus.skipped
          ? 'Skipped'
          : (effectiveStatus == RoutineStatus.missed ? 'Missed' : 'Completed');
      if (canUndo) {
        return RoutineCardActionSet([
          RoutineCardActionConfig(
            label: terminalLabel,
            type: RoutineCardActionType.terminalBadge,
            isPrimary: true,
          ),
          const RoutineCardActionConfig(
            label: 'Undo',
            type: RoutineCardActionType.undo,
          ),
        ]);
      }
      return RoutineCardActionSet([
        RoutineCardActionConfig(
          label: terminalLabel,
          type: RoutineCardActionType.terminalBadge,
          isPrimary: true,
        ),
      ]);
    }

    if (hasGenericCountdown) {
      return const RoutineCardActionSet([
        RoutineCardActionConfig(
          label: '00:00:00',
          type: RoutineCardActionType.countdown,
        ),
        RoutineCardActionConfig(
          label: 'Done',
          type: RoutineCardActionType.done,
          isPrimary: true,
        ),
        RoutineCardActionConfig(
          label: 'Stop',
          type: RoutineCardActionType.stop,
        ),
      ]);
    }

    if (item.blockType == RoutineBlockType.moneyTask) {
      return const RoutineCardActionSet([
        RoutineCardActionConfig(
          label: 'Save money',
          type: RoutineCardActionType.saveMoney,
          isPrimary: true,
        ),
        RoutineCardActionConfig(
          label: 'Move',
          type: RoutineCardActionType.move,
        ),
        RoutineCardActionConfig(
          label: 'Skip',
          type: RoutineCardActionType.skip,
        ),
      ]);
    }

    if (item.blockType == RoutineBlockType.checkIn &&
        item.category == RoutineCategory.badHabit) {
      return const RoutineCardActionSet([
        RoutineCardActionConfig(
          label: 'Check in',
          type: RoutineCardActionType.checkIn,
          isPrimary: true,
        ),
        RoutineCardActionConfig(
          label: 'Move',
          type: RoutineCardActionType.move,
        ),
        RoutineCardActionConfig(
          label: 'Skip',
          type: RoutineCardActionType.skip,
        ),
      ]);
    }

    if (item.blockType == RoutineBlockType.trackerTask) {
      if (isTrackerActive) {
        return const RoutineCardActionSet([
          RoutineCardActionConfig(
            label: 'Open Tracker',
            type: RoutineCardActionType.openTracker,
            isPrimary: true,
          ),
          RoutineCardActionConfig(
            label: 'Done',
            type: RoutineCardActionType.done,
          ),
        ]);
      } else {
        return const RoutineCardActionSet([
          RoutineCardActionConfig(
            label: 'Start Tracker',
            type: RoutineCardActionType.startTracker,
            isPrimary: true,
          ),
          RoutineCardActionConfig(
            label: 'Move',
            type: RoutineCardActionType.move,
          ),
          RoutineCardActionConfig(
            label: 'Skip',
            type: RoutineCardActionType.skip,
          ),
        ]);
      }
    }

    // Standard planned/active routine item
    final isAlreadyActive = effectiveStatus == RoutineStatus.active;
    if (isAlreadyActive) {
      return const RoutineCardActionSet([
        RoutineCardActionConfig(
          label: 'Done',
          type: RoutineCardActionType.done,
          isPrimary: true,
        ),
        RoutineCardActionConfig(
          label: 'Stop',
          type: RoutineCardActionType.stop,
        ),
      ]);
    }

    return const RoutineCardActionSet([
      RoutineCardActionConfig(
        label: 'Start',
        type: RoutineCardActionType.start,
        isPrimary: true,
      ),
      RoutineCardActionConfig(label: 'Done', type: RoutineCardActionType.done),
      RoutineCardActionConfig(label: 'Move', type: RoutineCardActionType.move),
      RoutineCardActionConfig(label: 'Skip', type: RoutineCardActionType.skip),
    ]);
  }
}
