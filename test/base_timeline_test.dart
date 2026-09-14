import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_domain_engine.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/skin_care_domain_engine.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/nutrition_ai_client.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/services/skin_care_ai_client.dart';
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

    test(
      'BaseTimelineSetup serialization and deserialization is idempotent',
      () {
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
        expect(
          restored.classLogicalAssetR2Key,
          'uploads/classes_user-123_1.jpg',
        );
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
      },
    );

    test('BaseTimelineSetup snapshots accurately compute section states', () {
      final emptySetup = BaseTimelineSetup(
        uid: 'user-1',
        updatedAt: DateTime.now(),
      );
      expect(
        emptySetup.snapshotFor(BaseTimelineSection.classes).configured,
        isFalse,
      );
      expect(
        emptySetup.snapshotFor(BaseTimelineSection.work).configured,
        isFalse,
      );
      expect(
        emptySetup.snapshotFor(BaseTimelineSection.eating).configured,
        isFalse,
      );
      expect(
        emptySetup.snapshotFor(BaseTimelineSection.fixed).configured,
        isFalse,
      );
      expect(
        emptySetup.snapshotFor(BaseTimelineSection.skinCare).configured,
        isFalse,
      );

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
      expect(
        activeSetup.snapshotFor(BaseTimelineSection.classes).configured,
        isTrue,
      );
      expect(
        activeSetup.snapshotFor(BaseTimelineSection.skinCare).configured,
        isFalse,
      );
      expect(
        activeSetup.snapshotFor(BaseTimelineSection.skinCare).origin,
        BaseSetupOrigin.skipped,
      );
    });

    test('wrong embedded owner is rejected during reconstruction', () {
      final map = BaseTimelineSetup(
        uid: 'owner-a',
        updatedAt: DateTime.utc(2026, 9, 13),
      ).toMap();
      expect(
        () => BaseTimelineSetup.fromMap(map, uid: 'owner-b'),
        throwsFormatException,
      );
    });

    test('nullable mode fields clear and remain null after round-trip', () {
      final setup = BaseTimelineSetup(
        uid: 'clear-fields',
        updatedAt: DateTime.utc(2026, 9, 13),
        eatingSetupPath: 'create',
        mealPlanningGoal: 'maintain',
        mealsPerDay: 4,
        eatingMode: 'home',
        foodType: 'vegetarian',
        foodStyleCustomText: 'regional',
        mealBudget: 'medium',
        cookingAbility: 'advanced',
        breakfastMinute: 480,
        targetCalories: 2200,
        targetProtein: 130,
        skinCareSetupPath: 'build_for_me',
        skinCareSkinType: 'dry',
        skinCareBudget: 'medium',
        skinCarePreference: 'simple',
      );

      final photo = setup.asEatingPhoto(
        photoAssetId: 'meal-photo',
        photoR2Key: 'users/clear-fields/meal-photo.jpg',
      );
      final products = photo.asSkinCareProducts(productNames: 'Cleanser');
      final restored = BaseTimelineSetup.fromMap(
        products.toMap(),
        uid: 'clear-fields',
      );

      expect(restored.mealPlanningGoal, isNull);
      expect(restored.mealsPerDay, isNull);
      expect(restored.eatingMode, isNull);
      expect(restored.foodType, isNull);
      expect(restored.foodStyleCustomText, isNull);
      expect(restored.mealBudget, isNull);
      expect(restored.cookingAbility, isNull);
      expect(restored.breakfastMinute, isNull);
      expect(restored.targetCalories, isNull);
      expect(restored.targetProtein, isNull);
      expect(restored.skinCareSkinType, isNull);
      expect(restored.skinCareBudget, isNull);
      expect(restored.skinCarePreference, isNull);
    });

    test('canonical serialization drops obsolete fields', () {
      final setup = BaseTimelineSetup(
        uid: 'canonical-rewrite',
        updatedAt: DateTime.utc(2026, 9, 13),
      );
      final legacyPayload = {...setup.toMap(), 'obsoleteField': 'ghost'};
      final loaded = BaseTimelineSetup.fromMap(
        legacyPayload,
        uid: 'canonical-rewrite',
      );
      expect(loaded.toMap(), isNot(contains('obsoleteField')));
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

    test(
      'Migrates accurately from OnboardingCompletionBundle with routines',
      () {
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

        final setup = BaseTimelineSetup.fromCompletionBundle(
          'bundle-user',
          bundle,
          projectedRoutineItems: RoutineOnboardingProjection.build(
            bundle,
          ).items,
        );

        expect(setup.uid, 'bundle-user');
        expect(setup.classBlocks.length, 1);
        expect(setup.workBlocks.length, 1);
        expect(setup.workLogicalAssetR2Key, 'r2/work_photo.jpg');

        final workSnap = setup.snapshotFor(BaseTimelineSection.work);
        expect(workSnap.configured, isTrue);
        expect(workSnap.origin, BaseSetupOrigin.photo);
      },
    );
  });

  group('BaseTimelineTransactionCoordinator Tests', () {
    test(
      'replaceSection atomically deletes old onboarding items and inserts new items',
      () async {
        final routineRepo = FakeRoutineRepository();
        final onboardingRepo = FakeOnboardingRepository();
        final baseTimelineRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: onboardingRepo,
        );
        final txRepo = FakeRoutineTransactionRepository(
          routineRepository: routineRepo,
          setupRepository: baseTimelineRepo,
        );

        final coordinator = BaseTimelineTransactionCoordinator(
          routineRepo: routineRepo,
          setupRepo: baseTimelineRepo,
          transactionRepo: txRepo,
        );

        // Canonical ownership tracks the existing projected class explicitly.
        await baseTimelineRepo.saveSetup(
          'user-a',
          BaseTimelineSetup(
            uid: 'user-a',
            updatedAt: DateTime.now(),
            classRoutineItemIds: const ['old-class-1'],
          ),
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
        expect(
          finalItems.any(
            (i) => i.id == 'manual-item-1' && i.title == 'Gym Workout',
          ),
          isTrue,
        );

        // Ensure new classes are present
        expect(finalItems.any((i) => i.title == 'Advanced AI 401'), isTrue);
        expect(finalItems.any((i) => i.title == 'Physics Lab'), isTrue);

        // Ensure BaseTimelineSetup is updated
        final updatedSetup = await baseTimelineRepo.fetchSetup('user-a');
        expect(updatedSetup.classBlocks.length, 2);
        expect(updatedSetup.classLogicalAssetR2Key, 'new_class_photo.jpg');
      },
    );

    test(
      'Overlapping blocks (e.g. Class 10-11 and Eating 10:20-10:40) save without conflict errors',
      () async {
        final routineRepo = FakeRoutineRepository();
        final onboardingRepo = FakeOnboardingRepository();
        final baseTimelineRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: onboardingRepo,
        );
        final txRepo = FakeRoutineTransactionRepository(
          routineRepository: routineRepo,
          setupRepository: baseTimelineRepo,
        );

        final coordinator = BaseTimelineTransactionCoordinator(
          routineRepo: routineRepo,
          setupRepo: baseTimelineRepo,
          transactionRepo: txRepo,
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
          updateSetup: (current) => current.copyWith(classBlocks: classBlocks),
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
            eatingSetupPath: 'create',
            eatingBlocks: eatingBlocks,
          ),
        );

        // In Base Timeline re-setup, zero cross-domain conflict validation is enforced:
        // Overlaps are accepted and successfully persisted!
        final allItems = await routineRepo.fetchRoutineItems('user-overlap');
        expect(allItems.length, 2);
        expect(allItems.any((i) => i.title == 'Math Lecture'), isTrue);
        expect(allItems.any((i) => i.title == 'Mid-Morning Snack'), isTrue);
      },
    );
  });

  group('Base Timeline Strict Repeat-Day Invariant & Observable Reconciliation', () {
    test(
      'validatedRepeatDays enforces 1..7, non-empty, unique, max 7, and deterministically sorts',
      () {
        // 1. Valid single day
        const singleDay = TimelineBlockDraft(
          id: 'b1',
          section: 'classes',
          title: 'Single Day',
          startMinute: 600,
          endMinute: 660,
          repeatDays: [3],
          blockType: TimelineBlockDraft.hardBlockKey,
        );
        expect(
          BaseTimelineTransactionCoordinator.validatedRepeatDays(singleDay),
          [3],
        );

        // 2. Valid multiple days (already sorted)
        const sortedDays = TimelineBlockDraft(
          id: 'b2',
          section: 'classes',
          title: 'Sorted Days',
          startMinute: 600,
          endMinute: 660,
          repeatDays: [1, 3, 5],
          blockType: TimelineBlockDraft.hardBlockKey,
        );
        expect(
          BaseTimelineTransactionCoordinator.validatedRepeatDays(sortedDays),
          [1, 3, 5],
        );

        // 3. Unsorted days are deterministically sorted ascending
        const unsortedDays = TimelineBlockDraft(
          id: 'b3',
          section: 'classes',
          title: 'Unsorted Days',
          startMinute: 600,
          endMinute: 660,
          repeatDays: [7, 1, 4, 2],
          blockType: TimelineBlockDraft.hardBlockKey,
        );
        expect(
          BaseTimelineTransactionCoordinator.validatedRepeatDays(unsortedDays),
          [1, 2, 4, 7],
        );

        // 4. Empty repeatDays throws ArgumentError (no silent default to 1..7!)
        const emptyDays = TimelineBlockDraft(
          id: 'b4',
          section: 'classes',
          title: 'Empty Days',
          startMinute: 600,
          endMinute: 660,
          repeatDays: [],
          blockType: TimelineBlockDraft.hardBlockKey,
        );
        expect(
          () =>
              BaseTimelineTransactionCoordinator.validatedRepeatDays(emptyDays),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('must specify at least one repeat day'),
            ),
          ),
        );

        // 5. Duplicate days throw ArgumentError
        const duplicateDays = TimelineBlockDraft(
          id: 'b5',
          section: 'classes',
          title: 'Duplicate Days',
          startMinute: 600,
          endMinute: 660,
          repeatDays: [1, 3, 1],
          blockType: TimelineBlockDraft.hardBlockKey,
        );
        expect(
          () => BaseTimelineTransactionCoordinator.validatedRepeatDays(
            duplicateDays,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('contains duplicate repeat days'),
            ),
          ),
        );

        // 6. Day < 1 (0) throws ArgumentError
        const outOfRangeLow = TimelineBlockDraft(
          id: 'b6',
          section: 'classes',
          title: 'Out of range low',
          startMinute: 600,
          endMinute: 660,
          repeatDays: [0, 2],
          blockType: TimelineBlockDraft.hardBlockKey,
        );
        expect(
          () => BaseTimelineTransactionCoordinator.validatedRepeatDays(
            outOfRangeLow,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('is out of range 1..7'),
            ),
          ),
        );

        // 7. Day > 7 (8) throws ArgumentError
        const outOfRangeHigh = TimelineBlockDraft(
          id: 'b7',
          section: 'classes',
          title: 'Out of range high',
          startMinute: 600,
          endMinute: 660,
          repeatDays: [2, 8],
          blockType: TimelineBlockDraft.hardBlockKey,
        );
        expect(
          () => BaseTimelineTransactionCoordinator.validatedRepeatDays(
            outOfRangeHigh,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('is out of range 1..7'),
            ),
          ),
        );

        // 8. More than 7 days throws ArgumentError
        const moreThanSeven = TimelineBlockDraft(
          id: 'b8',
          section: 'classes',
          title: 'More than seven',
          startMinute: 600,
          endMinute: 660,
          repeatDays: [1, 2, 3, 4, 5, 6, 7, 8],
          blockType: TimelineBlockDraft.hardBlockKey,
        );
        expect(
          () => BaseTimelineTransactionCoordinator.validatedRepeatDays(
            moreThanSeven,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('cannot specify more than 7 repeat days'),
            ),
          ),
        );
      },
    );

    test(
      'replaceSection fails before durable mutation when block repeatDays is invalid',
      () async {
        final routineRepo = FakeRoutineRepository();
        final onboardingRepo = FakeOnboardingRepository();
        final baseTimelineRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: onboardingRepo,
        );
        final txRepo = FakeRoutineTransactionRepository(
          routineRepository: routineRepo,
          setupRepository: baseTimelineRepo,
        );

        final coordinator = BaseTimelineTransactionCoordinator(
          routineRepo: routineRepo,
          setupRepo: baseTimelineRepo,
          transactionRepo: txRepo,
        );

        // Pre-save initial setup at revision 1
        await baseTimelineRepo.saveSetup(
          'user-strict',
          BaseTimelineSetup(
            uid: 'user-strict',
            revision: 1,
            updatedAt: DateTime.now(),
          ),
        );

        // Malformed block with empty repeatDays
        const malformedBlock = TimelineBlockDraft(
          id: 'bad-cls',
          section: 'classes',
          title: 'Invalid Repeat Class',
          startMinute: 600,
          endMinute: 660,
          repeatDays: [],
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        expect(
          () => coordinator.replaceSection(
            uid: 'user-strict',
            section: BaseTimelineSection.classes,
            newBlocks: const [malformedBlock],
            updateSetup: (s) => s.copyWith(classBlocks: const [malformedBlock]),
          ),
          throwsA(isA<ArgumentError>()),
        );

        // Invariant verification: setup was NEVER mutated, revision remains 1, 0 items created
        final setupAfter = await baseTimelineRepo.fetchSetup('user-strict');
        expect(setupAfter.revision, 1);
        expect(setupAfter.classBlocks, isEmpty);

        final routineItemsAfter = await routineRepo.fetchRoutineItems(
          'user-strict',
        );
        expect(routineItemsAfter, isEmpty);
      },
    );

    test(
      'RoutineItem converted from Base Timeline block inherits sorted repeatDays and weekly repeatRule',
      () {
        final now = DateTime.now();
        const block = TimelineBlockDraft(
          id: 'block-1',
          section: 'classes',
          title: 'Discrete Math',
          startMinute: 600,
          endMinute: 660,
          repeatDays: [5, 2], // Unsorted
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        final item =
            BaseTimelineTransactionCoordinator.routineItemForSectionBlock(
              uid: 'user-sort',
              section: BaseTimelineSection.classes,
              block: block,
              index: 0,
              now: now,
            );

        expect(item.repeatDays, [2, 5]); // Deterministically sorted
        expect(item.repeatRule, 'weekly');
        expect(item.source, RoutineSource.baseTimeline);
        expect(item.baseTimelineSection, 'classes');
      },
    );

    test(
      'General one-time routine items with empty repeatDays remain valid and distinct from Base Timeline recurring blocks',
      () {
        final now = DateTime.now();
        // Routine data contract allows one-time items with repeatDays: [] and repeatRule: 'once'
        final oneTimeItem = RoutineItem(
          id: 'one-time-task',
          userId: 'user-1',
          title: 'Doctor Appointment',
          category: RoutineCategory.health,
          blockType: RoutineBlockType.hardBlock,
          startMinute: 720,
          endMinute: 780,
          repeatDays: const [],
          repeatRule: 'once',
          createdAt: now,
          updatedAt: now,
          source: RoutineSource.manual,
        );

        expect(oneTimeItem.repeatDays, isEmpty);
        expect(oneTimeItem.repeatRule, 'once');
        expect(oneTimeItem.source, RoutineSource.manual);
      },
    );

    test(
      'routineItemsForSectionBlocks throws ArgumentError if any block has invalid repeatDays',
      () {
        const invalidBlock = TimelineBlockDraft(
          id: 'bad-block',
          section: 'classes',
          title: 'Corrupted Class',
          startMinute: 600,
          endMinute: 660,
          repeatDays: [0, 1], // 0 is invalid
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        expect(
          () => BaseTimelineTransactionCoordinator.routineItemsForSectionBlocks(
            uid: 'user-corrupted',
            section: BaseTimelineSection.classes,
            blocks: const [invalidBlock],
            now: DateTime.now(),
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test(
      'retryRoutineRefresh guards owner isolation and monotonic revision',
      () async {
        final fakeSetupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: FakeOnboardingRepository(),
        );
        final fakeRoutineRepo = FakeRoutineRepository();
        final fakeTxRepo = FakeRoutineTransactionRepository(
          routineRepository: fakeRoutineRepo,
          setupRepository: fakeSetupRepo,
        );

        final container = ProviderContainer(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: 'active-owner-1',
                    email: 'owner1@optivus.app',
                    displayName: 'Owner One',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(
              fakeSetupRepo,
            ),
            routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
            routineTransactionRepositoryProvider.overrideWithValue(fakeTxRepo),
          ],
        );
        addTearDown(container.dispose);

        final coordinator = container.read(
          baseTimelineTransactionCoordinatorProvider,
        );

        // 1. Calling retryRoutineRefresh for a DIFFERENT owner must be rejected by owner isolation guard
        final staleOwnerResult = await coordinator.retryRoutineRefresh(
          uid: 'stale-owner-999',
        );
        expect(
          staleOwnerResult.status,
          BaseTimelineRoutineRefreshStatus.notAttempted,
        );
        expect(
          staleOwnerResult.message,
          contains('Active session does not match requested owner'),
        );

        // 2. Monotonic guard: Calling retry with older targetRevision than committed revision returns superseded
        const validBlock = TimelineBlockDraft(
          id: 'b-ok',
          section: 'work',
          title: 'Deep Work',
          startMinute: 540,
          endMinute: 600,
          repeatDays: [1, 2, 3],
          blockType: TimelineBlockDraft.hardBlockKey,
        );
        // Perform replaceSection for active-owner-1 to establish revision 2
        final replaceRes = await coordinator.replaceSection(
          uid: 'active-owner-1',
          section: BaseTimelineSection.work,
          newBlocks: const [validBlock],
          updateSetup: (s) => s.copyWith(workBlocks: const [validBlock]),
        );
        expect(replaceRes.revision, 2);

        // Retry targeting revision 1 (older than committed revision 2)
        final olderRevResult = await coordinator.retryRoutineRefresh(
          uid: 'active-owner-1',
          targetRevision: 1,
        );
        expect(
          olderRevResult.message,
          contains('Superseded by newer revision'),
        );
      },
    );
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
        r2Key: 'users/user-test/onboarding/classes_preview.jpg',
        status: UploadedAssetStatus.uploaded,
        createdAt: now,
        updatedAt: now,
      );

      // First call: fetches token and preview URL
      final uri1 = await resolver.resolvePreview(
        uid: 'user-test',
        asset: asset,
      );
      expect(uri1, isNotNull);
      expect(
        uri1.toString(),
        contains(
          'https://preview.local/users/user-test/onboarding/classes_preview.jpg',
        ),
      );
      expect(tokenFetchCount, 1);

      // Second call: in-memory cache hit, does not call getIdToken again
      final uri2 = await resolver.resolvePreview(
        uid: 'user-test',
        asset: asset,
      );
      expect(uri2, uri1);
      expect(tokenFetchCount, 1); // Remains 1 due to cache hit
    });

    test(
      'Returns null gracefully when asset has no r2Key or client errors',
      () async {
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

        final uri = await resolver.resolvePreview(
          uid: 'user-test',
          asset: emptyAsset,
        );
        expect(uri, isNull);
      },
    );

    test(
      'Denies cross-user key resolution and isolates cache by UID',
      () async {
        final fakeClient = FakeR2UploadClient();
        var tokenFetchCount = 0;
        final resolver = AuthenticatedR2PreviewResolver(
          client: fakeClient,
          getIdToken: () async {
            tokenFetchCount++;
            return 'valid-token';
          },
        );

        // Attempt to resolve another user's key with user-1 UID
        final deniedUri = await resolver.resolveR2Key(
          uid: 'user-1',
          r2Key: 'users/other-user/onboarding/photo.jpg',
        );
        expect(deniedUri, isNull);
        expect(
          tokenFetchCount,
          0,
        ); // Denied before fetching token or calling worker

        // Resolving legitimately owned key works
        final allowedUri = await resolver.resolveR2Key(
          uid: 'user-1',
          r2Key: 'users/user-1/onboarding/photo.jpg',
        );
        expect(allowedUri, isNotNull);
        expect(tokenFetchCount, 1);

        // Clearing cache forces re-fetch
        resolver.clearCache();
        final refetchedUri = await resolver.resolveR2Key(
          uid: 'user-1',
          r2Key: 'users/user-1/onboarding/photo.jpg',
        );
        expect(refetchedUri, isNotNull);
        expect(tokenFetchCount, 2);
      },
    );
  });

  group('Base Timeline Provenance and Item Isolation Tests', () {
    test(
      'replaceSection assigns RoutineSource.baseTimeline, section tag, and tracks IDs',
      () async {
        final routineRepo = FakeRoutineRepository();
        final onboardingRepo = FakeOnboardingRepository();
        final baseTimelineRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: onboardingRepo,
        );
        final txRepo = FakeRoutineTransactionRepository(
          routineRepository: routineRepo,
          setupRepository: baseTimelineRepo,
        );
        final coordinator = BaseTimelineTransactionCoordinator(
          routineRepo: routineRepo,
          setupRepo: baseTimelineRepo,
          transactionRepo: txRepo,
        );

        final blocks = <TimelineBlockDraft>[
          const TimelineBlockDraft(
            id: 'c1',
            section: 'classes',
            title: 'Bio 101',
            startMinute: 600,
            endMinute: 660,
            repeatDays: [1, 3],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ];

        await coordinator.replaceSection(
          uid: 'user-provenance',
          section: BaseTimelineSection.classes,
          newBlocks: blocks,
          updateSetup: (current) => current.copyWith(classBlocks: blocks),
        );

        final items = await routineRepo.fetchRoutineItems('user-provenance');
        expect(items.length, 1);
        final item = items.first;
        expect(item.source, RoutineSource.baseTimeline);
        expect(item.baseTimelineSection, 'classes');
        expect(item.title, 'Bio 101');

        final setup = await baseTimelineRepo.fetchSetup('user-provenance');
        expect(setup.classRoutineItemIds, contains(item.id));
      },
    );

    test(
      'replaceSection strictly protects RoutineSource.imported and RoutineSource.manual items',
      () async {
        final routineRepo = FakeRoutineRepository();
        final onboardingRepo = FakeOnboardingRepository();
        final baseTimelineRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: onboardingRepo,
        );
        final txRepo = FakeRoutineTransactionRepository(
          routineRepository: routineRepo,
          setupRepository: baseTimelineRepo,
        );
        final coordinator = BaseTimelineTransactionCoordinator(
          routineRepo: routineRepo,
          setupRepo: baseTimelineRepo,
          transactionRepo: txRepo,
        );

        // Pre-seed an imported meal and a manual habit
        final importedMeal = RoutineItem(
          id: 'imported-meal-1',
          userId: 'user-protect',
          title: 'Imported Keto Lunch',
          category: RoutineCategory.eating,
          blockType: RoutineBlockType.softBlock,
          startMinute: 720,
          endMinute: 760,
          repeatDays: const [1, 2, 3, 4, 5],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          source: RoutineSource.imported,
        );

        final manualItem = RoutineItem(
          id: 'manual-task-1',
          userId: 'user-protect',
          title: 'Call Family',
          category: RoutineCategory.habit,
          blockType: RoutineBlockType.softBlock,
          startMinute: 1200,
          endMinute: 1230,
          repeatDays: const [7],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          source: RoutineSource.manual,
        );

        await routineRepo.createRoutineItem('user-protect', importedMeal);
        await routineRepo.createRoutineItem('user-protect', manualItem);

        // Now re-setup Eating section
        final newEatingBlocks = <TimelineBlockDraft>[
          const TimelineBlockDraft(
            id: 'meal-new-1',
            section: 'eating',
            title: 'New Breakfast',
            startMinute: 480,
            endMinute: 510,
            repeatDays: [1, 2, 3, 4, 5, 6, 7],
            blockType: TimelineBlockDraft.softBlockKey,
          ),
        ];

        await coordinator.replaceSection(
          uid: 'user-protect',
          section: BaseTimelineSection.eating,
          newBlocks: newEatingBlocks,
          updateSetup: (current) =>
              current.copyWith(eatingBlocks: newEatingBlocks),
        );

        final items = await routineRepo.fetchRoutineItems('user-protect');
        // Must contain: new breakfast + imported meal + manual task = 3 items
        expect(items.length, 3);
        expect(
          items.any(
            (i) =>
                i.id == 'imported-meal-1' && i.source == RoutineSource.imported,
          ),
          isTrue,
        );
        expect(
          items.any(
            (i) => i.id == 'manual-task-1' && i.source == RoutineSource.manual,
          ),
          isTrue,
        );
        expect(
          items.any(
            (i) =>
                i.title == 'New Breakfast' &&
                i.source == RoutineSource.baseTimeline,
          ),
          isTrue,
        );
      },
    );

    test(
      'Atomic transaction failure rolls back both items and BaseTimelineSetup',
      () async {
        final routineRepo = FakeRoutineRepository();
        final onboardingRepo = FakeOnboardingRepository();
        final baseTimelineRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: onboardingRepo,
        );
        final txRepo = FakeRoutineTransactionRepository(
          routineRepository: routineRepo,
          setupRepository: baseTimelineRepo,
        );

        final coordinator = BaseTimelineTransactionCoordinator(
          routineRepo: routineRepo,
          setupRepo: baseTimelineRepo,
          transactionRepo: txRepo,
        );

        // Pre-seed an existing class item and setup doc
        final initialItem = RoutineItem(
          id: 'initial-class',
          userId: 'user-rollback',
          title: 'Initial Class',
          category: RoutineCategory.classBlock,
          blockType: RoutineBlockType.hardBlock,
          startMinute: 600,
          endMinute: 660,
          repeatDays: const [1],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          source: RoutineSource.baseTimeline,
          baseTimelineSection: 'classes',
        );
        await routineRepo.createRoutineItem('user-rollback', initialItem);

        final initialSetup = BaseTimelineSetup(
          uid: 'user-rollback',
          updatedAt: DateTime.now(),
          classRoutineItemIds: const ['initial-class'],
          classBlocks: const [
            TimelineBlockDraft(
              id: 'c-init',
              section: 'classes',
              title: 'Initial Class',
              startMinute: 600,
              endMinute: 660,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );
        await baseTimelineRepo.saveSetup('user-rollback', initialSetup);

        // Simulate a failure in commitWrite
        txRepo.onBeforeMutation = () async {
          throw StateError('Firestore commit failure simulated');
        };

        final newBlocks = <TimelineBlockDraft>[
          const TimelineBlockDraft(
            id: 'c-new',
            section: 'classes',
            title: 'Failing New Class',
            startMinute: 700,
            endMinute: 760,
            repeatDays: [2],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ];

        expect(
          () async => coordinator.replaceSection(
            uid: 'user-rollback',
            section: BaseTimelineSection.classes,
            newBlocks: newBlocks,
            updateSetup: (current) => current.copyWith(classBlocks: newBlocks),
          ),
          throwsA(isA<StateError>()),
        );

        // Verify that initial item was NOT deleted, and new item was NOT created
        final itemsAfterRollback = await routineRepo.fetchRoutineItems(
          'user-rollback',
        );
        expect(itemsAfterRollback.length, 1);
        expect(itemsAfterRollback.first.id, 'initial-class');
        expect(itemsAfterRollback.first.title, 'Initial Class');

        // Verify that setup was NOT changed
        final setupAfterRollback = await baseTimelineRepo.fetchSetup(
          'user-rollback',
        );
        expect(setupAfterRollback.classBlocks.first.title, 'Initial Class');
        expect(setupAfterRollback.classRoutineItemIds, const ['initial-class']);
      },
    );
  });

  group('SkinCareDomainEngine Tests', () {
    test('analyzeProducts uses client and returns detected products', () async {
      const client = FakeSkinCareAiClient();
      final engine = SkinCareDomainEngine(client: client);

      final result = await engine.analyzeProducts(
        uid: 'user-skin',
        idToken: 'token',
        productPhotos: ['r2/photo1.jpg'],
      );

      expect(result.hasError, isFalse);
      expect(result.detectedProducts.length, 1);
      expect(result.detectedProducts.first.name, 'Fake Cleanser');
      expect(result.detectedProducts.first.category, 'cleanser');
    });

    test(
      'generateRoutineFromProducts schedules routines anchored around bath',
      () async {
        const client = FakeSkinCareAiClient();
        final engine = SkinCareDomainEngine(client: client);

        final detected = [
          const SkinCareDetectedProduct(
            name: 'Fake Cleanser',
            category: 'cleanser',
          ),
          const SkinCareDetectedProduct(
            name: 'Moisturizer',
            category: 'moisturizer',
          ),
          const SkinCareDetectedProduct(
            name: 'Sunscreen',
            category: 'sunscreen',
          ),
        ];

        final baseTimeline = BaseTimelineDraft(
          blocks: [
            const TimelineBlockDraft(
              id: BaseTimelineDraft.fixedBathId,
              section: 'fixed',
              title: 'Bath',
              startMinute: 450, // 7:30 AM
              endMinute: 480, // 8:00 AM
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );

        final blocks = await engine.generateRoutineFromProducts(
          uid: 'user-skin',
          idToken: 'token',
          products: detected,
          skinType: 'Combination',
          problems: const ['acne'],
          desiredApplicationsPerDay: 2,
          baseTimeline: baseTimeline,
        );

        expect(blocks.isNotEmpty, isTrue);
        expect(blocks.every((b) => b.section == 'skin_care'), isTrue);
      },
    );

    test(
      'generateBuildForMeRoutine schedules routine without pre-existing products',
      () async {
        const client = FakeSkinCareAiClient();
        final engine = SkinCareDomainEngine(client: client);

        final result = await engine.generateBuildForMeRoutine(
          uid: 'user-skin-build',
          idToken: 'token',
          skinType: 'Dry',
          problems: const ['dryness'],
          desiredApplicationsPerDay: 2,
          baseTimeline: const BaseTimelineDraft(),
        );

        expect(result.blocks.isNotEmpty, isTrue);
        expect(result.blocks.every((b) => b.section == 'skin_care'), isTrue);
      },
    );
  });

  group('EatingDomainEngine Tests', () {
    test('calculateTargets and buildInputs compute canonical targets', () {
      final engine = EatingDomainEngine(client: const _TestNutritionAiClient());
      final profile = UserProfile(
        uid: 'user-nutrition',
        email: 'user-nutrition@optivus.local',
        displayName: 'Test User',
        weight: 70,
        height: 175,
        gender: 'male',
        ageRange: '25-34',
        exerciseLevel: 'moderate',
        lifeRole: 'professional',
      );
      final setup = BaseTimelineSetup(
        uid: 'user-nutrition',
        updatedAt: DateTime.now(),
        mealPlanningGoal: 'maintain',
        mealsPerDay: 3,
        foodType: 'Balanced',
      );

      final targets = engine.calculateTargets(profile: profile, setup: setup);
      expect(targets.targetCalories, isNotNull);
      expect(targets.proteinTarget, isNotNull);

      final inputs = engine.buildInputs(
        profile: profile,
        setup: setup,
        targets: targets,
      );
      expect(inputs.mealsPerDay, 3);
      expect(inputs.targetMode, 'maintenance');
    });

    test(
      'generateEatingRoutine generates and validates 7-day diverse meal plan',
      () async {
        final engine = EatingDomainEngine(
          client: const _TestNutritionAiClient(),
        );
        final profile = UserProfile(
          uid: 'user-eating-gen',
          email: 'user-eating-gen@optivus.local',
          displayName: 'Test User',
          weight: 70,
          height: 175,
          gender: 'male',
          ageRange: '25-34',
        );
        final setup = BaseTimelineSetup(
          uid: 'user-eating-gen',
          updatedAt: DateTime.now(),
          mealPlanningGoal: 'maintain',
          mealsPerDay: 3,
          foodType: 'Balanced',
        );

        final targets = engine.calculateTargets(profile: profile, setup: setup);
        final inputs = engine.buildInputs(
          profile: profile,
          setup: setup,
          targets: targets,
        );

        final blocks = await engine.generateEatingRoutine(
          uid: 'user-eating-gen',
          idToken: 'token',
          inputs: inputs,
          targets: targets,
          baseTimeline: const BaseTimelineDraft(),
        );

        expect(blocks.isNotEmpty, isTrue);
        expect(blocks.every((b) => b.section == 'eating'), isTrue);
        // Ensure breakfast, lunch, and dinner blocks were mapped
        final titles = blocks.map((b) => b.title.toLowerCase()).toSet();
        expect(titles.any((t) => t.contains('breakfast')), isTrue);
        expect(titles.any((t) => t.contains('lunch')), isTrue);
        expect(titles.any((t) => t.contains('dinner')), isTrue);
      },
    );
  });
}

class _TestNutritionAiClient implements NutritionAiClient {
  const _TestNutritionAiClient();

  @override
  Future<RoutineImportExtractionResult> generateEatingRoutine({
    required String uid,
    required String idToken,
    required Map<String, dynamic> params,
  }) async {
    final int mealsPerDay = (params['mealsPerDay'] as num?)?.round() ?? 3;
    final int targetCalories =
        (params['targetCalories'] as num?)?.round() ?? 2000;
    final int proteinTarget = (params['proteinTarget'] as num?)?.round() ?? 130;

    final mealCal = (targetCalories / mealsPerDay).round();
    final mealPro = (proteinTarget / mealsPerDay).round();

    final slotDefs = [
      ('breakfast', 'Breakfast', 8 * 60, 30),
      ('lunch', 'Lunch', 13 * 60, 45),
      ('dinner', 'Dinner', 20 * 60, 45),
    ];

    final dishLibrary = {
      'breakfast': [
        ['Oatmeal', 'Banana'],
        ['Avocado Toast', 'Tofu Scramble'],
        ['Smoothie Bowl', 'Granola'],
        ['Poha', 'Sprouts'],
        ['Besan Chilla', 'Mint Chutney'],
        ['Idli', 'Sambar'],
        ['Pancakes', 'Berries'],
      ],
      'lunch': [
        ['Rice Bowl', 'Dal Curry'],
        ['Quinoa Salad', 'Chickpeas'],
        ['Wrap', 'Hummus'],
        ['Millet Bowl', 'Sambar'],
        ['Rajma', 'Rice'],
        ['Curd Rice', 'Beans'],
        ['Chole', 'Rice'],
      ],
      'dinner': [
        ['Roti', 'Paneer'],
        ['Brown Rice', 'Lentils'],
        ['Khichdi', 'Veggies'],
        ['Chapati', 'Mushroom'],
        ['Stew', 'Rice'],
        ['Palak Paneer', 'Roti'],
        ['Veg Biryani', 'Raita'],
      ],
    };

    final candidates = <RoutineImportCandidateBlock>[];
    for (var d = 1; d <= 7; d++) {
      for (final slot in slotDefs) {
        final slotId = slot.$1;
        final title = slot.$2;
        final start = slot.$3;
        final duration = slot.$4;
        final dishes = dishLibrary[slotId]?[d - 1] ?? ['Dish A', 'Dish B'];

        candidates.add(
          RoutineImportCandidateBlock(
            id: 'ai-gen-d$d-$slotId',
            mealSlot: slotId,
            title: title,
            startMinute: start,
            endMinute: start + duration,
            hasFixedTime: true,
            repeatDays: [d],
            blockType: TimelineBlockDraft.softBlockKey,
            category: 'eating',
            hardBlock: false,
            selected: true,
            candidateType: RoutineImportCandidateType.block,
            confidenceScore: 0.95,
            confidenceLabel: 'high',
            extractionEngine: 'test',
            extractionVersion: 'phase2d',
            needsManualReview: false,
            steps: dishes,
            mealCategory: slotId,
            caloriesEstimate: mealCal.toDouble(),
            proteinEstimate: mealPro.toDouble(),
          ),
        );
      }
    }

    return RoutineImportExtractionResult(
      id: 'ext-generated-eating',
      uid: uid,
      source: RoutineImportReviewSource.eating,
      createdAt: DateTime.now(),
      candidates: candidates,
      warnings: const [],
    );
  }
}
