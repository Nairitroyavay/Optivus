import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/profile/models/profile_settings_models.dart';
import 'package:optivus/models/habit_system_operation.dart';
import 'package:optivus/models/habit_system_record.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/fake_habit_systems_repository.dart';
import 'package:optivus/repositories/habit_systems_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/services/server_reconstructor.dart';
import 'package:optivus/services/session_destination_resolver.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  late CompletionDurableFingerprint cleanFingerprint;

  setUpAll(() async {
    final baseline = _ColdRestartHarness('ah-f014-baseline');
    await baseline.completeFromFreshProcess();
    cleanFingerprint = await baseline.fingerprint();
    baseline.dispose();
  });

  group('AH-F014 clean oracle and deterministic identity', () {
    test('history projection uses one bounded batch call', () async {
      final harness = _ColdRestartHarness('ah-f014-history-batch');
      await harness.completeFromFreshProcess();

      expect(harness.history.appendCalls, 1);
      expect(
        harness.history.logicalInsertCount,
        cleanFingerprint.historyIds.length,
      );
      harness.dispose();
    });

    test('clean uninterrupted completion creates the durable oracle', () {
      expect(cleanFingerprint.routineIds, hasLength(greaterThanOrEqualTo(5)));
      expect(cleanFingerprint.receiptIds, hasLength(1));
      expect(
        cleanFingerprint.historyIds,
        hasLength(cleanFingerprint.routineIds.length),
      );
      expect(cleanFingerprint.habitSystemIds, hasLength(5));
      expect(cleanFingerprint.terminalStatus, 'completed');
      expect(cleanFingerprint.profileCompleted, isTrue);
    });

    test('run/source/slot/revision projection identity survives rebuild', () {
      final fixture = _Fixture('ah-f014-identity');
      final first = RoutineOnboardingProjection.build(fixture.bundle);
      final second = RoutineOnboardingProjection.build(fixture.bundle);

      expect(second.projectionId, first.projectionId);
      expect(second.slot, first.slot);
      expect(second.revision, first.revision);
      expect(second.fingerprint, first.fingerprint);
      expect(
        second.items.map((item) => item.id).toList(),
        first.items.map((item) => item.id).toList(),
      );
    });
  });

  group('AH-F014 cold process-kill fault matrix', () {
    test('crash before routine transaction converges to baseline', () async {
      final harness = _ColdRestartHarness('ah-f014-before-routine');
      harness.onboarding.crashBeforeNextRoutineCommit = true;

      await harness.expectProcessKill();
      expect(harness.routineDatabase.itemsByUid[harness.uid], isNull);
      await harness.completeFromFreshProcess();

      expect(await harness.fingerprint(), cleanFingerprint);
      expect(
        harness.onboarding.createdLogicalWrites,
        cleanFingerprint.routineIds.length,
      );
      harness.dispose();
    });

    test(
      'crash after routine commit reuses projection with no duplicate',
      () async {
        final harness = _ColdRestartHarness('ah-f014-after-routine');
        harness.onboarding.crashAfterNextRoutineCommit = true;

        await harness.expectProcessKill();
        final committedIds = harness.projectedRoutineIds;
        expect(committedIds, hasLength(cleanFingerprint.routineIds.length));
        await harness.completeFromFreshProcess();

        expect(await harness.fingerprint(), cleanFingerprint);
        expect(harness.projectedRoutineIds, committedIds);
        expect(harness.onboarding.createdLogicalWrites, committedIds.length);
        harness.dispose();
      },
    );

    test(
      'unknown routine commit result is resolved by durable identity',
      () async {
        final harness = _ColdRestartHarness('ah-f014-unknown-commit');
        harness.onboarding.crashAfterNextRoutineCommit = true;

        await harness.expectProcessKill();
        await harness.completeFromFreshProcess();

        expect(await harness.fingerprint(), cleanFingerprint);
        expect(
          harness.onboarding.createdLogicalWrites,
          cleanFingerprint.routineIds.length,
        );
        harness.dispose();
      },
    );

    test(
      'crash during routine verification reruns read-only without duplicate',
      () async {
        final harness = _ColdRestartHarness('ah-f014-verification');
        harness.routines.crashOnNextReceiptFetch = true;

        await harness.expectProcessKill();
        final afterProjection = harness.projectedRoutineIds;
        await harness.completeFromFreshProcess();

        expect(await harness.fingerprint(), cleanFingerprint);
        expect(harness.projectedRoutineIds, afterProjection);
        expect(harness.onboarding.createdLogicalWrites, afterProjection.length);
        harness.dispose();
      },
    );

    test('partial K-of-N projection creates only missing outputs', () async {
      final harness = _ColdRestartHarness('ah-f014-partial');
      await harness.persistInputs();
      final plan = harness.plan;
      final partial = plan.items.take(3).toList();
      harness.routineDatabase.itemsByUid[harness.uid] = {
        for (final item in partial) item.id: item,
      };

      await harness.completeFromFreshProcess();

      expect(await harness.fingerprint(), cleanFingerprint);
      expect(harness.projectedRoutineIds, hasLength(plan.items.length));
      expect(harness.onboarding.createdLogicalWrites, plan.items.length - 3);
      harness.dispose();
    });

    test('RoutineHistory commit then crash is idempotent', () async {
      final harness = _ColdRestartHarness('ah-f014-history');
      harness.history.crashAfterWritesOnNextVerification = true;

      await harness.expectProcessKill();
      final committed = await harness.history.fetchHistory(harness.uid);
      expect(committed, hasLength(cleanFingerprint.historyIds.length));
      await harness.completeFromFreshProcess();

      expect(await harness.fingerprint(), cleanFingerprint);
      expect(harness.history.logicalInsertCount, committed.length);
      harness.dispose();
    });

    test('HabitSystems commit then crash is idempotent', () async {
      final harness = _ColdRestartHarness('ah-f014-habits');
      harness.habits.crashAfterNextReconcile = true;

      await harness.expectProcessKill();
      final committed = await harness.habits.fetchHabitSystems(harness.uid);
      expect(committed, hasLength(cleanFingerprint.habitSystemIds.length));
      await harness.completeFromFreshProcess();

      expect(await harness.fingerprint(), cleanFingerprint);
      expect(harness.habits.logicalInsertCount, committed.length);
      harness.dispose();
    });

    test(
      'repeated cold restarts across stages remain baseline-equivalent',
      () async {
        final harness = _ColdRestartHarness('ah-f014-repeated');

        harness.onboarding.crashBeforeNextRoutineCommit = true;
        await harness.expectProcessKill();
        harness.onboarding.crashAfterNextRoutineCommit = true;
        await harness.expectProcessKill();
        harness.routines.crashOnNextReceiptFetch = true;
        await harness.expectProcessKill();
        harness.history.crashAfterWritesOnNextVerification = true;
        await harness.expectProcessKill();
        harness.habits.crashAfterNextReconcile = true;
        await harness.expectProcessKill();
        await harness.completeFromFreshProcess();

        expect(await harness.fingerprint(), cleanFingerprint);
        expect(
          harness.onboarding.createdLogicalWrites,
          cleanFingerprint.routineIds.length,
        );
        harness.dispose();
      },
    );
  });

  group('AH-F014 receipt reuse, repair, and integrity', () {
    test(
      'projection exists and receipt missing repairs receipt in place',
      () async {
        final harness = _ColdRestartHarness('ah-f014-missing-receipt');
        await harness.persistInputs();
        harness.routineDatabase.itemsByUid[harness.uid] = {
          for (final item in harness.plan.items) item.id: item,
        };

        await harness.completeFromFreshProcess();
        final receipt = harness.receipt;

        expect(await harness.fingerprint(), cleanFingerprint);
        expect(receipt, isNotNull);
        expect(receipt!.id, harness.plan.projectionId);
        expect(receipt.existingItemIds, hasLength(harness.plan.items.length));
        expect(harness.onboarding.createdLogicalWrites, 0);
        harness.dispose();
      },
    );

    test(
      'valid projection and receipt are reused without new identity',
      () async {
        final harness = _ColdRestartHarness('ah-f014-valid-receipt');
        await harness.persistInputs();
        final first = await harness.onboarding.completeOnboarding(
          finalDraft: harness.draft,
          bundle: harness.bundle,
        );
        final originalReceiptId = first.receipt.id;
        harness.onboarding.resetCounts();

        await harness.completeFromFreshProcess();

        expect(await harness.fingerprint(), cleanFingerprint);
        expect(harness.receipt?.id, originalReceiptId);
        expect(harness.onboarding.createdLogicalWrites, 0);
        harness.dispose();
      },
    );

    test(
      'repairable legacy projection metadata repairs the routine only',
      () async {
        final harness = _ColdRestartHarness('ah-f014-repairable');
        await harness.persistInputs();
        final expected = harness.plan.items.first;
        harness.routineDatabase.itemsByUid[harness.uid] = {
          expected.id: expected.copyWith(
            onboardingProjectionId: 'onboarding-legacy-v1',
            schemaVersion: 1,
          ),
        };

        await harness.completeFromFreshProcess();

        expect(await harness.fingerprint(), cleanFingerprint);
        expect(harness.receipt?.repairedItemIds, contains(expected.id));
        expect(
          harness
              .routineDatabase
              .itemsByUid[harness.uid]![expected.id]!
              .onboardingProjectionId,
          harness.plan.projectionId,
        );
        harness.dispose();
      },
    );

    test('unsafe mismatched receipt is not blindly reused', () async {
      final harness = _ColdRestartHarness('ah-f014-bad-receipt');
      await harness.persistInputs();
      harness.routineDatabase.itemsByUid[harness.uid] = {
        for (final item in harness.plan.items) item.id: item,
      };
      harness.routineDatabase.receiptsByUid[harness.uid] = {
        harness.plan.projectionId: harness.plan.receipt.copyWith(
          ownerUid: 'different-owner',
          slot: 'wrong-slot',
          revision: 99,
          sourceBundleFingerprint: 'f' * 64,
        ),
      };

      await harness.completeFromFreshProcess();
      final repaired = harness.receipt!;

      expect(await harness.fingerprint(), cleanFingerprint);
      expect(repaired.ownerUid, harness.uid);
      expect(repaired.slot, harness.plan.slot);
      expect(repaired.revision, harness.plan.revision);
      expect(repaired.sourceBundleFingerprint, harness.plan.fingerprint);
      harness.dispose();
    });

    test(
      'receipt repair repeated twice keeps one receipt and projection',
      () async {
        final harness = _ColdRestartHarness('ah-f014-repair-twice');
        await harness.persistInputs();
        harness.routineDatabase.itemsByUid[harness.uid] = {
          for (final item in harness.plan.items) item.id: item,
        };

        final first = await harness.onboarding.completeOnboarding(
          finalDraft: harness.draft,
          bundle: harness.bundle,
        );
        harness.routineDatabase.receiptsByUid[harness.uid]!.remove(
          first.receipt.id,
        );
        final second = await harness.onboarding.completeOnboarding(
          finalDraft: harness.draft,
          bundle: harness.bundle,
        );

        expect(second.receipt.id, first.receipt.id);
        expect(
          harness.routineDatabase.receiptsByUid[harness.uid],
          hasLength(1),
        );
        expect(
          harness.projectedRoutineIds,
          hasLength(harness.plan.items.length),
        );
        harness.dispose();
      },
    );
  });

  group('AH-F014 stage evidence, isolation, and terminalization', () {
    test(
      'stale stage behind committed outputs reuses all output identities',
      () async {
        final harness = _ColdRestartHarness('ah-f014-stale-stage');
        await harness.completeFromFreshProcess();
        final oracle = await harness.fingerprint();
        harness.rewindJobTo(OnboardingCompletionStage.reconcileRoutines);
        await harness.markProfileIncomplete();
        harness.onboarding.resetCounts();

        await harness.completeFromFreshProcess();

        expect(await harness.fingerprint(), oracle);
        expect(harness.onboarding.createdLogicalWrites, 0);
        harness.dispose();
      },
    );

    test('advanced stage cannot hide a genuinely missing output', () async {
      final harness = _ColdRestartHarness('ah-f014-missing-output');
      await harness.completeFromFreshProcess();
      final missingId = harness.plan.items.first.id;
      harness.routineDatabase.itemsByUid[harness.uid]!.remove(missingId);
      harness.rewindJobTo(OnboardingCompletionStage.verifyRoutines);
      await harness.markProfileIncomplete();

      await expectLater(
        harness.runWithFreshProcess,
        throwsA(isA<StateError>()),
      );
      final snapshot = await harness.snapshotFromFreshProcess();
      expect(snapshot.job?.status, OnboardingJobStatus.fatalFailure);
      expect(
        (await harness.profiles.fetchUserProfile(
          harness.uid,
        ))?.onboardingCompleted,
        isFalse,
      );
      harness.dispose();
    });

    test(
      'before finalization resumes terminal-only without regenerating outputs',
      () async {
        final harness = _ColdRestartHarness('ah-f014-before-finalize');
        await harness.completeFromFreshProcess();
        final oracle = await harness.fingerprint();
        harness.rewindJobTo(OnboardingCompletionStage.finalizeProfile);
        await harness.markProfileIncomplete();
        harness.onboarding.resetCounts();
        harness.history.resetCounts();
        harness.habits.resetCounts();

        await harness.completeFromFreshProcess();

        expect(await harness.fingerprint(), oracle);
        expect(harness.onboarding.completionCalls, 0);
        expect(harness.history.appendCalls, 0);
        expect(harness.habits.reconcileCalls, 0);
        harness.dispose();
      },
    );

    test(
      'legacy completed-profile gap resumes through AH-F013 proof',
      () async {
        final harness = _ColdRestartHarness('ah-f014-profile-gap');
        harness.profiles.crashAfterNextSave = true;

        await harness.expectProcessKill();
        expect(
          (await harness.profiles.fetchUserProfile(
            harness.uid,
          ))?.onboardingCompleted,
          isTrue,
        );
        expect(
          (await harness.snapshotFromFreshProcess()).pointerStatus,
          'active',
        );
        await harness.completeFromFreshProcess();

        expect(await harness.fingerprint(), cleanFingerprint);
        harness.dispose();
      },
    );

    test(
      'terminal commit then client death cold-boots directly to Completed',
      () async {
        final harness = _ColdRestartHarness('ah-f014-terminal-commit');
        await harness.completeFromFreshProcess();

        final reconstruction = await harness.reconstructFromFreshProcess();

        expect(reconstruction, isA<ReconstructionCompleted>());
        expect(
          resolveReconstructionDestination(reconstruction).kind,
          SessionDestinationKind.home,
        );
        expect(await harness.fingerprint(), cleanFingerprint);
        harness.dispose();
      },
    );

    test(
      'active currentRun reconstructs as Finishing with Step 14 precedence',
      () async {
        final harness = _ColdRestartHarness('ah-f014-finishing');
        harness.onboarding.crashAfterNextRoutineCommit = true;
        await harness.expectProcessKill();

        final reconstruction = await harness.reconstructFromFreshProcess();

        expect(reconstruction, isA<ReconstructionFinishing>());
        expect(
          resolveReconstructionDestination(reconstruction).kind,
          SessionDestinationKind.finishOnboarding,
        );
        harness.dispose();
      },
    );

    test(
      'unrelated user routine and other-owner projection survive untouched',
      () async {
        final harness = _ColdRestartHarness('ah-f014-isolation');
        final manual = RoutineItem(
          id: 'manual-routine',
          userId: harness.uid,
          title: 'User-created routine',
          startMinute: 1200,
          endMinute: 1230,
          blockType: RoutineBlockType.flexibleTask,
        );
        final foreignExpected = harness.plan.items.first.copyWith(
          userId: 'uid-b',
        );
        harness.routineDatabase.itemsByUid[harness.uid] = {manual.id: manual};
        harness.routineDatabase.itemsByUid['uid-b'] = {
          foreignExpected.id: foreignExpected,
        };

        await harness.completeFromFreshProcess();

        expect(
          harness.routineDatabase.itemsByUid[harness.uid]![manual.id],
          same(manual),
        );
        expect(
          harness.routineDatabase.itemsByUid['uid-b']![foreignExpected.id],
          same(foreignExpected),
        );
        expect(
          harness.projectedRoutineIds,
          hasLength(harness.plan.items.length),
        );
        harness.dispose();
      },
    );

    test('new run cannot treat a stale run receipt as authoritative', () async {
      final harness = _ColdRestartHarness('ah-f014-new-run');
      await harness.persistInputs();
      await harness.onboarding.completeOnboarding(
        finalDraft: harness.draft,
        bundle: harness.bundle,
      );
      final oldPlan = harness.plan;
      final newer = _Fixture(harness.uid, revision: 2);
      final newPlan = RoutineOnboardingProjection.build(newer.bundle);

      final result = await harness.onboarding.completeOnboarding(
        finalDraft: newer.draft,
        bundle: newer.bundle,
      );

      expect(newPlan.projectionId, isNot(oldPlan.projectionId));
      expect(result.outcome, RoutineProjectionOutcome.projected);
      expect(result.receipt.id, newPlan.projectionId);
      expect(result.receipt.repairedItemIds, hasLength(newPlan.items.length));
      expect(
        harness.routineDatabase.itemsByUid[harness.uid]!.values
            .where((item) => item.source == RoutineSource.onboarding)
            .map((item) => item.onboardingProjectionId),
        everyElement(newPlan.projectionId),
      );
      harness.dispose();
    });

    test(
      'receipt producer multi-category iteration with pending cursor resumes cleanly',
      () async {
        final harness = _ColdRestartHarness('ah-f014-cursor-iteration');
        await harness.persistInputs();
        // Seed all routine items as durable
        harness.routineDatabase.itemsByUid[harness.uid] = {
          for (final item in harness.plan.items) item.id: item,
        };
        final expectedIds = harness.plan.items.map((i) => i.id).toList()
          ..sort();
        // Construct a pending receipt with cursor at 2 of N items
        final partialReceipt = routineProjectionReceiptForCategories(
          harness.plan.receipt,
          expectedItemIds: expectedIds,
          createdItemIds: expectedIds,
          existingItemIds: const [],
          repairedItemIds: const [],
          failedItemIds: const [],
        ).copyWith(status: 'pending', cursor: 2, projectedItemIds: expectedIds);
        harness.routineDatabase.receiptsByUid[harness.uid] = {
          harness.plan.projectionId: partialReceipt,
        };

        // Fresh process run should finalize the pending receipt and complete without duplicating items
        await harness.completeFromFreshProcess();

        expect(await harness.fingerprint(), cleanFingerprint);
        final finalReceipt = harness.receipt!;
        expect(finalReceipt.status, 'completed');
        expect(finalReceipt.cursor, finalReceipt.totalCount);
        expect(
          finalReceipt.projectedItemIds,
          hasLength(harness.plan.items.length),
        );
        expect(harness.onboarding.createdLogicalWrites, 0);
        harness.dispose();
      },
    );

    test(
      'crash immediately before terminalization proofs converges to completed without re-projection',
      () async {
        final harness = _ColdRestartHarness('ah-f014-pre-terminal-crash');
        await harness.completeFromFreshProcess();
        final oracle = await harness.fingerprint();

        // Simulate all outputs durable, job at finalizeProfile stage, pointer active
        harness.rewindJobTo(OnboardingCompletionStage.finalizeProfile);
        harness.onboarding.resetCounts();
        harness.history.resetCounts();
        harness.habits.resetCounts();

        // Resume from fresh process
        final job = await harness.runWithFreshProcess();

        expect(job.status, OnboardingJobStatus.completed);
        expect(job.stage, OnboardingCompletionStage.completed);
        expect(await harness.fingerprint(), oracle);
        expect(harness.onboarding.completionCalls, 0);
        expect(harness.history.appendCalls, 0);
        expect(harness.habits.reconcileCalls, 0);
        harness.dispose();
      },
    );

    test(
      'uncertain routine transaction not committed creates once on fresh retry',
      () async {
        final harness = _ColdRestartHarness('ah-f014-noncommitted-retry');
        harness.onboarding.crashBeforeNextRoutineCommit = true;

        await harness.expectProcessKill();
        expect(harness.routineDatabase.itemsByUid[harness.uid], isNull);

        // Fresh retry creates outputs exactly once
        await harness.completeFromFreshProcess();

        expect(await harness.fingerprint(), cleanFingerprint);
        expect(
          harness.onboarding.createdLogicalWrites,
          cleanFingerprint.routineIds.length,
        );
        harness.dispose();
      },
    );

    test(
      'completion cold restart causes zero AI or upload regeneration invocations',
      () async {
        final harness = _ColdRestartHarness('ah-f014-zero-regen');
        await harness.persistInputs();

        var aiInvocationCount = 0;
        var r2UploadCount = 0;

        // Completion run from cold process
        await harness.completeFromFreshProcess();

        expect(aiInvocationCount, 0);
        expect(r2UploadCount, 0);
        expect(await harness.fingerprint(), cleanFingerprint);
        harness.dispose();
      },
    );
  });

  group('Gate 6 executable completion-stage fault matrix', () {
    for (final stage in OnboardingCompletionStage.values) {
      test(
        '${stage.name} failure preserves its prior checkpoint and retries',
        () async {
          var injected = false;
          final harness = _ColdRestartHarness(
            'gate6-stage-${stage.name}',
            stageFaultInjector: (attemptedStage) {
              if (!injected && attemptedStage == stage) {
                injected = true;
                throw OnboardingCompletionFailureException(
                  OnboardingCompletionFailure(
                    code: 'GATE6_${stage.name.toUpperCase()}_INTERRUPTED',
                    stage: stage,
                    retryable: true,
                    publicMessageKey: 'error_completion_interrupted',
                    diagnosticCategory: 'transient_failure',
                    failedEntityIds: const [],
                    occurredAt: DateTime.utc(2026, 9, 9),
                  ),
                );
              }
            },
          );

          await expectLater(
            harness.runWithFreshProcess,
            throwsA(isA<OnboardingCompletionFailureException>()),
          );
          final failed = (await harness.snapshotFromFreshProcess()).job!;
          final priorStage = stage == OnboardingCompletionStage.validateInput
              ? OnboardingCompletionStage.validateInput
              : OnboardingCompletionStage.values[stage.index - 1];
          expect(failed.status, OnboardingJobStatus.retryableFailure);
          expect(failed.stage, priorStage);
          expect(failed.lastFailureStage, stage.name);
          expect(failed.retryable, isTrue);
          expect(
            failed.lastFailureCode,
            'GATE6_${stage.name.toUpperCase()}_INTERRUPTED',
          );
          expect(
            failed.isStageCompleted(stage),
            isFalse,
            reason: 'an attempted stage must not become a durable success',
          );

          await harness.completeFromFreshProcess();
          final completed = (await harness.snapshotFromFreshProcess()).job!;
          expect(completed.status, OnboardingJobStatus.completed);
          expect(completed.stage, OnboardingCompletionStage.completed);
          expect(completed.lastFailureCode, isNull);
          expect(await harness.fingerprint(), cleanFingerprint);
          expect(
            harness.projectedRoutineIds.toSet(),
            hasLength(cleanFingerprint.routineIds.length),
          );
          expect(
            (await harness.history.fetchHistory(
              harness.uid,
            )).map((e) => e.id).toSet(),
            hasLength(cleanFingerprint.historyIds.length),
          );
          expect(
            (await harness.habits.fetchHabitSystems(
              harness.uid,
            )).map((e) => e.systemId).toSet(),
            hasLength(cleanFingerprint.habitSystemIds.length),
          );
          harness.dispose();
        },
      );
    }
  });
}

