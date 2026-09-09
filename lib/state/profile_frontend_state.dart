import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/goal_models.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';

final currentRoutineItemsProvider = Provider<List<RoutineItem>>((ref) {
  return ref.watch(routineNotifierProvider).items;
});

final currentGoalsProvider = Provider<List<GoalModel>>((ref) {
  return ref.watch(mockGoalProvider);
});

final currentCoachPreferencesProvider = Provider<CoachPreferences>((ref) {
  return ref.watch(mockCoachPreferencesProvider);
});

void prepareProfileSetupRerun(WidgetRef ref) {
  final auth = ref.read(authProvider);
  final user = auth.user;
  final profile = ref.read(userProfileProvider);
  final uid = user?.uid ?? profile.uid;

  ref.read(onboardingStateProvider.notifier).reset(uid);
  ref
      .read(userProfileProvider.notifier)
      .updateProfile(
        profile.copyWith(onboardingCompleted: false, onboardingStep: 0),
      );

  if (user != null) {
    ref.read(authProvider.notifier).markOnboardingIncomplete(user);
  }
}
