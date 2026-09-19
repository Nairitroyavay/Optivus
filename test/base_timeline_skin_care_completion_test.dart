import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/skin_care_base_setup_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_upload_lifecycle_helper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/skin_care_domain_engine.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_current_setup_header.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/skin_care_ai_client.dart';
import 'package:optivus/services/uploads/image_prepare_service.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/upload_state.dart';

// Test Stubs
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

class _FakeSkinCareAiClient implements SkinCareAiClient {
  final SkinCareAiProductResult? productAnalysisToReturn;

  const _FakeSkinCareAiClient({this.productAnalysisToReturn});

  @override
  Future<SkinCareAiProductResult> analyzeProducts({
    required String uid,
    required String idToken,
    required List<String> productPhotos,
  }) async {
    return productAnalysisToReturn ??
        const SkinCareAiProductResult(
          products: [],
          warnings: ['No products detected in photo.'],
        );
  }

  @override
  Future<SkinCareAiRoutineResult> generateRoutine({
    required String uid,
    required String idToken,
    required Map<String, dynamic> params,
  }) async {
    return SkinCareAiRoutineResult.error('No routine generated.');
  }
}

class _FakeSkinCareDomainEngine extends SkinCareDomainEngine {
  _FakeSkinCareDomainEngine({super.client = const _FakeSkinCareAiClient()});

