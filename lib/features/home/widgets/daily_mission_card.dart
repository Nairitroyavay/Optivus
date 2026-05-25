import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'home_glass_widgets.dart';

/// Daily habit progress card with circular progress indicator.
class DailyMissionCard extends StatelessWidget {
  final int completedTasks;
  final int totalTasks;

  const DailyMissionCard({
    super.key,
    required this.completedTasks,
    required this.totalTasks,
  });

  @override
  Widget build(BuildContext context) {
    final completionRatio = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

    return HomeGlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  value: completionRatio,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    OptivusColors.homeAccent,
                  ),
                ),
              ),
              Text(
                '${(completionRatio * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Habit Progress',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$completedTasks of $totalTasks routine blocks completed.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: OptivusColors.textBody,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
