import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/firestore_paths.dart';

abstract class OnboardingDraftRepository {
  Future<OnboardingDraft?> fetchDraft(String uid);
  Future<void> saveDraft(OnboardingDraft draft);
}

abstract class UserProfileRepository {
  Future<UserProfile?> fetchProfile(String uid);
  Future<void> upsertProfile(UserProfile profile);
  Future<void> applyProfilePatch(String uid, Map<String, dynamic> patch);
}

abstract class RoutineSetupRepository {
  Future<void> saveRoutineItems(String uid, List<RoutineItem> items);
}

abstract class PreferencesRepository {
  Future<void> saveCoachPreferences(String uid, CoachPreferences preferences);
  Future<void> saveNotificationPreferences(
    String uid,
    NotificationPreferences preferences,
  );
}

abstract class OnboardingCompletionRepository {
  Future<void> saveCompletionBundle(OnboardingCompletionBundle bundle);
}

class FirebaseOnboardingDraftRepository implements OnboardingDraftRepository {
  final FirebaseFirestore _firestore;

  FirebaseOnboardingDraftRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<OnboardingDraft?> fetchDraft(String uid) async {
    final doc = await _firestore
        .doc(FirestoreUserPaths.onboardingDraft(uid))
        .get();
    final data = doc.data();
    return data == null ? null : OnboardingDraft.fromMap(data);
  }

  @override
  Future<void> saveDraft(OnboardingDraft draft) {
    return _firestore
        .doc(FirestoreUserPaths.onboardingDraft(draft.uid))
        .set(draft.toMap(), SetOptions(merge: true));
  }
}

class FirebaseUserProfileRepository implements UserProfileRepository {
  final FirebaseFirestore _firestore;

  FirebaseUserProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<UserProfile?> fetchProfile(String uid) async {
    final doc = await _firestore.doc(FirestoreUserPaths.user(uid)).get();
    final data = doc.data();
    return data == null ? null : UserProfile.fromMap(data);
  }

