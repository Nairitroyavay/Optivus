import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/server_reconstructor.dart';

/// Coordinates migration of legacy (pre-lineage / setupLineageVersion == 0)
/// onboarding accounts to setupLineageVersion == 1.
///
/// Ensures that existing in-progress drafts retain 100% of user answers and progress,
/// stale pre-lineage completion run pointers are marked superseded, and profiles
/// are upgraded monotonically without data loss or dropping into Recovery.
class OnboardingSetupLineageMigrationCoordinator {
  final FirebaseFirestore? firestore;
  final ProfileRepository profileRepository;
  final OnboardingRepository onboardingRepository;
  final OnboardingCompletionJobService? jobService;

  const OnboardingSetupLineageMigrationCoordinator({
    this.firestore,
    required this.profileRepository,
    required this.onboardingRepository,
    this.jobService,
  });

  /// Determines if an account requires migration to the current setup lineage version.
  /// Only in-progress (non-completed) accounts with legacy lineage versions (0)
  /// and partial/fresh drafts are migrated.
  bool shouldMigrate(ServerReconstructionSnapshot snapshot) {
    final profile = snapshot.profile;
    if (profile == null) return false;

    // Completed profiles must not be mutated by migration coordinator.
    if (profile.onboardingCompleted) return false;

    // Must have legacy lineage version on profile or draft.
    final hasLegacyProfile =
        profile.setupLineageVersion < UserProfile.currentSetupLineageVersion;
    final hasLegacyDraft = snapshot.draft != null &&
        snapshot.draft!.setupLineageVersion <
            OnboardingDraft.currentSetupLineageVersion;

    if (!hasLegacyProfile && !hasLegacyDraft) return false;

    // Do not migrate if draft claims to be final completed draft
    if (snapshot.draft != null && isReconstructionFinalDraft(snapshot.draft!)) {
      return false;
    }

    return true;
  }

  /// Migrates a legacy account to lineage v1 atomically and idempotently.
  /// Preserves all draft steps, photos, answers, and progress intact.
  /// Marks any stale completion run pointer as superseded.
  Future<ServerReconstructionSnapshot> migrate(
    ServerReconstructionSnapshot snapshot, {
    required ServerReconstructionSource source,
  }) async {
    final profile = snapshot.profile;
    if (profile == null) return snapshot;

    final cleanUid = profile.uid.trim();
    if (cleanUid.isEmpty) return snapshot;

    final now = DateTime.now();
    final targetGeneration = profile.currentSetupGeneration < 1
        ? 1
        : profile.currentSetupGeneration;

    developer.log(
      '[LineageMigration] started uid=$cleanUid '
      'profileGen=${profile.currentSetupGeneration} targetGen=$targetGeneration '
      'profileLineage=${profile.setupLineageVersion} draftLineage=${snapshot.draft?.setupLineageVersion}',
      name: 'onboarding_setup_lineage_migration_coordinator',
    );

    if (firestore != null) {
      final profileRef = firestore!.doc(FirestoreUserPaths.user(cleanUid));
      final pointerRef =
          firestore!.doc(FirestoreUserPaths.onboardingCurrentRun(cleanUid));
      final draftRef =
          firestore!.doc(FirestoreUserPaths.onboardingDraft(cleanUid));

      await firestore!.runTransaction((tx) async {
        final profileDoc = await tx.get(profileRef);
        final pointerDoc = await tx.get(pointerRef);
        final draftDoc = await tx.get(draftRef);

        final profileData = profileDoc.data();
        final pointerData = pointerDoc.data();
        final draftData = draftDoc.data();

        final curProfile = profileData != null
            ? UserProfile.fromFirestoreMap(profileData)
            : profile;

        // Idempotency check: if profile already migrated to current lineage, skip.
        if (curProfile.setupLineageVersion >=
                UserProfile.currentSetupLineageVersion &&
            curProfile.currentSetupGeneration >= targetGeneration) {
          return;
        }

        // 1. Mark existing stale completion run pointer as superseded.
        if (pointerData != null) {
          final supersededPointer = Map<String, dynamic>.from(pointerData)
            ..['status'] = 'superseded'
            ..['setupLineageVersion'] = UserProfile.currentSetupLineageVersion
            ..['updatedAt'] = Timestamp.fromDate(now);
          tx.set(pointerRef, supersededPointer);
        }

        // 2. Migrate draft: preserve all step answers, photos, and progress.
        if (draftData != null) {
          final curDraft = OnboardingDraft.fromMap(draftData);
          final migratedDraft = curDraft.copyWith(
            setupGeneration: targetGeneration,
            setupLineageVersion: OnboardingDraft.currentSetupLineageVersion,
            updatedAt: now,
          );
          tx.set(draftRef, migratedDraft.toFirestoreMap());
        }

        // 3. Migrate profile.
        final migratedProfile = curProfile.copyWith(
          currentSetupGeneration: targetGeneration,
          setupLineageVersion: UserProfile.currentSetupLineageVersion,
          updatedAt: now,
        );
        tx.set(profileRef, migratedProfile.toFirestoreMap());
      });
    } else {
      // In-memory fallback
      if (snapshot.currentRun.hasPointer) {
        jobService?.markCurrentRunSupersededInMemory(cleanUid);
      }

      if (snapshot.draft != null) {
        final migratedDraft = snapshot.draft!.copyWith(
          setupGeneration: targetGeneration,
          setupLineageVersion: OnboardingDraft.currentSetupLineageVersion,
          updatedAt: now,
        );
        await onboardingRepository.saveDraft(migratedDraft);
      }

      final migratedProfile = profile.copyWith(
        currentSetupGeneration: targetGeneration,
        setupLineageVersion: UserProfile.currentSetupLineageVersion,
        updatedAt: now,
      );
      await profileRepository.saveUserProfile(migratedProfile);
    }

    developer.log(
      '[LineageMigration] completed uid=$cleanUid migrated to generation=$targetGeneration lineage=${UserProfile.currentSetupLineageVersion}',
      name: 'onboarding_setup_lineage_migration_coordinator',
    );

    // Reload fresh server snapshot post-migration.
    return await source.load(cleanUid);
  }
}

final onboardingSetupLineageMigrationCoordinatorProvider =
    Provider<OnboardingSetupLineageMigrationCoordinator>((ref) {
  final firebaseMode = !ref.watch(fakeDataAllowedProvider);
  final firebaseReady = firebaseMode && Firebase.apps.isNotEmpty;
  return OnboardingSetupLineageMigrationCoordinator(
    firestore: firebaseReady ? FirebaseFirestore.instance : null,
    profileRepository: ref.watch(profileRepositoryProvider),
    onboardingRepository: ref.watch(onboardingRepositoryProvider),
    jobService: ref.watch(onboardingCompletionJobServiceProvider),
  );
});
