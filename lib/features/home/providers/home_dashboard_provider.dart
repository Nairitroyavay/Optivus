import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/features/home/models/home_dashboard_state.dart';

class HomeDashboardNotifier extends StateNotifier<HomeDashboardState> {
  HomeDashboardNotifier() : super(_initialMockState());

  static HomeDashboardState _initialMockState() {
    return const HomeDashboardState(
      identityFocus: IdentityFocus(
        primaryIdentity: 'Become Disciplined',
        primaryProof: 'Complete your first non-negotiable task.',
      ),
      nowNextAction: NowNextActionState(
        currentType: NowActionType.flexibleTask,
        currentTitle: 'Meditation',
        currentSubtitle: '5 min • Flexible task',
        nextActionTitle: 'Read 5 pages',
      ),
      missionSummary: HomeMissionSummary(
        percentage: 0.0,
        actionsDone: 0,
        actionsTotal: 6,
        focusMinutes: 0,
        moneySaved: 0,
        badHabitsAvoided: 0,
      ),
      lifeOsSnapshot: [
        LifeOsPillarProgress(pillar: LifePillar.body, current: 0, target: 1),
        LifeOsPillarProgress(pillar: LifePillar.mind, current: 0, target: 1),
        LifeOsPillarProgress(
          pillar: LifePillar.workStudy,
          current: 0,
          target: 2,
        ),
        LifeOsPillarProgress(pillar: LifePillar.finance, current: 0, target: 1),
        LifeOsPillarProgress(pillar: LifePillar.focus, current: 0, target: 1),
        LifeOsPillarProgress(pillar: LifePillar.growth, current: 0, target: 1),
      ],
      checkIns: [
        CheckInItem(
          id: 'water',
          title: 'Water',
          icon: '💧',
          options: ['+250ml'],
        ),
        CheckInItem(
          id: 'sleep',
          title: 'Sleep',
          icon: '😴',
          options: ['Good', 'Okay', 'Poor'],
        ),
      ],
      autoInsights: [
        AutoInsight(
          title: 'Instagram 1h 20m',
          description: 'Risk: Medium',
          risk: InsightRisk.medium,
        ),
      ],
      trackerPreviews: [
        TrackerPreview(
          id: 'money',
          title: 'Money System',
          subtitle: 'Save ₹10 today',
          buttonText: 'Save via UPI',
        ),
        TrackerPreview(
          id: 'med',
          title: 'Meditation',
          subtitle: '0 / 5 min',
          buttonText: 'Start',
        ),
      ],
      coachTip: CoachTip(
        coachName: 'Sensei',
        message: 'Start with one small win. Do not wait for motivation.',
      ),
      comingUpItems: [
        const ComingUpItem(
          time: '9:00',
          amPm: 'AM',
          title: 'Class',
          icon: Icons.school_outlined,
          iconColor: Color(0xFF6B5319),
          iconBgColor: Color(0xFFF6E8CE),
          isNext: true,
        ),
        const ComingUpItem(
          time: '6:30',
          amPm: 'PM',
          title: 'Gym',
          icon: Icons.fitness_center,
          iconColor: Color(0xFF754545),
          iconBgColor: Color(0xFFFAEAEC),
        ),
        const ComingUpItem(
          time: '9:45',
          amPm: 'PM',
          title: 'Save ₹10',
          icon: Icons.savings_outlined,
          iconColor: Color(0xFF4A3B3D),
          iconBgColor: Color(0xFFF1EBEB),
        ),
      ],
    );
  }

  void completeCheckIn(String checkInId, String option) {
    final newCheckIns = state.checkIns.map((item) {
      if (item.id == checkInId) {
        return item.copyWith(selectedOption: option);
      }
      return item;
    }).toList();

    state = state.copyWith(checkIns: newCheckIns);
  }

  void completeTracker(String trackerId) {
    // Mock update logic
  }
}

final homeDashboardProvider =
    StateNotifierProvider<HomeDashboardNotifier, HomeDashboardState>((ref) {
      return HomeDashboardNotifier();
    });
