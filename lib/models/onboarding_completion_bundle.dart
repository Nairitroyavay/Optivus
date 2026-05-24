import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/goal_models.dart';
import 'package:optivus/models/money_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';

class OnboardingCompletionBundle {
  static const int schemaVersion = 1;

  final String uid;
  final int version;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> userProfilePatch;
  final List<TimelineBlockDraft> baseTimelineBlocks;
  final List<FinalTimelineItem> finalTimelineItems;
  final List<RoutineItem> routineItemsForApp;
  final List<GoodHabitTemplateBundle> goodHabitTemplates;
  final List<BadHabitCheckInBundle> badHabitCheckIns;
  final List<GoalModel> identityGoalSystems;
  final NotificationPreferences notificationPreferences;
  final CoachPreferences coachPreferences;
  final MoneyGoal? moneyGoal;
  final List<String> warnings;
  final List<String> duplicateSystemKeysMerged;

  const OnboardingCompletionBundle({
    required this.uid,
    this.version = schemaVersion,
    this.source = OnboardingDraft.sourceOnboarding,
    required this.createdAt,
    required this.updatedAt,
    required this.userProfilePatch,
    required this.baseTimelineBlocks,
    required this.finalTimelineItems,
    required this.routineItemsForApp,
    required this.goodHabitTemplates,
    required this.badHabitCheckIns,
    required this.identityGoalSystems,
    required this.notificationPreferences,
    required this.coachPreferences,
    required this.moneyGoal,
    required this.warnings,
    required this.duplicateSystemKeysMerged,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'schemaVersion': version,
      'source': source,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'onboardingCompleted': true,
      'userProfilePatch': userProfilePatch,
      'baseTimelineBlocks': baseTimelineBlocks
          .map((block) => block.toMap())
          .toList(),
      'finalTimelineItems': finalTimelineItems
          .map((item) => item.toMap())
          .toList(),
      'routineItemsForApp': routineItemsForApp.map(_routineItemToMap).toList(),
      'goodHabitTemplates': goodHabitTemplates
          .map((item) => item.toMap())
          .toList(),
      'badHabitCheckIns': badHabitCheckIns.map((item) => item.toMap()).toList(),
      'identityGoalSystems': identityGoalSystems.map(_goalToMap).toList(),
      'notificationPreferences': {
        'morningStart': notificationPreferences.morningStart,
        'nextTask': notificationPreferences.nextTask,
        'eating': notificationPreferences.eating,
        'badHabitCheckIn': notificationPreferences.badHabitCheckIn,
        'savings': notificationPreferences.savings,
        'nightReflection': notificationPreferences.nightReflection,
        'intensity': notificationPreferences.intensity.name,
      },
      'coachPreferences': {
        'name': coachPreferences.name,
        'style': coachPreferences.style,
        'allowRoutineContext': coachPreferences.allowRoutineContext,
        'allowTrackerContext': coachPreferences.allowTrackerContext,
        'allowGoalsContext': coachPreferences.allowGoalsContext,
        'allowProfileContext': coachPreferences.allowProfileContext,
        'shareSelectedNotesOnly': coachPreferences.shareSelectedNotesOnly,
      },
      'moneyGoal': moneyGoal == null
          ? null
          : {
              'id': moneyGoal!.id,
              'dailyTarget': moneyGoal!.dailyTarget,
              'totalConfirmedSaved': moneyGoal!.totalConfirmedSaved,
              'totalPotentialSaved': moneyGoal!.totalPotentialSaved,
              'streakDays': moneyGoal!.streakDays,
              'streakLevel': moneyGoal!.streakLevel,
            },
      'warnings': warnings,
      'duplicateSystemKeysMerged': duplicateSystemKeysMerged,
    };
  }
}

class GoodHabitTemplateBundle {
  final String id;
  final String systemKey;
  final String title;
  final int durationMinutes;
  final String frequency;
  final String bestTime;
  final String priority;
  final List<int> repeatDays;

