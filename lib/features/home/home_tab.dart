import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/features/home/models/home_dashboard_state.dart';
import 'package:optivus/features/home/providers/home_dashboard_provider.dart';

import 'package:optivus/app/app_navigation_controller.dart';

import 'widgets/home_header.dart';
import 'widgets/today_identity_card.dart';
import 'widgets/now_next_action_card.dart';
import 'widgets/today_mission_card.dart';
import 'widgets/life_os_snapshot.dart';
import 'widgets/today_check_in_card.dart';
import 'widgets/auto_insights_card.dart';
import 'widgets/tracker_preview_section.dart';
import 'widgets/coach_tip_card.dart';
import 'widgets/mind_timeline_card.dart';
import 'widgets/coming_up_card.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We get the user name from the existing mock profile or fall back
    final userProfile = ref.watch(mockUserProfileProvider);
    final userName = userProfile.displayName.isNotEmpty
        ? userProfile.displayName
        : 'Nairit';

    // We get all home dashboard state from our new provider
    final dashboardState = ref.watch(homeDashboardProvider);
    final trackerState = ref.watch(mockTrackerProvider);
    final todayMoneySaved = _confirmedMoneySavedToday(trackerState);
    final moneyGoal = trackerState.moneyGoal;
    final checkIns = dashboardState.checkIns
        .map((item) {
          if (item.id != 'money_saved') return item;
          final options = <String>{
            '₹${moneyGoal.tinySaveAmount.toInt()}',
            '₹${moneyGoal.dailyTarget.toInt()}',
            'Custom',
          }.toList();
          return CheckInItem(
            id: item.id,
            title: item.title,
            icon: item.icon,
            options: options,
            selectedOption: item.selectedOption,
          );
        })
        .toList(growable: false);
    final missionSummary = HomeMissionSummary(
      percentage: dashboardState.missionSummary.percentage,
      actionsDone: dashboardState.missionSummary.actionsDone,
      actionsTotal: dashboardState.missionSummary.actionsTotal,
      focusMinutes: dashboardState.missionSummary.focusMinutes,
      moneySaved: todayMoneySaved.toInt(),
      badHabitsAvoided: dashboardState.missionSummary.badHabitsAvoided,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: HomeHeader(userName: userName),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TodayIdentityCard(
                      identity: dashboardState.identityFocus,
                      onTap: () =>
                          ref.read(appNavigationProvider.notifier).goToGoals(),
                    ),
                    const SizedBox(height: 16),
                    NowNextActionCard(
                      actionState: dashboardState.nowNextAction,
                    ),
                    const SizedBox(height: 16),
                    TodayMissionCard(summary: missionSummary),
                    const SizedBox(height: 16),
                    LifeOsSnapshot(pillars: dashboardState.lifeOsSnapshot),
                    const SizedBox(height: 16),
                    TodayCheckInCard(checkIns: checkIns),
                    const SizedBox(height: 16),
                    AutoInsightsCard(insights: dashboardState.autoInsights),
                    const SizedBox(height: 24),
                    TrackerPreviewSection(
                      previews: dashboardState.trackerPreviews,
                    ),
                    const SizedBox(height: 24),
                    CoachTipCard(tip: dashboardState.coachTip),
                    const SizedBox(height: 16),
                    const MindTimelineCard(),
                    const SizedBox(height: 16),
                    ComingUpCard(items: dashboardState.comingUpItems),
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

double _confirmedMoneySavedToday(MockTrackerState state) {
  final now = DateTime.now();
  final todayKey =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  return state.savingsEntries
      .where((entry) => entry.dateKey == todayKey && entry.isConfirmed)
      .fold(0.0, (sum, entry) => sum + entry.amount);
}
