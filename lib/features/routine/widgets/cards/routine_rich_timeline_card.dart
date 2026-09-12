import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_actions.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_base.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';
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

    const headingStyle = TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w900,
      color: OptivusColors.textSecondary,
      letterSpacing: 0.8,
      height: 1.2,
    );
    const detailStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: OptivusColors.textPrimary,
      height: 1.25,
    );

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
            const SizedBox(height: 6),
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
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, constraints) {
                  final maxChipWidth = math.max(
                    40.0,
                    constraints.maxWidth - 4.0,
                  );
                  return Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final dish in cleanDishes)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFD4D7E2),
                              width: 1,
                            ),
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxChipWidth),
                            child: Text(
                              dish,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: OptivusColors.textPrimary,
                              ),
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
              const SizedBox(height: 6),
              Text(item.skincareSlotLabel!.trim(), style: detailStyle),
            ],
            if (item.displaySteps != null && item.displaySteps!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('STEPS', style: headingStyle),
              for (
                var index = 0;
                index < item.displaySteps!.length;
                index++
              ) ...[
                if (item.displaySteps![index].trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${index + 1}. ${item.displaySteps![index].trim()}',
                    style: detailStyle,
                  ),
                ],
              ],
            ],
            if (item.skincareProducts != null &&
                item.skincareProducts!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('PRODUCTS', style: headingStyle),
              for (final product in item.skincareProducts!) ...[
                if (product.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text('• ${product.trim()}', style: detailStyle),
                ],
              ],
            ],
            if (item.skincareMissingItems != null &&
                item.skincareMissingItems!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'MISSING',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.warning,
                  letterSpacing: 0.7,
                  height: 1.2,
                ),
              ),
              for (final missing in item.skincareMissingItems!) ...[
                if (missing.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    '⚠ ${missing.trim()}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.warning,
                      height: 1.25,
                    ),
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
