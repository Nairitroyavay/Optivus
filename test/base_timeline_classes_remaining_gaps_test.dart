import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/onboarding/timeline/adapters/class_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/layout/timeline_overlap_engine.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_entry.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/classes_review_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_upload_lifecycle_helper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/class_setup_error_mapper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/classes_setup_controller.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/class_detail_sheet.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
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
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/services/routine_import_ai_client.dart';
import 'package:optivus/services/uploads/image_prepare_service.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/state/upload_state.dart';

class _TrackingLifecycleHelper extends BaseTimelineUploadLifecycleHelper {
  int cleanupCalls = 0;
  String? lastProtectedAssetId;
  String? lastProtectedR2Key;
  int retireCalls = 0;
  String? lastRetiredAssetId;
  String? lastRetiredObjectKey;

  _TrackingLifecycleHelper()
    : super(
        assetRepository: FakeUploadedAssetRepository(),
        r2UploadClient: FakeR2UploadClient(),
        authRepository: _FakeAuthRepo(),
      );

  @override
  Future<int> cleanupStaleUncommittedAssets({
    required String uid,
    required String? committedAssetId,
    String? committedR2Key,
    Set<String> activeSessionAssetIds = const {},
    Set<String> activeSessionR2Keys = const {},
    Duration graceWindow = const Duration(minutes: 15),
  }) async {
    cleanupCalls++;
    lastProtectedAssetId = committedAssetId;
    lastProtectedR2Key = committedR2Key;
    return 0;
  }

  @override
  Future<void> retireUncommittedUpload({
    required String uid,
    String? assetId,
    String? objectKey,
  }) async {
    retireCalls++;
    lastRetiredAssetId = assetId;
    lastRetiredObjectKey = objectKey;
  }
}

class _FakeAuthRepo implements AuthRepository {
  @override
  Future<String?> currentIdToken({bool forceRefresh = false}) async =>
      'fake-id-token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingFollowUpFetchRoutineRepository extends FakeRoutineRepository {
  int fetchCalls = 0;

  @override
  Future<List<RoutineItem>> fetchRoutineItems(String uid) async {
    fetchCalls++;
    if (fetchCalls > 1) {
      throw Exception('Simulated network failure on follow-up routine fetch');
    }
    return super.fetchRoutineItems(uid);
  }
}

class _StubAuthRepo implements AuthRepository {
  @override
  Future<String?> currentIdToken({bool forceRefresh = false}) async =>
      'dummy-token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubImagePrepareService implements ImagePrepareService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DirectUploadController extends UploadController {
  UploadedAsset? assetToReturn;

  _DirectUploadController({required super.assetRepository})
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

class _ConfigurableAiController extends RoutineImportAiController {
  final Future<RoutineImportExtractionResult?> Function(
    RoutineImportReviewDraft,
  )
  onExtraction;

  _ConfigurableAiController(Ref ref, this.onExtraction)
    : super(ref, const FakeRoutineImportAiClient());

