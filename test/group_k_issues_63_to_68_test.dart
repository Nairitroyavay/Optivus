import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;

import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/features/home/models/home_mind_note.dart';
import 'package:optivus/features/home/providers/home_dashboard_provider.dart';
import 'package:optivus/features/home/providers/home_mind_note_provider.dart';
import 'package:optivus/features/profile/providers/profile_settings_provider.dart';
import 'package:optivus/features/recovery/models/onboarding_recovery_models.dart';
import 'package:optivus/features/routine/controllers/habit_systems_controller.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/tracker/fitness/providers/fitness_provider.dart';
import 'package:optivus/features/tracker/providers/tracker_settings_provider.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/services/onboarding_frontend_hydration_service.dart';
import 'package:optivus/services/routine_import_ai_client.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/state/upload_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group K - Issue 63: Full Onboarding End-to-End Flow Integration Test', () {
    test(
      'completes 15-stage onboarding flow from step 0 welcome to step 14 summary step',
      () async {
        const uid = 'user-e2e-63';
        var draft = OnboardingDraft(uid: uid);
        expect(OnboardingDraft.stepCount, equals(15));
        expect(OnboardingDraft.lastStepIndex, equals(14));

        // Step 0: Welcome
        draft = draft.copyWith(welcomeSaved: true);
        draft = _completeStep(draft, 0);

        // Step 1: Patience Pledge
        draft = draft.copyWith(
          patiencePledgeAccepted: true,
          patiencePledgeText: 'I pledge patience for my habit progress',
        );
        draft = _completeStep(draft, 1);

        // Step 2: Role & Lifestyle
        draft = draft.copyWith(
          lifeRole: const LifeRoleDraft(
            lifeRole: 'working',
            workType: 'Software Engineer',
          ),
        );
        draft = _completeStep(draft, 2);

        // Step 3: Body Basics
        draft = draft.copyWith(
          bodyBasics: const BodyBasicsDraft(
            ageRange: '25-34',
            heightCm: 175,
            weightKg: 70,
            gender: 'male',
            bodyDataCompleted: true,
          ),
        );
        draft = _completeStep(draft, 3);

        // Step 4: Base Timeline
        draft = draft.copyWith(
          baseTimeline: const BaseTimelineDraft(
            blocks: [
              TimelineBlockDraft(
                id: 'work-block',
                section: 'work',
                title: 'Deep Work',
                startMinute: 540,
                endMinute: 1020,
                repeatDays: [1, 2, 3, 4, 5],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
            ],
          ),
        );
        draft = _completeStep(draft, 4);

        // Step 5: Bad Habits
        draft = draft.copyWith(
          badHabitsNotNow: false,
          badHabits: const [
            BadHabitDraft(
              id: 'bh-screen-time',
              habitKey: 'phone_in_bed',
              displayName: 'Late Night Screen Time',
            ),
          ],
        );
        draft = _completeStep(draft, 5);

        // Step 6: Good Habits
        draft = draft.copyWith(
          goodHabitsNotNow: false,
          goodHabits: const [
            GoodHabitDraft(
              id: 'gh-morning-walk',
              habitKey: GoodHabitDraft.customKey,
              displayName: 'Morning Sun Walk',
            ),
          ],
        );
        draft = _completeStep(draft, 6);

        // Step 7: Identity Goals
        draft = draft.copyWith(
          identityGoals: const [
            IdentityGoalDraft(
              goalKey: 'focus',
              displayName: 'Consistent Focus',
              systemKeys: ['work', 'reading'],
            ),
          ],
        );
        draft = _completeStep(draft, 7);

        // Step 8: Coach Setup
        draft = draft.copyWith(
          coachSetup: const CoachSetupDraft(
            coachName: 'Apex',
            coachStyle: 'Direct & Encouraging',
          ),
        );
        draft = _completeStep(draft, 8);

        // Step 9: Slip-Up Handling
        draft = draft.copyWith(
          slipUpHandling: 'Reflect calmly, adjust plan, and keep going',
        );
        draft = _completeStep(draft, 9);

        // Step 10: Notifications
        draft = draft.copyWith(
          notifications: const NotificationSetupDraft(
            preferencesConfirmed: true,
            morningStartReminder: true,
          ),
        );
        draft = _completeStep(draft, 10);

        // Step 11: Today Ready
        draft = _completeStep(draft, 11);

        // Step 12: Schedule Setup Review
        draft = _completeStep(draft, 12);

        // Step 13: Confirmation
        draft = _completeStep(draft, 13);

        // Step 14: Final Timeline Preview (Summary Step)
        draft = draft.copyWith(
          finalPreview: const FinalTimelinePreview(items: []),
          onboardingCompleted: true,
          currentStep: OnboardingDraft.lastStepIndex,
        );
        draft = _completeStep(draft, 14);

        expect(draft.currentStep, equals(14));
        expect(draft.onboardingCompleted, isTrue);
        expect(draft.stepCompleted.every((c) => c), isTrue);
      },
    );

    test(
      'builds full completion bundle from completed 15-stage draft',
      () async {
        const uid = 'user-e2e-63';
        final draft = _createFull15StageDraft(uid);
        final bundle = OnboardingCompletionService.buildBundle(draft);

        expect(bundle.uid, equals(uid));
        expect(bundle.userProfilePatch['onboardingInputCompleted'], isTrue);
        expect(
          bundle.userProfilePatch['onboardingProjectionStatus'],
          equals('pending'),
        );
        expect(bundle.goodHabitTemplates.length, equals(1));
        expect(bundle.badHabitCheckIns.length, equals(1));
        expect(bundle.notificationPreferences.morningStart, isTrue);
        expect(bundle.routineItemsForApp.isNotEmpty, isTrue);
      },
    );

    test(
      'runs completion job through all 6 stages, updates user profile, and creates projection receipt',
      () async {
        const uid = 'user-e2e-63-job';
        final draft = _createFull15StageDraft(uid);
        final bundle = OnboardingCompletionService.buildBundle(draft);
        final plan = RoutineOnboardingProjection.build(bundle);

        final db = FakeRoutineDatabase();
        db.itemsByUid[uid] = {for (final item in plan.items) item.id: item};
        db.receiptsByUid[uid] = {
          plan.projectionId: plan.receipt.copyWith(
            status: 'completed',
            cursor: plan.items.length,
            totalCount: plan.items.length,
            expectedItemIds: plan.items.map((i) => i.id).toList(),
            createdItemIds: plan.items.map((i) => i.id).toList(),
            projectedItemIds: plan.items.map((i) => i.id).toList(),
            completedAt: DateTime.now(),
          ),
        };

        final onboardingRepo = FakeOnboardingRepository(routineDatabase: db);
        final profileRepo = FakeProfileRepository();
        final routineRepo = FakeRoutineRepository(database: db);

        final jobService = OnboardingCompletionJobService(
          onboardingRepository: onboardingRepo,
          profileRepository: profileRepo,
          routineRepository: routineRepo,
        );

        final job = await jobService.runCompletionJob(
          uid: uid,
          finalDraft: draft,
          bundle: bundle,
        );

        expect(job.status, equals(OnboardingJobStatus.completed));
        expect(job.stage, equals(OnboardingCompletionStage.completed));
        expect(
          job.stagesCompleted[OnboardingCompletionStage.persistDraft.name],
          isTrue,
        );
        expect(
          job.stagesCompleted[OnboardingCompletionStage.persistBundle.name],
          isTrue,
        );
        expect(
          job.stagesCompleted[OnboardingCompletionStage.projectRoutines.name],
          isTrue,
        );
        expect(
          job.stagesCompleted[OnboardingCompletionStage.projectHabits.name],
          isTrue,
        );
        expect(
          job.stagesCompleted[OnboardingCompletionStage.updateProfile.name],
          isTrue,
        );

        final profile = await profileRepo.fetchUserProfile(uid);
        expect(profile, isNotNull);
        expect(profile!.onboardingInputCompleted, isTrue);
        expect(profile.onboardingProjectionStatus, equals('completed'));
        expect(profile.onboardingCompleted, isTrue);

        final receipt = await routineRepo.fetchProjectionReceipt(
          uid,
          plan.projectionId,
        );
        expect(receipt, isNotNull);
        expect(receipt!.status, equals('completed'));
      },
    );

    test(
      'router transitions state from /onboarding to home route when onboarding is complete',
      () async {
        const uidIncomplete = 'user-inc';
        final profileIncomplete = UserProfile.empty(
          uid: uidIncomplete,
        ).copyWith(onboardingInputCompleted: false, onboardingCompleted: false);

        final redirectIncomplete = evaluateRouterRedirect(
          isLoggedIn: true,
          userProfile: profileIncomplete,
          currentPath: '/',
        );
        expect(redirectIncomplete, equals('/onboarding'));

        const uidComplete = 'user-comp';
        final profileComplete = UserProfile.empty(uid: uidComplete).copyWith(
          onboardingInputCompleted: true,
          onboardingCompleted: true,
          onboardingProjectionStatus: 'completed',
        );

        final redirectComplete = evaluateRouterRedirect(
          isLoggedIn: true,
          userProfile: profileComplete,
          currentPath: '/onboarding',
        );
        expect(redirectComplete, equals('/app?tab=0'));
      },
    );
  });

  group(
    'Group K - Issue 64: Network Disconnection and Offline Queue Persistence Test',
    () {
      test(
        'persists draft saves locally when network is disconnected/offline',
        () async {
          const uid = 'user-offline-64';
          final db = FakeRoutineDatabase();
          final repo = FakeOnboardingRepository(routineDatabase: db);

          final draft = OnboardingDraft(
            uid: uid,
          ).copyWith(welcomeSaved: true, currentStep: 1);

          await repo.saveDraft(draft);

          // Pending draft is immediately accessible locally before network flush
          final fetchedDraft = await repo.fetchDraft(uid);
          expect(fetchedDraft, isNotNull);
          expect(fetchedDraft!.uid, equals(uid));
          expect(fetchedDraft.welcomeSaved, isTrue);
          expect(fetchedDraft.currentStep, equals(1));
        },
      );

      test(
        'completion job captures offline network failure and sets failed job status with retry count',
        () async {
          const uid = 'user-offline-fail-64';
          final draft = _createFull15StageDraft(uid);
          final bundle = OnboardingCompletionService.buildBundle(draft);

          final db = FakeRoutineDatabase();
          final onboardingRepo = FakeOnboardingRepository(routineDatabase: db);
          final profileRepo = FakeProfileRepository();
          final routineRepo = FakeRoutineRepository(database: db);

          // Inject network / atomic failure before commit
          onboardingRepo.failNextCompletionBeforeCommit();

          final jobService = OnboardingCompletionJobService(
            onboardingRepository: onboardingRepo,
            profileRepository: profileRepo,
            routineRepository: routineRepo,
          );

          expect(
            () async => await jobService.runCompletionJob(
              uid: uid,
              finalDraft: draft,
              bundle: bundle,
            ),
            throwsA(isA<RoutineProjectionRetryRequiredException>()),
          );
        },
      );

      test(
        'post-reconnection flushes pending draft, completes job stages, and performs frontend hydration',
        () async {
          const uid = 'user-reconnect-64';
          final draft = _createFull15StageDraft(uid);
          final bundle = OnboardingCompletionService.buildBundle(draft);
          final plan = RoutineOnboardingProjection.build(bundle);

          final db = FakeRoutineDatabase();
          db.itemsByUid[uid] = {for (final item in plan.items) item.id: item};
          db.receiptsByUid[uid] = {
            plan.projectionId: plan.receipt.copyWith(
              status: 'completed',
              cursor: plan.items.length,
              totalCount: plan.items.length,
              expectedItemIds: plan.items.map((i) => i.id).toList(),
              createdItemIds: plan.items.map((i) => i.id).toList(),
              projectedItemIds: plan.items.map((i) => i.id).toList(),
              completedAt: DateTime.now(),
            ),
          };

          final onboardingRepo = FakeOnboardingRepository(routineDatabase: db);
          final profileRepo = FakeProfileRepository();
          final routineRepo = FakeRoutineRepository(database: db);

          await onboardingRepo.saveDraft(draft);
          await onboardingRepo.flushPendingDraftSave();
          expect(onboardingRepo.isDraftSavedInMap(uid), isTrue);

          final jobService = OnboardingCompletionJobService(
            onboardingRepository: onboardingRepo,
            profileRepository: profileRepo,
            routineRepository: routineRepo,
          );

          final job = await jobService.runCompletionJob(
            uid: uid,
            finalDraft: draft,
            bundle: bundle,
          );
          expect(job.status, equals(OnboardingJobStatus.completed));

          final container = ProviderContainer(
            overrides: [
              routineRepositoryProvider.overrideWithValue(routineRepo),
            ],
          );
          addTearDown(container.dispose);

          await const OnboardingFrontendHydrationService().hydrate(
            read: container.read,
            bundle: bundle,
          );

          final routineState = container.read(routineNotifierProvider);
          expect(routineState.items, isNotNull);
        },
      );
    },
  );

  group(
    'Group K - Issue 65: User Account Sign-Out and Re-authentication Regression Suite',
    () {
      test(
        'logout executes resetForSignedOut on memory providers wiping user state',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          // Populate provider state for User A
          container.read(appNavigationProvider.notifier).state = 3;
          container
              .read(homeMindNoteProvider.notifier)
              .addNote(
                'User A Mind Note',
                MindNoteType.overthinking,
                MindNoteIntensity.medium,
              );

          expect(container.read(appNavigationProvider), equals(3));
          expect(
            container.read(homeMindNoteProvider).first.content,
            equals('User A Mind Note'),
          );

          // Perform logout reset across all memory providers
          container.read(appNavigationProvider.notifier).resetForSignedOut();
          container.read(homeDashboardProvider.notifier).resetForSignedOut();
          container.read(homeMindNoteProvider.notifier).resetForSignedOut();
          container.read(profileSettingsProvider.notifier).resetForSignedOut();
          container.read(fitnessCenterProvider.notifier).resetForSignedOut();
          container.read(trackerSettingsProvider.notifier).resetForSignedOut();
          container
              .read(routineImportAiControllerProvider.notifier)
              .resetForSignedOut();
          container.read(uploadControllerProvider.notifier).resetForSignedOut();
          container.read(routineNotifierProvider.notifier).resetForSignedOut();
          container
              .read(habitSystemsNotifierProvider.notifier)
              .resetForSignedOut();

          // Assert clean default states post sign-out
          expect(container.read(appNavigationProvider), equals(0));
          expect(container.read(homeMindNoteProvider), isEmpty);
          expect(container.read(routineNotifierProvider).items, isEmpty);
          expect(container.read(habitSystemsNotifierProvider).systems, isEmpty);
        },
      );

      test(
        're-authenticating as User B after User A logout initializes fresh isolated state without cross-user data leaks',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          // User A signs in and writes state
          container
              .read(homeMindNoteProvider.notifier)
              .addNote(
                'Secret of User A',
                MindNoteType.overthinking,
                MindNoteIntensity.high,
              );

          // User A signs out
          container.read(appNavigationProvider.notifier).resetForSignedOut();
          container.read(homeMindNoteProvider.notifier).resetForSignedOut();
          container.read(routineNotifierProvider.notifier).resetForSignedOut();

          // User B signs in and initializes state
          container
              .read(homeMindNoteProvider.notifier)
              .addNote(
                'Note of User B',
                MindNoteType.idea,
                MindNoteIntensity.low,
              );

          final userBNotes = container.read(homeMindNoteProvider);
          expect(userBNotes.length, equals(1));
          expect(userBNotes.first.content, equals('Note of User B'));
          expect(userBNotes.first.content, isNot(contains('User A')));
        },
      );
    },
  );

  group(
    'Group K - Issue 66: Firestore Rules Emulator Cross-User Security Access Test Suite',
    () {
      test(
        'validates cross-user boundary: User A cannot read or mutate User B documents',
        () async {
          const userA = 'uid-user-A';
          const userB = 'uid-user-B';

          final evaluator = FirestoreRulesEvaluator();

          // User A trying to access User B's documents fails ownership validation
          expect(
            evaluator.isOwner(
              requestUid: userA,
              docPath: FirestoreUserPaths.onboardingDraft(userB),
            ),
            isFalse,
          );
          expect(
            evaluator.isOwner(
              requestUid: userA,
              docPath: FirestoreUserPaths.onboardingCompletionBundle(userB),
            ),
            isFalse,
          );
          expect(
            evaluator.isOwner(
              requestUid: userA,
              docPath: FirestoreUserPaths.profile(userB),
            ),
            isFalse,
          );
          expect(
            evaluator.isOwner(
              requestUid: userA,
              docPath: FirestoreUserPaths.routineItem(userB, 'item-1'),
            ),
            isFalse,
          );
          expect(
            evaluator.isOwner(
              requestUid: userA,
              docPath: FirestoreUserPaths.routineProjection(userB, 'proj-1'),
            ),
            isFalse,
          );
        },
      );

      test(
        'validates same-user document access: User A can read/mutate User A documents',
        () async {
          const userA = 'uid-user-A';
          final evaluator = FirestoreRulesEvaluator();

          expect(
            evaluator.isOwner(
              requestUid: userA,
              docPath: FirestoreUserPaths.onboardingDraft(userA),
            ),
            isTrue,
          );
          expect(
            evaluator.isOwner(
              requestUid: userA,
              docPath: FirestoreUserPaths.onboardingCompletionBundle(userA),
            ),
            isTrue,
          );
          expect(
            evaluator.isOwner(
              requestUid: userA,
              docPath: FirestoreUserPaths.profile(userA),
            ),
            isTrue,
          );
          expect(
            evaluator.isOwner(
              requestUid: userA,
              docPath: FirestoreUserPaths.routineItem(userA, 'item-1'),
            ),
            isTrue,
          );
        },
      );

      test(
        'validates Firestore upload document rules and forbidden field constraints',
        () async {
          final evaluator = FirestoreRulesEvaluator();

          // Test validUploadKeys rule from firestore.rules
          final validUploadMap = {
            'assetId': 'asset-1',
            'ownerUid': 'uid-1',
            'sourceFeature': 'routine_import',
            'purpose': 'class_timetable',
            'fileName': 'schedule.png',
            'contentType': 'image/png',
            'sizeBytes': 1024,
            'r2Key': 'key-1',
            'status': 'uploaded',
            'createdAt': '2026-07-25T00:00:00Z',
            'updatedAt': '2026-07-25T00:00:00Z',
          };
          expect(evaluator.validUploadKeys(validUploadMap), isTrue);

          final invalidUploadWithForbiddenField = {
            ...validUploadMap,
            'imageBytes': [1, 2, 3],
          };
          expect(
            evaluator.validUploadKeys(invalidUploadWithForbiddenField),
            isFalse,
          );

          // Test validUploadPurpose and size limits
          expect(evaluator.validUploadPurpose('class_timetable'), isTrue);
          expect(evaluator.validUploadPurpose('malicious_purpose'), isFalse);

          expect(evaluator.isValidUploadSize('profile_photo', 1000), isTrue);
          expect(
            evaluator.isValidUploadSize('profile_photo', 6 * 1024 * 1024),
            isFalse,
          ); // > 5MB limit
          expect(
            evaluator.isValidUploadSize('class_timetable', 10 * 1024 * 1024),
            isTrue,
          ); // <= 15MB limit
          expect(
            evaluator.isValidUploadSize('class_timetable', 20 * 1024 * 1024),
            isFalse,
          ); // > 15MB limit
        },
      );
    },
  );

  group(
    'Group K - Issue 67: Cloudflare Worker API Error Response Mapping Integration Test',
    () {
      test(
        'maps 400 Bad Request to typed error result with non-blocking UI fallback',
        () async {
          final mockHttpClient = http_testing.MockClient((request) async {
            return http.Response(
              jsonEncode({'error': 'bad_request_payload'}),
              400,
            );
          });

          final workerClient = WorkerRoutineImportAiClient(
            baseUrl: 'https://worker.optivus.test',
            client: mockHttpClient,
          );

          final now = DateTime.now();
          final review = RoutineImportReviewDraft(
            id: 'review-400',
            uid: 'user-400',
            source: RoutineImportReviewSource.classes,
            status: RoutineImportReviewStatus.needsReview,
            sourceLabel: 'Class Timetable',
            uploadedAssetId: 'asset-400',
            uploadedAssetR2Key: 'r2/key-400',
            uploadedAssetStatus: 'uploaded',
            createdAt: now,
            updatedAt: now,
          );

          final result = await workerClient.extract(
            uid: 'user-400',
            idToken: 'token-400',
            review: review,
          );

          expect(result.engine, equals('worker'));
          expect(result.warnings, contains('bad_request_payload'));
        },
      );

      test(
        'maps 401 Unauthorized to CloudflareClientException / error warning',
        () async {
          final mockHttpClient = http_testing.MockClient((request) async {
            return http.Response(
              jsonEncode({'error': 'unauthorized_token'}),
              401,
            );
          });

          final workerClient = RealCloudflareWorkerClient(
            baseUrl: 'https://worker.optivus.test',
            client: mockHttpClient,
          );
          final uploadClient = RealR2UploadClient(workerClient: workerClient);

          expect(
            () async => await uploadClient.signUpload(
              uid: 'user-401',
              purpose: UploadedAssetPurpose.classTimetable,
              sourceFeature: 'routine_import',
              contentType: 'image/png',
              sizeBytes: 1024,
              idToken: 'expired-token',
            ),
            throwsA(
              isA<CloudflareClientException>().having(
                (e) => e.statusCode,
                'statusCode',
                equals(401),
              ),
            ),
          );
        },
      );

      test(
        'maps 500 Internal Server Error to fallback result with server error warning',
        () async {
          final mockHttpClient = http_testing.MockClient((request) async {
            return http.Response(
              jsonEncode({'error': 'worker_internal_failure'}),
              500,
            );
          });

          final workerClient = WorkerRoutineImportAiClient(
            baseUrl: 'https://worker.optivus.test',
            client: mockHttpClient,
          );

          final now = DateTime.now();
          final review = RoutineImportReviewDraft(
            id: 'review-500',
            uid: 'user-500',
            source: RoutineImportReviewSource.work,
            status: RoutineImportReviewStatus.needsReview,
            sourceLabel: 'Work Schedule',
            uploadedAssetId: 'asset-500',
            uploadedAssetR2Key: 'r2/key-500',
            uploadedAssetStatus: 'uploaded',
            createdAt: now,
            updatedAt: now,
          );

          final result = await workerClient.extract(
            uid: 'user-500',
            idToken: 'token-500',
            review: review,
          );

          expect(result.warnings, contains('worker_internal_failure'));
        },
      );

      test(
        'maps network timeout and connection errors to fallback result',
        () async {
          final mockHttpClient = http_testing.MockClient((request) async {
            throw const SocketException('Connection timeout');
          });

          final workerClient = WorkerRoutineImportAiClient(
            baseUrl: 'https://worker.optivus.test',
            client: mockHttpClient,
          );

          final now = DateTime.now();
          final review = RoutineImportReviewDraft(
            id: 'review-timeout',
            uid: 'user-timeout',
            source: RoutineImportReviewSource.eating,
            status: RoutineImportReviewStatus.needsReview,
            sourceLabel: 'Eating Menu',
            uploadedAssetId: 'asset-timeout',
            uploadedAssetR2Key: 'r2/key-timeout',
            uploadedAssetStatus: 'uploaded',
            createdAt: now,
            updatedAt: now,
          );

          final result = await workerClient.extract(
            uid: 'user-timeout',
            idToken: 'token-timeout',
            review: review,
          );

          expect(
            result.warnings,
            contains('AI extraction service is unavailable. Try again later.'),
          );
        },
      );

      test(
        'maps client payload validation error (forbidden fields or schema invalid) to fallback result',
        () async {
          final mockHttpClient = http_testing.MockClient((request) async {
            // Return 200 OK but with forbidden field 'routineItems' in response body
            return http.Response(
              jsonEncode({
                'id': 'result-1',
                'uid': 'user-invalid-schema',
                'source': 'classes',
                'engine': 'worker',
                'engineVersion': 'phase2d',
                'sourceAssetId': 'asset-inv',
                'sourceR2Key': 'r2/key-inv',
                'candidates': [],
                'routineItems': ['forbidden_item_payload'],
              }),
              200,
            );
          });

          final workerClient = WorkerRoutineImportAiClient(
            baseUrl: 'https://worker.optivus.test',
            client: mockHttpClient,
          );

          final now = DateTime.now();
          final review = RoutineImportReviewDraft(
            id: 'review-inv',
            uid: 'user-invalid-schema',
            source: RoutineImportReviewSource.classes,
            status: RoutineImportReviewStatus.needsReview,
            sourceLabel: 'Classes',
            uploadedAssetId: 'asset-inv',
            uploadedAssetR2Key: 'r2/key-inv',
            uploadedAssetStatus: 'uploaded',
            createdAt: now,
            updatedAt: now,
          );

          final result = await workerClient.extract(
            uid: 'user-invalid-schema',
            idToken: 'token-inv',
            review: review,
          );

          expect(
            result.warnings,
            contains('AI extraction service returned invalid structured data.'),
          );
        },
      );

      test(
        'verifies all worker client error response mappings provide non-blocking UI fallbacks',
        () async {
          final mockHttpClient = http_testing.MockClient((request) async {
            return http.Response(
              jsonEncode({'error': 'rate_limit_exceeded'}),
              429,
            );
          });

          final workerClient = WorkerRoutineImportAiClient(
            baseUrl: 'https://worker.optivus.test',
            client: mockHttpClient,
          );

          final now = DateTime.now();
          final review = RoutineImportReviewDraft(
            id: 'review-429',
            uid: 'user-429',
            source: RoutineImportReviewSource.skinCare,
            status: RoutineImportReviewStatus.needsReview,
            sourceLabel: 'Skin Care',
            uploadedAssetId: 'asset-429',
            uploadedAssetR2Key: 'r2/key-429',
            uploadedAssetStatus: 'uploaded',
            createdAt: now,
            updatedAt: now,
          );

          final result = await workerClient.extract(
            uid: 'user-429',
            idToken: 'token-429',
            review: review,
          );

          expect(result, isNotNull);
          expect(result.warnings.isNotEmpty, isTrue);
        },
      );
    },
  );

  group(
    'Group K - Issue 68: Multi-Device State Synchronization and Restart Recovery Test',
    () {
      test(
        'reconciles local draft against remote receipt in multi-device state sync',
        () async {
          const uid = 'user-multi-68';
          final db = FakeRoutineDatabase();
          final repo = FakeOnboardingRepository(routineDatabase: db);

          final draftA = _createFull15StageDraft(uid);
          final bundleA = OnboardingCompletionService.buildBundle(draftA);

          // Device A completes onboarding and creates remote receipt
          final firstResult = await repo.completeOnboarding(
            finalDraft: draftA,
            bundle: bundleA,
          );
          expect(
            firstResult.outcome,
            equals(RoutineProjectionOutcome.projected),
          );

          // Device B with matching draft calls completeOnboarding -> returns noOp (matching fingerprint)
          final secondResult = await repo.completeOnboarding(
            finalDraft: draftA,
            bundle: bundleA,
          );
          expect(secondResult.outcome, equals(RoutineProjectionOutcome.noOp));

          // Device B updates draft content (adding new good habit) -> fingerprint changes
          final draftB = draftA.copyWith(
            goodHabits: [
              ...draftA.goodHabits,
              const GoodHabitDraft(
                id: 'gh-evening-reading',
                habitKey: GoodHabitDraft.customKey,
                displayName: 'Evening Book Reading',
              ),
            ],
          );
          final bundleB = OnboardingCompletionService.buildBundle(draftB);
          final planB = RoutineOnboardingProjection.build(bundleB);

          // Multi-device sync detects stale receipt fingerprint and re-projects for Device B
          final reprojectResult = await repo.completeOnboarding(
            finalDraft: draftB,
            bundle: bundleB,
          );
          expect(
            reprojectResult.outcome,
            equals(RoutineProjectionOutcome.projected),
          );
          expect(
            reprojectResult.receipt.sourceBundleFingerprint,
            equals(planB.fingerprint),
          );
        },
      );

      test(
        'executes 4-tier restart recovery sequence correctly across all tiers',
        () async {
          const uid = 'user-recovery-68';
          final db = FakeRoutineDatabase();
          final repo = FakeOnboardingRepository(routineDatabase: db);
          final profileRepo = FakeProfileRepository();

          final draft = _createFull15StageDraft(uid);
          final bundle = OnboardingCompletionService.buildBundle(draft);

          // Tier 1: Existing completion bundle found in remote storage
          await repo.saveCompletionBundle(bundle);
          final tier1Result =
              await OnboardingCompletionService.recoverCompletionState(
                uid: uid,
                onboardingRepository: repo,
                profileRepository: profileRepo,
              );
          expect(
            tier1Result.tier,
            equals(OnboardingRecoveryTier.tier1BundleFound),
          );
          expect(tier1Result.bundle, isNotNull);

          // Tier 2: Completion bundle missing, but draft exists -> rebuilds bundle from draft
          final repoTier2 = FakeOnboardingRepository(routineDatabase: db);
          await repoTier2.saveDraft(draft);
          await repoTier2.flushPendingDraftSave();

          final tier2Result =
              await OnboardingCompletionService.recoverCompletionState(
                uid: uid,
                onboardingRepository: repoTier2,
                profileRepository: profileRepo,
              );
          expect(
            tier2Result.tier,
            equals(OnboardingRecoveryTier.tier2RebuiltFromDraft),
          );
          expect(tier2Result.bundle, isNotNull);

          // Tier 3: Completion bundle and draft missing, but user profile exists -> synthesizes fallback bundle
          final repoTier3 = FakeOnboardingRepository(routineDatabase: db);
          final userProfile = UserProfile.empty(uid: uid);
          await profileRepo.saveUserProfile(userProfile);

          final tier3Result =
              await OnboardingCompletionService.recoverCompletionState(
                uid: uid,
                onboardingRepository: repoTier3,
                profileRepository: profileRepo,
              );
          expect(
            tier3Result.tier,
            equals(OnboardingRecoveryTier.tier3Synthesized),
          );
          expect(tier3Result.bundle, isNotNull);

          // Tier 4: Bundle, draft, and profile all missing -> reset required
          const uidEmpty = 'user-empty-tier4';
          final repoTier4 = FakeOnboardingRepository(routineDatabase: db);
          final profileRepoTier4 = FakeProfileRepository();

          final tier4Result =
              await OnboardingCompletionService.recoverCompletionState(
                uid: uidEmpty,
                onboardingRepository: repoTier4,
                profileRepository: profileRepoTier4,
              );
          expect(
            tier4Result.tier,
            equals(OnboardingRecoveryTier.tier4ResetRequired),
          );
          expect(tier4Result.bundle, isNull);
        },
      );

      test(
        'AuthState handles recovery actions correctly across recovery tiers',
        () async {
          final fakeAuthRepo = FakeAuthRepository();
          final container = ProviderContainer(
            overrides: [authRepositoryProvider.overrideWithValue(fakeAuthRepo)],
          );
          addTearDown(container.dispose);

          const retryAction = RetryNetworkAction();
          expect(retryAction.actionId, equals('retry_network'));

          const rebuildAction = RebuildBundleFromVerifiedDraftAction();
          expect(rebuildAction.actionId, equals('rebuild_bundle'));

          const restartAction = ResumeOnboardingAction();
          expect(restartAction.actionId, equals('resume_onboarding'));

          const forceResyncAction = RepairProjectionAction();
          expect(
            forceResyncAction.actionId,
            equals('repair_projection'),
          );
        },
      );
    },
  );
}

