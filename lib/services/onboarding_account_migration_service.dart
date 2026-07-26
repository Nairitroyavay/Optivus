import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/routine_occurrence.dart';

import 'package:optivus/repositories/app_preferences_repository.dart';
import 'package:optivus/repositories/habit_systems_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';

/// Migrates anonymous onboarding draft, profile settings, routine items,
/// habit systems, and preferences to a newly linked authenticated user account UID.
class OnboardingAccountMigrationService {
  const OnboardingAccountMigrationService._();

  static Future<void> migrateAccountData({
    required String oldAnonUid,
    required String newUid,
    required T Function<T>(ProviderListenable<T>) read,
  }) async {
    if (oldAnonUid.trim().isEmpty ||
        newUid.trim().isEmpty ||
        oldAnonUid == newUid) {
      return;
    }

    final onboardingRepo = read(onboardingRepositoryProvider);
    final profileRepo = read(profileRepositoryProvider);
    final routineRepo = read(routineRepositoryProvider);
    final routineHistoryRepo = read(routineHistoryRepositoryProvider);
    final habitSystemsRepo = read(habitSystemsRepositoryProvider);
    final appPreferencesRepo = read(appPreferencesRepositoryProvider);

    // 1. Migrate Onboarding Draft
    final draft = await onboardingRepo.fetchDraft(oldAnonUid);
    if (draft != null) {
      final updatedDraft = draft.copyWith(uid: newUid);
      await onboardingRepo.saveDraft(updatedDraft);
    }

    // 2. Migrate User Profile & Profile Settings
    final userProfile = await profileRepo.fetchUserProfile(oldAnonUid);
    if (userProfile != null) {
      final updatedProfile = userProfile.copyWith(
        uid: newUid,
        updatedAt: DateTime.now(),
      );
      await profileRepo.saveUserProfile(updatedProfile);
    }

    final settings = await profileRepo.fetchProfileSettings(oldAnonUid);
    await profileRepo.saveProfileSettings(newUid, settings);

    // 3. Migrate Routine Items & History
    final routineItems = await routineRepo.fetchRoutineItems(oldAnonUid);
    for (final item in routineItems) {
      final updatedItem = item.copyWith(
        userId: newUid,
        updatedAt: DateTime.now(),
      );
      await routineRepo.createRoutineItem(newUid, updatedItem);
    }

    final history = await routineHistoryRepo.fetchHistory(oldAnonUid);
    for (final record in history) {
      final updatedRecord = RoutineOccurrenceRecord(
        id: record.id,
        ownerUid: newUid,
        routineItemId: record.routineItemId,
        occurrenceDateKey: record.occurrenceDateKey,
        status: record.status,
        source: record.source,
        action: record.action,
        operationKey: record.operationKey,
        createdAt: record.createdAt,
        updatedAt: DateTime.now(),
        schemaVersion: record.schemaVersion,
        movedToDateKey: record.movedToDateKey,
        movedStartMinute: record.movedStartMinute,
        movedEndMinute: record.movedEndMinute,
        completedSubtaskIndexes: record.completedSubtaskIndexes,
        note: record.note,
        displayTitleOverride: record.displayTitleOverride,
        undoToPlannedAllowed: record.undoToPlannedAllowed,
      );
      await routineHistoryRepo.appendHistory(newUid, updatedRecord);
    }

    // 4. Migrate Habit Systems
    final habitSystems = await habitSystemsRepo.fetchHabitSystems(oldAnonUid);
    if (habitSystems.isNotEmpty) {
      final updatedSystems = habitSystems
          .map((s) => s.copyWith(ownerUid: newUid, updatedAt: DateTime.now()))
          .toList();
      await habitSystemsRepo.reconcileProjectedSystems(
        ownerUid: newUid,
        projectionId: 'migration',
        systems: updatedSystems,
      );
    }

    // 5. Migrate App Preferences
    final prefs = await appPreferencesRepo.fetchAppPreferences(oldAnonUid);
    if (prefs != null) {
      await appPreferencesRepo.saveAppPreferences(newUid, prefs);
    }
  }
}