  @override
  Future<SkinCareBuildResult> generateBuildForMeRoutine({
    required String uid,
    required String idToken,
    required String skinType,
    required List<String> problems,
    required int desiredApplicationsPerDay,
    required BaseTimelineDraft baseTimeline,
    String? budget,
    String? preference,
    String? facePhotoR2Key,
  }) async {
    return SkinCareBuildResult(
      blocks: [
        TimelineBlockDraft(
          id: 'skin-morning-1',
          section: 'skinCare',
          title: 'Morning Skincare',
          startMinute: 7 * 60 + 30,
          endMinute: 7 * 60 + 45,
          repeatDays: const [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
          skincareSlotLabel: 'morning',
          skincareSteps: const ['Cleanser', 'Moisturizer', 'Sunscreen'],
        ),
        TimelineBlockDraft(
          id: 'skin-night-1',
          section: 'skinCare',
          title: 'Night Skincare',
          startMinute: 22 * 60,
          endMinute: 22 * 60 + 15,
          repeatDays: const [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
          skincareSlotLabel: 'night',
          skincareSteps: const ['Cleanser', 'Night Cream'],
        ),
      ],
      productRecommendations: [
        const SkinCareProductRecommendationDraft(
          name: 'Gentle Hydrating Cleanser',
          brand: 'CeraVe',
          category: 'Cleanser',
          estimatedPrice: '12',
          currencyCode: 'USD',
          reason: 'Non-stripping formulation suitable for daily use',
        ),
      ],
      selectedProductNames: const [
        'Gentle Hydrating Cleanser',
        'Daily Moisturizer',
      ],
      specialCareNotes: const ['Always apply sunscreen before sun exposure.'],
    );
  }

  @override
  Future<List<TimelineBlockDraft>> generateRoutineFromProducts({
    required String uid,
    required String idToken,
    required List<SkinCareDetectedProduct> products,
    required String skinType,
    required List<String> problems,
    required int desiredApplicationsPerDay,
    required BaseTimelineDraft baseTimeline,
  }) async {
    return [
      TimelineBlockDraft(
        id: 'skin-product-morning',
        section: 'skinCare',
        title: 'Morning Routine',
        startMinute: 8 * 60,
        endMinute: 8 * 60 + 15,
        repeatDays: const [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.softBlockKey,
        skincareSlotLabel: 'morning',
        skincareSteps: products.map((p) => p.displayName).toList(),
      ),
    ];
  }
}

void main() {
  group('Base Timeline Skin Care Completion Tests', () {
    const uid = 'user-skin-completion-test';

    testWidgets(
      'Skin Care setup screen displays BaseTimelineCurrentSetupHeader and renders cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final now = DateTime.now();
        final setup = BaseTimelineSetup(
          uid: uid,
          updatedAt: now,
          skinCareBlocks: const [
            TimelineBlockDraft(
              id: 'skin-am-1',
              section: 'skinCare',
              title: 'Morning Routine',
              startMinute: 7 * 60,
              endMinute: 7 * 60 + 15,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.softBlockKey,
              skincareSlotLabel: 'morning',
              skincareSteps: ['Wash Face', 'Moisturize'],
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
                      email: 'skincare@optivus.local',
                      displayName: 'Skin Care Test User',
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
              home: SkinCareBaseSetupScreen(onBack: () {}),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(BaseTimelineCurrentSetupHeader), findsOneWidget);
        expect(find.text('Skin Care'), findsWidgets);
        expect(find.text('Change setup'), findsOneWidget);
        final err = tester.takeException();
        expect(err, isNull);
      },
    );

    testWidgets(
      'Reset Skin Care Setup displays confirmation dialog, clears setup, and retires product & face assets',
      (tester) async {
        final now = DateTime.now();
        final setup = BaseTimelineSetup(
          uid: uid,
          updatedAt: now,
          skinCareSetupPath: 'products',
          skinCareProductPhotoAssetId: 'initial-skin-product-asset',
          skinCareProductPhotoR2Key: 'users/$uid/skin/products.jpg',
          skinCareFacePhotoAssetId: 'initial-skin-face-asset',
          skinCareFacePhotoR2Key: 'users/$uid/skin/face.jpg',
          skinCareBlocks: const [
            TimelineBlockDraft(
              id: 'skin-pm-1',
              section: 'skinCare',
              title: 'Night Routine',
              startMinute: 22 * 60,
              endMinute: 22 * 60 + 15,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.softBlockKey,
              skincareSlotLabel: 'night',
              skincareSteps: ['Cleanse', 'Serum'],
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
                      email: 'skincare@optivus.local',
                      displayName: 'Skin Care Test User',
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
              authRepositoryProvider.overrideWithValue(stubAuth),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: SkinCareBaseSetupScreen(onBack: () {}),
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

        expect(find.text('Reset Skin Care Setup'), findsOneWidget);
        await tester.tap(find.text('Reset Skin Care Setup'));
        await tester.pumpAndSettle();

        expect(find.text('Reset Skin Care Setup?'), findsOneWidget);
        expect(
          find.text(
            'This will remove all skin care routine blocks and reset skin care to unconfigured. Your skin care schedule will be cleared from Base Timeline.',
          ),
          findsOneWidget,
        );

        // Cancel first
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        var currentSetup = await fakeSetupRepo.fetchSetup(uid);
        expect(currentSetup.skinCareBlocks.length, equals(1));
        expect(trackingAssetRepo.deletedAssetIds, isEmpty);

        // Confirm reset
        await tester.tap(moreButton);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reset Skin Care Setup'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Reset'));
        await tester.pumpAndSettle();

        expect(
          find.text('Skin Care setup reset successfully.'),
          findsOneWidget,
        );

        currentSetup = await fakeSetupRepo.fetchSetup(uid);
        expect(currentSetup.skinCareBlocks, isEmpty);
        expect(currentSetup.skinCareSkipped, isTrue);
        expect(currentSetup.skinCareProductPhotoAssetId, isNull);
        expect(currentSetup.skinCareFacePhotoAssetId, isNull);
        expect(
          trackingAssetRepo.deletedAssetIds,
          contains('initial-skin-product-asset'),
        );
        expect(
          trackingAssetRepo.deletedAssetIds,
          contains('initial-skin-face-asset'),
        );
      },
    );

    testWidgets(
      'Candidate asset lifecycle: failed product photo analysis retires candidate asset and preserves existing routine',
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
          assetId: 'cand-failed-skin-product',
          ownerUid: uid,
          sourceFeature: 'routine_base_timeline',
          purpose: UploadedAssetPurpose.skinProducts,
          fileName: 'products.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 2048,
          r2Key:
              'users/$uid/routine_base_timeline/cand-failed-skin-product.jpg',
          status: UploadedAssetStatus.uploaded,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final directUploadController = _DirectUploadController(
          assetRepository: trackingAssetRepo,
          assetToReturn: candidateAsset,
        );

        final now = DateTime.now();
        final setup = BaseTimelineSetup(
          uid: uid,
          updatedAt: now,
          skinCareBlocks: const [
            TimelineBlockDraft(
              id: 'existing-skin-block',
              section: 'skinCare',
              title: 'Existing Night Skin',
              startMinute: 21 * 60,
              endMinute: 21 * 60 + 15,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.softBlockKey,
              skincareSlotLabel: 'night',
              skincareSteps: ['Cleanse'],
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
                      email: 'skincare@optivus.local',
                      displayName: 'Skin Care Test User',
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
                (ref) => directUploadController,
              ),
              authRepositoryProvider.overrideWithValue(stubAuth),
              skinCareDomainEngineProvider.overrideWithValue(
                _FakeSkinCareDomainEngine(
                  client: const _FakeSkinCareAiClient(
                    productAnalysisToReturn: SkinCareAiProductResult(
                      products: [],
                      warnings: [
                        'No products detected in photo. Please type your products.',
                      ],
                    ),
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: SkinCareBaseSetupScreen(onBack: () {}),
            ),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('Change setup'));
        await tester.pumpAndSettle();

        // Tap Camera button -> Gallery
        await tester.tap(find.byIcon(Icons.camera_alt_outlined));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose from gallery'));
        await tester.pumpAndSettle();

        // Dialog to type products appears because photo had no products
        expect(find.text('Your Skin Care Products'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Existing block preserved
        expect(find.text('Existing Night Skin'), findsOneWidget);

        // Candidate asset was retired
        expect(
          trackingAssetRepo.deletedAssetIds,
          contains('cand-failed-skin-product'),
        );
      },
    );

    testWidgets(
      'Candidate asset lifecycle: cancelled face photo upload in Build For Me retires candidate face upload',
      (tester) async {
        final trackingAssetRepo = _TrackingAssetRepo();
        final trackingR2 = _TrackingR2Client();
        final stubAuth = _StubAuthRepo();
        final lifecycleHelper = BaseTimelineUploadLifecycleHelper(
          assetRepository: trackingAssetRepo,
          r2UploadClient: trackingR2,
          authRepository: stubAuth,
        );

        final candidateFaceAsset = UploadedAsset(
          assetId: 'cand-face-skin-asset',
          ownerUid: uid,
          sourceFeature: 'routine_base_timeline',
          purpose: UploadedAssetPurpose.skinFace,
          fileName: 'face.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 4096,
          r2Key: 'users/$uid/routine_base_timeline/cand-face-skin-asset.jpg',
          status: UploadedAssetStatus.uploaded,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final directUploadController = _DirectUploadController(
          assetRepository: trackingAssetRepo,
          assetToReturn: candidateFaceAsset,
        );

        final now = DateTime.now();
        final setup = BaseTimelineSetup(
          uid: uid,
          updatedAt: now,
          skinCareBlocks: const [],
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
                      email: 'skincare@optivus.local',
                      displayName: 'Skin Care Test User',
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
                (ref) => directUploadController,
              ),
              authRepositoryProvider.overrideWithValue(stubAuth),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: SkinCareBaseSetupScreen(onBack: () {}),
            ),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('Set up Skin Care'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Build For Me'));
        await tester.pumpAndSettle();

        expect(find.text('Personalized Skin Care'), findsOneWidget);

        // Tap Gallery to upload face photo
        await tester.tap(find.text('Gallery'));
        await tester.pumpAndSettle();

        // Cancel the sheet with close button
        await tester.tap(find.byIcon(Icons.close_rounded).last);
        await tester.pumpAndSettle();

        // Candidate face asset was retired on sheet cancel
        expect(
          trackingAssetRepo.deletedAssetIds,
          contains('cand-face-skin-asset'),
        );
      },
    );

    testWidgets(
      'Build For Me flow collects Step 7 inputs, generates routine, and persists recommendations & notes',
      (tester) async {
        final now = DateTime.now();
        final setup = BaseTimelineSetup(
          uid: uid,
          updatedAt: now,
          skinCareBlocks: const [],
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
        final stubAuth = _StubAuthRepo();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userProfileProvider.overrideWith(
                (ref) => UserProfileNotifier()
                  ..loadSeedData(
                    UserProfile(
                      uid: uid,
                      email: 'skincare@optivus.local',
                      displayName: 'Skin Care Test User',
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
              authRepositoryProvider.overrideWithValue(stubAuth),
              skinCareDomainEngineProvider.overrideWithValue(
                _FakeSkinCareDomainEngine(),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: SkinCareBaseSetupScreen(onBack: () {}),
            ),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('Set up Skin Care'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Build For Me'));
        await tester.pumpAndSettle();

        expect(find.text('Personalized Skin Care'), findsOneWidget);
        expect(find.text('Skin Type'), findsOneWidget);
        expect(find.text('Concerns'), findsOneWidget);
        expect(find.text('Budget'), findsWidgets);
        expect(find.text('Routine Style'), findsOneWidget);

        // Select Oily
        await tester.tap(find.widgetWithText(ChoiceChip, 'Oily'));
        await tester.pumpAndSettle();

        // Select Acne
        await tester.tap(find.widgetWithText(FilterChip, 'Acne'));
        await tester.pumpAndSettle();

        // Select Budget
        await tester.tap(find.widgetWithText(ChoiceChip, 'Budget'));
        await tester.pumpAndSettle();

        // Select Simple
        await tester.tap(find.widgetWithText(ChoiceChip, 'Simple'));
        await tester.pumpAndSettle();

        // Tap Build Routine
        final buildBtn = find.text('Build Routine');
        await tester.scrollUntilVisible(buildBtn, 200);
        await tester.tap(buildBtn);
        await tester.pumpAndSettle();

        // Generated blocks appear in review
        expect(find.text('Morning Skincare'), findsWidgets);
        expect(find.text('Night Skincare'), findsWidgets);

        // Save
        await tester.tap(find.text('Apply changes'));
        await tester.pumpAndSettle();

        // Verify persisted setup in repository
        final updatedSetup = await fakeSetupRepo.fetchSetup(uid);
        expect(updatedSetup.skinCareSetupPath, equals('build_for_me'));
        expect(updatedSetup.skinCareSkinType, equals('oily'));
        expect(updatedSetup.skinCareProblems, contains('pimples'));
        expect(updatedSetup.skinCareBudget, equals('low'));
        expect(updatedSetup.skinCarePreference, equals('simple'));
        expect(updatedSetup.skinCareProductRecommendations, isNotEmpty);
        expect(
          updatedSetup.skinCareProductRecommendations.first.name,
          equals('Gentle Hydrating Cleanser'),
        );
        expect(
          updatedSetup.skinCareSelectedProductNames,
          contains('Gentle Hydrating Cleanser'),
        );
        expect(updatedSetup.skinCareSpecialCareNotes, isNotEmpty);
        expect(updatedSetup.skinCareBlocks.length, equals(2));
      },
    );
  });
}
