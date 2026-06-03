import 'package:cloud_firestore/cloud_firestore.dart';
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
  final List<OnboardingUploadedAssetReference> uploadedAssetReferences;
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
    required this.uploadedAssetReferences,
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
      'uploadedAssetReferences': uploadedAssetReferences
          .map((asset) => asset.toMap())
          .toList(),
      'warnings': warnings,
      'duplicateSystemKeysMerged': duplicateSystemKeysMerged,
    };
  }

  factory OnboardingCompletionBundle.fromMap(Map<String, dynamic> map) {
    final createdAt = _bundleDateTimeFromValue(map['createdAt']);
    final updatedAt = _bundleDateTimeFromValue(map['updatedAt']);
    return OnboardingCompletionBundle(
      uid: map['uid'] as String? ?? '',
      version:
          (map['schemaVersion'] as num?)?.toInt() ??
          (map['version'] as num?)?.toInt() ??
          schemaVersion,
      source: map['source'] as String? ?? OnboardingDraft.sourceOnboarding,
      createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          updatedAt ?? createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      userProfilePatch: _bundleMap(map['userProfilePatch']),
      baseTimelineBlocks: _bundleReadList(
        map['baseTimelineBlocks'],
        TimelineBlockDraft.fromMap,
      ),
      finalTimelineItems: _bundleReadList(
        map['finalTimelineItems'],
        FinalTimelineItem.fromMap,
      ),
      routineItemsForApp: _bundleReadList(
        map['routineItemsForApp'],
        RoutineItem.fromMap,
      ),
      goodHabitTemplates: _bundleReadList(
        map['goodHabitTemplates'],
        GoodHabitTemplateBundle.fromMap,
      ),
      badHabitCheckIns: _bundleReadList(
        map['badHabitCheckIns'],
        BadHabitCheckInBundle.fromMap,
      ),
      identityGoalSystems: _bundleReadList(
        map['identityGoalSystems'],
        _goalFromMap,
      ),
      notificationPreferences: _notificationPreferencesFromMap(
        _bundleMap(map['notificationPreferences']),
      ),
      coachPreferences: _coachPreferencesFromMap(
        _bundleMap(map['coachPreferences']),
      ),
      moneyGoal: map['moneyGoal'] is Map
          ? _moneyGoalFromMap(_bundleMap(map['moneyGoal']))
          : null,
      uploadedAssetReferences: _bundleReadList(
        map['uploadedAssetReferences'],
        OnboardingUploadedAssetReference.fromMap,
      ),
      warnings: _bundleStringList(map['warnings']),
      duplicateSystemKeysMerged: _bundleStringList(
        map['duplicateSystemKeysMerged'],
      ),
    );
  }
}

