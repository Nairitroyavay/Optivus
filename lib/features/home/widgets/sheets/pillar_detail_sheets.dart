import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/home/models/home_dashboard_state.dart';
import 'package:optivus/features/home/widgets/home_glass_widgets.dart';

class PillarDetailSheet extends StatelessWidget {
  final LifePillar pillar;

  const PillarDetailSheet({super.key, required this.pillar});

  static void show(BuildContext context, LifePillar pillar) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PillarDetailSheet(pillar: pillar),
    );
  }

  String _getPillarName() {
    switch (pillar) {
      case LifePillar.body:
        return 'Body';
      case LifePillar.mind:
        return 'Mind';
      case LifePillar.workStudy:
        return 'Work / Study';
      case LifePillar.finance:
        return 'Finance';
      case LifePillar.focus:
        return 'Focus';
      case LifePillar.growth:
        return 'Growth';
      case LifePillar.skill:
        return 'Skill';
    }
  }

  List<Widget> _getPillarContent() {
    switch (pillar) {
      case LifePillar.body:
        return [
          _buildTaskRow('Water', '500/2500ml', Icons.water_drop, Colors.blue),
          _buildTaskRow(
            'Workout',
            'Pending',
            Icons.fitness_center,
            OptivusColors.textSecondary,
          ),
          _buildTaskRow(
            'Protein meal',
            'Done',
            Icons.restaurant,
            OptivusColors.routineAccent,
          ),
        ];
      case LifePillar.mind:
        return [
          _buildTaskRow(
            'Meditation',
            'Pending',
            Icons.self_improvement,
            OptivusColors.textSecondary,
          ),
          _buildTaskRow('Stress', 'Medium', Icons.warning_amber, Colors.orange),
          _buildTaskRow(
            'Mind note',
            '3 captured',
            Icons.edit_note,
            OptivusColors.homeAccent,
          ),
        ];
      case LifePillar.workStudy:
        return [
          _buildTaskRow(
            'Class',
            '9 AM - 5 PM',
            Icons.school,
            OptivusColors.routineAccent,
          ),
          _buildTaskRow(
            'DSA practice',
            'Pending',
            Icons.code,
            OptivusColors.textSecondary,
          ),
        ];
      case LifePillar.skill:
        return [
          _buildTaskRow(
            'Coding',
            'Pending',
            Icons.computer,
            OptivusColors.textSecondary,
          ),
          _buildTaskRow(
            'Editing practice',
            'Not planned',
            Icons.videocam,
            OptivusColors.textSecondary.withValues(alpha: 0.5),
          ),
        ];
      case LifePillar.finance:
        return [
          _buildTaskRow('Tiny money save', 'Done', Icons.savings, Colors.amber),
          _buildTaskRow(
            'Bad-habit money saved',
            'None yet',
            Icons.money_off,
            OptivusColors.textSecondary,
          ),
        ];
      case LifePillar.focus:
        return [
          _buildTaskRow(
            'Instagram risk',
            'High',
            Icons.phonelink_ring,
            Colors.redAccent,
          ),
          _buildTaskRow(
            'Deep work',
            'Pending',
            Icons.timer,
            OptivusColors.textSecondary,
          ),
        ];
      case LifePillar.growth:
        return [
          _buildTaskRow(
            'Reading',
            'Pending',
            Icons.menu_book,
            OptivusColors.textSecondary,
          ),
          _buildTaskRow(
            'Identity proof',
            'Pending',
            Icons.verified,
            OptivusColors.textSecondary,
          ),
        ];
    }
  }

  Widget _buildTaskRow(
    String title,
    String status,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                color: OptivusColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            status,
            style: const TextStyle(
              fontSize: 14,
              color: OptivusColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
              Text(
                '${_getPillarName()} Pillar',
                style: const TextStyle(
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
                child: Column(children: _getPillarContent()),
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
