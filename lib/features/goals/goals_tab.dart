import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/features/goals/widgets/goals_tab_widgets.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

class GoalsTab extends ConsumerWidget {
  const GoalsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final bottomReserve =
        76.0 + media.padding.bottom + media.viewInsets.bottom + 48.0;

    final goals = ref.watch(mockGoalProvider);

    final overloadCount = goals
        .where((g) => g.dailyProof.selectedDifficulty == 'strong')
        .length;

    final primaryGoal = goals.isNotEmpty ? goals[0] : null;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [OptivusColors.goalsTop, OptivusColors.goalsBottom],
          stops: [0.0, 0.80],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: const GoalsHeader(),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, 16, 20, bottomReserve),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (primaryGoal != null) ...[
                      TodayIdentityFocusCard(primaryGoal: primaryGoal),
                      const SizedBox(height: 32),
                    ] else ...[
                      const GoalsEmptyIdentityCard(),
                      const SizedBox(height: 32),
                    ],

                    const TodayProofsCard(),
                    const SizedBox(height: 32),

                    const GoalsSectionHeader(title: 'ACTIVE IDENTITIES'),
                    const ActiveIdentityGoalsSection(),
                    const SizedBox(height: 32),

                    const GoalsSectionHeader(title: 'SYSTEMS'),
                    const GoalSystemsSection(),
                    const SizedBox(height: 32),

                    const GoalsSectionHeader(title: 'GOAL HEALTH'),
                    GoalHealthCard(activeCount: overloadCount),
                    const SizedBox(height: 32),

                    const GoalsSectionHeader(title: 'WEEKLY PROGRESS'),
                    const WeeklyGoalProgressCard(),
                    const SizedBox(height: 32),

                    const GoalsSectionHeader(title: 'INSIGHTS'),
                    const GoalInsightsCard(),
                    const SizedBox(height: 32),

                    const GoalsSectionHeader(title: 'MILESTONES'),
                    const MilestonesCard(),
                    const SizedBox(height: 32),

                    const GoalsSectionHeader(title: 'UPCOMING REVIEWS'),
                    const UpcomingReviewsCard(),
                    const SizedBox(height: 32),

                    const ArchivedGoalsShortcut(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
