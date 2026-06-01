import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/sheets/routine_move_sheet.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_base.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';

/// Card for soft blocks: Eating (rich with dishes/nutrition) and Skin Care (steps).
class SoftBlockCard extends ConsumerWidget {
  final RoutineItem item;
  final bool isNow;
  final double? railHeight;
  final VoidCallback? onTap;

  const SoftBlockCard({
    super.key,
    required this.item,
    this.isNow = false,
    this.railHeight,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = RoutineCardFactory.colorForType(RoutineBlockType.softBlock);
    final isEating = item.category == RoutineCategory.eating;
    final isSkinCare = item.category == RoutineCategory.skinCare;
    final steps = item.displaySteps;

    return RoutineCardBase(
      railColor: color,
      railHeight: railHeight,
      isCompleted: item.isCompleted,
      hasConflict: item.hasConflict,
      isNow: isNow,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Emoji icon box
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.22),
                      color.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: color.withValues(alpha: 0.18),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Text(
                    isEating ? '🍽️' : '🧴',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: item.isCompleted
                            ? OptivusColors.success
                            : OptivusColors.ink,
                        letterSpacing: -0.2,
                        decoration: item.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Time + type
                    Text(
                      '${TimelineUtils.formatTimeRange(item.startMinute, item.endMinute)} • ${item.blockTypeLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: OptivusColors.sub,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Eating: dishes + nutrition
          if (isEating && item.dishes != null && item.dishes!.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              _formatDishes(item.dishes!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: OptivusColors.sub,
              ),
            ),
            if (item.caloriesEstimate != null || item.proteinEstimate != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _formatNutrition(item.caloriesEstimate, item.proteinEstimate),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: OptivusColors.sub.withValues(alpha: 0.82),
                  ),
                ),
              ),
          ],

          // Skin care: steps
          if (isSkinCare && steps != null && steps.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...steps
                .take(3)
                .map(
                  (step) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      step,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: OptivusColors.sub,
                      ),
                    ),
                  ),
                ),
            if (steps.length > 3)
              Text(
                '${steps.length} steps',
                style: TextStyle(
                  fontSize: 11,
                  color: OptivusColors.sub.withValues(alpha: 0.7),
                ),
              ),
          ],

          // Action buttons
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              CardActionButton(
                label: 'Done',
                color: color,
                icon: Icons.check_rounded,
                onTap: () => ref
                    .read(routineNotifierProvider.notifier)
                    .markCompleted(item.id),
              ),
              if (isEating && item.dishes != null)
                CardActionButton(
                  label: 'View dishes',
                  color: color,
                  icon: Icons.restaurant_menu_rounded,
                  onTap: onTap,
                ),
              if (isSkinCare)
                CardActionButton(
                  label: 'View steps',
                  color: color,
                  icon: Icons.format_list_numbered_rounded,
                  onTap: onTap,
                ),
              CardActionButton(
                label: 'Move',
                color: OptivusColors.textSecondary,
                icon: Icons.schedule_rounded,
                onTap: () => showRoutineMoveSheet(context, ref, item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDishes(List<String> dishes) {
    if (dishes.length <= 3) return dishes.join(' • ');
    return '${dishes.take(3).join(' • ')} + ${dishes.length - 3} more';
  }

  String _formatNutrition(double? cal, double? protein) {
    final parts = <String>[];
    if (cal != null) parts.add('${cal.toInt()} kcal');
    if (protein != null) parts.add('${protein.toInt()}g protein');
    return parts.join(' • ');
  }
}
