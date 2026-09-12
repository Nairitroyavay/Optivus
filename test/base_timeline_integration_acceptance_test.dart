import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_upload_lifecycle_helper.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/services/uploads/authenticated_r2_preview_resolver.dart';
import 'package:optivus/state/upload_state.dart';

void main() {
  group('Base Timeline End-to-End Integration Acceptance Gate', () {
    const uid = 'user-acceptance-e2e';
    late FakeRoutineRepository routineRepo;
    late FakeOnboardingRepository onboardingRepo;
    late FakeBaseTimelineSetupRepository setupRepo;
    late FakeRoutineTransactionRepository txRepo;
    late BaseTimelineTransactionCoordinator coordinator;
    late FakeUploadedAssetRepository assetRepo;
    late _TrackingR2UploadClient r2Client;
    late _FakeAuthRepository authRepo;
    late BaseTimelineUploadLifecycleHelper uploadLifecycleHelper;
    late AuthenticatedR2PreviewResolver previewResolver;

    setUp(() {
      routineRepo = FakeRoutineRepository();
      onboardingRepo = FakeOnboardingRepository();
      setupRepo = FakeBaseTimelineSetupRepository(
        onboardingRepo: onboardingRepo,
      );
      txRepo = FakeRoutineTransactionRepository(
        routineRepository: routineRepo,
        setupRepository: setupRepo,
      );
      coordinator = BaseTimelineTransactionCoordinator(
        routineRepo: routineRepo,
        setupRepo: setupRepo,
        transactionRepo: txRepo,
      );
      assetRepo = FakeUploadedAssetRepository();
      r2Client = _TrackingR2UploadClient();
      authRepo = _FakeAuthRepository();
      uploadLifecycleHelper = BaseTimelineUploadLifecycleHelper(
        assetRepository: assetRepo,
        r2UploadClient: r2Client,
        authRepository: authRepo,
      );
      previewResolver = AuthenticatedR2PreviewResolver(
        client: r2Client,
        getIdToken: () async => 'token-e2e',
      );
    });

    test(
      'Complete end-to-end journey: Onboarding completion -> Hub baseline -> Upload discard -> Plan commit -> Zero conflict cross-domain -> OCC concurrency protection -> R2 isolation',
      () async {
        final now = DateTime.now();

        // -------------------------------------------------------------
        // Step 1: Onboarding Completion Creates Initial Base Timeline Setup
        // -------------------------------------------------------------
        final draft = OnboardingDraft(
          uid: uid,
          bodyBasics: const BodyBasicsDraft(
            weightKg: 72.0,
            heightCm: 178.0,
            ageRange: '25-34',
            gender: 'male',
          ),
          lifeRole: const LifeRoleDraft(
            exerciseLevel: 'moderate',
            lifeRole: 'professional',
          ),
          baseTimeline: const BaseTimelineDraft(
            mealPlanningGoal: 'maintain',
            mealsPerDay: 3,
            fixedScheduleSetupStep: 1,
          ),
        );

        final initialClassRoutineItem = RoutineItem(
          id: 'initial-class-item-1',
          userId: uid,
          title: 'Morning Lecture',
          category: RoutineCategory.classBlock,
          blockType: RoutineBlockType.hardBlock,
          startMinute: 540,
          endMinute: 600,
          repeatDays: const [1, 3, 5],
          createdAt: now,
          updatedAt: now,
          source: RoutineSource.onboarding,
        );

        final initialSleepRoutineItem = RoutineItem(
          id: 'initial-sleep-item-1',
          userId: uid,
          title: 'Sleep',
          category: RoutineCategory.sleep,
          blockType: RoutineBlockType.hardBlock,
          crossesMidnight: true,
          endsNextDay: true,
          startMinute: 1380,
          endMinute: 420,
          repeatDays: const [1, 2, 3, 4, 5, 6, 7],
          createdAt: now,
          updatedAt: now,
          source: RoutineSource.onboarding,
        );

        final bundle = OnboardingCompletionBundle(
          uid: uid,
          createdAt: now,
          updatedAt: now,
          userProfilePatch: const {},
          baseTimelineBlocks: const [
            TimelineBlockDraft(
              id: 'c1',
              section: 'classes',
              title: 'Morning Lecture',
              startMinute: 540,
              endMinute: 600,
              repeatDays: [1, 3, 5],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
            TimelineBlockDraft(
              id: BaseTimelineDraft.fixedSleepId,
              section: 'fixed',
              title: 'Sleep',
              startMinute: 1380,
              endMinute: 420,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
          finalTimelineItems: const [],
          routineItemsForApp: [
            initialClassRoutineItem,
            initialSleepRoutineItem,
          ],
          goodHabitTemplates: const [],
          badHabitCheckIns: const [],
          identityGoalSystems: const [],
          notificationPreferences: NotificationPreferences(),
          coachPreferences: CoachPreferences(),
          moneyGoal: null,
          uploadedAssetReferences: const [],
          warnings: const [],
          duplicateSystemKeysMerged: const [],
        );

        await onboardingRepo.saveCompletionBundle(bundle);
        final plan = RoutineOnboardingProjection.build(bundle);
        for (final item in plan.items) {
          await routineRepo.createRoutineItem(uid, item);
        }

        final initialSetup = BaseTimelineSetup.fromOnboardingCompletion(
          finalDraft: draft,
          bundle: bundle,
          projectedRoutineItems: plan.items,
        );
        await setupRepo.saveSetup(uid, initialSetup);

        // Verify initial setup contract
        expect(initialSetup.schemaVersion, 2);
        expect(initialSetup.revision, 1);
        expect(
          initialSetup.classRoutineItemIds,
          contains(
            RoutineOnboardingProjection.stableRoutineDocumentId(
              ownerUid: uid,
              sourceItemId: 'initial-class-item-1',
            ),
          ),
        );
        expect(
          initialSetup.fixedRoutineItemIds,
          contains(
            RoutineOnboardingProjection.stableRoutineDocumentId(
              ownerUid: uid,
              sourceItemId: 'initial-sleep-item-1',
            ),
          ),
        );
        expect(
          initialSetup.snapshotFor(BaseTimelineSection.classes).configured,
          isTrue,
        );
        expect(
          initialSetup.snapshotFor(BaseTimelineSection.eating).configured,
          isFalse,
        );

        // -------------------------------------------------------------
        // Step 2: Uncommitted Upload Retirement on Discard in Eating Flow
        // -------------------------------------------------------------
        const eatingAssetId = 'eat-asset-temp';
        const eatingObjectKey =
            'users/$uid/routine_base_timeline/eating_menu/$eatingAssetId.jpg';

        final tempEatingAsset = UploadedAsset(
          assetId: eatingAssetId,
          ownerUid: uid,
          sourceFeature: 'routine_base_timeline',
          purpose: UploadedAssetPurpose.eatingMenu,
          fileName: '$eatingAssetId.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 2048,
          r2Key: eatingObjectKey,
          status: UploadedAssetStatus.uploaded,
          createdAt: now,
          updatedAt: now,
        );
        await assetRepo.saveAsset(tempEatingAsset);

        // Verify upload validity for routine_base_timeline
        final validUpload = uploadedAssetIsDurablyUploadedForSlot(
          asset: tempEatingAsset,
          uid: uid,
          expectedSourceFeature: UploadSourceFeature.routineBaseTimeline,
          purpose: UploadedAssetPurpose.eatingMenu,
        );
        expect(validUpload, isTrue);

        // User changes mind and discards Eating setup -> retire uncommitted upload
        await uploadLifecycleHelper.retireUncommittedUpload(
          uid: uid,
          assetId: eatingAssetId,
          objectKey: eatingObjectKey,
        );

        // R2 deletion was called and Firestore asset marked deleted
        expect(r2Client.deletedKeys, contains(eatingObjectKey));
        final deletedAsset = await assetRepo.fetchAsset(
          uid: uid,
          assetId: eatingAssetId,
        );
        expect(deletedAsset?.status, UploadedAssetStatus.deleted);

        // Setup remains at revision 1 and eating is still unconfigured
        var currentSetup = await setupRepo.fetchSetup(uid);
        expect(currentSetup.revision, 1);
        expect(
          currentSetup.snapshotFor(BaseTimelineSection.eating).configured,
          isFalse,
        );

        // -------------------------------------------------------------
        // Step 3: User Configures & Commits Eating Section Atomically
        // -------------------------------------------------------------
        final eatingBlocks = [
          const TimelineBlockDraft(
            id: 'eat-b1',
            section: 'eating',
            title: 'Breakfast',
            startMinute: 480,
            endMinute: 510,
            repeatDays: [1, 2, 3, 4, 5, 6, 7],
            blockType: TimelineBlockDraft.softBlockKey,
            mealCategory: 'breakfast',
          ),
          const TimelineBlockDraft(
            id: 'eat-b2',
            section: 'eating',
            title: 'Lunch',
            startMinute: 720,
            endMinute: 750,
            repeatDays: [1, 2, 3, 4, 5, 6, 7],
            blockType: TimelineBlockDraft.softBlockKey,
            mealCategory: 'lunch',
          ),
          const TimelineBlockDraft(
            id: 'eat-b3',
            section: 'eating',
            title: 'Dinner',
            startMinute: 1140,
            endMinute: 1180,
            repeatDays: [1, 2, 3, 4, 5, 6, 7],
            blockType: TimelineBlockDraft.softBlockKey,
            mealCategory: 'dinner',
          ),
        ];

        await coordinator.replaceSection(
          uid: uid,
          section: BaseTimelineSection.eating,
          newBlocks: eatingBlocks,
          updateSetup: (current) => current.copyWith(
            eatingBlocks: eatingBlocks,
            eatingSetupPath: 'plan',
            mealsPerDay: 3,
          ),
        );

        // Invariant: authoritatively written IDs match updatedSetup.eatingRoutineItemIds
        currentSetup = await setupRepo.fetchSetup(uid);
        expect(currentSetup.revision, 2);
        expect(currentSetup.schemaVersion, 2);
        expect(currentSetup.eatingRoutineItemIds.length, 3);

        // Verify Routine items in Routine repository
        final allRoutineItems = await routineRepo.fetchRoutineItems(uid);
        final eatingRoutineItems = allRoutineItems
            .where((i) => i.category == RoutineCategory.eating)
            .toList();
        expect(eatingRoutineItems.length, 3);
        for (final item in eatingRoutineItems) {
          expect(item.source, RoutineSource.baseTimeline);
          expect(item.userId, uid);
          expect(currentSetup.eatingRoutineItemIds, contains(item.id));
        }

        // Survivor check: Classes item and Sleep item from onboarding survived!
        expect(
          allRoutineItems.any(
            (i) =>
                i.id ==
                RoutineOnboardingProjection.stableRoutineDocumentId(
                  ownerUid: uid,
                  sourceItemId: 'initial-class-item-1',
                ),
          ),
          isTrue,
        );
        expect(
          allRoutineItems.any(
            (i) =>
                i.id ==
                RoutineOnboardingProjection.stableRoutineDocumentId(
                  ownerUid: uid,
                  sourceItemId: 'initial-sleep-item-1',
                ),
          ),
          isTrue,
        );

        // -------------------------------------------------------------
        // Step 4: Cross-Domain Overlap Saves With Zero Conflict Errors
        // -------------------------------------------------------------
        // User configures Work with hours that overlap with Eating (e.g. 700 to 840 vs Lunch 720-750)
        final workBlocks = [
          const TimelineBlockDraft(
            id: 'work-b1',
            section: 'job_work_business',
            title: 'Client Meeting',
            startMinute: 700,
            endMinute: 840, // overlaps with Lunch (720-750)
            repeatDays: [1, 2, 3, 4, 5],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ];

        await coordinator.replaceSection(
          uid: uid,
          section: BaseTimelineSection.work,
          newBlocks: workBlocks,
          updateSetup: (current) => current.copyWith(workBlocks: workBlocks),
        );

        currentSetup = await setupRepo.fetchSetup(uid);
        expect(currentSetup.revision, 3);

        // Both Work and Eating items exist peacefully in routine repository
        final updatedRoutineItems = await routineRepo.fetchRoutineItems(uid);
        expect(
          updatedRoutineItems.any((i) => i.title == 'Client Meeting'),
          isTrue,
        );
        expect(updatedRoutineItems.any((i) => i.title == 'Lunch'), isTrue);

        // -------------------------------------------------------------
        // Step 5: Optimistic Concurrency Control (OCC) Protection
        // -------------------------------------------------------------
        // Stale transaction attempt using expectedRevision: 2 when current is 3
        expect(
          () async => txRepo.replaceBaseTimelineSection(
            uid: uid,
            section: BaseTimelineSection.classes,
            expectedRevision: 2, // Stale! Current in DB is 3.
            newRoutineItems: [],
            buildUpdatedSetup: (curr) => curr.copyWith(classBlocks: []),
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('revision mismatch'),
            ),
          ),
        );

        // Verify setup revision remained 3
        currentSetup = await setupRepo.fetchSetup(uid);
        expect(currentSetup.revision, 3);

        // -------------------------------------------------------------
        // Step 6: Authenticated R2 Preview Security & Tenant Isolation
        // -------------------------------------------------------------
        final committedAsset = UploadedAsset(
          assetId: 'asset-committed-1',
          ownerUid: uid,
          sourceFeature: 'routine_base_timeline',
          purpose: UploadedAssetPurpose.classTimetable,
          fileName: 'asset-committed-1.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 1024,
          r2Key:
              'users/$uid/routine_base_timeline/class_timetable/asset-committed-1.jpg',
          status: UploadedAssetStatus.uploaded,
          createdAt: now,
          updatedAt: now,
        );

        // Authorized preview resolve succeeds
        final previewUri = await previewResolver.resolvePreview(
          uid: uid,
          asset: committedAsset,
        );
        expect(previewUri, isNotNull);
        expect(
          previewUri.toString(),
          contains('users/$uid/routine_base_timeline'),
        );

        // Cross-user malicious attempt: trying to resolve an asset from another user
        final deniedUri = await previewResolver.resolveR2Key(
          uid: uid,
          r2Key: 'users/other-victim-user/routine_base_timeline/secret.jpg',
        );
        expect(deniedUri, isNull);
      },
    );
  });
}

class _TrackingR2UploadClient extends FakeR2UploadClient {
  final List<String> deletedKeys = [];

  @override
  Future<void> deleteUpload({
    required String objectKey,
    required String idToken,
  }) async {
    deletedKeys.add(objectKey);
  }
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<String?> currentIdToken() async => 'fake-id-token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
