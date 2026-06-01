import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HomeDetailView { none, missionDetail }

class HomeDetailTarget {
  final HomeDetailView view;

  const HomeDetailTarget({required this.view});

  const HomeDetailTarget.none() : view = HomeDetailView.none;
  const HomeDetailTarget.mission() : view = HomeDetailView.missionDetail;
}

final homeDetailViewRequestProvider = StateProvider<HomeDetailTarget>(
  (ref) => const HomeDetailTarget.none(),
);
