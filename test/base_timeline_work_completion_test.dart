import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/work_current_setup_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/work_review_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/work_source_selection_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/work_base_setup_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_upload_lifecycle_helper.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_current_setup_header.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/work_detail_sheet.dart';
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

    testWidgets(
      'WorkBaseSetupScreen source selection and photo scan workflow retires candidate upload if user cancels',
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

        final setup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          workBlocks: const [],
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
              home: WorkBaseSetupScreen(onBack: () {}),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Initial screen: Tap "Set up Work" to enter Source Selection
        expect(find.text('Set up Work'), findsWidgets);
        await tester.tap(find.text('Set up Work').first);
        await tester.pumpAndSettle();

        expect(find.byType(WorkSourceSelectionView), findsOneWidget);
        expect(find.text('Update Work Schedule'), findsOneWidget);

        // 2. Choose from Gallery
        await tester.tap(find.text('Choose from Gallery'));
        await tester.pumpAndSettle();

        // 3. Reaches WorkReviewView with 1 block scheduled
        expect(find.byType(WorkReviewView), findsOneWidget);
        expect(find.text('1 blocks scheduled'), findsOneWidget);
        expect(find.text('Store Shift'), findsOneWidget);

        // 4. Cancel via close icon
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        // Discard dialog is shown because edits are dirty
        expect(find.text('Discard this setup?'), findsOneWidget);
        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();

        // Returns to WorkCurrentSetupView
        expect(find.byType(WorkCurrentSetupView), findsOneWidget);

        // Candidate upload was retired!
        expect(
          trackingAssetRepo.deletedAssetIds,
          contains('cand-work-upload-1'),
        );
      },
    );

    testWidgets(
      'WorkBaseSetupScreen AI extraction failure preserves working state and retires candidate asset',
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

        const existingBlock = TimelineBlockDraft(
          id: 'existing-work-shift',
          section: 'work',
          title: 'Morning Shift',
          startMinute: 8 * 60,
          endMinute: 12 * 60,
          repeatDays: [1, 2, 3, 4, 5],
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        final setup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          workBlocks: const [existingBlock],
          workLogicalAssetId: 'initial-work-asset-id',
          workLogicalAssetR2Key: 'users/$uid/work/initial.jpg',
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
              home: WorkBaseSetupScreen(onBack: () {}),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Morning Shift'), findsOneWidget);

        // Tap Change setup -> Source Selection
        await tester.tap(find.text('Change setup'));
        await tester.pumpAndSettle();

        // Tap Choose from Gallery
        await tester.tap(find.text('Choose from Gallery'));
        await tester.pumpAndSettle();

        // Error message is displayed in error stage
        expect(find.text('Work Schedule Processing Issue'), findsOneWidget);
        expect(
          find.text('Image was too blurry to read work shifts.'),
          findsOneWidget,
        );

        // Candidate asset was retired!
        expect(
          trackingAssetRepo.deletedAssetIds,
          contains('cand-failed-work-upload'),
        );

        // Tap "Keep previous draft" to recover working blocks
        expect(find.text('Keep previous draft'), findsOneWidget);
        await tester.tap(find.text('Keep previous draft'));
        await tester.pumpAndSettle();

        // Reaches review view with existing block intact!
        expect(find.byType(WorkReviewView), findsOneWidget);
        expect(find.text('Morning Shift'), findsOneWidget);
      },
    );

    testWidgets(
      'WorkDetailSheet opens when tapping a work card in current setup',
      (tester) async {
        const block = TimelineBlockDraft(
          id: 'work-detail-1',
          section: 'work',
          title: 'Project Deep Work',
          startMinute: 13 * 60,
          endMinute: 17 * 60,
          repeatDays: [1, 2, 3],
          location: 'HQ Floor 4',
          sectionLabel: 'Sprint 88',
          notes: 'Bring sprint checklist',
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        final setup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          workBlocks: const [block],
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

        // Find the card and tap it
        expect(find.text('Project Deep Work'), findsOneWidget);
        await tester.tap(find.text('Project Deep Work'));
        await tester.pumpAndSettle();

        // WorkDetailSheet is displayed
        expect(find.byType(WorkDetailSheet), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(WorkDetailSheet),
            matching: find.text('HQ Floor 4'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(WorkDetailSheet),
            matching: find.text('Sprint 88'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(WorkDetailSheet),
            matching: find.text('Bring sprint checklist'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('WorkReviewView disables save when working blocks are empty', (
      tester,
    ) async {
      final setup = BaseTimelineSetup(
        uid: uid,
        updatedAt: DateTime.now(),
        workBlocks: const [],
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
            routineTransactionRepositoryProvider.overrideWithValue(fakeTxRepo),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: WorkBaseSetupScreen(onBack: () {}),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter manual setup
      await tester.tap(find.text('Set up Work').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set up manually'));
      await tester.pumpAndSettle();

      expect(find.byType(WorkReviewView), findsOneWidget);
      expect(find.text('No work blocks scheduled'), findsOneWidget);

      // Verify "Use this work schedule" button is disabled
      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Use this work schedule'),
      );
      expect(saveButton.onPressed, isNull);
    });

    testWidgets(
      'Manual block addition via edit sheet enables save and updates setup',
      (tester) async {
        final setup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          workBlocks: const [],
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

        // 1. Enter manual setup
        await tester.tap(find.text('Set up Work').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Set up manually'));
        await tester.pumpAndSettle();

        expect(find.byType(WorkReviewView), findsOneWidget);

        // 2. Tap Add Work
        await tester.tap(find.text('Add Work'));
        await tester.pumpAndSettle();

        // Edit sheet is shown
        expect(find.text('Add Work Block'), findsOneWidget);

        // Enter title
        final titleField = find.byKey(const ValueKey('base-work-title-field'));
        await tester.enterText(titleField, 'Focus Time');
        await tester.pumpAndSettle();

        // Tap Save in edit sheet
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // 3. Back in ReviewView with 1 block scheduled
        expect(find.byType(WorkReviewView), findsOneWidget);
        expect(find.text('Focus Time'), findsOneWidget);
        expect(find.text('1 blocks scheduled'), findsOneWidget);

        // Save button is now enabled
        final saveButton = find.widgetWithText(
          FilledButton,
          'Use this work schedule',
        );
        expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);

        // 4. Tap Use this work schedule to save
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Save success view completes and navigates to currentSetup
        expect(find.byType(WorkCurrentSetupView), findsOneWidget);
        expect(find.text('Focus Time'), findsOneWidget);

        // Verify persisted in repo
        final updatedSetup = await fakeSetupRepo.fetchSetup(uid);
        expect(updatedSetup.workBlocks.length, equals(1));
        expect(updatedSetup.workBlocks.first.title, equals('Focus Time'));
      },
    );

    testWidgets(
      'In-sheet Remove button confirms and deletes work block from draft',
      (tester) async {
        const block = TimelineBlockDraft(
          id: 'work-delete-test-1',
          section: 'work',
          title: 'Morning Operations',
          startMinute: 9 * 60,
          endMinute: 11 * 60,
          repeatDays: [1, 2, 3, 4, 5],
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        final setup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          workBlocks: const [block],
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

        // Enter Source Selection
        await tester.tap(find.text('Change setup'));
        await tester.pumpAndSettle();

        // Tap Edit current work schedule
        await tester.tap(find.text('Set up manually'));
        await tester.pumpAndSettle();

        expect(find.byType(WorkReviewView), findsOneWidget);
        expect(find.text('Morning Operations'), findsOneWidget);

        // Tap the block to edit
        await tester.tap(find.text('Morning Operations'));
        await tester.pumpAndSettle();

        expect(find.text('Edit Work Block'), findsOneWidget);

        // Scroll to the remove button in the sheet
        final removeButton = find.text('Remove work block');
        await tester.scrollUntilVisible(
          removeButton,
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();

        await tester.tap(removeButton);
        await tester.pumpAndSettle();

        // Confirmation dialog
        expect(find.text('Remove this work block?'), findsOneWidget);
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        // Block is now deleted from working blocks!
        expect(find.text('No work blocks scheduled'), findsOneWidget);
        expect(find.text('0 blocks scheduled'), findsOneWidget);
      },
    );
  });
}
