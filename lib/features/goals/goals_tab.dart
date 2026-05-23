import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/models/goal_models.dart';
import 'package:optivus/features/goals/screens/goals_sub_screens.dart';

class GoalsTab extends ConsumerWidget {
  const GoalsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(mockGoalProvider);

    // Calculate count of "Overload" difficulties chosen today
    final overloadCount = goals
        .where((g) => g.dailyProof.selectedDifficulty == 'strong')
        .length;

    final hasOverloadRisk = overloadCount >= 2;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Cognitive Burnout Warning Alert
          if (hasOverloadRisk)
            _buildOverloadProtectionAlert(context, overloadCount),

          // 2. Identity dashboard section header with Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'IDENTITY-LEVEL ALIGNMENTS',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: OptivusColors.textSecondary,
                    ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.reviews_outlined, color: OptivusColors.brandAccent, size: 18),
                    onPressed: () => showGoalWeeklyReviewScreen(context, ref),
                    tooltip: 'Weekly Review',
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: OptivusColors.brandAccent, size: 18),
                    onPressed: () => showAddGoalScreen(context, ref),
                    tooltip: 'Create Focus',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: InkWell(
                  onTap: () => showGoalDetailScreen(context, ref, goal),
                  borderRadius: BorderRadius.circular(24),
                  child: _buildGoalCard(context, ref, goal),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverloadProtectionAlert(BuildContext context, int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OptivusColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: OptivusColors.danger, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: OptivusColors.danger, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'COGNITIVE OVERLOAD SYSTEM ON',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.danger,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'You have locked $count "OVERLOAD" targets today. Doing this triggers rapid high-intensity fatigue. Aura recommends shifting at least one goal to "Tiny" to preserve long-term habit momentum.',
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, WidgetRef ref, GoalModel goal) {
    Color labelColor = Colors.grey;
    IconData icon = Icons.verified;

    final idLower = goal.id.toLowerCase();
    if (idLower.contains('body') || idLower.contains('gym')) {
      labelColor = const Color(0xFFA3FF91);
      icon = Icons.directions_run;
    } else if (idLower.contains('mind') || idLower.contains('reflection')) {
      labelColor = const Color(0xFFDCCBFF);
      icon = Icons.psychology;
    } else if (idLower.contains('money') || idLower.contains('finance')) {
      labelColor = const Color(0xFFFFC35C);
      icon = Icons.monetization_on_outlined;
    } else {
      labelColor = const Color(0xFFFFB6DC);
      icon = Icons.computer;
    }

    final proof = goal.dailyProof;
    final isDone = proof.isCompleted;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDone ? OptivusColors.success.withValues(alpha: 0.5) : Colors.white,
          width: isDone ? 2.0 : 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Goal Identity Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: labelColor.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: Colors.blueGrey.shade800, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'IDENTITY ALIGNMENT',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: OptivusColors.textSecondary,
                                  letterSpacing: 0.8),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              goal.identityTitle,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: OptivusColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${goal.streakDays} Days',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: OptivusColors.brandAccent),
                          ),
                          const Text('STREAK', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: OptivusColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Progress meter
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: goal.progressPercent,
                            minHeight: 6,
                            backgroundColor: Colors.white.withValues(alpha: 0.4),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                labelColor == const Color(0xFFDCCBFF) ? Colors.deepPurple : (labelColor == Colors.grey ? OptivusColors.brandAccent : labelColor)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${(goal.progressPercent * 100).toInt()}% Completed',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: OptivusColors.textSecondary),
                      ),
                    ],
                  )
                ],
              ),
            ),

            // Proof Verifier and Selector Panel
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white.withValues(alpha: 0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'DAILY MICRO PROOF: ${proof.title.toUpperCase()}',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: OptivusColors.textSecondary),
                        ),
                      ),
                      // Completion checkbox
                      InkWell(
                        onTap: () {
                          ref.read(mockGoalProvider.notifier).toggleGoalProofCompleted(goal.id);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDone ? OptivusColors.success.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDone ? OptivusColors.success : OptivusColors.borderSoft,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isDone ? Icons.verified : Icons.radio_button_unchecked,
                                color: isDone ? OptivusColors.success : OptivusColors.brandAccent,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isDone ? 'Verified' : 'Verify Proof',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDone ? OptivusColors.success : OptivusColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Difficulty Selector Chips
                  Row(
                    children: [
                      _buildDifficultyChip(ref, goal.id, 'Tiny', 'tiny', proof.selectedDifficulty, OptivusColors.success, isDone),
                      _buildDifficultyChip(ref, goal.id, 'Standard', 'normal', proof.selectedDifficulty, OptivusColors.brandAccent, isDone),
                      _buildDifficultyChip(ref, goal.id, 'Overload', 'strong', proof.selectedDifficulty, OptivusColors.danger, isDone),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyChip(
    WidgetRef ref,
    String goalId,
    String label,
    String valCode,
    String currentDifficulty,
    Color activeColor,
    bool isDone,
  ) {
    final isSel = currentDifficulty.toLowerCase() == valCode.toLowerCase();
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 6.0),
        child: InkWell(
          onTap: isDone
              ? null
              : () {
                  ref.read(mockGoalProvider.notifier).changeGoalProofDifficulty(goalId, valCode);
                },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSel ? activeColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSel ? activeColor : OptivusColors.borderSoft,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSel ? activeColor : OptivusColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