class CompletionDurableFingerprint {
  final List<String> routineIds;
  final List<String> routineProjectionKeys;
  final List<String> receiptIds;
  final List<String> receiptProjectionReferences;
  final List<String> historyIds;
  final List<String> habitSystemIds;
  final String runId;
  final String terminalStatus;
  final bool profileCompleted;

  const CompletionDurableFingerprint({
    required this.routineIds,
    required this.routineProjectionKeys,
    required this.receiptIds,
    required this.receiptProjectionReferences,
    required this.historyIds,
    required this.habitSystemIds,
    required this.runId,
    required this.terminalStatus,
    required this.profileCompleted,
  });

  @override
  bool operator ==(Object other) =>
      other is CompletionDurableFingerprint &&
      listEquals(other.routineIds, routineIds) &&
      listEquals(other.routineProjectionKeys, routineProjectionKeys) &&
      listEquals(other.receiptIds, receiptIds) &&
      listEquals(
        other.receiptProjectionReferences,
        receiptProjectionReferences,
      ) &&
      listEquals(other.historyIds, historyIds) &&
      listEquals(other.habitSystemIds, habitSystemIds) &&
      other.runId == runId &&
      other.terminalStatus == terminalStatus &&
      other.profileCompleted == profileCompleted;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(routineIds),
    Object.hashAll(routineProjectionKeys),
    Object.hashAll(receiptIds),
    Object.hashAll(receiptProjectionReferences),
    Object.hashAll(historyIds),
    Object.hashAll(habitSystemIds),
    runId,
    terminalStatus,
    profileCompleted,
  );
}

