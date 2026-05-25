import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_base.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';

/// Card for check-in tasks: Smoking, Alcohol, Junk food etc.
class CheckInCard extends StatelessWidget {
  final RoutineItem item;
  final bool isNow;
  final VoidCallback? onTap;

  const CheckInCard({
    super.key,
    required this.item,
    this.isNow = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = RoutineCardFactory.colorForType(RoutineBlockType.checkIn);

    return RoutineCardBase(
      railColor: color,
      isCompleted: item.isCompleted,
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
                child: const Center(
                  child: Text('✅', style: TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: OptivusColors.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${TimelineUtils.formatMinute(item.startMinute)} • ${item.blockTypeLabel}',
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              CardActionButton(
                label: 'Avoided',
                color: OptivusColors.success,
                icon: Icons.check,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Check-in: Avoided ✓'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              CardActionButton(
                label: 'Craving',
                color: OptivusColors.warning,
                icon: Icons.warning_amber_rounded,
              ),
              CardActionButton(
                label: 'Relapsed',
                color: OptivusColors.danger,
                icon: Icons.close,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
