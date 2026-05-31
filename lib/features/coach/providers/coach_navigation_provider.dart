import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CoachDetailView {
  none,
  sessionHistory,
  coachSettings,
  newSession,
  privacyData,
}

final coachDetailViewRequestProvider = StateProvider<CoachDetailView>(
  (ref) => CoachDetailView.none,
);
