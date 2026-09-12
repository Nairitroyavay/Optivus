import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_actions.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_base.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';

/// Card for soft blocks: Eating (rich with all dishes/nutrition) and Skin Care (all steps/products).
class SoftBlockCard extends ConsumerWidget {
  final RoutineItem item;
  final bool isNow;
  final double? railHeight;
  final bool isFront;
  final bool hasOverlap;
  final VoidCallback? onTap;

  const SoftBlockCard({
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
    final color = RoutineCardFactory.colorForType(RoutineBlockType.softBlock);
    final isEating = item.category == RoutineCategory.eating;
    final isSkinCare = item.category == RoutineCategory.skinCare;
    final steps = item.displaySteps;

    return RoutineCardBase(
      railColor: color,
      railHeight: railHeight,
      isCompleted: item.isCompleted,
      isNow: isNow,
      isFront: isFront,
      hasOverlap: hasOverlap,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    isEating ? '🍽️' : (isSkinCare ? '🧴' : '🌿'),
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
                      maxLines: 2,
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

          // Meal slot or category subtitle if distinct from title
          if (isEating &&
              item.mealSlot != null &&
              item.mealSlot!.trim().isNotEmpty &&
              item.mealSlot!.trim().toLowerCase() !=
                  item.title.trim().toLowerCase()) ...[
            const SizedBox(height: 5),
            Text(
              item.mealSlot!.trim(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: OptivusColors.sub,
              ),
            ),
          ],

          // Location
          if (item.location != null && item.location!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 13,
                  color: OptivusColors.sub,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.location!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: OptivusColors.sub,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Eating: Nutrition
          if (isEating &&
              (item.caloriesEstimate != null ||
                  item.proteinEstimate != null)) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _formatNutrition(item.caloriesEstimate, item.proteinEstimate),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.sub.withValues(alpha: 0.95),
                ),
              ),
            ),
          ],

          // Eating: Full list of Dishes as chips
          if (isEating && item.dishes != null && item.dishes!.isNotEmpty) ...[
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: item.dishes!
                  .map((v) => v.trim())
                  .where((v) => v.isNotEmpty)
                  .map(
                    (dish) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: color.withValues(alpha: 0.22),
                          width: 0.6,
                        ),
                      ),
                      child: Text(
                        dish,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: OptivusColors.ink,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],

          // Skin care: Steps (all steps rendered)
          if (isSkinCare && steps != null && steps.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'STEPS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            ...steps.indexed.map((entry) {
              final idx = entry.$1;
              final step = entry.$2.trim();
              if (step.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '${idx + 1}. $step',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: OptivusColors.sub,
                  ),
                ),
              );
            }),
          ],

          // Skin care: Products (all products rendered)
          if (isSkinCare &&
              item.skincareProducts != null &&
              item.skincareProducts!.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'PRODUCTS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            ...item.skincareProducts!
                .map((p) => p.trim())
                .where((p) => p.isNotEmpty)
                .map(
                  (product) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '• $product',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: OptivusColors.sub,
                      ),
                    ),
                  ),
                ),
          ],

          // Notes
          if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.notes_rounded,
                  size: 13,
                  color: OptivusColors.sub,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.notes!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: OptivusColors.sub,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Three Primary Footer Actions: Start, Done, Move
          const SizedBox(height: 8),
          RoutineCardActions(item: item, color: color),
        ],
      ),
    );
  }

  static String _formatNutrition(double? cal, double? protein) {
    final parts = <String>[];
    if (cal != null) parts.add('${cal.toInt()} kcal');
    if (protein != null) parts.add('${protein.toInt()}g protein');
    return parts.join(' • ');
  }
}
