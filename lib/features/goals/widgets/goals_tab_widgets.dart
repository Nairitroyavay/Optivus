import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/goal_models.dart';
import 'package:optivus/state/app_state.dart';

// --- Base Components ---

class GoalsSectionHeader extends StatelessWidget {
  final String title;

  const GoalsSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: OptivusColors.textSecondary,
        ) ?? TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: OptivusColors.textSecondary,
        ),
      ),
    );
  }
}

class GoalsGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final double opacity;
  final Color glowColor;

  const GoalsGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.tint,
    this.opacity = 0.55,
    this.glowColor = OptivusColors.goalsAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: OptivusColors.ink.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: glowColor.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: tint ?? Colors.white.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.3),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 3,
                  left: 20,
                  right: 20,
                  height: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.95),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GoalsHeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const GoalsHeaderButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: OptivusColors.goalsTop.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.3),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 2,
                    left: 8,
                    right: 8,
                    height: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.8),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Icon(icon, color: OptivusColors.ink, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Specific Widgets ---

class GoalsHeader extends StatelessWidget {
  const GoalsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Become . Prove . Evolve',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: OptivusColors.sub,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Goal.',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.ink,
                  ) ??
                  const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.ink,
                  ),
            ),
          ],
        ),
        GoalsHeaderButton(
          icon: Icons.add,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Add Identity Goal')),
            );
          },
        ),
      ],
    );
  }
}

class GoalsEmptyIdentityCard extends StatelessWidget {
  const GoalsEmptyIdentityCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GoalsGlassCard(
      padding: const EdgeInsets.all(24),
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 48, color: OptivusColors.goalsAccent),
          const SizedBox(height: 16),
          const Text(
            'No identity goal selected yet.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: OptivusColors.ink,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose who you are becoming.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: OptivusColors.sub,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: OptivusColors.goalsAccent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: OptivusColors.goalsAccent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                'Add Identity Goal',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TodayIdentityFocusCard extends StatelessWidget {
  final GoalModel primaryGoal;

  const TodayIdentityFocusCard({super.key, required this.primaryGoal});

  @override
  Widget build(BuildContext context) {
    return GoalsGlassCard(
      padding: const EdgeInsets.all(24),
      radius: 28,
      opacity: 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: OptivusColors.goalsAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'PRIMARY IDENTITY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.goalsAccent,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.star_rounded, color: OptivusColors.brandAccent, size: 24),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            primaryGoal.identityTitle,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: OptivusColors.ink,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Why: ${primaryGoal.purposeStatement}',
            style: const TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
              color: OptivusColors.sub,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Progress',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: OptivusColors.sub),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(primaryGoal.progressPercent * 100).toInt()}%',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: OptivusColors.ink),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: OptivusColors.sub.withValues(alpha: 0.2)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Proofs',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: OptivusColors.sub),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${primaryGoal.streakDays > 0 ? primaryGoal.streakDays : 3} this week',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: OptivusColors.ink),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'View Identity',
                      style: TextStyle(fontWeight: FontWeight.bold, color: OptivusColors.ink),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined, color: OptivusColors.ink),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TodayProofsCard extends ConsumerWidget {
  const TodayProofsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(mockGoalProvider);
    final incompleteGoals = goals.where((g) => !g.dailyProof.isCompleted).toList();
    final nextGoal = incompleteGoals.isNotEmpty ? incompleteGoals.first : (goals.isNotEmpty ? goals.first : null);

    if (nextGoal == null) {
      return GoalsGlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: OptivusColors.success, size: 48),
            const SizedBox(height: 12),
            const Text(
              'All proofs completed!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: OptivusColors.ink),
            ),
          ],
        ),
      );
    }

    final proof = nextGoal.dailyProof;

    return GoalsGlassCard(
      padding: const EdgeInsets.all(24),
      radius: 28,
      opacity: 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: OptivusColors.brandAccent, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Next Proof',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            proof.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: OptivusColors.ink,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'For: ${nextGoal.identityTitle}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: OptivusColors.sub,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () {
                    ref.read(mockGoalProvider.notifier).toggleGoalProofCompleted(nextGoal.id);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [OptivusColors.success, Color(0xFF2E995A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: OptivusColors.success.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Done',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: InkWell(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Do Tiny',
                      style: TextStyle(color: OptivusColors.ink, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: InkWell(
              onTap: () {},
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Skip / Not Today',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: OptivusColors.sub,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ActiveIdentityGoalsSection extends ConsumerWidget {
  const ActiveIdentityGoalsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(mockGoalProvider);

    return Column(
      children: goals.map((goal) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: ActiveIdentityGoalCard(goal: goal),
      )).toList(),
    );
  }
}

class ActiveIdentityGoalCard extends StatelessWidget {
  final GoalModel goal;

  const ActiveIdentityGoalCard({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    final isNeedsAttention = goal.streakDays == 0;
    final statusColor = isNeedsAttention ? OptivusColors.warning : OptivusColors.success;

    return GoalsGlassCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      opacity: 0.6,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        goal.systems.isNotEmpty ? goal.systems.first.description.split(' ').first : 'Core',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: OptivusColors.sub),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  goal.identityTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: OptivusColors.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  '${goal.streakDays}-day streak',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: OptivusColors.sub),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: goal.progressPercent,
                  strokeWidth: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.5),
                  valueColor: AlwaysStoppedAnimation<Color>(OptivusColors.goalsAccent),
                ),
                Center(
                  child: Text(
                    '${(goal.progressPercent * 100).toInt()}%',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: OptivusColors.ink),
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

class GoalSystemsSection extends ConsumerWidget {
  const GoalSystemsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(mockGoalProvider);
    final allSystems = goals.expand((g) => g.systems).toList();

    if (allSystems.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 12,
      children: allSystems.map((sys) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Text(
          sys.description,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: OptivusColors.ink),
        ),
      )).toList(),
    );
  }
}

