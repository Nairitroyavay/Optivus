import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_domain_engine.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_setup_controller.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/services/nutrition_ai_client.dart';
import 'package:optivus/services/nutrition_target_service.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';

class _AuthRepository implements AuthRepository {
  @override
  Future<String?> currentIdToken() async => 'test-token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GeneratedPlanEngine extends EatingDomainEngine {
  _GeneratedPlanEngine()
    : super(client: const MissingConfigNutritionAiClient());

  @override
  Future<List<TimelineBlockDraft>> generateEatingRoutine({
    required String uid,
    required String idToken,
    required EatingGenerationInputs inputs,
    required NutritionTargets targets,
    required BaseTimelineDraft baseTimeline,
    http.Client? client,
  }) async {
    return [
      for (final day in List<int>.generate(7, (index) => index + 1)) ...[
        TimelineBlockDraft(
          id: 'breakfast-$day',
          section: 'eating',
          title: 'Breakfast $day',
          startMinute: inputs.breakfastMinute,
          endMinute: inputs.breakfastMinute + 30,
          repeatDays: [day],
          blockType: TimelineBlockDraft.softBlockKey,
          source: 'ai_generated_meal_setup',
          mealCategory: 'breakfast',
          mealSlot: 'breakfast',
          dishes: ['Oats $day', 'Fruit $day'],
          calories: 550,
          protein: 30,
        ),
        TimelineBlockDraft(
          id: 'lunch-$day',
          section: 'eating',
          title: 'Lunch $day',
          startMinute: inputs.lunchMinute,
          endMinute: inputs.lunchMinute + 30,
          repeatDays: [day],
          blockType: TimelineBlockDraft.softBlockKey,
          source: 'ai_generated_meal_setup',
          mealCategory: 'lunch',
          mealSlot: 'lunch',
          dishes: ['Bowl $day', 'Salad $day'],
          calories: 700,
          protein: 45,
        ),
        TimelineBlockDraft(
          id: 'dinner-$day',
          section: 'eating',
          title: 'Dinner $day',
          startMinute: inputs.dinnerMinute,
          endMinute: inputs.dinnerMinute + 30,
          repeatDays: [day],
          blockType: TimelineBlockDraft.softBlockKey,
          source: 'ai_generated_meal_setup',
          mealCategory: 'dinner',
          mealSlot: 'dinner',
          dishes: ['Curry $day', 'Rice $day'],
          calories: 750,
          protein: 50,
        ),
      ],
    ];
  }
}

