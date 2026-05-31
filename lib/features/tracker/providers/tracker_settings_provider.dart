import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrackerSettingsState {
  final Map<String, bool> activeTrackers;
  final List<String> trackerOrder;
  final bool hydrationReminders;
  final bool screenTimePrivacyHideNames;

  const TrackerSettingsState({
    required this.activeTrackers,
    required this.trackerOrder,
    this.hydrationReminders = true,
    this.screenTimePrivacyHideNames = false,
  });

  factory TrackerSettingsState.defaults() {
    const trackers = {
      'Meditation': true,
      'Money System': true,
      'Screen Time': true,
      'Fitness Center': true,
      'Hydration': true,
      'Focus Timer': false,
      'Nutrition': false,
      'Sleep': false,
      'Smoking': false,
      'Alcohol': false,
      'Junk Food': false,
      'Reading': false,
      'Language Learning': false,
      'Skill Practice': false,
      'Skin Care': false,
      'Custom Bad Habit': false,
      'Custom': false,
    };
    return const TrackerSettingsState(
      activeTrackers: trackers,
      trackerOrder: [
        'Meditation',
        'Money System',
        'Screen Time',
        'Fitness Center',
        'Hydration',
      ],
    );
  }

  TrackerSettingsState copyWith({
    Map<String, bool>? activeTrackers,
    List<String>? trackerOrder,
    bool? hydrationReminders,
    bool? screenTimePrivacyHideNames,
  }) {
    return TrackerSettingsState(
      activeTrackers: activeTrackers ?? this.activeTrackers,
      trackerOrder: trackerOrder ?? this.trackerOrder,
      hydrationReminders: hydrationReminders ?? this.hydrationReminders,
      screenTimePrivacyHideNames:
          screenTimePrivacyHideNames ?? this.screenTimePrivacyHideNames,
    );
  }
}

class TrackerSettingsNotifier extends StateNotifier<TrackerSettingsState> {
  TrackerSettingsNotifier() : super(TrackerSettingsState.defaults());

  void toggleTracker(String tracker) {
    final updated = Map<String, bool>.from(state.activeTrackers);
    updated[tracker] = !(updated[tracker] ?? false);
    final order =
        updated[tracker] == true && !state.trackerOrder.contains(tracker)
        ? [...state.trackerOrder, tracker]
        : state.trackerOrder;
    state = state.copyWith(activeTrackers: updated, trackerOrder: order);
  }

  void activateTracker(String tracker) {
    final updated = Map<String, bool>.from(state.activeTrackers);
    updated[tracker] = true;
    final order = state.trackerOrder.contains(tracker)
        ? state.trackerOrder
        : [...state.trackerOrder, tracker];
    state = state.copyWith(activeTrackers: updated, trackerOrder: order);
  }

  void setHydrationReminders(bool value) {
    state = state.copyWith(hydrationReminders: value);
  }

  void setScreenTimePrivacyHideNames(bool value) {
    state = state.copyWith(screenTimePrivacyHideNames: value);
  }

  void resetMockSettings() {
    state = TrackerSettingsState.defaults();
  }
}

final trackerSettingsProvider =
    StateNotifierProvider<TrackerSettingsNotifier, TrackerSettingsState>((ref) {
      return TrackerSettingsNotifier();
    });
