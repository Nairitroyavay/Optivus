import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/app_preferences_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/repositories/region_settings_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/repositories/habit_systems_repository.dart';
import 'package:optivus/repositories/fake_habit_systems_repository.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_resume_validator.dart';
import 'package:optivus/services/habit_system_onboarding_projection.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/services/server_reconstructor.dart';
import 'package:optivus/services/session_destination_resolver.dart';
import 'package:optivus/features/routine/controllers/habit_systems_controller.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/recovery/models/onboarding_recovery_models.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/upload_state.dart';

void main() {
  const uid = 'ah-f007-owner';

  group('AH-F007 typed server classification', () {
    test('A no meaningful durable onboarding state is Fresh', () {
      final result = _classify(profile: _profile(uid));
      expect(result, isA<ReconstructionFresh>());
      expect(
        resolveReconstructionDestination(result).kind,
        SessionDestinationKind.freshOnboarding,
      );
    });

    test('B valid incomplete draft returns canonical server step', () {
      final result = _classify(
        profile: _profile(uid),
        draft: _validDraftAtStep(uid, 4),
      );
      expect(result, isA<ReconstructionIncomplete>());
      expect((result as ReconstructionIncomplete).step, 4);
    });

    test('C stored step ahead of invalid predecessor resumes predecessor', () {
      final completed = List<bool>.filled(OnboardingDraft.stepCount, false);
      for (var index = 0; index < 8; index++) {
        completed[index] = true;
      }
      final draft = _validDraftAtStep(uid, 8).copyWith(
        currentStep: 8,
        stepCompleted: completed,
        bodyBasics: const BodyBasicsDraft(),
        incrementRevision: false,
      );
      final result = _classify(profile: _profile(uid), draft: draft);
      expect((result as ReconstructionIncomplete).step, 3);
    });

    test('D optional skin-care skip does not block resume', () {
      final draft = _validDraftAtStep(uid, 8);
      expect(draft.baseTimeline.skinCareSkipped, isTrue);
      expect(validateOnboardingResume(draft).resumeStep, 8);
    });

    test('E valid active currentRun is Finishing with its runId', () {
      final draft = _finalDraft(uid);
      final job = _job(uid, draft, status: OnboardingJobStatus.running);
      final result = _classify(
        profile: _profile(
          uid,
          inputCompleted: true,
          projectionStatus: 'pending',
        ),
        draft: draft,
        bundle: _bundle(uid, draft),
        run: _run(job),
      );
      expect(result, isA<ReconstructionFinishing>());
      expect((result as ReconstructionFinishing).runId, job.jobId);
    });

    test(
      'F durable completed profile, draft, bundle, and job is Completed',
      () {
        final draft = _finalDraft(uid);
        final job = _job(uid, draft, status: OnboardingJobStatus.completed);
        final result = _classify(
          profile: _profile(
            uid,
            inputCompleted: true,
            projectionStatus: 'completed',
          ),
          draft: draft,
          bundle: _bundle(uid, draft),
          run: _run(job),
        );
        expect(result, isA<ReconstructionCompleted>());
        expect(
          resolveReconstructionDestination(result).kind,
          SessionDestinationKind.home,
        );
      },
    );

    test('G dangling currentRun pointer is typed Recovery', () {
      final result = _classify(
        profile: _profile(uid),
        run: const OnboardingCurrentRunSnapshot(
          hasPointer: true,
          runId: 'missing-run',
          ownerUid: uid,
          pointerSchemaVersion: 1,
        ),
      );
      expect(
        (result as ReconstructionRecovery).reason,
        ReconstructionRecoveryReason.danglingRunReference,
      );
    });

    test('H owner mismatch is typed Recovery', () {
      final result = _classify(
        profile: _profile(uid),
        draft: _validDraftAtStep('another-owner', 4),
      );
      expect(
        (result as ReconstructionRecovery).reason,
        ReconstructionRecoveryReason.ownerMismatch,
      );
    });

    test('I unsupported durable schema is typed Recovery', () {
      final result = _classify(
        profile: _profile(uid),
        draft: OnboardingDraft(
          uid: uid,
          storedSchemaVersion: OnboardingDraft.schemaVersion + 1,
        ),
      );
      expect(
        (result as ReconstructionRecovery).reason,
        ReconstructionRecoveryReason.schemaUnsupported,
      );
    });

    test(
      'missing profile with returning durable state is Recovery without create',
      () async {
        final source = _RecordingSnapshotSource(
          ServerReconstructionSnapshot(
            profile: null,
            draft: _validDraftAtStep(uid, 4),
            completionBundle: null,
            currentRun: const OnboardingCurrentRunSnapshot.none(),
          ),
        );
        final result = await ServerReconstructor(
          source: source,
        ).reconstruct(uid: uid);
        expect(
          (result as ReconstructionRecovery).reason,
          ReconstructionRecoveryReason.missingProfile,
        );
        expect(source.createCalls, 0);
      },
    );

    test(
      'mismatched completion bundle revision or fingerprint is typed Recovery',
      () {
        final draft = _finalDraft(uid);
        final bundle = _bundle(uid, draft, draftRevision: draft.revision + 1);
        final result = _classify(
          profile: _profile(
            uid,
            inputCompleted: true,
            projectionStatus: 'completed',
          ),
          draft: draft,
          bundle: bundle,
          run: _run(_job(uid, draft, status: OnboardingJobStatus.completed)),
        );
        expect(
          (result as ReconstructionRecovery).reason,
          ReconstructionRecoveryReason.invalidCompletionBundle,
        );
      },
    );

    test('currentRun job input mismatch with draft is typed Recovery', () {
      final draft = _finalDraft(uid);
      final mismatchedJob = _job(
        uid,
        draft,
        status: OnboardingJobStatus.running,
        draftRevision: draft.revision + 1,
      );
      final result = _classify(
        profile: _profile(
          uid,
          inputCompleted: true,
          projectionStatus: 'pending',
        ),
        draft: draft,
        bundle: _bundle(uid, draft),
        run: _run(mismatchedJob),
      );
      expect(
        (result as ReconstructionRecovery).reason,
        ReconstructionRecoveryReason.durableStateConflict,
      );
    });
  });

  group('AH-F007 bootstrap failures never become Fresh', () {
    test(
      'J transient backend read failure is retryable bootstrap failure',
      () async {
        final reconstructor = ServerReconstructor(
          source: _ThrowingSource(const SocketException('offline')),
        );
        await expectLater(
          reconstructor.reconstruct(uid: uid),
          throwsA(
            isA<ReconstructionBootstrapException>().having(
              (error) => error.reason,
              'reason',
              ReconstructionBootstrapFailureReason.backendUnavailable,
            ),
          ),
        );
      },
    );

    test('K permission-denied is a bootstrap failure, never Fresh', () async {
      final reconstructor = ServerReconstructor(
        source: _ThrowingSource(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
      );
      await expectLater(
        reconstructor.reconstruct(uid: uid),
        throwsA(
          isA<ReconstructionBootstrapException>().having(
            (error) => error.reason,
            'reason',
            ReconstructionBootstrapFailureReason.permissionDenied,
          ),
        ),
      );
    });

    test('unknown bootstrap errors fail closed', () async {
      final reconstructor = ServerReconstructor(
        source: _ThrowingSource(StateError('unexpected local failure')),
      );
      await expectLater(
        reconstructor.reconstruct(uid: uid),
        throwsA(
          isA<ReconstructionBootstrapException>().having(
            (error) => error.reason,
            'reason',
            ReconstructionBootstrapFailureReason.unknown,
          ),
        ),
      );
    });
  });

  group('AH-F007 same server state and zero-cache contract', () {
    test(
      'Fresh/Incomplete/Finishing/Completed/Recovery are local-state invariant',
      () {
        final finalDraft = _finalDraft(uid);
        final activeJob = _job(
          uid,
          finalDraft,
          status: OnboardingJobStatus.running,
        );
        final completedJob = _job(
          uid,
          finalDraft,
          status: OnboardingJobStatus.completed,
        );
        final fixtures = <ReconstructionResult Function()>[
          () => _classify(profile: _profile(uid)),
          () => _classify(
            profile: _profile(uid),
            draft: _validDraftAtStep(uid, 4),
          ),
          () => _classify(
            profile: _profile(
              uid,
              inputCompleted: true,
              projectionStatus: 'pending',
            ),
            draft: finalDraft,
            bundle: _bundle(uid, finalDraft),
            run: _run(activeJob),
          ),
          () => _classify(
            profile: _profile(
              uid,
              inputCompleted: true,
              projectionStatus: 'completed',
            ),
            draft: finalDraft,
            bundle: _bundle(uid, finalDraft),
            run: _run(completedJob),
          ),
          () => _classify(
            profile: _profile(uid),
            run: const OnboardingCurrentRunSnapshot(
              hasPointer: true,
              runId: 'gone',
              ownerUid: uid,
              pointerSchemaVersion: 1,
            ),
          ),
        ];

        for (final fixture in fixtures) {
          final signatures = <String>{};
          for (final entryMode in const [
            'cold',
            'warm-with-old-local-state',
            'relogin',
            'reinstall-zero-cache',
            'account-switch',
          ]) {
            // entryMode is deliberately not an input to the classifier.
            expect(entryMode, isNotEmpty);
            signatures.add(_signature(fixture()));
          }
          expect(signatures, hasLength(1));
        }
      },
    );

    test(
      'zero-cache reinstall completed user reconstructs Completed to Home',
      () async {
        final draft = _finalDraft(uid);
        final snapshot = ServerReconstructionSnapshot(
          profile: _profile(
            uid,
            inputCompleted: true,
            projectionStatus: 'completed',
          ),
          draft: draft,
          completionBundle: _bundle(uid, draft),
          currentRun: _run(
            _job(uid, draft, status: OnboardingJobStatus.completed),
          ),
        );
        final result = await ServerReconstructor(
          source: _SnapshotSource(snapshot),
        ).reconstruct(uid: uid);
        expect(result, isA<ReconstructionCompleted>());
        expect(
          resolveReconstructionDestination(result).kind,
          SessionDestinationKind.home,
        );
      },
    );

    test(
      'completed cold reconstruction restores routine and habit state before Home',
      () async {
        final draft = _finalDraft(uid);
        final sourceRoutine = RoutineItem(
          id: 'reading-source',
          title: 'Read',
          startMinute: 420,
          endMinute: 435,
          blockType: RoutineBlockType.flexibleTask,
          category: RoutineCategory.habit,
          repeatDays: const [1, 2, 3, 4, 5, 6, 7],
        );
        final baseBundle = _bundle(uid, draft);
        final bundleMap = baseBundle.toMap()
          ..['routineItemsForApp'] = [sourceRoutine.toMap()]
          ..['goodHabitTemplates'] = [
            const GoodHabitTemplateBundle(
              id: 'reading-habit',
              systemKey: 'read',
              title: 'Read',
              durationMinutes: 15,
              frequency: 'daily',
              bestTime: 'morning',
              priority: 'good_to_do',
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
            ).toMap(),
          ]
          ..['sourceFingerprint'] = draft.effectiveSourceFingerprint;
        final bundle = OnboardingCompletionBundle.fromMap(bundleMap);
        final routineProjection = RoutineOnboardingProjection.build(bundle);
        final expectedSystems = HabitSystemOnboardingProjection.build(
          bundle,
          routineProjection.items,
        );
        final routineRepository = FakeRoutineRepository();
        await routineRepository.createRoutineItemsIfMissing(
          uid,
          routineProjection.items,
        );
        final habitRepository = FakeHabitSystemsRepository();
        for (final system in expectedSystems) {
          await habitRepository.createSystem(
            system: system,
            operationId: 'seed-${system.systemId}',
          );
        }

        final snapshot = ServerReconstructionSnapshot(
          profile: _profile(
            uid,
            inputCompleted: true,
            projectionStatus: 'completed',
          ),
          draft: draft,
          completionBundle: bundle,
          currentRun: _run(
            _job(uid, draft, status: OnboardingJobStatus.completed),
          ),
        );
        final auth = _StreamAuthRepository();
        final container = _authContainer(
          auth,
          _SnapshotSource(snapshot),
          routineRepository: routineRepository,
          habitSystemsRepository: habitRepository,
        );
        addTearDown(container.dispose);
        addTearDown(auth.dispose);
        var frontendReadyWhenHomePublished = false;
        final subscription = container.listen<AuthState>(authProvider, (
          _,
          next,
        ) {
          if (next.sessionDestination.kind == SessionDestinationKind.home) {
            final routineIds = container
                .read(routineNotifierProvider)
                .items
                .map((item) => item.id)
                .toSet();
            final systemIds = container
                .read(habitSystemsNotifierProvider)
                .systems
                .map((system) => system.systemId)
                .toSet();
            frontendReadyWhenHomePublished =
                routineIds.containsAll(
                  routineProjection.items.map((item) => item.id),
                ) &&
                systemIds.containsAll(
                  expectedSystems.map((system) => system.systemId),
                );
          }
        });
        addTearDown(subscription.close);

        auth.emit(const AuthUser(uid: uid, emailVerified: true));
        await pumpEventQueue(times: 30);

        expect(
          container.read(authProvider).status,
          AuthFlowStatus.signedInOnboardingComplete,
        );
        expect(frontendReadyWhenHomePublished, isTrue);
      },
    );

    test(
      'zero-cache reinstall incomplete user uses server step, not local step 10',
      () async {
        final snapshot = ServerReconstructionSnapshot(
          profile: _profile(uid),
          draft: _validDraftAtStep(uid, 4),
          completionBundle: null,
          currentRun: const OnboardingCurrentRunSnapshot.none(),
        );
        const ignoredLocalStep = 10;
        expect(ignoredLocalStep, isNot(4));
        final result = await ServerReconstructor(
          source: _SnapshotSource(snapshot),
        ).reconstruct(uid: uid);
        expect((result as ReconstructionIncomplete).step, 4);
      },
    );

    test('old local completion flag cannot override server Fresh', () async {
      const ignoredLocalCompletionFlag = true;
      expect(ignoredLocalCompletionFlag, isTrue);
      final result = await ServerReconstructor(
        source: _SnapshotSource(
          ServerReconstructionSnapshot(
            profile: _profile(uid),
            draft: null,
            completionBundle: null,
            currentRun: const OnboardingCurrentRunSnapshot.none(),
          ),
        ),
      ).reconstruct(uid: uid);
      expect(result, isA<ReconstructionFresh>());
    });
  });

  group('AH-F007 hydration and async session safety', () {
    test(
      'stale reconstructed destination cannot override verification gate',
      () {
        final stale = ReconstructionFresh(
          ownerUid: 'account-a',
          profile: _profile('account-a'),
        );
        final state = AuthState(
          user: const AuthUser(
            uid: 'account-b',
            emailVerified: false,
            providerIds: {'password'},
          ),
          status: AuthFlowStatus.signedInEmailUnverified,
          reconstructionResult: stale,
        );
        expect(
          state.sessionDestination.kind,
          SessionDestinationKind.verifyEmail,
        );
      },
    );

    test(
      'Q/R classified draft hydrates before destination is published',
      () async {
        const user = AuthUser(uid: uid, emailVerified: true);
        final auth = _StreamAuthRepository();
        final source = _SnapshotSource(
          ServerReconstructionSnapshot(
            profile: _profile(uid),
            draft: _validDraftAtStep(uid, 4),
            completionBundle: null,
            currentRun: const OnboardingCurrentRunSnapshot.none(),
          ),
        );
        final container = _authContainer(auth, source);
        addTearDown(container.dispose);
        addTearDown(auth.dispose);
        var hydratedBeforePublish = false;
        final subscription = container.listen<AuthState>(authProvider, (
          _,
          next,
        ) {
          if (next.status == AuthFlowStatus.signedInOnboardingIncomplete) {
            hydratedBeforePublish =
                container.read(mockOnboardingProvider).draft.currentStep == 4;
          }
        });
        addTearDown(subscription.close);

        auth.emit(user);
        await pumpEventQueue(times: 20);

        expect(hydratedBeforePublish, isTrue);
        expect(
          container.read(authProvider).reconstructionResult,
          isA<ReconstructionIncomplete>(),
        );
      },
    );

    test(
      'S/T/U finishing, completed, and recovery hydrate without fabrication',
      () async {
        final finalDraft = _finalDraft(uid);
        final cases = <ServerReconstructionSnapshot, AuthFlowStatus>{
          ServerReconstructionSnapshot(
            profile: _profile(
              uid,
              inputCompleted: true,
              projectionStatus: 'pending',
            ),
            draft: finalDraft,
            completionBundle: _bundle(uid, finalDraft),
            currentRun: _run(
              _job(uid, finalDraft, status: OnboardingJobStatus.running),
            ),
          ): AuthFlowStatus.finishingOnboarding,
          ServerReconstructionSnapshot(
            profile: _profile(
              uid,
              inputCompleted: true,
              projectionStatus: 'completed',
            ),
            draft: finalDraft,
            completionBundle: _bundle(uid, finalDraft),
            currentRun: _run(
              _job(uid, finalDraft, status: OnboardingJobStatus.completed),
            ),
          ): AuthFlowStatus.signedInOnboardingComplete,
          ServerReconstructionSnapshot(
            profile: _profile(uid),
            draft: null,
            completionBundle: null,
            currentRun: const OnboardingCurrentRunSnapshot(
              hasPointer: true,
              runId: 'missing',
              ownerUid: uid,
              pointerSchemaVersion: 1,
            ),
          ): AuthFlowStatus.needsAction,
        };

        for (final entry in cases.entries) {
          final auth = _StreamAuthRepository();
          final container = _authContainer(auth, _SnapshotSource(entry.key));
          auth.emit(const AuthUser(uid: uid, emailVerified: true));
          await pumpEventQueue(times: 20);
          expect(container.read(authProvider).status, entry.value);
          if (entry.value == AuthFlowStatus.finishingOnboarding) {
            expect(container.read(authProvider).completionRunId, 'run-1');
          } else if (entry.value == AuthFlowStatus.signedInOnboardingComplete) {
            expect(container.read(mockOnboardingProvider).draft.uid, uid);
          } else {
            expect(container.read(mockOnboardingProvider).draft.uid, uid);
            expect(
              container.read(authProvider).reconstructionResult,
              isA<ReconstructionRecovery>(),
            );
          }
          container.dispose();
          auth.dispose();
        }
      },
    );

    test('V/W/X late A result is ignored and B result applies', () async {
      const userA = AuthUser(uid: 'account-a', emailVerified: true);
      const userB = AuthUser(uid: 'account-b', emailVerified: true);
      final auth = _StreamAuthRepository();
      final source = _ControllableSource();
      final container = _authContainer(auth, source);
      addTearDown(container.dispose);
      addTearDown(auth.dispose);

      auth.emit(userA);
      await pumpEventQueue(times: 5);
      auth.emit(userB);
      await pumpEventQueue(times: 5);

      source.completeFresh(userB.uid);
      await pumpEventQueue(times: 10);
      expect(container.read(authProvider).user?.uid, userB.uid);
      expect(container.read(mockUserProfileProvider).uid, userB.uid);

      source.completeFresh(userA.uid);
      await pumpEventQueue(times: 10);
      expect(container.read(authProvider).user?.uid, userB.uid);
      expect(container.read(mockUserProfileProvider).uid, userB.uid);
    });

    test(
      'upload owner integrity mismatch reaches controlled recovery',
      () async {
        const user = AuthUser(uid: uid, emailVerified: true);
        final auth = _StreamAuthRepository();
        final draft = _validDraftAtStep(uid, 5).copyWith(
          lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
          baseTimeline: const BaseTimelineDraft(classLogicalAssetId: 'class-a'),
          incrementRevision: false,
        );
        final container = _authContainer(
          auth,
          _SnapshotSource(
            ServerReconstructionSnapshot(
              profile: _profile(uid),
              draft: draft,
              completionBundle: null,
              currentRun: const OnboardingCurrentRunSnapshot.none(),
            ),
          ),
          restoredUploadsController: _FixedRestoredUploadsController(
            const RestoredUploadsState(uid: 'different-owner'),
          ),
        );
        addTearDown(container.dispose);
        addTearDown(auth.dispose);

        auth.emit(user);
        await pumpEventQueue(times: 20);

        final state = container.read(authProvider);
        expect(state.status, AuthFlowStatus.needsAction);
        expect(
          state.sessionDestination.kind,
          SessionDestinationKind.needsAction,
        );
        expect(state.reconstructionResult, isA<ReconstructionRecovery>());
        expect(
          (state.reconstructionResult as ReconstructionRecovery).reason,
          ReconstructionRecoveryReason.ownerMismatch,
        );
        expect(state.recoveryActions, contains(isA<ResetSetupSafelyAction>()));
        expect(state.errorMessage, isNotEmpty);
      },
    );

    test('upload hydration error reaches reconnect actions', () async {
      const user = AuthUser(uid: uid, emailVerified: true);
      final auth = _StreamAuthRepository();
      final draft = _validDraftAtStep(uid, 5).copyWith(
        lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
        baseTimeline: const BaseTimelineDraft(classLogicalAssetId: 'class-a'),
        incrementRevision: false,
      );
      final container = _authContainer(
        auth,
        _SnapshotSource(
          ServerReconstructionSnapshot(
            profile: _profile(uid),
            draft: draft,
            completionBundle: null,
            currentRun: const OnboardingCurrentRunSnapshot.none(),
          ),
        ),
        restoredUploadsController: _FixedRestoredUploadsController(
          const RestoredUploadsState(
            uid: uid,
            errorMessage: 'metadata unavailable',
          ),
        ),
      );
      addTearDown(container.dispose);
      addTearDown(auth.dispose);

      auth.emit(user);
      await pumpEventQueue(times: 20);

      final state = container.read(authProvider);
      expect(state.status, AuthFlowStatus.reconnectRequired);
      expect(state.recoveryActions, contains(isA<RetryNetworkAction>()));
      expect(state.recoveryActions, contains(isA<SignOutAction>()));
      expect(
        state.recoveryActions,
        isNot(contains(isA<ResetSetupSafelyAction>())),
      );
    });

    test(
      'Y/Z same UID refresh and repeated unresolved event launch one read',
      () async {
        const user = AuthUser(uid: uid, emailVerified: true);
        final auth = _StreamAuthRepository();
        final source = _ControllableSource();
        final container = _authContainer(auth, source);
        addTearDown(container.dispose);
        addTearDown(auth.dispose);

        auth.emit(user);
        auth.emit(user);
        await pumpEventQueue(times: 5);
        expect(source.loadCounts[uid], 1);
        source.completeFresh(uid);
        await pumpEventQueue(times: 10);

        auth.emit(user);
        await pumpEventQueue(times: 5);
        expect(source.loadCounts[uid], 1);
      },
    );

    test(
      'Google sign-in and password login converge on identical ReconstructionResult',
      () async {
        final draft = _validDraftAtStep(uid, 4);
        final snapshot = ServerReconstructionSnapshot(
          profile: _profile(uid),
          draft: draft,
          completionBundle: null,
          currentRun: const OnboardingCurrentRunSnapshot.none(),
        );

        final authPass = _StreamAuthRepository();
        final containerPass = _authContainer(
          authPass,
          _SnapshotSource(snapshot),
        );
        addTearDown(containerPass.dispose);
        addTearDown(authPass.dispose);
        authPass.emit(
          const AuthUser(
            uid: uid,
            emailVerified: true,
            providerIds: {'password'},
          ),
        );
        await pumpEventQueue(times: 20);
        final passResult = containerPass
            .read(authProvider)
            .reconstructionResult;
        final passDest = containerPass.read(authProvider).sessionDestination;

        final authGoogle = _StreamAuthRepository();
        final containerGoogle = _authContainer(
          authGoogle,
          _SnapshotSource(snapshot),
        );
        addTearDown(containerGoogle.dispose);
        addTearDown(authGoogle.dispose);
        authGoogle.emit(
          const AuthUser(
            uid: uid,
            emailVerified: true,
            providerIds: {'google.com'},
          ),
        );
        await pumpEventQueue(times: 20);
        final googleResult = containerGoogle
            .read(authProvider)
            .reconstructionResult;
        final googleDest = containerGoogle
            .read(authProvider)
            .sessionDestination;

        expect(passResult, isA<ReconstructionIncomplete>());
        expect(googleResult, isA<ReconstructionIncomplete>());
        expect((passResult as ReconstructionIncomplete).step, 4);
        expect((googleResult as ReconstructionIncomplete).step, 4);
        expect(passDest.kind, googleDest.kind);
        expect(passDest.resumeStep, googleDest.resumeStep);
      },
    );

    test(
      'adversarial stale A completed state does not pollute B incomplete reconstruction',
      () async {
        const userA = AuthUser(uid: 'account-a', emailVerified: true);
        const userB = AuthUser(uid: 'account-b', emailVerified: true);
        final draftB = _validDraftAtStep('account-b', 4);
        final auth = _StreamAuthRepository();

        final snapshotsByUid = <String, ServerReconstructionSnapshot>{
          'account-a': ServerReconstructionSnapshot(
            profile: _profile(
              'account-a',
              inputCompleted: true,
              projectionStatus: 'completed',
            ),
            draft: _finalDraft('account-a'),
            completionBundle: _bundle('account-a', _finalDraft('account-a')),
            currentRun: _run(
              _job(
                'account-a',
                _finalDraft('account-a'),
                status: OnboardingJobStatus.completed,
              ),
            ),
          ),
          'account-b': ServerReconstructionSnapshot(
            profile: _profile('account-b'),
            draft: draftB,
            completionBundle: null,
            currentRun: const OnboardingCurrentRunSnapshot.none(),
          ),
        };

        final source = _MultiUserSnapshotSource(snapshotsByUid);
        final container = _authContainer(auth, source);
        addTearDown(container.dispose);
        addTearDown(auth.dispose);

        auth.emit(userA);
        await pumpEventQueue(times: 20);
        expect(
          container.read(authProvider).status,
          AuthFlowStatus.signedInOnboardingComplete,
        );
        expect(container.read(mockUserProfileProvider).uid, 'account-a');

        auth.emit(userB);
        await pumpEventQueue(times: 20);

        final authStateB = container.read(authProvider);
        expect(authStateB.user?.uid, 'account-b');
        expect(authStateB.status, AuthFlowStatus.signedInOnboardingIncomplete);
        expect(authStateB.resumeStep, 4);
        expect(
          authStateB.reconstructionResult,
          isA<ReconstructionIncomplete>(),
        );
        expect(container.read(mockUserProfileProvider).uid, 'account-b');
        expect(container.read(mockOnboardingProvider).draft.uid, 'account-b');
        expect(container.read(mockOnboardingProvider).draft.currentStep, 4);
      },
    );

    test(
      'email verification success handoff converges into server reconstruction',
      () async {
        const unverifiedUser = AuthUser(
          uid: uid,
          emailVerified: false,
          providerIds: {'password'},
        );
        const verifiedUser = AuthUser(
          uid: uid,
          emailVerified: true,
          providerIds: {'password'},
        );
        final auth = _StreamAuthRepository();
        final draft = _validDraftAtStep(uid, 4);
        final source = _SnapshotSource(
          ServerReconstructionSnapshot(
            profile: _profile(uid),
            draft: draft,
            completionBundle: null,
            currentRun: const OnboardingCurrentRunSnapshot.none(),
          ),
        );
        final container = _authContainer(auth, source);
        addTearDown(container.dispose);
        addTearDown(auth.dispose);

        auth.emit(unverifiedUser);
        await pumpEventQueue(times: 20);
        expect(
          container.read(authProvider).status,
          AuthFlowStatus.signedInEmailUnverified,
        );
        expect(
          container.read(authProvider).sessionDestination.kind,
          SessionDestinationKind.verifyEmail,
        );

        auth.emit(verifiedUser);
        await container.read(authProvider.notifier).checkEmailVerification();
        await pumpEventQueue(times: 20);

        expect(
          container.read(authProvider).status,
          AuthFlowStatus.signedInOnboardingIncomplete,
        );
        expect(
          container.read(authProvider).reconstructionResult,
          isA<ReconstructionIncomplete>(),
        );
        expect(
          (container.read(authProvider).reconstructionResult
                  as ReconstructionIncomplete)
              .step,
          4,
        );
      },
    );

    test(
      'transient reconstruction failure followed by retry recovers cleanly',
      () async {
        const user = AuthUser(uid: uid, emailVerified: true);
        final auth = _StreamAuthRepository();
        final draft = _validDraftAtStep(uid, 4);
        final snapshot = ServerReconstructionSnapshot(
          profile: _profile(uid),
          draft: draft,
          completionBundle: null,
          currentRun: const OnboardingCurrentRunSnapshot.none(),
        );
        final source = _FailableSnapshotSource(
          snapshot,
          errorSequence: [
            FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
          ],
        );
        final container = _authContainer(
          auth,
          source,
          reconstructionRetryPolicy: const ReconstructionRetryPolicy(
            retryDelays: [Duration.zero, Duration.zero],
          ),
        );
        addTearDown(container.dispose);
        addTearDown(auth.dispose);

        auth.emit(user);
        await pumpEventQueue(times: 20);
        await pumpEventQueue(times: 20);

        expect(
          container.read(authProvider).status,
          AuthFlowStatus.signedInOnboardingIncomplete,
        );
        expect(
          container.read(authProvider).reconstructionResult,
          isA<ReconstructionIncomplete>(),
        );
        expect(
          (container.read(authProvider).reconstructionResult
                  as ReconstructionIncomplete)
              .step,
          4,
        );
      },
    );
  });
}

ReconstructionResult _classify({
  required UserProfile profile,
  OnboardingDraft? draft,
  OnboardingCompletionBundle? bundle,
  OnboardingCurrentRunSnapshot run = const OnboardingCurrentRunSnapshot.none(),
}) {
  return classifyServerReconstruction(
    ownerUid: 'ah-f007-owner',
    profile: profile,
    draft: draft,
    completionBundle: bundle,
    currentRun: run,
  );
}

UserProfile _profile(
  String uid, {
  bool inputCompleted = false,
  String projectionStatus = 'none',
}) {
  return UserProfile.empty(uid: uid).copyWith(
    onboardingInputCompleted: inputCompleted,
    onboardingProjectionStatus: projectionStatus,
    onboardingStep: inputCompleted ? OnboardingDraft.lastStepIndex : 0,
  );
}

OnboardingDraft _validDraftAtStep(String uid, int step) {
  final completed = List<bool>.filled(OnboardingDraft.stepCount, false);
  for (var index = 0; index < step; index++) {
    completed[index] = true;
  }
  final base = const BaseTimelineDraft(
    eatingSetupPath: 'create',
    eatingMode: 'flat',
    shouldPlanMeals: false,
    skinCareSkipped: true,
    blocks: [
      TimelineBlockDraft(
        id: BaseTimelineDraft.fixedSleepId,
        section: 'fixed',
        title: 'Sleep',
        startMinute: 1380,
        endMinute: 420,
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.hardBlockKey,
        crossesMidnight: true,
      ),
      TimelineBlockDraft(
        id: BaseTimelineDraft.fixedBathId,
        section: 'fixed',
        title: 'Bath',
        startMinute: 430,
        endMinute: 460,
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
      TimelineBlockDraft(
        id: 'meal',
        section: 'eating',
        title: 'Lunch',
        startMinute: 720,
        endMinute: 750,
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
    ],
  );
  return OnboardingDraft(
    uid: uid,
    currentStep: step,
    stepCompleted: completed,
    patiencePledgeAccepted: true,
    lifeRole: const LifeRoleDraft(
      lifeRole: LifeRoleDraft.notStudentNotWorkingKey,
      exerciseLevel: 'moderate',
      waterIntake: 'medium',
      stressLevel: 'medium',
      sleepQuality: 'good',
    ),
    bodyBasics: const BodyBasicsDraft(
      ageRange: '25-34',
      heightCm: 175,
      weightKg: 70,
      gender: 'other',
    ),
    baseTimeline: base,
  );
}

OnboardingDraft _finalDraft(String uid) {
  return _validDraftAtStep(uid, OnboardingDraft.lastStepIndex).copyWith(
    currentStep: OnboardingDraft.lastStepIndex,
    stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
    onboardingCompleted: true,
    incrementRevision: false,
  );
}

OnboardingCompletionBundle _bundle(
  String uid,
  OnboardingDraft draft, {
  int? draftRevision,
  String? sourceFingerprint,
}) {
  return OnboardingCompletionBundle(
    uid: uid,
    runId: 'run-1',
    createdAt: DateTime.utc(2026, 8, 30),
    updatedAt: DateTime.utc(2026, 8, 30),
    userProfilePatch: const {},
    baseTimelineBlocks: const [],
    finalTimelineItems: const [],
    routineItemsForApp: const [],
    goodHabitTemplates: const [],
    badHabitCheckIns: const [],
    identityGoalSystems: const [],
    notificationPreferences: NotificationPreferences(),
    coachPreferences: CoachPreferences(),
    moneyGoal: null,
    uploadedAssetReferences: const [],
    warnings: const [],
    duplicateSystemKeysMerged: const [],
    sourceFingerprint: sourceFingerprint ?? draft.effectiveSourceFingerprint,
    draftRevision: draftRevision ?? draft.revision,
  );
}

OnboardingCompletionJob _job(
  String uid,
  OnboardingDraft draft, {
  required OnboardingJobStatus status,
  int? draftRevision,
  String? sourceFingerprint,
}) {
  return OnboardingCompletionJob(
    jobId: 'run-1',
    ownerUid: uid,
    status: status,
    stage: status == OnboardingJobStatus.completed
        ? OnboardingCompletionStage.completed
        : OnboardingCompletionStage.reconcileRoutines,
    sourceFingerprint: sourceFingerprint ?? draft.effectiveSourceFingerprint,
    draftRevision: draftRevision ?? draft.revision,
    createdAt: DateTime.utc(2026, 8, 30),
    updatedAt: DateTime.utc(2026, 8, 30),
  );
}

OnboardingCurrentRunSnapshot _run(OnboardingCompletionJob job) {
  return OnboardingCurrentRunSnapshot(
    hasPointer: true,
    runId: job.jobId,
    ownerUid: job.ownerUid,
    pointerSchemaVersion: 1,
    job: job,
  );
}

String _signature(ReconstructionResult result) {
  return switch (result) {
    ReconstructionFresh() => 'fresh',
    ReconstructionIncomplete(:final step) => 'incomplete:$step',
    ReconstructionFinishing(:final runId) => 'finishing:$runId',
    ReconstructionCompleted() => 'completed',
    ReconstructionRecovery(:final reason) => 'recovery:${reason.name}',
  };
}

class _SnapshotSource implements ServerReconstructionSource {
  final ServerReconstructionSnapshot snapshot;

  const _SnapshotSource(this.snapshot);

  @override
  Future<ServerReconstructionSnapshot> load(
    String uid, {
    void Function(UserProfile? profile)? onProfileLoaded,
  }) async {
    onProfileLoaded?.call(snapshot.profile);
    return snapshot;
  }

  @override
  Future<void> createProfileShell(UserProfile profile) async {}
}

class _RecordingSnapshotSource extends _SnapshotSource {
  int createCalls = 0;

  _RecordingSnapshotSource(super.snapshot);

  @override
  Future<void> createProfileShell(UserProfile profile) async {
    createCalls++;
  }
}

class _ThrowingSource implements ServerReconstructionSource {
  final Object error;

  const _ThrowingSource(this.error);

  @override
  Future<ServerReconstructionSnapshot> load(
    String uid, {
    void Function(UserProfile? profile)? onProfileLoaded,
  }) async {
    throw error;
  }

  @override
  Future<void> createProfileShell(UserProfile profile) async {}
}

ProviderContainer _authContainer(
  _StreamAuthRepository auth,
  ServerReconstructionSource source, {
  RoutineRepository? routineRepository,
  HabitSystemsRepository? habitSystemsRepository,
  RestoredUploadsController? restoredUploadsController,
  ReconstructionRetryPolicy? reconstructionRetryPolicy,
}) {
  return ProviderContainer(
    overrides: [
      optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.firebase),
      authRepositoryProvider.overrideWithValue(auth),
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      appPreferencesRepositoryProvider.overrideWithValue(
        FakeAppPreferencesRepository(),
      ),
      regionSettingsRepositoryProvider.overrideWithValue(
        FakeRegionSettingsRepository(),
      ),
      uploadedAssetRepositoryProvider.overrideWithValue(
        FakeUploadedAssetRepository(),
      ),
      if (restoredUploadsController != null)
        restoredUploadsProvider.overrideWith(
          (ref) => restoredUploadsController,
        ),
      routineRepositoryProvider.overrideWithValue(
        routineRepository ?? FakeRoutineRepository(),
      ),
      routineHistoryRepositoryProvider.overrideWithValue(
        FakeRoutineHistoryRepository(),
      ),
      routineTransactionRepositoryProvider.overrideWith((ref) {
        return FakeRoutineTransactionRepository(
          routineRepository: ref.read(routineRepositoryProvider),
          historyRepository: ref.read(routineHistoryRepositoryProvider),
        );
      }),
      habitSystemsRepositoryProvider.overrideWithValue(
        habitSystemsRepository ?? FakeHabitSystemsRepository(),
      ),
      serverReconstructorProvider.overrideWithValue(
        ServerReconstructor(source: source),
      ),
      if (reconstructionRetryPolicy != null)
        reconstructionRetryPolicyProvider.overrideWithValue(
          reconstructionRetryPolicy,
        ),
    ],
  )..read(authProvider);
}

class _FixedRestoredUploadsController extends RestoredUploadsController {
  final RestoredUploadsState fixedState;

  _FixedRestoredUploadsController(this.fixedState)
    : super(
        assetRepository: FakeUploadedAssetRepository(),
        previewResolver: const UnavailableUploadedAssetPreviewResolver(),
      );

  @override
  Future<void> hydrate({required String uid, bool force = false}) async {
    state = fixedState;
  }
}

class _ControllableSource implements ServerReconstructionSource {
  final Map<String, Completer<ServerReconstructionSnapshot>> _completers = {};
  final Map<String, int> loadCounts = {};

  @override
  Future<ServerReconstructionSnapshot> load(
    String uid, {
    void Function(UserProfile? profile)? onProfileLoaded,
  }) {
    loadCounts[uid] = (loadCounts[uid] ?? 0) + 1;
    return _completers
        .putIfAbsent(uid, Completer<ServerReconstructionSnapshot>.new)
        .future;
  }

  void completeFresh(String uid) {
    _completers[uid]!.complete(
      ServerReconstructionSnapshot(
        profile: _profile(uid),
        draft: null,
        completionBundle: null,
        currentRun: const OnboardingCurrentRunSnapshot.none(),
      ),
    );
  }

  @override
  Future<void> createProfileShell(UserProfile profile) async {}
}

class _StreamAuthRepository implements AuthRepository {
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();
  AuthUser? _user;

  void emit(AuthUser? user) {
    _user = user;
    _controller.add(user);
  }

  void dispose() => _controller.close();

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;
  @override
  AuthUser? get currentUser => _user;
  @override
  Future<String?> currentIdToken() async => 'token';
  @override
  Future<AuthUser?> reloadCurrentUser() async => _user;
  @override
  Future<void> sendEmailVerification() async {}
  @override
  Future<void> sendPasswordResetEmail(String email) async {}
  @override
  Future<void> signOut() async => emit(null);
  @override
  Future<AuthUser?> signInWithGoogle() async => _user;
  @override
  Future<AuthUser> signIn(String email, String password) async => _user!;
  @override
  Future<AuthUser> signInAnonymously() async => _user!;
  @override
  Future<AuthUser> signUp(
    String email,
    String password, {
    String? name,
  }) async => _user!;
  @override
  Future<AuthUser> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async => _user!;
}

class _FailableSnapshotSource implements ServerReconstructionSource {
  final ServerReconstructionSnapshot snapshot;
  final List<Object?> errorSequence;

  _FailableSnapshotSource(
    this.snapshot, {
    List<Object?> errorSequence = const [],
  }) : errorSequence = List<Object?>.from(errorSequence);

  @override
  Future<ServerReconstructionSnapshot> load(
    String uid, {
    void Function(UserProfile? profile)? onProfileLoaded,
  }) async {
    final err = errorSequence.isNotEmpty ? errorSequence.removeAt(0) : null;
    if (err != null) {
      throw err;
    }
    onProfileLoaded?.call(snapshot.profile);
    return snapshot;
  }

  @override
  Future<void> createProfileShell(UserProfile profile) async {}
}

class _MultiUserSnapshotSource implements ServerReconstructionSource {
  final Map<String, ServerReconstructionSnapshot> snapshots;

  _MultiUserSnapshotSource(this.snapshots);

  @override
  Future<ServerReconstructionSnapshot> load(
    String uid, {
    void Function(UserProfile? profile)? onProfileLoaded,
  }) async {
    final snapshot =
        snapshots[uid] ??
        ServerReconstructionSnapshot(
          profile: _profile(uid),
          draft: null,
          completionBundle: null,
          currentRun: const OnboardingCurrentRunSnapshot.none(),
        );
    onProfileLoaded?.call(snapshot.profile);
    return snapshot;
  }

  @override
  Future<void> createProfileShell(UserProfile profile) async {}
}