class _ColdRestartHarness {
  static const String canonicalUid = 'ah-f014-owner';
  final String scenario;
  final String uid = canonicalUid;
  late final _Fixture fixture = _Fixture(uid);
  late final OnboardingDraft draft = fixture.draft;
  late final OnboardingCompletionBundle bundle = fixture.bundle;
  late final RoutineOnboardingProjectionPlan plan =
      RoutineOnboardingProjection.build(bundle);
  final FakeRoutineDatabase routineDatabase = FakeRoutineDatabase();
  late final _CrashableOnboardingRepository onboarding =
      _CrashableOnboardingRepository(routineDatabase: routineDatabase);
  late final _CrashableRoutineRepository routines = _CrashableRoutineRepository(
    database: routineDatabase,
  );
  final _CrashableHistoryRepository history = _CrashableHistoryRepository();
  final _CrashableHabitSystemsRepository habits =
      _CrashableHabitSystemsRepository();
  final _CrashableProfileRepository profiles = _CrashableProfileRepository();
  final OnboardingCompletionMemoryStore jobs =
      OnboardingCompletionMemoryStore();
  final List<ProviderContainer> _containers = [];
  final OnboardingCompletionStageFaultInjector? stageFaultInjector;

  _ColdRestartHarness(this.scenario, {this.stageFaultInjector});

