import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/routine_item.dart';

/// Displays "ACTIVE NOW" or "UP NEXT" routine action card.
class NowNextActionCard extends StatelessWidget {
  final String label;
  final RoutineItem? item;
  final String fallbackTitle;
  final String fallbackDesc;
  final Color iconColor;
  final bool isNow;

  const NowNextActionCard({
    super.key,
    required this.label,
    required this.item,
    required this.fallbackTitle,
    required this.fallbackDesc,
    required this.iconColor,
    required this.isNow,
  });

  String _formatMinute(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${displayHour.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final title = item?.title ?? fallbackTitle;
    final subtitle = item != null
        ? '${_formatMinute(item!.startMinute)} - ${_formatMinute(item!.endMinute)}'
        : fallbackDesc;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isNow
            ? Colors.white.withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isNow
              ? OptivusColors.brandAccent.withValues(alpha: 0.4)
              : Colors.white,
          width: 1.5,
        ),
        boxShadow: isNow
            ? [
                BoxShadow(
                  color: OptivusColors.brandAccent.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: iconColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: OptivusColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: OptivusColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
