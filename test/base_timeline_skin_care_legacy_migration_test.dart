import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';

void main() {
  group('Base Timeline Skin Care Legacy Migration Tests', () {
    test(
      'legacy has_products in repository is normalized to products and rewritten durably',
      () async {
        const uid = 'legacy-has-products-user';
        final now = DateTime.utc(2026, 3, 1);
        final initialMap = <String, dynamic>{
          'uid': uid,
          'schemaVersion': BaseTimelineSetup.currentSchemaVersion,
          'revision': 1,
          'updatedAt': now.toIso8601String(),
          'skinCareSetupPath': 'has_products',
          'skinCareProductNames': 'Cleanser, Moisturizer',
          'skinCareProductPhotoAssetId': 'skin-asset-1',
          'skinCareProductPhotoR2Key': 'r2/skin1.jpg',
        };

        // 1. fromMap normalizes legacy has_products to products
        final rawSetup = BaseTimelineSetup.fromMap(initialMap, uid: uid);
        expect(rawSetup.skinCareSetupPath, 'products');

        // 2. Seed repository with an unmigrated legacy setup
        final setupRepo = FakeBaseTimelineSetupRepository();
        final legacySetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: now,
          schemaVersion: BaseTimelineSetup.currentSchemaVersion,
          revision: 1,
          skinCareSetupPath: 'has_products',
          skinCareProductNames: 'Cleanser, Moisturizer',
          skinCareProductPhotoAssetId: 'skin-asset-1',
          skinCareProductPhotoR2Key: 'r2/skin1.jpg',
        );
        setupRepo.seedSetup(legacySetup);

        // 3. fetchSetup normalizes and rewrites durably
        final loaded = await setupRepo.fetchSetup(uid);
        expect(loaded.skinCareSetupPath, 'products');
        expect(loaded.skinCareProductNames, 'Cleanser, Moisturizer');
        expect(loaded.revision, 2);

        // 4. Verify backing store retains normalized value and revision
        final stored = await setupRepo.fetchSetup(uid);
        expect(stored.skinCareSetupPath, 'products');
        expect(stored.revision, 2); // Idempotent: no unnecessary revision bump
      },
    );

    test(
      'legacy no_products in repository is normalized to build_for_me and rewritten durably',
      () async {
        const uid = 'legacy-no-products-user';
        final now = DateTime.utc(2026, 3, 1);
        final initialMap = <String, dynamic>{
          'uid': uid,
          'schemaVersion': BaseTimelineSetup.currentSchemaVersion,
          'revision': 1,
          'updatedAt': now.toIso8601String(),
          'skinCareSetupPath': 'no_products',
          'skinCareSkinType': 'oily',
          'skinCareProblems': ['acne', 'pores'],
          'skinCareBudget': 'medium',
          'skinCarePreference': 'minimal',
        };

        // 1. fromMap normalizes legacy no_products to build_for_me
        final rawSetup = BaseTimelineSetup.fromMap(initialMap, uid: uid);
        expect(rawSetup.skinCareSetupPath, 'build_for_me');

        final setupRepo = FakeBaseTimelineSetupRepository();
        final legacySetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: now,
          schemaVersion: BaseTimelineSetup.currentSchemaVersion,
          revision: 1,
          skinCareSetupPath: 'no_products',
          skinCareSkinType: 'oily',
          skinCareProblems: const ['acne', 'pores'],
          skinCareBudget: 'medium',
          skinCarePreference: 'minimal',
        );
        setupRepo.seedSetup(legacySetup);

        final loaded = await setupRepo.fetchSetup(uid);
        expect(loaded.skinCareSetupPath, 'build_for_me');
        expect(loaded.skinCareSkinType, 'oily');
        expect(loaded.revision, 2);

        final stored = await setupRepo.fetchSetup(uid);
        expect(stored.skinCareSetupPath, 'build_for_me');
        expect(stored.revision, 2);
      },
    );

    test(
      'skip path remains skip and does not trigger migration or revision bump',
      () async {
        const uid = 'skip-skin-care-user';
        final now = DateTime.utc(2026, 3, 1);
        final initialMap = <String, dynamic>{
          'uid': uid,
          'schemaVersion': BaseTimelineSetup.currentSchemaVersion,
          'revision': 1,
          'updatedAt': now.toIso8601String(),
          'skinCareSetupPath': 'skip',
          'skinCareSkipped': true,
        };

        final setup = BaseTimelineSetup.fromMap(initialMap, uid: uid);
        expect(setup.skinCareSetupPath, 'skip');
        expect(setup.skinCareSkipped, isTrue);

        final setupRepo = FakeBaseTimelineSetupRepository();
        setupRepo.seedSetup(setup);

        final loaded = await setupRepo.fetchSetup(uid);
        expect(loaded.skinCareSetupPath, 'skip');
        expect(loaded.skinCareSkipped, isTrue);
        expect(loaded.revision, 1);
      },
    );

    test(
      'canonical products and build_for_me do not trigger unnecessary rewrites',
      () async {
        const uid = 'canonical-user';
        final now = DateTime.utc(2026, 3, 1);
        final initialMap = <String, dynamic>{
          'uid': uid,
          'schemaVersion': BaseTimelineSetup.currentSchemaVersion,
          'revision': 3,
          'updatedAt': now.toIso8601String(),
          'skinCareSetupPath': 'products',
          'skinCareProductNames': 'Toner, Serum',
        };

        final setupRepo = FakeBaseTimelineSetupRepository();
        final setup = BaseTimelineSetup.fromMap(initialMap, uid: uid);
        setupRepo.seedSetup(setup);

        final loaded = await setupRepo.fetchSetup(uid);
        expect(loaded.skinCareSetupPath, 'products');
        expect(loaded.revision, 3);
      },
    );

    test(
      'unknown skin care setup path safely throws validation error',
      () {
        const uid = 'unknown-path-user';
        final initialMap = <String, dynamic>{
          'uid': uid,
          'schemaVersion': BaseTimelineSetup.currentSchemaVersion,
          'revision': 1,
          'skinCareSetupPath': 'unsupported_custom_path',
        };

        expect(
          () => BaseTimelineSetup.fromMap(initialMap, uid: uid),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test(
      'legacy onboarding completion bundle with has_products migrates safely',
      () {
        const uid = 'bundle-has-products-user';
        final now = DateTime.utc(2026, 3, 1);
        final draft = OnboardingDraft(
          uid: uid,
          baseTimeline: const BaseTimelineDraft(
            skinCareSetupPath: 'has_products',
            skinCareProductNames: 'Retinol, Moisturizer',
          ),
        );
        final bundle = OnboardingCompletionBundle(
          uid: uid,
          createdAt: now,
          updatedAt: now,
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
        );

        final setup = BaseTimelineSetup.fromOnboardingCompletion(
          finalDraft: draft,
          bundle: bundle,
          projectedRoutineItems: const [],
        );

        expect(setup.skinCareSetupPath, 'products');
        expect(setup.skinCareProductNames, 'Retinol, Moisturizer');

        // Also test fromOnboardingDraft
        final draftSetup = BaseTimelineSetup.fromOnboardingDraft(
          uid,
          draft,
        );
        expect(draftSetup.skinCareSetupPath, 'products');
        expect(draftSetup.skinCareProductNames, 'Retinol, Moisturizer');
      },
    );

    test(
      'legacy onboarding completion bundle with no_products migrates safely',
      () {
        const uid = 'bundle-no-products-user';
        final now = DateTime.utc(2026, 3, 1);
        final draft = OnboardingDraft(
          uid: uid,
          baseTimeline: const BaseTimelineDraft(
            skinCareSetupPath: 'no_products',
            skinCareSkinType: 'dry',
            skinCareProblems: ['dryness'],
          ),
        );
        final bundle = OnboardingCompletionBundle(
          uid: uid,
          createdAt: now,
          updatedAt: now,
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
        );

        final setup = BaseTimelineSetup.fromOnboardingCompletion(
          finalDraft: draft,
          bundle: bundle,
          projectedRoutineItems: const [],
        );

        expect(setup.skinCareSetupPath, 'build_for_me');
        expect(setup.skinCareSkinType, 'dry');

        // Also test fromOnboardingDraft
        final draftSetup = BaseTimelineSetup.fromOnboardingDraft(
          uid,
          draft,
        );
        expect(draftSetup.skinCareSetupPath, 'build_for_me');
        expect(draftSetup.skinCareSkinType, 'dry');
      },
    );

    test(
      'restart after migration loads cleanly without errors or redundant rewrite',
      () async {
        const uid = 'restart-user';
        final now = DateTime.utc(2026, 3, 1);

        final setupRepo = FakeBaseTimelineSetupRepository();
        final legacySetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: now,
          schemaVersion: BaseTimelineSetup.currentSchemaVersion,
          revision: 1,
          skinCareSetupPath: 'has_products',
          skinCareProductNames: 'Cleanser',
        );
        setupRepo.seedSetup(legacySetup);

        // 1. First fetch triggers migration & rewrite
        final firstFetch = await setupRepo.fetchSetup(uid);
        expect(firstFetch.skinCareSetupPath, 'products');
        expect(firstFetch.revision, 2);

        // 2. Simulated app restart: create a new repository instance pointing to the updated state
        final storedSetup = (await setupRepo.fetchSetup(uid));
        final restartedRepo = FakeBaseTimelineSetupRepository();
        restartedRepo.seedSetup(storedSetup);

        final restartFetch = await restartedRepo.fetchSetup(uid);
        expect(restartFetch.skinCareSetupPath, 'products');
        expect(restartFetch.revision, 2);
      },
    );
  });
}