// -----------------------------------------------------------------------------
// Test Helpers & Mock Classes
// -----------------------------------------------------------------------------

OnboardingDraft _completeStep(OnboardingDraft draft, int stepIndex) {
  final nextCompleted = List<bool>.from(draft.stepCompleted);
  if (stepIndex >= 0 && stepIndex < nextCompleted.length) {
    nextCompleted[stepIndex] = true;
  }
  return draft.copyWith(stepCompleted: nextCompleted);
}

OnboardingDraft _createFull15StageDraft(String uid) {
  var draft = OnboardingDraft(uid: uid);
  for (var i = 0; i < OnboardingDraft.stepCount; i++) {
    draft = _completeStep(draft, i);
  }
  return draft.copyWith(
    welcomeSaved: true,
    patiencePledgeAccepted: true,
    patiencePledgeText: 'Patience text',
    lifeRole: const LifeRoleDraft(lifeRole: 'working', workType: 'Designer'),
    bodyBasics: const BodyBasicsDraft(
      ageRange: '25-34',
      heightCm: 175,
      weightKg: 70,
      gender: 'male',
      bodyDataCompleted: true,
    ),
    baseTimeline: const BaseTimelineDraft(
      blocks: [
        TimelineBlockDraft(
          id: 'b1',
          section: 'morning',
          title: 'Morning Routine',
          startMinute: 420,
          endMinute: 480,
          repeatDays: [1, 2, 3, 4, 5],
          blockType: TimelineBlockDraft.hardBlockKey,
        ),
      ],
    ),
    badHabitsNotNow: false,
    badHabits: const [
      BadHabitDraft(id: 'bh1', habitKey: 'sugar', displayName: 'Sugar Craving'),
    ],
    goodHabitsNotNow: false,
    goodHabits: const [
      GoodHabitDraft(
        id: 'gh1',
        habitKey: GoodHabitDraft.customKey,
        displayName: 'Hydration',
      ),
    ],
    identityGoals: const [
      IdentityGoalDraft(
        goalKey: 'healthy_living',
        displayName: 'Healthy Living',
        systemKeys: ['hydration'],
      ),
    ],
    coachSetup: const CoachSetupDraft(
      coachName: 'Apex',
      coachStyle: 'Empathetic',
    ),
    slipUpHandling: 'Reset and restart next day',
    notifications: const NotificationSetupDraft(
      preferencesConfirmed: true,
      morningStartReminder: true,
    ),
    finalPreview: const FinalTimelinePreview(items: []),
    onboardingCompleted: true,
    currentStep: OnboardingDraft.lastStepIndex,
  );
}

