import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/eating_plan_freshness.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_candidate_dish_normalizer.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_setup_error_mapper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_source_transition_policy.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/eating_timeline_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/eating_base_setup_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_upload_lifecycle_helper.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_current_setup_header.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/eating_plan_settings_sheet.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/routine_import_ai_client.dart';
import 'package:optivus/services/uploads/image_prepare_service.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/state/upload_state.dart';

import 'package:optivus/features/routine/managers/base_timeline/services/eating_domain_engine.dart';
import 'package:optivus/services/nutrition_ai_client.dart';
import 'package:optivus/services/nutrition_target_service.dart';

// Test Stubs
class _FakeEatingDomainEngine extends EatingDomainEngine {
  _FakeEatingDomainEngine()
    : super(client: const MissingConfigNutritionAiClient());

  @override
  Future<List<TimelineBlockDraft>> generateEatingRoutine({
    required String uid,
    required String idToken,
    required EatingGenerationInputs inputs,
    required NutritionTargets targets,
    required BaseTimelineDraft baseTimeline,
  }) async {
    return [
      TimelineBlockDraft(
        id: 'gen-breakfast',
        section: 'eating',
        title: 'Breakfast',
        startMinute: inputs.breakfastMinute,
        endMinute: inputs.breakfastMinute + 30,
        repeatDays: const [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.softBlockKey,
        mealSlot: 'breakfast',
        dishes: const ['Oatmeal', 'Berries'],
      ),
      TimelineBlockDraft(
        id: 'gen-lunch',
        section: 'eating',
        title: 'Lunch',
        startMinute: inputs.lunchMinute,
        endMinute: inputs.lunchMinute + 45,
        repeatDays: const [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.softBlockKey,
        mealSlot: 'lunch',
        dishes: const ['Chicken Salad'],
      ),
      TimelineBlockDraft(
        id: 'gen-dinner',
        section: 'eating',
        title: 'Dinner',
        startMinute: inputs.dinnerMinute,
        endMinute: inputs.dinnerMinute + 45,
        repeatDays: const [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.softBlockKey,
        mealSlot: 'dinner',
        dishes: const ['Salmon & Veggies'],
      ),
    ];
  }
}

class _TrackingAssetRepo implements UploadedAssetRepository {
  final List<String> deletedAssetIds = [];

  _TrackingAssetRepo();

  @override
  Future<void> markDeleted({
    required String uid,
    required String assetId,
  }) async {
    deletedAssetIds.add(assetId);
  }

  @override
  Future<List<UploadedAsset>> fetchRecentAssets({
    required String uid,
    String? sourceFeature,
    UploadedAssetPurpose? purpose,
    int limit = 20,
  }) async => const [];

  @override
  Future<void> saveAsset(UploadedAsset asset) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TrackingR2Client implements R2UploadClient {
  final List<String> deletedKeys = [];

  @override
  Future<void> deleteUpload({
    required String objectKey,
    required String idToken,
  }) async {
    deletedKeys.add(objectKey);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubAuthRepo implements AuthRepository {
  @override
  Future<String?> currentIdToken() async => 'test-id-token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubImagePrepareService extends ImagePrepareService {
  @override
  Future<PreparedUploadImage?> pickAndPrepareImage({
    ImageSource source = ImageSource.gallery,
    UploadedAssetPurpose purpose = UploadedAssetPurpose.profilePhoto,
  }) async {
    return PreparedUploadImage(
      fileName: 'test.jpg',
      contentType: 'image/jpeg',
      bytes: Uint8List(0),
      sizeBytes: 1024,
    );
  }
}

class _DirectUploadController extends UploadController {
  final UploadedAsset? assetToReturn;

  _DirectUploadController({required super.assetRepository, this.assetToReturn})
    : super(
        authRepository: _StubAuthRepo(),
        imagePrepareService: _StubImagePrepareService(),
        r2UploadClient: _TrackingR2Client(),
      );

  @override
  Future<UploadedAsset?> startUpload({
    required String uid,
    required UploadedAssetPurpose purpose,
    required String sourceFeature,
    ImageSource source = ImageSource.gallery,
    int maxDimension = 1600,
    int imageQuality = 85,
  }) async {
    return assetToReturn;
  }
}

class _CustomResultAiController extends RoutineImportAiController {
  final RoutineImportExtractionResult? resultToReturn;

  _CustomResultAiController(Ref ref, {this.resultToReturn})
    : super(ref, const FakeRoutineImportAiClient());

  @override
  Future<RoutineImportExtractionResult?> runExtraction(
    RoutineImportReviewDraft review,
  ) async {
    return resultToReturn;
  }
}

void main() {
  group('Base Timeline Eating Completion Tests', () {
    const uid = 'user-eating-completion-test';

    testWidgets(
      'Eating setup screen displays BaseTimelineCurrentSetupHeader and renders cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final now = DateTime.now();
        final setup = BaseTimelineSetup(
          uid: uid,
          updatedAt: now,
          eatingBlocks: const [
            TimelineBlockDraft(
              id: 'meal-breakfast-1',
              section: 'eating',
              title: 'Breakfast',
              startMinute: 8 * 60,
              endMinute: 8 * 60 + 30,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.softBlockKey,
              mealSlot: 'breakfast',
              dishes: ['Oatmeal', 'Berries'],
            ),
          ],
        );

        final fakeOnboardingRepo = FakeOnboardingRepository();
        final fakeSetupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: fakeOnboardingRepo,
        );
        await fakeSetupRepo.saveSetup(uid, setup);
        final fakeRoutineRepo = FakeRoutineRepository();
        final fakeTxRepo = FakeRoutineTransactionRepository(
          routineRepository: fakeRoutineRepo,
          setupRepository: fakeSetupRepo,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userProfileProvider.overrideWith(
                (ref) => UserProfileNotifier()
                  ..loadSeedData(
                    UserProfile(
                      uid: uid,
                      email: 'eating@optivus.local',
                      displayName: 'Eating Test User',
                    ),
                  ),
              ),
              baseTimelineSetupRepositoryProvider.overrideWithValue(
                fakeSetupRepo,
              ),
              routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
              routineTransactionRepositoryProvider.overrideWithValue(
                fakeTxRepo,
              ),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: EatingBaseSetupScreen(onBack: () {}),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(BaseTimelineCurrentSetupHeader), findsOneWidget);
        expect(find.text('Eating'), findsWidgets);
        expect(find.text('Edit schedule'), findsOneWidget);
        final err = tester.takeException();
        if (err != null) {
          debugPrint('OVERFLOW: $err');
        }
        expect(err, isNull);
      },
    );

    testWidgets(
      'Reset Eating Setup displays confirmation dialog, clears setup, and retires asset',
      (tester) async {
        final now = DateTime.now();
        final setup = BaseTimelineSetup(
          uid: uid,
          updatedAt: now,
          eatingPhotoAssetId: 'initial-eating-photo-asset',
          eatingPhotoR2Key: 'users/$uid/eating/menu.jpg',
          eatingSetupPath: 'has_routine',
          eatingBlocks: const [
            TimelineBlockDraft(
              id: 'meal-lunch-1',
              section: 'eating',
              title: 'Lunch',
              startMinute: 12 * 60,
              endMinute: 13 * 60,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.softBlockKey,
              mealSlot: 'lunch',
              dishes: ['Rice Bowl'],
            ),
          ],
        );

        final fakeOnboardingRepo = FakeOnboardingRepository();
        final fakeSetupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: fakeOnboardingRepo,
        );
        await fakeSetupRepo.saveSetup(uid, setup);
        final fakeRoutineRepo = FakeRoutineRepository();
        final fakeTxRepo = FakeRoutineTransactionRepository(
          routineRepository: fakeRoutineRepo,
          setupRepository: fakeSetupRepo,
        );
        final trackingAssetRepo = _TrackingAssetRepo();
        final trackingR2 = _TrackingR2Client();
        final stubAuth = _StubAuthRepo();
        final lifecycleHelper = BaseTimelineUploadLifecycleHelper(
          assetRepository: trackingAssetRepo,
          r2UploadClient: trackingR2,
          authRepository: stubAuth,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userProfileProvider.overrideWith(
                (ref) => UserProfileNotifier()
                  ..loadSeedData(
                    UserProfile(
                      uid: uid,
                      email: 'eating@optivus.local',
                      displayName: 'Eating Test User',
                    ),
                  ),
              ),
              baseTimelineSetupRepositoryProvider.overrideWithValue(
                fakeSetupRepo,
              ),
              routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
              routineTransactionRepositoryProvider.overrideWithValue(
                fakeTxRepo,
              ),
              baseTimelineUploadLifecycleHelperProvider.overrideWithValue(
                lifecycleHelper,
              ),
              uploadedAssetRepositoryProvider.overrideWithValue(
                trackingAssetRepo,
              ),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: EatingBaseSetupScreen(onBack: () {}),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final moreButton = find.byKey(
          const Key('base-timeline-header-menu-button'),
        );
        expect(moreButton, findsOneWidget);
        await tester.tap(moreButton);
        await tester.pumpAndSettle();

        expect(find.text('Remove Eating Plan'), findsOneWidget);
        await tester.tap(find.text('Remove Eating Plan'));
        await tester.pumpAndSettle();

        expect(find.text('Remove Eating Plan?'), findsOneWidget);
        expect(
          find.text(
            'This will delete your current eating schedule and clear your meal plan setup. This action cannot be undone.',
          ),
          findsOneWidget,
        );

        // Cancel first
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        var currentSetup = await fakeSetupRepo.fetchSetup(uid);
        expect(currentSetup.eatingBlocks.length, equals(1));
        expect(trackingAssetRepo.deletedAssetIds, isEmpty);

        // Confirm reset
        await tester.tap(moreButton);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove Eating Plan'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        expect(find.text('Eating plan removed.'), findsOneWidget);

        currentSetup = await fakeSetupRepo.fetchSetup(uid);
        expect(currentSetup.eatingBlocks, isEmpty);
        expect(currentSetup.eatingPhotoAssetId, isNull);
        expect(currentSetup.eatingPhotoR2Key, isNull);
        expect(currentSetup.eatingSetupPath, isNull);
        expect(
          trackingAssetRepo.deletedAssetIds,
          contains('initial-eating-photo-asset'),
        );
      },
    );

    testWidgets('Eating setup prevents accidental empty plan save', (
      tester,
    ) async {
      final now = DateTime.now();
      final setup = BaseTimelineSetup(
        uid: uid,
        updatedAt: now,
        eatingBlocks: const [
          TimelineBlockDraft(
            id: 'meal-breakfast-1',
            section: 'eating',
            title: 'Breakfast',
            startMinute: 8 * 60,
            endMinute: 8 * 60 + 30,
            repeatDays: [1, 2, 3, 4, 5, 6, 7],
            blockType: TimelineBlockDraft.softBlockKey,
            mealSlot: 'breakfast',
            dishes: ['Oatmeal'],
          ),
        ],
      );

      final fakeOnboardingRepo = FakeOnboardingRepository();
      final fakeSetupRepo = FakeBaseTimelineSetupRepository(
        onboardingRepo: fakeOnboardingRepo,
      );
      await fakeSetupRepo.saveSetup(uid, setup);
      final fakeRoutineRepo = FakeRoutineRepository();
      final fakeTxRepo = FakeRoutineTransactionRepository(
        routineRepository: fakeRoutineRepo,
        setupRepository: fakeSetupRepo,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: uid,
                    email: 'eating@optivus.local',
                    displayName: 'Eating Test User',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(
              fakeSetupRepo,
            ),
            routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
            routineTransactionRepositoryProvider.overrideWithValue(fakeTxRepo),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: EatingBaseSetupScreen(onBack: () {}),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter edit mode
      await tester.tap(find.text('Edit schedule'));
      await tester.pumpAndSettle();

      // Delete the only block
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Verify guard error message is shown and save is prevented
      expect(
        find.text(
          'Cannot save an empty eating schedule. Add meals or build a plan.',
        ),
        findsOneWidget,
      );

      // Setup remains untouched in repo
      final currentSetup = await fakeSetupRepo.fetchSetup(uid);
      expect(currentSetup.eatingBlocks.length, equals(1));
    });

    testWidgets(
      'Photo extraction failure retires candidate asset and preserves existing plan',
      (tester) async {
        final trackingAssetRepo = _TrackingAssetRepo();
        final trackingR2 = _TrackingR2Client();
        final stubAuth = _StubAuthRepo();
        final lifecycleHelper = BaseTimelineUploadLifecycleHelper(
          assetRepository: trackingAssetRepo,
          r2UploadClient: trackingR2,
          authRepository: stubAuth,
        );

        final candidateAsset = UploadedAsset(
          assetId: 'cand-failed-eating-photo',
          ownerUid: uid,
          sourceFeature: 'routine_base_timeline',
          purpose: UploadedAssetPurpose.eatingMenu,
          status: UploadedAssetStatus.uploaded,
          fileName: 'invalid_menu.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 1024,
          r2Key: 'users/$uid/eating/invalid_menu.jpg',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final now = DateTime.now();
        final existingSetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: now,
          eatingBlocks: const [
            TimelineBlockDraft(
              id: 'existing-lunch',
              section: 'eating',
              title: 'Existing Lunch',
              startMinute: 13 * 60,
              endMinute: 14 * 60,
              repeatDays: [1, 2, 3, 4, 5],
              blockType: TimelineBlockDraft.softBlockKey,
              mealSlot: 'lunch',
              dishes: ['Existing Dish'],
            ),
          ],
        );

        final fakeOnboardingRepo = FakeOnboardingRepository();
        final fakeSetupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: fakeOnboardingRepo,
        );
        await fakeSetupRepo.saveSetup(uid, existingSetup);
        final fakeRoutineRepo = FakeRoutineRepository();
        final fakeTxRepo = FakeRoutineTransactionRepository(
          routineRepository: fakeRoutineRepo,
          setupRepository: fakeSetupRepo,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userProfileProvider.overrideWith(
                (ref) => UserProfileNotifier()
                  ..loadSeedData(
                    UserProfile(
                      uid: uid,
                      email: 'eating@optivus.local',
                      displayName: 'Eating Test User',
                    ),
                  ),
              ),
              baseTimelineSetupRepositoryProvider.overrideWithValue(
                fakeSetupRepo,
              ),
              routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
              routineTransactionRepositoryProvider.overrideWithValue(
                fakeTxRepo,
              ),
              baseTimelineUploadLifecycleHelperProvider.overrideWithValue(
                lifecycleHelper,
              ),
              uploadedAssetRepositoryProvider.overrideWithValue(
                trackingAssetRepo,
              ),
              uploadControllerProvider.overrideWith(
                (ref) => _DirectUploadController(
                  assetRepository: trackingAssetRepo,
                  assetToReturn: candidateAsset,
                ),
              ),
              // AI returns 0 meal candidates
              routineImportAiControllerProvider.overrideWith(
                (ref) => _CustomResultAiController(
                  ref,
                  resultToReturn: RoutineImportExtractionResult(
                    id: 'ext-empty-eating',
                    uid: uid,
                    source: RoutineImportReviewSource.eating,
                    createdAt: DateTime.now(),
                    candidates: const [],
                    warnings: const [
                      'No meals could be recognized in the image.',
                    ],
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: EatingBaseSetupScreen(onBack: () {}),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final moreButton = find.byKey(
          const Key('base-timeline-header-menu-button'),
        );
        await tester.tap(moreButton);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Change source'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Import from Photo'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Choose from Gallery'));
        await tester.pumpAndSettle();

        // Error message shown
        expect(
          find.text('No meals could be recognized in the image.'),
          findsWidgets,
        );

        // Existing block preserved in review
        expect(find.text('Existing Lunch'), findsOneWidget);

        // Candidate asset was retired
        expect(
          trackingAssetRepo.deletedAssetIds,
          contains('cand-failed-eating-photo'),
        );
      },
    );

    testWidgets(
      'Build Balanced Meal Plan sheet collects Step 5 inputs and generates plan',
      (tester) async {
        final now = DateTime.now();
        final setup = BaseTimelineSetup(
          uid: uid,
          updatedAt: now,
          eatingBlocks: const [],
        );

        final fakeOnboardingRepo = FakeOnboardingRepository();
        final fakeSetupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: fakeOnboardingRepo,
        );
        await fakeSetupRepo.saveSetup(uid, setup);
        final fakeRoutineRepo = FakeRoutineRepository();
        final fakeTxRepo = FakeRoutineTransactionRepository(
          routineRepository: fakeRoutineRepo,
          setupRepository: fakeSetupRepo,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userProfileProvider.overrideWith(
                (ref) => UserProfileNotifier()
                  ..loadSeedData(
                    UserProfile(
                      uid: uid,
                      email: 'eating@optivus.local',
                      displayName: 'Eating Test User',
                      height: 175,
                      weight: 72,
                      ageRange: '20-29',
                      gender: 'male',
                    ),
                  ),
              ),
              baseTimelineSetupRepositoryProvider.overrideWithValue(
                fakeSetupRepo,
              ),
              routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
              routineTransactionRepositoryProvider.overrideWithValue(
                fakeTxRepo,
              ),
              eatingDomainEngineProvider.overrideWithValue(
                _FakeEatingDomainEngine(),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: EatingBaseSetupScreen(onBack: () {}),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap Build Balanced Plan directly from empty source selection view
        await tester.tap(find.text('Build Balanced Plan'));
        await tester.pumpAndSettle();

        // Sheet opens
        expect(find.text('Build Balanced Meal Plan'), findsOneWidget);
        expect(find.text('Goal'), findsOneWidget);
        expect(find.text('Meals per Day'), findsOneWidget);
        expect(find.text('Food Culture & Style'), findsOneWidget);
        expect(find.text('Dietary Preference'), findsOneWidget);

        // Select 4 meals
        await tester.tap(find.text('4 meals'));
        await tester.pumpAndSettle();

        // Select Gain
        await tester.tap(find.text('Gain'));
        await tester.pumpAndSettle();

        final generateBtn = find.text('Generate Balanced Plan');
        await tester.scrollUntilVisible(
          generateBtn,
          200,
          scrollable: find.descendant(
            of: find.byType(EatingPlanSettingsSheet),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(generateBtn);
        await tester.pumpAndSettle();

        // Generated plan has populated review editor!
        expect(find.text('Breakfast'), findsWidgets);
        expect(find.text('Lunch'), findsWidgets);
        expect(find.text('Dinner'), findsWidgets);

        // Tap Save
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Setup in repository now has generated eating setup path
        final updatedSetup = await fakeSetupRepo.fetchSetup(uid);
        expect(updatedSetup.eatingSetupPath, equals('create'));
        expect(updatedSetup.mealPlanningGoal, equals('gain'));
        expect(updatedSetup.mealsPerDay, equals(4));
        expect(updatedSetup.eatingBlocks, isNotEmpty);
      },
    );

    test(
      'EatingCandidateDishNormalizer preserves multi-word dishes and removes metadata noise',
      () {
        final candidate = RoutineImportCandidateBlock(
          id: 'c1',
          title: 'Lunch',
          startMinute: 720,
          endMinute: 760,
          repeatDays: const [1, 2, 3, 4, 5],
          blockType: 'soft',
          category: 'eating',
          hardBlock: false,
          mealCategory: 'Lunch',
          mealSlot: 'lunch',
          steps: const [
            'Dal Tadka',
            'Chicken 65',
            'PB&J Sandwich',
            'Greek Yogurt',
            'Lunch',
            '500 kcal',
            'High protein',
            'Meal 2',
          ],
        );

        final normalized = EatingCandidateDishNormalizer.extractDishes(
          candidate,
        );
        expect(normalized, contains('Dal Tadka'));
        expect(normalized, contains('Chicken 65'));
        expect(normalized, contains('PB&J Sandwich'));
        expect(normalized, contains('Greek Yogurt'));
        expect(normalized, isNot(contains('Lunch')));
        expect(normalized, isNot(contains('500 kcal')));
        expect(normalized, isNot(contains('High protein')));
        expect(normalized, isNot(contains('Meal 2')));

        // Test fallback from title
        final candidateTitleOnly = RoutineImportCandidateBlock(
          id: 'c2',
          title: 'Paneer Bhurji & Roti',
          startMinute: 780,
          endMinute: 810,
          repeatDays: const [1, 2, 3, 4, 5],
          blockType: 'soft',
          category: 'eating',
          hardBlock: false,
        );
        final fromTitle = EatingCandidateDishNormalizer.extractDishes(
          candidateTitleOnly,
        );
        expect(fromTitle, equals(['Paneer Bhurji & Roti']));

        // Title that is just meal metadata should NOT be used as a dish
        final candidateGenericTitle = RoutineImportCandidateBlock(
          id: 'c3',
          title: 'Dinner',
          startMinute: 1200,
          endMinute: 1240,
          repeatDays: const [1, 2, 3, 4, 5],
          blockType: 'soft',
          category: 'eating',
          hardBlock: false,
        );
        final fromGenericTitle = EatingCandidateDishNormalizer.extractDishes(
          candidateGenericTitle,
        );
        expect(fromGenericTitle, isEmpty);
      },
    );

    test(
      'EatingPlanFreshness correctly evaluates current, stale, and unknown states',
      () {
        final engine = EatingDomainEngine(
          client: const MissingConfigNutritionAiClient(),
        );
        final profile = UserProfile(
          uid: uid,
          email: 'eating@optivus.local',
          displayName: 'Eating Test User',
          height: 175,
          weight: 70,
          ageRange: '20-29',
          gender: 'male',
        );

        final setup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          eatingSetupPath: 'create',
          mealPlanningGoal: 'maintain',
          mealsPerDay: 3,
          breakfastMinute: 8 * 60,
          lunchMinute: 13 * 60,
          dinnerMinute: 19 * 60,
        );

        final targets = engine.calculateTargets(profile: profile, setup: setup);
        final inputs = engine.buildInputs(
          profile: profile,
          setup: setup,
          targets: targets,
        );
        final fingerprint = inputs.computeFingerprint();

        // Matching fingerprint -> current
        final setupWithFingerprint = setup.copyWith(
          eatingGeneratedInputFingerprint: fingerprint,
        );
        expect(
          EatingPlanFreshness.evaluate(
            setup: setupWithFingerprint,
            profile: profile,
            engine: engine,
          ),
          equals(EatingPlanFreshness.current),
        );

        // Non-generated plan -> current
        final photoSetup = setup.copyWith(
          eatingSetupPath: 'has_routine',
          eatingGeneratedInputFingerprint: 'old-fingerprint',
        );
        expect(
          EatingPlanFreshness.evaluate(
            setup: photoSetup,
            profile: profile,
            engine: engine,
          ),
          equals(EatingPlanFreshness.current),
        );

        // Changed profile weight -> stale
        final changedProfile = profile.copyWith(weight: 85);
        expect(
          EatingPlanFreshness.evaluate(
            setup: setupWithFingerprint,
            profile: changedProfile,
            engine: engine,
          ),
          equals(EatingPlanFreshness.stale),
        );

        // Missing body basics (null weight/height) -> unknown
        final incompleteProfile = UserProfile(
          uid: uid,
          email: 'incomplete@optivus.local',
          displayName: 'No Basics',
        );
        expect(
          EatingPlanFreshness.evaluate(
            setup: setupWithFingerprint,
            profile: incompleteProfile,
            engine: engine,
          ),
          equals(EatingPlanFreshness.unknown),
        );
      },
    );

    test('EatingSourceTransitionPolicy guarantees clean draft transitions', () {
      // toPhoto clears all generation preferences and targets
      final photoDraft = EatingSourceTransitionPolicy.toPhoto(
        blocks: const [],
        photoAssetId: 'photo-1',
        photoR2Key: 'key-1',
      );
      expect(photoDraft.setupPath, equals('has_routine'));
      expect(photoDraft.photoAssetId, equals('photo-1'));
      expect(photoDraft.photoR2Key, equals('key-1'));
      expect(photoDraft.mealsPerDay, isNull);
      expect(photoDraft.targetCalories, isNull);
      expect(photoDraft.targetProtein, isNull);
      expect(photoDraft.inputFingerprint, isNull);
      expect(photoDraft.planVersion, isNull);
      expect(photoDraft.customized, isFalse);

      // toManual clears photo and generation metadata
      final manualDraft = EatingSourceTransitionPolicy.toManual(
        blocks: const [],
      );
      expect(manualDraft.setupPath, equals('manual'));
      expect(manualDraft.photoAssetId, isNull);
      expect(manualDraft.photoR2Key, isNull);
      expect(manualDraft.mealsPerDay, isNull);
      expect(manualDraft.targetCalories, isNull);
      expect(manualDraft.targetProtein, isNull);
      expect(manualDraft.inputFingerprint, isNull);

      // toGenerated sets generation parameters and clears photo
      final genDraft = EatingSourceTransitionPolicy.toGenerated(
        blocks: const [],
        goal: 'gain',
        mealsPerDay: 4,
        targetCalories: 2600,
        targetProtein: 150,
        planVersion: 2,
        inputFingerprint: 'fp-123',
        customized: false,
      );
      expect(genDraft.setupPath, equals('create'));
      expect(genDraft.photoAssetId, isNull);
      expect(genDraft.goal, equals('gain'));
      expect(genDraft.mealsPerDay, equals(4));
      expect(genDraft.targetCalories, equals(2600));
      expect(genDraft.targetProtein, equals(150));
      expect(genDraft.planVersion, equals(2));
      expect(genDraft.inputFingerprint, equals('fp-123'));
      expect(genDraft.customized, isFalse);
    });

    test(
      'replaceEatingGeneratedConfiguration explicitly nulls unpassed fields',
      () {
        final initial = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          eatingSetupPath: 'create',
          mealPlanningGoal: 'fat_loss',
          mealsPerDay: 3,
          eatingMode: 'vegetarian',
          foodType: 'home_cooked',
          foodStyleCustomText: 'No dairy',
          targetCalories: 2000,
          targetProtein: 130,
          eatingPhotoAssetId: 'old-photo',
          eatingPhotoR2Key: 'old-key',
        );

        final replaced = initial.replaceEatingGeneratedConfiguration(
          blocks: const [],
          goal: 'gain',
          meals: 4,
          mode: null,
          type: null,
          styleCustomText: null,
          calories: null,
          protein: null,
          planVersion: 2,
          inputFingerprint: 'new-fp',
          customized: false,
        );

        expect(replaced.mealPlanningGoal, equals('gain'));
        expect(replaced.mealsPerDay, equals(4));
        expect(replaced.eatingMode, isNull);
        expect(replaced.foodType, isNull);
        expect(replaced.foodStyleCustomText, isNull);
        expect(replaced.targetCalories, isNull);
        expect(replaced.targetProtein, isNull);
        expect(replaced.eatingPhotoAssetId, isNull);
        expect(replaced.eatingPhotoR2Key, isNull);
        expect(replaced.eatingGeneratedPlanVersion, equals(2));
        expect(replaced.eatingGeneratedInputFingerprint, equals('new-fp'));
        expect(replaced.eatingCustomized, isFalse);
      },
    );

    test(
      'validateBeforeSave distinguishes pristine AI plans from customized plans',
      () {
        final engine = EatingDomainEngine(
          client: const MissingConfigNutritionAiClient(),
        );

        // Incomplete block schedule: only 1 meal on 1 day
        final singleMealBlock = TimelineBlockDraft(
          id: 'b1',
          section: 'eating',
          title: 'Single Lunch',
          startMinute: 12 * 60,
          endMinute: 13 * 60,
          repeatDays: const [1],
          blockType: TimelineBlockDraft.softBlockKey,
          mealSlot: 'lunch',
          dishes: const ['Chicken Salad'],
          source: 'ai_generated_meal_setup',
        );

        // Pristine AI plan: eatingCustomized == false -> requires full weekly coverage
        final pristineSetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          eatingSetupPath: 'create',
          eatingCustomized: false,
          eatingBlocks: [singleMealBlock],
        );
        final pristineErr = engine.validateBeforeSave(
          blocks: [singleMealBlock],
          setup: pristineSetup,
        );
        expect(pristineErr, isNotNull);
        expect(pristineErr, contains('missing required meals for all 7 days'));

        // Customized plan: eatingCustomized == true -> only requires schedule integrity
        final customizedSetup = pristineSetup.copyWith(eatingCustomized: true);
        final customizedErr = engine.validateBeforeSave(
          blocks: [singleMealBlock],
          setup: customizedSetup,
        );
        expect(customizedErr, isNull);
      },
    );

    test(
      'EatingSetupErrorMapper provides actionable messages for timeout, worker, and diversity errors',
      () {
        expect(
          EatingSetupErrorMapper.mapError(TimeoutException('Timed out')),
          equals(
            'The request timed out. Please check your connection and try again.',
          ),
        );
        expect(
          EatingSetupErrorMapper.mapError(Exception('503 Service Unavailable')),
          equals(
            'AI generation service is currently unavailable. Please try again later.',
          ),
        );
        expect(
          EatingSetupErrorMapper.mapError(
            Exception('Macro tolerance exceeded'),
          ),
          equals(
            'Generated meal plan could not meet required nutritional tolerances. Please adjust preferences and try again.',
          ),
        );
        expect(
          EatingSetupErrorMapper.mapError(
            Exception('Weekly diversity check failed'),
          ),
          equals(
            'Generated meal plan did not meet weekly diversity requirements. Please try again.',
          ),
        );
      },
    );

    test(
      'EatingTimelineCard minimumHeight accounts for multi-line location and notes',
      () {
        const singleLineBlock = TimelineBlockDraft(
          id: 't1',
          section: 'eating',
          title: 'Breakfast',
          startMinute: 480,
          endMinute: 510,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
          dishes: ['Oatmeal'],
        );
        final h1 = EatingTimelineCard.minimumHeight(singleLineBlock);

        const multiLineBlock = TimelineBlockDraft(
          id: 't2',
          section: 'eating',
          title: 'Breakfast',
          startMinute: 480,
          endMinute: 510,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
          dishes: ['Oatmeal'],
          location: 'Office Cafeteria Level 4, Building B',
          notes:
              'Low sodium option. Ask chef to prepare with olive oil and separate dressing.',
        );
        final h2 = EatingTimelineCard.minimumHeight(multiLineBlock);

        expect(h2, greaterThan(h1));
      },
    );
  });
}
