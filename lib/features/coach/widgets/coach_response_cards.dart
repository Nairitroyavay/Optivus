import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

class TodayPlanCard extends StatelessWidget {
  final VoidCallback onStartMeditation;
  final VoidCallback onOpenRoutine;
  final VoidCallback onImprovePlan;

  const TodayPlanCard({
    super.key,
    required this.onStartMeditation,
    required this.onOpenRoutine,
    required this.onImprovePlan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OptivusColors.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OptivusColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.wb_sunny_rounded,
                color: OptivusColors.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Today\'s plan is:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: OptivusColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTimelineItem('7:40 AM', 'Meditation'),
          _buildTimelineItem('9:00 AM', 'Class'),
          _buildTimelineItem('6:30 PM', 'Gym'),
          _buildTimelineItem('9:45 PM', 'Tiny money save'),
          _buildTimelineItem('10:15 PM', 'Reading'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: OptivusColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: OptivusColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Your first small win:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: OptivusColors.success,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Meditation for 5 minutes.',
                  style: TextStyle(
                    fontSize: 13,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildButton(
                'Start Meditation',
                OptivusColors.success,
                onStartMeditation,
              ),
              _buildButton(
                'Open Routine',
                OptivusColors.brandAccent,
                onOpenRoutine,
              ),
              _buildButton(
                'Improve Plan',
                OptivusColors.coachAccent,
                onImprovePlan,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String time, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              time,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: OptivusColors.textSecondary,
              ),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: OptivusColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
