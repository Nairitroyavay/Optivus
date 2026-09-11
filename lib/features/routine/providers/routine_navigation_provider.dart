import 'package:flutter_riverpod/flutter_riverpod.dart';

enum RoutineDetailView {
  none,
  baseTimeline,
  @Deprecated('Use baseTimeline instead')
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

  bool get isBaseTimelineRelated =>
      view == RoutineDetailView.baseTimeline ||
      view == RoutineDetailView.baseTimelineManager ||
      view == RoutineDetailView.classesSetup ||
      view == RoutineDetailView.workSetup ||
      view == RoutineDetailView.eatingSetup ||
      view == RoutineDetailView.fixedSetup ||
      view == RoutineDetailView.skinCareSetup;
}

final routineDetailViewRequestProvider = StateProvider<RoutineDetailTarget>(
  (ref) => RoutineDetailTarget.none,
);
