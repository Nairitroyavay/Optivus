import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/services/onboarding_run_identity.dart';

void main() {
  test(
    'Step 14 retry reuses only the exact persisted final-draft bundle identity',
    () {
      const uid = 'completion-same-run-user';
      final draft = _completedDraft(uid);
      final bundle = OnboardingCompletionService.buildBundle(draft);

      expect(
        OnboardingCompletionService.bundleMatchesFinalDraft(
          uid: uid,
          draft: draft,
          bundle: bundle,
        ),
        isTrue,
      );
      expect(
        OnboardingCompletionService.bundleMatchesFinalDraft(
          uid: uid,
          draft: draft,
          bundle: OnboardingCompletionBundle.fromMap(
            Map<String, dynamic>.from(bundle.toMap())
              ..['runId'] = legacyOnboardingRunId(
                ownerUid: uid,
                sourceFingerprint: draft.effectiveSourceFingerprint,
                draftRevision: draft.revision,
              ),
          ),
        ),
        isTrue,
      );
      expect(
        OnboardingCompletionService.bundleMatchesFinalDraft(
          uid: uid,
          draft: draft,
          bundle: OnboardingCompletionBundle.fromMap(
            Map<String, dynamic>.from(bundle.toMap())
              ..['runId'] = 'run_0000000000000000000000000000000000000000',
          ),
        ),
        isFalse,
      );
      expect(
        OnboardingCompletionService.bundleMatchesFinalDraft(
          uid: uid,
          draft: draft.copyWith(),
          bundle: bundle,
        ),
        isFalse,
      );
      expect(
        OnboardingCompletionService.bundleMatchesFinalDraft(
          uid: 'different-owner',
          draft: draft,
          bundle: bundle,
        ),
        isFalse,
      );
    },
  );

  test(
    'Step 14 completion persists and verifies the schema-v2 bundle before reconciliation',
    () async {
      const uid = 'completion-schema-v2-pipeline-user';
      final repository = FakeOnboardingRepository();
      final profileRepository = FakeProfileRepository();
      final service = OnboardingCompletionJobService(
        onboardingRepository: repository,
        profileRepository: profileRepository,
      );
      final draft = _completedDraft(uid);
      final bundle = OnboardingCompletionService.buildBundle(draft);
      await profileRepository.saveUserProfile(
        UserProfile.empty(uid: uid, email: 'schema-v2@example.com'),
      );

      final completed = await service.runCompletionJob(
        uid: uid,
        finalDraft: draft,
        bundle: bundle,
      );

      expect(completed.status, OnboardingJobStatus.completed);
      for (final stage in const [
        OnboardingCompletionStage.persistBundle,
        OnboardingCompletionStage.verifyBundle,
        OnboardingCompletionStage.reconcileRoutines,
        OnboardingCompletionStage.verifyRoutines,
        OnboardingCompletionStage.finalizeProfile,
      ]) {
        expect(completed.isStageCompleted(stage), isTrue, reason: stage.name);
      }
      final stored = await repository.fetchCompletionBundle(uid);
      expect(stored, isNotNull);
      expect(stored!.toFirestoreMap()['schemaVersion'], 2);
      expect(stored.runId, 'run_${draft.effectiveSourceFingerprint}');
    },
  );

  test(
    'production retry transition removes failure keys and preserves run state across multiple retries',
    () async {
      const uid = 'completion-retry-contract-user';
      final repository = _ControlledBundleRepository();
      final profileRepository = FakeProfileRepository();
      final service = OnboardingCompletionJobService(
        onboardingRepository: repository,
        profileRepository: profileRepository,
      );
      final draft = _completedDraft(uid);
      final bundle = OnboardingCompletionService.buildBundle(draft);
      await profileRepository.saveUserProfile(
        UserProfile.empty(uid: uid, email: 'retry@example.com'),
      );

      repository.failAttempt(1, _failure(code: 'persist_bundle_failure_1'));
      repository.pauseAttempt(2);
      repository.failAttempt(2, _failure(code: 'persist_bundle_failure_2'));
      repository.pauseAttempt(3);

      await expectLater(
        service.runCompletionJob(uid: uid, finalDraft: draft, bundle: bundle),
        throwsA(isA<OnboardingCompletionFailureException>()),
      );

      final firstFailure = await service.loadCurrentJob(uid);
      expect(firstFailure, isNotNull);
      expect(firstFailure!.status, OnboardingJobStatus.retryableFailure);
      expect(firstFailure.retryCount, 1);
      expect(firstFailure.lastFailureCode, 'persist_bundle_failure_1');
      _expectCanonicalFailureKeysPresent(firstFailure.toFirestoreMap());

      final secondAttempt = service.runCompletionJob(
        uid: uid,
        finalDraft: draft,
        bundle: bundle,
      );
      await repository.waitUntilAttemptStarts(2);

      final firstRetryRunning = await service.loadCurrentJob(uid);
      expect(firstRetryRunning, isNotNull);
      _expectCleanRunningRetry(
        firstRetryRunning!,
        original: firstFailure,
        expectedRetryCount: 1,
      );
      repository.releaseAttempt(2);

      await expectLater(
        secondAttempt,
        throwsA(isA<OnboardingCompletionFailureException>()),
      );
      final secondFailure = await service.loadCurrentJob(uid);
      expect(secondFailure, isNotNull);
      expect(secondFailure!.status, OnboardingJobStatus.retryableFailure);
      expect(secondFailure.retryCount, 2);
      expect(secondFailure.lastFailureCode, 'persist_bundle_failure_2');
      _expectCanonicalFailureKeysPresent(secondFailure.toFirestoreMap());

      final thirdAttempt = service.runCompletionJob(
        uid: uid,
        finalDraft: draft,
        bundle: bundle,
      );
      await repository.waitUntilAttemptStarts(3);

      final secondRetryRunning = await service.loadCurrentJob(uid);
      expect(secondRetryRunning, isNotNull);
      _expectCleanRunningRetry(
        secondRetryRunning!,
        original: secondFailure,
        expectedRetryCount: 2,
      );
      repository.releaseAttempt(3);

      final completed = await thirdAttempt;
      expect(completed.status, OnboardingJobStatus.completed);
      expect(completed.stage, OnboardingCompletionStage.completed);
      expect(completed.retryCount, 2);
      expect(completed.jobId, firstFailure.jobId);
      expect(completed.ownerUid, firstFailure.ownerUid);
      expect(completed.sourceFingerprint, firstFailure.sourceFingerprint);
      expect(completed.draftRevision, firstFailure.draftRevision);
    },
  );

  test(
    'failed run can be replaced after edit while stale reclaim is denied and restart restores B',
    () async {
      const uid = 'completion-edit-replacement-user';
      final repository = _ControlledBundleRepository();
      final profileRepository = FakeProfileRepository();
      final memoryStore = OnboardingCompletionMemoryStore();
      final firstProcess = OnboardingCompletionJobService(
        onboardingRepository: repository,
        profileRepository: profileRepository,
        memoryStore: memoryStore,
      );
      final draftA = _completedDraft(uid);
      final bundleA = OnboardingCompletionService.buildBundle(draftA);
      await profileRepository.saveUserProfile(
        UserProfile.empty(uid: uid, email: 'replacement@example.com'),
      );
      repository.failAttempt(1, _failure(code: 'persist_bundle_failure'));

      await expectLater(
        firstProcess.runCompletionJob(
          uid: uid,
          finalDraft: draftA,
          bundle: bundleA,
        ),
        throwsA(isA<OnboardingCompletionFailureException>()),
      );
      final failedA = await firstProcess.loadCurrentJob(uid);
      expect(failedA?.status, OnboardingJobStatus.retryableFailure);

      final draftB = draftA.copyWith(updatedAt: DateTime.utc(2026, 8, 29));
      final bundleB = OnboardingCompletionService.buildBundle(draftB);
      final completedB = await firstProcess.runCompletionJob(
        uid: uid,
        finalDraft: draftB,
        bundle: bundleB,
      );
      expect(completedB.status, OnboardingJobStatus.completed);
      expect(completedB.jobId, isNot(bundleA.runId));
      expect(completedB.jobId, 'run_${draftB.effectiveSourceFingerprint}');

      final restartedProcess = OnboardingCompletionJobService(
        onboardingRepository: repository,
        profileRepository: profileRepository,
        memoryStore: memoryStore,
      );
      final restored = await restartedProcess.loadCurrentRunSnapshot(uid);
      expect(restored.runId, completedB.jobId);
      expect(restored.pointerStatus, 'completed');
      expect(restored.job?.jobId, completedB.jobId);

      final duplicateB = await restartedProcess.runCompletionJob(
        uid: uid,
        finalDraft: draftB,
        bundle: bundleB,
      );
      expect(duplicateB.jobId, completedB.jobId);
      expect(duplicateB.status, OnboardingJobStatus.completed);

      await expectLater(
        restartedProcess.runCompletionJob(
          uid: uid,
          finalDraft: draftA,
          bundle: bundleA,
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        (await restartedProcess.loadCurrentJob(uid))?.jobId,
        completedB.jobId,
      );
      expect(failedA?.jobId, bundleA.runId);
    },
  );
}

OnboardingCompletionFailureException _failure({required String code}) {
  return OnboardingCompletionFailureException(
    OnboardingCompletionFailure(
      code: code,
      stage: OnboardingCompletionStage.persistBundle,
      retryable: true,
      publicMessageKey: 'error_persist_bundle',
      diagnosticCategory: 'transient_failure',
      failedEntityIds: const [],
      occurredAt: DateTime.utc(2026, 8, 28),
    ),
  );
}

void _expectCleanRunningRetry(
  OnboardingCompletionJob actual, {
  required OnboardingCompletionJob original,
  required int expectedRetryCount,
}) {
  expect(actual.status, OnboardingJobStatus.running);
  // persistBundle has not succeeded, so retry resumes from the last durable
  // checkpoint instead of falsely recording the failed operation as progress.
  expect(actual.stage, OnboardingCompletionStage.verifyDraft);
  expect(actual.retryCount, expectedRetryCount);
  expect(actual.jobId, original.jobId);
  expect(actual.ownerUid, original.ownerUid);
  expect(actual.sourceFingerprint, original.sourceFingerprint);
  expect(actual.draftRevision, original.draftRevision);
  expect(actual.createdAt, original.createdAt);
  expect(actual.schemaVersion, original.schemaVersion);
  expect(actual.stagesCompleted, original.stagesCompleted);

  final map = actual.toFirestoreMap();
  expect(map['status'], OnboardingJobStatus.running.name);
  for (final key in _canonicalFailureKeys) {
    expect(map.containsKey(key), isFalse, reason: '$key must be absent');
  }
}

void _expectCanonicalFailureKeysPresent(Map<String, dynamic> map) {
  for (final key in _canonicalFailureKeys) {
    expect(map.containsKey(key), isTrue, reason: '$key must be present');
  }
}

const _canonicalFailureKeys = <String>[
  'failureCode',
  'failureStage',
  'retryable',
  'publicMessageKey',
  'diagnosticCategory',
  'safeCauseType',
  'failureOccurredAt',
];

OnboardingDraft _completedDraft(String uid) {
  return OnboardingDraft(
    uid: uid,
    currentStep: OnboardingDraft.lastStepIndex,
    stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
    stepDirty: List<bool>.filled(OnboardingDraft.stepCount, false),
    stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
    onboardingCompleted: true,
    createdAt: DateTime.utc(2026, 8, 28),
    updatedAt: DateTime.utc(2026, 8, 28),
  );
}

class _ControlledBundleRepository extends FakeOnboardingRepository {
  final Map<int, Object> _failures = {};
  final Map<int, Completer<void>> _started = {};
  final Map<int, Completer<void>> _releases = {};
  int _attempt = 0;

  void failAttempt(int attempt, Object error) {
    _failures[attempt] = error;
  }

  void pauseAttempt(int attempt) {
    _started[attempt] = Completer<void>();
    _releases[attempt] = Completer<void>();
  }

  Future<void> waitUntilAttemptStarts(int attempt) {
    return _started[attempt]!.future;
  }

  void releaseAttempt(int attempt) {
    _releases[attempt]!.complete();
  }

  @override
  Future<void> saveCompletionBundle(OnboardingCompletionBundle bundle) async {
    _attempt++;
    final started = _started[_attempt];
    if (started != null && !started.isCompleted) started.complete();
    final release = _releases[_attempt];
    if (release != null) await release.future;
    final failure = _failures[_attempt];
    if (failure != null) throw failure;
    await super.saveCompletionBundle(bundle);
  }
}
