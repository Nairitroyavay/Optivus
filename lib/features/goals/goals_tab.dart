import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/features/coach/providers/coach_navigation_provider.dart';
import 'package:optivus/features/goals/providers/goals_navigation_provider.dart';
import 'package:optivus/features/goals/screens/goals_flow_screens.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/features/goals/widgets/goals_tab_widgets.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';

class GoalsTab extends ConsumerStatefulWidget {
  const GoalsTab({super.key});

  @override
  ConsumerState<GoalsTab> createState() => _GoalsTabState();
}

class _GoalsTabState extends ConsumerState<GoalsTab> {
  GoalsDetailTarget _activeDetail = GoalsDetailTarget.none;

  void _open(GoalsDetailTarget target) {
    setState(() => _activeDetail = target);
  }

  void _close() {
    setState(() => _activeDetail = GoalsDetailTarget.none);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(goalsDetailViewRequestProvider, (previous, next) {
      if (next.view == GoalsDetailView.none) return;
      _open(next);
      ref.read(goalsDetailViewRequestProvider.notifier).state =
          GoalsDetailTarget.none;
    });

    final pending = ref.watch(goalsDetailViewRequestProvider);
    if (pending.view != GoalsDetailView.none &&
        _activeDetail.view != pending.view) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _open(pending);
        ref.read(goalsDetailViewRequestProvider.notifier).state =
            GoalsDetailTarget.none;
      });
    }

    return PopScope(
      canPop: _activeDetail.view == GoalsDetailView.none,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _activeDetail.view != GoalsDetailView.none) _close();
      },
      child: _activeDetail.view == GoalsDetailView.none
          ? _GoalsMain(onOpen: _open)
          : _buildDetail(),
    );
  }

  Widget _buildDetail() {
    final goals = ref.watch(mockGoalProvider);
    final fallbackGoalId = goals.isEmpty ? null : goals.first.id;
    final goalId = _activeDetail.goalId ?? fallbackGoalId;

    return switch (_activeDetail.view) {
      GoalsDetailView.addGoal => AddGoalInlineScreen(onBack: _close),
      GoalsDetailView.goalDetail when goalId != null => GoalDetailInlineScreen(
        onBack: _close,
        goalId: goalId,
      ),
      GoalsDetailView.weeklyReview => WeeklyReviewInlineScreen(onBack: _close),
      GoalsDetailView.archivedGoals => ArchivedGoalsScreen(
        onBack: _close,
        onViewGoal: (id) => _open(
          GoalsDetailTarget(view: GoalsDetailView.goalDetail, goalId: id),
        ),
      ),
      GoalsDetailView.goalSettings => GoalsSettingsInlineScreen(onBack: _close),
      _ => _GoalsMain(onOpen: _open),
    };
  }
}

class _GoalsMain extends ConsumerWidget {
  final ValueChanged<GoalsDetailTarget> onOpen;

  const _GoalsMain({required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomReserve = liquidTabBarReserve(context);

    final goals = ref.watch(mockGoalProvider);
    final fakeDataAllowed = ref.watch(fakeDataAllowedProvider);

    final overloadCount = goals
        .where((g) => g.dailyProof.selectedDifficulty == 'strong')
        .length;

    final primaryGoal = goals.isNotEmpty ? goals[0] : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: _GoalsHeader(
                onAdd: () => onOpen(
                  const GoalsDetailTarget(view: GoalsDetailView.addGoal),
                ),
                onReview: () => onOpen(
                  const GoalsDetailTarget(view: GoalsDetailView.weeklyReview),
                ),
                onSettings: () => onOpen(
                  const GoalsDetailTarget(view: GoalsDetailView.goalSettings),
                ),
              ),
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
                      TodayIdentityFocusCard(
                        primaryGoal: primaryGoal,
                        onViewRoutine: () => ref
                            .read(appNavigationProvider.notifier)
                            .goToRoutine(),
                        onAskCoach: () {
                          ref.read(appNavigationProvider.notifier).goToCoach();
                          ref
                                  .read(coachDetailViewRequestProvider.notifier)
                                  .state =
                              CoachDetailView.newSession;
                        },
                        onSwitchGoal: () => onOpen(
                          const GoalsDetailTarget(
                            view: GoalsDetailView.goalSettings,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ] else ...[
                      GoalsEmptyIdentityCard(
                        onAddGoal: () => onOpen(
                          const GoalsDetailTarget(
                            view: GoalsDetailView.addGoal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    const TodayProofsCard(),
                    const SizedBox(height: 32),

                    const GoalsSectionHeader(title: 'ACTIVE IDENTITIES'),
                    Column(
                      children: goals.map((goal) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onOpen(
                            GoalsDetailTarget(
                              view: GoalsDetailView.goalDetail,
                              goalId: goal.id,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: ActiveIdentityGoalCard(goal: goal),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    const GoalsSectionHeader(title: 'SYSTEMS'),
                    const GoalSystemsSection(),
                    const SizedBox(height: 32),

                    const GoalsSectionHeader(title: 'GOAL HEALTH'),
                    GoalHealthCard(activeCount: overloadCount),
                    const SizedBox(height: 32),

                    if (goals.isNotEmpty && fakeDataAllowed) ...[
                      const GoalsSectionHeader(title: 'WEEKLY PROGRESS'),
                      const WeeklyGoalProgressCard(),
                      const SizedBox(height: 32),

                      const GoalsSectionHeader(title: 'INSIGHTS'),
                      const GoalInsightsCard(),
                      const SizedBox(height: 32),

                      const GoalsSectionHeader(title: 'MILESTONES'),
                      const MilestonesCard(),
                      const SizedBox(height: 32),
                    ],

                    if (fakeDataAllowed) ...[
                      const GoalsSectionHeader(title: 'UPCOMING REVIEWS'),
                      GestureDetector(
                        onTap: () => onOpen(
                          const GoalsDetailTarget(
                            view: GoalsDetailView.weeklyReview,
                          ),
                        ),
                        child: const UpcomingReviewsCard(),
                      ),
                      const SizedBox(height: 32),
                    ],

                    GestureDetector(
                      onTap: () => onOpen(
                        const GoalsDetailTarget(
                          view: GoalsDetailView.archivedGoals,
                        ),
                      ),
                      child: const ArchivedGoalsShortcut(),
                    ),
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

class _GoalsHeader extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onReview;
  final VoidCallback onSettings;

  const _GoalsHeader({
    required this.onAdd,
    required this.onReview,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Goals',
                style:
                    Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.ink,
                    ) ??
                    const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.ink,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Build the person you chose to become',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: OptivusColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            GoalsHeaderButton(icon: Icons.add, onTap: onAdd),
            const SizedBox(width: 8),
            GoalsHeaderButton(icon: Icons.assignment_outlined, onTap: onReview),
            const SizedBox(width: 8),
            GoalsHeaderButton(icon: Icons.settings_outlined, onTap: onSettings),
          ],
        ),
      ],
    );
  }
}