class MilestonesCard extends StatelessWidget {
  const MilestonesCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GoalsGlassCard(
      padding: const EdgeInsets.all(20),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMilestoneRow(title: 'Week 1: Start identity', isCompleted: true),
          _buildMilestoneRow(title: 'Week 2: Consistency proof', isCompleted: false, isCurrent: true),
          _buildMilestoneRow(title: 'Month 1: Visible progress', isCompleted: false),
        ],
      ),
    );
  }

  Widget _buildMilestoneRow({required String title, required bool isCompleted, bool isCurrent = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : (isCurrent ? Icons.radio_button_checked : Icons.radio_button_unchecked),
            color: isCompleted ? OptivusColors.success : (isCurrent ? OptivusColors.goalsAccent : OptivusColors.sub.withValues(alpha: 0.5)),
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
              color: isCompleted ? OptivusColors.sub : OptivusColors.ink,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}

class TinyVersionCard extends StatelessWidget {
  const TinyVersionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GoalsGlassCard(
      padding: const EdgeInsets.all(20),
      radius: 20,
      opacity: 0.4,
      tint: OptivusColors.brandAccent.withValues(alpha: 0.05),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.battery_2_bar_rounded, color: OptivusColors.brandAccent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Low energy today?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: OptivusColors.ink),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Switch to tiny versions to protect your streak.',
                  style: TextStyle(fontSize: 12, color: OptivusColors.sub, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OverloadProtectionCard extends StatelessWidget {
  final int activeCount;

  const OverloadProtectionCard({super.key, required this.activeCount});

  @override
  Widget build(BuildContext context) {
    if (activeCount == 0) return const SizedBox.shrink();
    
    final bool isOverloaded = activeCount >= 4;

    return GoalsGlassCard(
      padding: const EdgeInsets.all(16),
      radius: 16,
      opacity: 0.5,
      child: Row(
        children: [
          Icon(
            isOverloaded ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
            color: isOverloaded ? OptivusColors.warning : OptivusColors.sub,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isOverloaded ? '$activeCount active goals · Overload risk' : '$activeCount active goals · Healthy load',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isOverloaded ? OptivusColors.warning : OptivusColors.ink,
              ),
            ),
          ),
          if (isOverloaded)
            Text(
              'Pause one',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: OptivusColors.sub, decoration: TextDecoration.underline),
            ),
        ],
      ),
    );
  }
}

class ArchivedGoalsShortcut extends StatelessWidget {
  const ArchivedGoalsShortcut({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildShortcutButton('Archived', Icons.archive_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildShortcutButton('Completed', Icons.done_all_rounded),
        ),
      ],
    );
  }

  Widget _buildShortcutButton(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: OptivusColors.sub),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: OptivusColors.ink),
          ),
        ],
      ),
    );
  }
}