  const GoodHabitTemplateBundle({
    required this.id,
    required this.systemKey,
    required this.title,
    required this.durationMinutes,
    required this.frequency,
    required this.bestTime,
    required this.priority,
    required this.repeatDays,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'systemKey': systemKey,
    'title': title,
    'durationMinutes': durationMinutes,
    'frequency': frequency,
    'bestTime': bestTime,
    'priority': priority,
    'repeatDays': repeatDays,
  };

  Map<String, dynamic> toMapWithMetadata(String uid) => {
    'uid': uid,
    'schemaVersion': OnboardingCompletionBundle.schemaVersion,
    'createdAt': DateTime.now().toIso8601String(),
    'updatedAt': DateTime.now().toIso8601String(),
    'source': OnboardingDraft.sourceOnboarding,
    'onboardingCompleted': true,
    ...toMap(),
  };
}

class BadHabitCheckInBundle {
  final String id;
  final String habitKey;
  final String displayName;
  final double dailySpend;
  final int lostTimeMinutes;
  final bool badHabitCheckInEnabled;
  final bool moneySavedTrackerEnabled;
  final String? linkedRoutineItemId;

  const BadHabitCheckInBundle({
    required this.id,
    required this.habitKey,
    required this.displayName,
    required this.dailySpend,
    required this.lostTimeMinutes,
    required this.badHabitCheckInEnabled,
    required this.moneySavedTrackerEnabled,
    this.linkedRoutineItemId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'habitKey': habitKey,
    'displayName': displayName,
    'dailySpend': dailySpend,
    'lostTimeMinutes': lostTimeMinutes,
    'badHabitCheckInEnabled': badHabitCheckInEnabled,
    'moneySavedTrackerEnabled': moneySavedTrackerEnabled,
    'linkedRoutineItemId': linkedRoutineItemId,
  };

  Map<String, dynamic> toMapWithMetadata(String uid) => {
    'uid': uid,
    'schemaVersion': OnboardingCompletionBundle.schemaVersion,
    'createdAt': DateTime.now().toIso8601String(),
    'updatedAt': DateTime.now().toIso8601String(),
    'source': OnboardingDraft.sourceOnboarding,
    'onboardingCompleted': true,
    ...toMap(),
  };
}

Map<String, dynamic> _routineItemToMap(RoutineItem item) => {
  'id': item.id,
  'title': item.title,
  'startMinute': item.startMinute,
  'endMinute': item.endMinute,
  'crossesMidnight': item.crossesMidnight,
  'endsNextDay': item.endsNextDay,
  'repeatDays': item.repeatDays,
  'location': item.location,
  'blockType': item.blockType.name,
  'notes': item.notes,
  'subtasks': item.subtasks,
  'mealCategory': item.mealCategory,
  'dishes': item.dishes,
  'calories': item.calories,
  'protein': item.protein,
  'skincareProducts': item.skincareProducts,
  'hasConflict': item.hasConflict,
  'conflictMessage': item.conflictMessage,
};

Map<String, dynamic> _goalToMap(GoalModel goal) => {
  'id': goal.id,
  'identityTitle': goal.identityTitle,
  'purposeStatement': goal.purposeStatement,
  'progressPercent': goal.progressPercent,
  'systems': goal.systems
      .map(
        (system) => {
          'id': system.id,
          'description': system.description,
          'linkedRoutineTaskIds': system.linkedRoutineTaskIds,
          'linkedTrackerIds': system.linkedTrackerIds,
        },
      )
      .toList(),
  'dailyProof': {
    'id': goal.dailyProof.id,
    'title': goal.dailyProof.title,
    'tinyVersion': goal.dailyProof.tinyVersion,
    'normalVersion': goal.dailyProof.normalVersion,
    'strongVersion': goal.dailyProof.strongVersion,
    'selectedDifficulty': goal.dailyProof.selectedDifficulty,
    'isCompleted': goal.dailyProof.isCompleted,
    'note': goal.dailyProof.note,
    'sharedToCoach': goal.dailyProof.sharedToCoach,
  },
  'streakDays': goal.streakDays,
  'isArchived': goal.isArchived,
  'isPaused': goal.isPaused,
};
