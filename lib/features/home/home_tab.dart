import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/features/home/providers/home_dashboard_provider.dart';

import 'widgets/home_header.dart';
import 'widgets/now_next_action_card.dart';
import 'widgets/today_mission_card.dart';
import 'widgets/life_os_snapshot.dart';
import 'widgets/today_check_in_card.dart';
import 'widgets/auto_insights_card.dart';
import 'widgets/tracker_preview_section.dart';
import 'widgets/coach_tip_card.dart';
import 'widgets/mind_timeline_card.dart';
import 'widgets/coming_up_card.dart';
import 'widgets/floating_quick_add.dart';

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

    return Scaffold(
      backgroundColor: Colors.transparent, // Background gradient is handled by app shell
      floatingActionButton: const FloatingQuickAdd(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: HomeHeader(userName: userName),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NowNextActionCard(actionState: dashboardState.nowNextAction),
                    const SizedBox(height: 16),
                    TodayMissionCard(summary: dashboardState.missionSummary),
                    const SizedBox(height: 16),
                    LifeOsSnapshot(pillars: dashboardState.lifeOsSnapshot),
                    const SizedBox(height: 16),
                    TodayCheckInCard(checkIns: dashboardState.checkIns),
                    const SizedBox(height: 16),
                    AutoInsightsCard(insights: dashboardState.autoInsights),
                    const SizedBox(height: 24),
                    TrackerPreviewSection(previews: dashboardState.trackerPreviews),
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