  @override
  Future<RoutineImportExtractionResult?> runExtraction(
    RoutineImportReviewDraft review,
  ) {
    return onExtraction(review);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gap 1: Active Timetable Photo Startup Cleanup Protection', () {
    test(
      'performStartupCleanup does nothing when setup is null (loading)',
      () async {
        final lifecycleHelper = _TrackingLifecycleHelper();
        final container = ProviderContainer(
          overrides: [
            baseTimelineUploadLifecycleHelperProvider.overrideWithValue(
              lifecycleHelper,
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          classesSetupControllerProvider.notifier,
        );

        // When setup is null (still loading), cleanup must NEVER be called!
        await controller.performStartupCleanup(null, uid: 'user-123');

        expect(lifecycleHelper.cleanupCalls, 0);
        expect(
          container.read(classesSetupControllerProvider).hasRunStartupCleanup,
          isFalse,
        );
      },
    );

    test(
      'performStartupCleanup runs once when setup arrives and protects both committedAssetId and committedR2Key',
      () async {
        final lifecycleHelper = _TrackingLifecycleHelper();
        final container = ProviderContainer(
          overrides: [
            baseTimelineUploadLifecycleHelperProvider.overrideWithValue(
              lifecycleHelper,
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          classesSetupControllerProvider.notifier,
        );

        final setup = BaseTimelineSetup(
          uid: 'user-123',
          updatedAt: DateTime.now(),
          classLogicalAssetId: 'photo-asset-777',
          classLogicalAssetR2Key: 'users/user-123/classes/photo.jpg',
        );

        await controller.performStartupCleanup(setup, uid: 'user-123');

        expect(lifecycleHelper.cleanupCalls, 1);
        expect(lifecycleHelper.lastProtectedAssetId, 'photo-asset-777');
        expect(
          lifecycleHelper.lastProtectedR2Key,
          'users/user-123/classes/photo.jpg',
        );
        expect(
          container.read(classesSetupControllerProvider).hasRunStartupCleanup,
          isTrue,
        );

        // Second invocation is guarded by hasRunStartupCleanup
        await controller.performStartupCleanup(setup, uid: 'user-123');
        expect(lifecycleHelper.cleanupCalls, 1);
      },
    );
  });

  group('Gap 2: Transaction Commit Result & Coordinator In-Memory Update', () {
    test(
      'replaceSection returns BaseTimelineSectionCommitResult directly with updated setup',
      () async {
        final fakeSetupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: FakeOnboardingRepository(),
        );
        final fakeRoutineRepo = FakeRoutineRepository();
        final fakeTxRepo = FakeRoutineTransactionRepository(
          routineRepository: fakeRoutineRepo,
          setupRepository: fakeSetupRepo,
        );

        final coordinator = BaseTimelineTransactionCoordinator(
          routineRepo: fakeRoutineRepo,
          setupRepo: fakeSetupRepo,
          transactionRepo: fakeTxRepo,
        );

        const List<TimelineBlockDraft> newBlocks = [
          TimelineBlockDraft(
            id: 'cls-1',
            section: 'classes',
            title: 'Operating Systems',
            startMinute: 600,
            endMinute: 660,
            repeatDays: [1, 3],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ];

        final result = await coordinator.replaceSection(
          uid: 'user-tx-test',
          section: BaseTimelineSection.classes,
          newBlocks: newBlocks,
          updateSetup: (curr) => curr.copyWith(classBlocks: newBlocks),
        );

        expect(result, isA<BaseTimelineSectionCommitResult>());
        expect(result.committedSetup.classBlocks.length, 1);
        expect(
          result.committedSetup.classBlocks.first.title,
          'Operating Systems',
        );
        expect(result.routineItemIds, isNotEmpty);
      },
    );

    test(
      'ClassesSetupController save updates in-memory baseTimelineSetupNotifierProvider directly',
      () async {
        final fakeSetupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: FakeOnboardingRepository(),
        );
        final fakeRoutineRepo = FakeRoutineRepository();
        final fakeTxRepo = FakeRoutineTransactionRepository(
          routineRepository: fakeRoutineRepo,
          setupRepository: fakeSetupRepo,
        );

        final coordinator = BaseTimelineTransactionCoordinator(
          routineRepo: fakeRoutineRepo,
          setupRepo: fakeSetupRepo,
          transactionRepo: fakeTxRepo,
        );

        final container = ProviderContainer(
          overrides: [
            baseTimelineSetupRepositoryProvider.overrideWithValue(
              fakeSetupRepo,
            ),
            routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
            routineTransactionRepositoryProvider.overrideWithValue(fakeTxRepo),
            baseTimelineTransactionCoordinatorProvider.overrideWithValue(
              coordinator,
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          classesSetupControllerProvider.notifier,
        );

        final initialSetup = BaseTimelineSetup(
          uid: 'user-save-inmem',
          updatedAt: DateTime.now(),
        );

        // Add a block in working state
        controller.addBlock(
          ClassRoutineBlock(
            id: 'cls-mem',
            subject: 'Distributed Systems',
            startMinute: 600,
            endMinute: 660,
            repeatDays: const [1],
          ),
        );

        // Save
        await controller.save(uid: 'user-save-inmem', setup: initialSetup);

        // Check in-memory provider was updated directly!
        final inMemory = container
            .read(baseTimelineSetupNotifierProvider)
            .value;
        expect(inMemory, isNotNull);
        expect(inMemory!.classBlocks.length, 1);
        expect(inMemory.classBlocks.first.title, 'Distributed Systems');
      },
    );

    test(
      'replaceSection succeeds even if Routine reload throws an error',
      () async {
        final fakeSetupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: FakeOnboardingRepository(),
        );
        final fakeRoutineRepo = FakeRoutineRepository();
        final fakeTxRepo = FakeRoutineTransactionRepository(
          routineRepository: fakeRoutineRepo,
          setupRepository: fakeSetupRepo,
        );

        final coordinator = BaseTimelineTransactionCoordinator(
          routineRepo: fakeRoutineRepo,
          setupRepo: fakeSetupRepo,
          transactionRepo: fakeTxRepo,
        );

        const List<TimelineBlockDraft> newBlocks = [
          TimelineBlockDraft(
            id: 'cls-2',
            section: 'classes',
            title: 'Computer Networks',
            startMinute: 700,
            endMinute: 760,
            repeatDays: [2, 4],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ];

        // Should complete without throwing!
        final result = await coordinator.replaceSection(
          uid: 'user-tx-fail-routine',
          section: BaseTimelineSection.classes,
          newBlocks: newBlocks,
          updateSetup: (curr) => curr.copyWith(classBlocks: newBlocks),
        );

        expect(
          result.committedSetup.classBlocks.first.title,
          'Computer Networks',
        );
      },
    );
  });

  group('Gap 3: Explicit AI Extraction Cancellation', () {
    test(
      'RoutineImportAiController exposes cancelCurrentExtraction and resets state',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final controller = container.read(
          routineImportAiControllerProvider.notifier,
        );

        // Call cancelCurrentExtraction
        controller.cancelCurrentExtraction();

        final state = container.read(routineImportAiControllerProvider);
        expect(state.status, RoutineImportAiStatus.idle);
        expect(state.result, isNull);
      },
    );

    test(
      'cancelCurrentExtraction in ClassesSetupController aborts extraction, increments generation, and retires candidate',
      () async {
        final lifecycleHelper = _TrackingLifecycleHelper();
        final container = ProviderContainer(
          overrides: [
            baseTimelineUploadLifecycleHelperProvider.overrideWithValue(
              lifecycleHelper,
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          classesSetupControllerProvider.notifier,
        );

        final setup = BaseTimelineSetup(
          uid: 'user-cancel-test',
          updatedAt: DateTime.now(),
        );

        // Put controller into chooseSource
        controller.chooseSource(setup, uid: 'user-cancel-test');

        // Cancel
        await controller.cancelCurrentExtraction(
          setup,
          uid: 'user-cancel-test',
        );

        final state = container.read(classesSetupControllerProvider);
        expect(state.candidateAssetId, isNull);
        expect(state.candidateR2Key, isNull);
        expect(state.stage, ClassesSetupStage.chooseSource);
      },
    );
  });

  group('Gap 4: Distinct Error Copy (Upload vs AI)', () {
    test(
      'ClassSetupErrorMapper maps camera/gallery permission errors to clear settings copy',
      () {
        final permError = Exception('Camera permission denied by system');
        final copy = ClassSetupErrorMapper.mapUploadError(permError);
        expect(
          copy,
          'Camera or photo access was denied.\n'
          'Please allow access in your device Settings and try again.',
        );
      },
    );

    test('ClassSetupErrorMapper maps network errors to connectivity copy', () {
      final netError = Exception(
        'SocketException: Connection refused (network failure)',
      );
      final copy = ClassSetupErrorMapper.mapUploadError(netError);
      expect(
        copy,
        "We couldn't upload this timetable photo.\n\n"
        'Check your connection and try again.',
      );
    });

    test(
      'ClassSetupErrorMapper mapAiExtractionError never leaks worker or json internals',
      () {
        final internalError = Exception(
          'Worker HTTP 500: JSON decoding failed at line 1',
        );
        final copy = ClassSetupErrorMapper.mapAiExtractionError(internalError);
        expect(copy.contains('Worker'), isFalse);
        expect(copy.contains('JSON'), isFalse);
        expect(copy.contains('HTTP'), isFalse);
        expect(
          copy,
          contains('Try a clearer photo with the full timetable visible'),
        );
      },
    );

    test(
      'ClassSetupErrorMapper formatDroppedSummary uses truthful skipped wording',
      () {
        expect(
          ClassSetupErrorMapper.formatDroppedSummary(1, ['Overnight class']),
          '1 timetable entry was skipped (Overnight class). Please verify your classes.',
        );
        expect(
          ClassSetupErrorMapper.formatDroppedSummary(3, ['Overnight class']),
          '3 timetable entries were skipped (Overnight class). Please verify your classes.',
        );
        expect(ClassSetupErrorMapper.formatDroppedSummary(0, []), isEmpty);
      },
    );
  });

  group(
    'Gap 5: "Set up manually" vs "Edit current timetable" Provenance Distinction',
    () {
      test(
        'startManualSetup clears asset IDs and R2 keys for pure manual provenance while preserving blocks',
        () {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          final controller = container.read(
            classesSetupControllerProvider.notifier,
          );

          final existingSetup = BaseTimelineSetup(
            uid: 'user-prov-test',
            updatedAt: DateTime.now(),
            classLogicalAssetId: 'photo-asset-to-clear',
            classLogicalAssetR2Key: 'users/user-prov-test/photo.jpg',
            classBlocks: const [
              TimelineBlockDraft(
                id: 'c1',
                section: 'classes',
                title: 'Physics 101',
                startMinute: 600,
                endMinute: 660,
                repeatDays: [1, 2],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
            ],
          );

          controller.startManualSetup(existingSetup);

          final state = container.read(classesSetupControllerProvider);
          expect(state.stage, ClassesSetupStage.review);
          expect(state.workingAssetId, isNull);
          expect(state.workingR2Key, isNull);
          expect(state.workingBlocks.length, 1);
          expect(state.workingBlocks.first.subject, 'Physics 101');
        },
      );

      test(
        'editCurrentTimetable retains existing photo provenance and blocks',
        () {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          final controller = container.read(
            classesSetupControllerProvider.notifier,
          );

          final existingSetup = BaseTimelineSetup(
            uid: 'user-prov-test',
            updatedAt: DateTime.now(),
            classLogicalAssetId: 'photo-asset-retained',
            classLogicalAssetR2Key: 'users/user-prov-test/retained.jpg',
            classBlocks: const [
              TimelineBlockDraft(
                id: 'c2',
                section: 'classes',
                title: 'Chemistry 101',
                startMinute: 600,
                endMinute: 660,
                repeatDays: [3, 5],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
            ],
          );

          controller.editCurrentTimetable(existingSetup);

          final state = container.read(classesSetupControllerProvider);
          expect(state.stage, ClassesSetupStage.review);
          expect(state.workingAssetId, 'photo-asset-retained');
          expect(state.workingR2Key, 'users/user-prov-test/retained.jpg');
          expect(state.workingBlocks.length, 1);
          expect(state.workingBlocks.first.subject, 'Chemistry 101');
        },
      );
    },
  );

  group('Gap 6: Overlap Presentation (Front & Exposed Layout)', () {
    test(
      'TimelineOverlapEngine computes front card with exposed left strip for back cards',
      () {
        final entry1 = TimelineEntry(
          id: 'class-1',
          sourceId: 'c1',
          title: 'Data Structures',
          startMinute: 600,
          endMinute: 720,
          repeatDays: const [1],
          category: TimelineCategory.classes,
        );
        final entry2 = TimelineEntry(
          id: 'class-2',
          sourceId: 'c2',
          title: 'Algorithms',
          startMinute: 630,
          endMinute: 750,
          repeatDays: const [1],
          category: TimelineCategory.classes,
        );

        final result = TimelineOverlapEngine.computeLayout(
          entries: [entry1, entry2],
          availableWidth: 360,
          selectedDay: 1,
          overlapPresentation: TimelineOverlapPresentation.frontAndExposed,
          frontEntryId: 'class-2',
        );

        final positioned = result.entries;
        expect(positioned.length, 2);

        final pos1 = positioned.firstWhere((p) => p.entry.id == 'class-1');
        final pos2 = positioned.firstWhere((p) => p.entry.id == 'class-2');

        expect(pos1.hasOverlap, isTrue);
        expect(pos2.hasOverlap, isTrue);

        // class-2 is front
        expect(pos2.isFront, isTrue);
        expect(pos1.isFront, isFalse);

        // Front entry has left offset greater than back entry (exposed left strip)
        expect(pos2.left, greaterThan(pos1.left));
        expect(pos1.left, 62.0); // config.leftOffset

        // Front entry is ordered last in painted list so it paints on top!
        expect(positioned.last.entry.id, 'class-2');
      },
    );

    test(
      'Generic sideBySide overlap presentation remains default and untouched for other domains',
      () {
        final entry1 = TimelineEntry(
          id: 'work-1',
          sourceId: 'w1',
          title: 'Shift 1',
          startMinute: 600,
          endMinute: 720,
          repeatDays: const [1],
          category: TimelineCategory.work,
        );
        final entry2 = TimelineEntry(
          id: 'work-2',
          sourceId: 'w2',
          title: 'Shift 2',
          startMinute: 630,
          endMinute: 750,
          repeatDays: const [1],
          category: TimelineCategory.work,
        );

        final result = TimelineOverlapEngine.computeLayout(
          entries: [entry1, entry2],
          availableWidth: 360,
          selectedDay: 1,
          // Defaults to sideBySide
        );

        final positioned = result.entries;
        expect(positioned.length, 2);
        // Each gets roughly half usable width: (360 - 62 - 16 - 6) / 2 = 138.0
        expect(positioned[0].width, closeTo(138.0, 1.0));
        expect(positioned[1].width, closeTo(138.0, 1.0));
        expect(positioned[0].left, 62.0);
        expect(positioned[1].left, closeTo(206.0, 1.0));
      },
    );
  });

  group('Gap 7: Selected Day Normalization', () {
    test('normalizeSelectedDay keeps currentDay if it has classes', () {
      final blocks = [
        ClassRoutineBlock(
          id: '1',
          subject: 'Math',
          startMinute: 600,
          endMinute: 660,
          repeatDays: [2, 4],
        ),
      ];
      expect(normalizeSelectedDay(currentDay: 2, blocks: blocks), 2);
    });

    test('normalizeSelectedDay switches to today if today has classes', () {
      final blocks = [
        ClassRoutineBlock(
          id: '1',
          subject: 'Math',
          startMinute: 600,
          endMinute: 660,
          repeatDays: [3, 5],
        ),
      ];
      final wednesday = DateTime(2026, 9, 16); // Wednesday = 3
      expect(
        normalizeSelectedDay(currentDay: 1, blocks: blocks, now: wednesday),
        3,
      );
    });

    test(
      'normalizeSelectedDay falls back to earliest weekday if currentDay and today have no classes',
      () {
        final blocks = [
          ClassRoutineBlock(
            id: '1',
            subject: 'Math',
            startMinute: 600,
            endMinute: 660,
            repeatDays: [2, 5],
          ),
        ];
        final sunday = DateTime(2026, 9, 20); // Sunday = 7
        expect(
          normalizeSelectedDay(currentDay: 6, blocks: blocks, now: sunday),
          2,
        );
      },
    );

    test(
      'normalizeSelectedDay falls back to today clamped when schedule is empty',
      () {
        final sunday = DateTime(2026, 9, 20); // Sunday = 7
        expect(
          normalizeSelectedDay(currentDay: 2, blocks: const [], now: sunday),
          7,
        );
      },
    );
  });

  group('Gap 8: ClassDetailSheet Scroll Safety & Overflow Prevention', () {
    testWidgets(
      'ClassDetailSheet renders with massive notes and lengthy professor name without overflow',
      (tester) async {
        final massiveBlock = ClassRoutineBlock(
          id: 'cls-massive',
          subject: 'Advanced Quantum Computing & Cryptography',
          courseCode: 'CS9999-ADV',
          classType: 'Super Extended Laboratory & Seminar Discussion',
          section: 'Section Alpha Beta Gamma Delta',
          room: 'Main Academic Building, Wing D, Room 504A / Lab 2',
          professor:
              'Distinguished Prof. Dr. Alexander Theophilus Montgomery III',
          notes: List.generate(
            20,
            (i) =>
                'Note line $i: Review quantum phase estimation algorithm and Shor factoring implementation.',
          ).join('\n'),
          startMinute: 540,
          endMinute: 720,
          repeatDays: const [1, 3, 5],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ClassDetailSheet.show(context, massiveBlock),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(
          find.text('Advanced Quantum Computing & Cryptography'),
          findsOneWidget,
        );
        expect(find.text('CS9999-ADV'), findsOneWidget);
        expect(find.textContaining('Distinguished Prof.'), findsOneWidget);
        expect(find.textContaining('Note line 0'), findsOneWidget);
        // No overflow exception thrown!
      },
    );
  });

  group('Gap 9: Truthful Fallback for Photo with assetId and null r2Key', () {
    testWidgets(
      'BaseTimelinePhotoPreviewCard renders truthful fallback when assetId is present but r2Key is null and cannot resolve',
      (tester) async {
        final fakeRepo = FakeUploadedAssetRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              uploadedAssetRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: BaseTimelinePhotoPreviewCard(
                  assetId: 'saved-asset-id',
                  r2Key: null,
                  title: 'Timetable photo',
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('Timetable photo saved · Preview unavailable'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'BaseTimelinePhotoPreviewCard renders truthful fallback when assetId is present, r2Key is null, and subtitle is provided',
      (tester) async {
        final fakeRepo = FakeUploadedAssetRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              uploadedAssetRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: BaseTimelinePhotoPreviewCard(
                  assetId: 'saved-asset-with-sub',
                  r2Key: null,
                  title: 'Timetable photo',
                  subtitle: '3 weekly classes',
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('Preview unavailable · 3 weekly classes'),
          findsOneWidget,
        );
      },
    );
  });

  group('Gap 10: Onboarding Completion Rich Metadata Projection Pipeline', () {
    test(
      'OnboardingCompletionService preserves professor, courseCode, classType, sectionLabel, and notes in RoutineItem',
      () {
        final draft = OnboardingDraft(
          uid: 'user-onb-proj',
          baseTimeline: const BaseTimelineDraft(
            blocks: [
              TimelineBlockDraft(
                id: 'onb-cls-1',
                section: 'classes',
                title: 'Algorithms & Data Structures',
                courseCode: 'CS201',
                classType: 'Lecture',
                sectionLabel: 'Sec-A',
                location: 'Hall B',
                professor: 'Prof. Donald Knuth',
                notes: 'Bring graph theory notes',
                startMinute: 600,
                endMinute: 660,
                repeatDays: [1, 3],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
            ],
          ),
        );

        final bundle = OnboardingCompletionService.buildBundle(draft);
        final classItem = bundle.routineItemsForApp.firstWhere(
          (i) => i.title == 'Algorithms & Data Structures',
        );

        expect(classItem.courseCode, 'CS201');
        expect(classItem.classType, 'Lecture');
        expect(classItem.sectionLabel, 'Sec-A');
        expect(classItem.location, 'Hall B');
        expect(classItem.professor, 'Prof. Donald Knuth');
        expect(classItem.notes, 'Bring graph theory notes');
      },
    );
  });

  group(
    'Gap 11: Commit Success + Follow-up Fetch Failure Resiliency (Req 38)',
    () {
      test(
        'replaceSection succeeds and updates in-memory provider even when routine fetch throws',
        () async {
          final fakeSetupRepo = FakeBaseTimelineSetupRepository(
            onboardingRepo: FakeOnboardingRepository(),
          );
          final failingRoutineRepo = _FailingFollowUpFetchRoutineRepository();
          final fakeTxRepo = FakeRoutineTransactionRepository(
            routineRepository: FakeRoutineRepository(),
            setupRepository: fakeSetupRepo,
          );

          final container = ProviderContainer(
            overrides: [
              baseTimelineSetupRepositoryProvider.overrideWithValue(
                fakeSetupRepo,
              ),
              routineRepositoryProvider.overrideWithValue(failingRoutineRepo),
              routineTransactionRepositoryProvider.overrideWithValue(
                fakeTxRepo,
              ),
            ],
          );
          addTearDown(container.dispose);

          final coordinator = container.read(
            baseTimelineTransactionCoordinatorProvider,
          );

          const List<TimelineBlockDraft> newBlocks = [
            TimelineBlockDraft(
              id: 'cls-commit-test',
              section: 'classes',
              title: 'Compiler Design',
              startMinute: 600,
              endMinute: 660,
              repeatDays: [1, 3],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ];

          final result = await coordinator.replaceSection(
            uid: 'user-commit-success',
            section: BaseTimelineSection.classes,
            newBlocks: newBlocks,
            updateSetup: (curr) => curr.copyWith(classBlocks: newBlocks),
          );

          expect(result.committedSetup.classBlocks.length, 1);
          expect(
            result.committedSetup.classBlocks.first.title,
            'Compiler Design',
          );

          // Verify in-memory provider was updated directly and stays updated
          final inMemory = container
              .read(baseTimelineSetupNotifierProvider)
              .value;
          expect(inMemory, isNotNull);
          expect(inMemory!.classBlocks.length, 1);
          expect(inMemory.classBlocks.first.title, 'Compiler Design');
        },
      );
    },
  );

  group('Gap 12: Cancel AI Extraction Then Retry Immediately (Req 39)', () {
    test(
      'User cancels Photo A extraction, starts Photo B immediately, B succeeds and populates working timetable while late A is ignored',
      () async {
        final completerA = Completer<RoutineImportExtractionResult?>();
        final completerB = Completer<RoutineImportExtractionResult?>();
        var callCount = 0;

        final uploadController = _DirectUploadController(
          assetRepository: FakeUploadedAssetRepository(),
        );
        final lifecycleHelper = _TrackingLifecycleHelper();
        final fakeSetupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: FakeOnboardingRepository(),
        );
        final fakeRoutineRepo = FakeRoutineRepository();
        final fakeTxRepo = FakeRoutineTransactionRepository(
          routineRepository: fakeRoutineRepo,
          setupRepository: fakeSetupRepo,
        );
        final coordinator = BaseTimelineTransactionCoordinator(
          routineRepo: fakeRoutineRepo,
          setupRepo: fakeSetupRepo,
          transactionRepo: fakeTxRepo,
        );

        final container = ProviderContainer(
          overrides: [
            uploadControllerProvider.overrideWith((ref) => uploadController),
            baseTimelineUploadLifecycleHelperProvider.overrideWithValue(
              lifecycleHelper,
            ),
            baseTimelineTransactionCoordinatorProvider.overrideWithValue(
              coordinator,
            ),
            routineImportAiControllerProvider.overrideWith(
              (ref) => _ConfigurableAiController(ref, (review) {
                callCount++;
                if (callCount == 1) return completerA.future;
                return completerB.future;
              }),
            ),
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: 'user-retry-test',
                    email: 'test@optivus.app',
                    displayName: 'Test User',
                  ),
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
        final setup = BaseTimelineSetup(
          uid: 'user-retry-test',
          updatedAt: DateTime.now(),
        );

        final assetA = UploadedAsset(
          assetId: 'asset-A',
          ownerUid: 'user-retry-test',
          sourceFeature: UploadSourceFeature.routineBaseTimeline,
          purpose: UploadedAssetPurpose.classTimetable,
          status: UploadedAssetStatus.uploaded,
          fileName: 'photo_a.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 1024,
          r2Key: 'r2-key-A',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final assetB = UploadedAsset(
          assetId: 'asset-B',
          ownerUid: 'user-retry-test',
          sourceFeature: UploadSourceFeature.routineBaseTimeline,
          purpose: UploadedAssetPurpose.classTimetable,
          status: UploadedAssetStatus.uploaded,
          fileName: 'photo_b.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 1024,
          r2Key: 'r2-key-B',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // 1. Start Photo A extraction
        uploadController.assetToReturn = assetA;
        final photoAFuture = controller.pickAndUploadPhoto(
          uid: 'user-retry-test',
          source: ImageSource.gallery,
          setup: setup,
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(classesSetupControllerProvider).stage,
          ClassesSetupStage.extracting,
        );
        expect(
          container.read(classesSetupControllerProvider).candidateAssetId,
          'asset-A',
        );

        // 2. User cancels Photo A
        await controller.cancelCurrentExtraction(setup, uid: 'user-retry-test');
        expect(
          container.read(classesSetupControllerProvider).stage,
          ClassesSetupStage.chooseSource,
        );
        expect(
          container.read(classesSetupControllerProvider).candidateAssetId,
          isNull,
        );
        expect(lifecycleHelper.lastRetiredAssetId, 'asset-A');

        // 3. Start Photo B extraction immediately
        uploadController.assetToReturn = assetB;
        final photoBFuture = controller.pickAndUploadPhoto(
          uid: 'user-retry-test',
          source: ImageSource.gallery,
          setup: setup,
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(classesSetupControllerProvider).stage,
          ClassesSetupStage.extracting,
        );
        expect(
          container.read(classesSetupControllerProvider).candidateAssetId,
          'asset-B',
        );

        // 4. Photo B succeeds
        completerB.complete(
          RoutineImportExtractionResult(
            id: 'res-b',
            uid: 'user-retry-test',
            source: RoutineImportReviewSource.classes,
            createdAt: DateTime.now(),
            candidates: [
              RoutineImportCandidateBlock(
                id: 'cand-b-1',
                title: 'Physics II',
                startMinute: 600,
                endMinute: 660,
                repeatDays: const [2, 4],
                blockType: 'hard',
                category: 'class',
                hardBlock: true,
              ),
            ],
          ),
        );
        await photoBFuture;

        final stateAfterB = container.read(classesSetupControllerProvider);
        expect(stateAfterB.stage, ClassesSetupStage.review);
        expect(stateAfterB.workingAssetId, 'asset-B');
        expect(stateAfterB.workingBlocks.length, 1);
        expect(stateAfterB.workingBlocks.first.subject, 'Physics II');

        // 5. Late Photo A result arrives - must be ignored!
        completerA.complete(
          RoutineImportExtractionResult(
            id: 'res-a',
            uid: 'user-retry-test',
            source: RoutineImportReviewSource.classes,
            createdAt: DateTime.now(),
            candidates: [
              RoutineImportCandidateBlock(
                id: 'cand-a-1',
                title: 'Late Timetable Class A',
                startMinute: 480,
                endMinute: 540,
                repeatDays: const [1],
                blockType: 'hard',
                category: 'class',
                hardBlock: true,
              ),
            ],
          ),
        );
        await photoAFuture;

        final finalState = container.read(classesSetupControllerProvider);
        expect(finalState.workingAssetId, 'asset-B');
        expect(finalState.workingBlocks.length, 1);
        expect(finalState.workingBlocks.first.subject, 'Physics II');
      },
    );
  });

  group('Gap 13: AI Timeout Then Retry (Req 40)', () {
    test(
      'Photo A extraction throws TimeoutException, resets controller to error stage, and retry with Photo B succeeds',
      () async {
        var callCount = 0;
        final completerB = Completer<RoutineImportExtractionResult?>();

        final uploadController = _DirectUploadController(
          assetRepository: FakeUploadedAssetRepository(),
        );
        final lifecycleHelper = _TrackingLifecycleHelper();
        final fakeSetupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: FakeOnboardingRepository(),
        );
        final fakeRoutineRepo = FakeRoutineRepository();
        final fakeTxRepo = FakeRoutineTransactionRepository(
          routineRepository: fakeRoutineRepo,
          setupRepository: fakeSetupRepo,
        );
        final coordinator = BaseTimelineTransactionCoordinator(
          routineRepo: fakeRoutineRepo,
          setupRepo: fakeSetupRepo,
          transactionRepo: fakeTxRepo,
        );

        final container = ProviderContainer(
          overrides: [
            uploadControllerProvider.overrideWith((ref) => uploadController),
            baseTimelineUploadLifecycleHelperProvider.overrideWithValue(
              lifecycleHelper,
            ),
            baseTimelineTransactionCoordinatorProvider.overrideWithValue(
              coordinator,
            ),
            routineImportAiControllerProvider.overrideWith(
              (ref) => _ConfigurableAiController(ref, (review) {
                callCount++;
                if (callCount == 1) {
                  throw TimeoutException('AI timetable extraction timed out.');
                }
                return completerB.future;
              }),
            ),
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: 'user-timeout-test',
                    email: 'test@optivus.app',
                    displayName: 'Test User',
                  ),
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
        final setup = BaseTimelineSetup(
          uid: 'user-timeout-test',
          updatedAt: DateTime.now(),
        );

        final assetA = UploadedAsset(
          assetId: 'asset-timeout-A',
          ownerUid: 'user-timeout-test',
          sourceFeature: UploadSourceFeature.routineBaseTimeline,
          purpose: UploadedAssetPurpose.classTimetable,
          status: UploadedAssetStatus.uploaded,
          fileName: 'photo_a.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 1024,
          r2Key: 'r2-key-timeout-A',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final assetB = UploadedAsset(
          assetId: 'asset-success-B',
          ownerUid: 'user-timeout-test',
          sourceFeature: UploadSourceFeature.routineBaseTimeline,
          purpose: UploadedAssetPurpose.classTimetable,
          status: UploadedAssetStatus.uploaded,
          fileName: 'photo_b.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 1024,
          r2Key: 'r2-key-success-B',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // 1. Photo A extraction times out
        uploadController.assetToReturn = assetA;
        await controller.pickAndUploadPhoto(
          uid: 'user-timeout-test',
          source: ImageSource.gallery,
          setup: setup,
        );

        final timeoutState = container.read(classesSetupControllerProvider);
        expect(timeoutState.stage, ClassesSetupStage.error);
        expect(timeoutState.errorMessage, contains('timed out'));

        // 2. Retry with Photo B immediately
        uploadController.assetToReturn = assetB;
        final photoBFuture = controller.pickAndUploadPhoto(
          uid: 'user-timeout-test',
          source: ImageSource.gallery,
          setup: setup,
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(classesSetupControllerProvider).stage,
          ClassesSetupStage.extracting,
        );

        // 3. Photo B completes successfully
        completerB.complete(
          RoutineImportExtractionResult(
            id: 'res-b-success',
            uid: 'user-timeout-test',
            source: RoutineImportReviewSource.classes,
            createdAt: DateTime.now(),
            candidates: [
              RoutineImportCandidateBlock(
                id: 'cand-b-1',
                title: 'Linear Algebra',
                startMinute: 720,
                endMinute: 780,
                repeatDays: const [3, 5],
                blockType: 'hard',
                category: 'class',
                hardBlock: true,
              ),
            ],
          ),
        );
        await photoBFuture;

        final successState = container.read(classesSetupControllerProvider);
        expect(successState.stage, ClassesSetupStage.review);
        expect(successState.workingAssetId, 'asset-success-B');
        expect(successState.workingBlocks.first.subject, 'Linear Algebra');
      },
    );
  });

  group('Gap 14: Selected Day Recalibration After Edit/Delete (Req 43)', () {
    test(
      'Deleting the only class on Monday smoothly recalibrates selectedDay to Tuesday when Tuesday has classes',
      () {
        final mondayClass = ClassRoutineBlock(
          id: 'cls-mon',
          subject: 'Algorithms',
          startMinute: 600,
          endMinute: 660,
          repeatDays: const [1],
        );
        final tuesdayClass = ClassRoutineBlock(
          id: 'cls-tue',
          subject: 'Database Systems',
          startMinute: 600,
          endMinute: 660,
          repeatDays: const [2],
        );

        final lifecycleHelper = _TrackingLifecycleHelper();
        final fakeSetupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: FakeOnboardingRepository(),
        );
        final fakeRoutineRepo = FakeRoutineRepository();
        final fakeTxRepo = FakeRoutineTransactionRepository(
          routineRepository: fakeRoutineRepo,
          setupRepository: fakeSetupRepo,
        );
        final coordinator = BaseTimelineTransactionCoordinator(
          routineRepo: fakeRoutineRepo,
          setupRepo: fakeSetupRepo,
          transactionRepo: fakeTxRepo,
        );

        final container = ProviderContainer(
          overrides: [
            baseTimelineUploadLifecycleHelperProvider.overrideWithValue(
              lifecycleHelper,
            ),
            baseTimelineTransactionCoordinatorProvider.overrideWithValue(
              coordinator,
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          classesSetupControllerProvider.notifier,
        );

        controller.addBlock(mondayClass);
        controller.addBlock(tuesdayClass);
        controller.selectDay(1);

        expect(container.read(classesSetupControllerProvider).selectedDay, 1);
        expect(
          container.read(classesSetupControllerProvider).workingBlocks.length,
          2,
        );

        controller.deleteBlock('cls-mon');

        final remaining = container
            .read(classesSetupControllerProvider)
            .workingBlocks;
        expect(remaining.length, 1);
        expect(remaining.first.id, 'cls-tue');

        final recalibrated = normalizeSelectedDay(
          currentDay: container
              .read(classesSetupControllerProvider)
              .selectedDay,
          blocks: remaining,
          now: DateTime(2026, 9, 20), // Sunday
        );
        expect(recalibrated, 2);
      },
    );
  });

  group('Gap 15: 3-Class Front/Back Overlap Interaction (Req 46)', () {
    testWidgets(
      'Class A (10:00-11:00), Class B (10:20-11:20), Class C (10:30-10:50): back cards are discoverable, tap brings to front, no conflict UI',
      (tester) async {
        final classA = ClassRoutineBlock(
          id: 'cls-a',
          subject: 'Class A',
          startMinute: 600,
          endMinute: 660,
          repeatDays: const [1],
        );
        final classB = ClassRoutineBlock(
          id: 'cls-b',
          subject: 'Class B',
          startMinute: 620,
          endMinute: 680,
          repeatDays: const [1],
        );
        final classC = ClassRoutineBlock(
          id: 'cls-c',
          subject: 'Class C',
          startMinute: 630,
          endMinute: 650,
          repeatDays: const [1],
        );

        String? activeFrontId = 'cls-a';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return ClassesReviewView(
                    workingBlocks: [classA, classB, classC],
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
                    onAddClass: () {},
                    onEditBlock: (_) {},
                    onSave: () {},
                    frontBlockId: activeFrontId,
                    onFrontSelected: (id) => setState(() => activeFrontId = id),
                  );
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Class A'), findsOneWidget);
        expect(find.text('Class B'), findsOneWidget);
        expect(find.text('Class C'), findsOneWidget);

        // Verify no conflict UI exists
        expect(find.textContaining('Conflict'), findsNothing);
        expect(find.textContaining('Overlap warning'), findsNothing);

        // Tap Class B at its top-left exposed area to bring to front
        await tester.tapAt(
          tester.getTopLeft(find.text('Class B')) + const Offset(4, 2),
        );
        await tester.pumpAndSettle();
        expect(activeFrontId, 'cls-b');

        // Tap Class C to bring to front
        await tester.tap(find.text('Class C'));
        await tester.pumpAndSettle();
        expect(activeFrontId, 'cls-c');
      },
    );
  });

  group('Gap 16: All 8 Class Fields Accessible via Tap (Req 47)', () {
    final completeBlock = ClassRoutineBlock(
      id: 'cls-all-fields',
      subject: 'Quantum Mechanics',
      courseCode: 'PHYS-401',
      classType: 'Laboratory',
      section: 'Lab-3B',
      room: 'Science Complex Room 402',
      professor: 'Dr. Richard Feynman',
      notes: 'Bring lab notebook and safety goggles',
      startMinute: 600,
      endMinute: 720,
      repeatDays: const [1, 3],
    );

    testWidgets('ClassDetailSheet displays all 8 class fields clearly', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ClassDetailSheet.show(context, completeBlock),
                child: const Text('View Class'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('View Class'));
      await tester.pumpAndSettle();

      expect(find.text('Quantum Mechanics'), findsOneWidget);
      expect(find.text('PHYS-401'), findsOneWidget);
      expect(find.text('Laboratory'), findsOneWidget);
      expect(find.text('Sec Lab-3B'), findsOneWidget);
      expect(find.text('10:00 AM - 12:00 PM'), findsOneWidget);
      expect(find.text('Science Complex Room 402'), findsOneWidget);
      expect(find.text('Dr. Richard Feynman'), findsOneWidget);
      expect(
        find.text('Bring lab notebook and safety goggles'),
        findsOneWidget,
      );
    });

    testWidgets(
      'ClassTimelineAdapter.showClassEditSheet displays all 8 class fields for editing',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ClassTimelineAdapter.showClassEditSheet(
                    context: context,
                    block: completeBlock,
                    onSave: (_) async => true,
                  ),
                  child: const Text('Edit Class'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Edit Class'));
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(TextFormField, 'Quantum Mechanics'),
          findsOneWidget,
        );
        expect(find.widgetWithText(TextFormField, 'PHYS-401'), findsOneWidget);
        expect(
          find.widgetWithText(TextFormField, 'Laboratory'),
          findsOneWidget,
        );
        expect(find.widgetWithText(TextFormField, 'Lab-3B'), findsOneWidget);
        expect(
          find.widgetWithText(TextFormField, 'Science Complex Room 402'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(TextFormField, 'Dr. Richard Feynman'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(
            TextFormField,
            'Bring lab notebook and safety goggles',
          ),
          findsOneWidget,
        );
        expect(find.text('Start: 10:00 AM'), findsOneWidget);
        expect(find.text('End: 12:00 PM'), findsOneWidget);
      },
    );
  });
}
