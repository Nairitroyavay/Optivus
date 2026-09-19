import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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
import 'package:optivus/features/routine/managers/base_timeline/widgets/eating_meal_detail_sheet.dart';
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
import 'package:optivus/features/routine/managers/base_timeline/widgets/eating_plan_summary_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/eating_operation_session.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/nutrition_ai_failure.dart';

// Test Stubs
class _FailingHttpClient extends http.BaseClient {
  final Exception exception;
  _FailingHttpClient(this.exception);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw exception;
  }
}

class _ThrowingEatingDomainEngine extends EatingDomainEngine {
  final Object errorToThrow;
  _ThrowingEatingDomainEngine(this.errorToThrow)
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
    throw errorToThrow;
  }
}

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
    http.Client? client,
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

      // Delete the only block via EatingMealEditSheet
      await tester.tap(find.text('Breakfast').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete this Meal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Tap Save bottom CTA
      await tester.tap(
        find.byKey(const Key('base-timeline-eating-save-button')),
      );
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

        await tester.tap(find.text('Choose from gallery'));
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
        await tester.tap(find.text('Build personalized plan'));
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
          scrollable: find
              .descendant(
                of: find.byType(EatingPlanSettingsSheet),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(generateBtn);
        await tester.pumpAndSettle();

        // Generated plan has populated review editor!
        expect(find.text('Breakfast'), findsWidgets);
        expect(find.text('Lunch'), findsWidgets);
        expect(find.text('Dinner'), findsWidgets);

        // Tap Use this meal plan bottom CTA
        await tester.tap(find.text('Use this meal plan'));
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
            'The meal planner is temporarily experiencing high demand. Please try again in a moment.',
          ),
        );
        expect(
          EatingSetupErrorMapper.mapError(
            Exception('Macro tolerance exceeded'),
          ),
          equals(
            'The meal plan could not meet your nutritional targets. Try adjusting your schedule or targets.',
          ),
        );
        expect(
          EatingSetupErrorMapper.mapError(
            Exception('Weekly diversity check failed'),
          ),
          equals(
            'The generated meal plan was not varied enough across the week. Please try again.',
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

    test(
      'Target overrides vs calculated targets: model support and precedence in EatingDomainEngine',
      () {
        // 1. Model support and serialization
        final setupWithOverrides = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          targetCaloriesOverride: 2350,
          targetProteinOverride: 165,
        );
        expect(setupWithOverrides.hasTargetOverrides, isTrue);

        final map = setupWithOverrides.toMap();
        expect(map['targetCaloriesOverride'], equals(2350));
        expect(map['targetProteinOverride'], equals(165));

        final reconstructed = BaseTimelineSetup.fromMap(map, uid: uid);
        expect(reconstructed.targetCaloriesOverride, equals(2350));
        expect(reconstructed.targetProteinOverride, equals(165));
        expect(reconstructed.hasTargetOverrides, isTrue);

        // 2. Precedence in buildInputs
        final engine = EatingDomainEngine(
          client: const MissingConfigNutritionAiClient(),
        );
        final userProfile = UserProfile(
          uid: uid,
          email: 'test@example.com',
          displayName: 'Test User',
          height: 175.0,
          weight: 75.0,
          gender: 'male',
          ageRange: '20-29',
        );
        const calculatedTargets = NutritionTargets(
          bmi: 24.5,
          estimatedAge: 30,
          estimatedBmr: 1700,
          activityFactor: 1.3,
          estimatedMaintenanceCalories: 2200,
          targetCalories: 2200,
          proteinTarget: 150.0,
          bodyGoal: 'maintain',
          hasBodyBasics: true,
        );

        // Case A: Override is present -> takes absolute precedence
        final inputsWithOverride = engine.buildInputs(
          profile: userProfile,
          setup: setupWithOverrides.copyWith(targetCalories: 2000),
          targets: calculatedTargets,
        );
        expect(inputsWithOverride.targetCalories, equals(2350));
        expect(inputsWithOverride.proteinTarget, equals(165.0));

        // Case B: No override, setup target is present -> setup target takes precedence over calculated
        final setupWithoutOverride = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          targetCalories: 2050,
          targetProtein: 140,
        );
        expect(setupWithoutOverride.hasTargetOverrides, isFalse);
        final inputsWithSetup = engine.buildInputs(
          profile: userProfile,
          setup: setupWithoutOverride,
          targets: calculatedTargets,
        );
        expect(inputsWithSetup.targetCalories, equals(2050));
        expect(inputsWithSetup.proteinTarget, equals(140.0));

        // Case C: Neither override nor setup target -> calculated target is used
        final setupEmpty = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
        );
        final inputsCalculated = engine.buildInputs(
          profile: userProfile,
          setup: setupEmpty,
          targets: calculatedTargets,
        );
        expect(inputsCalculated.targetCalories, equals(2200));
        expect(inputsCalculated.proteinTarget, equals(150.0));
      },
    );

    testWidgets(
      'EatingPlanSummaryCard displays truthful target labels (Custom target vs Calculated from Body Basics)',
      (tester) async {
        // Case 1: Custom target override
        final customSetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          eatingSetupPath: 'create',
          eatingCustomized: false,
          targetCaloriesOverride: 2400,
          targetProteinOverride: 170,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: EatingPlanSummaryCard(setup: customSetup)),
          ),
        );
        expect(find.textContaining('(Custom target)'), findsOneWidget);
        expect(
          find.textContaining('(Calculated from Body Basics)'),
          findsNothing,
        );

        // Case 2: Calculated from Body Basics
        final calculatedSetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          eatingSetupPath: 'create',
          eatingCustomized: false,
          targetCalories: 2150,
          targetProtein: 155,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: EatingPlanSummaryCard(setup: calculatedSetup)),
          ),
        );
        expect(
          find.textContaining('(Calculated from Body Basics)'),
          findsOneWidget,
        );
        expect(find.textContaining('(Custom target)'), findsNothing);
      },
    );

    testWidgets(
      'EatingPlanSummaryCard matches BaseTimeline context card style and handles interactions',
      (tester) async {
        var settingsOpened = false;
        var photoOpened = false;
        var regenerated = false;

        // Test 1: Generated setup with settings button and stale warning
        final generatedSetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          eatingSetupPath: 'create',
          eatingCustomized: true,
          mealPlanningGoal: 'maintain',
          targetCalories: 2000,
          targetProtein: 140,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EatingPlanSummaryCard(
                setup: generatedSetup,
                isStale: true,
                onOpenSettings: () => settingsOpened = true,
                onRegenerate: () => regenerated = true,
              ),
            ),
          ),
        );

        // Header and badges
        expect(find.text('NUTRITION PLAN'), findsOneWidget);
        expect(find.text('Customized'), findsOneWidget);
        expect(find.text('Maintain weight'), findsOneWidget);
        expect(find.text('Maintain Weight Plan'), findsOneWidget);
        expect(
          find.text('2000 kcal · 140 g protein (Calculated from Body Basics)'),
          findsOneWidget,
        );

        // Action button
        expect(find.byKey(const Key('eating-summary-plan-settings-button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('eating-summary-plan-settings-button')));
        expect(settingsOpened, isTrue);

        // Stale warning and regenerate button
        expect(
          find.text('Your Eating Plan was generated from older preferences.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('eating-summary-stale-regenerate-button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('eating-summary-stale-regenerate-button')));
        expect(regenerated, isTrue);

        // Test 2: Photo setup with view photo action
        final photoSetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          eatingSetupPath: 'photo',
          eatingCustomized: false,
          eatingPhotoR2Key: 'photos/meal_plan.jpg',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EatingPlanSummaryCard(
                setup: photoSetup,
                onViewPhoto: () => photoOpened = true,
              ),
            ),
          ),
        );

        expect(find.text('MEAL PLAN PHOTO'), findsOneWidget);
        expect(find.text('Photo synced'), findsOneWidget);
        expect(find.text('Imported Meal Plan'), findsOneWidget);
        expect(find.byKey(const Key('eating-summary-view-photo-button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('eating-summary-view-photo-button')));
        expect(photoOpened, isTrue);

        // Test 3: Manual setup
        final manualSetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          eatingSetupPath: 'manual',
          eatingCustomized: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EatingPlanSummaryCard(setup: manualSetup),
            ),
          ),
        );

        expect(find.text('MANUAL MEAL PLAN'), findsOneWidget);
        expect(find.text('Custom plan'), findsOneWidget);
        expect(find.text('Manual setup'), findsOneWidget);
        expect(find.text('Manual Eating Plan'), findsOneWidget);
      },
    );

    testWidgets(
      'EatingPlanSettingsSheet preserves null preferred times when untouched and requires explicit selections on regenerate',
      (tester) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        EatingPlanSettingsResult? savedResult;

        // 1. Initial state with null preferred times
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      savedResult = await EatingPlanSettingsSheet.show(
                        context,
                        isNew: false,
                        initialGoal: 'maintain',
                        initialMealsPerDay: 3,
                        initialEatingMode: 'balanced',
                        initialFoodType: 'mixed',
                        initialBreakfastMinute: null, // Legacy null times
                        initialLunchMinute: null,
                        initialDinnerMinute: null,
                      );
                    },
                    child: const Text('Open Settings'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Settings'));
        await tester.pumpAndSettle();

        // Visible default labels are rendered for untouched null times
        expect(find.text('Default (8:00 AM)'), findsOneWidget);
        expect(find.text('Default (1:00 PM)'), findsOneWidget);
        expect(find.text('Default (8:30 PM)'), findsOneWidget);

        // Tap 'Lose' to change goal from maintain -> lose, marking form dirty
        await tester.tap(find.text('Lose'));
        await tester.pumpAndSettle();

        // Scroll down to make Save Settings button visible and tap it
        await tester.scrollUntilVisible(
          find.text('Save settings'),
          100.0,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Save settings'));
        await tester.pumpAndSettle();

        expect(savedResult, isNotNull);
        expect(savedResult!.goal, equals('lose'));
        expect(savedResult!.breakfastMinute, isNull);
        expect(savedResult!.lunchMinute, isNull);
        expect(savedResult!.dinnerMinute, isNull);

        // 2. Regeneration requires explicit selections for legacy unconfigured plans
        EatingPlanSettingsResult? regenerateResult;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      regenerateResult = await EatingPlanSettingsSheet.show(
                        context,
                        isNew: false,
                        regenerateActionLabel: 'Regenerate Plan',
                        // Null selections
                        initialGoal: null,
                        initialMealsPerDay: null,
                        initialEatingMode: null,
                        initialFoodType: null,
                      );
                    },
                    child: const Text('Open New Settings'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open New Settings'));
        await tester.pumpAndSettle();

        // Scroll down to make Regenerate Plan button visible
        await tester.scrollUntilVisible(
          find.text('Regenerate Plan'),
          100.0,
          scrollable: find.byType(Scrollable).first,
        );

        // Tap Regenerate Plan without making selections
        await tester.tap(find.text('Regenerate Plan'));
        await tester.pumpAndSettle();

        // Validation error is displayed and modal does not dismiss
        expect(
          find.textContaining(
            'Please select a meal planning goal before generating.',
          ),
          findsOneWidget,
        );
        expect(regenerateResult, isNull);
      },
    );

    test(
      'Decoupled settings save from strict AI macro validation (stale plans remain saveable)',
      () {
        final engine = EatingDomainEngine(
          client: const MissingConfigNutritionAiClient(),
        );

        // Valid 7-day 21-meal schedule structure (each meal has >= 2 dishes)
        final fullWeekBlocks = <TimelineBlockDraft>[];
        for (var day = 1; day <= 7; day++) {
          fullWeekBlocks.addAll([
            TimelineBlockDraft(
              id: 'b_b_$day',
              section: 'eating',
              title: 'Day $day Breakfast',
              startMinute: 8 * 60,
              endMinute: 8 * 60 + 30,
              repeatDays: [day],
              blockType: TimelineBlockDraft.softBlockKey,
              mealSlot: 'breakfast',
              dishes: ['Oatmeal $day', 'Fruit $day'],
              calories: 400,
              protein: 20,
              source: 'ai_generated_meal_setup',
            ),
            TimelineBlockDraft(
              id: 'b_l_$day',
              section: 'eating',
              title: 'Day $day Lunch',
              startMinute: 13 * 60,
              endMinute: 13 * 60 + 45,
              repeatDays: [day],
              blockType: TimelineBlockDraft.softBlockKey,
              mealSlot: 'lunch',
              dishes: ['Chicken Bowl $day', 'Brown Rice $day'],
              calories: 500,
              protein: 35,
              source: 'ai_generated_meal_setup',
            ),
            TimelineBlockDraft(
              id: 'b_d_$day',
              section: 'eating',
              title: 'Day $day Dinner',
              startMinute: 19 * 60,
              endMinute: 19 * 60 + 45,
              repeatDays: [day],
              blockType: TimelineBlockDraft.softBlockKey,
              mealSlot: 'dinner',
              dishes: ['Salmon Dinner $day', 'Steamed Broccoli $day'],
              calories: 600,
              protein: 45,
              source: 'ai_generated_meal_setup',
            ),
          ]);
        }

        final pristineSetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          eatingSetupPath: 'create',
          eatingCustomized: false,
          mealsPerDay: 3,
          targetCalories: 2500,
          eatingBlocks: fullWeekBlocks,
        );

        const staleTargets = NutritionTargets(
          bmi: 22.0,
          estimatedAge: 25,
          estimatedBmr: 1600,
          activityFactor: 1.3,
          estimatedMaintenanceCalories: 2500,
          targetCalories: 2500,
          proteinTarget: 140.0,
          bodyGoal: 'maintain',
          hasBodyBasics: true,
        );

        // 1. Saving an existing plan (isFreshAiGeneration: false) must NOT fail on macro deviation
        final saveErr = engine.validateBeforeSave(
          blocks: fullWeekBlocks,
          setup: pristineSetup,
          targets: staleTargets,
          isFreshAiGeneration: false,
        );
        expect(saveErr, isNull);

        // 2. Fresh generation validation (isFreshAiGeneration: true) MUST enforce macro tolerance
        final freshErr = engine.validateBeforeSave(
          blocks: fullWeekBlocks,
          setup: pristineSetup,
          targets: staleTargets,
          isFreshAiGeneration: true,
        );
        expect(freshErr, isNotNull);
        expect(freshErr, contains('calorie'));
      },
    );

    test(
      'Missing or empty fingerprint on generated plans evaluates to EatingPlanFreshness.unknown',
      () {
        final setupNoFingerprint = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          eatingSetupPath: 'create',
          eatingGeneratedInputFingerprint: null,
          eatingBlocks: const [
            TimelineBlockDraft(
              id: 'm1',
              section: 'eating',
              title: 'Meal 1',
              startMinute: 480,
              endMinute: 510,
              repeatDays: [1],
              blockType: TimelineBlockDraft.softBlockKey,
            ),
          ],
        );
        final profile = UserProfile(
          uid: uid,
          email: 'test@example.com',
          displayName: 'Test',
        );
        final engine = EatingDomainEngine(
          client: const MissingConfigNutritionAiClient(),
        );

        final freshness = EatingPlanFreshness.evaluate(
          setup: setupNoFingerprint,
          profile: profile,
          engine: engine,
        );
        expect(freshness, equals(EatingPlanFreshness.unknown));

        final setupEmptyFingerprint = setupNoFingerprint.copyWith(
          eatingGeneratedInputFingerprint: '',
        );
        final freshnessEmpty = EatingPlanFreshness.evaluate(
          setup: setupEmptyFingerprint,
          profile: profile,
          engine: engine,
        );
        expect(freshnessEmpty, equals(EatingPlanFreshness.unknown));
      },
    );

    test(
      'EatingImportReviewSheet minute validation correctly allows endMinute up to 1439 (23:59)',
      () {
        const validLateNightBlock = TimelineBlockDraft(
          id: 'late_dinner',
          section: 'eating',
          title: 'Late Dinner',
          startMinute: 23 * 60, // 1380
          endMinute: 1439, // 23:59
          repeatDays: [1, 2, 3],
          blockType: TimelineBlockDraft.softBlockKey,
          dishes: ['Soup'],
        );

        const invalidPastMidnightBlock = TimelineBlockDraft(
          id: 'past_midnight',
          section: 'eating',
          title: 'Midnight Snack',
          startMinute: 23 * 60,
          endMinute: 1440, // 24:00 -> invalid!
          repeatDays: [1, 2, 3],
          blockType: TimelineBlockDraft.softBlockKey,
          dishes: ['Toast'],
        );

        final engine = EatingDomainEngine(
          client: const MissingConfigNutritionAiClient(),
        );
        final manualSetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          eatingSetupPath: 'manual',
        );

        // Schedule integrity check via validateBeforeSave
        final validErr = engine.validateBeforeSave(
          blocks: [validLateNightBlock],
          setup: manualSetup,
        );
        expect(validErr, isNull);

        final invalidErr = engine.validateBeforeSave(
          blocks: [invalidPastMidnightBlock],
          setup: manualSetup,
        );
        expect(invalidErr, isNotNull);
        expect(invalidErr, contains('within a valid day range'));
      },
    );

    test(
      'Authoritative save branching in BaseTimelineSetup strictly adheres to setupPath and preserves target overrides',
      () {
        final base = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          eatingPhotoAssetId: 'old-asset',
          eatingPhotoR2Key: 'old-key',
          mealPlanningGoal: 'maintain',
          mealsPerDay: 3,
          eatingMode: 'balanced',
          foodType: 'mixed',
          targetCaloriesOverride: 2200,
          targetProteinOverride: 160,
        );

        const sampleBlock = TimelineBlockDraft(
          id: 'b1',
          section: 'eating',
          title: 'Lunch',
          startMinute: 720,
          endMinute: 765,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
          dishes: ['Chicken Bowl', 'Rice'],
        );

        // 1. Photo path ('has_routine')
        final photoResult = base.asEatingPhoto(
          photoAssetId: 'new-asset',
          photoR2Key: 'new-key',
          blocks: const [sampleBlock],
          meals: 3,
        );
        expect(photoResult.eatingSetupPath, equals('has_routine'));
        expect(photoResult.eatingPhotoAssetId, equals('new-asset'));
        expect(photoResult.eatingPhotoR2Key, equals('new-key'));
        expect(photoResult.mealPlanningGoal, isNull);
        expect(photoResult.eatingMode, isNull);
        expect(photoResult.foodType, isNull);
        expect(photoResult.targetCaloriesOverride, isNull);
        expect(photoResult.targetProteinOverride, isNull);

        // 2. Manual path ('manual')
        final manualResult = base.asEatingManual(
          blocks: const [sampleBlock],
          meals: 3,
          targetCaloriesOverride: 2300,
          targetProteinOverride: 170,
        );
        expect(manualResult.eatingSetupPath, equals('manual'));
        expect(manualResult.eatingPhotoAssetId, isNull);
        expect(manualResult.eatingPhotoR2Key, isNull);
        expect(manualResult.targetCaloriesOverride, equals(2300));
        expect(manualResult.targetProteinOverride, equals(170));
        expect(manualResult.hasTargetOverrides, isTrue);

        // 3. Generated path ('create')
        final generatedResult = base.replaceEatingGeneratedConfiguration(
          blocks: const [sampleBlock],
          goal: 'gain',
          meals: 4,
          mode: 'balanced',
          type: 'mixed',
          breakfast: 480,
          lunch: 780,
          dinner: 1200,
          snack: 960,
          caloriesOverride: 2500,
          proteinOverride: 180,
          planVersion: BaseTimelineDraft.currentGate2EatingPlanVersion,
          inputFingerprint: 'fp123',
        );
        expect(generatedResult.eatingSetupPath, equals('create'));
        expect(generatedResult.eatingPhotoAssetId, isNull);
        expect(generatedResult.eatingPhotoR2Key, isNull);
        expect(generatedResult.mealPlanningGoal, equals('gain'));
        expect(generatedResult.mealsPerDay, equals(4));
        expect(generatedResult.targetCaloriesOverride, equals(2500));
        expect(generatedResult.targetProteinOverride, equals(180));
        expect(generatedResult.hasTargetOverrides, isTrue);
        expect(
          generatedResult.eatingGeneratedPlanVersion,
          equals(BaseTimelineDraft.currentGate2EatingPlanVersion),
        );
        expect(
          generatedResult.eatingGeneratedInputFingerprint,
          equals('fp123'),
        );
      },
    );

    test(
      'EatingOperationSession lifecycle and photo extraction cancel contract',
      () {
        // Initial uploading session
        final uploadSession = EatingOperationSession(
          generationId: 1,
          ownerUid: uid,
          type: EatingOperationType.uploading,
        );
        expect(uploadSession.type, equals(EatingOperationType.uploading));
        expect(uploadSession.candidateAssetId, isNull);

        // Extraction session with candidate asset
        final extractingSession = EatingOperationSession(
          generationId: 1,
          ownerUid: uid,
          type: EatingOperationType.extracting,
          candidateAssetId: 'cand-asset-1',
          candidateR2Key: 'cand-key-1',
        );
        expect(extractingSession.type, equals(EatingOperationType.extracting));
        expect(extractingSession.candidateAssetId, equals('cand-asset-1'));
        expect(extractingSession.candidateR2Key, equals('cand-key-1'));
      },
    );

    test(
      'NutritionAiClient handles cancellation and maps to provider_cancelled failure',
      () async {
        final client = WorkerNutritionAiClient(
          baseUrl: 'https://nutrition-worker.optivus.local',
          client: _FailingHttpClient(http.ClientException('Connection closed')),
        );

        final result = await client.generateEatingRoutine(
          uid: uid,
          idToken: 'token',
          params: const {},
        );

        expect(result.warnings, contains('provider_cancelled'));
        final failure = NutritionAiFailure.fromObject(result.warnings.first);
        expect(failure.type, equals(NutritionAiFailureType.cancelled));
        expect(failure.safeMessage, equals('Meal generation was cancelled.'));
        expect(failure.canRetry, isFalse);
      },
    );

    test(
      'EatingGenerationInputs propagates personalization parameters to worker params',
      () {
        const inputs = EatingGenerationInputs(
          contractVersion: BaseTimelineDraft.currentGate2EatingPlanVersion,
          heightCm: 180,
          weightKg: 75,
          estimatedAge: 28,
          gender: 'female',
          exerciseLevel: 'high',
          lifeRole: 'software_engineer',
          bmi: 23.1,
          estimatedBmr: 1600,
          estimatedMaintenanceCalories: 2200,
          bodyGoal: 'gain',
          targetMode: 'mild_surplus',
          targetCalories: 2400,
          proteinTarget: 140,
          foodType: 'mediterranean',
          foodStyleCustomText: null,
          eatingMode: 'balanced',
          mealsPerDay: 3,
          breakfastMinute: 480,
          morningSnackMinute: null,
          lunchMinute: 780,
          afternoonSnackMinute: null,
          dinnerMinute: 1200,
          country: 'Canada',
          foodsToAvoid: ['shellfish', 'peanuts'],
        );

        final params = inputs.toWorkerParams();
        expect(
          inputs.contractVersion,
          equals(BaseTimelineDraft.currentGate2EatingPlanVersion),
        );
        expect(params['exerciseLevel'], equals('high'));
        expect(params['lifeRole'], equals('software_engineer'));
        expect(params['country'], equals('Canada'));
        expect(params['foodsToAvoid'], equals(['shellfish', 'peanuts']));
        expect(params['foodType'], equals('mediterranean'));
        expect(params['eatingMode'], equals('balanced'));
      },
    );

    test(
      'foodsToAvoid is preserved in EatingPlanSettingsResult and BaseTimelineSetup',
      () {
        const result = EatingPlanSettingsResult(
          goal: 'maintain',
          mealsPerDay: 3,
          eatingMode: 'balanced',
          foodType: 'vegetarian',
          foodStyleCustomText: null,
          foodsToAvoid: ['mushrooms', 'gluten'],
          breakfastMinute: 480,
          extraSnackMinute: null,
          lunchMinute: 780,
          snackMinute: null,
          dinnerMinute: 1200,
          targetCalories: 2000,
          targetProtein: 120,
          shouldRegenerate: true,
        );
        expect(result.foodsToAvoid, equals(['mushrooms', 'gluten']));

        final setup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          foodsToAvoid: const ['mushrooms', 'gluten'],
        );
        expect(setup.foodsToAvoid, equals(['mushrooms', 'gluten']));

        final copied = setup.copyWith(foodsToAvoid: const ['dairy']);
        expect(copied.foodsToAvoid, equals(['dairy']));

        final map = setup.toMap();
        expect(map['foodsToAvoid'], equals(['mushrooms', 'gluten']));
        final deserialized = BaseTimelineSetup.fromMap(map, uid: uid);
        expect(deserialized.foodsToAvoid, equals(['mushrooms', 'gluten']));
      },
    );

    testWidgets(
      'Configured view tap behavior: tapping card opens EatingMealDetailSheet and Edit schedule is available',
      (tester) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final now = DateTime.now();
        final setup = BaseTimelineSetup(
          uid: uid,
          updatedAt: now,
          mealPlanningGoal: 'maintain',
          mealsPerDay: 3,
          eatingMode: 'balanced',
          foodType: 'mixed',
          breakfastMinute: 8 * 60,
          lunchMinute: 13 * 60,
          dinnerMinute: 20 * 60,
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

        // Configured view: Edit schedule button is present, Add meal is NOT present
        expect(find.text('Edit schedule'), findsOneWidget);
        expect(find.text('Add meal'), findsNothing);

        // Find the meal card
        final cardFinder = find.text('Breakfast');
        expect(cardFinder, findsWidgets);

        // Tap the card in configured view
        await tester.tap(cardFinder.first);
        await tester.pumpAndSettle();

        // EatingMealDetailSheet must be present with meal details
        expect(find.byType(EatingMealDetailSheet), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(EatingMealDetailSheet),
            matching: find.text('Oatmeal'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Rebuild safety: generation failure preserves existing configured plan and leaves editing false',
      (tester) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final now = DateTime.now();
        final originalBlocks = [
          const TimelineBlockDraft(
            id: 'original-breakfast',
            section: 'eating',
            title: 'Original Oatmeal',
            startMinute: 8 * 60,
            endMinute: 8 * 60 + 30,
            repeatDays: [1, 2, 3, 4, 5, 6, 7],
            blockType: TimelineBlockDraft.softBlockKey,
            mealSlot: 'breakfast',
            dishes: ['Steel cut oats'],
          ),
        ];
        final setup = BaseTimelineSetup(
          uid: uid,
          updatedAt: now,
          eatingSetupPath: 'create',
          mealPlanningGoal: 'maintain',
          mealsPerDay: 3,
          eatingMode: 'balanced',
          foodType: 'mixed',
          breakfastMinute: 8 * 60,
          lunchMinute: 13 * 60,
          dinnerMinute: 20 * 60,
          eatingBlocks: originalBlocks,
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

        // Domain engine that always fails generation
        final failingEngine = _ThrowingEatingDomainEngine(
          StateError('provider_high_demand'),
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
              eatingDomainEngineProvider.overrideWithValue(failingEngine),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: EatingBaseSetupScreen(onBack: () {}),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Initial configured view displays original meal
        expect(find.text('Original Oatmeal'), findsWidgets);

        // Tap Settings action to open sheet
        await tester.tap(find.byIcon(Icons.tune_rounded));
        await tester.pumpAndSettle();

        // Sheet is open: tap Regenerate Plan
        final regenBtn = find.text('Regenerate Plan');
        await tester.scrollUntilVisible(
          regenBtn,
          200,
          scrollable: find
              .descendant(
                of: find.byType(EatingPlanSettingsSheet),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(regenBtn);
        await tester.pumpAndSettle();

        // Generation failed:
        // 1. Error snackbar is shown
        expect(
          find.text(
            'The meal planner is temporarily experiencing high demand. Please try again in a moment.',
          ),
          findsOneWidget,
        );
        // 2. Retry button exists in snackbar
        expect(find.text('Retry'), findsOneWidget);
        // 3. Screen stays in configured view (NOT in edit view)
        expect(find.text('Edit schedule'), findsOneWidget);
        expect(find.text('Save'), findsNothing);
        // 4. Original plan is completely intact and still displayed
        expect(find.text('Original Oatmeal'), findsWidgets);
      },
    );
  });
}
