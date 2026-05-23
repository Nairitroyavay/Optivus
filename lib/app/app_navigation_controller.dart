import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controls tab navigation state for the main app shell.
/// Separates navigation logic from the UI layer.
class AppNavigationController extends StateNotifier<int> {
  AppNavigationController() : super(0);

  void setTab(int index) {
    if (index >= 0 && index <= 5) {
      state = index;
    }
  }

  void goToHome() => state = 0;
  void goToRoutine() => state = 1;
  void goToTracker() => state = 2;
  void goToCoach() => state = 3;
  void goToGoals() => state = 4;
  void goToProfile() => state = 5;
}

final appNavigationProvider =
    StateNotifierProvider<AppNavigationController, int>((ref) {
  return AppNavigationController();
});