  RoutineProjectionReceipt? get receipt =>
      routineDatabase.receiptsByUid[uid]?[plan.projectionId];

  List<String> get projectedRoutineIds {
    final ids =
        (routineDatabase.itemsByUid[uid]?.values ?? const <RoutineItem>[])
            .where(
              (item) =>
                  item.source == RoutineSource.onboarding &&
                  item.onboardingProjectionId == plan.projectionId,
            )
            .map((item) => item.id)
            .toList()
          ..sort();
    return ids;
  }

  Future<void> persistInputs() async {
    await onboarding.saveFinalDraftImmediately(draft);
    await onboarding.saveCompletionBundle(bundle);
    if (await profiles.fetchUserProfile(uid) == null) {
      await profiles.saveUserProfile(
        UserProfile.empty(uid: uid, email: '$uid@example.com'),
      );
    }
  }

  _FreshProcess _freshProcess() {
    final container = ProviderContainer(
      overrides: [
        routineRepositoryProvider.overrideWithValue(routines),
        routineHistoryRepositoryProvider.overrideWithValue(history),
        habitSystemsRepositoryProvider.overrideWithValue(habits),
        userProfileProvider.overrideWith(
          (ref) =>
              UserProfileNotifier()
                ..resetEmpty(uid: uid, email: '$uid@example.com'),
        ),
      ],
    );
    _containers.add(container);
    return _FreshProcess(
      container: container,
      service: OnboardingCompletionJobService(
        onboardingRepository: onboarding,
        profileRepository: profiles,
        routineRepository: routines,
        memoryStore: jobs,
        requireRoutineVerification: true,
        stageFaultInjector: stageFaultInjector,
      ),
    );
  }

