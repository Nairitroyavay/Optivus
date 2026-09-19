import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_theme.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_entry.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/work_presentation_utils.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/work_current_setup_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/work_review_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/work_source_selection_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/work_base_setup_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_upload_lifecycle_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/work_setup_controller.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/work_setup_error_mapper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/work_timeline_adapter.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_current_setup_header.dart';

import 'package:optivus/features/routine/managers/base_timeline/widgets/work_detail_sheet.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/work_setup_profile_summary_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/work_timeline_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step4_candidate_mapping.dart';
import 'package:optivus/repositories/routine_firestore_codec.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';
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

class _FailingRemoveTxRepo extends FakeRoutineTransactionRepository {
  final Object errorToThrow;

  _FailingRemoveTxRepo({
    super.routineRepository,
    super.setupRepository,
    this.errorToThrow = const FormatException('Simulated repository failure'),
  });

  @override
  Future<BaseTimelineSectionCommitResult> replaceBaseTimelineSection({
    required String uid,
    required BaseTimelineSection section,
    required int expectedRevision,
    required List<RoutineItem> newRoutineItems,
    List<String> additionalDeleteIds = const [],
    required BaseTimelineSetup Function(BaseTimelineSetup liveSetup)
    buildUpdatedSetup,
  }) async {
    throw errorToThrow;
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
        expect(find.text('Edit schedule'), findsOneWidget);
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
                      lifeRole: LifeRoleDraft.workingKey,
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
                      lifeRole: LifeRoleDraft.workingKey,
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

        expect(find.byType(WorkSourceSelectionView), findsOneWidget);
        expect(find.text('Set up Work Schedule'), findsOneWidget);

        // 2. Choose from Gallery
        await tester.tap(find.text('Choose from gallery'));
        await tester.pumpAndSettle();

        // 3. Reaches WorkReviewView with 1 block scheduled
        expect(find.byType(WorkReviewView), findsOneWidget);
        expect(find.text('1 work block scheduled'), findsOneWidget);
        expect(find.text('Store Shift'), findsOneWidget);

        // 4. Cancel via close icon
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        // Discard dialog is shown because edits are dirty
        expect(find.text('Discard this setup?'), findsOneWidget);
        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();

        // Returns to WorkCurrentSetupView
        expect(find.byType(WorkSourceSelectionView), findsOneWidget);

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

        // Open overflow menu
        await tester.tap(find.byIcon(Icons.more_vert_rounded));
        await tester.pumpAndSettle();
        // Tap Change source -> Source Selection
        await tester.tap(find.text('Change source'));
        await tester.pumpAndSettle();

        // Tap Choose from Gallery
        await tester.tap(find.text('Choose from gallery'));
        await tester.pumpAndSettle();

        // Error message is displayed in error stage
        expect(find.text('Schedule Analysis Issue'), findsOneWidget);
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
      'Front card in current setup shows all details inline and opens WorkDetailSheet on tap',
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

        // Details are displayed directly on the front card inline
        expect(find.text('Project Deep Work'), findsOneWidget);
        expect(find.text('HQ Floor 4'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(WorkTimelineCard),
            matching: find.text('Sprint 88'),
          ),
          findsOneWidget,
        );
        expect(find.text('Bring sprint checklist'), findsOneWidget);

        // Tapping opens WorkDetailSheet
        await tester.tap(find.text('Project Deep Work'));
        await tester.pumpAndSettle();
        expect(find.byType(WorkDetailSheet), findsOneWidget);
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
                    lifeRole: LifeRoleDraft.workingKey,
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
                      lifeRole: LifeRoleDraft.workingKey,
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

        await tester.tap(find.text('Set up manually'));
        await tester.pumpAndSettle();

        expect(find.byType(WorkReviewView), findsOneWidget);

        // 2. Tap Add work block
        await tester.tap(find.text('Add work block'));
        await tester.pumpAndSettle();

        // Edit sheet is shown (both the background review action button and the sheet title match)
        expect(find.text('Add work block'), findsNWidgets(2));

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
        expect(find.text('1 work block scheduled'), findsOneWidget);

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
                      lifeRole: LifeRoleDraft.workingKey,
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

        // Tap Edit schedule directly opens WorkReviewView
        await tester.tap(find.text('Edit schedule'));
        await tester.pumpAndSettle();

        expect(find.byType(WorkReviewView), findsOneWidget);
        expect(find.text('Morning Operations'), findsOneWidget);

        // Tap the block to edit
        await tester.tap(find.text('Morning Operations'));
        await tester.pumpAndSettle();

        expect(find.text('Edit work block'), findsOneWidget);

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
        expect(find.text('0 work blocks scheduled'), findsOneWidget);
      },
    );

    testWidgets(
      'Overlapping work cards expose back card with bring-to-front action and semantics',
      (tester) async {
        const blockA = TimelineBlockDraft(
          id: 'work-overlap-a',
          section: 'work',
          title: 'Planning Session',
          startMinute: 9 * 60,
          endMinute: 12 * 60,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.hardBlockKey,
        );
        const blockB = TimelineBlockDraft(
          id: 'work-overlap-b',
          section: 'work',
          title: 'Technical Sync',
          startMinute: 10 * 60,
          endMinute: 13 * 60,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        final setup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          workBlocks: const [blockA, blockB],
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

        // Both cards should be rendered
        expect(find.byType(WorkTimelineCard), findsNWidgets(2));

        // Find the back card semantics which has 'Tap to bring to front.'
        final backCardSemantics = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.button == true &&
              (w.properties.label?.contains('Tap to bring to front.') ?? false),
        );
        expect(backCardSemantics, findsOneWidget);

        // Find the front card semantics which has button: false
        final frontCardSemantics = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.button == false &&
              !(w.properties.label?.contains('Tap to bring to front.') ?? true),
        );
        expect(frontCardSemantics, findsOneWidget);

        // Tap the back card to bring it to front
        await tester.tap(backCardSemantics, warnIfMissed: false);
        await tester.pumpAndSettle();

        // Both semantics are still present (the swapped card is now back)
        expect(backCardSemantics, findsOneWidget);
        expect(frontCardSemantics, findsOneWidget);
      },
    );

    testWidgets(
      'Remove Work Setup failure presents error SnackBar and preserves existing setup',
      (tester) async {
        const block = TimelineBlockDraft(
          id: 'work-remove-fail-1',
          section: 'work',
          title: 'Mission Critical Operations',
          startMinute: 9 * 60,
          endMinute: 17 * 60,
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
        final failingTxRepo = _FailingRemoveTxRepo(
          routineRepository: fakeRoutineRepo,
          setupRepository: fakeSetupRepo,
          errorToThrow: const FormatException('Network failure during removal'),
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
                      lifeRole: LifeRoleDraft.workingKey,
                    ),
                  ),
              ),
              baseTimelineSetupRepositoryProvider.overrideWithValue(
                fakeSetupRepo,
              ),
              routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
              routineTransactionRepositoryProvider.overrideWithValue(
                failingTxRepo,
              ),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: WorkBaseSetupScreen(onBack: () {}),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap menu and select Remove Work Setup
        await tester.tap(
          find.byKey(const Key('base-timeline-header-menu-button')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Remove Work Setup'));
        await tester.pumpAndSettle();

        // Confirm dialog
        expect(find.text('Remove Work Setup?'), findsOneWidget);
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        // Error SnackBar is shown with the failure message
        expect(
          find.textContaining('Failed to remove work setup'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Your current setup is still active'),
          findsOneWidget,
        );

        // Success SnackBar is NOT shown
        expect(find.text('Work setup removed successfully.'), findsNothing);
        expect(
          find.text('Work setup removed, refreshing live state...'),
          findsNothing,
        );

        // Setup in repo was NOT deleted
        final remainingSetup = await fakeSetupRepo.fetchSetup(uid);
        expect(remainingSetup.workBlocks, isNotEmpty);
      },
    );

    test(
      'reloadFromCanonical cleans uncommitted working assets without deleting canonical assets',
      () async {
        final setup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          workLogicalAssetId: 'canonical-work-asset-111',
          workLogicalAssetR2Key: 'users/$uid/work/canonical.jpg',
          workBlocks: const [
            TimelineBlockDraft(
              id: 'work-block-1',
              section: 'work',
              title: 'Canonical Job',
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

        final container = ProviderContainer(
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
            baseTimelineUploadLifecycleHelperProvider.overrideWithValue(
              lifecycleHelper,
            ),
            uploadedAssetRepositoryProvider.overrideWithValue(
              trackingAssetRepo,
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(workSetupControllerProvider.notifier);

        // Simulate an uncommitted working asset set via draft update
        controller.setWorkingAssetsForTesting(
          workingAssetId: 'uncommitted-working-asset-999',
          workingR2Key: 'users/$uid/work/uncommitted-working.jpg',
        );

        // Now reload from canonical
        controller.reloadFromCanonical(setup);
        await pumpEventQueue(times: 20);

        // The uncommitted working assets were retired
        expect(
          trackingAssetRepo.deletedAssetIds,
          contains('uncommitted-working-asset-999'),
        );
        expect(
          trackingR2.deletedKeys,
          contains('users/$uid/work/uncommitted-working.jpg'),
        );

        // Canonical assets were NOT deleted
        expect(
          trackingAssetRepo.deletedAssetIds,
          isNot(contains('canonical-work-asset-111')),
        );
        expect(
          trackingR2.deletedKeys,
          isNot(contains('users/$uid/work/canonical.jpg')),
        );
      },
    );

    testWidgets(
      'WorkSourceSelectionView displays correct contextual copy for photo, manual configured, and unconfigured setups',
      (tester) async {
        // 1. Configured with photo
        final photoSetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          workLogicalAssetR2Key: 'users/$uid/work/schedule.jpg',
          workBlocks: const [
            TimelineBlockDraft(
              id: 'b1',
              section: 'work',
              title: 'Photo Shift',
              startMinute: 9 * 60,
              endMinute: 17 * 60,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );

        final trackingAssetRepo = _TrackingAssetRepo();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              uploadedAssetRepositoryProvider.overrideWithValue(
                trackingAssetRepo,
              ),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: Scaffold(
                body: WorkSourceSelectionView(
                  setup: photoSetup,
                  lifeRole: LifeRoleDraft.workingKey,
                  onCancel: () {},
                  onPickPhoto: (_) {},
                  onManualSetup: () {},
                  onEditCurrent: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Edit current work schedule'), findsOneWidget);
        expect(
          find.text('Keep schedule photo and adjust blocks'),
          findsOneWidget,
        );

        // 2. Configured manual (no photo)
        final manualSetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          workBlocks: const [
            TimelineBlockDraft(
              id: 'b2',
              section: 'work',
              title: 'Manual Shift',
              startMinute: 9 * 60,
              endMinute: 17 * 60,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              uploadedAssetRepositoryProvider.overrideWithValue(
                trackingAssetRepo,
              ),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: Scaffold(
                body: WorkSourceSelectionView(
                  setup: manualSetup,
                  lifeRole: LifeRoleDraft.workingKey,
                  onCancel: () {},
                  onPickPhoto: (_) {},
                  onManualSetup: () {},
                  onEditCurrent: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Edit current work schedule'), findsOneWidget);
        expect(
          find.text('Keep your current blocks and adjust them manually'),
          findsOneWidget,
        );

        // 3. Unconfigured
        final unconfiguredSetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          workBlocks: const [],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              uploadedAssetRepositoryProvider.overrideWithValue(
                trackingAssetRepo,
              ),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: Scaffold(
                body: WorkSourceSelectionView(
                  setup: unconfiguredSetup,
                  lifeRole: LifeRoleDraft.workingKey,
                  onCancel: () {},
                  onPickPhoto: (_) {},
                  onManualSetup: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Set up manually'), findsOneWidget);
        expect(find.text('Add your work blocks day by day'), findsOneWidget);
      },
    );

    testWidgets(
      'WorkReviewView displays photo preview and "Change photo" when workingAssetId exists, or "Add photo" when none',
      (tester) async {
        final trackingAssetRepo = _TrackingAssetRepo();

        // 1. With workingAssetId
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              uploadedAssetRepositoryProvider.overrideWithValue(
                trackingAssetRepo,
              ),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: Scaffold(
                body: WorkReviewView(
                  workingBlocks: const [
                    TimelineBlockDraft(
                      id: 'rev-1',
                      section: 'work',
                      title: 'Office',
                      startMinute: 9 * 60,
                      endMinute: 17 * 60,
                      repeatDays: [1],
                      blockType: TimelineBlockDraft.hardBlockKey,
                    ),
                  ],
                  workingAssetId: 'working-asset-abc-123',
                  workingR2Key: null,
                  workingLocalPreviewPath: null,
                  selectedDay: 1,
                  onDayChanged: (_) {},
                  droppedCount: 0,
                  droppedExamples: const [],
                  errorMessage: null,
                  onClearError: () {},
                  isSaving: false,
                  onCancel: () {},
                  onScanAgain: () {},
                  onAddBlock: () {},
                  onEditBlock: (_) {},
                  onSave: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Change photo'), findsOneWidget);
        expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);

        // 2. Without any working source
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              uploadedAssetRepositoryProvider.overrideWithValue(
                trackingAssetRepo,
              ),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: Scaffold(
                body: WorkReviewView(
                  workingBlocks: const [
                    TimelineBlockDraft(
                      id: 'rev-2',
                      section: 'work',
                      title: 'Office',
                      startMinute: 9 * 60,
                      endMinute: 17 * 60,
                      repeatDays: [1],
                      blockType: TimelineBlockDraft.hardBlockKey,
                    ),
                  ],
                  workingAssetId: null,
                  workingR2Key: null,
                  workingLocalPreviewPath: null,
                  selectedDay: 1,
                  onDayChanged: (_) {},
                  droppedCount: 0,
                  droppedExamples: const [],
                  errorMessage: null,
                  onClearError: () {},
                  isSaving: false,
                  onCancel: () {},
                  onScanAgain: () {},
                  onAddBlock: () {},
                  onEditBlock: (_) {},
                  onSave: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Add photo'), findsOneWidget);
        expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'Work edit sheet guards last repeat day from being deselected and validates end time > start time',
      (tester) async {
        const block = TimelineBlockDraft(
          id: 'test-edit-guard',
          section: 'work',
          title: 'Engineering Sprint',
          startMinute: 10 * 60,
          endMinute: 12 * 60,
          repeatDays: [1], // Only Monday
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      BaseTimelineWorkAdapter.showEditSheet(
                        context: context,
                        block: block,
                        onSave: (_) async => true,
                        lifeRole: LifeRoleDraft.workingKey,
                      );
                    },
                    child: const Text('Open Edit Sheet'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Edit Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Edit work block'), findsOneWidget);

        // Find Monday chip (Mon)
        final mondayChip = find.widgetWithText(FilterChip, 'Mon');
        expect(mondayChip, findsOneWidget);
        expect(tester.widget<FilterChip>(mondayChip).selected, isTrue);

        // Tap Monday to attempt deselecting it
        await tester.tap(mondayChip);
        await tester.pumpAndSettle();

        // Monday must still be selected because days.length == 1
        expect(tester.widget<FilterChip>(mondayChip).selected, isTrue);

        // Now select Tuesday (Tue)
        final tuesdayChip = find.widgetWithText(FilterChip, 'Tue');
        await tester.tap(tuesdayChip);
        await tester.pumpAndSettle();

        // Now both Monday and Tuesday are selected
        expect(tester.widget<FilterChip>(mondayChip).selected, isTrue);
        expect(tester.widget<FilterChip>(tuesdayChip).selected, isTrue);

        // Now deselect Tuesday (since days.length == 2, it succeeds)
        await tester.tap(tuesdayChip);
        await tester.pumpAndSettle();

        expect(tester.widget<FilterChip>(tuesdayChip).selected, isFalse);
        expect(tester.widget<FilterChip>(mondayChip).selected, isTrue);

        // Attempt deselecting Monday again - guarded!
        await tester.tap(mondayChip);
        await tester.pumpAndSettle();
        expect(tester.widget<FilterChip>(mondayChip).selected, isTrue);

        // Verify valid range has no error
        expect(find.text('End time must be after start time.'), findsNothing);

        // Close sheet
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Open edit sheet with invalid time range (start >= end)
        const invalidBlock = TimelineBlockDraft(
          id: 'test-invalid-time',
          section: 'work',
          title: 'Invalid Time Shift',
          startMinute: 14 * 60,
          endMinute: 12 * 60,
          repeatDays: [1],
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      BaseTimelineWorkAdapter.showEditSheet(
                        context: context,
                        block: invalidBlock,
                        onSave: (_) async => true,
                      );
                    },
                    child: const Text('Open Invalid Edit Sheet'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Invalid Edit Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('End time must be after start time.'), findsOneWidget);
      },
    );

    testWidgets(
      'WorkTimelineCard minimumHeight dynamically calculates expanded height and wraps all fields without overflow',
      (tester) async {
        const block = TimelineBlockDraft(
          id: 'multiline-work-card',
          section: 'work',
          title:
              'Executive Architecture Review & Global Infrastructure Operations Summit',
          location: 'Building B, Floor 14, East Conference Room Alpha',
          sectionLabel: 'Infrastructure Core Team 2026',
          notes:
              'Present cross-region failover benchmarks, disaster recovery SLAs, and multi-tenant security guarantees',
          startMinute: 9 * 60,
          endMinute: 12 * 60,
          repeatDays: [1],
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(800, 1200);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final dynamicHeight = WorkTimelineCard.minimumHeight(
          block,
          contentWidth: 220,
          textScale: 1.4,
        );

        // Must dynamically exceed the default minimum height of 96.0
        expect(dynamicHeight, greaterThan(150.0));

        const entry = TimelineEntry(
          id: 'entry-multiline',
          sourceId: 'multiline-work-card',
          title:
              'Executive Architecture Review & Global Infrastructure Operations Summit',
          subtitle: 'Building B, Floor 14, East Conference Room Alpha',
          startMinute: 9 * 60,
          endMinute: 12 * 60,
          repeatDays: [1],
          category: TimelineCategory.work,
        );

        final positioned = PositionedTimelineEntry(
          entry: entry,
          left: 0,
          top: 0,
          width: 220,
          height: dynamicHeight,
          column: 0,
          columnCount: 1,
          isFront: true,
          hasOverlap: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: SizedBox(
                    width: 220,
                    height: dynamicHeight,
                    child: WorkTimelineCard(
                      positioned: positioned,
                      block: block,
                      isEditable: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final exception = tester.takeException();
        expect(exception, isNull);

        // All fields are fully rendered
        expect(
          find.text(
            'Executive Architecture Review & Global Infrastructure Operations Summit',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Building B, Floor 14, East Conference Room Alpha'),
          findsOneWidget,
        );
        expect(find.text('Infrastructure Core Team 2026'), findsOneWidget);
        expect(
          find.text(
            'Present cross-region failover benchmarks, disaster recovery SLAs, and multi-tenant security guarantees',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'WorkCurrentSetupView and WorkReviewView render 5-minute short blocks at 320dp width without RenderFlex overflow at text scales 1.4 and 2.0',
      (tester) async {
        final shortBlock = TimelineBlockDraft(
          id: 'short-block-1',
          section: 'work',
          title: 'Emergency Executive Sync & Architecture Review',
          location: 'Floor 12 Executive Briefing Center Alpha',
          sectionLabel: 'Infrastructure Core Engineering Operations',
          notes:
              'Review critical multi-tenant failover latency metrics and P0 disaster recovery protocol before APAC deployment',
          startMinute: 9 * 60,
          endMinute: 9 * 60 + 5,
          repeatDays: const [1],
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        final setup = BaseTimelineSetup(
          uid: 'user-1',
          updatedAt: DateTime.now(),
          workBlocks: [shortBlock],
          revision: 1,
        );

        for (final scale in [1.4, 2.0]) {
          tester.view.physicalSize = const Size(320 * 3, 640 * 3);
          tester.view.devicePixelRatio = 3.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          // Test Current Setup View at 320dp
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(320, 640),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: WorkCurrentSetupView(
                    setup: setup,
                    routineBlocks: [shortBlock],
                    selectedDay: 1,
                    onDayChanged: (_) {},
                    onBack: () {},
                    onChangeSetup: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final err = tester.takeException();
          if (err != null) {
            debugPrint('ERROR ON SCALE $scale: $err');
            if (err is FlutterError) {
              for (final d in err.diagnostics) {
                debugPrint('DIAG: ${d.name} -> ${d.toString()}');
              }
            }
          }
          expect(err, isNull);
          expect(
            find.text('Emergency Executive Sync & Architecture Review'),
            findsOneWidget,
          );

          // Test Review View at 320dp
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(320, 640),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: WorkReviewView(
                    workingBlocks: [shortBlock],
                    workingAssetId: null,
                    workingR2Key: null,
                    workingLocalPreviewPath: null,
                    selectedDay: 1,
                    onDayChanged: (_) {},
                    droppedCount: 0,
                    droppedExamples: const [],
                    errorMessage: null,
                    onClearError: () {},
                    isSaving: false,
                    onCancel: () {},
                    onScanAgain: () {},
                    onAddBlock: () {},
                    onEditBlock: (_) {},
                    onSave: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.text('Emergency Executive Sync & Architecture Review'),
            findsOneWidget,
          );
        }
      },
    );

    test(
      'Candidate asset double-retirement is strictly prevented on zero extraction and error catch',
      () async {
        final trackingAssetRepo = _TrackingAssetRepo();
        final trackingR2Client = _TrackingR2Client();
        final authRepo = _StubAuthRepo();
        final lifecycleHelper = BaseTimelineUploadLifecycleHelper(
          assetRepository: trackingAssetRepo,
          r2UploadClient: trackingR2Client,
          authRepository: authRepo,
        );

        final container = ProviderContainer(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: 'test-uid',
                    email: 'test@example.com',
                    displayName: 'Test User',
                  ),
                ),
            ),
            uploadedAssetRepositoryProvider.overrideWithValue(
              trackingAssetRepo,
            ),
            r2UploadClientProvider.overrideWithValue(trackingR2Client),
            baseTimelineUploadLifecycleHelperProvider.overrideWithValue(
              lifecycleHelper,
            ),
            routineImportAiControllerProvider.overrideWith(
              (ref) => _CustomResultAiController(
                ref,
                resultToReturn: RoutineImportExtractionResult(
                  id: 'test-result-1',
                  uid: 'test-uid',
                  source: RoutineImportReviewSource.work,
                  createdAt: DateTime.now(),
                  candidates: const [],
                ),
              ),
            ),
            uploadControllerProvider.overrideWith(
              (ref) => _DirectUploadController(
                assetRepository: trackingAssetRepo,
                assetToReturn: UploadedAsset(
                  assetId: 'candidate-zero-blocks',
                  ownerUid: 'test-uid',
                  sourceFeature: 'routine_base_timeline',
                  purpose: UploadedAssetPurpose.workSchedule,
                  status: UploadedAssetStatus.uploaded,
                  fileName: 'schedule.jpg',
                  contentType: 'image/jpeg',
                  sizeBytes: 1024,
                  r2Key:
                      'users/test-uid/routine_base_timeline/work/candidate_zero.jpg',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(workSetupControllerProvider.notifier);
        final setup = BaseTimelineSetup(
          uid: 'test-uid',
          updatedAt: DateTime.now(),
          workBlocks: const [
            TimelineBlockDraft(
              id: 'prev-block',
              section: 'work',
              title: 'Previous Work Block',
              startMinute: 9 * 60,
              endMinute: 17 * 60,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );
        controller.editCurrentWorkSchedule(setup);

        // Upload photo and run extraction that yields 0 blocks
        await controller.pickAndUploadPhoto(
          uid: 'test-uid',
          source: ImageSource.gallery,
          setup: setup,
        );

        final stateAfterZero = container.read(workSetupControllerProvider);
        expect(stateAfterZero.stage, WorkSetupStage.error);
        expect(
          trackingAssetRepo.deletedAssetIds,
          equals(['candidate-zero-blocks']),
        );
        expect(stateAfterZero.candidateAssetId, isNull);
        expect(stateAfterZero.candidateR2Key, isNull);

        // User taps "Keep previous draft"
        controller.keepPreviousDraft(setup, uid: 'test-uid');

        final stateAfterKeep = container.read(workSetupControllerProvider);
        expect(stateAfterKeep.stage, WorkSetupStage.review);
        // Must NOT retire candidate again
        expect(
          trackingAssetRepo.deletedAssetIds,
          equals(['candidate-zero-blocks']),
        );
      },
    );

    test(
      'Legacy R2-key-only source retirement works on save replacement and on removeSetup',
      () async {
        final trackingAssetRepo = _TrackingAssetRepo();
        final trackingR2Client = _TrackingR2Client();
        final authRepo = _StubAuthRepo();
        final fakeSetupRepo = FakeBaseTimelineSetupRepository();
        final fakeRoutineRepo = FakeRoutineRepository();
        final lifecycleHelper = BaseTimelineUploadLifecycleHelper(
          assetRepository: trackingAssetRepo,
          r2UploadClient: trackingR2Client,
          authRepository: authRepo,
        );

        final legacySetup = BaseTimelineSetup(
          uid: 'test-uid',
          updatedAt: DateTime.now(),
          workBlocks: const [
            TimelineBlockDraft(
              id: 'legacy-work-1',
              section: 'work',
              title: 'Legacy Shift',
              startMinute: 9 * 60,
              endMinute: 17 * 60,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
          workLogicalAssetId: null,
          workLogicalAssetR2Key:
              'users/test-uid/routine_base_timeline/work/legacy_photo.jpg',
          revision: 1,
        );
        await fakeSetupRepo.saveSetup('test-uid', legacySetup);

        final container = ProviderContainer(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: 'test-uid',
                    email: 'test@example.com',
                    displayName: 'Test User',
                  ),
                ),
            ),
            uploadedAssetRepositoryProvider.overrideWithValue(
              trackingAssetRepo,
            ),
            r2UploadClientProvider.overrideWithValue(trackingR2Client),
            baseTimelineUploadLifecycleHelperProvider.overrideWithValue(
              lifecycleHelper,
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(
              fakeSetupRepo,
            ),
            routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
          ],
        );
        addTearDown(container.dispose);
        final sub = container.listen(
          workSetupControllerProvider,
          (previous, next) {},
        );
        addTearDown(sub.close);

        final controller = container.read(workSetupControllerProvider.notifier);

        // 1. Test replacement via save():
        controller.startManualSetup(legacySetup);
        controller.addBlock(
          const TimelineBlockDraft(
            id: 'new-manual-block',
            section: 'work',
            title: 'New Manual Shift',
            startMinute: 10 * 60,
            endMinute: 18 * 60,
            repeatDays: [1],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        );
        await controller.save(uid: 'test-uid', setup: legacySetup);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(
          trackingR2Client.deletedKeys,
          contains(
            'users/test-uid/routine_base_timeline/work/legacy_photo.jpg',
          ),
        );

        // 2. Test removal via removeSetup():
        trackingR2Client.deletedKeys.clear();
        final legacySetup2 = legacySetup.copyWith(
          workLogicalAssetR2Key:
              'users/test-uid/routine_base_timeline/work/legacy_to_remove.jpg',
          revision: 2,
        );
        await fakeSetupRepo.saveSetup('test-uid', legacySetup2);

        final outcome = await controller.removeSetup(
          uid: 'test-uid',
          setup: legacySetup2,
        );
        expect(outcome.status, WorkRemoveOutcomeStatus.removed);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(
          trackingR2Client.deletedKeys,
          contains(
            'users/test-uid/routine_base_timeline/work/legacy_to_remove.jpg',
          ),
        );
      },
    );

    testWidgets(
      'WorkBaseSetupScreen renders cleanly under OptivusTheme.lightTheme across currentSetup, chooseSource, review, and refresh banner',
      (tester) async {
        final setup = BaseTimelineSetup(
          uid: 'test-uid',
          updatedAt: DateTime.now(),
          workBlocks: const [
            TimelineBlockDraft(
              id: 'work-1',
              section: 'work',
              title: 'Staff Engineer',
              location: 'Optivus HQ',
              startMinute: 9 * 60,
              endMinute: 17 * 60,
              repeatDays: [1, 2, 3, 4, 5],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
          workLogicalAssetR2Key:
              'users/test-uid/routine_base_timeline/work/office.jpg',
          revision: 1,
        );

        final container = ProviderContainer(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: 'test-uid',
                    email: 'test@example.com',
                    displayName: 'Test User',
                  ),
                ),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Current setup with photo and refresh pending banner
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: OptivusTheme.lightTheme,
              home: Scaffold(
                body: WorkCurrentSetupView(
                  setup: setup,
                  routineBlocks: setup.workBlocks,
                  selectedDay: 1,
                  onDayChanged: (_) {},
                  onBack: () {},
                  onChangeSetup: () {},
                  routineRefreshPending: true,
                  routineRefreshMessage: 'Routine sync pending',
                  onRetryRefresh: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Work / Business'), findsOneWidget);
        expect(find.text('Staff Engineer'), findsOneWidget);
        expect(find.text('Routine sync pending'), findsOneWidget);

        // Choose source view
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: OptivusTheme.lightTheme,
              home: Scaffold(
                body: WorkSourceSelectionView(
                  setup: setup,
                  lifeRole: LifeRoleDraft.workingKey,
                  onCancel: () {},
                  onPickPhoto: (_) {},
                  onManualSetup: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Change Work source'), findsOneWidget);

        // Review view
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: OptivusTheme.lightTheme,
              home: Scaffold(
                body: WorkReviewView(
                  lifeRole: LifeRoleDraft.workingKey,
                  workingBlocks: setup.workBlocks,
                  workingAssetId: null,
                  workingR2Key:
                      'users/test-uid/routine_base_timeline/work/office.jpg',
                  workingLocalPreviewPath: null,
                  selectedDay: 1,
                  onDayChanged: (_) {},
                  droppedCount: 1,
                  droppedExamples: const ['Overnight shift skipped'],
                  errorMessage: null,
                  onClearError: () {},
                  isSaving: false,
                  onCancel: () {},
                  onScanAgain: () {},
                  onAddBlock: () {},
                  onEditBlock: (_) {},
                  onSave: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Review Work Schedule'), findsOneWidget);
        expect(find.text('Use this work schedule'), findsOneWidget);
      },
    );

    testWidgets(
      'Reduced-motion disableAnimations: true renders WorkTimelineCard without animation lag',
      (tester) async {
        final block = TimelineBlockDraft(
          id: 'motion-block',
          section: 'work',
          title: 'Design Review',
          startMinute: 10 * 60,
          endMinute: 11 * 60,
          repeatDays: const [1],
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        const positionedFront = PositionedTimelineEntry(
          entry: TimelineEntry(
            id: 'motion-entry',
            sourceId: 'motion-block',
            title: 'Design Review',
            startMinute: 10 * 60,
            endMinute: 11 * 60,
            repeatDays: [1],
            category: TimelineCategory.work,
          ),
          left: 0,
          top: 0,
          width: 220,
          height: 100,
          column: 0,
          columnCount: 1,
          isFront: true,
          hasOverlap: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: WorkTimelineCard(
                  positioned: positionedFront,
                  block: block,
                  isEditable: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Design Review'), findsOneWidget);
      },
    );

    test(
      'Work domain data round-trip through BaseTimelineTransactionCoordinator and RoutineTemplateFirestoreCodec preserves all 6 fields and legacy fallback',
      () {
        final candidate = RoutineImportCandidateBlock(
          id: 'cand-work-1',
          title: 'Senior Engineer Focus',
          category: 'work',
          hardBlock: true,
          startMinute: 9 * 60,
          endMinute: 17 * 60,
          repeatDays: [1, 2, 3, 4, 5],
          blockType: TimelineBlockDraft.hardBlockKey,
          location: 'Building A, Rm 402',
          workRole: 'Senior Engineer',
          workOrganization: 'Acme Corp',
          workDepartmentOrProject: 'Core Infra',
          workContextType: 'job',
          workMode: 'hybrid',
          workBlockKind: 'deep_work',
          notes: 'Focus on database migration',
        );

        // 1. Map to TimelineBlockDraft
        final mappingResult = mapWorkImportCandidates(candidates: [candidate]);
        expect(mappingResult.blocks.length, equals(1));
        final block = mappingResult.blocks.first;
        expect(block.workRole, equals('Senior Engineer'));
        expect(block.workOrganization, equals('Acme Corp'));
        expect(block.workDepartmentOrProject, equals('Core Infra'));
        expect(block.effectiveWorkDepartmentOrProject, equals('Core Infra'));
        expect(block.workContextType, equals('job'));
        expect(block.workMode, equals('hybrid'));
        expect(block.workBlockKind, equals('deep_work'));

        // 2. Convert to RoutineItem via BaseTimelineTransactionCoordinator
        final now = DateTime.now();
        final routineItem =
            BaseTimelineTransactionCoordinator.routineItemForSectionBlock(
              block: block,
              section: BaseTimelineSection.work,
              uid: 'user-roundtrip-1',
              index: 0,
              now: now,
            );
        expect(routineItem.category, equals(RoutineCategory.job));
        expect(routineItem.workRole, equals('Senior Engineer'));
        expect(routineItem.workOrganization, equals('Acme Corp'));
        expect(routineItem.workDepartmentOrProject, equals('Core Infra'));
        expect(
          routineItem.effectiveWorkDepartmentOrProject,
          equals('Core Infra'),
        );
        expect(routineItem.workContextType, equals('job'));
        expect(routineItem.workMode, equals('hybrid'));
        expect(routineItem.workBlockKind, equals('deep_work'));

        // 3. Serialize to Firestore map and verify allowed fields check
        const codec = RoutineTemplateFirestoreCodec();
        final firestoreMap = codec.toFirestore(
          ownerUid: 'user-roundtrip-1',
          item: routineItem,
        );
        expect(firestoreMap['workRole'], equals('Senior Engineer'));
        expect(firestoreMap['workOrganization'], equals('Acme Corp'));
        expect(firestoreMap['workDepartmentOrProject'], equals('Core Infra'));
        expect(firestoreMap['workContextType'], equals('job'));
        expect(firestoreMap['workMode'], equals('hybrid'));
        expect(firestoreMap['workBlockKind'], equals('deep_work'));

        // 4. Deserialize from Firestore map
        final restoredItem = codec.fromFirestore(
          documentId: routineItem.id,
          data: firestoreMap,
        );
        expect(restoredItem.workRole, equals('Senior Engineer'));
        expect(restoredItem.workOrganization, equals('Acme Corp'));
        expect(restoredItem.workDepartmentOrProject, equals('Core Infra'));
        expect(restoredItem.workContextType, equals('job'));
        expect(restoredItem.workMode, equals('hybrid'));
        expect(restoredItem.workBlockKind, equals('deep_work'));
      },
    );

    test(
      'Legacy block with only sectionLabel resolves effectiveWorkDepartmentOrProject without writing to sectionLabel',
      () {
        const legacyBlock = TimelineBlockDraft(
          id: 'legacy-work-1',
          section: 'work',
          title: 'Consulting Shift',
          startMinute: 10 * 60,
          endMinute: 14 * 60,
          repeatDays: [2, 4],
          sectionLabel: 'Advisory Services',
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        // Effective getter returns legacy sectionLabel
        expect(
          legacyBlock.effectiveWorkDepartmentOrProject,
          equals('Advisory Services'),
        );
        expect(legacyBlock.workDepartmentOrProject, isNull);

        // Converted RoutineItem also preserves fallback
        final routineItem =
            BaseTimelineTransactionCoordinator.routineItemForSectionBlock(
              block: legacyBlock,
              section: BaseTimelineSection.work,
              uid: 'legacy-uid',
              index: 0,
              now: DateTime.now(),
            );
        expect(
          routineItem.effectiveWorkDepartmentOrProject,
          equals('Advisory Services'),
        );
      },
    );

    test(
      'True null clearing in TimelineBlockDraft and RoutineItem copyWith resets fields and never preserves deleted values',
      () {
        const block = TimelineBlockDraft(
          id: 'block-clear-1',
          section: 'work',
          title: 'Full Work Block',
          startMinute: 9 * 60,
          endMinute: 17 * 60,
          repeatDays: [1, 2, 3],
          location: 'Main Campus',
          workRole: 'Staff Engineer',
          workOrganization: 'Tech Corp',
          workDepartmentOrProject: 'Systems',
          workContextType: 'job',
          workMode: 'in_person',
          workBlockKind: 'shift',
          notes: 'Clear me',
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        // Clear all optional work fields
        final clearedBlock = block.copyWith(
          clearLocation: true,
          clearNotes: true,
          clearWorkRole: true,
          clearWorkOrganization: true,
          clearWorkDepartmentOrProject: true,
          clearWorkContextType: true,
          clearWorkMode: true,
          clearWorkBlockKind: true,
          clearSectionLabel: true,
        );

        expect(clearedBlock.location, isNull);
        expect(clearedBlock.notes, isNull);
        expect(clearedBlock.workRole, isNull);
        expect(clearedBlock.workOrganization, isNull);
        expect(clearedBlock.workDepartmentOrProject, isNull);
        expect(clearedBlock.workContextType, isNull);
        expect(clearedBlock.workMode, isNull);
        expect(clearedBlock.workBlockKind, isNull);
        expect(clearedBlock.sectionLabel, isNull);
        expect(clearedBlock.effectiveWorkDepartmentOrProject, isNull);

        // Same check on RoutineItem copyWith
        final item = RoutineItem(
          id: 'item-clear-1',
          title: 'Item Title',
          blockType: RoutineBlockType.hardBlock,
          startMinute: 9 * 60,
          endMinute: 17 * 60,
          repeatDays: const [1],
          workRole: 'Founder',
          workOrganization: 'My Startup',
          workDepartmentOrProject: 'GTM',
          workContextType: 'business',
          workMode: 'remote',
          workBlockKind: 'deep_work',
        );

        final clearedItem = item.copyWith(
          clearWorkRole: true,
          clearWorkOrganization: true,
          clearWorkDepartmentOrProject: true,
          clearWorkContextType: true,
          clearWorkMode: true,
          clearWorkBlockKind: true,
        );

        expect(clearedItem.workRole, isNull);
        expect(clearedItem.workOrganization, isNull);
        expect(clearedItem.workDepartmentOrProject, isNull);
        expect(clearedItem.workContextType, isNull);
        expect(clearedItem.workMode, isNull);
        expect(clearedItem.workBlockKind, isNull);
      },
    );

    testWidgets(
      'WorkDetailSheet displays complete work details including role, organization, badges, duration, and repeat days',
      (tester) async {
        const block = TimelineBlockDraft(
          id: 'sheet-test-1',
          section: 'work',
          title: 'Lead Architect Focus',
          startMinute: 10 * 60,
          endMinute: 12 * 60 + 30, // 2h 30m
          repeatDays: [1, 3, 5],
          location: 'Innovation Lab · Rm 204',
          workRole: 'Lead Architect',
          workOrganization: 'Nexus Labs',
          workDepartmentOrProject: 'NextGen Cloud',
          workContextType: 'business',
          workMode: 'hybrid',
          workBlockKind: 'deep_work',
          notes: 'Prepare system architecture diagrams',
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => WorkDetailSheet.show(context, block),
                    child: const Text('Open Sheet'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.byType(WorkDetailSheet), findsOneWidget);
        expect(find.text('Lead Architect Focus'), findsOneWidget);
        expect(find.text('Nexus Labs'), findsOneWidget);
        expect(find.text('NextGen Cloud'), findsOneWidget);
        expect(find.text('Business'), findsOneWidget);
        expect(find.text('Hybrid'), findsOneWidget);
        expect(find.text('Deep Work'), findsOneWidget);
        expect(find.text('Innovation Lab · Rm 204'), findsOneWidget);
        expect(
          find.text('Prepare system architecture diagrams'),
          findsOneWidget,
        );
        expect(find.textContaining('2h 30m'), findsOneWidget);
        expect(find.text('Mon, Wed, Fri'), findsOneWidget);
      },
    );

    test(
      'RoutineCardFactory workDetailsString and layoutFingerprint track work domain fields accurately',
      () {
        final item1 = RoutineItem(
          id: 'routine-work-1',
          title: 'Morning Operations',
          blockType: RoutineBlockType.hardBlock,
          startMinute: 9 * 60,
          endMinute: 17 * 60,
          repeatDays: const [1, 2, 3, 4, 5],
          workRole: 'Ops Manager',
          workOrganization: 'Starlight Retail',
          workDepartmentOrProject: 'Inventory',
          workContextType: 'job',
          workMode: 'in_person',
          workBlockKind: 'shift',
        );

        final details = RoutineCardFactory.workDetailsString(item1);
        expect(
          details,
          equals(
            'Ops Manager • Starlight Retail • Inventory • In-person • Shift',
          ),
        );

        final fingerprint1 = RoutineCardFactory.layoutFingerprint(item1);

        // Modifying any work field changes fingerprint
        final item2 = item1.copyWith(workMode: 'remote');
        final fingerprint2 = RoutineCardFactory.layoutFingerprint(item2);
        expect(fingerprint1, isNot(equals(fingerprint2)));

        final item3 = item1.copyWith(workOrganization: 'Different Co');
        final fingerprint3 = RoutineCardFactory.layoutFingerprint(item3);
        expect(fingerprint1, isNot(equals(fingerprint3)));
      },
    );

    testWidgets('WorkCurrentSetupView adapts copy according to LifeRole', (
      tester,
    ) async {
      const block = TimelineBlockDraft(
        id: 'role-aware-1',
        section: 'work',
        title: 'Client Sprint',
        startMinute: 9 * 60,
        endMinute: 17 * 60,
        repeatDays: [1, 2],
        blockType: TimelineBlockDraft.hardBlockKey,
      );

      final setup = BaseTimelineSetup(
        uid: uid,
        updatedAt: DateTime.now(),
        workBlocks: const [block],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: WorkCurrentSetupView(
              setup: setup,
              routineBlocks: const [],
              selectedDay: 1,
              onDayChanged: (_) {},
              onBack: () {},
              onChangeSetup: () {},
              lifeRole: LifeRoleDraft.businessKey,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      // Title header reflects business role
      expect(find.text('Business Hours'), findsOneWidget);
    });

    testWidgets(
      'BaseTimelineWorkAdapter edit sheet requires Activity title on save and does not substitute Role or Organization',
      (tester) async {
        const block = TimelineBlockDraft(
          id: 'validation-test-block',
          section: 'work',
          title: '',
          startMinute: 9 * 60,
          endMinute: 17 * 60,
          repeatDays: [1],
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        TimelineBlockDraft? savedBlock;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      BaseTimelineWorkAdapter.showEditSheet(
                        context: context,
                        block: block,
                        onSave: (b) async {
                          savedBlock = b;
                          return true;
                        },
                        lifeRole: LifeRoleDraft.workingKey,
                        isNew: false,
                      );
                    },
                    child: const Text('Open Sheet'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        // Sheet is open
        expect(find.text('Edit work block'), findsOneWidget);

        // Enter Role and Organization, but leave Activity empty
        final roleField = find.byKey(const ValueKey('base-work-role-field'));
        final orgField = find.byKey(
          const ValueKey('base-work-organization-field'),
        );
        await tester.enterText(roleField, 'Lead Systems Architect');
        await tester.enterText(orgField, 'Optivus Technologies');
        await tester.pumpAndSettle();

        // Tap Save
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Activity is required SnackBar is shown and save was prevented
        expect(find.text('Activity is required.'), findsOneWidget);
        expect(savedBlock, isNull);
        // Sheet remains open
        expect(find.text('Edit work block'), findsOneWidget);

        // Now enter Activity title
        final titleField = find.byKey(const ValueKey('base-work-title-field'));
        await tester.enterText(titleField, 'Quarterly Planning');
        await tester.pumpAndSettle();

        // Tap Save again
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Saved block has distinct title, role, and organization
        expect(savedBlock, isNotNull);
        expect(savedBlock!.title, equals('Quarterly Planning'));
        expect(savedBlock!.workRole, equals('Lead Systems Architect'));
        expect(savedBlock!.workOrganization, equals('Optivus Technologies'));
        // Sheet dismissed
        expect(find.text('Edit work block'), findsNothing);
      },
    );

    testWidgets(
      'Activity and Role fields remain strictly independent in edit sheet',
      (tester) async {
        const block = TimelineBlockDraft(
          id: 'independent-test-block',
          section: 'work',
          title: 'Infrastructure Refactor',
          startMinute: 10 * 60,
          endMinute: 12 * 60,
          repeatDays: [1, 2],
          workRole: 'DevOps Engineer',
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      BaseTimelineWorkAdapter.showEditSheet(
                        context: context,
                        block: block,
                        onSave: (_) async => true,
                        lifeRole: LifeRoleDraft.workingKey,
                      );
                    },
                    child: const Text('Open Sheet'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        final titleField = find.byKey(const ValueKey('base-work-title-field'));
        final roleField = find.byKey(const ValueKey('base-work-role-field'));

        // Initially matches block
        expect(
          tester.widget<TextField>(titleField).controller?.text,
          equals('Infrastructure Refactor'),
        );
        expect(
          tester.widget<TextField>(roleField).controller?.text,
          equals('DevOps Engineer'),
        );

        // Modifying Role does not alter Activity
        await tester.enterText(roleField, 'Site Reliability Director');
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(titleField).controller?.text,
          equals('Infrastructure Refactor'),
        );
        expect(
          tester.widget<TextField>(roleField).controller?.text,
          equals('Site Reliability Director'),
        );

        // Clearing Role does not alter Activity
        await tester.enterText(roleField, '');
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(titleField).controller?.text,
          equals('Infrastructure Refactor'),
        );
        expect(tester.widget<TextField>(roleField).controller?.text, isEmpty);

        // Modifying Activity does not alter Role
        await tester.enterText(titleField, 'Database Migration');
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(titleField).controller?.text,
          equals('Database Migration'),
        );
        expect(tester.widget<TextField>(roleField).controller?.text, isEmpty);
      },
    );

    test(
      'WorkPresentationUtils 3-mode profile resolution and labels across business, work, and neutral',
      () {
        // 1. Profile mode checks
        expect(
          WorkPresentationUtils.isBusinessProfile(LifeRoleDraft.businessKey),
          isTrue,
        );
        expect(
          WorkPresentationUtils.isBusinessProfile(LifeRoleDraft.workingKey),
          isFalse,
        );
        expect(
          WorkPresentationUtils.isBusinessProfile('student_working'),
          isFalse,
        );
        expect(WorkPresentationUtils.isBusinessProfile(null), isFalse);
        expect(
          WorkPresentationUtils.isBusinessProfile('unknown_role'),
          isFalse,
        );

        expect(
          WorkPresentationUtils.isWorkProfile(LifeRoleDraft.workingKey),
          isTrue,
        );
        expect(WorkPresentationUtils.isWorkProfile('student_working'), isTrue);
        expect(
          WorkPresentationUtils.isWorkProfile(LifeRoleDraft.businessKey),
          isFalse,
        );
        expect(WorkPresentationUtils.isWorkProfile(null), isFalse);
        expect(WorkPresentationUtils.isWorkProfile('unknown_role'), isFalse);

        // 2. Business profile strings
        const bRole = LifeRoleDraft.businessKey;
        expect(
          WorkPresentationUtils.currentSetupHeaderTitle(bRole),
          equals('Business Hours'),
        );
        expect(
          WorkPresentationUtils.currentSetupEmptyTitle(bRole),
          equals('No business hours yet'),
        );
        expect(
          WorkPresentationUtils.currentSetupEmptySubtitle(bRole),
          contains('business hours'),
        );
        expect(
          WorkPresentationUtils.currentSetupPrimaryButtonLabel(
            isConfigured: false,
            lifeRole: bRole,
          ),
          equals('Set up Business'),
        );
        expect(
          WorkPresentationUtils.currentSetupPrimaryButtonLabel(
            isConfigured: true,
            lifeRole: bRole,
          ),
          equals('Edit schedule'),
        );
        expect(
          WorkPresentationUtils.currentSetupSourceButtonLabel(lifeRole: bRole),
          equals('Change source'),
        );
        expect(
          WorkPresentationUtils.sourceSelectionTitle(bRole),
          equals('Change Business source'),
        );
        expect(
          WorkPresentationUtils.sourceSelectionSubtitle(bRole),
          contains('business hours'),
        );
        expect(
          WorkPresentationUtils.sourceManualTitle(bRole),
          equals('Set up business hours manually'),
        );
        expect(
          WorkPresentationUtils.sourceEditCurrentTitle(bRole),
          equals('Edit current business hours'),
        );
        expect(
          WorkPresentationUtils.reviewTitle(bRole),
          equals('Review Business Schedule'),
        );
        expect(
          WorkPresentationUtils.addBlockButtonLabel(bRole),
          equals('Add Business Block'),
        );
        expect(
          WorkPresentationUtils.useScheduleCtaLabel(bRole),
          equals('Use this business schedule'),
        );
        expect(
          WorkPresentationUtils.editorTitle(isNew: false, lifeRole: bRole),
          equals('Edit Business Block'),
        );
        expect(
          WorkPresentationUtils.editorTitle(isNew: true, lifeRole: bRole),
          equals('Add Business Block'),
        );
        expect(
          WorkPresentationUtils.removeBlockLabel(bRole),
          equals('Remove business block'),
        );
        expect(
          WorkPresentationUtils.removeBlockConfirmTitle(bRole),
          equals('Remove this business block?'),
        );
        expect(
          WorkPresentationUtils.removeSetupLabel(bRole),
          equals('Remove Business Setup'),
        );
        expect(
          WorkPresentationUtils.removeSetupConfirmTitle(bRole),
          equals('Remove Business Setup?'),
        );
        expect(
          WorkPresentationUtils.removeSetupConfirmContent(bRole),
          contains('business blocks'),
        );
        expect(
          WorkPresentationUtils.weeklyBlockCount(1, bRole),
          equals('1 weekly business block'),
        );
        expect(
          WorkPresentationUtils.weeklyBlockCount(3, bRole),
          equals('3 weekly business blocks'),
        );

        // 3. Work profile strings (both working and student_working)
        for (final wRole in [LifeRoleDraft.workingKey, 'student_working']) {
          expect(
            WorkPresentationUtils.currentSetupHeaderTitle(wRole),
            equals('Work Schedule'),
          );
          expect(
            WorkPresentationUtils.currentSetupEmptyTitle(wRole),
            equals('No work schedule yet'),
          );
          expect(
            WorkPresentationUtils.currentSetupEmptySubtitle(wRole),
            contains('shifts'),
          );
          expect(
            WorkPresentationUtils.currentSetupPrimaryButtonLabel(
              isConfigured: false,
              lifeRole: wRole,
            ),
            equals('Set up Work'),
          );
          expect(
            WorkPresentationUtils.currentSetupPrimaryButtonLabel(
              isConfigured: true,
              lifeRole: wRole,
            ),
            equals('Edit schedule'),
          );
          expect(
            WorkPresentationUtils.currentSetupSourceButtonLabel(
              lifeRole: wRole,
            ),
            equals('Change source'),
          );
          expect(
            WorkPresentationUtils.sourceSelectionTitle(wRole),
            equals('Change Work source'),
          );
          expect(
            WorkPresentationUtils.sourceManualTitle(wRole),
            equals('Set up manually'),
          );
          expect(
            WorkPresentationUtils.sourceEditCurrentTitle(wRole),
            equals('Edit current work schedule'),
          );
          expect(
            WorkPresentationUtils.reviewTitle(wRole),
            equals('Review Work Schedule'),
          );
          expect(
            WorkPresentationUtils.addBlockButtonLabel(wRole),
            equals('Add work block'),
          );
          expect(
            WorkPresentationUtils.useScheduleCtaLabel(wRole),
            equals('Use this work schedule'),
          );
          expect(
            WorkPresentationUtils.editorTitle(isNew: false, lifeRole: wRole),
            equals('Edit work block'),
          );
          expect(
            WorkPresentationUtils.editorTitle(isNew: true, lifeRole: wRole),
            equals('Add work block'),
          );
          expect(
            WorkPresentationUtils.removeBlockLabel(wRole),
            equals('Remove work block'),
          );
          expect(
            WorkPresentationUtils.removeBlockConfirmTitle(wRole),
            equals('Remove this work block?'),
          );
          expect(
            WorkPresentationUtils.removeSetupLabel(wRole),
            equals('Remove Work Setup'),
          );
          expect(
            WorkPresentationUtils.removeSetupConfirmTitle(wRole),
            equals('Remove Work Setup?'),
          );
          expect(
            WorkPresentationUtils.weeklyBlockCount(1, wRole),
            equals('1 weekly work block'),
          );
          expect(
            WorkPresentationUtils.weeklyBlockCount(3, wRole),
            equals('3 weekly work blocks'),
          );
        }

        // 4. Neutral profile strings (null, empty, unknown)
        for (final nRole in [null, '', 'student', 'retired', 'unknown']) {
          expect(
            WorkPresentationUtils.currentSetupHeaderTitle(nRole),
            equals('Work / Business'),
          );
          expect(
            WorkPresentationUtils.currentSetupEmptyTitle(nRole),
            equals('No Work / Business schedule yet'),
          );
          expect(
            WorkPresentationUtils.currentSetupEmptySubtitle(nRole),
            contains('work or business hours'),
          );
          expect(
            WorkPresentationUtils.currentSetupPrimaryButtonLabel(
              isConfigured: false,
              lifeRole: nRole,
            ),
            equals('Set up Work / Business'),
          );
          expect(
            WorkPresentationUtils.currentSetupPrimaryButtonLabel(
              isConfigured: true,
              lifeRole: nRole,
            ),
            equals('Edit schedule'),
          );
          expect(
            WorkPresentationUtils.currentSetupSourceButtonLabel(
              lifeRole: nRole,
            ),
            equals('Change source'),
          );
          expect(
            WorkPresentationUtils.sourceSelectionTitle(nRole),
            equals('Change Work source'),
          );
          expect(
            WorkPresentationUtils.sourceManualTitle(nRole),
            equals('Set up manually'),
          );
          expect(
            WorkPresentationUtils.sourceEditCurrentTitle(nRole),
            equals('Edit current schedule'),
          );
          expect(
            WorkPresentationUtils.reviewTitle(nRole),
            equals('Review Work / Business'),
          );
          expect(
            WorkPresentationUtils.addBlockButtonLabel(nRole),
            equals('Add Work / Business Block'),
          );
          expect(
            WorkPresentationUtils.useScheduleCtaLabel(nRole),
            equals('Use this schedule'),
          );
          expect(
            WorkPresentationUtils.editorTitle(isNew: false, lifeRole: nRole),
            equals('Edit Work / Business Block'),
          );
          expect(
            WorkPresentationUtils.editorTitle(isNew: true, lifeRole: nRole),
            equals('Add Work / Business Block'),
          );
          expect(
            WorkPresentationUtils.removeBlockLabel(nRole),
            equals('Remove block'),
          );
          expect(
            WorkPresentationUtils.removeBlockConfirmTitle(nRole),
            equals('Remove this block?'),
          );
          expect(
            WorkPresentationUtils.removeSetupLabel(nRole),
            equals('Remove Work / Business Setup'),
          );
          expect(
            WorkPresentationUtils.removeSetupConfirmTitle(nRole),
            equals('Remove Setup?'),
          );
          expect(
            WorkPresentationUtils.weeklyBlockCount(1, nRole),
            equals('1 weekly block'),
          );
          expect(
            WorkPresentationUtils.weeklyBlockCount(3, nRole),
            equals('3 weekly blocks'),
          );
        }
      },
    );

    test(
      'WorkPresentationUtils sourceManualSubtitle dynamic businessMode resolution',
      () {
        // Fixed business mode
        expect(
          WorkPresentationUtils.sourceManualSubtitle(
            lifeRole: LifeRoleDraft.businessKey,
            businessMode: 'fixed_business',
          ),
          equals('Add your regular business hours and recurring operations.'),
        );

        // Flexible business mode
        expect(
          WorkPresentationUtils.sourceManualSubtitle(
            lifeRole: LifeRoleDraft.businessKey,
            businessMode: 'flexible_business',
          ),
          equals(
            'Add the business blocks you want anchored to specific times.',
          ),
        );

        // Mixed business mode
        expect(
          WorkPresentationUtils.sourceManualSubtitle(
            lifeRole: LifeRoleDraft.businessKey,
            businessMode: 'mixed_business',
          ),
          equals(
            'Add your fixed business hours and scheduled client or operating blocks.',
          ),
        );

        // Default business (no businessMode or unrecognized)
        expect(
          WorkPresentationUtils.sourceManualSubtitle(
            lifeRole: LifeRoleDraft.businessKey,
            businessMode: null,
          ),
          equals('Add your business and client blocks day by day'),
        );

        // Work profile
        expect(
          WorkPresentationUtils.sourceManualSubtitle(
            lifeRole: LifeRoleDraft.workingKey,
          ),
          equals('Add your work blocks day by day'),
        );

        // Neutral profile
        expect(
          WorkPresentationUtils.sourceManualSubtitle(lifeRole: null),
          equals('Add your schedule blocks day by day'),
        );
      },
    );

    test(
      'WorkPresentationUtils scheduledCount formats block counts accurately',
      () {
        // Neutral
        expect(
          WorkPresentationUtils.scheduledCount(0),
          equals('0 blocks scheduled'),
        );
        expect(
          WorkPresentationUtils.scheduledCount(1),
          equals('1 block scheduled'),
        );
        expect(
          WorkPresentationUtils.scheduledCount(5),
          equals('5 blocks scheduled'),
        );

        // Work
        expect(
          WorkPresentationUtils.scheduledCount(0, LifeRoleDraft.workingKey),
          equals('0 work blocks scheduled'),
        );
        expect(
          WorkPresentationUtils.scheduledCount(1, LifeRoleDraft.workingKey),
          equals('1 work block scheduled'),
        );
        expect(
          WorkPresentationUtils.scheduledCount(5, LifeRoleDraft.workingKey),
          equals('5 work blocks scheduled'),
        );

        // Student working (must use Work wording)
        expect(
          WorkPresentationUtils.scheduledCount(
            1,
            LifeRoleDraft.studentWorkingKey,
          ),
          equals('1 work block scheduled'),
        );
        expect(
          WorkPresentationUtils.scheduledCount(
            5,
            LifeRoleDraft.studentWorkingKey,
          ),
          equals('5 work blocks scheduled'),
        );

        // Business
        expect(
          WorkPresentationUtils.scheduledCount(0, LifeRoleDraft.businessKey),
          equals('0 business blocks scheduled'),
        );
        expect(
          WorkPresentationUtils.scheduledCount(1, LifeRoleDraft.businessKey),
          equals('1 business block scheduled'),
        );
        expect(
          WorkPresentationUtils.scheduledCount(5, LifeRoleDraft.businessKey),
          equals('5 business blocks scheduled'),
        );
      },
    );

    testWidgets(
      'Rich WorkTimelineCard wraps department and project text and calculates minimumHeight matching rendered layout without overflow',
      (tester) async {
        const richBlock = TimelineBlockDraft(
          id: 'rich-work-block-1',
          section: 'work',
          title: 'Strategic Architecture Review',
          startMinute: 9 * 60,
          endMinute: 11 * 60,
          repeatDays: [1],
          workRole: 'Principal Cloud Platform Architect',
          workOrganization:
              'Global Enterprise Solutions & Distributed Systems Infrastructure Corp.',
          workDepartmentOrProject:
              'Cloud Architecture & Reliability Engineering Group',
          location: 'Executive Briefing Center Tower B, 14th Floor Room 1402',
          notes:
              'Detailed architecture sign-off requirements, multi-region failover strategy, and zero-downtime database deployment checkpoints.',
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        const positionedEntry = PositionedTimelineEntry(
          entry: TimelineEntry(
            id: 'rich-entry-1',
            sourceId: 'rich-work-block-1',
            title: 'Strategic Architecture Review',
            startMinute: 9 * 60,
            endMinute: 11 * 60,
            repeatDays: [1],
            category: TimelineCategory.work,
          ),
          left: 0,
          top: 0,
          width: 320,
          height: 480,
          column: 0,
          columnCount: 1,
          isFront: true,
          hasOverlap: false,
        );

        for (final width in [320.0, 360.0]) {
          for (final scale in [1.0, 1.4, 2.0]) {
            tester.view.physicalSize = Size(width * scale, 1200 * scale);
            tester.view.devicePixelRatio = scale;
            addTearDown(tester.view.resetPhysicalSize);

            final minHeight = WorkTimelineCard.minimumHeight(
              richBlock,
              textScale: scale,
              contentWidth: width,
            );
            expect(minHeight, isPositive);

            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData.dark(),
                home: Scaffold(
                  body: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: SizedBox(
                      width: width,
                      height: minHeight + 50,
                      child: WorkTimelineCard(
                        positioned: positionedEntry,
                        block: richBlock,
                        isEditable: true,
                        accent: OptivusColors.routineAccent,
                      ),
                    ),
                  ),
                ),
              ),
            );

            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(find.text('Strategic Architecture Review'), findsOneWidget);
            expect(
              find.textContaining('Principal Cloud Platform Architect'),
              findsOneWidget,
            );
            expect(
              find.textContaining(
                'Global Enterprise Solutions & Distributed Systems Infrastructure Corp.',
              ),
              findsOneWidget,
            );
            expect(
              find.text('Cloud Architecture & Reliability Engineering Group'),
              findsOneWidget,
            );
            expect(
              find.text(
                'Executive Briefing Center Tower B, 14th Floor Room 1402',
              ),
              findsOneWidget,
            );
            expect(
              find.text(
                'Detailed architecture sign-off requirements, multi-region failover strategy, and zero-downtime database deployment checkpoints.',
              ),
              findsOneWidget,
            );
          }
        }
      },
    );

    group('WorkSetupErrorMapper regression tests', () {
      test(
        'Test A: FirebaseException(code: unauthenticated) maps to session expired copy',
        () {
          final saveError = FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unauthenticated',
          );
          final saveMsg = WorkSetupErrorMapper.mapSaveError(saveError);
          expect(saveMsg, contains('session expired'));
          expect(saveMsg, contains('Sign in again before saving'));

          final removeMsg = WorkSetupErrorMapper.mapRemoveError(saveError);
          expect(removeMsg, contains('session expired'));
          expect(removeMsg, contains('Sign in again before trying again'));
        },
      );

      test(
        'Test B: FirebaseException(code: permission-denied) does NOT claim session changed',
        () {
          final permError = FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          );
          final saveMsg = WorkSetupErrorMapper.mapSaveError(permError);
          expect(saveMsg, isNot(contains('session changed')));
          expect(saveMsg, isNot(contains('Sign in again')));
          expect(saveMsg, contains("wasn't permitted"));
          expect(saveMsg, contains('current setup is still active'));

          final removeMsg = WorkSetupErrorMapper.mapRemoveError(permError);
          expect(removeMsg, isNot(contains('session changed')));
          expect(removeMsg, isNot(contains('Sign in again')));
          expect(removeMsg, contains("wasn't permitted"));
          expect(removeMsg, contains('current setup is still active'));

          // Business profile-specific copy
          final bizSaveMsg = WorkSetupErrorMapper.mapSaveError(
            permError,
            LifeRoleDraft.businessKey,
          );
          expect(bizSaveMsg, contains('business schedule'));
          expect(bizSaveMsg, isNot(contains('session changed')));

          final bizRemoveMsg = WorkSetupErrorMapper.mapRemoveError(
            permError,
            LifeRoleDraft.businessKey,
          );
          expect(bizRemoveMsg, contains('business setup'));
          expect(bizRemoveMsg, isNot(contains('session changed')));
        },
      );

      test(
        'Test C: Concurrency exception maps to reload/latest-setup copy',
        () {
          final conflict = BaseTimelineConcurrencyException(
            expectedRevision: 2,
            actualRevision: 3,
          );
          final saveMsg = WorkSetupErrorMapper.mapSaveError(conflict);
          expect(saveMsg, contains('changed while you were editing'));
          expect(
            saveMsg,
            contains('Reload the latest setup before saving again'),
          );

          final removeMsg = WorkSetupErrorMapper.mapRemoveError(conflict);
          expect(removeMsg, contains('changed while you were editing'));
          expect(
            removeMsg,
            contains('Reload the latest setup before trying again'),
          );
        },
      );

      test('Test D: Timeout and network behavior remain consistent', () {
        final timeout = TimeoutException('Operation timed out');
        final timeoutMsg = WorkSetupErrorMapper.mapSaveError(timeout);
        expect(timeoutMsg, contains('timed out'));
        expect(timeoutMsg, contains('current setup is still active'));

        final networkError = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        );
        final networkMsg = WorkSetupErrorMapper.mapSaveError(networkError);
        expect(
          networkMsg,
          contains('current setup is still active. Please retry'),
        );
      });
    });

    group('WorkPresentationUtils secondarySetupSummary tests', () {
      test('Consistent metadata returns clean summary string', () {
        const blocks = [
          TimelineBlockDraft(
            id: 'b1',
            section: 'work',
            title: 'Morning Shift',
            startMinute: 9 * 60,
            endMinute: 13 * 60,
            repeatDays: [1, 2],
            workRole: 'Software Engineer',
            workOrganization: 'Optivus',
            workMode: 'hybrid',
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
          TimelineBlockDraft(
            id: 'b2',
            section: 'work',
            title: 'Afternoon Sync',
            startMinute: 14 * 60,
            endMinute: 17 * 60,
            repeatDays: [3, 4],
            workRole: 'Software Engineer',
            workOrganization: 'Optivus',
            workMode: 'hybrid',
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ];

        final summary = WorkPresentationUtils.secondarySetupSummary(blocks);
        expect(summary, equals('Software Engineer · Optivus · Hybrid'));
      });

      test('Conflicting organizations return null', () {
        const blocks = [
          TimelineBlockDraft(
            id: 'b1',
            section: 'work',
            title: 'Job 1',
            startMinute: 9 * 60,
            endMinute: 12 * 60,
            repeatDays: [1],
            workRole: 'Engineer',
            workOrganization: 'Optivus',
            workMode: 'hybrid',
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
          TimelineBlockDraft(
            id: 'b2',
            section: 'work',
            title: 'Job 2',
            startMinute: 13 * 60,
            endMinute: 17 * 60,
            repeatDays: [2],
            workRole: 'Engineer',
            workOrganization: 'Acme Corp',
            workMode: 'hybrid',
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ];

        expect(WorkPresentationUtils.secondarySetupSummary(blocks), isNull);
      });

      test('Conflicting roles return null', () {
        const blocks = [
          TimelineBlockDraft(
            id: 'b1',
            section: 'work',
            title: 'Task A',
            startMinute: 9 * 60,
            endMinute: 12 * 60,
            repeatDays: [1],
            workRole: 'Staff Engineer',
            workOrganization: 'Optivus',
            workMode: 'remote',
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
          TimelineBlockDraft(
            id: 'b2',
            section: 'work',
            title: 'Task B',
            startMinute: 13 * 60,
            endMinute: 17 * 60,
            repeatDays: [2],
            workRole: 'Consultant',
            workOrganization: 'Optivus',
            workMode: 'remote',
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ];

        expect(WorkPresentationUtils.secondarySetupSummary(blocks), isNull);
      });
    });

    testWidgets(
      'Role-clear UI save and reopen contract ensures cleared role stays empty and does not resurrect',
      (tester) async {
        const initialBlock = TimelineBlockDraft(
          id: 'role-clear-test-block',
          section: 'work',
          title: 'Sprint Planning',
          startMinute: 10 * 60,
          endMinute: 11 * 60,
          repeatDays: [1],
          workRole: 'Senior Engineer',
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        TimelineBlockDraft? savedResult;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      BaseTimelineWorkAdapter.showEditSheet(
                        context: context,
                        block: initialBlock,
                        onSave: (saved) async {
                          savedResult = saved;
                          return true;
                        },
                        lifeRole: LifeRoleDraft.workingKey,
                      );
                    },
                    child: const Text('Open Sheet'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Open editor
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        final titleField = find.byKey(const ValueKey('base-work-title-field'));
        final roleField = find.byKey(const ValueKey('base-work-role-field'));

        expect(
          tester.widget<TextField>(titleField).controller?.text,
          equals('Sprint Planning'),
        );
        expect(
          tester.widget<TextField>(roleField).controller?.text,
          equals('Senior Engineer'),
        );

        // 2. Clear role in UI
        await tester.enterText(roleField, '');
        await tester.pumpAndSettle();

        // 3. Save
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(savedResult, isNotNull);
        expect(savedResult!.title, equals('Sprint Planning'));
        expect(savedResult!.workRole, isNull);

        // 4. Reopen editor using the returned saved block
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      BaseTimelineWorkAdapter.showEditSheet(
                        context: context,
                        block: savedResult!,
                        onSave: (_) async => true,
                        lifeRole: LifeRoleDraft.workingKey,
                      );
                    },
                    child: const Text('Reopen Sheet'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Reopen Sheet'));
        await tester.pumpAndSettle();

        final reopenedTitle = find.byKey(
          const ValueKey('base-work-title-field'),
        );
        final reopenedRole = find.byKey(const ValueKey('base-work-role-field'));

        expect(
          tester.widget<TextField>(reopenedTitle).controller?.text,
          equals('Sprint Planning'),
        );
        // Role must remain strictly empty!
        expect(
          tester.widget<TextField>(reopenedRole).controller?.text,
          isEmpty,
        );
      },
    );

    testWidgets(
      'WorkCurrentSetupView with business lifeRole displays complete business copy and empty-day state',
      (tester) async {
        const businessBlock = TimelineBlockDraft(
          id: 'biz-block-1',
          section: 'work',
          title: 'Executive Leadership Sync',
          startMinute: 9 * 60,
          endMinute: 11 * 60,
          repeatDays: [1, 2, 3, 4, 5],
          workRole: 'Founder & CEO',
          workOrganization: 'Roy Enterprises',
          workMode: 'in_person',
          workBlockKind: 'business_hours',
          workContextType: 'business',
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        final trackingAssetRepo = _TrackingAssetRepo();
        final setup = BaseTimelineSetup(
          uid: 'user-biz-1',
          updatedAt: DateTime.now(),
          revision: 2,
          workAuthority: BaseTimelineSectionAuthority.baseTimeline,
          workRoutineItemIds: const ['biz-block-1'],
          workBlocks: const [businessBlock],
          workLogicalAssetId: 'biz-photo-1',
        );

        int currentDay = 7; // Sunday - no scheduled business blocks

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              uploadedAssetRepositoryProvider.overrideWithValue(
                trackingAssetRepo,
              ),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    return WorkCurrentSetupView(
                      setup: setup,
                      routineBlocks: const [businessBlock],
                      selectedDay: currentDay,
                      onDayChanged: (day) => setState(() => currentDay = day),
                      onBack: () {},
                      onChangeSetup: () {},
                      onRemoveSetup: () {},
                      lifeRole: LifeRoleDraft.businessKey,
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // 1. Business header title
        expect(find.text('Business Hours'), findsOneWidget);

        // 2. Business Schedule Photo
        expect(find.text('Business Schedule Photo'), findsOneWidget);

        // 3. Role-aware summary in header
        expect(find.textContaining('business block'), findsAtLeastNWidgets(1));

        // 4. Empty day message for business
        expect(find.text('No business scheduled on this day.'), findsOneWidget);

        // 5. Work-only strings must be absent initially
        expect(find.text('Work Schedule'), findsNothing);
        expect(find.text('Work Schedule Photo'), findsNothing);
        expect(find.text('No work scheduled on this day.'), findsNothing);

        // 6. Open header overflow menu to verify Remove Business Setup
        final menuBtn = find.byKey(
          const Key('base-timeline-header-menu-button'),
        );
        expect(menuBtn, findsOneWidget);
        await tester.tap(menuBtn);
        await tester.pumpAndSettle();

        expect(find.text('Remove Business Setup'), findsOneWidget);
        expect(find.text('Remove Work Setup'), findsNothing);
      },
    );

    testWidgets(
      'WorkCurrentSetupView with student_working profile displays Work domain labels and photo',
      (tester) async {
        final trackingAssetRepo = _TrackingAssetRepo();
        const studentBlock = TimelineBlockDraft(
          id: 'student-block-1',
          section: 'work',
          title: 'Campus IT Lab Support',
          startMinute: 13 * 60,
          endMinute: 17 * 60,
          repeatDays: [2, 4],
          workRole: 'Lab Assistant',
          workOrganization: 'University IT',
          workMode: 'in_person',
          workBlockKind: 'shift',
          workContextType: 'job',
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        final setup = BaseTimelineSetup(
          uid: 'student-user-1',
          updatedAt: DateTime.now(),
          revision: 1,
          workAuthority: BaseTimelineSectionAuthority.baseTimeline,
          workRoutineItemIds: const ['student-block-1'],
          workBlocks: const [studentBlock],
          workLogicalAssetId: 'student-photo-1',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              uploadedAssetRepositoryProvider.overrideWithValue(
                trackingAssetRepo,
              ),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: Scaffold(
                body: WorkCurrentSetupView(
                  setup: setup,
                  routineBlocks: const [studentBlock],
                  selectedDay: 1, // Monday (empty)
                  onDayChanged: (_) {},
                  onBack: () {},
                  onChangeSetup: () {},
                  onRemoveSetup: () {},
                  lifeRole: LifeRoleDraft.studentWorkingKey,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Work Schedule'), findsOneWidget);
        expect(find.text('Work Schedule Photo'), findsOneWidget);
        expect(find.text('No work scheduled on this day.'), findsOneWidget);
        expect(find.text('Business Hours'), findsNothing);
        expect(find.text('Business Schedule Photo'), findsNothing);

        // Open header menu to verify Remove Work Setup
        final menuBtn = find.byKey(
          const Key('base-timeline-header-menu-button'),
        );
        expect(menuBtn, findsOneWidget);
        await tester.tap(menuBtn);
        await tester.pumpAndSettle();

        expect(find.text('Remove Work Setup'), findsOneWidget);
        expect(find.text('Remove Business Setup'), findsNothing);
      },
    );

    test(
      'student_working profile preserves Work domain labels throughout presentation utils',
      () {
        const studentRole = LifeRoleDraft.studentWorkingKey;
        expect(WorkPresentationUtils.isWorkProfile(studentRole), isTrue);
        expect(WorkPresentationUtils.isBusinessProfile(studentRole), isFalse);
        expect(
          WorkPresentationUtils.currentSetupHeaderTitle(studentRole),
          equals('Work Schedule'),
        );
        expect(
          WorkPresentationUtils.emptyDayMessage(studentRole),
          equals('No work scheduled on this day.'),
        );
        expect(
          WorkPresentationUtils.photoCardTitle(LifeRoleDraft.businessKey),
          equals('Business Schedule Photo'),
        );
        expect(
          WorkPresentationUtils.photoCardTitle(LifeRoleDraft.workingKey),
          equals('Work Schedule Photo'),
        );
        expect(
          WorkPresentationUtils.scheduledCount(2, studentRole),
          equals('2 work blocks scheduled'),
        );
      },
    );

    test(
      'WorkSetupErrorMapper distinguishes authority and permission errors without false session expired',
      () {
        // Authority mismatch string must NOT map to session expired
        final authorityError = Exception(
          'BaseTimelineSectionAuthority.baseTimeline mismatch',
        );
        final authSaveMsg = WorkSetupErrorMapper.mapSaveError(authorityError);
        expect(authSaveMsg, isNot(contains('session expired')));
        expect(authSaveMsg, isNot(contains('Sign in again')));

        // Not authorized string must map to permission copy, NOT session expired
        final notAuthError = Exception(
          'Request not authorized to mutate routine',
        );
        final notAuthSaveMsg = WorkSetupErrorMapper.mapSaveError(notAuthError);
        expect(notAuthSaveMsg, isNot(contains('session expired')));
        expect(notAuthSaveMsg, isNot(contains('Sign in again')));
        expect(notAuthSaveMsg, contains("wasn't permitted"));
      },
    );

    testWidgets(
      'WorkSetupProfileSummaryCard renders consistent role, organization, department, badges, block count, and compact source row',
      (tester) async {
        var viewCalled = false;

        final summary = WorkProfileSummary(
          headerTitle: 'WORK PROFILE',
          headline: 'Staff Software Engineer',
          subline: 'Google · Cloud Infrastructure',
          badges: ['Job', 'Hybrid'],
          scheduleSummary: '2 work blocks scheduled each weekday (8h)',
          sourceLabel: 'Schedule Photo',
          hasSourcePhoto: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: WorkSetupProfileSummaryCard(
                  summary: summary,
                  onViewPhoto: () => viewCalled = true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('work-setup-profile-summary-card')),
          findsOneWidget,
        );
        expect(find.text('WORK PROFILE'), findsOneWidget);
        expect(find.text('Staff Software Engineer'), findsOneWidget);
        expect(find.text('Google · Cloud Infrastructure'), findsOneWidget);
        expect(find.text('Job'), findsOneWidget);
        expect(find.text('Hybrid'), findsOneWidget);
        expect(
          find.text('2 work blocks scheduled each weekday (8h)'),
          findsOneWidget,
        );
        expect(find.text('Schedule Photo'), findsOneWidget);

        // Tap View photo
        await tester.tap(
          find.byKey(const Key('work-setup-profile-view-photo-button')),
        );
        await tester.pumpAndSettle();
        expect(viewCalled, isTrue);
      },
    );

    testWidgets(
      'WorkSetupProfileSummaryCard renders aggregate summary without fabricating single profile when blocks differ',
      (tester) async {
        const blocks = <TimelineBlockDraft>[
          TimelineBlockDraft(
            id: 'b1',
            section: 'work',
            title: 'Consulting Session',
            startMinute: 9 * 60,
            endMinute: 11 * 60,
            repeatDays: [1],
            workRole: 'Adviser',
            workOrganization: 'Acme Corp',
            workContextType: 'freelance',
            workMode: 'remote',
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
          TimelineBlockDraft(
            id: 'b2',
            section: 'work',
            title: 'Internal Ops',
            startMinute: 13 * 60,
            endMinute: 15 * 60,
            repeatDays: [2],
            workRole: 'Founder',
            workOrganization: 'Optivus LLC',
            workContextType: 'business_owner',
            workMode: 'office',
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ];

        final summary = WorkPresentationUtils.resolveProfileSummary(
          blocks: blocks,
          lifeRole: 'business',
          hasSourcePhoto: false,
        );

        expect(summary.headerTitle, equals('Business Profile'));
        expect(summary.headline, equals('Multiple roles & organizations'));
        expect(summary.subline, equals('2 clients / organizations'));
        expect(summary.badges, contains('Mixed context'));
        expect(summary.badges, contains('Mixed modes'));
        expect(summary.hasSourcePhoto, isFalse);
        expect(summary.sourceLabel, equals('Manual setup'));

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: WorkSetupProfileSummaryCard(summary: summary),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('BUSINESS PROFILE'), findsOneWidget);
        expect(find.text('Multiple roles & organizations'), findsOneWidget);
        expect(find.text('2 clients / organizations'), findsOneWidget);
        expect(find.text('Manual setup'), findsOneWidget);
      },
    );

    testWidgets(
      'WorkDetailSheet displays complete work details and [ Edit this block ] action triggers onEdit callback',
      (tester) async {
        const block = TimelineBlockDraft(
          id: 'b-detail-test',
          section: 'work',
          title: 'Quarterly Executive Review',
          startMinute: 10 * 60,
          endMinute: 12 * 60,
          repeatDays: [1, 3],
          workRole: 'VP of Engineering',
          workOrganization: 'Optivus Enterprise',
          workDepartmentOrProject: 'Core Architecture',
          workContextType: 'job',
          workMode: 'hybrid',
          location: 'Executive Boardroom 401',
          notes: 'Prepare FY27 strategy decks',
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        bool editTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      WorkDetailSheet.show(
                        ctx,
                        block,
                        onEdit: () => editTapped = true,
                      );
                    },
                    child: const Text('Open Sheet'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.byType(WorkDetailSheet), findsOneWidget);
        expect(find.text('Quarterly Executive Review'), findsOneWidget);
        expect(find.text('VP of Engineering'), findsOneWidget);
        expect(find.text('Optivus Enterprise'), findsOneWidget);
        expect(find.text('Core Architecture'), findsOneWidget);
        expect(find.text('Executive Boardroom 401'), findsOneWidget);
        expect(find.text('Prepare FY27 strategy decks'), findsOneWidget);

        // Verify Edit this block button
        expect(find.text('Edit this block'), findsOneWidget);
        await tester.tap(find.text('Edit this block'));
        await tester.pumpAndSettle();

        expect(editTapped, isTrue);
        expect(find.byType(WorkDetailSheet), findsNothing);
      },
    );

    testWidgets(
      'Direct block addition via + Add work block bottom action enters draft review/edit without starting setup from scratch',
      (tester) async {
        final now = DateTime.now();
        const block = TimelineBlockDraft(
          id: 'work-1',
          section: 'work',
          title: 'Existing Shift',
          startMinute: 9 * 60,
          endMinute: 17 * 60,
          repeatDays: [1, 2, 3, 4, 5],
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        final setup = BaseTimelineSetup(
          uid: uid,
          updatedAt: now,
          workBlocks: const [block],
          workLogicalAssetId: 'asset-work-test',
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
                      lifeRole: 'work',
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

        expect(find.text('Existing Shift'), findsOneWidget);
        expect(
          find.byKey(const Key('work-current-setup-add-block-button')),
          findsNothing,
        );

        // Tap Edit schedule to enter editor
        await tester.tap(find.text('Edit schedule'));
        await tester.pumpAndSettle();

        // In review/edit mode, tap Add work block
        expect(find.text('Edit Work Schedule'), findsOneWidget);
        await tester.tap(find.text('Add work block'));
        await tester.pumpAndSettle();

        // Directly opens edit sheet for the new draft block!
        expect(find.text('ACTIVITY'), findsOneWidget);
        expect(find.text('PROFESSIONAL CONTEXT'), findsOneWidget);
        expect(find.text('SCHEDULE'), findsOneWidget);
        expect(find.text('PLACE & DETAILS'), findsOneWidget);

        // Canceling leaves canonical setup untouched
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Exit review back to Current Setup
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Existing Shift'), findsOneWidget);
        final saved = await fakeSetupRepo.fetchSetup(uid);
        expect(saved.workBlocks.length, equals(1));
      },
    );

    testWidgets(
      'BaseTimelineWorkAdapter showEditSheet organizes sections: Activity -> Professional Context -> Schedule -> Place & Details, dynamically updating labels based on context chips',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      BaseTimelineWorkAdapter.showEditSheet(
                        context: ctx,
                        block: const TimelineBlockDraft(
                          id: 'b-new',
                          section: 'work',
                          title: 'New Work Shift',
                          startMinute: 540,
                          endMinute: 600,
                          repeatDays: [1],
                          blockType: TimelineBlockDraft.hardBlockKey,
                        ),
                        onSave: (b) async => true,
                        lifeRole: 'work',
                      );
                    },
                    child: const Text('Open Editor'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Editor'));
        await tester.pumpAndSettle();

        // 1. Verify section hierarchy
        final activityFinder = find.text('ACTIVITY');
        final contextFinder = find.text('PROFESSIONAL CONTEXT');
        final scheduleFinder = find.text('SCHEDULE');
        final placeFinder = find.text('PLACE & DETAILS');

        expect(activityFinder, findsOneWidget);
        expect(contextFinder, findsOneWidget);
        expect(scheduleFinder, findsOneWidget);
        expect(placeFinder, findsOneWidget);

        // Verify vertical order
        final activityY = tester.getTopLeft(activityFinder).dy;
        final contextY = tester.getTopLeft(contextFinder).dy;
        final scheduleY = tester.getTopLeft(scheduleFinder).dy;
        final placeY = tester.getTopLeft(placeFinder).dy;

        expect(activityY, lessThan(contextY));
        expect(contextY, lessThan(scheduleY));
        expect(scheduleY, lessThan(placeY));

        // 2. Test dynamic label updates:
        // Default without context selected -> ROLE, ORGANIZATION, TEAM / PROJECT (OPTIONAL)
        expect(find.text('ROLE'), findsOneWidget);
        expect(find.text('ORGANIZATION'), findsOneWidget);
        expect(find.text('TEAM / PROJECT (OPTIONAL)'), findsOneWidget);

        // Tap Freelance chip -> CLIENT / ORGANIZATION, PROJECT (OPTIONAL)
        await tester.tap(find.text('Freelance'));
        await tester.pumpAndSettle();
        expect(find.text('YOUR ROLE'), findsOneWidget);
        expect(find.text('CLIENT / ORGANIZATION'), findsOneWidget);
        expect(find.text('PROJECT (OPTIONAL)'), findsOneWidget);

        // Tap Business chip -> BUSINESS NAME, BUSINESS AREA / PROJECT (OPTIONAL)
        await tester.tap(find.text('Business'));
        await tester.pumpAndSettle();
        expect(find.text('YOUR ROLE'), findsOneWidget);
        expect(find.text('BUSINESS NAME'), findsOneWidget);
        expect(find.text('BUSINESS AREA / PROJECT (OPTIONAL)'), findsOneWidget);
      },
    );

    testWidgets(
      'WorkReviewView renders dynamic title, compact source row, empty draft explanation, and Save changes CTA',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: WorkReviewView(
                workingBlocks: const [],
                workingAssetId: null,
                workingR2Key: null,
                workingLocalPreviewPath: null,
                selectedDay: 1,
                onDayChanged: (_) {},
                droppedCount: 0,
                droppedExamples: const [],
                errorMessage: null,
                onClearError: () {},
                isSaving: false,
                onCancel: () {},
                onScanAgain: () {},
                onEditBlock: (_) {},
                onAddBlock: () {},
                onSave: () {},
                lifeRole: 'work',
                isEditing: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Dynamic editing title
        expect(find.text('Edit Work Schedule'), findsOneWidget);

        // 2. Empty draft explanation
        expect(
          find.text(WorkPresentationUtils.emptyDraftExplanation('work')),
          findsOneWidget,
        );

        // 3. CTA says "Save changes" when isEditing: true
        expect(find.text('Save changes'), findsOneWidget);
        final saveBtn = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Save changes'),
        );
        expect(saveBtn.onPressed, isNull);
      },
    );

    test(
      'RoutineCardFactory workDetailsString includes non-job workContextType and preserves effectiveWorkDepartmentOrProject',
      () {
        final freelanceItem = RoutineItem(
          id: 'r-1',
          blockType: RoutineBlockType.hardBlock,
          title: 'Client Delivery',
          startMinute: 600,
          endMinute: 720,
          repeatDays: const [1],
          workRole: 'UX Consultant',
          workOrganization: 'Acme Studio',
          workDepartmentOrProject: 'Mobile Redesign',
          workContextType: 'freelance',
          workMode: 'remote',
        );

        final details = RoutineCardFactory.workDetailsString(freelanceItem);
        expect(details, contains('UX Consultant'));
        expect(details, contains('Acme Studio'));
        expect(details, contains('Mobile Redesign'));
        expect(details, contains('Freelance'));
        expect(details, contains('Remote'));

        const legacyBlock = TimelineBlockDraft(
          id: 'b-leg',
          section: 'work',
          title: 'Legacy Shift',
          startMinute: 540,
          endMinute: 1020,
          repeatDays: [1, 2, 3, 4, 5],
          sectionLabel: 'Engineering Platform Services',
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        expect(
          legacyBlock.effectiveWorkDepartmentOrProject,
          equals('Engineering Platform Services'),
        );
      },
    );
  });
}
