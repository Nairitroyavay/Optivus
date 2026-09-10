import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_resume_validator.dart';
import 'package:optivus/services/onboarding_run_identity.dart';
import 'package:optivus/services/onboarding_setup_lineage_migration_coordinator.dart';

enum ReconstructionLifecycle {
  fresh,
  incomplete,
  finishing,
  completed,
  recovery,
}

enum ReconstructionRecoveryReason {
  missingProfile,
  invalidDraft,
  missingCurrentRun,
  danglingRunReference,
  schemaUnsupported,
  ownerMismatch,
  durableStateConflict,
  invalidCompletionBundle,
  completionFatalFailure,
  unknown,
}

enum ReconstructionBootstrapFailureReason {
  permissionDenied,
  backendUnavailable,
  timeout,
  unknown,
}

class ReconstructionBootstrapException implements Exception {
  final ReconstructionBootstrapFailureReason reason;
  final String diagnosticCode;
  final Object? cause;

  const ReconstructionBootstrapException({
    required this.reason,
    required this.diagnosticCode,
    this.cause,
  });

  @override
  String toString() =>
      'ReconstructionBootstrapException(${reason.name}, $diagnosticCode)';
}

sealed class ReconstructionResult {
  final String ownerUid;
  final UserProfile profile;

  const ReconstructionResult({required this.ownerUid, required this.profile});

  ReconstructionLifecycle get lifecycle;
}

final class ReconstructionFresh extends ReconstructionResult {
  const ReconstructionFresh({required super.ownerUid, required super.profile});

  @override
  ReconstructionLifecycle get lifecycle => ReconstructionLifecycle.fresh;
}

final class ReconstructionIncomplete extends ReconstructionResult {
  final int step;
  final OnboardingDraft draft;
  final String diagnosticCode;
  final Map<String, Object?> diagnostics;

  const ReconstructionIncomplete({
    required super.ownerUid,
    required super.profile,
    required this.step,
    required this.draft,
    this.diagnosticCode = 'step_incomplete',
    this.diagnostics = const {},
  });

  @override
  ReconstructionLifecycle get lifecycle => ReconstructionLifecycle.incomplete;
}

final class ReconstructionFinishing extends ReconstructionResult {
  final String runId;
  final OnboardingDraft draft;
  final OnboardingCompletionJob? completionJob;
  final OnboardingCompletionBundle? completionBundle;

  const ReconstructionFinishing({
    required super.ownerUid,
    required super.profile,
    required this.runId,
    required this.draft,
    this.completionJob,
    this.completionBundle,
  });

  @override
  ReconstructionLifecycle get lifecycle => ReconstructionLifecycle.finishing;
}

final class ReconstructionCompleted extends ReconstructionResult {
  final OnboardingDraft draft;
  final OnboardingCompletionBundle completionBundle;
  final OnboardingCompletionJob? completionJob;

  const ReconstructionCompleted({
    required super.ownerUid,
    required super.profile,
    required this.draft,
    required this.completionBundle,
    this.completionJob,
  });

  @override
  ReconstructionLifecycle get lifecycle => ReconstructionLifecycle.completed;
}

final class ReconstructionRecovery extends ReconstructionResult {
  final ReconstructionRecoveryReason reason;
  final Map<String, Object?> diagnostics;

  ReconstructionRecovery({
    required super.ownerUid,
    required super.profile,
    required this.reason,
    Map<String, Object?> diagnostics = const {},
  }) : diagnostics = Map<String, Object?>.unmodifiable(diagnostics);

  @override
  ReconstructionLifecycle get lifecycle => ReconstructionLifecycle.recovery;
}

class ServerReconstructionSnapshot {
  final UserProfile? profile;
  final OnboardingDraft? draft;
  final OnboardingCompletionBundle? completionBundle;
  final OnboardingCurrentRunSnapshot currentRun;

  const ServerReconstructionSnapshot({
    required this.profile,
    required this.draft,
    required this.completionBundle,
    required this.currentRun,
  });
}

abstract interface class ServerReconstructionSource {
  Future<ServerReconstructionSnapshot> load(
    String uid, {
    void Function(UserProfile? profile)? onProfileLoaded,
  });
  Future<void> createProfileShell(UserProfile profile);
}

