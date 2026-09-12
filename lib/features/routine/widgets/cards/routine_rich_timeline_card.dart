import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_actions.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_base.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_presentation.dart';
import 'package:optivus/features/routine/widgets/routine_timeline_adapter.dart';
import 'package:optivus/models/routine_item.dart';

/// Unified rich routine timeline card implementing Onboarding Step 14's
/// visual presentation language with Routine-specific live state and actions.
class RoutineRichTimelineCard extends ConsumerWidget {
  final RoutineItem item;
  final bool isNow;
  final double? railHeight;
  final bool isFront;
  final bool hasOverlap;
  final VoidCallback? onTap;

  const RoutineRichTimelineCard({
    super.key,
    required this.item,
    this.isNow = false,
    this.railHeight,
    this.isFront = true,
    this.hasOverlap = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = RoutineCardFactory.colorForType(item.blockType);
    final isCompleted =
        item.isCompleted || item.status == RoutineStatus.completed;

    const headingStyle = RoutineCardPresentation.headingStyle;
    const detailStyle = RoutineCardPresentation.detailStyle;

    final classInfo = RoutineCardFactory.classDetailsString(item);
    final isEating = item.category == RoutineCategory.eating;
    final isSkinCare = item.category == RoutineCategory.skinCare;
    final cleanDishes =
        item.dishes?.map((v) => v.trim()).where((v) => v.isNotEmpty).toList() ??
        const [];
    final nutrition = RoutineCardFactory.nutritionString(item);

    final continuation = item.isContinuation
        ? 'Continued from yesterday'
        : ((item.crossesMidnight ||
                  item.endsNextDay ||
                  item.endMinute <= item.startMinute)
              ? 'Continues tomorrow'
              : null);

    final timeText = item.startMinute == item.endMinute
        ? TimelineUtils.formatMinute(item.startMinute)
        : '${TimelineUtils.formatMinute(item.startMinute)} – ${TimelineUtils.formatMinute(item.endMinute)}';

    return RoutineCardBase(
      railColor: accent,
      railHeight: railHeight,
      isCompleted: isCompleted,
      isNow: isNow,
      isFront: isFront,
      hasOverlap: hasOverlap,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row: 18px accent icon + title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(backTabIcon(item), size: 18, color: accent),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                    height: 1.2,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    decorationColor: OptivusColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Time range row in accent color
          Text(
            timeText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: accent,
              height: 1.2,
            ),
          ),

          // Overnight continuation
          if (continuation != null) ...[
            const SizedBox(height: 6),
            Text(continuation, style: detailStyle),
          ],

          // Location
          if (item.location != null && item.location!.trim().isNotEmpty) ...[
            const SizedBox(height: RoutineCardPresentation.locationGap),
            Text(item.location!.trim(), style: detailStyle),
          ],

          // Class details (professor • course • type • section)
          if (classInfo != null) ...[
            const SizedBox(height: 6),
            Text(classInfo, style: detailStyle),
          ],

          // In-tracker progress badge
          if (item.status == RoutineStatus.inTracker) ...[
            const SizedBox(height: 6),
            Text('In progress in Tracker', style: detailStyle),
          ],

          // Tracker details / type
          if (item.trackerType != TrackerType.none) ...[
            const SizedBox(height: 6),
            Text(item.trackerType.name, style: detailStyle),
          ],

          // Eating details
          if (isEating || item.dishes != null || item.mealSlot != null) ...[
            if (RoutineCardFactory.shouldShowMealSlot(item)) ...[
              const SizedBox(height: 6),
              Text(item.mealSlot!.trim(), style: detailStyle),
            ],
            if (RoutineCardFactory.shouldShowMealCategory(item)) ...[
              const SizedBox(height: 6),
              Text(item.mealCategory!.trim(), style: detailStyle),
            ],
            if (nutrition != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Text(
                  nutrition,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
            ],
            if (cleanDishes.isNotEmpty) ...[
              const SizedBox(height: RoutineCardPresentation.dishesWrapGap),
              LayoutBuilder(
                builder: (context, constraints) {
                  final maxChipWidth = constraints.maxWidth;
                  return Wrap(
                    spacing: RoutineCardPresentation.dishSpacing,
                    runSpacing: RoutineCardPresentation.dishRunSpacing,
                    children: [
                      for (final dish in cleanDishes)
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxChipWidth),
                          child: Container(
                            padding: RoutineCardPresentation.dishPadding,
                            decoration: BoxDecoration(
                              color: RoutineCardPresentation.dishBgColor,
                              borderRadius:
                                  RoutineCardPresentation.dishBorderRadius,
                              border: Border.all(
                                color: RoutineCardPresentation.dishBorderColor,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              dish,
                              style: RoutineCardPresentation.dishTextStyle,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],

          // Skincare details
          if (isSkinCare ||
              item.steps != null ||
              item.skincareProducts != null ||
              item.skincareSlotLabel != null) ...[
            if (RoutineCardFactory.shouldShowSkincareSlot(item)) ...[
              const SizedBox(height: RoutineCardPresentation.skinSlotGap),
              Text(item.skincareSlotLabel!.trim(), style: detailStyle),
            ],
            if (item.displaySteps != null && item.displaySteps!.isNotEmpty) ...[
              const SizedBox(height: RoutineCardPresentation.skinStepsHeadingGap),
              const Text('STEPS', style: headingStyle),
              for (
                var index = 0;
                index < item.displaySteps!.length;
                index++
              ) ...[
                if (item.displaySteps![index].trim().isNotEmpty) ...[
                  const SizedBox(height: RoutineCardPresentation.skinStepItemGap),
                  Text(
                    '${index + 1}. ${item.displaySteps![index].trim()}',
                    style: detailStyle,
                  ),
                ],
              ],
            ],
            if (item.skincareProducts != null &&
                item.skincareProducts!.isNotEmpty) ...[
              const SizedBox(height: RoutineCardPresentation.skinProductsHeadingGap),
              const Text('PRODUCTS', style: headingStyle),
              for (final product in item.skincareProducts!) ...[
                if (product.trim().isNotEmpty) ...[
                  const SizedBox(height: RoutineCardPresentation.skinProductItemGap),
                  Text(product.trim(), style: detailStyle),
                ],
              ],
            ],
            if (item.skincareMissingItems != null &&
                item.skincareMissingItems!.isNotEmpty) ...[
              const SizedBox(height: RoutineCardPresentation.skinMissingHeadingGap),
              const Text(
                'MISSING',
                style: RoutineCardPresentation.missingHeadingStyle,
              ),
              for (final missing in item.skincareMissingItems!) ...[
                if (missing.trim().isNotEmpty) ...[
                  const SizedBox(height: RoutineCardPresentation.skinMissingItemGap),
                  Text(
                    '⚠ ${missing.trim()}',
                    style: RoutineCardPresentation.missingDetailStyle,
                  ),
                ],
              ],
            ],
          ],

          // Subtasks
          if (item.subtasks != null && item.subtasks!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('SUBTASKS (${item.subtasks!.length})', style: headingStyle),
            for (var index = 0; index < item.subtasks!.length; index++) ...[
              const SizedBox(height: 4),
              _buildSubtaskRow(context, ref, item, index, detailStyle),
            ],
          ],

          // Notes
          if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(item.notes!.trim(), style: detailStyle),
          ],

          // Three Primary Actions footer
          const SizedBox(height: 8),
          RoutineCardActions(item: item, color: accent),
        ],
      ),
    );
  }

  Widget _buildSubtaskRow(
    BuildContext context,
    WidgetRef ref,
    RoutineItem item,
    int index,
    TextStyle style,
  ) {
    final task = item.subtasks![index];
    final done =
        item.subtasksCompleted != null &&
        index < item.subtasksCompleted!.length &&
        item.subtasksCompleted![index];
    final hasScope =
        context
            .getElementForInheritedWidgetOfExactType<
              UncontrolledProviderScope
            >() !=
        null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (hasScope) {
          ref
              .read(routineNotifierProvider.notifier)
              .toggleSubtask(item.id, index);
        }
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              done ? Icons.check_box : Icons.check_box_outline_blank,
              size: 15,
              color: done
                  ? OptivusColors.success
                  : OptivusColors.sub.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              task,
              style: style.copyWith(
                color: done ? OptivusColors.sub : OptivusColors.textPrimary,
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: OptivusColors.sub,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
