import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

/// Conflict notification banner shown at the top of the timeline.
class ConflictBanner extends StatelessWidget {
  final int conflictCount;
  final VoidCallback? onTap;

  const ConflictBanner({super.key, required this.conflictCount, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (conflictCount == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: OptivusColors.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: OptivusColors.danger.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: OptivusColors.danger,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$conflictCount time conflict${conflictCount > 1 ? 's' : ''} detected',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.danger,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: OptivusColors.danger,
            ),
          ],
        ),
      ),
    );
  }
}
