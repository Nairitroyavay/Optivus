import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/eating_base_setup_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_upload_lifecycle_helper.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_current_setup_header.dart';
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
        expect(find.text('Change setup'), findsOneWidget);
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

        expect(find.text('Reset Eating Setup'), findsOneWidget);
        await tester.tap(find.text('Reset Eating Setup'));
        await tester.pumpAndSettle();

        expect(find.text('Reset Eating Setup?'), findsOneWidget);
        expect(
          find.text(
            'This will remove your custom eating schedule and reset all meal planning preferences to default. This action cannot be undone.',
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
        await tester.tap(find.text('Reset Eating Setup'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Reset'));
        await tester.pumpAndSettle();

        expect(
          find.text('Eating schedule reset successfully.'),
          findsOneWidget,
        );

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
      await tester.tap(find.text('Change setup'));
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

        await tester.tap(find.text('Change setup'));
        await tester.pumpAndSettle();

        // Tap Scan Photo -> Gallery
        await tester.tap(find.text('Scan Photo'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose from Gallery'));
        await tester.pumpAndSettle();

        // Error message shown
        expect(
          find.text('No meals could be recognized in the image.'),
          findsOneWidget,
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

        // Tap Set up Eating
        await tester.tap(find.text('Set up Eating'));
        await tester.pumpAndSettle();

        // Tap Build Balanced Plan
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

        // Tap Generate Balanced Plan
        final generateBtn = find.text('Generate Balanced Plan');
        await tester.scrollUntilVisible(generateBtn, 200);
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
  });
}