  @override
  Future<void> upsertProfile(UserProfile profile) {
    return _firestore
        .doc(FirestoreUserPaths.user(profile.uid))
        .set(profile.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> applyProfilePatch(String uid, Map<String, dynamic> patch) {
    return _firestore
        .doc(FirestoreUserPaths.user(uid))
        .set(patch, SetOptions(merge: true));
  }
}

class FirebaseRoutineSetupRepository implements RoutineSetupRepository {
  final FirebaseFirestore _firestore;

  FirebaseRoutineSetupRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> saveRoutineItems(String uid, List<RoutineItem> items) async {
    final batch = _firestore.batch();
    for (final item in items) {
      batch.set(
        _firestore.doc(FirestoreUserPaths.routineItem(uid, item.id)),
        _routineItemToMap(uid, item),
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }
}

class FirebasePreferencesRepository implements PreferencesRepository {
  final FirebaseFirestore _firestore;

  FirebasePreferencesRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> saveCoachPreferences(String uid, CoachPreferences preferences) {
    return _firestore.doc(FirestoreUserPaths.coachPreferences(uid)).set({
      ..._baseDoc(uid, source: 'onboarding'),
      'name': preferences.name,
      'style': preferences.style,
      'allowRoutineContext': preferences.allowRoutineContext,
      'allowTrackerContext': preferences.allowTrackerContext,
      'allowGoalsContext': preferences.allowGoalsContext,
      'allowProfileContext': preferences.allowProfileContext,
      'shareSelectedNotesOnly': preferences.shareSelectedNotesOnly,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> saveNotificationPreferences(
    String uid,
    NotificationPreferences preferences,
  ) {
    return _firestore.doc(FirestoreUserPaths.notificationPreferences(uid)).set({
      ..._baseDoc(uid, source: 'onboarding'),
      'morningStart': preferences.morningStart,
      'nextTask': preferences.nextTask,
      'eating': preferences.eating,
      'badHabitCheckIn': preferences.badHabitCheckIn,
      'savings': preferences.savings,
      'nightReflection': preferences.nightReflection,
      'intensity': preferences.intensity.name,
    }, SetOptions(merge: true));
  }
}

class FirebaseOnboardingCompletionRepository
    implements OnboardingCompletionRepository {
  final FirebaseFirestore _firestore;

  FirebaseOnboardingCompletionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> saveCompletionBundle(OnboardingCompletionBundle bundle) {
    final uid = bundle.uid;
    final batch = _firestore.batch();
    final bundleMap = bundle.toMap();
    batch.set(
      _firestore.doc(FirestoreUserPaths.onboardingCompletionBundle(uid)),
      bundleMap,
      SetOptions(merge: true),
    );
    batch.set(
      _firestore.doc(
        FirestoreUserPaths.onboardingSetupVersion(
          uid,
          OnboardingCompletionBundle.schemaVersion,
        ),
      ),
      bundleMap,
      SetOptions(merge: true),
    );
    batch.set(
      _firestore.doc(FirestoreUserPaths.user(uid)),
      bundle.userProfilePatch,
      SetOptions(merge: true),
    );
    for (final item in bundle.routineItemsForApp) {
      batch.set(
        _firestore.doc(FirestoreUserPaths.routineItem(uid, item.id)),
        _routineItemToMap(uid, item),
        SetOptions(merge: true),
      );
    }
    for (final habit in bundle.goodHabitTemplates) {
      batch.set(
        _firestore.doc(FirestoreUserPaths.habitTemplate(uid, habit.id)),
        habit.toMapWithMetadata(uid),
        SetOptions(merge: true),
      );
    }
    for (final checkIn in bundle.badHabitCheckIns) {
      batch.set(
        _firestore.doc(FirestoreUserPaths.badHabitCheckIn(uid, checkIn.id)),
        checkIn.toMapWithMetadata(uid),
        SetOptions(merge: true),
      );
    }
    for (final goal in bundle.identityGoalSystems) {
      batch.set(
        _firestore.doc(FirestoreUserPaths.goal(uid, goal.id)),
        _goalToMap(uid, goal),
        SetOptions(merge: true),
      );
    }
    batch.set(
      _firestore.doc(FirestoreUserPaths.coachPreferences(uid)),
      {
        ..._baseDoc(uid, source: 'onboarding'),
        'name': bundle.coachPreferences.name,
        'style': bundle.coachPreferences.style,
        'allowRoutineContext': bundle.coachPreferences.allowRoutineContext,
        'allowTrackerContext': bundle.coachPreferences.allowTrackerContext,
        'allowGoalsContext': bundle.coachPreferences.allowGoalsContext,
        'allowProfileContext': bundle.coachPreferences.allowProfileContext,
        'shareSelectedNotesOnly':
            bundle.coachPreferences.shareSelectedNotesOnly,
      },
      SetOptions(merge: true),
    );
    batch.set(
      _firestore.doc(FirestoreUserPaths.notificationPreferences(uid)),
      {
        ..._baseDoc(uid, source: 'onboarding'),
        'morningStart': bundle.notificationPreferences.morningStart,
        'nextTask': bundle.notificationPreferences.nextTask,
        'eating': bundle.notificationPreferences.eating,
        'badHabitCheckIn': bundle.notificationPreferences.badHabitCheckIn,
        'savings': bundle.notificationPreferences.savings,
        'nightReflection': bundle.notificationPreferences.nightReflection,
        'intensity': bundle.notificationPreferences.intensity.name,
      },
      SetOptions(merge: true),
    );
    return batch.commit();
  }
}

Map<String, dynamic> _baseDoc(String uid, {required String source}) {
  final now = DateTime.now().toIso8601String();
  return {
    'uid': uid,
    'schemaVersion': OnboardingCompletionBundle.schemaVersion,
    'source': source,
    'onboardingCompleted': true,
    'createdAt': now,
    'updatedAt': now,
  };
}

Map<String, dynamic> _routineItemToMap(String uid, RoutineItem item) {
  return {
    ..._baseDoc(uid, source: item.notes ?? 'onboarding'),
    'id': item.id,
    'title': item.title,
    'startMinute': item.startMinute,
    'endMinute': item.endMinute,
    'crossesMidnight': item.crossesMidnight,
    'repeatDays': item.repeatDays,
    'location': item.location,
    'blockType': item.blockType.name,
    'notes': item.notes,
    'subtasks': item.subtasks,
    'mealCategory': item.mealCategory,
    'dishes': item.dishes,
    'calories': item.caloriesEstimate,
    'protein': item.proteinEstimate,
    'skincareProducts': item.skincareProducts,
    'hasConflict': item.hasConflict,
    'conflictMessage': item.conflictMessage,
  };
}

Map<String, dynamic> _goalToMap(String uid, goal) {
  return {
    ..._baseDoc(uid, source: 'onboarding'),
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
}
