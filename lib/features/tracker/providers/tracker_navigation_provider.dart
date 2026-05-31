import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TrackerDetailView {
  none,
  meditation,
  money,
  fitness,
  screenTime,
  hydration,
  trackerSettings,
  usageAccessSetup,
  healthConnectSetup,
  locationMapboxSetup,
  trackerActivation,
  trackerHistory,
  focusTimer,
  badHabit,
  sleep,
  nutrition,
}

class TrackerDetailTarget {
  final TrackerDetailView view;
  final String? trackerType;
  final String? badHabitType;

  const TrackerDetailTarget({
    required this.view,
    this.trackerType,
    this.badHabitType,
  });

  static const none = TrackerDetailTarget(view: TrackerDetailView.none);

  factory TrackerDetailTarget.view(TrackerDetailView view) {
    return TrackerDetailTarget(view: view);
  }
}

final trackerDetailViewRequestProvider = StateProvider<TrackerDetailTarget>(
  (ref) => TrackerDetailTarget.none,
);
