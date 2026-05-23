import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/goal_models.dart';
import 'package:optivus/state/app_state.dart';

/// Renders a single identity goal card with progress bar,
/// streak counter, daily proof section, and difficulty selector.
class ActiveGoalCard extends ConsumerWidget {
  final GoalModel goal;
  final VoidCallback? onTap;

  const ActiveGoalCard({
    super.key,
    required this.goal,
    this.onTap,
  });

  Color _getLabelColor() {
    final idLower = goal.id.toLowerCase();
    if (idLower.contains('body') || idLower.contains('gym')) {
      return const Color(0xFFA3FF91);
    } else if (idLower.contains('mind') || idLower.contains('reflection')) {
      return const Color(0xFFDCCBFF);
    } else if (idLower.contains('money') || idLower.contains('finance')) {
      return const Color(0xFFFFC35C);
    } else {
      return const Color(0xFFFFB6DC);
    }
  }

  IconData _getIcon() {
    final idLower = goal.id.toLowerCase();
    if (idLower.contains('body') || idLower.contains('gym')) {
      return Icons.directions_run;
    } else if (idLower.contains('mind') || idLower.contains('reflection')) {
      return Icons.psychology;
    } else if (idLower.contains('money') || idLower.contains('finance')) {
      return Icons.monetization_on_outlined;
    } else {
      return Icons.computer;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labelColor = _getLabelColor();
    final icon = _getIcon();
    final proof = goal.dailyProof;
    final isDone = proof.isCompleted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDone
                ? OptivusColors.success.withValues(alpha: 0.5)
                : Colors.white,
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
                          child: Icon(icon,
                              color: Colors.blueGrey.shade800, size: 20),
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
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: OptivusColors.brandAccent),
                            ),
                            const Text('STREAK',
                                style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: OptivusColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Progress meter
                    GoalProgressBar(
                      progress: goal.progressPercent,
                      color: labelColor == const Color(0xFFDCCBFF)
                          ? Colors.deepPurple
                          : (labelColor == Colors.grey
                              ? OptivusColors.brandAccent
                              : labelColor),
                    ),
                  ],
                ),
              ),

              // Daily Proof Panel
              DailyProofPanel(
                goal: goal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Linear progress bar with percentage label for goal cards.
class GoalProgressBar extends StatelessWidget {
  final double progress;
  final Color color;

  const GoalProgressBar({
    super.key,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${(progress * 100).toInt()}% Completed',
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: OptivusColors.textSecondary),
        ),
      ],
    );
  }
}

/// Daily proof verification and difficulty selector panel.
class DailyProofPanel extends ConsumerWidget {
  final GoalModel goal;

  const DailyProofPanel({super.key, required this.goal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proof = goal.dailyProof;
    final isDone = proof.isCompleted;

    return Container(
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
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textSecondary),
                ),
              ),
              InkWell(
                onTap: () {
                  ref
                      .read(mockGoalProvider.notifier)
                      .toggleGoalProofCompleted(goal.id);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDone
                        ? OptivusColors.success.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDone
                          ? OptivusColors.success
                          : OptivusColors.borderSoft,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDone
                            ? Icons.verified
                            : Icons.radio_button_unchecked,
                        color: isDone
                            ? OptivusColors.success
                            : OptivusColors.brandAccent,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isDone ? 'Verified' : 'Verify Proof',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDone
                              ? OptivusColors.success
                              : OptivusColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Difficulty Selector Chips
          Row(
            children: [
              _DifficultyChip(
                  goalId: goal.id,
                  label: 'Tiny',
                  valCode: 'tiny',
                  currentDifficulty: proof.selectedDifficulty,
                  activeColor: OptivusColors.success,
                  isDone: isDone),
              _DifficultyChip(
                  goalId: goal.id,
                  label: 'Standard',
                  valCode: 'normal',
                  currentDifficulty: proof.selectedDifficulty,
                  activeColor: OptivusColors.brandAccent,
                  isDone: isDone),
              _DifficultyChip(
                  goalId: goal.id,
                  label: 'Overload',
                  valCode: 'strong',
                  currentDifficulty: proof.selectedDifficulty,
                  activeColor: OptivusColors.danger,
                  isDone: isDone),
            ],
          ),
        ],
      ),
    );
  }
}

class _DifficultyChip extends ConsumerWidget {
  final String goalId;
  final String label;
  final String valCode;
  final String currentDifficulty;
  final Color activeColor;
  final bool isDone;

  const _DifficultyChip({
    required this.goalId,
    required this.label,
    required this.valCode,
    required this.currentDifficulty,
    required this.activeColor,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSel =
        currentDifficulty.toLowerCase() == valCode.toLowerCase();
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 6.0),
        child: InkWell(
          onTap: isDone
              ? null
              : () {
                  ref
                      .read(mockGoalProvider.notifier)
                      .changeGoalProofDifficulty(goalId, valCode);
                },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSel
                  ? activeColor.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.8),
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
