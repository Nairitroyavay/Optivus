import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/eating_current_setup_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_domain_engine.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_setup_controller.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_domain_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_stale_plan_banner.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/eating_plan_summary_card.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/region_settings_repository.dart';
import 'package:optivus/services/nutrition_ai_client.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/region_settings_provider.dart';

import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/state/auth_state.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<String?> currentIdToken() async => 'test-token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRegionSettingsRepo implements RegionSettingsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ControlledRefreshCoordinator extends BaseTimelineTransactionCoordinator {
  BaseTimelineRoutineRefreshResult refreshResult;

  _ControlledRefreshCoordinator({
    required super.routineRepo,
    required super.setupRepo,
    required super.transactionRepo,
    this.refreshResult = const BaseTimelineRoutineRefreshResult(
      status: BaseTimelineRoutineRefreshStatus.refreshed,
    ),
  });

  @override
  Future<BaseTimelineRoutineRefreshResult> retryRoutineRefresh({
    required String uid,
    int? targetRevision,
  }) async {
    return refreshResult;
  }
}

void main() {
  group('Eating Post-Save UI Cleanliness & Warning Tests', () {
    const uid = 'test-uid-cleanliness';
    final profile = UserProfile(
      uid: uid,
      email: 'clean@optivus.local',
      displayName: 'Clean User',
      weight: 70,
      height: 175,
      gender: 'male',
      ageRange: '25',
      exerciseLevel: 'moderate',
      lifeRole: 'employed',
    );

    final engine = EatingDomainEngine(
      client: const MissingConfigNutritionAiClient(),
    );

    final initialSetup = BaseTimelineSetup(
      uid: uid,
      updatedAt: DateTime.now(),
      eatingSetupPath: 'create',
      mealPlanningGoal: 'maintain',
      mealsPerDay: 3,
      eatingMode: 'balanced',
      foodType: 'mixed',
      breakfastMinute: 8 * 60,
      lunchMinute: 13 * 60,
      dinnerMinute: 19 * 60,
      eatingBlocks: const [
        TimelineBlockDraft(
          id: 'meal-1',
          section: 'eating',
          title: 'Morning Oats',
          startMinute: 480,
          endMinute: 510,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: 'meal',
          dishes: ['Oatmeal'],
          calories: 500,
          protein: 25,
        ),
      ],
    );

    Widget buildCurrentSetupScreen({
      required BaseTimelineSetup setup,
      required UserProfile userProfile,
      String countryCode = 'IN',
      bool routineRefreshPending = false,
      String? routineRefreshMessage,
    }) {
      final regionNotifier = RegionSettingsNotifier(_FakeRegionSettingsRepo());
      regionNotifier.state = RegionSettings.forCountry(
        userId: uid,
        countryCode: countryCode,
        countryName: 'India',
        source: RegionSource.userSaved,
      );

      return ProviderScope(
        overrides: [
          userProfileProvider.overrideWith(
            (ref) => UserProfileNotifier()..state = userProfile,
          ),
          eatingDomainEngineProvider.overrideWithValue(engine),
          regionSettingsProvider.overrideWith((ref) => regionNotifier),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EatingCurrentSetupView(
              setup: setup,
              selectedDay: 1,
              onDayChanged: (_) {},
              onBack: () {},
              onEditSchedule: () {},
              onChangeSource: () {},
              onRemoveSetup: () {},
              onOpenSettings: () {},
              onRegenerate: () {},
              routineRefreshPending: routineRefreshPending,
              routineRefreshMessage: routineRefreshMessage,
              onRetryRefresh: () {},
            ),
          ),
        ),
      );
    }

    testWidgets(
      'Freshly generated and saved plan shows ZERO stale banners and no older preferences notices',
      (tester) async {
        final genInputs = engine.buildCanonicalInputs(
          profile: profile,
          setup: initialSetup,
          country: 'IN',
        );
        final freshSavedSetup = initialSetup.copyWith(
          eatingGeneratedInputFingerprint: genInputs.computeFingerprint(),
          eatingGeneratedPlanVersion:
              BaseTimelineDraft.currentGate2EatingPlanVersion,
          eatingCustomized: false,
          revision: 2,
        );

        await tester.pumpWidget(
          buildCurrentSetupScreen(
            setup: freshSavedSetup,
            userProfile: profile,
            countryCode: 'IN',
          ),
        );
        await tester.pumpAndSettle();

        // Stale banners should NOT be present
        expect(find.byType(BaseTimelineStalePlanBanner), findsNothing);
        expect(find.text('Plan may need updating'), findsNothing);
        expect(
          find.text('Your Body Basics changed after this plan was generated.'),
          findsNothing,
        );
        expect(
          find.text('Your Eating Plan was generated from older preferences.'),
          findsNothing,
        );
        expect(find.text("Plan freshness couldn't be checked."), findsNothing);

        // Eating plan summary card is present and clean
        expect(find.byType(EatingPlanSummaryCard), findsOneWidget);
      },
    );

    testWidgets(
      'Edited meal dish (eatingCustomized: true) shows ZERO stale banners when generation inputs unchanged',
      (tester) async {
        final genInputs = engine.buildCanonicalInputs(
          profile: profile,
          setup: initialSetup,
          country: 'IN',
        );
        final customizedSetup = initialSetup.copyWith(
          eatingGeneratedInputFingerprint: genInputs.computeFingerprint(),
          eatingGeneratedPlanVersion:
              BaseTimelineDraft.currentGate2EatingPlanVersion,
          eatingCustomized: true, // User edited a dish
          eatingBlocks: const [
            TimelineBlockDraft(
              id: 'meal-1',
              section: 'eating',
              title: 'Avocado Toast & Eggs', // Modified meal
              startMinute: 480,
              endMinute: 510,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: 'meal',
              dishes: ['Toast', 'Eggs'],
              calories: 550,
              protein: 30,
            ),
          ],
          revision: 3,
        );

        await tester.pumpWidget(
          buildCurrentSetupScreen(
            setup: customizedSetup,
            userProfile: profile,
            countryCode: 'IN',
          ),
        );
        await tester.pumpAndSettle();

        // Must still show zero stale banners
        expect(find.byType(BaseTimelineStalePlanBanner), findsNothing);
        expect(find.text('Plan may need updating'), findsNothing);
      },
    );

    testWidgets(
      'Genuine Body Basics change displays exactly ONE stale banner and NO duplicate inside summary card',
      (tester) async {
        final genInputs = engine.buildCanonicalInputs(
          profile: profile,
          setup: initialSetup,
          country: 'IN',
        );
        final savedSetup = initialSetup.copyWith(
          eatingGeneratedInputFingerprint: genInputs.computeFingerprint(),
          eatingGeneratedPlanVersion:
              BaseTimelineDraft.currentGate2EatingPlanVersion,
          revision: 2,
        );

        // Body basics changed (weight changed from 70kg to 82kg)
        final driftedProfile = profile.copyWith(weight: 82);

        await tester.pumpWidget(
          buildCurrentSetupScreen(
            setup: savedSetup,
            userProfile: driftedProfile,
            countryCode: 'IN',
          ),
        );
        await tester.pumpAndSettle();

        // Exactly ONE banner
        expect(find.byType(BaseTimelineStalePlanBanner), findsOneWidget);
        expect(find.text('Plan may need updating'), findsOneWidget);
        expect(
          find.text(
            'Your Body Basics or meal-plan preferences changed after this plan was generated.',
          ),
          findsOneWidget,
        );

        // Actions
        expect(find.text('Review settings'), findsOneWidget);
        expect(find.text('Regenerate'), findsOneWidget);

        // No duplicate inside summary card
        expect(
          find.text('Your Eating Plan was generated from older preferences.'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Routine refresh pending displays single refresh banner without stale error',
      (tester) async {
        final genInputs = engine.buildCanonicalInputs(
          profile: profile,
          setup: initialSetup,
          country: 'IN',
        );
        final savedSetup = initialSetup.copyWith(
          eatingGeneratedInputFingerprint: genInputs.computeFingerprint(),
          revision: 2,
        );

        await tester.pumpWidget(
          buildCurrentSetupScreen(
            setup: savedSetup,
            userProfile: profile,
            countryCode: 'IN',
            routineRefreshPending: true,
            routineRefreshMessage:
                "Routine couldn't refresh yet. Please try again.",
          ),
        );
        await tester.pumpAndSettle();

        // Stale banner is NOT shown
        expect(find.byType(BaseTimelineStalePlanBanner), findsNothing);

        // Exactly one refresh pending banner
        expect(find.byType(BaseTimelineRefreshPendingBanner), findsOneWidget);
        expect(
          find.text("Routine couldn't refresh yet. Please try again."),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Plan setting change (mealsPerDay) after generation displays exactly ONE stale banner and NO duplicate',
      (tester) async {
        final genInputs = engine.buildCanonicalInputs(
          profile: profile,
          setup: initialSetup,
          country: 'IN',
        );
        // Generation was with mealsPerDay: 3, but setting drifted to 4 without regeneration
        final driftedSetup = initialSetup.copyWith(
          eatingGeneratedInputFingerprint: genInputs.computeFingerprint(),
          eatingGeneratedPlanVersion:
              BaseTimelineDraft.currentGate2EatingPlanVersion,
          mealsPerDay: 4,
          revision: 2,
        );

        await tester.pumpWidget(
          buildCurrentSetupScreen(
            setup: driftedSetup,
            userProfile: profile,
            countryCode: 'IN',
          ),
        );
        await tester.pumpAndSettle();

        // Exactly ONE banner
        expect(find.byType(BaseTimelineStalePlanBanner), findsOneWidget);
        expect(find.text('Plan may need updating'), findsOneWidget);
        expect(
          find.text(
            'Your Body Basics or meal-plan preferences changed after this plan was generated.',
          ),
          findsOneWidget,
        );

        // Actions
        expect(find.text('Review settings'), findsOneWidget);
        expect(find.text('Regenerate'), findsOneWidget);

        // No duplicate notice in summary card
        expect(
          find.text('Your Eating Plan was generated from older preferences.'),
          findsNothing,
        );
      },
    );

    test('dismissSuccess transitions stage to currentSetup cleanly', () {
      final container = ProviderContainer(
        overrides: [
          userProfileProvider.overrideWith(
            (ref) => UserProfileNotifier()..state = profile,
          ),
          eatingDomainEngineProvider.overrideWithValue(engine),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(eatingSetupControllerProvider.notifier);

      // Start in saveSuccess stage with an old error message
      controller.state = controller.state.copyWith(
        stage: EatingSetupStage.saveSuccess,
        errorMessage: 'Old temporary error',
        routineRefreshPending: false,
      );

      expect(controller.state.stage, equals(EatingSetupStage.saveSuccess));

      // Dismiss success
      controller.dismissSuccess();

      expect(controller.state.stage, equals(EatingSetupStage.currentSetup));
      expect(controller.state.errorMessage, isNull);
      expect(controller.state.isDirty, isFalse);
    });

    test(
      'Post-save message state hygiene: save with routineRefreshPending: false clears old refresh message',
      () async {
        final setupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: FakeOnboardingRepository(),
        );
        await setupRepo.saveSetup(uid, initialSetup);
        final routineRepo = FakeRoutineRepository();
        final txRepo = FakeRoutineTransactionRepository(
          routineRepository: routineRepo,
          setupRepository: setupRepo,
        );
        final coordinator = BaseTimelineTransactionCoordinator(
          routineRepo: routineRepo,
          setupRepo: setupRepo,
          transactionRepo: txRepo,
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
            eatingDomainEngineProvider.overrideWithValue(engine),
            baseTimelineSetupRepositoryProvider.overrideWithValue(setupRepo),
            routineRepositoryProvider.overrideWithValue(routineRepo),
            routineTransactionRepositoryProvider.overrideWithValue(txRepo),
            baseTimelineTransactionCoordinatorProvider.overrideWithValue(
              coordinator,
            ),
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()..state = profile,
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          eatingSetupControllerProvider.notifier,
        );
        controller.editCurrentMealPlan(initialSetup);

        // Pre-set an old routineRefreshMessage and old error
        controller.state = controller.state.copyWith(
          routineRefreshPending: true,
          routineRefreshMessage: 'Old stale refresh error',
          errorMessage: 'Old temporary save error',
        );

        final saved = await controller.saveWorkingSetup(
          uid: uid,
          currentSetup: initialSetup,
        );
        expect(saved, isTrue);

        // Successful save must clear old messages when refresh is not pending
        expect(controller.state.stage, equals(EatingSetupStage.saveSuccess));
        expect(controller.state.routineRefreshPending, isFalse);
        expect(controller.state.routineRefreshMessage, isNull);
        expect(controller.state.errorMessage, isNull);
        expect(controller.state.isConcurrencyConflict, isFalse);
      },
    );

    test(
      'retryRoutineRefresh clears routineRefreshPending and message on successful refresh',
      () async {
        final setupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: FakeOnboardingRepository(),
        );
        await setupRepo.saveSetup(uid, initialSetup);
        final routineRepo = FakeRoutineRepository();
        final txRepo = FakeRoutineTransactionRepository(
          routineRepository: routineRepo,
          setupRepository: setupRepo,
        );
        final coordinator = _ControlledRefreshCoordinator(
          routineRepo: routineRepo,
          setupRepo: setupRepo,
          transactionRepo: txRepo,
          refreshResult: const BaseTimelineRoutineRefreshResult(
            status: BaseTimelineRoutineRefreshStatus.refreshed,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
            eatingDomainEngineProvider.overrideWithValue(engine),
            baseTimelineSetupRepositoryProvider.overrideWithValue(setupRepo),
            routineRepositoryProvider.overrideWithValue(routineRepo),
            routineTransactionRepositoryProvider.overrideWithValue(txRepo),
            baseTimelineTransactionCoordinatorProvider.overrideWithValue(
              coordinator,
            ),
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()..state = profile,
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          eatingSetupControllerProvider.notifier,
        );

        // Set routineRefreshPending to true with a message
        controller.state = controller.state.copyWith(
          stage: EatingSetupStage.currentSetup,
          routineRefreshPending: true,
          routineRefreshMessage:
              "Routine couldn't refresh yet. Please try again.",
          committedRevision: 2,
        );

        expect(controller.state.routineRefreshPending, isTrue);
        expect(controller.state.routineRefreshMessage, isNotNull);

        // Trigger retryRoutineRefresh - success case
        await controller.retryRoutineRefresh(uid: uid);

        // Expect pending to be cleared
        expect(controller.state.routineRefreshPending, isFalse);
        expect(controller.state.routineRefreshMessage, isNull);

        // Failure case: if retry fails, routineRefreshPending stays true with mapped message
        coordinator.refreshResult = const BaseTimelineRoutineRefreshResult(
          status: BaseTimelineRoutineRefreshStatus.refreshPending,
          message: 'Simulated backend timeout',
        );
        await controller.retryRoutineRefresh(uid: uid);
        expect(controller.state.routineRefreshPending, isTrue);
        expect(
          controller.state.routineRefreshMessage,
          "Routine couldn't refresh yet. Please try again.",
        );
      },
    );

    test(
      'Post-save revision consistency: save N -> result N+1 -> dismiss leaves canonical N+1 revision',
      () async {
        final setupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: FakeOnboardingRepository(),
        );
        final setupAtRev10 = initialSetup.copyWith(revision: 10);
        await setupRepo.saveSetup(uid, setupAtRev10);
        final routineRepo = FakeRoutineRepository();
        final txRepo = FakeRoutineTransactionRepository(
          routineRepository: routineRepo,
          setupRepository: setupRepo,
        );
        final coordinator = BaseTimelineTransactionCoordinator(
          routineRepo: routineRepo,
          setupRepo: setupRepo,
          transactionRepo: txRepo,
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
            eatingDomainEngineProvider.overrideWithValue(engine),
            baseTimelineSetupRepositoryProvider.overrideWithValue(setupRepo),
            routineRepositoryProvider.overrideWithValue(routineRepo),
            routineTransactionRepositoryProvider.overrideWithValue(txRepo),
            baseTimelineTransactionCoordinatorProvider.overrideWithValue(
              coordinator,
            ),
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()..state = profile,
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          eatingSetupControllerProvider.notifier,
        );
        controller.editCurrentMealPlan(setupAtRev10);
        expect(controller.state.editorBaseRevision, equals(10));

        // Save working setup
        final saved = await controller.saveWorkingSetup(
          uid: uid,
          currentSetup: setupAtRev10,
        );
        expect(saved, isTrue);

        // Transaction result is N+1 (revision 11)
        expect(controller.state.stage, equals(EatingSetupStage.saveSuccess));
        expect(controller.state.editorBaseRevision, equals(11));
        expect(controller.state.isDirty, isFalse);

        // Repo has revision 11
        final reloadedSetup = await setupRepo.fetchSetup(uid);
        expect(reloadedSetup.revision, equals(11));

        // Dismiss success -> current setup
        controller.dismissSuccess();
        expect(controller.state.stage, equals(EatingSetupStage.currentSetup));
        expect(controller.state.isDirty, isFalse);

        // Editing again from canonical setup initialises with revision 11
        controller.editCurrentMealPlan(reloadedSetup);
        expect(controller.state.editorBaseRevision, equals(11));
        expect(controller.state.isDirty, isFalse);
      },
    );
  });
}
