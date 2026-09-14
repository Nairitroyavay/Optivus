import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/schedule_setup_flow.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/work_base_setup_screen.dart';
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
  group('Base Timeline Work Completion Tests', () {
    const uid = 'user-work-completion-test';

    testWidgets(
      'Work setup screen displays BaseTimelineCurrentSetupHeader and renders cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final now = DateTime.now();
        final setup = BaseTimelineSetup(
          uid: uid,
          updatedAt: now,
          workBlocks: const [
            TimelineBlockDraft(
              id: 'work-shift-1',
              section: 'work',
              title: 'Office Shift',
              startMinute: 9 * 60,
              endMinute: 17 * 60,
              repeatDays: [1, 2, 3, 4, 5],
              blockType: TimelineBlockDraft.hardBlockKey,
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
                      email: 'work@optivus.local',
                      displayName: 'Work Test User',
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
              home: WorkBaseSetupScreen(onBack: () {}),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(BaseTimelineCurrentSetupHeader), findsOneWidget);
        expect(find.text('Work / Business'), findsWidgets);
        expect(find.text('Change setup'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Remove Work Setup removes blocks, unconfigures section, and retires asset',
      (tester) async {
        final now = DateTime.now();
        final setup = BaseTimelineSetup(
          uid: uid,
          updatedAt: now,
          workLogicalAssetId: 'initial-work-asset-123',
          workLogicalAssetR2Key: 'users/$uid/work/initial.jpg',
          workBlocks: const [
            TimelineBlockDraft(
              id: 'work-shift-1',
              section: 'work',
              title: 'Office Shift',
              startMinute: 9 * 60,
              endMinute: 17 * 60,
              repeatDays: [1, 2, 3, 4, 5],
              blockType: TimelineBlockDraft.hardBlockKey,
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
                      email: 'work@optivus.local',
                      displayName: 'Work Test User',
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
              home: WorkBaseSetupScreen(onBack: () {}),
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

        expect(find.text('Remove Work Setup'), findsOneWidget);
        await tester.tap(find.text('Remove Work Setup'));
        await tester.pumpAndSettle();

        expect(find.text('Remove Work Setup?'), findsOneWidget);
        expect(
          find.text(
            'This will remove all work and business blocks from your Base Timeline. This action cannot be undone.',
          ),
          findsOneWidget,
        );

        // Tap cancel first to verify safety
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        var currentSetup = await fakeSetupRepo.fetchSetup(uid);
        expect(currentSetup.workBlocks.length, equals(1));
        expect(trackingAssetRepo.deletedAssetIds, isEmpty);

        // Open menu again and confirm removal
        await tester.tap(moreButton);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove Work Setup'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        expect(find.text('Work setup removed.'), findsOneWidget);

        currentSetup = await fakeSetupRepo.fetchSetup(uid);
        expect(currentSetup.workBlocks, isEmpty);
        expect(currentSetup.workLogicalAssetId, isNull);
        expect(currentSetup.workLogicalAssetR2Key, isNull);
        expect(
          trackingAssetRepo.deletedAssetIds,
          contains('initial-work-asset-123'),
        );
      },
    );

    testWidgets('ScheduleSetupFlow retires candidate upload if user cancels', (
      tester,
    ) async {
      final trackingAssetRepo = _TrackingAssetRepo();
      final trackingR2 = _TrackingR2Client();
      final stubAuth = _StubAuthRepo();
      final lifecycleHelper = BaseTimelineUploadLifecycleHelper(
        assetRepository: trackingAssetRepo,
        r2UploadClient: trackingR2,
        authRepository: stubAuth,
      );

      final candidateAsset = UploadedAsset(
        assetId: 'cand-work-upload-1',
        ownerUid: uid,
        sourceFeature: 'routine_base_timeline',
        purpose: UploadedAssetPurpose.workSchedule,
        status: UploadedAssetStatus.uploaded,
        fileName: 'schedule.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 1024,
        r2Key: 'users/$uid/work/schedule.jpg',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      var didCancel = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: uid,
                    email: 'work@optivus.local',
                    displayName: 'Work Test User',
                  ),
                ),
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
            routineImportAiControllerProvider.overrideWith(
              (ref) => _CustomResultAiController(
                ref,
                resultToReturn: RoutineImportExtractionResult(
                  id: 'ext-work-1',
                  uid: uid,
                  source: RoutineImportReviewSource.work,
                  createdAt: DateTime.now(),
                  candidates: [
                    RoutineImportCandidateBlock(
                      id: 'extracted-item-1',
                      title: 'Store Shift',
                      startMinute: 10 * 60,
                      endMinute: 18 * 60,
                      repeatDays: const [1, 2, 3, 4, 5],
                      blockType: 'hard',
                      category: 'work',
                      hardBlock: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: ScheduleSetupFlow(
                config: ScheduleSetupConfig.workSetup,
                initialBlocks: const [],
                initialAssetId: null,
                initialR2Key: null,
                onSave: (blocks, assetId, r2Key) async {},
                onCancel: () {
                  didCancel = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Scan Photo -> Gallery
      await tester.tap(find.text('Scan Photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from Gallery'));
      await tester.pumpAndSettle();

      // Extraction succeeded and shows 1 block scheduled
      expect(find.text('1 blocks scheduled'), findsOneWidget);

      // Now cancel via close icon
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Discard dialog is shown because edits are dirty
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(didCancel, isTrue);
      // Candidate upload was retired!
      expect(trackingAssetRepo.deletedAssetIds, contains('cand-work-upload-1'));
    });

    testWidgets(
      'ScheduleSetupFlow extraction failure preserves working state and retires candidate asset',
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
          assetId: 'cand-failed-work-upload',
          ownerUid: uid,
          sourceFeature: 'routine_base_timeline',
          purpose: UploadedAssetPurpose.workSchedule,
          status: UploadedAssetStatus.uploaded,
          fileName: 'unreadable.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 1024,
          r2Key: 'users/$uid/work/unreadable.jpg',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final existingBlock = const TimelineBlockDraft(
          id: 'existing-work-shift',
          section: 'work',
          title: 'Morning Shift',
          startMinute: 8 * 60,
          endMinute: 12 * 60,
          repeatDays: [1, 2, 3, 4, 5],
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userProfileProvider.overrideWith(
                (ref) => UserProfileNotifier()
                  ..loadSeedData(
                    UserProfile(
                      uid: uid,
                      email: 'work@optivus.local',
                      displayName: 'Work Test User',
                    ),
                  ),
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
              // Returns 0 candidates
              routineImportAiControllerProvider.overrideWith(
                (ref) => _CustomResultAiController(
                  ref,
                  resultToReturn: RoutineImportExtractionResult(
                    id: 'ext-fail-work',
                    uid: uid,
                    source: RoutineImportReviewSource.work,
                    createdAt: DateTime.now(),
                    candidates: const [],
                    warnings: const [
                      'Image was too blurry to read work shifts.',
                    ],
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: Scaffold(
                body: ScheduleSetupFlow(
                  config: ScheduleSetupConfig.workSetup,
                  initialBlocks: [existingBlock],
                  initialAssetId: 'initial-work-asset-id',
                  initialR2Key: 'users/$uid/work/initial.jpg',
                  onSave: (blocks, assetId, r2Key) async {},
                  onCancel: () {},
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Morning Shift'), findsOneWidget);
        expect(find.text('1 blocks scheduled'), findsOneWidget);

        // Tap Scan Photo -> Gallery
        await tester.tap(find.text('Scan Photo'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose from Gallery'));
        await tester.pumpAndSettle();

        // Error message is displayed
        expect(
          find.text('Image was too blurry to read work shifts.'),
          findsOneWidget,
        );

        // Existing block is preserved!
        expect(find.text('Morning Shift'), findsOneWidget);

        // Candidate asset was retired!
        expect(
          trackingAssetRepo.deletedAssetIds,
          contains('cand-failed-work-upload'),
        );
      },
    );
  });
}