class OnboardingUploadedAssetReference {
  final String id;
  final String section;
  final String mode;
  final String? uploadedAssetId;
  final String? uploadedAssetR2Key;
  final String? uploadedAssetStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OnboardingUploadedAssetReference({
    required this.id,
    required this.section,
    required this.mode,
    required this.createdAt,
    required this.updatedAt,
    this.uploadedAssetId,
    this.uploadedAssetR2Key,
    this.uploadedAssetStatus,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'section': section,
    'mode': mode,
    'uploadedAssetId': uploadedAssetId,
    'uploadedAssetR2Key': uploadedAssetR2Key,
    'uploadedAssetStatus': uploadedAssetStatus,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory OnboardingUploadedAssetReference.fromMap(Map<String, dynamic> map) {
    final createdAt = _bundleDateTimeFromValue(map['createdAt']);
    final updatedAt = _bundleDateTimeFromValue(map['updatedAt']);
    return OnboardingUploadedAssetReference(
      id: map['id'] as String? ?? '',
      section: map['section'] as String? ?? '',
      mode: map['mode'] as String? ?? '',
      uploadedAssetId: map['uploadedAssetId'] as String?,
      uploadedAssetR2Key: map['uploadedAssetR2Key'] as String?,
      uploadedAssetStatus: map['uploadedAssetStatus'] as String?,
      createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          updatedAt ?? createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
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

  factory GoodHabitTemplateBundle.fromMap(Map<String, dynamic> map) {
    return GoodHabitTemplateBundle(
      id: map['id'] as String? ?? '',
      systemKey: map['systemKey'] as String? ?? '',
      title: map['title'] as String? ?? '',
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 15,
      frequency: map['frequency'] as String? ?? 'daily',
      bestTime: map['bestTime'] as String? ?? 'anytime',
      priority: map['priority'] as String? ?? 'good_to_do',
      repeatDays: _bundleIntList(map['repeatDays']),
    );
  }

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

  factory BadHabitCheckInBundle.fromMap(Map<String, dynamic> map) {
    return BadHabitCheckInBundle(
      id: map['id'] as String? ?? '',
      habitKey: map['habitKey'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      dailySpend: (map['dailySpend'] as num?)?.toDouble() ?? 0,
      lostTimeMinutes: (map['lostTimeMinutes'] as num?)?.toInt() ?? 0,
      badHabitCheckInEnabled: map['badHabitCheckInEnabled'] as bool? ?? true,
      moneySavedTrackerEnabled:
          map['moneySavedTrackerEnabled'] as bool? ?? true,
      linkedRoutineItemId: map['linkedRoutineItemId'] as String?,
    );
  }

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

Map<String, dynamic> _routineItemToMap(RoutineItem item) => item.toMap();

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

DateTime? _bundleDateTimeFromValue(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

Map<String, dynamic> _bundleMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<T> _bundleReadList<T>(
  Object? value,
  T Function(Map<String, dynamic>) mapper,
) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => mapper(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

List<int> _bundleIntList(Object? value) {
  if (value is! List) return const [1, 2, 3, 4, 5, 6, 7];
  final days =
      value
          .whereType<num>()
          .map((item) => item.toInt())
          .where((item) => item >= 1 && item <= 7)
          .toSet()
          .toList(growable: false)
        ..sort();
  return days.isEmpty ? const [1, 2, 3, 4, 5, 6, 7] : days;
}

List<String> _bundleStringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList(growable: false);
}

NotificationPreferences _notificationPreferencesFromMap(
  Map<String, dynamic> map,
) {
  return NotificationPreferences(
    morningStart: map['morningStart'] as bool? ?? true,
    nextTask: map['nextTask'] as bool? ?? true,
    eating: map['eating'] as bool? ?? true,
    badHabitCheckIn: map['badHabitCheckIn'] as bool? ?? true,
    savings: map['savings'] as bool? ?? true,
    nightReflection: map['nightReflection'] as bool? ?? true,
    intensity: _enumFromName(
      NotificationIntensity.values,
      map['intensity'] as String?,
      NotificationIntensity.medium,
    ),
  );
}

CoachPreferences _coachPreferencesFromMap(Map<String, dynamic> map) {
  return CoachPreferences(
    name: map['name'] as String? ?? 'Coach',
    style: map['style'] as String? ?? 'Supportive',
    allowRoutineContext: map['allowRoutineContext'] as bool? ?? true,
    allowTrackerContext: map['allowTrackerContext'] as bool? ?? true,
    allowGoalsContext: map['allowGoalsContext'] as bool? ?? true,
    allowProfileContext: map['allowProfileContext'] as bool? ?? true,
    shareSelectedNotesOnly: map['shareSelectedNotesOnly'] as bool? ?? true,
  );
}

MoneyGoal _moneyGoalFromMap(Map<String, dynamic> map) {
  return MoneyGoal(
    id: map['id'] as String? ?? '',
    currencyCode: map['currencyCode'] as String? ?? 'USD',
    dailyTarget: (map['dailyTarget'] as num?)?.toDouble() ?? 10.0,
    tinySaveAmount: (map['tinySaveAmount'] as num?)?.toDouble() ?? 5.0,
    totalConfirmedSaved:
        (map['totalConfirmedSaved'] as num?)?.toDouble() ?? 0.0,
    totalPotentialSaved:
        (map['totalPotentialSaved'] as num?)?.toDouble() ?? 0.0,
    streakDays: (map['streakDays'] as num?)?.toInt() ?? 0,
    bestStreakDays: (map['bestStreakDays'] as num?)?.toInt() ?? 0,
    streakLevel: (map['streakLevel'] as num?)?.toInt() ?? 1,
    successfulDaysAtCurrentLevel:
        (map['successfulDaysAtCurrentLevel'] as num?)?.toInt() ?? 0,
    currentLevelAmount: (map['currentLevelAmount'] as num?)?.toDouble() ?? 10.0,
    nextLevelAmount: (map['nextLevelAmount'] as num?)?.toDouble() ?? 25.0,
    levelUpAfterDays: (map['levelUpAfterDays'] as num?)?.toInt() ?? 5,
    destinationLabel: map['destinationLabel'] as String? ?? 'My Second Bank',
    defaultMethod: _enumFromName(
      MoneySaveMethod.values,
      map['defaultMethod'] as String?,
      MoneySaveMethod.custom,
    ),
    reminderTimeLabel: map['reminderTimeLabel'] as String? ?? '8:00 PM',
    manualConfirmationAllowed:
        map['manualConfirmationAllowed'] as bool? ?? true,
  );
}

GoalModel _goalFromMap(Map<String, dynamic> map) {
  return GoalModel(
    id: map['id'] as String? ?? '',
    identityTitle: map['identityTitle'] as String? ?? '',
    purposeStatement: map['purposeStatement'] as String? ?? '',
    progressPercent: (map['progressPercent'] as num?)?.toDouble() ?? 0,
    systems: _bundleReadList(map['systems'], _goalSystemFromMap),
    dailyProof: map['dailyProof'] is Map
        ? _goalProofFromMap(_bundleMap(map['dailyProof']))
        : GoalProof(
            id: '',
            title: '',
            tinyVersion: '',
            normalVersion: '',
            strongVersion: '',
          ),
    streakDays: (map['streakDays'] as num?)?.toInt() ?? 0,
    isArchived: map['isArchived'] as bool? ?? false,
    isPaused: map['isPaused'] as bool? ?? false,
  );
}

GoalSystem _goalSystemFromMap(Map<String, dynamic> map) {
  return GoalSystem(
    id: map['id'] as String? ?? '',
    description: map['description'] as String? ?? '',
    linkedRoutineTaskIds: _bundleStringList(map['linkedRoutineTaskIds']),
    linkedTrackerIds: _bundleStringList(map['linkedTrackerIds']),
  );
}

GoalProof _goalProofFromMap(Map<String, dynamic> map) {
  return GoalProof(
    id: map['id'] as String? ?? '',
    title: map['title'] as String? ?? '',
    tinyVersion: map['tinyVersion'] as String? ?? '',
    normalVersion: map['normalVersion'] as String? ?? '',
    strongVersion: map['strongVersion'] as String? ?? '',
    selectedDifficulty: map['selectedDifficulty'] as String? ?? 'normal',
    isCompleted: map['isCompleted'] as bool? ?? false,
    note: map['note'] as String?,
    sharedToCoach: map['sharedToCoach'] as bool? ?? false,
  );
}

T _enumFromName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
