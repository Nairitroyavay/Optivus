import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_presentation_utils.dart';
import 'package:optivus/models/onboarding_draft.dart';

/// Renders the occurrence-based day summary directly above the timeline for the selected weekday.
///
/// Complies with Sections 34 & 35:
/// - Represents actual scheduled meal blocks and actual calorie/protein sums for this day.
/// - Explicitly labels partial nutrition estimates instead of fabricating totals.
/// - Does not conflate actual daily occurrence totals with overall daily targets.
class EatingDaySummaryBar extends StatelessWidget {
  final List<TimelineBlockDraft> blocks;
  final int selectedDay;
  final int? targetCalories;
  final int? targetProtein;

  const EatingDaySummaryBar({
    super.key,
    required this.blocks,
    required this.selectedDay,
    this.targetCalories,
    this.targetProtein,
  });

  @override
  Widget build(BuildContext context) {
    final summary = EatingPresentationUtils.daySummary(blocks, selectedDay);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final isNarrow =
            constraints.maxWidth < 340 || textScaler.scale(14) > 18;
        final hasChip =
            targetCalories != null &&
            summary.mealCount > 0 &&
            summary.totalCalories != null;

        final infoColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              summary.dayName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textPrimary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              summary.displayText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: summary.mealCount > 0
                    ? (summary.isPartial
                          ? OptivusColors.warning
                          : OptivusColors.textSecondary)
                    : OptivusColors.textSecondary.withValues(alpha: 0.7),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );

        Widget chipWidget() => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: OptivusColors.roseAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: OptivusColors.roseAccent.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Target: $targetCalories',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: OptivusColors.roseAccent,
                ),
              ),
              Text(
                'Actual: ~${summary.totalCalories}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: OptivusColors.textPrimary,
                ),
              ),
            ],
          ),
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.09),
              width: 1,
            ),
          ),
          child: isNarrow && hasChip
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    infoColumn,
                    const SizedBox(height: 6),
                    chipWidget(),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: infoColumn),
                    if (hasChip) ...[const SizedBox(width: 8), chipWidget()],
                  ],
                ),
        );
      },
    );
  }
}
