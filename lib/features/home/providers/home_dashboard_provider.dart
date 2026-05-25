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
        percentage: 0.65,
        actionsDone: 4,
        actionsTotal: 6,
        focusMinutes: 120,
        moneySaved: 150,
        badHabitsAvoided: 2,
      ),
      lifeOsSnapshot: [
        LifeOsPillarProgress(pillar: LifePillar.body, current: 1, target: 3),
        LifeOsPillarProgress(pillar: LifePillar.mind, current: 2, target: 2),
        LifeOsPillarProgress(pillar: LifePillar.workStudy, current: 1, target: 2),
        LifeOsPillarProgress(pillar: LifePillar.skill, current: 0, target: 1),
        LifeOsPillarProgress(pillar: LifePillar.finance, current: 1, target: 1),
        LifeOsPillarProgress(pillar: LifePillar.focus, current: 1, target: 2),
        LifeOsPillarProgress(pillar: LifePillar.growth, current: 0, target: 1),
      ],
      checkIns: [
        CheckInItem(id: 'water', title: 'Water', icon: '💧', options: ['+250ml', 'Done']),
        CheckInItem(id: 'sleep', title: 'Sleep', icon: '😴', options: ['Good', 'Okay', 'Poor']),
        CheckInItem(id: 'stress', title: 'Stress', icon: '😫', options: ['Low', 'Medium', 'High']),
        CheckInItem(id: 'mood', title: 'Mood', icon: '😊', options: ['Good', 'Okay', 'Low']),
        CheckInItem(id: 'cigarettes', title: 'Cigarettes', icon: '🚬', options: ['Avoided', 'Craving', 'Relapsed']),
        CheckInItem(id: 'alcohol', title: 'Alcohol', icon: '🍷', options: ['Avoided', 'Craving', 'Relapsed']),
        CheckInItem(id: 'junk_food', title: 'Junk Food', icon: '🍔', options: ['Avoided', 'Craving', 'Relapsed']),
        CheckInItem(id: 'money_saved', title: 'Money Saved', icon: '💰', options: ['₹10', '₹20', 'Custom']),
      ],
      autoInsights: [
        AutoInsight(
          title: 'Instagram 1h 20m',
          description: 'Risk: Medium',
          risk: InsightRisk.medium,
        ),
      ],
      trackerPreviews: [
        TrackerPreview(id: 'meditation', title: 'Meditation', subtitle: '0 / 10 min', buttonText: 'Start'),
        TrackerPreview(id: 'screen_time', title: 'Screen Time', subtitle: '2h 15m (Limit: 3h)', buttonText: 'Log'),
        TrackerPreview(id: 'money', title: 'Money System', subtitle: 'Save ₹50 today', buttonText: 'Save via UPI'),
        TrackerPreview(id: 'hydration', title: 'Hydration', subtitle: '3 / 8 glasses', buttonText: 'Drink'),
        TrackerPreview(id: 'smoking', title: 'Smoking', subtitle: '0 cigarettes', buttonText: 'Log'),
        TrackerPreview(id: 'workout', title: 'Workout', subtitle: 'Not started', buttonText: 'Start'),
        TrackerPreview(id: 'focus', title: 'Deep Focus', subtitle: '45m completed', buttonText: 'Focus'),
      ],
      coachTip: CoachTip(
        coachName: 'Sensei',
        message: 'Start with one small win. Do not wait for motivation.',
      ),
      comingUpItems: [
        ComingUpItem(
          time: '9:00',
          amPm: 'AM',
          title: 'Class',
          icon: Icons.school_outlined,
          iconColor: Color(0xFF6B5319),
          iconBgColor: Color(0xFFF6E8CE),
          isNext: true,
        ),
        ComingUpItem(
          time: '6:30',
          amPm: 'PM',
          title: 'Gym',
          icon: Icons.fitness_center,
          iconColor: Color(0xFF754545),
          iconBgColor: Color(0xFFFAEAEC),
        ),
        ComingUpItem(
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

  void cycleNowNextState() {
    final types = NowActionType.values;
    final currentIndex = types.indexOf(state.nowNextAction!.currentType);
    final nextIndex = (currentIndex + 1) % types.length;
    final nextType = types[nextIndex];
    
    NowNextActionState newState;
    switch (nextType) {
      case NowActionType.flexibleTask:
        newState = const NowNextActionState(
          currentType: NowActionType.flexibleTask,
          currentTitle: 'Meditation',
          currentSubtitle: '5 min • Flexible task',
          nextActionTitle: 'Read 5 pages',
        );
        break;
      case NowActionType.hardBlock:
        newState = const NowNextActionState(
          currentType: NowActionType.hardBlock,
          currentTitle: 'Class',
          currentSubtitle: '9:00 AM - 5:00 PM • Hard block',
          nextActionTitle: 'Gym at 6:30 PM',
        );
        break;
      case NowActionType.workBlock:
        newState = const NowNextActionState(
          currentType: NowActionType.workBlock,
          currentTitle: 'Work',
          currentSubtitle: '10:00 AM - 6:00 PM • Hard block',
          nextActionTitle: 'Save ₹10 at 8:30 PM',
        );
        break;
      case NowActionType.freeTime:
        newState = const NowNextActionState(
          currentType: NowActionType.freeTime,
          currentTitle: 'Free time',
          currentSubtitle: 'Next small win: Read 5 pages',
          nextActionTitle: 'Read 5 pages',
        );
        break;
      case NowActionType.missedTask:
        newState = const NowNextActionState(
          currentType: NowActionType.missedTask,
          currentTitle: 'Meditation',
          currentSubtitle: 'Restart with 2 minutes now.',
          missedTaskTime: '7:30 AM',
          nextActionTitle: 'Read 5 pages',
        );
        break;
    }
    
    state = state.copyWith(nowNextAction: newState);
  }
}

final homeDashboardProvider =
    StateNotifierProvider<HomeDashboardNotifier, HomeDashboardState>((ref) {
      return HomeDashboardNotifier();
    });
