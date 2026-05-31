import 'package:flutter_riverpod/flutter_riverpod.dart';

enum RoutineDetailView {
  none,
  baseTimelineManager,
  classesSetup,
  workSetup,
  eatingSetup,
  fixedSetup,
  skinCareSetup,
  importReview,
  routineSettings,
  habitSystems,
  routineHistory,
}

enum RoutineImportSource { classes, work, eating, skinCare }

class RoutineDetailTarget {
  final RoutineDetailView view;
  final RoutineImportSource? importSource;

  const RoutineDetailTarget({required this.view, this.importSource});

  static const none = RoutineDetailTarget(view: RoutineDetailView.none);
}

final routineDetailViewRequestProvider = StateProvider<RoutineDetailTarget>(
  (ref) => RoutineDetailTarget.none,
);