void main() {
  const uid = 'eating-real-save-user';

  test(
    'AI generate -> edit -> controller save commits, projects, and reloads edit',
    () async {
      final setupRepository = FakeBaseTimelineSetupRepository(
        onboardingRepo: FakeOnboardingRepository(),
      );
      final initial = BaseTimelineSetup(
        uid: uid,
        updatedAt: DateTime.now(),
        eatingSetupPath: 'has_routine',
        eatingPhotoAssetId: 'old-photo-asset',
        eatingPhotoR2Key:
            'users/$uid/onboarding/eating_menu/old-photo-asset.jpg',
        eatingBlocks: const [
          TimelineBlockDraft(
            id: 'old-photo-meal',
            section: 'eating',
            title: 'Imported meal',
            startMinute: 720,
            endMinute: 750,
            repeatDays: [1],
            blockType: TimelineBlockDraft.softBlockKey,
            dishes: ['Imported dish'],
          ),
        ],
      );
      await setupRepository.saveSetup(uid, initial);
      final routineRepository = FakeRoutineRepository();
      final transactionRepository = FakeRoutineTransactionRepository(
        routineRepository: routineRepository,
        setupRepository: setupRepository,
      );

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_AuthRepository()),
          eatingDomainEngineProvider.overrideWithValue(_GeneratedPlanEngine()),
          baseTimelineSetupRepositoryProvider.overrideWithValue(
            setupRepository,
          ),
          routineRepositoryProvider.overrideWithValue(routineRepository),
          routineTransactionRepositoryProvider.overrideWithValue(
            transactionRepository,
          ),
          userProfileProvider.overrideWith(
            (ref) => UserProfileNotifier()
              ..loadSeedData(
                UserProfile(
                  uid: uid,
                  email: 'save@optivus.local',
                  displayName: 'Save Test',
                  height: 175,
                  weight: 75,
                  ageRange: '25-34',
                  gender: 'male',
                  exerciseLevel: 'moderate',
                  lifeRole: 'professional',
                ),
              ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controllerSubscription = container.listen(
        eatingSetupControllerProvider,
        (_, _) {},
      );
      addTearDown(controllerSubscription.close);

      final controller = container.read(eatingSetupControllerProvider.notifier);
      controller.performStartupCleanup(initial, uid: uid);
      controller.editCurrentMealPlan(initial);
      controller.updateSettingsParameters(
        goal: 'maintain',
        mealsPerDay: 3,
        eatingMode: 'balanced',
        foodType: 'mixed',
        foodStyleCustomText: null,
        foodsToAvoid: const [],
        breakfastMinute: 480,
        lunchMinute: 780,
        dinnerMinute: 1200,
        snackMinute: null,
        extraSnackMinute: null,
        targetCalories: null,
        targetProtein: null,
        targetCaloriesOverride: null,
        targetProteinOverride: null,
      );

      expect(
        await controller.generateBalancedPlan(uid: uid, currentSetup: initial),
        isTrue,
      );
      final generated = controller.state;
      expect(generated.workingSetupPath, 'create');
      expect(generated.workingGeneratedPlanVersion, isNotNull);
      expect(generated.workingGeneratedInputFingerprint, isNotEmpty);
      expect(generated.workingCustomized, isFalse);
      expect(generated.workingAssetId, isNull);
      expect(generated.workingR2Key, isNull);

      final before = generated.workingBlocks.first;
      controller.updateBlock(
        before.copyWith(title: 'Edited breakfast', dishes: const ['New oats']),
      );
      expect(controller.state.workingBlocks.first.id, before.id);
      expect(controller.state.isDirty, isTrue);
      expect(controller.state.workingCustomized, isTrue);
      expect(controller.state.workingGeneratedPlanVersion, isNotNull);
      expect(controller.state.workingGeneratedInputFingerprint, isNotEmpty);

      expect(
        await controller.saveWorkingSetup(uid: uid, currentSetup: initial),
        isTrue,
        reason: controller.state.errorMessage,
      );
      expect(controller.state.stage, EatingSetupStage.saveSuccess);

      final reloaded = await setupRepository.fetchSetup(uid);
      expect(reloaded.revision, initial.revision + 1);
      expect(reloaded.eatingSetupPath, 'create');
      expect(reloaded.eatingAuthority.name, 'baseTimeline');
      expect(reloaded.eatingCustomized, isTrue);
      expect(reloaded.eatingGeneratedPlanVersion, isNotNull);
      expect(reloaded.eatingGeneratedInputFingerprint, isNotEmpty);
      expect(reloaded.eatingBlocks.first.id, before.id);
      expect(reloaded.eatingBlocks.first.title, 'Edited breakfast');
      expect(reloaded.eatingBlocks.first.dishes, const ['New oats']);

      final projected = await routineRepository.fetchRoutineItems(uid);
      final edited = projected.singleWhere(
        (item) => item.title == 'Edited breakfast',
      );
      expect(edited.dishes, const ['New oats']);
      expect(edited.baseTimelineSection, 'eating');

      controller.reloadFromCanonical(reloaded);
      expect(controller.state.workingBlocks.first.title, 'Edited breakfast');
      expect(controller.state.workingCustomized, isTrue);

      final deletedId = controller.state.workingBlocks.last.id;
      controller.deleteBlock(deletedId);
      expect(
        await controller.saveWorkingSetup(uid: uid, currentSetup: reloaded),
        isTrue,
        reason: controller.state.errorMessage,
      );
      final afterDelete = await setupRepository.fetchSetup(uid);
      expect(afterDelete.revision, initial.revision + 2);
      expect(
        afterDelete.eatingBlocks.any((block) => block.id == deletedId),
        isFalse,
      );

      controller.reloadFromCanonical(afterDelete);
      controller.updateSettingsParameters(
        goal: 'maintain',
        mealsPerDay: 3,
        eatingMode: 'balanced',
        foodType: 'mixed',
        foodStyleCustomText: null,
        foodsToAvoid: const ['peanuts'],
        breakfastMinute: 480,
        lunchMinute: 780,
        dinnerMinute: 1200,
        snackMinute: null,
        extraSnackMinute: null,
        targetCalories: controller.state.workingTargetCalories,
        targetProtein: controller.state.workingTargetProtein,
        targetCaloriesOverride: 2100,
        targetProteinOverride: 130,
      );
      expect(
        await controller.saveWorkingSetup(uid: uid, currentSetup: afterDelete),
        isTrue,
        reason: controller.state.errorMessage,
      );
      final afterSettings = await setupRepository.fetchSetup(uid);
      expect(afterSettings.revision, initial.revision + 3);
      expect(afterSettings.foodsToAvoid, const ['peanuts']);
      expect(afterSettings.targetCaloriesOverride, 2100);
      expect(afterSettings.eatingCustomized, isTrue);

      controller.startManualSetup(afterSettings);
      controller.addBlock(
        const TimelineBlockDraft(
          id: 'manual-meal',
          section: 'eating',
          title: 'Manual lunch',
          startMinute: 720,
          endMinute: 750,
          repeatDays: [1, 2, 3, 4, 5],
          blockType: TimelineBlockDraft.softBlockKey,
          dishes: ['Rice bowl'],
        ),
      );
      expect(controller.state.workingGeneratedPlanVersion, isNull);
      expect(controller.state.workingGeneratedInputFingerprint, isNull);
      expect(
        await controller.saveWorkingSetup(
          uid: uid,
          currentSetup: afterSettings,
        ),
        isTrue,
        reason: controller.state.errorMessage,
      );
      final manual = await setupRepository.fetchSetup(uid);
      expect(manual.eatingSetupPath, 'manual');
      expect(manual.eatingGeneratedPlanVersion, isNull);
      expect(manual.eatingGeneratedInputFingerprint, isNull);
      expect(manual.eatingPhotoAssetId, isNull);
    },
  );
}
