import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/profile/models/profile_settings_models.dart';
import 'package:optivus/features/recovery/models/onboarding_recovery_models.dart';
import 'package:optivus/features/recovery/services/recovery_retry_controller.dart';
import 'package:optivus/models/habit_system_record.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/models/tracker_session_link.dart';
import 'package:optivus/models/user_model.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Challenger P46 M3.1: Onboarding Recovery State Transitions & Draft Handling',
    () {
      test(
        'RebuildBundleFromVerifiedDraftAction on incomplete draft NEVER sets onboardingCompleted: true',
        () async {
          final fakeAuthRepo = FakeAuthRepository();
          final fakeOnboardingRepo = FakeOnboardingRepository();
          final fakeProfileRepo = FakeProfileRepository();
          final container = ProviderContainer(
            overrides: [
              authRepositoryProvider.overrideWithValue(fakeAuthRepo),
              onboardingRepositoryProvider.overrideWithValue(
                fakeOnboardingRepo,
              ),
              profileRepositoryProvider.overrideWithValue(fakeProfileRepo),
            ],
          );
          addTearDown(container.dispose);

          const testUser = AuthUser(
            uid: 'user-incomplete-draft',
            email: 'incomplete@example.com',
            isAnonymous: false,
            emailVerified: true,
            providerIds: {'password'},
          );

          // Seed an incomplete draft with stepCompleted containing false
          final incompleteDraft = OnboardingDraft(
            uid: testUser.uid,
            currentStep: 3,
            stepCompleted: const [
              true,
              true,
              false,
              false,
              false,
              false,
              false,
              false,
              false,
              false,
              false,
              false,
              false,
              false,
              false,
            ],
            onboardingCompleted: false,
          );
          await fakeOnboardingRepo.saveDraft(incompleteDraft);

          container.read(authProvider.notifier).state = const AuthState(
            user: testUser,
            status: AuthFlowStatus.needsAction,
          );

          final notifier = container.read(authProvider.notifier);
          await notifier.executeRecoveryAction(
            const RebuildBundleFromVerifiedDraftAction(),
          );

          final authState = container.read(authProvider);
          final profile = container.read(userProfileProvider);

          expect(
            authState.status,
            equals(AuthFlowStatus.signedInOnboardingIncomplete),
          );
          expect(profile.onboardingCompleted, isFalse);
          expect(profile.onboardingInputCompleted, isFalse);
          expect(profile.onboardingStep, equals(0));

          final bundle = await fakeOnboardingRepo.fetchCompletionBundle(
            testUser.uid,
          );
          expect(bundle, isNull);
        },
      );

      test('ResumeOnboardingAction without a draft fails safely', () async {
        final fakeAuthRepo = FakeAuthRepository();
        final fakeOnboardingRepo = FakeOnboardingRepository();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            onboardingRepositoryProvider.overrideWithValue(fakeOnboardingRepo),
          ],
        );
        addTearDown(container.dispose);

        const testUser = AuthUser(
          uid: 'user-restart-action',
          email: 'restart@example.com',
          isAnonymous: false,
          emailVerified: true,
          providerIds: {'password'},
        );

        container.read(authProvider.notifier).state = const AuthState(
          user: testUser,
          status: AuthFlowStatus.needsAction,
        );

        final notifier = container.read(authProvider.notifier);
        await notifier.executeRecoveryAction(const ResumeOnboardingAction());

        final authState = container.read(authProvider);
        final profile = container.read(userProfileProvider);

        expect(authState.status, equals(AuthFlowStatus.needsAction));
        expect(profile.onboardingCompleted, isFalse);
        expect(profile.onboardingStep, equals(0));
      });

      test(
        'RebuildBundleFromVerifiedDraftAction when draft is missing fails safely',
        () async {
          final fakeAuthRepo = FakeAuthRepository();
          final fakeOnboardingRepo = FakeOnboardingRepository();
          final fakeProfileRepo = FakeProfileRepository();
          final container = ProviderContainer(
            overrides: [
              authRepositoryProvider.overrideWithValue(fakeAuthRepo),
              onboardingRepositoryProvider.overrideWithValue(
                fakeOnboardingRepo,
              ),
              profileRepositoryProvider.overrideWithValue(fakeProfileRepo),
            ],
          );
          addTearDown(container.dispose);

          const testUser = AuthUser(
            uid: 'user-missing-draft-and-profile',
            email: 'nodraft@example.com',
            isAnonymous: false,
            emailVerified: true,
            providerIds: {'password'},
          );

          container.read(authProvider.notifier).state = const AuthState(
            user: testUser,
            status: AuthFlowStatus.needsAction,
          );

          final notifier = container.read(authProvider.notifier);
          await notifier.executeRecoveryAction(
            const RebuildBundleFromVerifiedDraftAction(),
          );

          final authState = container.read(authProvider);
          final profile = container.read(userProfileProvider);

          expect(authState.status, equals(AuthFlowStatus.needsAction));
          expect(profile.onboardingCompleted, isFalse);
        },
      );

      test(
        'RebuildBundleFromVerifiedDraftAction rejects a malformed completed draft',
        () async {
          final fakeAuthRepo = FakeAuthRepository();
          final fakeOnboardingRepo = FakeOnboardingRepository();
          final container = ProviderContainer(
            overrides: [
              authRepositoryProvider.overrideWithValue(fakeAuthRepo),
              onboardingRepositoryProvider.overrideWithValue(
                fakeOnboardingRepo,
              ),
            ],
          );
          addTearDown(container.dispose);

          const testUser = AuthUser(
            uid: 'user-partial-draft-rebuild',
            email: 'partial@example.com',
            isAnonymous: false,
            emailVerified: true,
            providerIds: {'password'},
          );

          final partialDraft = OnboardingDraft(
            uid: testUser.uid,
            currentStep: 5,
            stepCompleted: const [
              true,
              true,
              true,
              true,
              true,
              false,
              false,
              false,
              false,
              false,
              false,
              false,
              false,
              false,
              false,
            ],
            onboardingCompleted: true, // Malformed flag
          );
          await fakeOnboardingRepo.saveDraft(partialDraft);

          container.read(authProvider.notifier).state = const AuthState(
            user: testUser,
            status: AuthFlowStatus.needsAction,
          );

          final notifier = container.read(authProvider.notifier);
          await notifier.executeRecoveryAction(
            const RebuildBundleFromVerifiedDraftAction(),
          );

          final authState = container.read(authProvider);
          final profile = container.read(userProfileProvider);

          expect(authState.status, equals(AuthFlowStatus.needsAction));
          expect(profile.onboardingCompleted, isFalse);

          final savedDraft = await fakeOnboardingRepo.fetchDraft(testUser.uid);
          expect(savedDraft?.onboardingCompleted, isTrue);
        },
      );

      test(
        'executeRecoveryAction at max attempts still fails closed without a draft',
        () async {
          final fakeAuthRepo = FakeAuthRepository();
          final fakeOnboardingRepo = FakeOnboardingRepository();
          final container = ProviderContainer(
            overrides: [
              authRepositoryProvider.overrideWithValue(fakeAuthRepo),
              onboardingRepositoryProvider.overrideWithValue(
                fakeOnboardingRepo,
              ),
            ],
          );
          addTearDown(container.dispose);

          const testUser = AuthUser(
            uid: 'user-max-attempts',
            email: 'maxattempts@example.com',
            isAnonymous: false,
            emailVerified: true,
            providerIds: {'password'},
          );

          container.read(authProvider.notifier).state = const AuthState(
            user: testUser,
            status: AuthFlowStatus.needsAction,
          );

          // Max out retry attempts
          final retryController = container.read(
            recoveryRetryControllerProvider.notifier,
          );
          for (var i = 0; i < 5; i++) {
            retryController.recordAttemptAndStartCooldown();
          }
          expect(
            container.read(recoveryRetryControllerProvider).maxAttemptsReached,
            isTrue,
          );

          final notifier = container.read(authProvider.notifier);
          await notifier.executeRecoveryAction(
            const RebuildBundleFromVerifiedDraftAction(),
          );

          final authState = container.read(authProvider);
          final profile = container.read(userProfileProvider);

          expect(authState.status, equals(AuthFlowStatus.needsAction));
          expect(profile.onboardingCompleted, isFalse);
        },
      );
    },
  );

  group('Challenger P46 M3.1: Auth Sign-Out & Account Switching Isolation', () {
    test(
      'Rapid sign-out during in-flight operations resets state to signedOut without leak',
      () async {
        final fakeAuthRepo = FakeAuthRepository();
        final fakeOnboardingRepo = FakeOnboardingRepository();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            onboardingRepositoryProvider.overrideWithValue(fakeOnboardingRepo),
          ],
        );
        addTearDown(container.dispose);

        const userA = AuthUser(
          uid: 'account-a',
          email: 'usera@example.com',
          isAnonymous: false,
          emailVerified: true,
          providerIds: {'password'},
        );

        final notifier = container.read(authProvider.notifier);

        // Start loading backend user state for User A
        notifier.state = const AuthState(
          user: userA,
          status: AuthFlowStatus.loadingBackendUser,
        );

        // Immediately trigger logout
        await notifier.logout();

        final finalState = container.read(authProvider);
        expect(finalState.status, equals(AuthFlowStatus.signedOut));
        expect(finalState.user, isNull);
      },
    );

    test(
      'Rapid Account Switching (User A -> User B) isolates state cleanly',
      () async {
        final fakeAuthRepo = FakeAuthRepository();
        final fakeOnboardingRepo = FakeOnboardingRepository();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            onboardingRepositoryProvider.overrideWithValue(fakeOnboardingRepo),
          ],
        );
        addTearDown(container.dispose);

        const userA = AuthUser(
          uid: 'account-a-switch',
          email: 'usera@example.com',
          isAnonymous: false,
          emailVerified: true,
          providerIds: {'password'},
        );

        const userB = AuthUser(
          uid: 'account-b-switch',
          email: 'userb@example.com',
          isAnonymous: false,
          emailVerified: true,
          providerIds: {'password'},
        );

        // Draft for User A
        final draftA = OnboardingDraft(
          uid: userA.uid,
          currentStep: 8,
          onboardingCompleted: false,
        );
        await fakeOnboardingRepo.saveDraft(draftA);

        // Draft for User B
        final draftB = OnboardingDraft(
          uid: userB.uid,
          currentStep: 2,
          onboardingCompleted: false,
        );
        await fakeOnboardingRepo.saveDraft(draftB);

        final notifier = container.read(authProvider.notifier);

        // Set state to User A
        notifier.state = const AuthState(
          user: userA,
          status: AuthFlowStatus.loadingBackendUser,
        );

        // Switch immediately to User B
        notifier.state = const AuthState(
          user: userB,
          status: AuthFlowStatus.signedInOnboardingIncomplete,
        );

        final currentProfile = container.read(userProfileProvider);
        expect(
          container.read(authProvider).user?.uid,
          equals('account-b-switch'),
        );
        expect(currentProfile.uid, isNot(equals('account-a-switch')));
      },
    );

    test(
      'In-flight async recovery action for User A is dropped when active user switches to User B',
      () async {
        final fakeAuthRepo = FakeAuthRepository();
        final fakeOnboardingRepo = DelayedOnboardingRepository();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            onboardingRepositoryProvider.overrideWithValue(fakeOnboardingRepo),
          ],
        );
        addTearDown(container.dispose);

        const userA = AuthUser(
          uid: 'user-a-late',
          email: 'usera@example.com',
          isAnonymous: false,
          emailVerified: true,
          providerIds: {'password'},
        );

        const userB = AuthUser(
          uid: 'user-b-active',
          email: 'userb@example.com',
          isAnonymous: false,
          emailVerified: true,
          providerIds: {'password'},
        );

        final notifier = container.read(authProvider.notifier);

        // Active user is User A in recovery state
        notifier.state = const AuthState(
          user: userA,
          status: AuthFlowStatus.needsAction,
        );

        // Start async recovery action for User A (which will hit fetchDraft delay)
        final recoveryFuture = notifier.executeRecoveryAction(
          const RebuildBundleFromVerifiedDraftAction(),
        );

        // Immediately switch active user to User B
        notifier.state = const AuthState(
          user: userB,
          status: AuthFlowStatus.signedInOnboardingComplete,
        );

        // Complete the delayed draft fetch
        fakeOnboardingRepo.completer.complete(
          OnboardingDraft(uid: userA.uid, currentStep: 0),
        );

        await recoveryFuture;

        final authState = container.read(authProvider);
        // State must remain intact as User B
        expect(authState.user?.uid, equals(userB.uid));
        expect(
          authState.status,
          equals(AuthFlowStatus.signedInOnboardingComplete),
        );
      },
    );

    test(
      '10-cycle rapid sign-in / sign-out / switch stress test maintains complete isolation',
      () async {
        final fakeAuthRepo = FakeAuthRepository();
        final fakeOnboardingRepo = FakeOnboardingRepository();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            onboardingRepositoryProvider.overrideWithValue(fakeOnboardingRepo),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(authProvider.notifier);

        for (var i = 0; i < 10; i++) {
          final user = AuthUser(
            uid: 'rapid-user-$i',
            email: 'rapid$i@example.com',
            isAnonymous: false,
            emailVerified: true,
            providerIds: {'password'},
          );
          notifier.state = AuthState(
            user: user,
            status: AuthFlowStatus.loadingBackendUser,
          );
          if (i % 2 == 0) {
            await notifier.logout();
          } else {
            notifier.state = AuthState(
              user: user,
              status: AuthFlowStatus.signedInOnboardingIncomplete,
            );
          }
        }

        final finalState = container.read(authProvider);
        expect(
          finalState.status,
          equals(AuthFlowStatus.signedInOnboardingIncomplete),
        );
        expect(finalState.user?.uid, equals('rapid-user-9'));
      },
    );
  });

  group(
    'Challenger P46 M3.1: Firestore Contract Boundary Limits & Serializer Robustness',
    () {
      test(
        'UserProfile.fromMap handles nulls, optional fields, and unexpected keys',
        () {
          final input = <String, dynamic>{
            'uid': 'u-123',
            'email': null,
            'displayName': null,
            'accountStatus': null,
            'createdAt': '2026-01-01T12:00:00.000Z',
            'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 2)),
            'onboardingCompleted': true,
            'unexpectedField': 99999,
            'height': 175.5,
            'weight': 70.0,
          };

          final profile = UserProfile.fromMap(input);
          expect(profile.uid, equals('u-123'));
          expect(profile.email, equals(''));
          expect(profile.displayName, equals(''));
          expect(profile.accountStatus, equals('active'));
          expect(profile.createdAt, equals(DateTime.utc(2026, 1, 1, 12, 0, 0)));
          expect(profile.updatedAt?.toUtc(), equals(DateTime.utc(2026, 1, 2)));
          expect(profile.onboardingInputCompleted, isTrue);
          expect(profile.height, equals(175.5));
          expect(profile.weight, equals(70.0));
        },
      );

      test(
        'UserModel.fromMap handles null/missing optional fields and unexpected keys',
        () {
          final input = <String, dynamic>{
            'id': 'um-456',
            'email': 'um@test.com',
            'displayName': null,
            'timezone': null,
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
            'unexpectedKey': 'extra',
          };

          final user = UserModel.fromMap(input);
          expect(user.uid, equals('um-456'));
          expect(user.email, equals('um@test.com'));
          expect(user.displayName, isNull);
          expect(user.onboardingCompleted, isFalse);
        },
      );

      test(
        'OnboardingDraft.fromMap handles missing steps, legacy step arrays, and corrupted sub-maps',
        () {
          final input = <String, dynamic>{
            'uid': 'draft-789',
            'currentStep': 99,
            'stepCompleted': [true, false],
            'lifeRole': 'corrupted_string_instead_of_map',
            'bodyBasics': <String, dynamic>{'heightCm': 180, 'weightKg': null},
            'unexpectedKey': {'nested': true},
          };

          final draft = OnboardingDraft.fromMap(input);
          expect(draft.uid, equals('draft-789'));
          expect(draft.stepCompleted.length, equals(OnboardingDraft.stepCount));
          expect(draft.stepCompleted[0], isTrue);
          expect(draft.stepCompleted[1], isFalse);
          expect(draft.bodyBasics.heightCm, equals(180.0));
        },
      );

      test(
        'RoutineItem.fromMap handles string/int timestamps, nulls, corrupted enum strings',
        () {
          final input = <String, dynamic>{
            'id': 'item-001',
            'userId': 'user-001',
            'title': 'Test Item',
            'startMinute': 60,
            'endMinute': 120,
            'blockType': 'INVALID_BLOCK_TYPE',
            'category': 'INVALID_CATEGORY',
            'source': null,
            'repeatDays': [1, 3, 5],
            'caloriesEstimate': 500,
            'createdAt': '2026-05-10T10:00:00.000Z',
            'allowedConflicts': [
              {
                'canonicalPairId': 'pair-1',
                'evaluatedDateKey': '2026-05-10',
                'conflictType': 'overlap',
                'scheduleFingerprint': 'fp-123',
              },
            ],
          };

          final item = RoutineItem.fromMap(input);
          expect(item.id, equals('item-001'));
          expect(item.blockType, equals(RoutineBlockType.flexibleTask));
          expect(item.category, equals(RoutineCategory.fixed));
          expect(item.source, equals(RoutineSource.manual));
          expect(item.repeatDays, equals([1, 3, 5]));
          expect(item.caloriesEstimate, equals(500.0));
          expect(item.allowedConflicts.length, equals(1));
          expect(item.allowedConflicts.first.canonicalPairId, equals('pair-1'));
        },
      );

      test(
        'HabitSystemRecord.fromMap handles Timestamp, int dates, and invalid enums',
        () {
          final input = <String, dynamic>{
            'systemId': 'sys-001',
            'ownerUid': 'user-123',
            'title': 'Daily Exercise',
            'category': 'INVALID_CAT',
            'systemType': 'INVALID_TYPE',
            'status': 'INVALID_STATUS',
            'linkedRoutineIds': ['r1', 'r2', ''],
            'createdAt': Timestamp.fromDate(DateTime.utc(2026, 3, 1)),
            'updatedAt': 1772409600000,
          };

          final record = HabitSystemRecord.fromMap(input);
          expect(record.systemId, equals('sys-001'));
          expect(record.ownerUid, equals('user-123'));
          expect(record.category, equals(RoutineCategory.habit));
          expect(record.systemType, equals(HabitSystemType.goodHabit));
          expect(record.status, equals(HabitSystemStatus.active));
          expect(record.linkedRoutineIds, equals(['r1', 'r2']));
          expect(record.createdAt, equals(DateTime.utc(2026, 3, 1)));
          expect(
            record.updatedAt,
            equals(
              DateTime.fromMillisecondsSinceEpoch(1772409600000, isUtc: true),
            ),
          );
        },
      );

      test(
        'OnboardingCompletionJob.fromMap handles null lists, unexpected keys, and invalid enums',
        () {
          final input = <String, dynamic>{
            'jobId': 'job-999',
            'uid': 'user-999',
            'status': 'invalid_status_str',
            'stage': 'invalid_stage_str',
            'stagesCompleted': {'stage1': true, 'stage2': false},
            'failedEntityIds': null,
            'createdAt': '2026-04-01T08:00:00.000Z',
          };

          final job = OnboardingCompletionJob.fromMap(input);
          expect(job.jobId, equals('job-999'));
          expect(job.status, equals(OnboardingJobStatus.pending));
          expect(job.stage, equals(OnboardingCompletionStage.init));
          expect(job.stagesCompleted['stage1'], isTrue);
          expect(job.failedEntityIds, isEmpty);
          expect(job.createdAt, equals(DateTime.utc(2026, 4, 1, 8, 0, 0)));
        },
      );

      test(
        'UserProfileSettings.fromMap handles empty and unexpected inputs',
        () {
          final input = <String, dynamic>{
            'name': 'Alice',
            'username': null,
            'customIdentityDisplay': null,
            'unexpected': 'extra',
          };

          final settings = UserProfileSettings.fromMap(input);
          expect(settings.name, equals('Alice'));
          expect(settings.username, equals(''));
          expect(settings.customIdentityDisplay, isFalse);
        },
      );

      test(
        'RegionSettings.fromMap handles missing/invalid enums and defaults safely',
        () {
          final input = <String, dynamic>{
            'userId': 'user-reg-1',
            'countryCode': 'US',
            'measurementSystem': 'INVALID_SYSTEM',
            'createdAt': '2026-06-01T00:00:00.000Z',
          };

          final settings = RegionSettings.fromMap(input);
          expect(settings.userId, equals('user-reg-1'));
          expect(settings.countryCode, equals('US'));
          expect(
            settings.measurementSystem,
            equals(MeasurementSystem.imperial),
          );
        },
      );

      test('TrackerSessionLink.fromMap handles null and missing fields', () {
        final input = <String, dynamic>{
          'routineTaskId': 'routine-1',
          'trackerType': null,
          'status': 'active',
        };

        final link = TrackerSessionLink.fromMap(input);
        expect(link.routineTaskId, equals('routine-1'));
        expect(link.trackerType, equals('none'));
        expect(link.status, equals('active'));
      });

      test(
        'RoutineOccurrenceRecord.fromMap handles nulls and invalid status',
        () {
          final input = <String, dynamic>{
            'id': 'occ-123',
            'ownerUid': 'u-occ-1',
            'routineItemId': 'ritem-1',
            'occurrenceDateKey': '2026-07-29',
            'status': 'INVALID_STATUS',
            'source': 'user',
            'action': 'complete',
            'operationKey': 'op-1',
            'createdAt': '2026-07-29T10:00:00.000Z',
            'updatedAt': '2026-07-29T10:00:00.000Z',
          };

          final occ = RoutineOccurrenceRecord.fromMap(input);
          expect(occ.id, equals('occ-123'));
          expect(occ.routineItemId, equals('ritem-1'));
          expect(occ.ownerUid, equals('u-occ-1'));
          expect(occ.status, equals(RoutineStatus.active));
        },
      );
    },
  );
}

class DelayedOnboardingRepository extends FakeOnboardingRepository {
  final completer = Completer<OnboardingDraft?>();

  @override
  Future<OnboardingDraft?> fetchDraft(String uid) {
    return completer.future;
  }
}