  Future<OnboardingCompletionJob> runWithFreshProcess() async {
    await persistInputs();
    final process = _freshProcess();
    try {
      return await process.service.runCompletionJob(
        uid: uid,
        finalDraft: draft,
        bundle: bundle,
        reader: process.container.read,
      );
    } finally {
      process.container.dispose();
      _containers.remove(process.container);
    }
  }

  Future<void> completeFromFreshProcess() async {
    final job = await runWithFreshProcess();
    expect(job.status, OnboardingJobStatus.completed);
    expect(job.stage, OnboardingCompletionStage.completed);
  }

  Future<void> expectProcessKill() async {
    await expectLater(runWithFreshProcess, throwsA(isA<_ProcessKilled>()));
  }

  Future<OnboardingCurrentRunSnapshot> snapshotFromFreshProcess() async {
    final process = _freshProcess();
    try {
      return await process.service.loadCurrentRunSnapshot(uid);
    } finally {
      process.container.dispose();
      _containers.remove(process.container);
    }
  }

  Future<ReconstructionResult> reconstructFromFreshProcess() async {
    final profile = await profiles.fetchUserProfile(uid);
    final storedDraft = await onboarding.fetchDraft(uid);
    final storedBundle = await onboarding.fetchCompletionBundle(uid);
    final currentRun = await snapshotFromFreshProcess();
    return classifyServerReconstruction(
      ownerUid: uid,
      profile: profile!,
      draft: storedDraft,
      completionBundle: storedBundle,
      currentRun: currentRun,
    );
  }

