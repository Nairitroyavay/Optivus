import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:optivus/models/habit_system_record.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/routine_item.dart';

class HabitSystemOnboardingProjection {
  const HabitSystemOnboardingProjection._();

  static List<HabitSystemRecord> build(
    OnboardingCompletionBundle bundle,
    List<RoutineItem> projectedRoutines, {
    DateTime? now,
  }) {
    if (bundle.uid.trim().isEmpty || bundle.uid.contains('/')) {
      throw ArgumentError('Valid owner UID is required.');
    }
    final timestamp = (now ?? DateTime.now()).toUtc();
    final systems = <HabitSystemRecord>[];
    final seenIds = <String>{};

    // 1. Good Habits
    for (final habit in bundle.goodHabitTemplates) {
      final systemId = _stableSystemId(bundle.uid, 'good_${habit.systemKey}');
      if (!seenIds.add(systemId)) continue;

      final linked = projectedRoutines
          .where(
            (r) => _matchesTitleOrKey(r.title, habit.title, habit.systemKey),
          )
          .map((r) => r.id)
          .toList();

      systems.add(
        HabitSystemRecord(
          systemId: systemId,
          ownerUid: bundle.uid,
          title: habit.title,
          description: '${habit.durationMinutes}m daily good habit system',
          category: RoutineCategory.habit,
          systemType: HabitSystemType.goodHabit,
          status: HabitSystemStatus.active,
          linkedRoutineIds: linked,
          source: 'onboarding',
          onboardingSourceId: habit.id,
          onboardingProjectionId: 'proj_onboard_hs_v1_${bundle.uid}',
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );
    }

    // 2. Bad Habits
    for (final bad in bundle.badHabitCheckIns) {
      final systemId = _stableSystemId(bundle.uid, 'bad_${bad.habitKey}');
      if (!seenIds.add(systemId)) continue;

      final linked = projectedRoutines
          .where(
            (r) =>
                r.category == RoutineCategory.badHabit ||
                r.id == bad.linkedRoutineItemId,
          )
          .map((r) => r.id)
          .toList();

      systems.add(
        HabitSystemRecord(
          systemId: systemId,
          ownerUid: bundle.uid,
          title: '${bad.displayName} System',
          description: 'Daily check-in & risk management system',
          category: RoutineCategory.badHabit,
          systemType: HabitSystemType.badHabit,
          status: HabitSystemStatus.active,
          linkedRoutineIds: linked,
          source: 'onboarding',
          onboardingSourceId: bad.id,
          onboardingProjectionId: 'proj_onboard_hs_v1_${bundle.uid}',
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );
    }

    // 3. Identity Goal Systems
    for (final goal in bundle.identityGoalSystems) {
      final systemId = _stableSystemId(bundle.uid, 'identity_${goal.id}');
      if (!seenIds.add(systemId)) continue;

      final linkedIds = <String>{};
      for (final system in goal.systems) {
        linkedIds.addAll(system.linkedRoutineTaskIds);
      }

      systems.add(
        HabitSystemRecord(
          systemId: systemId,
          ownerUid: bundle.uid,
          title: goal.identityTitle,
          description: goal.purposeStatement,
          category: RoutineCategory.identity,
          systemType: HabitSystemType.identity,
          status: HabitSystemStatus.active,
          linkedRoutineIds: linkedIds.toList(),
          source: 'onboarding',
          onboardingSourceId: goal.id,
          onboardingProjectionId: 'proj_onboard_hs_v1_${bundle.uid}',
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );
    }

    return systems;
  }

  static String _stableSystemId(String ownerUid, String key) {
    final digest = sha256.convert(
      utf8.encode('habitsys-onboarding-v1\u001f$ownerUid\u001f$key'),
    );
    return 'habitsys_${digest.toString().substring(0, 32)}';
  }

  static bool _matchesTitleOrKey(String text, String title, String key) {
    final lowerText = text.toLowerCase();
    final lowerTitle = title.toLowerCase();
    final lowerKey = key.toLowerCase().replaceAll('_', ' ');
    return lowerText.contains(lowerTitle) || lowerText.contains(lowerKey);
  }
}
