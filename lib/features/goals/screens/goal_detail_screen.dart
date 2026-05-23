import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/goal_models.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';
import '../widgets/goals_widgets.dart';

void showGoalDetailScreen(BuildContext context, WidgetRef ref, GoalModel goal) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFFECEC), // Goals visual gradient background color match
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top drag line
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'IDENTITY ANCHOR & SYSTEM MAPS',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: OptivusColors.textSecondary, letterSpacing: 0.8),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            goal.identityTitle,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: OptivusColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Text(
                        '${goal.streakDays}d Streak',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 20),

                // Purpose Statement Card
                LiquidGlassPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.psychology, color: Colors.indigo, size: 16),
                          SizedBox(width: 8),
                          Text('PURPOSE STATEMENT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: OptivusColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        goal.purposeStatement,
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, height: 1.35, color: OptivusColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Milestone progress list
                const Text(
                  'COMPLETION MILESTONES Checklist',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: OptivusColors.textSecondary, letterSpacing: 0.8),
                ),
                const SizedBox(height: 12),
                MilestoneCard(title: 'Establish baseline streak of 7 days', date: 'Completed 3 days ago', isCompleted: true),
                MilestoneCard(title: 'Increase frequency to Standard levels', date: 'Unlocked today', isCompleted: true),
                MilestoneCard(title: 'Complete 30 days unbroken target streak', date: 'In Progress (Estimated: June 15)', isCompleted: false),
                MilestoneCard(title: 'Sync total with Aura Coach reflection logs', date: 'Locked', isCompleted: false),
                const SizedBox(height: 24),

                // Systems processes cards mapping
                if (goal.systems.isNotEmpty) ...[
                  const Text(
                    'ROUTINES & LOGIC LOOPS MAP',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: OptivusColors.textSecondary, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 12),
                  for (final sys in goal.systems) GoalSystemCard(system: sys),
                  const SizedBox(height: 24),
                ],

                // Action buttons
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OptivusColors.brandAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to Identity Goals', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      );
    },
  );
}
