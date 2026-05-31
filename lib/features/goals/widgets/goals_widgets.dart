import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/goal_models.dart';

class MilestoneCard extends StatelessWidget {
  final String title;
  final String date;
  final bool isCompleted;

  const MilestoneCard({
    super.key,
    required this.title,
    required this.date,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? OptivusColors.success.withValues(alpha: 0.4)
              : OptivusColors.borderSoft,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCompleted
                ? OptivusColors.success
                : OptivusColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isCompleted
                        ? OptivusColors.textSecondary
                        : OptivusColors.textPrimary,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 9,
                    color: OptivusColors.textSecondary,
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

class GoalSystemCard extends StatelessWidget {
  final GoalSystem system;

  const GoalSystemCard({super.key, required this.system});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(
                Icons.settings_suggest_outlined,
                color: OptivusColors.brandAccent,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'SYSTEM PROCESS MAP',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  color: OptivusColors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            system.description,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: OptivusColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (system.linkedRoutineTaskIds.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.teal.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.lock_reset, color: Colors.teal, size: 12),
                      SizedBox(width: 4),
                      Text(
                        '1 Routine Linked',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (system.linkedTrackerIds.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: OptivusColors.brandAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: OptivusColors.brandAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.insights,
                        color: OptivusColors.brandAccent,
                        size: 12,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '1 Telemetry Linked',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: OptivusColors.brandAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
