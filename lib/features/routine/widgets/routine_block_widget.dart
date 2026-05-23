import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/state/app_state.dart';

/// Individual routine block rendered on the 24-hour time ruler.
class RoutineBlockWidget extends ConsumerWidget {
  final RoutineItem item;
  const RoutineBlockWidget({super.key, required this.item});

  String _formatMinute(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${displayHour.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color baseColor;
    switch (item.blockType) {
      case RoutineBlockType.hardBlock:
        baseColor = const Color(0xFF3B82F6);
        break;
      case RoutineBlockType.softBlock:
        baseColor = const Color(0xFF10B981);
        break;
      case RoutineBlockType.flexibleTask:
        baseColor = const Color(0xFF8B5CF6);
        break;
      case RoutineBlockType.trackerTask:
        baseColor = const Color(0xFFF59E0B);
        break;
      case RoutineBlockType.checkIn:
        baseColor = const Color(0xFFEC4899);
        break;
      case RoutineBlockType.moneyTask:
        baseColor = const Color(0xFF14B8A6);
        break;
    }

    final isHard = item.blockType == RoutineBlockType.hardBlock;

    return GestureDetector(
      onTap: () {
        ref.read(mockRoutineProvider.notifier).toggleRoutineCompleted(item.id);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: item.isCompleted
              ? OptivusColors.success.withValues(alpha: 0.15)
              : item.hasConflict
                  ? OptivusColors.danger.withValues(alpha: 0.15)
                  : baseColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isCompleted
                ? OptivusColors.success
                : item.hasConflict
                    ? OptivusColors.danger
                    : baseColor,
            width: item.hasConflict ? 2.0 : 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              item.isCompleted
                  ? Icons.check_circle
                  : item.hasConflict
                      ? Icons.warning
                      : isHard
                          ? Icons.lock_outline
                          : Icons.access_time_filled,
              color: item.isCompleted
                  ? OptivusColors.success
                  : item.hasConflict
                      ? OptivusColors.danger
                      : baseColor,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: item.isCompleted
                          ? OptivusColors.success
                          : item.hasConflict
                              ? OptivusColors.danger
                              : OptivusColors.textPrimary,
                      decoration:
                          item.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (item.conflictMessage != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.conflictMessage!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: OptivusColors.danger),
                    ),
                  ] else ...[
                    const SizedBox(height: 2),
                    Text(
                      '${_formatMinute(item.startMinute)} - ${_formatMinute(item.endMinute)}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: item.isCompleted
                            ? OptivusColors.success.withValues(alpha: 0.7)
                            : OptivusColors.textSecondary,
                      ),
                    ),
                  ]
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 16, color: OptivusColors.textSecondary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                ref
                    .read(mockRoutineProvider.notifier)
                    .deleteRoutineItem(item.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}
