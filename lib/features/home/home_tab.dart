import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/core/utils/currency_formatter.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/region_settings_provider.dart';
import 'package:optivus/features/home/models/home_dashboard_state.dart';
import 'package:optivus/features/home/providers/home_dashboard_provider.dart';
import 'package:optivus/features/home/providers/home_navigation_provider.dart';
import 'package:optivus/features/home/screens/home_mission_detail_screen.dart';

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
    final detailTarget = ref.watch(homeDetailViewRequestProvider);
    final profile = ref.watch(mockUserProfileProvider);
    final auth = ref.watch(authProvider);
    final userName = _safeHomeDisplayName(
      profileName: profile.displayName,
      authDisplayName: auth.user?.displayName,
      email: auth.user?.email ?? profile.email,
    );

    final dashboardState = ref.watch(homeDashboardProvider);
    final trackerState = ref.watch(mockTrackerProvider);
    final region = ref.watch(regionSettingsProvider);
    final todayMoneySaved = _confirmedMoneySavedToday(trackerState);
    final moneyGoal = trackerState.moneyGoal;
    final checkIns = dashboardState.checkIns
        .map((item) {
          if (item.id != 'money_saved') return item;
          final options = <String>{
            formatMoney(moneyGoal.tinySaveAmount, region),
            formatMoney(moneyGoal.dailyTarget, region),
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
      moneySavedLabel: formatMoney(todayMoneySaved, region),
      badHabitsAvoided: dashboardState.missionSummary.badHabitsAvoided,
    );

    void closeDetail() {
      ref.read(homeDetailViewRequestProvider.notifier).state =
          const HomeDetailTarget.none();
    }

    if (detailTarget.view == HomeDetailView.missionDetail) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) closeDetail();
        },
        child: HomeMissionDetailScreen(
          summary: missionSummary,
          onBack: closeDetail,
        ),
      );
    }

    final bottomReserve = liquidTabBarReserve(context) + 8;

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
                padding: EdgeInsets.fromLTRB(20, 16, 20, bottomReserve),
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
                    TodayMissionCard(
                      summary: missionSummary,
                      onTap: () {
                        ref.read(homeDetailViewRequestProvider.notifier).state =
                            const HomeDetailTarget.mission();
                      },
                    ),
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

String _safeHomeDisplayName({
  required String? profileName,
  required String? authDisplayName,
  required String? email,
}) {
  String clean(String? value) => (value ?? '').trim();

  final emailValue = clean(email).toLowerCase();
  final emailLocalPart = emailValue.contains('@')
      ? emailValue.split('@').first
      : '';

  bool isEmailLike(String value) {
    final lower = value.toLowerCase();
    final hasWhitespace = RegExp(r'\s+').hasMatch(value);
    return lower.contains('@') ||
        lower.contains('.com') ||
        lower.contains('.net') ||
        lower.contains('.org') ||
        (emailLocalPart.isNotEmpty && lower == emailLocalPart) ||
        (value.length > 24 && !hasWhitespace);
  }

  final candidates = [clean(profileName), clean(authDisplayName)];

  for (final candidate in candidates) {
    if (candidate.isEmpty) continue;
    if (isEmailLike(candidate)) continue;

    final firstPart = candidate.split(RegExp(r'\s+')).first.trim();
    if (firstPart.isNotEmpty && firstPart.length <= 18) {
      return firstPart;
    }

    return candidate.length > 18
        ? '${candidate.substring(0, 18)}...'
        : candidate;
  }

  if (emailValue == 'test@optivus.dev') return 'Nairit';
  return 'there';
}

double _confirmedMoneySavedToday(MockTrackerState state) {
  final now = DateTime.now();
  final todayKey =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  return state.savingsEntries
      .where((entry) => entry.dateKey == todayKey && entry.isConfirmed)
      .fold(0.0, (sum, entry) => sum + entry.amount);
}
