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

class OnboardingSetupResetResult {
  final UserProfile profile;
  final OnboardingDraft draft;
  final int setupGeneration;
  final String resetOperationId;

  const OnboardingSetupResetResult({
    required this.profile,
    required this.draft,
    required this.setupGeneration,
    required this.resetOperationId,
  });
}

/// Unified atomic, idempotent coordinator for resetting onboarding setup.
/// Increments setupGeneration across UserProfile and OnboardingDraft, marks the
/// currentRun pointer as superseded, writes a fresh schema v4 draft, and
/// invalidates in-flight completion jobs.
class OnboardingSetupResetCoordinator {
  final FirebaseFirestore? firestore;
  final ProfileRepository profileRepository;
  final OnboardingRepository onboardingRepository;
  final OnboardingCompletionJobService? jobService;

  const OnboardingSetupResetCoordinator({
    this.firestore,
    required this.profileRepository,
    required this.onboardingRepository,
    this.jobService,
  });

  Future<OnboardingSetupResetResult> resetSetup({
    required String uid,
    String? resetOperationId,
  }) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) {
      throw ArgumentError('uid cannot be empty');
    }

    final operationId =
        resetOperationId ?? 'reset_${DateTime.now().millisecondsSinceEpoch}';

    // Invalidate any in-flight completion jobs for this user immediately.
    jobService?.invalidateInFlightOperations(cleanUid);

    final now = DateTime.now();

    if (firestore != null) {
      final profileRef = firestore!.doc(FirestoreUserPaths.user(cleanUid));
      final pointerRef = firestore!.doc(
        FirestoreUserPaths.onboardingCurrentRun(cleanUid),
      );
      final draftRef = firestore!.doc(
        FirestoreUserPaths.onboardingDraft(cleanUid),
      );

      return await firestore!.runTransaction<OnboardingSetupResetResult>((
        tx,
      ) async {
        final profileDoc = await tx.get(profileRef);
        final pointerDoc = await tx.get(pointerRef);
        final draftDoc = await tx.get(draftRef);

        final profileData = profileDoc.data();
        final pointerData = pointerDoc.data();
        final draftData = draftDoc.data();

        // Idempotency: if already executed with this resetOperationId, return current state.
        if (profileData != null &&
            profileData['lastResetOperationId'] == operationId &&
            draftData != null &&
            draftData['lastResetOperationId'] == operationId) {
          final existingProfile = UserProfile.fromFirestoreMap(profileData);
          final existingDraft = OnboardingDraft.fromMap(draftData);
          return OnboardingSetupResetResult(
            profile: existingProfile,
            draft: existingDraft,
            setupGeneration: existingProfile.currentSetupGeneration,
            resetOperationId: operationId,
          );
        }

        final currentProfile = profileData != null
            ? UserProfile.fromFirestoreMap(profileData)
            : UserProfile.empty(uid: cleanUid);

        final nextGeneration = currentProfile.currentSetupGeneration + 1;

        // 1. Mark existing currentRun pointer as superseded.
        if (pointerData != null) {
          final supersededPointer = Map<String, dynamic>.from(pointerData)
            ..['status'] = 'superseded'
            ..['setupLineageVersion'] = UserProfile.currentSetupLineageVersion
            ..['updatedAt'] = Timestamp.fromDate(now);
          tx.set(pointerRef, supersededPointer);
        }

        // 2. Write fresh schema v4 draft for the new setup generation.
        final newDraft = OnboardingDraft.freshForSetup(
          uid: cleanUid,
          setupGeneration: nextGeneration,
          setupLineageVersion: UserProfile.currentSetupLineageVersion,
          lastResetOperationId: operationId,
          createdAt: now,
          updatedAt: now,
        );
        tx.set(draftRef, newDraft.toFirestoreMap());

        // 3. Update UserProfile with new setup generation and pending projection.
        final updatedProfile = currentProfile.copyWith(
          uid: cleanUid,
          currentSetupGeneration: nextGeneration,
          setupLineageVersion: UserProfile.currentSetupLineageVersion,
          lastResetOperationId: operationId,
          onboardingInputCompleted: false,
          onboardingProjectionStatus: 'pending',
          onboardingCompleted: false,
          onboardingStep: 0,
          updatedAt: now,
        );
        tx.set(profileRef, updatedProfile.toFirestoreMap());

        developer.log(
          '[SetupReset] uid=$cleanUid generation=$nextGeneration operationId=$operationId',
          name: 'onboarding_setup_reset_coordinator',
        );

        return OnboardingSetupResetResult(
          profile: updatedProfile,
          draft: newDraft,
          setupGeneration: nextGeneration,
          resetOperationId: operationId,
        );
      });
    }

    // In-memory fallback (e.g. tests or local fake repository mode)
    final existingProfile =
        await profileRepository.fetchUserProfile(cleanUid) ??
        UserProfile.empty(uid: cleanUid);
    final existingDraft = await onboardingRepository.fetchDraft(cleanUid);

    if (existingProfile.lastResetOperationId == operationId &&
        existingDraft != null &&
        existingDraft.lastResetOperationId == operationId) {
      return OnboardingSetupResetResult(
        profile: existingProfile,
        draft: existingDraft,
        setupGeneration: existingProfile.currentSetupGeneration,
        resetOperationId: operationId,
      );
    }

    final nextGeneration = existingProfile.currentSetupGeneration + 1;

    jobService?.markCurrentRunSupersededInMemory(cleanUid);

    final newDraft = OnboardingDraft.freshForSetup(
      uid: cleanUid,
      setupGeneration: nextGeneration,
      setupLineageVersion: UserProfile.currentSetupLineageVersion,
      lastResetOperationId: operationId,
      createdAt: now,
      updatedAt: now,
    );
    await onboardingRepository.saveDraft(newDraft);

    final updatedProfile = existingProfile.copyWith(
      uid: cleanUid,
      currentSetupGeneration: nextGeneration,
      setupLineageVersion: UserProfile.currentSetupLineageVersion,
      lastResetOperationId: operationId,
      onboardingInputCompleted: false,
      onboardingProjectionStatus: 'pending',
      onboardingCompleted: false,
      onboardingStep: 0,
      updatedAt: now,
    );
    await profileRepository.saveUserProfile(updatedProfile);

    return OnboardingSetupResetResult(
      profile: updatedProfile,
      draft: newDraft,
      setupGeneration: nextGeneration,
      resetOperationId: operationId,
    );
  }
}

final onboardingSetupResetCoordinatorProvider =
    Provider<OnboardingSetupResetCoordinator>((ref) {
      final firebaseMode = !ref.watch(fakeDataAllowedProvider);
      final firebaseReady = firebaseMode && Firebase.apps.isNotEmpty;
      return OnboardingSetupResetCoordinator(
        firestore: firebaseReady ? FirebaseFirestore.instance : null,
        profileRepository: ref.watch(profileRepositoryProvider),
        onboardingRepository: ref.watch(onboardingRepositoryProvider),
        jobService: ref.watch(onboardingCompletionJobServiceProvider),
      );
    });