class RepositoryServerReconstructionSource
    implements ServerReconstructionSource {
  final ProfileRepository profileRepository;
  final OnboardingRepository onboardingRepository;
  final OnboardingCompletionJobService completionJobService;

  const RepositoryServerReconstructionSource({
    required this.profileRepository,
    required this.onboardingRepository,
    required this.completionJobService,
  });

  @override
  Future<ServerReconstructionSnapshot> load(
    String uid, {
    void Function(UserProfile? profile)? onProfileLoaded,
  }) async {
    final profileFuture = profileRepository.fetchUserProfile(uid).then((value) {
      onProfileLoaded?.call(value);
      return value;
    });
    final reads = await Future.wait<Object?>([
      profileFuture,
      onboardingRepository.fetchDraft(uid),
      onboardingRepository.fetchCompletionBundle(uid),
      completionJobService.loadCurrentRunSnapshot(uid),
    ]);
    return ServerReconstructionSnapshot(
      profile: reads[0] as UserProfile?,
      draft: reads[1] as OnboardingDraft?,
      completionBundle: reads[2] as OnboardingCompletionBundle?,
      currentRun: reads[3] as OnboardingCurrentRunSnapshot,
    );
  }

  @override
  Future<void> createProfileShell(UserProfile profile) {
    return profileRepository.saveUserProfile(profile);
  }
}

/// The only server-authoritative classifier for an authenticated Optivus UID.
/// It never reads Riverpod state, SharedPreferences, or route state.
class ServerReconstructor {
  final ServerReconstructionSource source;
  final OnboardingSetupLineageMigrationCoordinator? migrationCoordinator;
  final DateTime Function() clock;

  const ServerReconstructor({
    required this.source,
    this.migrationCoordinator,
    this.clock = DateTime.now,
  });

  Future<ReconstructionResult> reconstruct({
    required String uid,
    String email = '',
    String displayName = '',
    void Function(UserProfile? profile)? onProfileLoaded,
  }) async {
    if (uid.trim().isEmpty) {
      throw const ReconstructionBootstrapException(
        reason: ReconstructionBootstrapFailureReason.unknown,
        diagnosticCode: 'empty_uid',
      );
    }
    final stopwatch = Stopwatch()..start();
    debugPrint('[Reconstruction] started uid=${_safeUid(uid)}');
    try {
      var snapshot = await source.load(uid, onProfileLoaded: onProfileLoaded);
      var profile = snapshot.profile;
      if (profile == null) {
        final now = clock();
        profile = UserProfile.empty(
          uid: uid,
          email: email,
          displayName: displayName,
        ).copyWith(createdAt: now, updatedAt: now);
        final hasReturningAccountState =
            snapshot.draft != null ||
            snapshot.completionBundle != null ||
            snapshot.currentRun.hasPointer;
        if (hasReturningAccountState) {
          return ReconstructionRecovery(
            ownerUid: uid,
            profile: profile,
            reason: ReconstructionRecoveryReason.missingProfile,
            diagnostics: const {'code': 'profile_missing_with_account_state'},
          );
        }
        await source.createProfileShell(profile);
      } else if (migrationCoordinator != null &&
          migrationCoordinator!.shouldMigrate(snapshot)) {
        debugPrint(
          '[Reconstruction] legacy lineage detected for uid=${_safeUid(uid)}, migrating...',
        );
        snapshot = await migrationCoordinator!.migrate(
          snapshot,
          source: source,
        );
        profile = snapshot.profile;
      }
      final result = classifyServerReconstruction(
        ownerUid: uid,
        profile: profile!,
        draft: snapshot.draft,
        completionBundle: snapshot.completionBundle,
        currentRun: snapshot.currentRun,
      );
      debugPrint(
        '[Reconstruction] classified uid=${_safeUid(uid)} '
        'lifecycle=${result.lifecycle.name} durationMs=${stopwatch.elapsedMilliseconds}',
      );
      return result;
    } on ReconstructionBootstrapException {
      rethrow;
    } on FirebaseException catch (error) {
      final reason = switch (error.code) {
        'permission-denied' =>
          ReconstructionBootstrapFailureReason.permissionDenied,
        'unavailable' || 'deadline-exceeded' =>
          ReconstructionBootstrapFailureReason.backendUnavailable,
        _ => ReconstructionBootstrapFailureReason.unknown,
      };
      throw ReconstructionBootstrapException(
        reason: reason,
        diagnosticCode: 'firestore_${error.code}',
        cause: error,
      );
    } on TimeoutException {
      throw const ReconstructionBootstrapException(
        reason: ReconstructionBootstrapFailureReason.timeout,
        diagnosticCode: 'server_read_timeout',
      );
    } on SocketException {
      throw const ReconstructionBootstrapException(
        reason: ReconstructionBootstrapFailureReason.backendUnavailable,
        diagnosticCode: 'server_read_socket_failure',
      );
    } catch (error) {
      throw ReconstructionBootstrapException(
        reason: ReconstructionBootstrapFailureReason.unknown,
        diagnosticCode: 'server_read_failed_${error.runtimeType}',
        cause: error,
      );
    }
  }
}

