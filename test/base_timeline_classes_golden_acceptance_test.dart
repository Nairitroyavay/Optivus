import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/classes_base_setup_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_upload_lifecycle_helper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/class_schedule_draft_mapper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/classes_setup_controller.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
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

// ---------------------------------------------------------------------------
// Fakes and Test Harness Doubles
// ---------------------------------------------------------------------------

class _StubAuthRepo implements AuthRepository {
  @override
  Future<String?> currentIdToken({bool forceRefresh = false}) async =>
      'test-id-token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TrackingAssetRepo implements UploadedAssetRepository {
  final List<String> deletedAssetIds = [];
  final List<UploadedAsset> assetsToReturn = const [];

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
  }) async {
    return assetsToReturn;
  }

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

class _StubImagePrepareService implements ImagePrepareService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ControlledUploadController extends UploadController {
  UploadedAsset? assetToReturn;

  _ControlledUploadController({required super.assetRepository})
    : super(
        authRepository: _StubAuthRepo(),
        imagePrepareService: _StubImagePrepareService(),
        r2UploadClient: FakeR2UploadClient(),
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

class _ControlledAiController extends RoutineImportAiController {
  final Future<RoutineImportExtractionResult?> Function(
    RoutineImportReviewDraft,
  )
  extraction;

  _ControlledAiController(Ref ref, this.extraction)
    : super(ref, const FakeRoutineImportAiClient());

  @override
  Future<RoutineImportExtractionResult?> runExtraction(
    RoutineImportReviewDraft review,
  ) => extraction(review);
}

class _FailingRoutineRepo extends FakeRoutineRepository {
  int fetchCalls = 0;
  bool failOnFollowUp = false;

  @override
  Future<List<RoutineItem>> fetchRoutineItems(String uid) async {
    fetchCalls++;
    if (fetchCalls > 2 && failOnFollowUp) {
      throw StateError('Simulated routine network timeout on follow-up');
    }
    return super.fetchRoutineItems(uid);
  }
}

class _TestErrorSetupRepo extends FakeBaseTimelineSetupRepository {
  bool failFetch = false;

  _TestErrorSetupRepo({super.onboardingRepo});

  @override
  Future<BaseTimelineSetup> fetchSetup(String uid) async {
    if (failFetch) {
      throw StateError(
        'FirestoreException permission-denied /internal/path {secret: json}',
      );
    }
    return super.fetchSetup(uid);
  }
}

// ---------------------------------------------------------------------------
// Golden Acceptance Suite
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R4 Classes Golden Acceptance: Journey & Invariants', () {
    late FakeBaseTimelineSetupRepository setupRepo;
    late _FailingRoutineRepo routineRepo;
    late FakeRoutineTransactionRepository txRepo;
    late _TrackingAssetRepo assetRepo;
    late _TrackingR2Client r2Client;
    late BaseTimelineUploadLifecycleHelper lifecycleHelper;

    setUp(() {
      setupRepo = FakeBaseTimelineSetupRepository(
        onboardingRepo: FakeOnboardingRepository(),
      );
      routineRepo = _FailingRoutineRepo();
      txRepo = FakeRoutineTransactionRepository(
        routineRepository: routineRepo,
        setupRepository: setupRepo,
      );
      assetRepo = _TrackingAssetRepo();
      r2Client = _TrackingR2Client();
      lifecycleHelper = BaseTimelineUploadLifecycleHelper(
        assetRepository: assetRepo,
        r2UploadClient: r2Client,
        authRepository: _StubAuthRepo(),
      );
    });

    ProviderContainer createContainer({
      String uid = 'user-golden',
      BaseTimelineSetup? initialSetup,
    }) {
      if (initialSetup != null) {
        setupRepo.saveSetup(uid, initialSetup);
      }
      final container = ProviderContainer(
        overrides: [
          userProfileProvider.overrideWith(
            (ref) => UserProfileNotifier()
              ..loadSeedData(
                UserProfile(
                  uid: uid,
                  email: '$uid@optivus.app',
                  displayName: 'Golden User',
                ),
              ),
          ),
          baseTimelineSetupRepositoryProvider.overrideWithValue(setupRepo),
          routineRepositoryProvider.overrideWithValue(routineRepo),
          routineTransactionRepositoryProvider.overrideWithValue(txRepo),
          baseTimelineUploadLifecycleHelperProvider.overrideWithValue(
            lifecycleHelper,
          ),
          baseTimelineTransactionCoordinatorProvider.overrideWith(
            (ref) => BaseTimelineTransactionCoordinator(
              routineRepo: routineRepo,
              setupRepo: setupRepo,
              transactionRepo: txRepo,
              ref: ref,
            ),
          ),
        ],
      );

      return container;
    }

    testWidgets(
      '1. Canonical Load States: Loading displays skeleton, Error displays retry/back, never fake empty setup',
      (tester) async {
        final errorSetupRepo = _TestErrorSetupRepo(
          onboardingRepo: FakeOnboardingRepository(),
        );
        errorSetupRepo.failFetch = true;

        final container = ProviderContainer(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: 'user-load-test',
                    email: 'test@optivus.app',
                    displayName: 'User',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(
              errorSetupRepo,
            ),
            routineRepositoryProvider.overrideWithValue(routineRepo),
            routineTransactionRepositoryProvider.overrideWithValue(txRepo),
            baseTimelineUploadLifecycleHelperProvider.overrideWithValue(
              lifecycleHelper,
            ),
          ],
        );
        addTearDown(container.dispose);

        // Verify that in-memory state is loading initially, then error, NOT empty setup!
        expect(
          container.read(baseTimelineSetupNotifierProvider).isLoading,
          isTrue,
        );
        await tester.pump();

        final setupAsync = container.read(baseTimelineSetupNotifierProvider);
        expect(setupAsync.hasError, isTrue);
        expect(setupAsync.hasValue, isFalse);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(home: ClassesBaseSetupScreen(onBack: () {})),
          ),
        );
        await tester.pump();
        expect(
          find.textContaining("We couldn't load your Classes setup"),
          findsOneWidget,
        );
        expect(find.textContaining('FirestoreException'), findsNothing);

