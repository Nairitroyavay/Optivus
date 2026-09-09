import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/onboarding_step_id.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/skin_care_product_draft.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/services/onboarding_resume_validator.dart';
import 'package:optivus/services/onboarding_upload_source_reconciler.dart';
import 'package:optivus/services/session_destination_resolver.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/upload_state.dart';

void main() {
  const testUid = 'g4-restore-test-uid';

  group('Gate 4: Step 0 through 13 Durable Restore Matrix', () {
    test('Step 0 (welcome) completed restores to Step 1 (patience)', () {
      final draft = _validDraftAt(testUid, 1);
      final validation = validateOnboardingResume(draft);
      expect(validation.resumeStep, 1);
      expect(
        validation.reason,
        OnboardingResumeValidationReason.durableCompletionNotRecorded,
      );
    });

    test(
      'Step 1 (patience pledge) completed restores to Step 2 (role / lifestyle)',
      () {
        final draft = _validDraftAt(testUid, 2);
        final validation = validateOnboardingResume(draft);
        expect(validation.resumeStep, 2);
        expect(
          validation.reason,
          OnboardingResumeValidationReason.durableCompletionNotRecorded,
        );
      },
    );

    test(
      'Step 2 (role / lifestyle) completed restores to Step 3 (body basics)',
      () {
        final draft = _validDraftAt(testUid, 3);
        final validation = validateOnboardingResume(draft);
        expect(validation.resumeStep, 3);
        expect(
          validation.reason,
          OnboardingResumeValidationReason.durableCompletionNotRecorded,
        );
      },
    );

    test(
      'Step 3 (body basics) completed restores to Step 4 (classes / job schedule)',
      () {
        final draft = _validDraftAt(testUid, 4);
        final validation = validateOnboardingResume(draft);
        expect(validation.resumeStep, 4);
        expect(
          validation.reason,
          OnboardingResumeValidationReason.durableCompletionNotRecorded,
        );
      },
    );

    test('Step 4 (classes / job) completed restores to Step 5 (eating)', () {
      final draft = _validDraftAt(testUid, 5);
      final validation = validateOnboardingResume(draft);
      expect(validation.resumeStep, 5);
      expect(
        validation.reason,
        OnboardingResumeValidationReason.durableCompletionNotRecorded,
      );
    });

    test(
      'Step 5 (eating - skipped) completed restores to Step 6 (fixed schedule)',
      () {
        final draft = _validDraftAt(testUid, 6);
        final validation = validateOnboardingResume(draft);
        expect(validation.resumeStep, 6);
        expect(
          validation.reason,
          OnboardingResumeValidationReason.durableCompletionNotRecorded,
        );
      },
    );

    test(
      'Step 5 (eating - photo import) completed restores to Step 6 (fixed schedule)',
      () {
        const assetId = 'eating-menu-asset-1';
        const r2Key = 'users/$testUid/eating/$assetId.jpg';
        final eatingBlocks = [
          const TimelineBlockDraft(
            id: 'ai-lunch',
            section: 'eating',
            title: 'Healthy Lunch',
            startMinute: 720,
            endMinute: 780,
            repeatDays: [1, 2, 3, 4, 5, 6, 7],
            source: 'ai_import',
            blockType: TimelineBlockDraft.hardBlockKey,
            provenanceSourceIds: [assetId, r2Key],
          ),
        ];
        final base = _validBaseTimeline().copyWith(
          eatingSetupPath: 'has_routine',
          blocks: [
            ..._validBaseTimeline().blocks.where((b) => b.section != 'eating'),
            ...eatingBlocks,
          ],
          pendingFutureImports: [
            PendingFutureImportDraft(
              id: 'eating_import_1',
              section: 'Eating',
              mode: 'ai_import',
              createdAt: DateTime.utc(2026, 1, 1),
              uploadedAssetId: assetId,
              uploadedAssetR2Key: r2Key,
              status: 'applied',
            ),
          ],
        );
        final draft = _validDraftAt(
          testUid,
          6,
        ).copyWith(baseTimeline: base, incrementRevision: false);
        final validation = validateOnboardingResume(draft);
        expect(validation.resumeStep, 6);
      },
    );

    test(
      'Step 5 (eating - generated 7-day 3-slot plan) completed restores to Step 6',
      () {
        final generatedBlocks = <TimelineBlockDraft>[];
        const slotNames = ['breakfast', 'lunch', 'dinner'];
        for (var day = 1; day <= 7; day++) {
          for (var slot = 0; slot < 3; slot++) {
            final start = 480 + (slot * 300);
            final slotName = slotNames[slot];
            generatedBlocks.add(
              TimelineBlockDraft(
                id: 'gen-meal-d$day-s$slot',
                section: 'eating',
                title: 'Meal Day $day $slotName',
                mealSlot: slotName,
                dishes: [
                  'Oatmeal bowl $day $slotName',
                  'Almond smoothie $day $slotName',
                ],
                calories: 600.0,
                protein: 30.0,
                startMinute: start,
                endMinute: start + 30,
                repeatDays: [day],
                source: 'ai_generated_meal_setup',
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
            );
          }
        }
        final base = _validBaseTimeline().copyWith(
          eatingSetupPath: 'create',
          mealsPerDay: 3,
          eatingGeneratedInputFingerprint: 'valid-fp-12345',
          eatingGeneratedPlanVersion:
              BaseTimelineDraft.currentGate2EatingPlanVersion,
          blocks: [
            ..._validBaseTimeline().blocks.where((b) => b.section != 'eating'),
            ...generatedBlocks,
          ],
        );
        final draft = _validDraftAt(
          testUid,
          6,
        ).copyWith(baseTimeline: base, incrementRevision: false);
        final validation = validateOnboardingResume(draft);
        expect(validation.resumeStep, 6);
      },
    );

    test(
      'Step 6 (fixed schedule - sleep + bath) completed restores to Step 7 (skin care)',
      () {
        final draft = _validDraftAt(testUid, 7);
        final validation = validateOnboardingResume(draft);
        expect(validation.resumeStep, 7);
        expect(
          validation.reason,
          OnboardingResumeValidationReason.durableCompletionNotRecorded,
        );
      },
    );

    test(
      'Step 7 (skin care - skipped) completed restores to Step 8 (bad habits)',
      () {
        final draft = _validDraftAt(testUid, 8);
        final validation = validateOnboardingResume(draft);
        expect(validation.resumeStep, 8);
        expect(
          validation.reason,
          OnboardingResumeValidationReason.durableCompletionNotRecorded,
        );
      },
    );

    test(
      'Step 7 (skin care - products routine) completed restores to Step 8 (bad habits)',
      () {
        var base = _validBaseTimeline().copyWith(
          skinCareSkipped: false,
          skinCareSetupPath: 'has_products',
          skinCareDesiredApplicationsPerDay: 2,
          skinCareProductNames: 'Gentle Cleanser',
          skinCareReviewedProducts: const [
            SkinCareDetectedProduct(name: 'Gentle Cleanser'),
          ],
        );
        final fp = base.computeSkinCareRoutineFingerprint();
        final skinBlocks = [
          TimelineBlockDraft(
            id: 'skincare-am',
            section: 'skin_care',
            title: 'AM Routine',
            startMinute: 470,
            endMinute: 485,
            repeatDays: const [1, 2, 3, 4, 5, 6, 7],
            source: 'ai_generated_skin_care_setup',
            blockType: TimelineBlockDraft.softBlockKey,
            skincareProducts: const ['Gentle Cleanser'],
            skincareSteps: const ['Apply and rinse'],
            provenanceSourceIds: ['skin-care-generation:$fp'],
          ),
          TimelineBlockDraft(
            id: 'skincare-pm',
            section: 'skin_care',
            title: 'PM Routine',
            startMinute: 1260,
            endMinute: 1275,
            repeatDays: const [1, 2, 3, 4, 5, 6, 7],
            source: 'ai_generated_skin_care_setup',
            blockType: TimelineBlockDraft.softBlockKey,
            skincareProducts: const ['Gentle Cleanser'],
            skincareSteps: const ['Apply and rinse'],
            provenanceSourceIds: ['skin-care-generation:$fp'],
          ),
        ];
        base = base.copyWith(
          skinCareRoutineFingerprint: fp,
          blocks: [...base.blocks, ...skinBlocks],
        );
        final draft = _validDraftAt(
          testUid,
          8,
        ).copyWith(baseTimeline: base, incrementRevision: false);
        final validation = validateOnboardingResume(draft);
        expect(validation.resumeStep, 8);
      },
    );

    test('Step 8 (bad habits) completed restores to Step 9 (good habits)', () {
      final draft = _validDraftAt(testUid, 9);
      final validation = validateOnboardingResume(draft);
      expect(validation.resumeStep, 9);
      expect(
        validation.reason,
        OnboardingResumeValidationReason.durableCompletionNotRecorded,
      );
    });

    test(
      'Step 9 (good habits) completed restores to Step 10 (identity goals)',
      () {
        final draft = _validDraftAt(testUid, 10);
        final validation = validateOnboardingResume(draft);
        expect(validation.resumeStep, 10);
        expect(
          validation.reason,
          OnboardingResumeValidationReason.durableCompletionNotRecorded,
        );
      },
    );

    test(
      'Step 10 (identity goals) completed restores to Step 11 (coach setup)',
      () {
        final draft = _validDraftAt(testUid, 11);
        final validation = validateOnboardingResume(draft);
        expect(validation.resumeStep, 11);
        expect(
          validation.reason,
          OnboardingResumeValidationReason.durableCompletionNotRecorded,
        );
      },
    );

    test('Step 11 (coach setup) completed restores to Step 12 (slip up)', () {
      final draft = _validDraftAt(testUid, 12);
      final validation = validateOnboardingResume(draft);
      expect(validation.resumeStep, 12);
      expect(
        validation.reason,
        OnboardingResumeValidationReason.durableCompletionNotRecorded,
      );
    });

    test('Step 12 (slip up) completed restores to Step 13 (notifications)', () {
      final draft = _validDraftAt(testUid, 13);
      final validation = validateOnboardingResume(draft);
      expect(validation.resumeStep, 13);
      expect(
        validation.reason,
        OnboardingResumeValidationReason.durableCompletionNotRecorded,
      );
    });

    test(
      'Step 13 (notifications) completed restores to Step 14 (today ready)',
      () {
        final draft = _validDraftAt(testUid, 14);
        final validation = validateOnboardingResume(draft);
        expect(validation.resumeStep, 14);
        expect(
          validation.reason,
          OnboardingResumeValidationReason.readyForFinalReview,
        );
        expect(validation.diagnosticCode, 'ready_for_final_review');
      },
    );
  });

  group('Gate 4: Step 14 Completion & Session Destination', () {
    test(
      'Step 14 complete with onboardingCompleted: true resolves to Home',
      () {
        final draft = _validDraftAt(testUid, 14).copyWith(
          stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
          onboardingCompleted: true,
          incrementRevision: false,
        );
        final profile = UserProfile.empty(uid: testUid).copyWith(
          onboardingInputCompleted: true,
          onboardingCompleted: true,
          onboardingProjectionStatus: 'completed',
        );
        final destination = resolveOnboardingSessionDestination(
          ownerUid: testUid,
          profile: profile,
          draft: draft,
        );
        expect(destination.kind, SessionDestinationKind.home);
      },
    );

    test('Incomplete Step 14 resolves to resumeOnboarding', () {
      final draft = _validDraftAt(testUid, 14);
      final profile = UserProfile.empty(uid: testUid);
      final destination = resolveOnboardingSessionDestination(
        ownerUid: testUid,
        profile: profile,
        draft: draft,
      );
      expect(destination.kind, SessionDestinationKind.resumeOnboarding);
    });
  });

  group('Gate 4: Obsolete Generated Eating Plan Quarantine', () {
    test(
      'Obsolete weekly eating plan forces Step 5 resume without crashing',
      () {
        final legacyMealBlocks = [
          const TimelineBlockDraft(
            id: 'legacy-meal-1',
            section: 'eating',
            title: 'Daily Lunch',
            startMinute: 720,
            endMinute: 760,
            repeatDays: [1, 2, 3, 4, 5, 6, 7],
            source: 'ai_generated_meal_setup',
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ];
        final base = _validBaseTimeline().copyWith(
          eatingSetupPath: 'create',
          eatingGeneratedPlanVersion: 0,
          blocks: [..._validBaseTimeline().blocks, ...legacyMealBlocks],
        );
        final draft = _validDraftAt(
          testUid,
          10,
        ).copyWith(baseTimeline: base, incrementRevision: false);

        final restoreErr = draft.baseTimeline.validateDurableEatingRestore();
        expect(restoreErr, 'step_5_migration_required');

        final validation = validateOnboardingResume(draft);
        expect(validation.resumeStep, 5);
        expect(
          validation.reason,
          OnboardingResumeValidationReason.durableStepInvalid,
        );
        expect(validation.diagnosticCode, 'step_5_migration_required');
      },
    );
  });

  group('Gate 4: Incomplete / Hole Monotonic Rewind', () {
    test(
      'Hole at Step 2 rewinds to Step 2 even if currentStep is 10 and subsequent steps completed',
      () {
        final completed = List<bool>.filled(OnboardingDraft.stepCount, true);
        completed[2] = false;

        final draft = _validDraftAt(testUid, 14).copyWith(
          currentStep: 10,
          stepCompleted: completed,
          incrementRevision: false,
        );

        final validation = validateOnboardingResume(draft);
        expect(validation.resumeStep, 2);
        expect(
          validation.reason,
          OnboardingResumeValidationReason.durableCompletionNotRecorded,
        );
        expect(validation.diagnosticCode, 'step_2_save_not_acknowledged');
      },
    );

    test(
      'Corrupt body basics at Step 3 rewinds to Step 3 even if currentStep is 8',
      () {
        final draft = _validDraftAt(testUid, 8).copyWith(
          currentStep: 8,
          bodyBasics: const BodyBasicsDraft(),
          incrementRevision: false,
        );

        final validation = validateOnboardingResume(draft);
        expect(validation.resumeStep, 3);
        expect(
          validation.reason,
          OnboardingResumeValidationReason.durableStepInvalid,
        );
        expect(validation.diagnosticCode, 'step_3_body_basics_invalid');
      },
    );
  });

  group('Gate 4: Downstream Invalidation Policy', () {
    test(
      'Editing Step 2 (life role) invalidates Step 4, Step 5, and Step 14',
      () {
        final initialDraft = _validDraftAt(testUid, 14).copyWith(
          stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
          incrementRevision: false,
        );

        final updatedDraft = initialDraft.copyWith(
          lifeRole: initialDraft.lifeRole.copyWith(
            lifeRole: LifeRoleDraft.studentKey,
          ),
          incrementRevision: false,
        );

        final invalidated = updatedDraft.invalidateDownstreamDependencies(
          initialDraft,
        );

        expect(
          invalidated.stepCompleted[OnboardingStepId.classesJob.index],
          isFalse,
        );
        expect(
          invalidated.stepCompleted[OnboardingStepId.eating.index],
          isFalse,
        );
        expect(
          invalidated.stepCompleted[OnboardingStepId.todayReady.index],
          isFalse,
        );
        expect(
          invalidated.stepCompleted[OnboardingStepId.patience.index],
          isTrue,
        );
        expect(
          invalidated.stepCompleted[OnboardingStepId.fixedSchedule.index],
          isTrue,
        );
        expect(
          invalidated.stepCompleted[OnboardingStepId.skinCare.index],
          isTrue,
        );
      },
    );

    test('Editing Step 3 (body basics) invalidates Step 5 and Step 14', () {
      final initialDraft = _validDraftAt(testUid, 14).copyWith(
        stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
        incrementRevision: false,
      );

      final updatedDraft = initialDraft.copyWith(
        bodyBasics: initialDraft.bodyBasics.copyWith(weightKg: 85),
        incrementRevision: false,
      );

      final invalidated = updatedDraft.invalidateDownstreamDependencies(
        initialDraft,
      );

      expect(invalidated.stepCompleted[OnboardingStepId.eating.index], isFalse);
      expect(
        invalidated.stepCompleted[OnboardingStepId.todayReady.index],
        isFalse,
      );
      expect(
        invalidated.stepCompleted[OnboardingStepId.classesJob.index],
        isTrue,
      );
      expect(
        invalidated.stepCompleted[OnboardingStepId.fixedSchedule.index],
        isTrue,
      );
    });

    test('Editing Step 6 (fixed schedule) invalidates Step 14', () {
      final initialDraft = _validDraftAt(testUid, 14).copyWith(
        stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
        incrementRevision: false,
      );

      final updatedDraft = initialDraft.copyWith(
        baseTimeline: initialDraft.baseTimeline.copyWith(
          blocks: [
            ...initialDraft.baseTimeline.blocks,
            const TimelineBlockDraft(
              id: 'extra-fixed',
              section: 'fixed',
              title: 'Fixed Routine',
              startMinute: 300,
              endMinute: 330,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        ),
        incrementRevision: false,
      );

      final invalidated = updatedDraft.invalidateDownstreamDependencies(
        initialDraft,
      );

      expect(
        invalidated.stepCompleted[OnboardingStepId.fixedSchedule.index],
        isTrue,
      );
      expect(
        invalidated.stepDirty[OnboardingStepId.fixedSchedule.index],
        isTrue,
      );
      expect(
        invalidated.stepCompleted[OnboardingStepId.todayReady.index],
        isFalse,
      );
    });

    test('Editing Step 7 (skin care) invalidates Step 14', () {
      final initialDraft = _validDraftAt(testUid, 14).copyWith(
        stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
        incrementRevision: false,
      );

      final updatedDraft = initialDraft.copyWith(
        baseTimeline: initialDraft.baseTimeline.copyWith(
          skinCareSkipped: false,
          skinCareSetupPath: 'has_products',
        ),
        incrementRevision: false,
      );

      final invalidated = updatedDraft.invalidateDownstreamDependencies(
        initialDraft,
      );

      expect(invalidated.stepDirty[OnboardingStepId.skinCare.index], isTrue);
      expect(
        invalidated.stepCompleted[OnboardingStepId.todayReady.index],
        isFalse,
      );
    });

    test('Eating dependency matrix invalidates Step 5 at mutation time', () {
      final initial = _validDraftAt(testUid, 14).copyWith(
        stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
        incrementRevision: false,
      );
      final mutations =
          <(String, BaseTimelineDraft Function(BaseTimelineDraft))>[
            ('setupPath', (base) => base.copyWith(eatingSetupPath: 'create')),
            ('mode', (base) => base.copyWith(eatingMode: 'planned')),
            ('shouldPlan', (base) => base.copyWith(shouldPlanMeals: true)),
            ('goal', (base) => base.copyWith(mealPlanningGoal: 'gain')),
            ('foodType', (base) => base.copyWith(foodType: 'vegetarian')),
            (
              'customFood',
              (base) => base.copyWith(foodStyleCustomText: 'local'),
            ),
            ('budget', (base) => base.copyWith(mealBudget: 'medium')),
            ('ability', (base) => base.copyWith(cookingAbility: 'basic')),
            ('mealCount', (base) => base.copyWith(mealsPerDay: 4)),
            ('breakfast', (base) => base.copyWith(breakfastMinute: 500)),
            ('lunch', (base) => base.copyWith(lunchMinute: 800)),
            ('dinner', (base) => base.copyWith(dinnerMinute: 1220)),
            ('snack', (base) => base.copyWith(snackMinute: 1000)),
            ('extraSnack', (base) => base.copyWith(extraSnackMinute: 650)),
            (
              'planVersion',
              (base) => base.copyWith(eatingGeneratedPlanVersion: 2),
            ),
            (
              'fingerprint',
              (base) =>
                  base.copyWith(eatingGeneratedInputFingerprint: 'changed'),
            ),
            (
              'importIdentity',
              (base) => base.copyWith(
                pendingFutureImports: [
                  PendingFutureImportDraft(
                    id: 'changed-import',
                    section: 'Eating',
                    mode: 'Photo AI',
                    createdAt: DateTime.utc(2026),
                    uploadedAssetId: 'asset-A',
                    uploadedAssetR2Key:
                        'users/$testUid/onboarding/eating_menu/asset-A.jpg',
                  ),
                ],
              ),
            ),
            (
              'eatingBlock',
              (base) => base.copyWith(
                blocks: [
                  ...base.blocks,
                  const TimelineBlockDraft(
                    id: 'changed-eating',
                    section: 'eating',
                    title: 'Changed meal',
                    startMinute: 780,
                    endMinute: 810,
                    repeatDays: [1],
                    blockType: TimelineBlockDraft.softBlockKey,
                  ),
                ],
              ),
            ),
          ];
      for (final mutation in mutations) {
        final updated = initial.copyWith(
          baseTimeline: mutation.$2(initial.baseTimeline),
          incrementRevision: false,
        );
        final invalidated = updated.invalidateDownstreamDependencies(initial);
        expect(
          invalidated.stepCompleted[OnboardingStepId.eating.index],
          isFalse,
          reason: mutation.$1,
        );
        expect(
          invalidated.stepDirty[OnboardingStepId.eating.index],
          isTrue,
          reason: mutation.$1,
        );
      }
    });

    test('Skin Care dependency matrix invalidates Step 7 at mutation time', () {
      final initial = _validDraftAt(testUid, 14).copyWith(
        stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
        incrementRevision: false,
      );
      final mutations =
          <(String, BaseTimelineDraft Function(BaseTimelineDraft))>[
            (
              'setupPath',
              (base) => base.copyWith(skinCareSetupPath: 'has_products'),
            ),
            ('skip', (base) => base.copyWith(skinCareSkipped: false)),
            (
              'productId',
              (base) => base.copyWith(skinCareProductPhotoAssetId: 'A'),
            ),
            (
              'productKey',
              (base) => base.copyWith(skinCareProductPhotoR2Key: 'key-A'),
            ),
            (
              'productStatus',
              (base) => base.copyWith(skinCareProductPhotoStatus: 'uploaded'),
            ),
            ('faceId', (base) => base.copyWith(skinCareFacePhotoAssetId: 'F')),
            (
              'faceKey',
              (base) => base.copyWith(skinCareFacePhotoR2Key: 'key-F'),
            ),
            (
              'faceStatus',
              (base) => base.copyWith(skinCareFacePhotoStatus: 'uploaded'),
            ),
            (
              'faceSkip',
              (base) => base.copyWith(skinCareFacePhotoSkipped: true),
            ),
            (
              'productNames',
              (base) => base.copyWith(skinCareProductNames: 'Cleanser'),
            ),
            ('skinType', (base) => base.copyWith(skinCareSkinType: 'dry')),
            (
              'problems',
              (base) => base.copyWith(skinCareProblems: const ['dryness']),
            ),
            ('budget', (base) => base.copyWith(skinCareBudget: 'medium')),
            (
              'preference',
              (base) => base.copyWith(skinCarePreference: 'simple'),
            ),
            (
              'applications',
              (base) => base.copyWith(skinCareDesiredApplicationsPerDay: 2),
            ),
            (
              'reviewed',
              (base) => base.copyWith(
                skinCareReviewedProducts: const [
                  SkinCareDetectedProduct(name: 'Cleanser'),
                ],
              ),
            ),
            (
              'recommendations',
              (base) => base.copyWith(
                skinCareProductRecommendations: const [
                  SkinCareProductRecommendationDraft(name: 'Cleanser'),
                ],
              ),
            ),
            (
              'selected',
              (base) => base.copyWith(
                skinCareSelectedProductNames: const ['Cleanser'],
              ),
            ),
            (
              'recommendationFingerprint',
              (base) => base.copyWith(skinCareRecommendationFingerprint: 'rec'),
            ),
            (
              'routineFingerprint',
              (base) => base.copyWith(skinCareRoutineFingerprint: 'routine'),
            ),
            (
              'country',
              (base) => base.copyWith(skinCareRecommendationCountryCode: 'US'),
            ),
            (
              'currency',
              (base) =>
                  base.copyWith(skinCareRecommendationCurrencyCode: 'USD'),
            ),
            (
              'routineBlock',
              (base) => base.copyWith(
                blocks: [
                  ...base.blocks,
                  const TimelineBlockDraft(
                    id: 'changed-skin',
                    section: 'skin_care',
                    title: 'Changed routine',
                    startMinute: 480,
                    endMinute: 495,
                    repeatDays: [1],
                    blockType: TimelineBlockDraft.softBlockKey,
                  ),
                ],
              ),
            ),
          ];
      for (final mutation in mutations) {
        final updated = initial.copyWith(
          baseTimeline: mutation.$2(initial.baseTimeline),
          incrementRevision: false,
        );
        final invalidated = updated.invalidateDownstreamDependencies(initial);
        expect(
          invalidated.stepCompleted[OnboardingStepId.skinCare.index],
          isFalse,
          reason: mutation.$1,
        );
        expect(
          invalidated.stepDirty[OnboardingStepId.skinCare.index],
          isTrue,
          reason: mutation.$1,
        );
      }
    });
  });

  group(
    'Gate 4: Upload Reconciler & Exact Asset Hydration Beyond 100 Recent Uploads',
    () {
      test(
        'Hydrating with requiredAssetIds fetches exact asset older than 100 recent uploads',
        () async {
          final mockAssetRepo = FakeUploadedAssetRepository();
          const oldDraftAssetId = 'old-asset-step-5';
          final oldAsset = UploadedAsset(
            assetId: oldDraftAssetId,
            ownerUid: testUid,
            fileName: '$oldDraftAssetId.jpg',
            r2Key: 'users/$testUid/onboarding/eating_menu/$oldDraftAssetId.jpg',
            purpose: UploadedAssetPurpose.eatingMenu,
            sourceFeature: OnboardingDraft.sourceOnboarding,
            status: UploadedAssetStatus.uploaded,
            contentType: 'image/jpeg',
            sizeBytes: 1024,
            createdAt: DateTime.utc(2025, 1, 1),
            updatedAt: DateTime.utc(2025, 1, 1),
          );
          await mockAssetRepo.saveAsset(oldAsset);

          // Add 102 newer assets for same user
          for (var i = 1; i <= 102; i++) {
            await mockAssetRepo.saveAsset(
              UploadedAsset(
                assetId: 'recent-asset-$i',
                ownerUid: testUid,
                fileName: 'recent-asset-$i.jpg',
                r2Key:
                    'users/$testUid/onboarding/skin_products/recent-asset-$i.jpg',
                purpose: UploadedAssetPurpose.skinProducts,
                sourceFeature: OnboardingDraft.sourceOnboarding,
                status: UploadedAssetStatus.uploaded,
                contentType: 'image/jpeg',
                sizeBytes: 1024,
                createdAt: DateTime.utc(2026, 9, 1, i),
                updatedAt: DateTime.utc(2026, 9, 1, i),
              ),
            );
          }

          final controller = RestoredUploadsController(
            assetRepository: mockAssetRepo,
            previewResolver: const UnavailableUploadedAssetPreviewResolver(),
          );

          await controller.hydrate(
            uid: testUid,
            requiredAssetIds: {oldDraftAssetId},
          );

          final restored = controller.state.forAssetId(oldDraftAssetId);
          expect(restored, isNotNull);
          expect(restored!.asset.assetId, oldDraftAssetId);
        },
      );

      test(
        'Upload reconciler preserves exact referenced asset without resetting valid step',
        () {
          const assetId = 'exact-step4-class-asset';
          const r2Key =
              'users/$testUid/onboarding/class_timetable/$assetId.jpg';

          final asset = UploadedAsset(
            assetId: assetId,
            ownerUid: testUid,
            fileName: '$assetId.jpg',
            r2Key: r2Key,
            purpose: UploadedAssetPurpose.classTimetable,
            sourceFeature: OnboardingDraft.sourceOnboarding,
            status: UploadedAssetStatus.uploaded,
            contentType: 'image/jpeg',
            sizeBytes: 1024,
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          );

          final classBlocks = [
            const TimelineBlockDraft(
              id: 'class-block-1',
              section: 'classes',
              title: 'Math',
              startMinute: 540,
              endMinute: 600,
              repeatDays: [1, 3, 5],
              source: 'ai_import',
              blockType: TimelineBlockDraft.hardBlockKey,
              provenanceSourceIds: [assetId, r2Key],
            ),
          ];

          final base = _validBaseTimeline().copyWith(
            classLogicalAssetId: assetId,
            classLogicalAssetR2Key: r2Key,
            blocks: [..._validBaseTimeline().blocks, ...classBlocks],
            pendingFutureImports: [
              PendingFutureImportDraft(
                id: 'class_import_1',
                section: 'Classes',
                mode: 'ai_import',
                createdAt: DateTime.utc(2026, 1, 1),
                uploadedAssetId: assetId,
                uploadedAssetR2Key: r2Key,
                status: 'applied',
              ),
            ],
          );

          final draft = _validDraftAt(testUid, 5).copyWith(
            lifeRole: const LifeRoleDraft(
              lifeRole: LifeRoleDraft.studentKey,
              exerciseLevel: 'rarely',
              waterIntake: 'medium',
              stressLevel: 'medium',
              sleepQuality: 'good',
            ),
            baseTimeline: base,
            incrementRevision: false,
          );

          final uploadsState = RestoredUploadsState(
            uid: testUid,
            assetsById: {assetId: RestoredUploadedAsset(asset: asset)},
            assetsByPurpose: {
              UploadedAssetPurpose.classTimetable: RestoredUploadedAsset(
                asset: asset,
              ),
            },
          );

          final result = OnboardingUploadSourceReconciler.reconcile(
            ownerUid: testUid,
            draft: draft,
            restoredUploads: uploadsState,
          );

          expect(result.changed, isFalse);
          expect(
            result.reconciledDraft.stepCompleted[OnboardingStepId
                .classesJob
                .index],
            isTrue,
          );
        },
      );
    },
  );

  group('Gate 4: Cold Restart Idempotency', () {
    test(
      'Persisting reconciled draft makes subsequent cold restart idempotent (changed == false)',
      () async {
        final fakeRepo = _FakeOnboardingRepository();
        const assetId = 'eating-asset-reconcile';
        const r2Key = 'users/$testUid/onboarding/eating_menu/$assetId.jpg';

        final asset = UploadedAsset(
          assetId: assetId,
          ownerUid: testUid,
          fileName: '$assetId.jpg',
          r2Key: r2Key,
          purpose: UploadedAssetPurpose.eatingMenu,
          sourceFeature: OnboardingDraft.sourceOnboarding,
          status: UploadedAssetStatus.uploaded,
          contentType: 'image/jpeg',
          sizeBytes: 2048,
          createdAt: DateTime.utc(2026, 8, 1),
          updatedAt: DateTime.utc(2026, 8, 1),
        );

        final draft = _validDraftAt(testUid, 6).copyWith(
          baseTimeline: _validBaseTimeline().copyWith(
            eatingSetupPath: 'has_routine',
            blocks: [
              ..._validBaseTimeline().blocks,
              const TimelineBlockDraft(
                id: 'ai-lunch',
                section: 'eating',
                title: 'Lunch',
                startMinute: 720,
                endMinute: 750,
                repeatDays: [1, 2, 3, 4, 5, 6, 7],
                source: 'ai_import',
                blockType: TimelineBlockDraft.hardBlockKey,
                provenanceSourceIds: [assetId, r2Key],
              ),
            ],
            pendingFutureImports: [
              PendingFutureImportDraft(
                id: 'eating_import_reconcile',
                section: 'Eating',
                mode: 'ai_import',
                createdAt: DateTime.utc(2026, 1, 1),
                uploadedAssetId: assetId,
                uploadedAssetR2Key: r2Key,
                status: 'applied',
              ),
            ],
          ),
          incrementRevision: false,
        );

        await fakeRepo.saveDraft(draft);

        final uploadsState = RestoredUploadsState(
          uid: testUid,
          assetsById: {assetId: RestoredUploadedAsset(asset: asset)},
          assetsByPurpose: {
            UploadedAssetPurpose.eatingMenu: RestoredUploadedAsset(
              asset: asset,
            ),
          },
        );

        // Pass 1: Cold restart reconciles
        final result1 = OnboardingUploadSourceReconciler.reconcile(
          ownerUid: testUid,
          draft: draft,
          restoredUploads: uploadsState,
        );
        if (result1.changed) {
          await fakeRepo.saveDraft(result1.reconciledDraft);
        }

        // Pass 2: Second cold restart from persisted draft
        final reloadedDraft = await fakeRepo.fetchDraft(testUid);
        expect(reloadedDraft, isNotNull);

        final result2 = OnboardingUploadSourceReconciler.reconcile(
          ownerUid: testUid,
          draft: reloadedDraft!,
          restoredUploads: uploadsState,
        );
        expect(
          result2.changed,
          isFalse,
          reason: 'Second cold restart must be fully idempotent',
        );
      },
    );
  });

  group('Gate 4: Account Isolation & Clear State', () {
    test(
      'Resetting for signed out resets draft state to clean empty draft',
      () {
        final notifier = OnboardingNotifier();
        final seedDraft = _validDraftAt(testUid, 5);
        notifier.loadSeedData(seedDraft);
        expect(notifier.state.draft.currentStep, 5);

        notifier.resetForSignedOut();
        expect(notifier.state.draft.uid, '');
        expect(notifier.state.draft.currentStep, 0);
        expect(
          notifier.state.draft.stepCompleted,
          List<bool>.filled(15, false),
        );
      },
    );
  });
}

// Helpers

BodyBasicsDraft _validBody() => const BodyBasicsDraft(
  ageRange: '25-34',
  heightCm: 175,
  weightKg: 70,
  gender: 'other',
);

BaseTimelineDraft _validBaseTimeline() => const BaseTimelineDraft(
  eatingSetupPath: 'skip',
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

OnboardingDraft _validDraftAt(String uid, int step, {int? currentStep}) {
  return OnboardingDraft(
    uid: uid,
    currentStep: currentStep ?? step,
    welcomeSaved: true,
    stepCompleted: List<bool>.generate(
      OnboardingDraft.stepCount,
      (index) => index < step,
    ),
    patiencePledgeAccepted: true,
    lifeRole: const LifeRoleDraft(
      lifeRole: LifeRoleDraft.notStudentNotWorkingKey,
      exerciseLevel: 'rarely',
      waterIntake: 'medium',
      stressLevel: 'medium',
      sleepQuality: 'good',
    ),
    bodyBasics: _validBody(),
    baseTimeline: _validBaseTimeline(),
    badHabitsNotNow: true,
    goodHabitsNotNow: true,
    identityGoals: const [
      IdentityGoalDraft(
        goalKey: 'healthy',
        displayName: 'Healthy person',
        systemKeys: [],
      ),
    ],
    coachSetup: const CoachSetupDraft(
      coachName: 'Nova',
      coachStyle: 'supportive',
    ),
    slipUpHandling: 'restart_small',
    notifications: const NotificationSetupDraft(preferencesConfirmed: true),
  );
}

class _FakeOnboardingRepository implements OnboardingRepository {
  OnboardingDraft? _draft;

  @override
  Future<OnboardingDraft?> fetchDraft(String uid) async => _draft;

  @override
  Future<void> saveDraft(OnboardingDraft draft) async {
    _draft = draft;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
