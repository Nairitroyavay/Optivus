import 'package:flutter/material.dart';

enum NowActionType { flexibleTask, hardBlock, workBlock, freeTime, missedTask }

enum LifePillar { body, mind, workStudy, skill, finance, focus, growth }

enum InsightRisk { low, medium, high }

@immutable
class HomeMissionSummary {
  final double percentage;
  final int actionsDone;
  final int actionsTotal;
  final int focusMinutes;
  final int moneySaved;
  final int badHabitsAvoided;

  const HomeMissionSummary({
    this.percentage = 0.0,
    this.actionsDone = 0,
    this.actionsTotal = 0,
    this.focusMinutes = 0,
    this.moneySaved = 0,
    this.badHabitsAvoided = 0,
  });
}

@immutable
class NowNextActionState {
  final NowActionType currentType;
  final String currentTitle;
  final String currentSubtitle;
  final String nextActionTitle;
  final String? missedTaskTime; // Only for missedTask type

  const NowNextActionState({
    required this.currentType,
    required this.currentTitle,
    required this.currentSubtitle,
    required this.nextActionTitle,
    this.missedTaskTime,
  });
}

@immutable
class IdentityFocus {
  final String primaryIdentity;
  final String primaryProof;
  final String? secondaryIdentity;

  const IdentityFocus({
    required this.primaryIdentity,
    required this.primaryProof,
    this.secondaryIdentity,
  });
}

@immutable
class LifeOsPillarProgress {
  final LifePillar pillar;
  final int current;
  final int target;

  const LifeOsPillarProgress({
    required this.pillar,
    required this.current,
    required this.target,
  });
}

@immutable
class CheckInItem {
  final String id;
  final String title;
  final String icon;
  final List<String> options;
  final String? selectedOption;

  const CheckInItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.options,
    this.selectedOption,
  });

  CheckInItem copyWith({String? selectedOption}) {
    return CheckInItem(
      id: id,
      title: title,
      icon: icon,
      options: options,
      selectedOption: selectedOption ?? this.selectedOption,
    );
  }
}

@immutable
class AutoInsight {
  final String title;
  final String description;
  final InsightRisk risk;

  const AutoInsight({
    required this.title,
    required this.description,
    required this.risk,
  });
}

@immutable
class TrackerPreview {
  final String id;
  final String title;
  final String subtitle;
  final String buttonText;

  const TrackerPreview({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.buttonText,
  });
}

@immutable
class CoachTip {
  final String coachName;
  final String message;

  const CoachTip({required this.coachName, required this.message});
}

@immutable
class ComingUpItem {
  final String time;
  final String amPm;
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final bool isNext;
  final String? badgeText;

  const ComingUpItem({
    required this.time,
    required this.amPm,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    this.isNext = false,
    this.badgeText,
  });
}

@immutable
class HomeDashboardState {
  final IdentityFocus? identityFocus;
  final NowNextActionState? nowNextAction;
  final HomeMissionSummary missionSummary;
  final List<LifeOsPillarProgress> lifeOsSnapshot;
  final List<CheckInItem> checkIns;
  final List<AutoInsight> autoInsights;
  final List<TrackerPreview> trackerPreviews;
  final CoachTip? coachTip;
  final List<ComingUpItem> comingUpItems;

  const HomeDashboardState({
    this.identityFocus,
    this.nowNextAction,
    this.missionSummary = const HomeMissionSummary(),
    this.lifeOsSnapshot = const [],
    this.checkIns = const [],
    this.autoInsights = const [],
    this.trackerPreviews = const [],
    this.coachTip,
    this.comingUpItems = const [],
  });

  HomeDashboardState copyWith({
    IdentityFocus? identityFocus,
    NowNextActionState? nowNextAction,
    HomeMissionSummary? missionSummary,
    List<LifeOsPillarProgress>? lifeOsSnapshot,
    List<CheckInItem>? checkIns,
    List<AutoInsight>? autoInsights,
    List<TrackerPreview>? trackerPreviews,
    CoachTip? coachTip,
    List<ComingUpItem>? comingUpItems,
  }) {
    return HomeDashboardState(
      identityFocus: identityFocus ?? this.identityFocus,
      nowNextAction: nowNextAction ?? this.nowNextAction,
      missionSummary: missionSummary ?? this.missionSummary,
      lifeOsSnapshot: lifeOsSnapshot ?? this.lifeOsSnapshot,
      checkIns: checkIns ?? this.checkIns,
      autoInsights: autoInsights ?? this.autoInsights,
      trackerPreviews: trackerPreviews ?? this.trackerPreviews,
      coachTip: coachTip ?? this.coachTip,
      comingUpItems: comingUpItems ?? this.comingUpItems,
    );
  }
}