        // Now fix the error and call load() -> should transition to data
        errorSetupRepo.failFetch = false;
        await container.read(baseTimelineSetupNotifierProvider.notifier).load();
        await tester.pump();

        final recovered = container.read(baseTimelineSetupNotifierProvider);
        expect(recovered.hasValue, isTrue);
        expect(recovered.value, isNotNull);
      },
    );

    test(
      '2. Full Product Journey: view -> change setup -> add -> edit -> delete -> save -> restart -> projection -> remove -> account switch',
      () async {
        const uid = 'user-journey';
        final initialBlocks = [
          ClassRoutineBlock(
            id: 'cls-init-1',
            subject: 'Linear Algebra',
            startMinute: 540,
            endMinute: 600,
            repeatDays: const [1, 3, 5],
            room: 'Hall 101',
            professor: 'Dr. Gauss',
            courseCode: 'MATH201',
            classType: 'Lecture',
            section: 'Sec A',
            notes: 'Bring calculator',
          ),
        ];
        final initialDrafts = ClassScheduleDraftMapper.toTimelineDrafts(
          initialBlocks,
          section: 'classes',
          provenanceAssetId: 'asset-init-photo',
          provenanceR2Key: 'users/user-journey/classes/init.jpg',
        );
        final initialSetup = BaseTimelineSetup(
          uid: uid,
          revision: 1,
          updatedAt: DateTime.now(),
          classBlocks: initialDrafts,
          classLogicalAssetId: 'asset-init-photo',
          classLogicalAssetR2Key: 'users/user-journey/classes/init.jpg',
        );

        final container = createContainer(uid: uid, initialSetup: initialSetup);
        addTearDown(container.dispose);

        while (container.read(baseTimelineSetupNotifierProvider).isLoading) {
          await pumpEventQueue();
        }
        final controller = container.read(
          classesSetupControllerProvider.notifier,
        );
        final setup = container
            .read(baseTimelineSetupNotifierProvider)
            .requireValue;

        // Step 1: view existing with full lossless metadata
        expect(setup.classBlocks.length, 1);
        final classRoutineBlocks =
            ClassScheduleDraftMapper.toClassRoutineBlocks(setup.classBlocks);
        expect(classRoutineBlocks.first.subject, 'Linear Algebra');
        expect(classRoutineBlocks.first.room, 'Hall 101');
        expect(classRoutineBlocks.first.professor, 'Dr. Gauss');
        expect(classRoutineBlocks.first.courseCode, 'MATH201');
        expect(classRoutineBlocks.first.classType, 'Lecture');
        expect(classRoutineBlocks.first.section, 'Sec A');
        expect(classRoutineBlocks.first.notes, 'Bring calculator');
        expect(setup.classLogicalAssetId, 'asset-init-photo');

        // Startup cleanup protects committed asset
        await controller.performStartupCleanup(setup, uid: uid);
        expect(
          container.read(classesSetupControllerProvider).stage,
          ClassesSetupStage.currentSetup,
        );

        // Step 2: change setup
        controller.chooseSource(setup, uid: uid);
        expect(
          container.read(classesSetupControllerProvider).stage,
          ClassesSetupStage.chooseSource,
        );
        expect(
          container.read(classesSetupControllerProvider).editorBaseRevision,
          1,
        );

        controller.editCurrentTimetable(setup);
        expect(
          container.read(classesSetupControllerProvider).stage,
          ClassesSetupStage.review,
        );
        expect(
          container.read(classesSetupControllerProvider).workingBlocks.length,
          1,
        );
        expect(
          container.read(classesSetupControllerProvider).workingAssetId,
          'asset-init-photo',
        );

        // Step 3: add block with all 8 rich metadata fields
        final addedBlock = ClassRoutineBlock(
          id: 'cls-add-2',
          subject: 'Computer Architecture',
          room: 'Lab 4',
          professor: 'Dr. Turing',
          courseCode: 'CS301',
          classType: 'Lab',
          section: 'Sec B',
          notes: 'FPGA board needed',
          startMinute: 660,
          endMinute: 780,
          repeatDays: const [2, 4],
        );
        controller.addBlock(addedBlock);
        expect(
          container.read(classesSetupControllerProvider).workingBlocks.length,
          2,
        );
        expect(container.read(classesSetupControllerProvider).isDirty, isTrue);

        // Step 4: edit existing block
        final editedFirstBlock = ClassRoutineBlock(
          id: 'cls-init-1',
          subject: 'Linear Algebra Advanced',
          room: 'Hall 202',
          professor: 'Dr. Gauss Jr.',
          courseCode: 'MATH201A',
          classType: 'Seminar',
          section: 'Sec A1',
          notes: 'Bring laptop',
          startMinute: 600,
          endMinute: 660,
          repeatDays: const [1, 3],
        );
        controller.updateBlock(editedFirstBlock);
        expect(
          container
              .read(classesSetupControllerProvider)
              .workingBlocks
              .firstWhere((b) => b.id == 'cls-init-1')
              .subject,
          'Linear Algebra Advanced',
        );

        // Step 5: delete block in draft
        controller.addBlock(
          ClassRoutineBlock(
            id: 'cls-temp',
            subject: 'To Delete',
            startMinute: 480,
            endMinute: 540,
            repeatDays: const [5],
          ),
        );
        expect(
          container.read(classesSetupControllerProvider).workingBlocks.length,
          3,
        );
        controller.deleteBlock('cls-temp');
        expect(
          container.read(classesSetupControllerProvider).workingBlocks.length,
          2,
        );
        final setupInRepo = await setupRepo.fetchSetup(uid);
        expect(setupInRepo.classBlocks.length, 1);

        // Step 6: save
        await controller.save(uid: uid, setup: setup);
        expect(
          container.read(classesSetupControllerProvider).stage,
          ClassesSetupStage.saveSuccess,
        );
        expect(
          container.read(classesSetupControllerProvider).routineRefreshPending,
          isFalse,
        );

        final committedSetup = await setupRepo.fetchSetup(uid);
        expect(committedSetup.revision, 2);
        expect(committedSetup.classBlocks.length, 2);
        final committedBlocks = ClassScheduleDraftMapper.toClassRoutineBlocks(
          committedSetup.classBlocks,
        );
        final mathBlock = committedBlocks.firstWhere(
          (b) => b.id == 'cls-init-1',
        );
        expect(mathBlock.subject, 'Linear Algebra Advanced');
        expect(mathBlock.room, 'Hall 202');
        expect(mathBlock.professor, 'Dr. Gauss Jr.');
        expect(mathBlock.courseCode, 'MATH201A');
        expect(mathBlock.classType, 'Seminar');
        expect(mathBlock.section, 'Sec A1');
        expect(mathBlock.notes, 'Bring laptop');

        final csBlock = committedBlocks.firstWhere((b) => b.id == 'cls-add-2');
        expect(csBlock.subject, 'Computer Architecture');
        expect(csBlock.room, 'Lab 4');
        expect(csBlock.repeatDays, [2, 4]);

        // Step 7: Routine projection
        final routineItems = await routineRepo.fetchRoutineItems(uid);
        expect(routineItems.length, 2);
        expect(
          routineItems.any((i) => i.title == 'Linear Algebra Advanced'),
          isTrue,
        );
        expect(
          routineItems.any((i) => i.title == 'Computer Architecture'),
          isTrue,
        );

        controller.dismissSuccess();
        expect(
          container.read(classesSetupControllerProvider).stage,
          ClassesSetupStage.currentSetup,
        );

        // Step 8: restart / reconstruction
        final restartedContainer = createContainer(uid: uid);
        addTearDown(restartedContainer.dispose);
        while (restartedContainer
            .read(baseTimelineSetupNotifierProvider)
            .isLoading) {
          await pumpEventQueue();
        }

        final reconstructedSetup = restartedContainer
            .read(baseTimelineSetupNotifierProvider)
            .requireValue;
        expect(reconstructedSetup.revision, 2);
        expect(reconstructedSetup.classBlocks.length, 2);

        // Step 9: remove setup
        final restartController = restartedContainer.read(
          classesSetupControllerProvider.notifier,
        );
        await restartController.removeSetup(
          uid: uid,
          setup: reconstructedSetup,
        );
        expect(
          restartedContainer.read(classesSetupControllerProvider).stage,
          ClassesSetupStage.currentSetup,
        );

        final removedSetup = await setupRepo.fetchSetup(uid);
        expect(removedSetup.revision, 3);
        expect(removedSetup.classBlocks, isEmpty);
        expect(removedSetup.classLogicalAssetId, isNull);

        final itemsAfterRemove = await routineRepo.fetchRoutineItems(uid);
        expect(
          itemsAfterRemove.where(
            (i) => i.category == RoutineCategory.classBlock,
          ),
          isEmpty,
        );
        expect(assetRepo.deletedAssetIds, contains('asset-init-photo'));

        final removedRestart = createContainer(uid: uid);
        addTearDown(removedRestart.dispose);
        await removedRestart
            .read(baseTimelineSetupNotifierProvider.notifier)
            .load();
        final reconstructedRemoval = removedRestart
            .read(baseTimelineSetupNotifierProvider)
            .requireValue;
        expect(reconstructedRemoval.revision, 3);
        expect(reconstructedRemoval.classBlocks, isEmpty);
        expect(reconstructedRemoval.classLogicalAssetId, isNull);
        expect(
          (await routineRepo.fetchRoutineItems(
            uid,
          )).where((i) => i.baseTimelineSection == 'classes'),
          isEmpty,
        );

        // Step 10: account switch isolation
        final switchContainer = ProviderContainer(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: 'user-other',
                    email: 'other@optivus.app',
                    displayName: 'Other User',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(setupRepo),
            routineRepositoryProvider.overrideWithValue(routineRepo),
            routineTransactionRepositoryProvider.overrideWithValue(txRepo),
            baseTimelineUploadLifecycleHelperProvider.overrideWithValue(
              lifecycleHelper,
            ),
          ],
        );
        addTearDown(switchContainer.dispose);
        await pumpEventQueue();

        final otherController = switchContainer.read(
          classesSetupControllerProvider.notifier,
        );
        expect(otherController.ownerUid, 'user-other');
        expect(
          switchContainer.read(classesSetupControllerProvider).workingBlocks,
          isEmpty,
        );
        expect(
          switchContainer.read(classesSetupControllerProvider).stage,
          ClassesSetupStage.currentSetup,
        );
      },
    );

    test(
      '3. Optimistic Concurrency Conflict: stale base revision is rejected, marks isConcurrencyConflict, preserves draft, allows reloadFromCanonical',
      () async {
        const uid = 'user-conflict';
        final initialSetup = BaseTimelineSetup(
          uid: uid,
          revision: 1,
          updatedAt: DateTime.now(),
          classBlocks: const [
            TimelineBlockDraft(
              id: 'cls-1',
              section: 'classes',
              title: 'Physics I',
              startMinute: 600,
              endMinute: 660,
              repeatDays: [1, 3],
              blockType: 'hardBlock',
            ),
          ],
        );

        final container = createContainer(uid: uid, initialSetup: initialSetup);
        addTearDown(container.dispose);
        while (container.read(baseTimelineSetupNotifierProvider).isLoading) {
          await pumpEventQueue();
        }

        final controller = container.read(
          classesSetupControllerProvider.notifier,
        );
        final setup = container
            .read(baseTimelineSetupNotifierProvider)
            .requireValue;

        controller.editCurrentTimetable(setup);
        expect(
          container.read(classesSetupControllerProvider).editorBaseRevision,
          1,
        );

        controller.addBlock(
          ClassRoutineBlock(
            id: 'cls-draft',
            subject: 'Draft Chemistry',
            startMinute: 700,
            endMinute: 760,
            repeatDays: const [2],
          ),
        );

        // Remote concurrent edit bumps revision to 2
        final concurrentSetup = setup.copyWith(
          revision: 2,
          classBlocks: [
            ...setup.classBlocks,
            const TimelineBlockDraft(
              id: 'cls-remote-sync',
              section: 'classes',
              title: 'Biology Remote',
              startMinute: 800,
              endMinute: 860,
              repeatDays: [4],
              blockType: 'hardBlock',
            ),
          ],
        );
        await setupRepo.saveSetup(uid, concurrentSetup);

        // Save with expected revision 1 triggers conflict
        await controller.save(uid: uid, setup: setup);

        final stateAfterConflict = container.read(
          classesSetupControllerProvider,
        );
        expect(stateAfterConflict.isConcurrencyConflict, isTrue);
        expect(
          stateAfterConflict.errorMessage,
          contains('Reload the latest setup'),
        );
        expect(stateAfterConflict.workingBlocks.length, 2);
        expect(stateAfterConflict.stage, ClassesSetupStage.review);

        // Reload latest setup
        controller.reloadFromCanonical(concurrentSetup);
        final stateAfterReload = container.read(classesSetupControllerProvider);
        expect(stateAfterReload.isConcurrencyConflict, isFalse);
        expect(stateAfterReload.editorBaseRevision, 2);
        expect(stateAfterReload.workingBlocks.length, 2);
        expect(
          stateAfterReload.workingBlocks.any(
            (b) => b.subject == 'Biology Remote',
          ),
          isTrue,
        );
      },
    );

    test(
      '4. Truthful Routine Reconciliation: follow-up routine fetch failure sets routineRefreshPending and retryRoutineRefresh reconciles without rerunning save',
      () async {
        const uid = 'user-refresh-pending';
        final initialSetup = BaseTimelineSetup(
          uid: uid,
          revision: 1,
          updatedAt: DateTime.now(),
        );

        final container = createContainer(uid: uid, initialSetup: initialSetup);
        addTearDown(container.dispose);
        while (container.read(baseTimelineSetupNotifierProvider).isLoading) {
          await pumpEventQueue();
        }

        final controller = container.read(
          classesSetupControllerProvider.notifier,
        );
        final setup = container
            .read(baseTimelineSetupNotifierProvider)
            .requireValue;

        controller.startManualSetup(setup);
        controller.addBlock(
          ClassRoutineBlock(
            id: 'cls-1',
            subject: 'Algorithms',
            startMinute: 600,
            endMinute: 660,
            repeatDays: const [1],
          ),
        );

        // Follow-up fetch throws
        routineRepo.failOnFollowUp = true;

        await controller.save(uid: uid, setup: setup);

        final saveState = container.read(classesSetupControllerProvider);
        expect(saveState.stage, ClassesSetupStage.saveSuccess);
        expect(saveState.routineRefreshPending, isTrue);
        expect(saveState.committedRevision, 2);

        final currentSetup = await setupRepo.fetchSetup(uid);
        expect(currentSetup.revision, 2);

        // Retry reconciliation without re-saving BaseTimelineSetup
        await controller.retryRoutineRefresh(uid: uid);
        final failedRetry = container.read(classesSetupControllerProvider);
        expect(failedRetry.routineRefreshPending, isTrue);
        expect(
          failedRetry.routineRefreshMessage,
          "Routine couldn't refresh yet. Please try again.",
        );
        expect(
          failedRetry.routineRefreshMessage,
          isNot(contains('Simulated routine network timeout')),
        );

        routineRepo.failOnFollowUp = false;
        final currentTxRevision = currentSetup.revision;
        await controller.retryRoutineRefresh(uid: uid);

        final refreshedState = container.read(classesSetupControllerProvider);
        expect(refreshedState.routineRefreshPending, isFalse);
        final afterRetrySetup = await setupRepo.fetchSetup(uid);
        expect(afterRetrySetup.revision, currentTxRevision);
      },
    );

    test(
      '5. Validation: invalid block contract blocks save before transaction submission',
      () async {
        const uid = 'user-val';
        final initialSetup = BaseTimelineSetup(
          uid: uid,
          revision: 1,
          updatedAt: DateTime.now(),
        );

        final container = createContainer(uid: uid, initialSetup: initialSetup);
        addTearDown(container.dispose);
        while (container.read(baseTimelineSetupNotifierProvider).isLoading) {
          await pumpEventQueue();
        }

        final controller = container.read(
          classesSetupControllerProvider.notifier,
        );
        final setup = container
            .read(baseTimelineSetupNotifierProvider)
            .requireValue;

        controller.startManualSetup(setup);

        // Empty title
        controller.addBlock(
          ClassRoutineBlock(
            id: 'cls-invalid-1',
            subject: '   ',
            startMinute: 600,
            endMinute: 660,
            repeatDays: const [1],
          ),
        );
        await controller.save(uid: uid, setup: setup);
        expect(
          container.read(classesSetupControllerProvider).errorMessage,
          contains('Please enter a subject name'),
        );

        // Start >= End
        controller.deleteBlock('cls-invalid-1');
        controller.addBlock(
          ClassRoutineBlock(
            id: 'cls-invalid-2',
            subject: 'Valid Title',
            startMinute: 700,
            endMinute: 700,
            repeatDays: const [1],
          ),
        );
        await controller.save(uid: uid, setup: setup);
        expect(
          container.read(classesSetupControllerProvider).errorMessage,
          contains('earlier than end time'),
        );

        // Empty repeatDays
        controller.deleteBlock('cls-invalid-2');
        controller.addBlock(
          ClassRoutineBlock(
            id: 'cls-invalid-3',
            subject: 'Valid Title',
            startMinute: 600,
            endMinute: 660,
            repeatDays: const [],
          ),
        );
        await controller.save(uid: uid, setup: setup);
        expect(
          container.read(classesSetupControllerProvider).errorMessage,
          contains('at least one scheduled day'),
        );

        final repoSetup = await setupRepo.fetchSetup(uid);
        expect(repoSetup.revision, 1);
      },
    );

    test(
      '6. Photo A -> Photo B extraction -> durable save -> restart preserves rich Routine projection and retires A only after commit',
      () async {
        const uid = 'user-photo-golden';
        const photoAId = 'asset-photo-a';
        const photoAKey =
            'users/user-photo-golden/routineBaseTimeline/classTimetable/asset-photo-a.jpg';
        const photoBId = 'asset-photo-b';
        const photoBKey =
            'users/user-photo-golden/routineBaseTimeline/classTimetable/asset-photo-b.jpg';
        final initialSetup = BaseTimelineSetup(
          uid: uid,
          revision: 1,
          updatedAt: DateTime.now(),
          classLogicalAssetId: photoAId,
          classLogicalAssetR2Key: photoAKey,
          classBlocks: const [
            TimelineBlockDraft(
              id: 'old-class',
              section: 'classes',
              title: 'Old Timetable',
              startMinute: 540,
              endMinute: 600,
              repeatDays: [1],
              blockType: 'hardBlock',
            ),
          ],
        );
        await setupRepo.saveSetup(uid, initialSetup);

        final uploadController =
            _ControlledUploadController(
                assetRepository: FakeUploadedAssetRepository(),
              )
              ..assetToReturn = UploadedAsset(
                assetId: photoBId,
                ownerUid: uid,
                sourceFeature: UploadSourceFeature.routineBaseTimeline,
                purpose: UploadedAssetPurpose.classTimetable,
                status: UploadedAssetStatus.uploaded,
                fileName: 'asset-photo-b.jpg',
                contentType: 'image/jpeg',
                sizeBytes: 2048,
                r2Key: photoBKey,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
        final container = ProviderContainer(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: uid,
                    email: '$uid@optivus.app',
                    displayName: 'Photo User',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(setupRepo),
            routineRepositoryProvider.overrideWithValue(routineRepo),
            routineTransactionRepositoryProvider.overrideWithValue(txRepo),
            baseTimelineUploadLifecycleHelperProvider.overrideWithValue(
              lifecycleHelper,
            ),
            uploadControllerProvider.overrideWith((ref) => uploadController),
            routineImportAiControllerProvider.overrideWith(
              (ref) => _ControlledAiController(
                ref,
                (_) async => RoutineImportExtractionResult(
                  id: 'photo-b-result',
                  uid: uid,
                  source: RoutineImportReviewSource.classes,
                  createdAt: DateTime.now(),
                  candidates: [
                    RoutineImportCandidateBlock(
                      id: 'new-class',
                      title: 'Distributed Systems',
                      startMinute: 660,
                      endMinute: 750,
                      repeatDays: [2, 4],
                      blockType: 'hardBlock',
                      category: 'class',
                      hardBlock: true,
                      location: 'Lab 9',
                      instructor: 'Dr. Lamport',
                      courseCode: 'CS402',
                      classType: 'Seminar',
                      sectionLabel: 'A2',
                      notes: 'Read the paper',
                    ),
                  ],
                ),
              ),
            ),
            baseTimelineTransactionCoordinatorProvider.overrideWith(
              (ref) => BaseTimelineTransactionCoordinator(
                routineRepo: routineRepo,
                setupRepo: setupRepo,
                transactionRepo: txRepo,
                ref: ref,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        final sub = container.listen(classesSetupControllerProvider, (_, _) {});
        addTearDown(sub.close);
        await container.read(baseTimelineSetupNotifierProvider.notifier).load();

        final controller = container.read(
          classesSetupControllerProvider.notifier,
        );
        controller.chooseSource(initialSetup, uid: uid);
        await controller.pickAndUploadPhoto(
          uid: uid,
          source: ImageSource.gallery,
          setup: initialSetup,
        );

        final candidateState = container.read(classesSetupControllerProvider);
        expect(candidateState.stage, ClassesSetupStage.review);
        expect(candidateState.workingAssetId, photoBId);
        expect((await setupRepo.fetchSetup(uid)).classLogicalAssetId, photoAId);
        expect(assetRepo.deletedAssetIds, isNot(contains(photoAId)));

        await controller.save(uid: uid);
        await pumpEventQueue();
        final committed = await setupRepo.fetchSetup(uid);
        expect(committed.revision, 2);
        expect(committed.classLogicalAssetId, photoBId);
        expect(committed.classLogicalAssetR2Key, photoBKey);
        expect(committed.classBlocks.single.title, 'Distributed Systems');
        expect(assetRepo.deletedAssetIds, contains(photoAId));

        final projected = (await routineRepo.fetchRoutineItems(uid)).single;
        expect(projected.source, RoutineSource.baseTimeline);
        expect(projected.baseTimelineSection, 'classes');
        expect(projected.title, 'Distributed Systems');
        expect(projected.startMinute, 660);
        expect(projected.endMinute, 750);
        expect(projected.repeatDays, [2, 4]);
        expect(projected.professor, 'Dr. Lamport');
        expect(projected.courseCode, 'CS402');
        expect(projected.classType, 'Seminar');
        expect(projected.sectionLabel, 'A2');
        expect(projected.notes, 'Read the paper');

        final restarted = createContainer(uid: uid);
        addTearDown(restarted.dispose);
        await restarted.read(baseTimelineSetupNotifierProvider.notifier).load();
        final reconstructed = restarted
            .read(baseTimelineSetupNotifierProvider)
            .requireValue;
        expect(reconstructed.classLogicalAssetId, photoBId);
        expect(reconstructed.classBlocks.single.title, 'Distributed Systems');
        expect(
          (await routineRepo.fetchRoutineItems(uid)).single.baseTimelineSection,
          'classes',
        );
      },
    );

    test(
      '7. Photo replacement save failure retains B for retry; discard retires B without changing canonical A',
      () async {
        const uid = 'user-photo-failure';
        const photoAId = 'failure-photo-a';
        const photoBId = 'failure-photo-b';
        const photoBKey =
            'users/user-photo-failure/routineBaseTimeline/classTimetable/failure-photo-b.jpg';
        final initialSetup = BaseTimelineSetup(
          uid: uid,
          revision: 1,
          updatedAt: DateTime.now(),
          classLogicalAssetId: photoAId,
          classLogicalAssetR2Key: 'photo-a-key',
        );
        await setupRepo.saveSetup(uid, initialSetup);
        final uploadController =
            _ControlledUploadController(
                assetRepository: FakeUploadedAssetRepository(),
              )
              ..assetToReturn = UploadedAsset(
                assetId: photoBId,
                ownerUid: uid,
                sourceFeature: UploadSourceFeature.routineBaseTimeline,
                purpose: UploadedAssetPurpose.classTimetable,
                status: UploadedAssetStatus.uploaded,
                fileName: 'failure-photo-b.jpg',
                contentType: 'image/jpeg',
                sizeBytes: 1024,
                r2Key: photoBKey,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
        final container = ProviderContainer(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: uid,
                    email: '$uid@test.dev',
                    displayName: 'Failure',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(setupRepo),
            routineRepositoryProvider.overrideWithValue(routineRepo),
            routineTransactionRepositoryProvider.overrideWithValue(txRepo),
            baseTimelineUploadLifecycleHelperProvider.overrideWithValue(
              lifecycleHelper,
            ),
            uploadControllerProvider.overrideWith((ref) => uploadController),
            routineImportAiControllerProvider.overrideWith(
              (ref) => _ControlledAiController(
                ref,
                (_) async => RoutineImportExtractionResult(
                  id: 'failure-result',
                  uid: uid,
                  source: RoutineImportReviewSource.classes,
                  createdAt: DateTime.now(),
                  candidates: [
                    RoutineImportCandidateBlock(
                      id: 'failure-class',
                      title: 'Networks',
                      startMinute: 600,
                      endMinute: 660,
                      repeatDays: [3],
                      blockType: 'hardBlock',
                      category: 'class',
                      hardBlock: true,
                    ),
                  ],
                ),
              ),
            ),
            baseTimelineTransactionCoordinatorProvider.overrideWith(
              (ref) => BaseTimelineTransactionCoordinator(
                routineRepo: routineRepo,
                setupRepo: setupRepo,
                transactionRepo: txRepo,
                ref: ref,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        final sub = container.listen(classesSetupControllerProvider, (_, _) {});
        addTearDown(sub.close);
        final controller = container.read(
          classesSetupControllerProvider.notifier,
        );
        controller.chooseSource(initialSetup, uid: uid);
        await controller.pickAndUploadPhoto(
          uid: uid,
          source: ImageSource.gallery,
          setup: initialSetup,
        );

        txRepo.onBeforeMutation = () async =>
            throw StateError('internal transaction dump');
        await controller.save(uid: uid);
        final failed = container.read(classesSetupControllerProvider);
        expect(failed.stage, ClassesSetupStage.review);
        expect(failed.workingAssetId, photoBId);
        expect(failed.workingBlocks.single.subject, 'Networks');
        expect(
          failed.errorMessage,
          isNot(contains('internal transaction dump')),
        );
        expect((await setupRepo.fetchSetup(uid)).classLogicalAssetId, photoAId);
        expect(assetRepo.deletedAssetIds, isNot(contains(photoAId)));

        await controller.resetWorkingDraft(initialSetup, uid: uid);
        await pumpEventQueue();
        expect((await setupRepo.fetchSetup(uid)).revision, 1);
        expect((await setupRepo.fetchSetup(uid)).classLogicalAssetId, photoAId);
        expect(assetRepo.deletedAssetIds, contains(photoBId));
        expect(assetRepo.deletedAssetIds, isNot(contains(photoAId)));
      },
    );

    test(
      '8. Same-container A -> B -> A recreates owner state and reconstructs only durable setup; startup cleanup is per owner',
      () async {
        const uidA = 'live-owner-a';
        const uidB = 'live-owner-b';
        final setupA = BaseTimelineSetup(
          uid: uidA,
          revision: 1,
          updatedAt: DateTime.now(),
          classLogicalAssetId: 'photo-a',
          classBlocks: const [
            TimelineBlockDraft(
              id: 'a-class',
              section: 'classes',
              title: 'Operating Systems',
              startMinute: 600,
              endMinute: 660,
              repeatDays: [1],
              blockType: 'hardBlock',
            ),
          ],
        );
        final setupB = BaseTimelineSetup(
          uid: uidB,
          revision: 4,
          updatedAt: DateTime.now(),
          classLogicalAssetId: 'photo-b',
          classBlocks: const [
            TimelineBlockDraft(
              id: 'b-class',
              section: 'classes',
              title: 'Networks',
              startMinute: 700,
              endMinute: 760,
              repeatDays: [2],
              blockType: 'hardBlock',
            ),
          ],
        );
        await setupRepo.saveSetup(uidA, setupA);
        await setupRepo.saveSetup(uidB, setupB);
        final container = createContainer(uid: uidA);
        addTearDown(container.dispose);
        final sub = container.listen(classesSetupControllerProvider, (_, _) {});
        addTearDown(sub.close);
        await container.read(baseTimelineSetupNotifierProvider.notifier).load();

        final controllerA = container.read(
          classesSetupControllerProvider.notifier,
        );
        await controllerA.performStartupCleanup(setupA, uid: uidA);
        controllerA.editCurrentTimetable(setupA);
        controllerA.addBlock(
          ClassRoutineBlock(
            id: 'unsaved-a',
            subject: 'Unsaved A',
            startMinute: 800,
            endMinute: 860,
            repeatDays: [3],
          ),
        );
        expect(
          container.read(classesSetupControllerProvider).hasRunStartupCleanup,
          isTrue,
        );

        container
            .read(userProfileProvider.notifier)
            .updateProfile(
              UserProfile(uid: uidB, email: '$uidB@test.dev', displayName: 'B'),
            );
        await pumpEventQueue();
        final controllerB = container.read(
          classesSetupControllerProvider.notifier,
        );
        final stateB = container.read(classesSetupControllerProvider);
        expect(controllerB.ownerUid, uidB);
        expect(stateB.workingBlocks, isEmpty);
        expect(stateB.candidateAssetId, isNull);
        expect(stateB.errorMessage, isNull);
        expect(stateB.routineRefreshPending, isFalse);
        expect(stateB.frontBlockId, isNull);
        expect(stateB.hasRunStartupCleanup, isFalse);
        await container.read(baseTimelineSetupNotifierProvider.notifier).load();
        expect(
          container
              .read(baseTimelineSetupNotifierProvider)
              .requireValue
              .classBlocks
              .single
              .title,
          'Networks',
        );
        await controllerB.performStartupCleanup(setupB, uid: uidB);
        expect(
          container.read(classesSetupControllerProvider).hasRunStartupCleanup,
          isTrue,
        );

        container
            .read(userProfileProvider.notifier)
            .updateProfile(
              UserProfile(uid: uidA, email: '$uidA@test.dev', displayName: 'A'),
            );
        await pumpEventQueue();
        await container.read(baseTimelineSetupNotifierProvider.notifier).load();
        final returnedA = container
            .read(baseTimelineSetupNotifierProvider)
            .requireValue;
        expect(
          container.read(classesSetupControllerProvider.notifier).ownerUid,
          uidA,
        );
        expect(
          container.read(classesSetupControllerProvider).workingBlocks,
          isEmpty,
        );
        expect(returnedA.classBlocks.single.title, 'Operating Systems');
      },
    );

    test(
      '9. Account switch during photo extraction ignores A result, leaves B untouched, and retires A candidate',
      () async {
        const uidA = 'photo-switch-a';
        const uidB = 'photo-switch-b';
        final extraction = Completer<RoutineImportExtractionResult?>();
        final setupA = BaseTimelineSetup(
          uid: uidA,
          revision: 1,
          updatedAt: DateTime.now(),
        );
        await setupRepo.saveSetup(uidA, setupA);
        final uploadController =
            _ControlledUploadController(
                assetRepository: FakeUploadedAssetRepository(),
              )
              ..assetToReturn = UploadedAsset(
                assetId: 'switch-candidate-a',
                ownerUid: uidA,
                sourceFeature: UploadSourceFeature.routineBaseTimeline,
                purpose: UploadedAssetPurpose.classTimetable,
                status: UploadedAssetStatus.uploaded,
                fileName: 'switch-a.jpg',
                contentType: 'image/jpeg',
                sizeBytes: 512,
                r2Key: 'switch-a-key',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
        final container = ProviderContainer(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: uidA,
                    email: '$uidA@test.dev',
                    displayName: 'A',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(setupRepo),
            routineRepositoryProvider.overrideWithValue(routineRepo),
            routineTransactionRepositoryProvider.overrideWithValue(txRepo),
            baseTimelineUploadLifecycleHelperProvider.overrideWithValue(
              lifecycleHelper,
            ),
            uploadControllerProvider.overrideWith((ref) => uploadController),
            routineImportAiControllerProvider.overrideWith(
              (ref) => _ControlledAiController(ref, (_) => extraction.future),
            ),
            baseTimelineTransactionCoordinatorProvider.overrideWith(
              (ref) => BaseTimelineTransactionCoordinator(
                routineRepo: routineRepo,
                setupRepo: setupRepo,
                transactionRepo: txRepo,
                ref: ref,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        final sub = container.listen(classesSetupControllerProvider, (_, _) {});
        addTearDown(sub.close);
        final controllerA = container.read(
          classesSetupControllerProvider.notifier,
        );
        controllerA.chooseSource(setupA, uid: uidA);
        final pending = controllerA.pickAndUploadPhoto(
          uid: uidA,
          source: ImageSource.gallery,
          setup: setupA,
        );
        await pumpEventQueue();
        expect(
          container.read(classesSetupControllerProvider).stage,
          ClassesSetupStage.extracting,
        );

        container
            .read(userProfileProvider.notifier)
            .updateProfile(
              UserProfile(uid: uidB, email: '$uidB@test.dev', displayName: 'B'),
            );
        await pumpEventQueue();
        extraction.complete(
          RoutineImportExtractionResult(
            id: 'late-a',
            uid: uidA,
            source: RoutineImportReviewSource.classes,
            createdAt: DateTime.now(),
            candidates: [
              RoutineImportCandidateBlock(
                id: 'late-class-a',
                title: 'Must Not Leak',
                startMinute: 600,
                endMinute: 660,
                repeatDays: [1],
                blockType: 'hardBlock',
                category: 'class',
                hardBlock: true,
              ),
            ],
          ),
        );
        await pending;
        await pumpEventQueue();

        final stateB = container.read(classesSetupControllerProvider);
        expect(
          container.read(classesSetupControllerProvider.notifier).ownerUid,
          uidB,
        );
        expect(stateB.workingBlocks, isEmpty);
        expect(stateB.candidateAssetId, isNull);
        expect(stateB.errorMessage, isNull);
        expect(assetRepo.deletedAssetIds, contains('switch-candidate-a'));
      },
    );

    test(
      '10. Account switch during successful Save/Remove and failed Save keeps A durability truthful without publishing into B',
      () async {
        const uidA = 'transaction-switch-a';
        const uidB = 'transaction-switch-b';
        final setupA = BaseTimelineSetup(
          uid: uidA,
          revision: 1,
          updatedAt: DateTime.now(),
          classBlocks: const [
            TimelineBlockDraft(
              id: 'existing-a',
              section: 'classes',
              title: 'Existing A',
              startMinute: 500,
              endMinute: 560,
              repeatDays: [1],
              blockType: 'hardBlock',
            ),
          ],
        );
        final setupB = BaseTimelineSetup(
          uid: uidB,
          revision: 7,
          updatedAt: DateTime.now(),
          classBlocks: const [
            TimelineBlockDraft(
              id: 'existing-b',
              section: 'classes',
              title: 'Networks B',
              startMinute: 700,
              endMinute: 760,
              repeatDays: [2],
              blockType: 'hardBlock',
            ),
          ],
        );
        await setupRepo.saveSetup(uidA, setupA);
        await setupRepo.saveSetup(uidB, setupB);
        final container = createContainer(uid: uidA);
        addTearDown(container.dispose);
        final sub = container.listen(classesSetupControllerProvider, (_, _) {});
        addTearDown(sub.close);

        var entered = Completer<void>();
        var release = Completer<void>();
        txRepo.onBeforeMutation = () async {
          entered.complete();
          await release.future;
        };
        final controllerA = container.read(
          classesSetupControllerProvider.notifier,
        );
        controllerA.editCurrentTimetable(setupA);
        controllerA.addBlock(
          ClassRoutineBlock(
            id: 'saved-a',
            subject: 'Durable A',
            startMinute: 600,
            endMinute: 660,
            repeatDays: [3],
          ),
        );
        final saveFuture = controllerA.save(uid: uidA);
        await entered.future;
        container
            .read(userProfileProvider.notifier)
            .updateProfile(
              UserProfile(uid: uidB, email: '$uidB@test.dev', displayName: 'B'),
            );
        await pumpEventQueue();
        release.complete();
        await saveFuture;
        expect((await setupRepo.fetchSetup(uidA)).revision, 2);
        expect(
          (await setupRepo.fetchSetup(
            uidA,
          )).classBlocks.any((b) => b.title == 'Durable A'),
          isTrue,
        );
        expect(
          (await setupRepo.fetchSetup(uidB)).classBlocks.single.title,
          'Networks B',
        );
        expect(
          container.read(classesSetupControllerProvider).errorMessage,
          isNull,
        );

        container
            .read(userProfileProvider.notifier)
            .updateProfile(
              UserProfile(uid: uidA, email: '$uidA@test.dev', displayName: 'A'),
            );
        await pumpEventQueue();
        final committedA = await setupRepo.fetchSetup(uidA);
        entered = Completer<void>();
        release = Completer<void>();
        final removeControllerA = container.read(
          classesSetupControllerProvider.notifier,
        );
        final removeFuture = removeControllerA.removeSetup(
          uid: uidA,
          setup: committedA,
        );
        final duplicateRemove = removeControllerA.removeSetup(
          uid: uidA,
          setup: committedA,
        );
        await duplicateRemove;
        await entered.future;
        container
            .read(userProfileProvider.notifier)
            .updateProfile(
              UserProfile(uid: uidB, email: '$uidB@test.dev', displayName: 'B'),
            );
        await pumpEventQueue();
        release.complete();
        await removeFuture;
        final removedA = await setupRepo.fetchSetup(uidA);
        expect(removedA.revision, 3);
        expect(removedA.classBlocks, isEmpty);
        expect(
          (await setupRepo.fetchSetup(uidB)).classBlocks.single.title,
          'Networks B',
        );
        expect(
          container.read(classesSetupControllerProvider).workingBlocks,
          isEmpty,
        );
        expect(
          container.read(classesSetupControllerProvider).errorMessage,
          isNull,
        );

        // A failed old-owner Save must also remain local-state silent in B.
        container
            .read(userProfileProvider.notifier)
            .updateProfile(
              UserProfile(uid: uidA, email: '$uidA@test.dev', displayName: 'A'),
            );
        await pumpEventQueue();
        entered = Completer<void>();
        release = Completer<void>();
        txRepo.onBeforeMutation = () async {
          entered.complete();
          await release.future;
          throw StateError('private A transaction failure');
        };
        final failedSaveController = container.read(
          classesSetupControllerProvider.notifier,
        );
        failedSaveController.startManualSetup(removedA);
        failedSaveController.addBlock(
          ClassRoutineBlock(
            id: 'failed-a',
            subject: 'Failed A',
            startMinute: 800,
            endMinute: 860,
            repeatDays: const [4],
          ),
        );
        final failedSave = failedSaveController.save(uid: uidA);
        await entered.future;
        container
            .read(userProfileProvider.notifier)
            .updateProfile(
              UserProfile(uid: uidB, email: '$uidB@test.dev', displayName: 'B'),
            );
        await pumpEventQueue();
        release.complete();
        await failedSave;
        expect((await setupRepo.fetchSetup(uidA)).revision, 3);
        expect((await setupRepo.fetchSetup(uidA)).classBlocks, isEmpty);
        expect(
          container.read(classesSetupControllerProvider).errorMessage,
          isNull,
        );
      },
    );

    testWidgets(
      '11. UI Golden Flow: Widget renders header, photo card, timeline, error banners, and conflict reload button',
      (tester) async {
        const uid = 'user-ui-golden';
        final initialSetup = BaseTimelineSetup(
          uid: uid,
          revision: 1,
          updatedAt: DateTime.now(),
          classLogicalAssetId: 'asset-ui-photo',
          classLogicalAssetR2Key: 'users/user-ui-golden/classes/photo.jpg',
          classBlocks: const [
            TimelineBlockDraft(
              id: 'cls-ui-1',
              section: 'classes',
              title: 'Operating Systems',
              startMinute: 600,
              endMinute: 660,
              repeatDays: [1, 3],
              blockType: 'hardBlock',
            ),
          ],
        );

        final container = createContainer(uid: uid, initialSetup: initialSetup);
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(home: ClassesBaseSetupScreen(onBack: () {})),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Classes'), findsOneWidget);
        expect(find.text('Edit schedule'), findsNothing);
        expect(
          find.byKey(const Key('base-timeline-header-edit-schedule-button')),
          findsOneWidget,
        );
        expect(find.text('Operating Systems'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.more_vert_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Change source'));
        await tester.pumpAndSettle();

        expect(find.text('Choose from gallery'), findsOneWidget);
        expect(find.text('Take a photo'), findsOneWidget);
        expect(find.text('Edit current timetable'), findsOneWidget);

        await tester.tap(find.text('Edit current timetable'));
        await tester.pumpAndSettle();

        expect(find.text('Review Timetable'), findsOneWidget);
        // Editing an existing configured timetable shows 'Save changes'
        expect(find.text('Save changes'), findsOneWidget);
      },
    );
  });
}
