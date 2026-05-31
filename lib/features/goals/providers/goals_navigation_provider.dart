import 'package:flutter_riverpod/flutter_riverpod.dart';

enum GoalsDetailView {
  none,
  addGoal,
  goalDetail,
  weeklyReview,
  archivedGoals,
  goalSettings,
}

class GoalsDetailTarget {
  final GoalsDetailView view;
  final String? goalId;

  const GoalsDetailTarget({required this.view, this.goalId});

  static const none = GoalsDetailTarget(view: GoalsDetailView.none);
}

final goalsDetailViewRequestProvider = StateProvider<GoalsDetailTarget>(
  (ref) => GoalsDetailTarget.none,
);