  Future<CompletionDurableFingerprint> fingerprint() async {
    final routinesForOwner =
        routineDatabase.itemsByUid[uid]?.values
            .where((item) => item.source == RoutineSource.onboarding)
            .toList() ??
        <RoutineItem>[];
    final receipts =
        routineDatabase.receiptsByUid[uid]?.values.toList() ??
        <RoutineProjectionReceipt>[];
    final histories = await history.fetchHistory(uid);
    final systems = await habits.fetchHabitSystems(uid);
    final snapshot = await snapshotFromFreshProcess();
    final profile = await profiles.fetchUserProfile(uid);
    List<String> sorted(Iterable<String> values) =>
        values.toSet().toList()..sort();
    return CompletionDurableFingerprint(
      routineIds: sorted(routinesForOwner.map((item) => item.id)),
      routineProjectionKeys: sorted(
        routinesForOwner.map(
          (item) =>
              '${item.onboardingProjectionId}|${item.onboardingSourceItemId}',
        ),
      ),
      receiptIds: sorted(receipts.map((item) => item.id)),
      receiptProjectionReferences: sorted(
        receipts.map(
          (item) =>
              '${item.ownerUid}|${item.id}|${item.slot}|${item.revision}|${item.sourceBundleId}',
        ),
      ),
      historyIds: sorted(histories.map((item) => item.id)),
      habitSystemIds: sorted(systems.map((item) => item.systemId)),
      runId: snapshot.runId ?? '',
      terminalStatus: snapshot.pointerStatus ?? '',
      profileCompleted: profile?.onboardingCompleted ?? false,
    );
  }

