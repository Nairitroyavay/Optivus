import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/uploads/authenticated_r2_preview_resolver.dart';

void main() {
  group('BaseTimelineSection and Snapshot Tests', () {
    test('Snapshot labels and origins match specifications', () {
      const snapClasses = BaseTimelineSectionSnapshot(
        section: BaseTimelineSection.classes,
        origin: BaseSetupOrigin.photo,
        configured: true,
        blocks: [],
        summary: 'Timetable photo · 4 blocks',
      );
      expect(snapClasses.displayName, 'Classes');
      expect(snapClasses.configured, isTrue);
      expect(snapClasses.origin, BaseSetupOrigin.photo);

      const snapWork = BaseTimelineSectionSnapshot(
        section: BaseTimelineSection.work,
        origin: BaseSetupOrigin.manual,
        configured: true,
        blocks: [],
        summary: '5 weekly blocks',
      );
      expect(snapWork.displayName, 'Work / Business');

      const snapEating = BaseTimelineSectionSnapshot(
        section: BaseTimelineSection.eating,
        origin: BaseSetupOrigin.generatedFromAnswers,
        configured: true,
        blocks: [],
        summary: 'Built for me · 3 meals/day',
      );
      expect(snapEating.displayName, 'Eating');

      const snapFixed = BaseTimelineSectionSnapshot(
        section: BaseTimelineSection.fixed,
        origin: BaseSetupOrigin.manual,
        configured: true,
        blocks: [],
        summary: 'Sleep, Bath',
      );
      expect(snapFixed.displayName, 'Fixed');

      const snapSkin = BaseTimelineSectionSnapshot(
        section: BaseTimelineSection.skinCare,
        origin: BaseSetupOrigin.skipped,
        configured: false,
        blocks: [],
        summary: 'Not set up',
      );
      expect(snapSkin.displayName, 'Skin Care');
      expect(snapSkin.origin, BaseSetupOrigin.skipped);
    });

    test('BaseTimelineSetup serialization and deserialization is idempotent', () {
      final now = DateTime.now();
      final setup = BaseTimelineSetup(
        uid: 'user-123',
        updatedAt: now,
        classLogicalAssetId: 'asset-classes-1',
        classLogicalAssetR2Key: 'uploads/classes_user-123_1.jpg',
        classBlocks: const [
          TimelineBlockDraft(
            id: 'c1',
            section: 'classes',
            title: 'Math 101',
            startMinute: 540,
            endMinute: 600,
            repeatDays: [1, 3],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ],
        workBlocks: const [],
        eatingSetupPath: 'has_routine',
        eatingPhotoAssetId: 'asset-eating-1',
        eatingPhotoR2Key: 'uploads/eating_plan.jpg',
        eatingBlocks: const [
          TimelineBlockDraft(
            id: 'e1',
            section: 'eating',
            title: 'Lunch',
            startMinute: 720,
            endMinute: 760,
            repeatDays: [1, 2, 3, 4, 5],
            blockType: TimelineBlockDraft.softBlockKey,
            mealCategory: 'lunch',
          ),
        ],
        fixedBlocks: const [
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
        skinCareSkipped: true,
      );

      final map = setup.toMap();
      final restored = BaseTimelineSetup.fromMap(map, uid: 'user-123');

      expect(restored.uid, 'user-123');
      expect(restored.classLogicalAssetId, 'asset-classes-1');
      expect(restored.classLogicalAssetR2Key, 'uploads/classes_user-123_1.jpg');
      expect(restored.classBlocks.length, 1);
      expect(restored.classBlocks.first.title, 'Math 101');

      expect(restored.eatingSetupPath, 'has_routine');
      expect(restored.eatingPhotoR2Key, 'uploads/eating_plan.jpg');
      expect(restored.eatingBlocks.length, 1);

      expect(restored.fixedBlocks.length, 1);
      expect(restored.skinCareSkipped, isTrue);

      // Snapshot assertions on restored
      final classSnap = restored.snapshotFor(BaseTimelineSection.classes);
      expect(classSnap.configured, isTrue);
      expect(classSnap.origin, BaseSetupOrigin.photo);

      final workSnap = restored.snapshotFor(BaseTimelineSection.work);
      expect(workSnap.configured, isFalse);
      expect(workSnap.origin, BaseSetupOrigin.notConfigured);

      final skinSnap = restored.snapshotFor(BaseTimelineSection.skinCare);
      expect(skinSnap.configured, isFalse);
      expect(skinSnap.origin, BaseSetupOrigin.skipped);
    });

    test('BaseTimelineSetup snapshots accurately compute section states', () {
      final emptySetup = BaseTimelineSetup(uid: 'user-1', updatedAt: DateTime.now());
      expect(emptySetup.snapshotFor(BaseTimelineSection.classes).configured, isFalse);
      expect(emptySetup.snapshotFor(BaseTimelineSection.work).configured, isFalse);
      expect(emptySetup.snapshotFor(BaseTimelineSection.eating).configured, isFalse);
      expect(emptySetup.snapshotFor(BaseTimelineSection.fixed).configured, isFalse);
      expect(emptySetup.snapshotFor(BaseTimelineSection.skinCare).configured, isFalse);

      final activeSetup = BaseTimelineSetup(
        uid: 'user-1',
        updatedAt: DateTime.now(),
        classBlocks: const [
          TimelineBlockDraft(
            id: 'c1',
            section: 'classes',
            title: 'Chem',
            startMinute: 600,
            endMinute: 660,
            repeatDays: [1, 2, 3],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ],
        skinCareSkipped: true,
      );
      expect(activeSetup.snapshotFor(BaseTimelineSection.classes).configured, isTrue);
      expect(activeSetup.snapshotFor(BaseTimelineSection.skinCare).configured, isFalse);
      expect(activeSetup.snapshotFor(BaseTimelineSection.skinCare).origin, BaseSetupOrigin.skipped);
    });
  });

  group('Migration from Onboarding Draft & Completion Bundle', () {
    test('Migrates accurately from OnboardingDraft with uploaded assets', () {
      final now = DateTime.now();
      final draft = OnboardingDraft(
        uid: 'test-uid',
        baseTimeline: BaseTimelineDraft(
          blocks: const [
            TimelineBlockDraft(
              id: 'c1',
              section: 'classes',
              title: 'Math 101',
              startMinute: 540,
              endMinute: 600,
              repeatDays: [1, 3],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
            TimelineBlockDraft(
              id: 'j1',
              section: 'job_work_business',
              title: 'Deep Work',
              startMinute: 600,
              endMinute: 720,
              repeatDays: [1, 2, 3, 4, 5],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
            TimelineBlockDraft(
              id: 's1',
              section: 'skin_care',
              title: 'Morning Routine',
              startMinute: 480,
              endMinute: 495,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.softBlockKey,
            ),
          ],
          pendingFutureImports: [
            PendingFutureImportDraft(
              id: 'imp-classes',
              section: 'classes',
              mode: 'photo',
              createdAt: now,
              uploadedAssetId: 'asset-classes',
              uploadedAssetR2Key: 'r2/classes_photo.jpg',
              uploadPlaceholderPath: '/local/classes.jpg',
            ),
          ],
          skinCareProductPhotoAssetId: 'asset-skin',
          skinCareProductPhotoR2Key: 'r2/skin_photo.jpg',
          skinCareSkipped: false,
        ),
      );

      final setup = BaseTimelineSetup.fromOnboardingDraft('test-uid', draft);

      expect(setup.uid, 'test-uid');
      final classSnap = setup.snapshotFor(BaseTimelineSection.classes);
      expect(classSnap.configured, isTrue);
      expect(classSnap.origin, BaseSetupOrigin.photo);
      expect(setup.classLogicalAssetR2Key, 'r2/classes_photo.jpg');
      expect(setup.classBlocks.length, 1);

      final workSnap = setup.snapshotFor(BaseTimelineSection.work);
      expect(workSnap.configured, isTrue);
      expect(setup.workBlocks.length, 1);

      final skinSnap = setup.snapshotFor(BaseTimelineSection.skinCare);
      expect(skinSnap.configured, isTrue);
      expect(setup.skinCareProductPhotoR2Key, 'r2/skin_photo.jpg');
    });

    test('Migrates accurately from OnboardingCompletionBundle with routines', () {
      final now = DateTime.now();
      final bundle = OnboardingCompletionBundle(
        uid: 'bundle-user',
        createdAt: now,
        updatedAt: now,
        userProfilePatch: const {},
        baseTimelineBlocks: const [
          TimelineBlockDraft(
            id: 'c1',
            section: 'classes',
            title: 'CS 200',
            startMinute: 600,
            endMinute: 660,
            repeatDays: [1, 3],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
          TimelineBlockDraft(
            id: 'j1',
            section: 'job_work_business',
            title: 'Shift',
            startMinute: 720,
            endMinute: 960,
            repeatDays: [1, 2, 3],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ],
        finalTimelineItems: const [],
        routineItemsForApp: const [],
        goodHabitTemplates: const [],
        badHabitCheckIns: const [],
        identityGoalSystems: const [],
        notificationPreferences: NotificationPreferences(),
        coachPreferences: CoachPreferences(),
        moneyGoal: null,
        uploadedAssetReferences: [
          OnboardingUploadedAssetReference(
            id: 'ref-work',
            section: 'job_work_business',
            mode: 'photo',
            uploadedAssetId: 'asset-work',
            uploadedAssetR2Key: 'r2/work_photo.jpg',
            createdAt: now,
            updatedAt: now,
          ),
        ],
        warnings: const [],
        duplicateSystemKeysMerged: const [],
      );

      final setup = BaseTimelineSetup.fromCompletionBundle('bundle-user', bundle);

      expect(setup.uid, 'bundle-user');
      expect(setup.classBlocks.length, 1);
      expect(setup.workBlocks.length, 1);
      expect(setup.workLogicalAssetR2Key, 'r2/work_photo.jpg');

      final workSnap = setup.snapshotFor(BaseTimelineSection.work);
      expect(workSnap.configured, isTrue);
      expect(workSnap.origin, BaseSetupOrigin.photo);
    });
  });

  group('BaseTimelineTransactionCoordinator Tests', () {
    test('replaceSection atomically deletes old onboarding items and inserts new items', () async {
      final routineRepo = FakeRoutineRepository();
      final onboardingRepo = FakeOnboardingRepository();
      final baseTimelineRepo = FakeBaseTimelineSetupRepository(onboardingRepo: onboardingRepo);

      final coordinator = BaseTimelineTransactionCoordinator(
        routineRepo: routineRepo,
        setupRepo: baseTimelineRepo,
      );

      // Pre-seed with existing routine items:
      // 1 onboarding class item, 1 manual routine item (must be preserved)
      final oldClassItem = RoutineItem(
        id: 'old-class-1',
        userId: 'user-a',
        title: 'Old Chemistry Class',
        category: RoutineCategory.classBlock,
        blockType: RoutineBlockType.hardBlock,
        startMinute: 540,
        endMinute: 600,
        repeatDays: const [1, 3],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        source: RoutineSource.onboarding,
      );

      final manualItem = RoutineItem(
        id: 'manual-item-1',
        userId: 'user-a',
        title: 'Gym Workout',
        category: RoutineCategory.health,
        blockType: RoutineBlockType.hardBlock,
        startMinute: 1020,
        endMinute: 1080,
        repeatDays: const [1, 2, 3, 4, 5],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        source: RoutineSource.manual,
      );

      await routineRepo.createRoutineItem('user-a', oldClassItem);
      await routineRepo.createRoutineItem('user-a', manualItem);

      // Verify pre-seeded state
      final initialItems = await routineRepo.fetchRoutineItems('user-a');
      expect(initialItems.length, 2);

      // Now re-setup Classes section with 2 new blocks
      final newBlocks = <TimelineBlockDraft>[
        const TimelineBlockDraft(
          id: 'new-class-1',
          section: 'classes',
          title: 'Advanced AI 401',
          startMinute: 600,
          endMinute: 660,
          repeatDays: [2, 4],
          blockType: TimelineBlockDraft.hardBlockKey,
        ),
        const TimelineBlockDraft(
          id: 'new-class-2',
          section: 'classes',
          title: 'Physics Lab',
          startMinute: 720,
          endMinute: 840,
          repeatDays: [2],
          blockType: TimelineBlockDraft.hardBlockKey,
        ),
      ];

      await coordinator.replaceSection(
        uid: 'user-a',
        section: BaseTimelineSection.classes,
        newBlocks: newBlocks,
        updateSetup: (current) => current.copyWith(
          classBlocks: newBlocks,
          classLogicalAssetR2Key: 'new_class_photo.jpg',
        ),
      );

      // Check remaining routine items
      final finalItems = await routineRepo.fetchRoutineItems('user-a');
      expect(finalItems.length, 3); // 2 new classes + 1 manual preserved

      // Ensure old class was removed
      expect(finalItems.any((i) => i.id == 'old-class-1'), isFalse);

      // Ensure manual item was PRESERVED
      expect(finalItems.any((i) => i.id == 'manual-item-1' && i.title == 'Gym Workout'), isTrue);

      // Ensure new classes are present
      expect(finalItems.any((i) => i.title == 'Advanced AI 401'), isTrue);
      expect(finalItems.any((i) => i.title == 'Physics Lab'), isTrue);

      // Ensure BaseTimelineSetup is updated
      final updatedSetup = await baseTimelineRepo.fetchSetup('user-a');
      expect(updatedSetup.classBlocks.length, 2);
      expect(updatedSetup.classLogicalAssetR2Key, 'new_class_photo.jpg');
    });

    test('Overlapping blocks (e.g. Class 10-11 and Eating 10:20-10:40) save without conflict errors', () async {
      final routineRepo = FakeRoutineRepository();
      final onboardingRepo = FakeOnboardingRepository();
      final baseTimelineRepo = FakeBaseTimelineSetupRepository(onboardingRepo: onboardingRepo);

      final coordinator = BaseTimelineTransactionCoordinator(
        routineRepo: routineRepo,
        setupRepo: baseTimelineRepo,
      );

      // 1. Save Class from 10:00 to 11:00 (600 to 660)
      final classBlocks = <TimelineBlockDraft>[
        const TimelineBlockDraft(
          id: 'class-1',
          section: 'classes',
          title: 'Math Lecture',
          startMinute: 600,
          endMinute: 660,
          repeatDays: [1, 2, 3, 4, 5],
          blockType: TimelineBlockDraft.hardBlockKey,
        ),
      ];

      await coordinator.replaceSection(
        uid: 'user-overlap',
        section: BaseTimelineSection.classes,
        newBlocks: classBlocks,
        updateSetup: (current) => current.copyWith(
          classBlocks: classBlocks,
        ),
      );

      // 2. Save Eating from 10:20 to 10:40 (620 to 640) - DIRECT OVERLAP WITH CLASS
      final eatingBlocks = <TimelineBlockDraft>[
        const TimelineBlockDraft(
          id: 'meal-1',
          section: 'eating',
          title: 'Mid-Morning Snack',
          startMinute: 620,
          endMinute: 640,
          repeatDays: [1, 2, 3, 4, 5],
          blockType: TimelineBlockDraft.softBlockKey,
          mealCategory: 'snack',
        ),
      ];

      await coordinator.replaceSection(
        uid: 'user-overlap',
        section: BaseTimelineSection.eating,
        newBlocks: eatingBlocks,
        updateSetup: (current) => current.copyWith(
          eatingSetupPath: 'custom',
          eatingBlocks: eatingBlocks,
        ),
      );

      // In Base Timeline re-setup, zero cross-domain conflict validation is enforced:
      // Overlaps are accepted and successfully persisted!
      final allItems = await routineRepo.fetchRoutineItems('user-overlap');
      expect(allItems.length, 2);
      expect(allItems.any((i) => i.title == 'Math Lecture'), isTrue);
      expect(allItems.any((i) => i.title == 'Mid-Morning Snack'), isTrue);
    });
  });

  group('AuthenticatedR2PreviewResolver Tests', () {
    test('Resolves presigned URL with token and caches result', () async {
      final fakeClient = FakeR2UploadClient();
      var tokenFetchCount = 0;

      final resolver = AuthenticatedR2PreviewResolver(
        client: fakeClient,
        getIdToken: () async {
          tokenFetchCount++;
          return 'valid-firebase-token';
        },
      );

      final now = DateTime.now();
      final asset = UploadedAsset(
        assetId: 'asset-1',
        ownerUid: 'user-test',
        sourceFeature: 'onboarding',
        purpose: UploadedAssetPurpose.classTimetable,
        fileName: 'classes_preview.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 1024,
        r2Key: 'test/classes_preview.jpg',
        status: UploadedAssetStatus.uploaded,
        createdAt: now,
        updatedAt: now,
      );

      // First call: fetches token and preview URL
      final uri1 = await resolver.resolvePreview(uid: 'user-test', asset: asset);
      expect(uri1, isNotNull);
      expect(uri1.toString(), contains('https://preview.local/test/classes_preview.jpg'));
      expect(tokenFetchCount, 1);

      // Second call: in-memory cache hit, does not call getIdToken again
      final uri2 = await resolver.resolvePreview(uid: 'user-test', asset: asset);
      expect(uri2, uri1);
      expect(tokenFetchCount, 1); // Remains 1 due to cache hit
    });

    test('Returns null gracefully when asset has no r2Key or client errors', () async {
      final fakeClient = FakeR2UploadClient();
      final resolver = AuthenticatedR2PreviewResolver(
        client: fakeClient,
        getIdToken: () async => 'valid-token',
      );

      final now = DateTime.now();
      final emptyAsset = UploadedAsset(
        assetId: 'asset-empty',
        ownerUid: 'user-test',
        sourceFeature: 'onboarding',
        purpose: UploadedAssetPurpose.classTimetable,
        fileName: 'empty.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 0,
        r2Key: '',
        status: UploadedAssetStatus.uploaded,
        createdAt: now,
        updatedAt: now,
      );

      final uri = await resolver.resolvePreview(uid: 'user-test', asset: emptyAsset);
      expect(uri, isNull);
    });
  });
}
