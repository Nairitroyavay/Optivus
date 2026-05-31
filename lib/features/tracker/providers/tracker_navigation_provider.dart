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
}

final trackerDetailViewRequestProvider = StateProvider<TrackerDetailView>(
  (ref) => TrackerDetailView.none,
);
