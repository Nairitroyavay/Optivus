import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/state/app_state.dart';

final hydrationTodayTotalProvider = Provider<int>((ref) {
  final logs = ref.watch(mockTrackerProvider).hydrationLogs;
  return logs.fold<int>(0, (sum, log) => sum + log.amountMl);
});

final hydrationGoalMlProvider = Provider<int>((ref) => 2500);
