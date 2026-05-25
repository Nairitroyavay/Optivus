import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/home/widgets/home_glass_widgets.dart';

class MissionDetailSheet extends StatelessWidget {
  const MissionDetailSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const MissionDetailSheet(),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: OptivusColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: OptivusColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: OptivusColors.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Today\'s Mission Breakdown',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('CORE STATS'),
                    _buildStatRow('Routine Actions', '3/9 done', Icons.task_alt, OptivusColors.routineAccent),
                    _buildStatRow('Focus Time', '45m', Icons.timer, OptivusColors.homeAccent),
                    _buildStatRow('Money Saved', '₹10', Icons.savings, Colors.amber.shade600),
                    _buildStatRow('Bad Habit Avoided', '1', Icons.shield, OptivusColors.coachAccent),
                    
                    const Divider(height: 24, color: Colors.white),
                    
                    _buildSectionTitle('IDENTITY PROOF'),
                    _buildStatRow('Non-negotiable task', 'Pending', Icons.verified, OptivusColors.brandAccent),
                    
                    const Divider(height: 24, color: Colors.white),
                    
                    _buildSectionTitle('TRACKER SESSIONS'),
                    _buildStatRow('Meditation', 'Pending', Icons.self_improvement, OptivusColors.trackerAccent),
                    _buildStatRow('Workout', 'Pending', Icons.fitness_center, OptivusColors.trackerAccent),
                    
                    const Divider(height: 24, color: Colors.white),
                    
                    _buildSectionTitle('MANUAL CHECK-INS'),
                    _buildStatRow('Water', 'Logged', Icons.water_drop, Colors.blue),
                    _buildStatRow('Sleep', 'Checked', Icons.bedtime, Colors.indigo),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              HomeActionPill(
                label: 'Close',
                icon: Icons.close,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
