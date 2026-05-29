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
          colors: [OptivusColors.goalsTop, OptivusColors.goalsCardTint],
          stops: [0.0, 0.80],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(
                color: OptivusColors.goalsTop,
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

                      const GoalsSectionHeader(title: 'FOCUS AREAS'),
                      const GoalSystemsSection(),
                      const SizedBox(height: 32),

                      const GoalsSectionHeader(title: 'MILESTONES'),
                      const MilestonesCard(),
                      const SizedBox(height: 32),

                      // Tiny version/comeback card 
                      const TinyVersionCard(),
                      const SizedBox(height: 24),

                      OverloadProtectionCard(activeCount: overloadCount),
                      if (overloadCount > 0) const SizedBox(height: 32),

                      const ArchivedGoalsShortcut(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
