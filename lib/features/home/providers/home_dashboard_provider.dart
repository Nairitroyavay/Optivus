
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/features/home/models/home_dashboard_state.dart';

class HomeDashboardNotifier extends StateNotifier<HomeDashboardState> {
  HomeDashboardNotifier() : super(_initialMockState());

  static HomeDashboardState _initialMockState() {
    return const HomeDashboardState(
      identityFocus: IdentityFocus(
        primaryIdentity: '',
        primaryProof: '',
      ),
      nowNextAction: null,
      missionSummary: HomeMissionSummary(
        percentage: 0.0,
        actionsDone: 0,
        actionsTotal: 0,
        focusMinutes: 0,
        moneySaved: 0,
        badHabitsAvoided: 0,
      ),
      lifeOsSnapshot: [],
      checkIns: [],
      autoInsights: [],
      trackerPreviews: [],
      coachTip: null,
      comingUpItems: [],
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
          nextActionTitle: 'Confirm saving at 8:30 PM',
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