@visibleForTesting
ReconstructionResult classifyServerReconstruction({
  required String ownerUid,
  required UserProfile profile,
  required OnboardingDraft? draft,
  required OnboardingCompletionBundle? completionBundle,
  required OnboardingCurrentRunSnapshot currentRun,
}) {
  ReconstructionRecovery recovery(
    ReconstructionRecoveryReason reason,
    String code,
  ) {
    return ReconstructionRecovery(
      ownerUid: ownerUid,
      profile: profile,
      reason: reason,
      diagnostics: {'code': code},
    );
  }

  if (profile.uid != ownerUid ||
      (draft != null && draft.uid != ownerUid) ||
      (completionBundle != null && completionBundle.uid != ownerUid) ||
      (currentRun.ownerUid != null && currentRun.ownerUid != ownerUid) ||
      (currentRun.job != null && currentRun.job!.ownerUid != ownerUid)) {
    return recovery(
      ReconstructionRecoveryReason.ownerMismatch,
      'owner_mismatch',
    );
  }
  if (profile.schemaVersion > UserProfile.currentSchemaVersion ||
      profile.setupLineageVersion > UserProfile.currentSetupLineageVersion ||
      (draft != null &&
          (draft.storedSchemaVersion > OnboardingDraft.schemaVersion ||
              draft.setupLineageVersion >
                  OnboardingDraft.currentSetupLineageVersion)) ||
      (completionBundle != null &&
          (completionBundle.version >
                  OnboardingCompletionBundle.schemaVersion ||
              completionBundle.setupLineageVersion >
                  OnboardingCompletionBundle.currentSetupLineageVersion)) ||
      (currentRun.pointerSchemaVersion != null &&
          currentRun.pointerSchemaVersion! > 1) ||
      currentRun.setupLineageVersion >
          OnboardingCompletionJob.currentSetupLineageVersion ||
      (currentRun.job != null &&
          (currentRun.job!.schemaVersion >
                  OnboardingCompletionJob.currentSchemaVersion ||
              currentRun.job!.setupLineageVersion >
                  OnboardingCompletionJob.currentSetupLineageVersion))) {
    return recovery(
      ReconstructionRecoveryReason.schemaUnsupported,
      'unsupported_schema',
    );
  }
  final currentSetupGeneration = profile.currentSetupGeneration;

  // 1. Lineage check for draft: if draft exists, it must belong to currentSetupGeneration and setupLineageVersion.
  if (draft != null &&
      (draft.setupGeneration != currentSetupGeneration ||
          draft.setupLineageVersion != profile.setupLineageVersion)) {
    return recovery(
      ReconstructionRecoveryReason.durableStateConflict,
      'setup_lineage_corrupt',
    );
  }

  // 2. Lineage check for currentRun:
  // If run claims a future generation or future lineage version, durable state is corrupt.
  if (currentRun.hasPointer &&
      (currentRun.setupGeneration > currentSetupGeneration ||
          currentRun.setupLineageVersion > profile.setupLineageVersion)) {
    return recovery(
      ReconstructionRecoveryReason.durableStateConflict,
      'setup_lineage_corrupt',
    );
  }

  // A run is superseded if its generation or lineage version is older than the profile's,
  // or if its pointer status was explicitly marked 'superseded'.
  final isRunSuperseded =
      currentRun.hasPointer &&
      (currentRun.setupGeneration < currentSetupGeneration ||
          currentRun.setupLineageVersion < profile.setupLineageVersion ||
          currentRun.pointerStatus == 'superseded');

  if (isRunSuperseded) {
    developer.log(
      '[Reconstruction] completion_run_superseded '
      'runGeneration=${currentRun.setupGeneration} '
      'runLineage=${currentRun.setupLineageVersion} '
      'currentSetupGeneration=$currentSetupGeneration '
      'profileLineage=${profile.setupLineageVersion} '
      'pointerStatus=${currentRun.pointerStatus}',
      name: 'server_reconstructor',
    );
  }

  // A completed profile cannot have a superseded run.
  if (profile.onboardingCompleted && isRunSuperseded) {
    return recovery(
      ReconstructionRecoveryReason.durableStateConflict,
      'completed_profile_with_superseded_run',
    );
  }

  // For an active, same-lineage run, validate pointer status and run consistency.
  if (currentRun.hasPointer && !isRunSuperseded) {
    if (currentRun.runId == null || currentRun.runId!.trim().isEmpty) {
      return recovery(
        ReconstructionRecoveryReason.missingCurrentRun,
        'current_run_id_missing',
      );
    }
    if (currentRun.job == null) {
      return recovery(
        ReconstructionRecoveryReason.danglingRunReference,
        'current_run_dangling',
      );
    }
    if (currentRun.pointerStatus != null &&
        currentRun.pointerStatus != 'active' &&
        currentRun.pointerStatus != 'completed') {
      return recovery(
        ReconstructionRecoveryReason.durableStateConflict,
        'current_run_status_invalid',
      );
    }
  }

  final job = isRunSuperseded ? null : currentRun.job;
  final effectivePointerStatus = isRunSuperseded
      ? null
      : (currentRun.pointerStatus ??
            (job?.status == OnboardingJobStatus.completed &&
                    job?.stage == OnboardingCompletionStage.completed
                ? 'completed'
                : 'active'));

  if (job != null) {
    if (job.setupGeneration != currentSetupGeneration ||
        job.setupLineageVersion != profile.setupLineageVersion) {
      return recovery(
        ReconstructionRecoveryReason.durableStateConflict,
        'setup_lineage_corrupt',
      );
    }
    if (job.jobId != currentRun.runId ||
        (draft != null &&
            (job.draftRevision != draft.revision ||
                job.sourceFingerprint != draft.effectiveSourceFingerprint))) {
      return recovery(
        ReconstructionRecoveryReason.durableStateConflict,
        'completion_run_input_mismatch',
      );
    }
  }

  // Bundle lineage check: if bundle exists from older setup or older lineage, it is superseded.
  final isBundleSuperseded =
      completionBundle != null &&
      (completionBundle.setupGeneration < currentSetupGeneration ||
          completionBundle.setupLineageVersion < profile.setupLineageVersion);
  final effectiveBundle = isBundleSuperseded ? null : completionBundle;

  final finalDraft = draft != null && isReconstructionFinalDraft(draft);
  final validBundle =
      effectiveBundle != null &&
      draft != null &&
      effectiveBundle.version <= OnboardingCompletionBundle.schemaVersion &&
      effectiveBundle.draftRevision == draft.revision &&
      effectiveBundle.effectiveSourceFingerprint ==
          draft.effectiveSourceFingerprint &&
      effectiveBundle.setupGeneration == currentSetupGeneration &&
      effectiveBundle.setupLineageVersion == profile.setupLineageVersion;

  if (profile.onboardingCompleted) {
    if (!finalDraft) {
      return recovery(
        ReconstructionRecoveryReason.durableStateConflict,
        'completed_profile_without_final_draft',
      );
    }
    if (!validBundle) {
      return recovery(
        ReconstructionRecoveryReason.invalidCompletionBundle,
        'completed_profile_bundle_invalid',
      );
    }
    if (job?.status == OnboardingJobStatus.fatalFailure) {
      return recovery(
        ReconstructionRecoveryReason.completionFatalFailure,
        'completed_profile_terminal_failure',
      );
    }
    if (job != null &&
        (job.status != OnboardingJobStatus.completed ||
            job.stage != OnboardingCompletionStage.completed ||
            effectivePointerStatus != 'completed')) {
      return ReconstructionFinishing(
        ownerUid: ownerUid,
        profile: profile,
        runId: currentRun.runId!,
        draft: draft,
        completionJob: job,
        completionBundle: effectiveBundle,
      );
    }
    return ReconstructionCompleted(
      ownerUid: ownerUid,
      profile: profile,
      draft: draft,
      completionBundle: effectiveBundle,
      completionJob: job,
    );
  }

  if (job?.status == OnboardingJobStatus.fatalFailure) {
    return recovery(
      ReconstructionRecoveryReason.completionFatalFailure,
      'completion_run_fatal',
    );
  }
  if (finalDraft) {
    final runId =
        (isRunSuperseded ? null : currentRun.runId) ??
        (effectiveBundle?.runId.trim().isNotEmpty == true
            ? effectiveBundle!.runId
            : stableOnboardingRunId(
                ownerUid: ownerUid,
                sourceFingerprint: draft.effectiveSourceFingerprint,
                draftRevision: draft.revision,
              ));
    return ReconstructionFinishing(
      ownerUid: ownerUid,
      profile: profile,
      runId: runId,
      draft: draft,
      completionJob: job,
      completionBundle: effectiveBundle,
    );
  }

  if (profile.onboardingInputCompleted) {
    return recovery(
      ReconstructionRecoveryReason.durableStateConflict,
      'input_complete_without_final_draft',
    );
  }
  if (draft == null) {
    if (effectiveBundle != null ||
        (currentRun.hasPointer && !isRunSuperseded)) {
      return recovery(
        ReconstructionRecoveryReason.durableStateConflict,
        'completion_state_without_draft',
      );
    }
    final projectionIsFresh =
        profile.onboardingProjectionStatus.isEmpty ||
        profile.onboardingProjectionStatus == 'none' ||
        profile.onboardingProjectionStatus == 'pending';
    if (profile.onboardingStep <= 0 && projectionIsFresh) {
      return ReconstructionFresh(ownerUid: ownerUid, profile: profile);
    }
    return recovery(
      ReconstructionRecoveryReason.invalidDraft,
      'meaningful_profile_without_draft',
    );
  }

  final resumeValidation = validateOnboardingResume(draft);
  if (!hasReconstructionProgress(draft)) {
    return ReconstructionFresh(ownerUid: ownerUid, profile: profile);
  }
  final restoreDiagnostics = onboardingRestoreDiagnostics(
    draft: draft,
    validation: resumeValidation,
  );
  developer.log(
    '[OnboardingRestore] schema=${restoreDiagnostics['schemaVersion']} '
    'layout=${restoreDiagnostics['detectedTopology']} '
    'migration=${restoreDiagnostics['migrationAction']} '
    'completedThrough=${restoreDiagnostics['originalAcknowledgedCompletionBoundary']} '
    'uploads=${restoreDiagnostics['uploadReconciliation']} '
    'finalResume=${restoreDiagnostics['finalResumeStep']} '
    'reason=${restoreDiagnostics['reasonCode']}',
    name: 'server_reconstructor',
  );
  return ReconstructionIncomplete(
    ownerUid: ownerUid,
    profile: profile,
    step: resumeValidation.resumeStep,
    draft: draft,
    diagnosticCode: resumeValidation.diagnosticCode,
    diagnostics: restoreDiagnostics,
  );
}

bool hasReconstructionProgress(OnboardingDraft draft) {
  return draft.stepCompleted.any((value) => value);
}

bool isReconstructionFinalDraft(OnboardingDraft draft) {
  return draft.onboardingCompleted &&
      draft.stepCompleted.length == OnboardingDraft.stepCount &&
      draft.stepCompleted.every((value) => value) &&
      draft.uid.trim().isNotEmpty;
}

String _safeUid(String uid) {
  if (uid.length <= 6) return '***';
  return '${uid.substring(0, 3)}…${uid.substring(uid.length - 3)}';
}