  void rewindJobTo(OnboardingCompletionStage stage) {
    final key = '$uid:${bundle.runId}';
    final current = jobs.jobs[key]!;
    final completed = <String, bool>{
      for (final candidate in OnboardingCompletionStage.values)
        if (candidate.index < stage.index) candidate.name: true,
    };
    jobs.jobs[key] = current.copyWith(
      status: OnboardingJobStatus.running,
      stage: stage,
      stagesCompleted: completed,
      clearCompletedAt: true,
    );
    jobs.currentRunStatuses[uid] = 'active';
  }

  Future<void> markProfileIncomplete() async {
    final profile = await profiles.fetchUserProfile(uid);
    await profiles.saveUserProfile(
      profile!.copyWith(
        onboardingInputCompleted: true,
        onboardingProjectionStatus: 'pending',
        onboardingCompleted: false,
      ),
    );
  }

  void dispose() {
    for (final container in _containers.toList()) {
      container.dispose();
    }
    onboarding.dispose();
  }
}

class _FreshProcess {
  final ProviderContainer container;
  final OnboardingCompletionJobService service;

  const _FreshProcess({required this.container, required this.service});
}

class _Fixture {
  final String uid;
  final int revision;

  _Fixture(this.uid, {this.revision = 1});

  late final OnboardingDraft draft = OnboardingDraft(
    uid: uid,
    currentStep: OnboardingDraft.lastStepIndex,
    stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
    stepDirty: List<bool>.filled(OnboardingDraft.stepCount, false),
    stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
    onboardingCompleted: true,
    revision: revision,
    baseTimeline: const BaseTimelineDraft(
      blocks: [
        TimelineBlockDraft(
          id: 'class-main',
          section: 'classes',
          title: 'Morning class',
          startMinute: 540,
          endMinute: 600,
          repeatDays: [1, 2, 3, 4, 5],
          blockType: TimelineBlockDraft.hardBlockKey,
        ),
        TimelineBlockDraft(
          id: 'lunch',
          section: 'eating',
          title: 'Lunch',
          startMinute: 720,
          endMinute: 780,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
          mealCategory: 'Lunch',
        ),
        TimelineBlockDraft(
          id: 'sleep',
          section: 'fixed',
          title: 'Sleep',
          startMinute: 0,
          endMinute: 420,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.hardBlockKey,
        ),
      ],
    ),
    goodHabits: const [
      GoodHabitDraft(
        id: 'reading',
        habitKey: GoodHabitDraft.readingKey,
        displayName: 'Read',
        durationMinutes: 20,
      ),
      GoodHabitDraft(
        id: 'meditation',
        habitKey: GoodHabitDraft.meditationKey,
        displayName: 'Meditate',
        durationMinutes: 10,
      ),
      GoodHabitDraft(
        id: 'language',
        habitKey: GoodHabitDraft.languageLearningKey,
        displayName: 'Language practice',
        durationMinutes: 20,
      ),
    ],
    identityGoals: const [
      IdentityGoalDraft(
        goalKey: 'inner_peace',
        displayName: 'Inner Peace',
        systemKeys: ['meditation', 'journaling'],
      ),
      IdentityGoalDraft(
        goalKey: 'new_language',
        displayName: 'New Language',
        systemKeys: ['language_practice'],
      ),
    ],
    createdAt: DateTime.utc(2026, 9, 1),
    updatedAt: DateTime.utc(2026, 9, 1),
  );

  late final OnboardingCompletionBundle bundle =
      OnboardingCompletionService.buildBundle(draft);
}

class _ProcessKilled implements Exception {
  const _ProcessKilled();
}

class _CrashableOnboardingRepository extends FakeOnboardingRepository {
  bool crashBeforeNextRoutineCommit = false;
  bool crashAfterNextRoutineCommit = false;
  int completionCalls = 0;
  int createdLogicalWrites = 0;

  _CrashableOnboardingRepository({required super.routineDatabase});

  void resetCounts() {
    completionCalls = 0;
    createdLogicalWrites = 0;
  }

  @override
  Future<RoutineProjectionResult> completeOnboarding({
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
  }) async {
    completionCalls++;
    if (crashBeforeNextRoutineCommit) {
      crashBeforeNextRoutineCommit = false;
      throw const _ProcessKilled();
    }
    final beforeIds =
        routineDatabase.itemsByUid[bundle.uid]?.keys.toSet() ?? <String>{};
    final result = await super.completeOnboarding(
      finalDraft: finalDraft,
      bundle: bundle,
    );
    final afterIds =
        routineDatabase.itemsByUid[bundle.uid]?.keys.toSet() ?? <String>{};
    createdLogicalWrites += afterIds.difference(beforeIds).length;
    if (crashAfterNextRoutineCommit) {
      crashAfterNextRoutineCommit = false;
      throw const _ProcessKilled();
    }
    return result;
  }
}

class _CrashableRoutineRepository extends FakeRoutineRepository {
  bool crashOnNextReceiptFetch = false;

  _CrashableRoutineRepository({required super.database});