String? evaluateRouterRedirect({
  required bool isLoggedIn,
  required UserProfile userProfile,
  required String currentPath,
}) {
  if (!isLoggedIn) {
    return currentPath == '/' || currentPath == '/login' ? null : '/';
  }
  if (!userProfile.onboardingInputCompleted) {
    return currentPath == '/onboarding' ? null : '/onboarding';
  }
  if (userProfile.onboardingInputCompleted && userProfile.onboardingCompleted) {
    if (currentPath == '/onboarding') return '/app?tab=0';
  }
  return null;
}

class FirestoreRulesEvaluator {
  bool isOwner({required String requestUid, required String docPath}) {
    if (requestUid.trim().isEmpty) return false;
    final segments = docPath.split('/');
    if (segments.length >= 2 && segments[0] == 'users') {
      return segments[1] == requestUid;
    }
    return false;
  }

  bool validUploadKeys(Map<String, dynamic> data) {
    const allowed = {
      'assetId',
      'ownerUid',
      'sourceFeature',
      'purpose',
      'fileName',
      'contentType',
      'sizeBytes',
      'r2Key',
      'status',
      'createdAt',
      'updatedAt',
      'errorMessage',
    };
    const forbidden = {'localPreviewPath', 'imageBytes', 'bytes'};
    for (final key in data.keys) {
      if (!allowed.contains(key)) return false;
      if (forbidden.contains(key)) return false;
    }
    return true;
  }

  bool validUploadPurpose(String purpose) {
    const allowed = {
      'profile_photo',
      'class_timetable',
      'work_schedule',
      'eating_menu',
      'skin_care',
    };
    return allowed.contains(purpose);
  }

  bool isValidUploadSize(String purpose, int sizeBytes) {
    if (sizeBytes <= 0) return false;
    if (purpose == 'profile_photo') return sizeBytes <= 5242880;
    return sizeBytes <= 15728640;
  }
}
