import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';

void main() {
  group('Base Timeline Onboarding Migration and Builder Tests', () {
    test(
      'fromOnboardingCompletion builds rich setup with schemaVersion 2 and revision 1',
      () {
        const uid = 'user-onboarding-build';
        final now = DateTime.now();
        final draft = OnboardingDraft(
          uid: uid,
          bodyBasics: const BodyBasicsDraft(
            weightKg: 75.0,
            heightCm: 175.0,
            ageRange: '25-34',
            gender: 'male',
          ),
          lifeRole: const LifeRoleDraft(
            exerciseLevel: 'moderate',
            lifeRole: 'student',
          ),
          baseTimeline: BaseTimelineDraft(
            pendingFutureImports: [
              PendingFutureImportDraft(
                id: 'imp-classes',
                section: 'classes',
                mode: 'photo',
                uploadedAssetId: 'class-asset-1',
                uploadedAssetR2Key:
                    'users/user-onboarding-build/onboarding/class/c1.jpg',
                createdAt: now,
              ),
              PendingFutureImportDraft(
                id: 'imp-eating',
                section: 'eating',
                mode: 'photo',
                uploadedAssetId: 'eat-asset-1',
                uploadedAssetR2Key:
                    'users/user-onboarding-build/onboarding/eating/e1.jpg',
                createdAt: now,
              ),
            ],
            mealPlanningGoal: 'build_muscle',
            mealsPerDay: 4,
            foodType: 'High Protein',
            skinCareSetupPath: 'products',
            skinCareProductNames: 'Toner, Serum, Moisturizer',
            skinCareProductPhotoAssetId: 'skin-asset-1',
            skinCareProductPhotoR2Key:
                'users/user-onboarding-build/onboarding/skin/s1.jpg',
          ),
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
              title: 'Chemistry 101',
              startMinute: 540,
              endMinute: 600,
              repeatDays: [1, 3],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
            TimelineBlockDraft(
              id: 'j1',
              section: 'job_work_business',
              title: 'Engineering Shift',
              startMinute: 660,
              endMinute: 780,
              repeatDays: [1, 2, 3, 4, 5],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
            TimelineBlockDraft(
              id: BaseTimelineDraft.fixedSleepId,
              section: 'fixed',
              title: 'Sleep',
              startMinute: 1380,
              endMinute: 390,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
            TimelineBlockDraft(
              id: BaseTimelineDraft.fixedBathId,
              section: 'fixed',
              title: 'Bath',
              startMinute: 1260,
              endMinute: 1280,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
          finalTimelineItems: const [],
          routineItemsForApp: [
            RoutineItem(
              id: 'class-item-1',
              userId: uid,
              title: 'Chemistry 101',
              category: RoutineCategory.classBlock,
              blockType: RoutineBlockType.hardBlock,
              startMinute: 540,
              endMinute: 600,
              repeatDays: const [1, 3],
              createdAt: now,
              updatedAt: now,
              source: RoutineSource.onboarding,
            ),
            RoutineItem(
              id: 'work-item-1',
              userId: uid,
              title: 'Engineering Shift',
              category: RoutineCategory.job,
              blockType: RoutineBlockType.hardBlock,
              startMinute: 660,
              endMinute: 780,
              repeatDays: const [1, 2, 3, 4, 5],
              createdAt: now,
              updatedAt: now,
              source: RoutineSource.onboarding,
            ),
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

        final setup = BaseTimelineSetup.fromOnboardingCompletion(
          finalDraft: draft,
          bundle: bundle,
        );

        expect(setup.uid, uid);
        expect(setup.schemaVersion, 2);
        expect(setup.revision, 1);
        expect(setup.classLogicalAssetId, 'class-asset-1');
        expect(
          setup.classLogicalAssetR2Key,
          'users/user-onboarding-build/onboarding/class/c1.jpg',
        );
        expect(setup.eatingPhotoAssetId, 'eat-asset-1');
        expect(setup.targetCalories, isNotNull);
        expect(setup.targetProtein, isNotNull);
        expect(setup.skinCareProductNames, 'Toner, Serum, Moisturizer');
        expect(setup.classRoutineItemIds, contains('class-item-1'));
        expect(setup.workRoutineItemIds, contains('work-item-1'));

        final sleepBlock = setup.fixedBlocks.firstWhere(
          (b) => b.id == BaseTimelineDraft.fixedSleepId,
        );
        expect(sleepBlock.startMinute, 1380);
        expect(sleepBlock.endMinute, 390);

        final bathBlock = setup.fixedBlocks.firstWhere(
          (b) => b.id == BaseTimelineDraft.fixedBathId,
        );
        expect(bathBlock.startMinute, 1260);
      },
    );

    test(
      'migrateBaseTimelineSetupIfNeeded backfills unconfigured sections but protects post-onboarding edits',
      () async {
        const uid = 'user-partial-migration';
        final now = DateTime.now();
        final onboardingRepo = FakeOnboardingRepository();
        final setupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: onboardingRepo,
        );

        // 1. Seed completed onboarding bundle in onboardingRepo
        final bundle = OnboardingCompletionBundle(
          uid: uid,
          createdAt: now,
          updatedAt: now,
          userProfilePatch: const {},
          baseTimelineBlocks: const [
            TimelineBlockDraft(
              id: 'c-onboard',
              section: 'classes',
              title: 'Onboarding Chemistry',
              startMinute: 540,
              endMinute: 600,
              repeatDays: [1, 3],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
            TimelineBlockDraft(
              id: 'j-onboard',
              section: 'job_work_business',
              title: 'Onboarding Job',
              startMinute: 700,
              endMinute: 800,
              repeatDays: [1, 2, 3],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
          finalTimelineItems: const [],
          routineItemsForApp: [
            RoutineItem(
              id: 'onboarding-class-item',
              userId: uid,
              title: 'Onboarding Chemistry',
              category: RoutineCategory.classBlock,
              blockType: RoutineBlockType.hardBlock,
              startMinute: 540,
              endMinute: 600,
              repeatDays: const [1, 3],
              createdAt: now,
              updatedAt: now,
              source: RoutineSource.onboarding,
            ),
            RoutineItem(
              id: 'onboarding-work-item',
              userId: uid,
              title: 'Onboarding Job',
              category: RoutineCategory.job,
              blockType: RoutineBlockType.hardBlock,
              startMinute: 700,
              endMinute: 800,
              repeatDays: const [1, 2, 3],
              createdAt: now,
              updatedAt: now,
              source: RoutineSource.onboarding,
            ),
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

        // 2. User has an existing schemaVersion 1 setup with post-onboarding custom classes:
        // classBlocks was edited by user post-onboarding!
        // but workBlocks is empty (unconfigured).
        final v1Setup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          schemaVersion: 1,
          revision: 5, // user had 5 revisions post-onboarding
          classBlocks: const [
            TimelineBlockDraft(
              id: 'custom-class-edited',
              section: 'classes',
              title: 'Custom Post-Onboarding Class',
              startMinute: 600,
              endMinute: 660,
              repeatDays: [2, 4],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
          classRoutineItemIds: const ['custom-class-item-id'],
          workBlocks: const [], // empty -> unconfigured
          workRoutineItemIds: const [],
        );
        await setupRepo.saveSetup(uid, v1Setup);

        // 3. Trigger migration via setup repository
        final migrated = await setupRepo.fetchSetup(uid);

        // MUST be upgraded to schemaVersion 2
        expect(migrated.schemaVersion, 2);
        // Revision must be preserved >= 5
        expect(migrated.revision, 5);

        // POST-ONBOARDING EDITED SECTION MUST BE PRESERVED!
        expect(migrated.classBlocks.length, 1);
        expect(migrated.classBlocks.first.id, 'custom-class-edited');
        expect(
          migrated.classBlocks.first.title,
          'Custom Post-Onboarding Class',
        );
        expect(migrated.classRoutineItemIds, const ['custom-class-item-id']);

        // UNCONFIGURED SECTION BACKFILLED FROM ONBOARDING
        expect(migrated.workBlocks.isNotEmpty, isTrue);
        expect(migrated.workBlocks.first.title, 'Onboarding Job');
        expect(migrated.workRoutineItemIds, contains('onboarding-work-item'));
      },
    );

    test(
      'fromMap defaults unversioned documents to schemaVersion 1 and revision 1',
      () {
        final legacyMap = <String, dynamic>{
          'uid': 'legacy-user',
          'updatedAt': DateTime.now().toIso8601String(),
          'mealPlanningGoal': 'maintain',
        };

        final setup = BaseTimelineSetup.fromMap(legacyMap, uid: 'legacy-user');
        expect(setup.schemaVersion, 1);
        expect(setup.revision, 1);
      },
    );
  });
}
