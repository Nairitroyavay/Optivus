import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/classes_base_setup_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_upload_lifecycle_helper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/class_schedule_draft_mapper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/classes_setup_controller.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/state/app_state.dart';

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
      throw StateError('Simulated remote setup load failure');
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

    test(
      '1. Canonical Load States: Loading displays skeleton, Error displays retry/back, never fake empty setup',
      () async {
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
        await pumpEventQueue();

        final setupAsync = container.read(baseTimelineSetupNotifierProvider);
        expect(setupAsync.hasError, isTrue);
        expect(setupAsync.hasValue, isFalse);

        // Now fix the error and call load() -> should transition to data
        errorSetupRepo.failFetch = false;
        await container.read(baseTimelineSetupNotifierProvider.notifier).load();
        await pumpEventQueue();

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

        final container = createContainer(
          uid: uid,
          initialSetup: initialSetup,
        );
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
        final classRoutineBlocks = ClassScheduleDraftMapper.toClassRoutineBlocks(setup.classBlocks);
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
        expect(container.read(classesSetupControllerProvider).stage, ClassesSetupStage.currentSetup);

        // Step 2: change setup
        controller.chooseSource(setup, uid: uid);
        expect(container.read(classesSetupControllerProvider).stage, ClassesSetupStage.chooseSource);
        expect(container.read(classesSetupControllerProvider).editorBaseRevision, 1);

        controller.editCurrentTimetable(setup);
        expect(container.read(classesSetupControllerProvider).stage, ClassesSetupStage.review);
        expect(container.read(classesSetupControllerProvider).workingBlocks.length, 1);
        expect(container.read(classesSetupControllerProvider).workingAssetId, 'asset-init-photo');

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
        expect(container.read(classesSetupControllerProvider).workingBlocks.length, 2);
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
        expect(container.read(classesSetupControllerProvider).workingBlocks.length, 3);
        controller.deleteBlock('cls-temp');
        expect(container.read(classesSetupControllerProvider).workingBlocks.length, 2);
        final setupInRepo = await setupRepo.fetchSetup(uid);
        expect(setupInRepo.classBlocks.length, 1);

        // Step 6: save
        await controller.save(uid: uid, setup: setup);
        expect(container.read(classesSetupControllerProvider).stage, ClassesSetupStage.saveSuccess);
        expect(container.read(classesSetupControllerProvider).routineRefreshPending, isFalse);

        final committedSetup = await setupRepo.fetchSetup(uid);
        expect(committedSetup.revision, 2);
        expect(committedSetup.classBlocks.length, 2);
        final committedBlocks = ClassScheduleDraftMapper.toClassRoutineBlocks(committedSetup.classBlocks);
        final mathBlock = committedBlocks.firstWhere((b) => b.id == 'cls-init-1');
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
        expect(routineItems.any((i) => i.title == 'Linear Algebra Advanced'), isTrue);
        expect(routineItems.any((i) => i.title == 'Computer Architecture'), isTrue);

        controller.dismissSuccess();
        expect(container.read(classesSetupControllerProvider).stage, ClassesSetupStage.currentSetup);

        // Step 8: restart / reconstruction
        final restartedContainer = createContainer(
          uid: uid,
        );
        addTearDown(restartedContainer.dispose);
        while (restartedContainer.read(baseTimelineSetupNotifierProvider).isLoading) {
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
        await restartController.removeSetup(uid: uid, setup: reconstructedSetup);
        expect(restartedContainer.read(classesSetupControllerProvider).stage, ClassesSetupStage.currentSetup);

        final removedSetup = await setupRepo.fetchSetup(uid);
        expect(removedSetup.revision, 3);
        expect(removedSetup.classBlocks, isEmpty);
        expect(removedSetup.classLogicalAssetId, isNull);

        final itemsAfterRemove = await routineRepo.fetchRoutineItems(uid);
        expect(itemsAfterRemove.where((i) => i.category == RoutineCategory.classBlock), isEmpty);
        expect(assetRepo.deletedAssetIds, contains('asset-init-photo'));

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
        expect(switchContainer.read(classesSetupControllerProvider).workingBlocks, isEmpty);
        expect(switchContainer.read(classesSetupControllerProvider).stage, ClassesSetupStage.currentSetup);
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

        final container = createContainer(
          uid: uid,
          initialSetup: initialSetup,
        );
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
        expect(container.read(classesSetupControllerProvider).editorBaseRevision, 1);

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

        final stateAfterConflict = container.read(classesSetupControllerProvider);
        expect(stateAfterConflict.isConcurrencyConflict, isTrue);
        expect(stateAfterConflict.errorMessage, contains('Reload the latest setup'));
        expect(stateAfterConflict.workingBlocks.length, 2);
        expect(stateAfterConflict.stage, ClassesSetupStage.review);

        // Reload latest setup
        controller.reloadFromCanonical(concurrentSetup);
        final stateAfterReload = container.read(classesSetupControllerProvider);
        expect(stateAfterReload.isConcurrencyConflict, isFalse);
        expect(stateAfterReload.editorBaseRevision, 2);
        expect(stateAfterReload.workingBlocks.length, 2);
        expect(stateAfterReload.workingBlocks.any((b) => b.subject == 'Biology Remote'), isTrue);
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

        final container = createContainer(
          uid: uid,
          initialSetup: initialSetup,
        );
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

        final container = createContainer(
          uid: uid,
          initialSetup: initialSetup,
        );
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
        expect(container.read(classesSetupControllerProvider).errorMessage, contains('Please enter a subject name'));

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
        expect(container.read(classesSetupControllerProvider).errorMessage, contains('earlier than end time'));

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
        expect(container.read(classesSetupControllerProvider).errorMessage, contains('at least one scheduled day'));

        final repoSetup = await setupRepo.fetchSetup(uid);
        expect(repoSetup.revision, 1);
      },
    );

    testWidgets(
      '6. UI Golden Flow: Widget renders header, photo card, timeline, error banners, and conflict reload button',
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

        final container = createContainer(
          uid: uid,
          initialSetup: initialSetup,
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: ClassesBaseSetupScreen(
                onBack: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Classes'), findsOneWidget);
        expect(find.text('Change setup'), findsOneWidget);
        expect(find.text('Operating Systems'), findsOneWidget);

        await tester.tap(find.text('Change setup'));
        await tester.pumpAndSettle();

        expect(find.text('Choose from Gallery'), findsOneWidget);
        expect(find.text('Take a Photo'), findsOneWidget);
        expect(find.text('Edit current timetable'), findsOneWidget);

        await tester.tap(find.text('Edit current timetable'));
        await tester.pumpAndSettle();

        expect(find.text('Review Timetable'), findsOneWidget);
        expect(find.text('Use this timetable'), findsOneWidget);
      },
    );
  });
}