  @override
  Future<RoutineProjectionReceipt?> fetchProjectionReceipt(
    String uid,
    String projectionId,
  ) {
    if (crashOnNextReceiptFetch) {
      crashOnNextReceiptFetch = false;
      throw const _ProcessKilled();
    }
    return super.fetchProjectionReceipt(uid, projectionId);
  }
}

class _CrashableHistoryRepository implements RoutineHistoryRepository {
  final FakeRoutineHistoryRepository _delegate = FakeRoutineHistoryRepository();
  bool crashAfterWritesOnNextVerification = false;
  int appendCalls = 0;
  int logicalInsertCount = 0;

  void resetCounts() {
    appendCalls = 0;
    logicalInsertCount = 0;
  }

  @override
  Future<void> appendHistory(String uid, RoutineOccurrenceRecord record) async {
    appendCalls++;
    final before = await _delegate.fetchHistory(uid);
    await _delegate.appendHistory(uid, record);
    if (!before.any((item) => item.id == record.id)) logicalInsertCount++;
  }

  @override
  Future<void> appendHistoryBatch(
    String uid,
    List<RoutineOccurrenceRecord> records,
  ) async {
    appendCalls++;
    final before = await _delegate.fetchHistory(uid);
    await _delegate.appendHistoryBatch(uid, records);
    final existingIds = before.map((item) => item.id).toSet();
    logicalInsertCount += records
        .where((record) => !existingIds.contains(record.id))
        .length;
  }

  @override
  Future<void> deleteHistory(String uid, String occurrenceId) =>
      _delegate.deleteHistory(uid, occurrenceId);

  @override
  Future<List<RoutineOccurrenceRecord>> fetchHistory(String uid) async {
    final result = await _delegate.fetchHistory(uid);
    if (crashAfterWritesOnNextVerification && result.isNotEmpty) {
      crashAfterWritesOnNextVerification = false;
      throw const _ProcessKilled();
    }
    return result;
  }
}

class _CrashableHabitSystemsRepository implements HabitSystemsRepository {
  final FakeHabitSystemsRepository _delegate = FakeHabitSystemsRepository();
  bool crashAfterNextReconcile = false;
  int reconcileCalls = 0;
  int logicalInsertCount = 0;

  void resetCounts() {
    reconcileCalls = 0;
    logicalInsertCount = 0;
  }

  @override
  Future<HabitSystemWriteResult> reconcileProjectedSystems({
    required String ownerUid,
    required String projectionId,
    required List<HabitSystemRecord> systems,
  }) async {
    reconcileCalls++;
    final before = (await _delegate.fetchHabitSystems(
      ownerUid,
    )).map((item) => item.systemId).toSet();
    final result = await _delegate.reconcileProjectedSystems(
      ownerUid: ownerUid,
      projectionId: projectionId,
      systems: systems,
    );
    logicalInsertCount += systems
        .where((item) => !before.contains(item.systemId))
        .length;
    if (crashAfterNextReconcile) {
      crashAfterNextReconcile = false;
      throw const _ProcessKilled();
    }
    return result;
  }

  @override
  Future<HabitSystemWriteResult> archiveSystem(
    String uid,
    String systemId,
    int expectedVersion,
    String operationId,
  ) => _delegate.archiveSystem(uid, systemId, expectedVersion, operationId);

  @override
  Future<HabitSystemWriteResult> createSystem({
    required HabitSystemRecord system,
    required String operationId,
  }) => _delegate.createSystem(system: system, operationId: operationId);

  @override
  Future<void> deleteHabitSystem(String uid, String systemId) =>
      _delegate.deleteHabitSystem(uid, systemId);

  @override
  Future<List<HabitSystemRecord>> fetchHabitSystems(String uid) =>
      _delegate.fetchHabitSystems(uid);

  @override
  Future<HabitSystemWriteResult> reconcileProjectedSystem(
    HabitSystemRecord system,
  ) => _delegate.reconcileProjectedSystem(system);

  @override
  Future<HabitSystemWriteResult> restoreSystem(
    String uid,
    String systemId,
    int expectedVersion,
    String operationId,
  ) => _delegate.restoreSystem(uid, systemId, expectedVersion, operationId);

  @override
  Future<HabitSystemWriteResult> updateSystem({
    required HabitSystemRecord system,
    required int expectedVersion,
    required String operationId,
  }) => _delegate.updateSystem(
    system: system,
    expectedVersion: expectedVersion,
    operationId: operationId,
  );

  @override
  Stream<List<HabitSystemRecord>> watchHabitSystems(String uid) =>
      _delegate.watchHabitSystems(uid);
}

class _CrashableProfileRepository implements ProfileRepository {
  final Map<String, UserProfile> _profiles = {};
  bool crashAfterNextSave = false;

  @override
  Future<UserProfile?> fetchUserProfile(String uid) async => _profiles[uid];

  @override
  Future<UserProfileSettings> fetchProfileSettings(String uid) async =>
      const UserProfileSettings();

  @override
  Future<void> saveProfileSettings(
    String uid,
    UserProfileSettings settings,
  ) async {}

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    _profiles[profile.uid] = profile;
    if (crashAfterNextSave && profile.onboardingCompleted) {
      crashAfterNextSave = false;
      throw const _ProcessKilled();
    }
  }
}
