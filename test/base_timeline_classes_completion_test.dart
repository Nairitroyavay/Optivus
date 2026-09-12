import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_ai_thinking_view.dart';
import 'package:optivus/services/uploads/image_prepare_service.dart';
import 'package:optivus/services/routine_import_ai_client.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/state/upload_state.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/onboarding/timeline/adapters/class_timeline_adapter.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/classes_base_setup_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/classes_setup_controller.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_upload_lifecycle_helper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/class_schedule_draft_mapper.dart';
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
import 'package:optivus/features/onboarding/steps/onboarding_step4_candidate_mapping.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/classes_review_view.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/class_timeline_card.dart';

class _TrackingAssetRepo implements UploadedAssetRepository {
  final List<String> deletedAssetIds = [];
  final List<UploadedAsset> assetsToReturn;
  bool failMarkDeleted;

  _TrackingAssetRepo({
    this.assetsToReturn = const [],
    this.failMarkDeleted = false,
  });

  @override
  Future<void> markDeleted({
    required String uid,
    required String assetId,
  }) async {
    if (failMarkDeleted) {
      throw StateError('Firestore markDeleted failed');
    }
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
  bool failDelete;

  _TrackingR2Client({this.failDelete = false});

  @override
  Future<void> deleteUpload({
    required String objectKey,
    required String idToken,
  }) async {
    if (failDelete) {
      throw Exception('R2 delete failed');
    }
    deletedKeys.add(objectKey);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

class _HangingRoutineImportAiController extends RoutineImportAiController {
  final Completer<RoutineImportExtractionResult?> extractionCompleter;
  _HangingRoutineImportAiController(Ref ref, this.extractionCompleter)
    : super(ref, const FakeRoutineImportAiClient());

  @override
  Future<RoutineImportExtractionResult?> runExtraction(
    RoutineImportReviewDraft review,
  ) {
    return extractionCompleter.future;
  }
}

class _HangingSetupRepository implements BaseTimelineSetupRepository {
  final Completer<BaseTimelineSetup> completer;
  _HangingSetupRepository(this.completer);

  @override
  Future<BaseTimelineSetup> fetchSetup(String uid) => completer.future;

  @override
  Future<void> saveSetup(String uid, BaseTimelineSetup setup) async {}

  @override
  Stream<BaseTimelineSetup?> watchSetup(String uid) => const Stream.empty();
}

class _FailingRoutineImportAiController extends RoutineImportAiController {
  _FailingRoutineImportAiController(Ref ref)
    : super(ref, const FakeRoutineImportAiClient());

  @override
  Future<RoutineImportExtractionResult?> runExtraction(
    RoutineImportReviewDraft review,
  ) async {
    throw Exception('Simulated OCR extraction failure');
  }
}

class _CapturingUploadController extends UploadController {
  ImageSource? lastSource;
  int startUploadCount = 0;
  final UploadedAsset? assetToReturn;

  _CapturingUploadController({
    required super.assetRepository,
    this.assetToReturn,
  }) : super(
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
    startUploadCount++;
    lastSource = source;
    return assetToReturn;
  }
}

class _CountingCoordinator extends BaseTimelineTransactionCoordinator {
  int replaceSectionCalls = 0;
  final Completer<void> blocker = Completer<void>();

  _CountingCoordinator({
    required super.routineRepo,
    required super.setupRepo,
    required super.transactionRepo,
  });

  @override
  Future<BaseTimelineSectionCommitResult> replaceSection({
    required String uid,
    required BaseTimelineSection section,
    required List<TimelineBlockDraft> newBlocks,
    required BaseTimelineSetup Function(BaseTimelineSetup current) updateSetup,
  }) async {
    replaceSectionCalls++;
    await blocker.future;
    return super.replaceSection(
      uid: uid,
      section: section,
      newBlocks: newBlocks,
      updateSetup: updateSetup,
    );
  }
}

void main() {
  group('ClassScheduleDraftMapper Tests', () {
    test(
      'Round-trip fidelity preserves all rich class fields without data loss',
      () {
        final original = ClassRoutineBlock(
          id: 'cls-roundtrip-1',
          subject: 'Advanced Algorithms',
          room: 'Turing Hall 101',
          professor: 'Dr. Knuth',
          courseCode: 'CS401',
          classType: 'Lecture & Lab',
          section: 'Section Alpha',
          notes: 'Bring laptop and textbooks',
          startMinute: 600, // 10:00 AM
          endMinute: 720, // 12:00 PM
          repeatDays: const [2, 4], // Tuesday, Thursday
        );

        // Convert to TimelineBlockDraft
        final draft = ClassScheduleDraftMapper.toTimelineDraft(
          original,
          section: 'classes',
          provenanceSourceIds: const ['asset-123'],
        );

        expect(draft, isNotNull);
        expect(draft!.id, 'cls-roundtrip-1');
        expect(draft.title, 'Advanced Algorithms');
        expect(draft.location, 'Turing Hall 101');
        expect(draft.professor, 'Dr. Knuth');
        expect(draft.courseCode, 'CS401');
        expect(draft.classType, 'Lecture & Lab');
        expect(draft.sectionLabel, 'Section Alpha');
        expect(draft.notes, 'Bring laptop and textbooks');
        expect(draft.startMinute, 600);
        expect(draft.endMinute, 720);
        expect(draft.repeatDays, [2, 4]);

        // Convert back to ClassRoutineBlock
        final restored = ClassScheduleDraftMapper.toClassRoutineBlock(draft);
        expect(restored.id, original.id);
        expect(restored.subject, original.subject);
        expect(restored.room, original.room);
        expect(restored.professor, original.professor);
        expect(restored.courseCode, original.courseCode);
        expect(restored.classType, original.classType);
        expect(restored.section, original.section);
        expect(restored.notes, original.notes);
        expect(restored.startMinute, original.startMinute);
        expect(restored.endMinute, original.endMinute);
        expect(restored.repeatDays, [2, 4]);
      },
    );

    test('Strictly rejects invalid blocks and NEVER invents weekdays', () {
      // Empty repeat days
      final emptyDays = ClassRoutineBlock(
        id: 'cls-empty-days',
        subject: 'Physics',
        startMinute: 600,
        endMinute: 700,
        repeatDays: const [],
      );
      expect(
        ClassScheduleDraftMapper.toTimelineDraft(emptyDays, section: 'classes'),
        isNull,
      );

      // Out of range repeat days only
      final outOfRange = ClassRoutineBlock(
        id: 'cls-out-of-range',
        subject: 'Physics',
        startMinute: 600,
        endMinute: 700,
        repeatDays: const [0, 8, -1],
      );
      expect(
        ClassScheduleDraftMapper.toTimelineDraft(
          outOfRange,
          section: 'classes',
        ),
        isNull,
      );

      // Empty subject
      final emptySubject = ClassRoutineBlock(
        id: 'cls-empty-subj',
        subject: '   ',
        startMinute: 600,
        endMinute: 700,
        repeatDays: const [1],
      );
      expect(
        ClassScheduleDraftMapper.toTimelineDraft(
          emptySubject,
          section: 'classes',
        ),
        isNull,
      );

      // Invalid time ordering
      final invalidTime = ClassRoutineBlock(
        id: 'cls-invalid-time',
        subject: 'Physics',
        startMinute: 700,
        endMinute: 600,
        repeatDays: const [1],
      );
      expect(
        ClassScheduleDraftMapper.toTimelineDraft(
          invalidTime,
          section: 'classes',
        ),
        isNull,
      );
    });
  });

  group('sectionLabel Deserialization Defect Prevention Tests', () {
    test(
      'TimelineBlockDraft.fromMap does not fallback to section domain name',
      () {
        final mapWithNullSectionLabel = {
          'id': 'b1',
          'section': 'classes',
          'title': 'Operating Systems',
          'startMinute': 600,
          'endMinute': 700,
          'repeatDays': [1],
          'sectionLabel': null,
        };

        final draft = TimelineBlockDraft.fromMap(mapWithNullSectionLabel);
        expect(draft.section, 'classes');
        expect(draft.sectionLabel, isNull); // Must NOT be 'classes'!
      },
    );

    test(
      'RoutineItem.fromMap does not overwrite classSection with section domain name',
      () {
        final itemMap = {
          'id': 'ri-1',
          'section': 'classes',
          'title': 'Operating Systems',
          'startMinute': 600,
          'endMinute': 700,
          'repeatDays': [1],
          'sectionLabel': null,
        };

        final item = RoutineItem.fromMap(itemMap);
        expect(item.sectionLabel, isNull); // Must NOT be 'classes'!
      },
    );

    test('RoutineImportCandidateBlock.fromMap parses classSection cleanly', () {
      final candMap = {
        'id': 'c1',
        'section': 'classes',
        'name': 'Operating Systems',
        'startMinute': 600,
        'endMinute': 700,
        'daysOfWeek': [1],
        'classSection': 'Section 01',
      };

      final candidate = RoutineImportCandidateBlock.fromMap(candMap);
      expect(candidate.sectionLabel, 'Section 01');
    });
  });

  group('Post-Save Selected Day Recalculation Tests', () {
    test(
      'Calculates earliest scheduled day if current day is not in schedule',
      () {
        final tuesdayThursdayBlocks = [
          ClassRoutineBlock(
            id: 'cls-1',
            subject: 'Database Systems',
            startMinute: 600,
            endMinute: 700,
            repeatDays: const [2, 4],
          ),
        ];

        // On a Monday (weekday 1), schedule has Tuesday (2) and Thursday (4)
        final monday = DateTime(2026, 9, 14); // Monday
        final selectedDay = computeInitialClassWeekday(
          tuesdayThursdayBlocks,
          now: monday,
        );

        expect(selectedDay, 2); // Correctly selects Tuesday!
      },
    );

    test('Selects current day if current day has classes scheduled', () {
      final tuesdayThursdayBlocks = [
        ClassRoutineBlock(
          id: 'cls-1',
          subject: 'Database Systems',
          startMinute: 600,
          endMinute: 700,
          repeatDays: const [2, 4],
        ),
      ];

      // On a Thursday (weekday 4)
      final thursday = DateTime(2026, 9, 17); // Thursday
      final selectedDay = computeInitialClassWeekday(
        tuesdayThursdayBlocks,
        now: thursday,
      );

      expect(selectedDay, 4); // Selects Thursday!
    });
  });

  group('ClassTimelineAdapter Sizing & Deduplication Tests', () {
    test('Calculates content-aware minHeight and avoids tag duplication', () {
      const adapter = ClassTimelineAdapter(
        accent: OptivusColors.blueAccent,
        defaultEditable: false,
      );

      final minimalBlock = ClassRoutineBlock(
        id: 'cls-min',
        subject: 'Study Hall',
        startMinute: 600,
        endMinute: 660,
        repeatDays: const [1],
      );

      final richBlock = ClassRoutineBlock(
        id: 'cls-rich',
        subject: 'Microbiology',
        room: 'Lab 3B',
        professor: 'Dr. Pasteur',
        courseCode: 'BIO302',
        classType: 'Laboratory',
        section: 'Sec 2',
        notes: 'Wear safety goggles and lab coat',
        startMinute: 600,
        endMinute: 720,
        repeatDays: const [1],
      );

      final minEntries = adapter.toEntries(minimalBlock);
      final richEntries = adapter.toEntries(richBlock);

      expect(minEntries.length, 1);
      expect(richEntries.length, 1);

      // Rich block has greater minHeight to accommodate all rich badges & text
      expect(
        richEntries.first.minHeight,
        greaterThan(minEntries.first.minHeight),
      );

      // Style has empty tags so room is not duplicated as a tag chip
      final richStyle = adapter.styleForEntry(richEntries.first);
      expect(richStyle.tags, isEmpty);
    });
  });

  group('BaseTimelineUploadLifecycleHelper Tests', () {
    test(
      'Retires in authoritative order: Firestore tombstone first, then R2 delete',
      () async {
        final assetRepo = _TrackingAssetRepo();
        final r2Client = _TrackingR2Client();
        final authRepo = _StubAuthRepo();

        final helper = BaseTimelineUploadLifecycleHelper(
          assetRepository: assetRepo,
          r2UploadClient: r2Client,
          authRepository: authRepo,
        );

        await helper.retireUncommittedUpload(
          uid: 'user-lifecycle-test',
          assetId: 'asset-to-retire-1',
          objectKey:
              'users/user-lifecycle-test/routine_base_timeline/photo1.jpg',
        );

        expect(assetRepo.deletedAssetIds, ['asset-to-retire-1']);
        expect(r2Client.deletedKeys, [
          'users/user-lifecycle-test/routine_base_timeline/photo1.jpg',
        ]);
      },
    );

    test(
      'cleanupStaleUncommittedAssets strictly protects committed asset while retiring stale ones',
      () async {
        final now = DateTime.now();
        final staleAsset = UploadedAsset(
          assetId: 'stale-asset-99',
          ownerUid: 'user-clean-test',
          sourceFeature: UploadSourceFeature.routineBaseTimeline,
          purpose: UploadedAssetPurpose.classTimetable,
          status: UploadedAssetStatus.uploaded,
          fileName: 'stale.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 1024,
          r2Key: 'users/user-clean-test/stale.jpg',
          createdAt: now.subtract(const Duration(minutes: 30)),
          updatedAt: now.subtract(const Duration(minutes: 25)),
        );

        final committedAsset = UploadedAsset(
          assetId: 'committed-asset-current',
          ownerUid: 'user-clean-test',
          sourceFeature: UploadSourceFeature.routineBaseTimeline,
          purpose: UploadedAssetPurpose.classTimetable,
          status: UploadedAssetStatus.uploaded,
          fileName: 'committed.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 2048,
          r2Key: 'users/user-clean-test/committed.jpg',
          createdAt: now.subtract(const Duration(minutes: 40)),
          updatedAt: now.subtract(const Duration(minutes: 35)),
        );

        final assetRepo = _TrackingAssetRepo(
          assetsToReturn: [staleAsset, committedAsset],
        );
        final r2Client = _TrackingR2Client();
        final authRepo = _StubAuthRepo();

        final helper = BaseTimelineUploadLifecycleHelper(
          assetRepository: assetRepo,
          r2UploadClient: r2Client,
          authRepository: authRepo,
        );

        final cleanedCount = await helper.cleanupStaleUncommittedAssets(
          uid: 'user-clean-test',
          committedAssetId: 'committed-asset-current',
        );

        expect(cleanedCount, 1);
        // Stale asset deleted
        expect(assetRepo.deletedAssetIds.contains('stale-asset-99'), isTrue);
        // Committed asset PROTECTED
        expect(
          assetRepo.deletedAssetIds.contains('committed-asset-current'),
          isFalse,
        );
      },
    );
  });

  group('Intentional Setup Removal & Review Deletion UI Tests', () {
    testWidgets(
      'Removing class in review updates draft locally without touching live setup',
      (tester) async {
        final testSetup = BaseTimelineSetup(
          uid: 'user-review-delete-test',
          updatedAt: DateTime.now(),
          classBlocks: const [
            TimelineBlockDraft(
              id: 'class-keep',
              section: 'classes',
              title: 'Keep Class',
              startMinute: 540,
              endMinute: 600,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
            TimelineBlockDraft(
              id: 'class-remove',
              section: 'classes',
              title: 'Delete Me Class',
              startMinute: 660,
              endMinute: 720,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );

        final fakeOnboardingRepo = FakeOnboardingRepository();
        final fakeSetupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: fakeOnboardingRepo,
        );
        await fakeSetupRepo.saveSetup('user-review-delete-test', testSetup);
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

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userProfileProvider.overrideWith(
                (ref) => UserProfileNotifier()
                  ..loadSeedData(
                    UserProfile(
                      uid: 'user-review-delete-test',
                      email: 'test@optivus.app',
                      displayName: 'Test User',
                    ),
                  ),
              ),
              baseTimelineSetupRepositoryProvider.overrideWithValue(
                fakeSetupRepo,
              ),
              routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
              baseTimelineTransactionCoordinatorProvider.overrideWithValue(
                coordinator,
              ),
            ],
            child: MaterialApp(home: ClassesBaseSetupScreen(onBack: () {})),
          ),
        );

        await tester.pumpAndSettle();

        // Go to Change setup -> Set up manually
        await tester.tap(find.text('Change setup'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Set up manually'));
        await tester.pumpAndSettle();

        expect(find.text('Review Timetable'), findsOneWidget);
        expect(find.text('Keep Class'), findsOneWidget);
        expect(find.text('Delete Me Class'), findsOneWidget);

        // Tap on Delete Me Class
        await tester.tap(find.text('Delete Me Class'));
        await tester.pumpAndSettle();

        // Tap 'Remove class' button inside sheet
        final removeBtn = find.byKey(const Key('timeline-edit-delete-button'));
        expect(removeBtn, findsOneWidget);
        await tester.ensureVisible(removeBtn);
        await tester.pumpAndSettle();
        await tester.tap(removeBtn);
        await tester.pumpAndSettle();

        // Confirm dialog appears
        expect(find.text('Remove this class?'), findsOneWidget);
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        // Review view now only shows Keep Class
        expect(find.text('Keep Class'), findsOneWidget);
        expect(find.text('Delete Me Class'), findsNothing);

        // Live Firestore setup remains untouched!
        final currentLiveSetup = await fakeSetupRepo.fetchSetup(
          'user-review-delete-test',
        );
        expect(currentLiveSetup.classBlocks.length, 2);
      },
    );

    testWidgets(
      'Removing classes setup from overflow menu clears timetable completely',
      (tester) async {
        final testSetup = BaseTimelineSetup(
          uid: 'user-remove-setup-test',
          updatedAt: DateTime.now(),
          classBlocks: const [
            TimelineBlockDraft(
              id: 'c1',
              section: 'classes',
              title: 'Chemistry 101',
              startMinute: 540,
              endMinute: 600,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );

        final fakeOnboardingRepo = FakeOnboardingRepository();
        final fakeSetupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: fakeOnboardingRepo,
        );
        await fakeSetupRepo.saveSetup('user-remove-setup-test', testSetup);
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

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userProfileProvider.overrideWith(
                (ref) => UserProfileNotifier()
                  ..loadSeedData(
                    UserProfile(
                      uid: 'user-remove-setup-test',
                      email: 'test@optivus.app',
                      displayName: 'Test User',
                    ),
                  ),
              ),
              baseTimelineSetupRepositoryProvider.overrideWithValue(
                fakeSetupRepo,
              ),
              routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
              baseTimelineTransactionCoordinatorProvider.overrideWithValue(
                coordinator,
              ),
            ],
            child: MaterialApp(home: ClassesBaseSetupScreen(onBack: () {})),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Chemistry 101'), findsOneWidget);

        // Open overflow menu
        final moreBtn = find.byIcon(Icons.more_vert_rounded);
        expect(moreBtn, findsOneWidget);
        await tester.tap(moreBtn);
        await tester.pumpAndSettle();

        // Tap 'Remove setup'
        expect(find.text('Remove setup'), findsOneWidget);
        await tester.tap(find.text('Remove setup'));
        await tester.pumpAndSettle();

        // Confirmation dialog
        expect(find.text('Remove Classes setup?'), findsOneWidget);
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        // Timetable now cleared
        expect(find.text('Chemistry 101'), findsNothing);
        expect(find.text('No classes on this day.'), findsOneWidget);
        expect(find.text('Set up Classes'), findsOneWidget);

        // Repository also has 0 classes
        final updatedSetup = await fakeSetupRepo.fetchSetup(
          'user-remove-setup-test',
        );
        expect(updatedSetup.classBlocks, isEmpty);
      },
    );
  });

  group(
    'Item 38: Fresh Onboarding 4 to Base Timeline Rich Metadata Pipeline Tests',
    () {
      test(
        'AI candidate -> Step 4 mapping -> ClassRoutineBlock -> TimelineBlockDraft -> Onboarding completion -> BaseTimelineSetup -> Current Setup preserves every rich field',
        () {
          final candidate = RoutineImportCandidateBlock(
            id: 'cand-os-101',
            title: 'Operating Systems',
            startMinute: 600, // 10:00 AM
            endMinute: 660, // 11:00 AM
            repeatDays: const [2, 4], // Tue/Thu
            location: 'Room 402',
            instructor: 'Prof. Rao',
            courseCode: 'CSE301',
            classType: 'Lecture',
            sectionLabel: 'CSE-B',
            notes: 'Bring lab record',
            blockType: 'hard',
            category: 'class',
            hardBlock: true,
          );

          // 1. Canonical Step 4 mapping
          final mappingResult = mapOnboarding4Candidates(
            candidates: [candidate],
            config: ScheduleSetupConfig.classSetup,
          );
          expect(mappingResult.blocks.length, 1);
          final step4Block = mappingResult.blocks.first;

          expect(step4Block.subject, 'Operating Systems');
          expect(step4Block.room, 'Room 402');
          expect(step4Block.professor, 'Prof. Rao');
          expect(step4Block.courseCode, 'CSE301');
          expect(step4Block.classType, 'Lecture');
          expect(step4Block.section, 'CSE-B');
          expect(step4Block.notes, 'Bring lab record');
          expect(step4Block.repeatDays, [2, 4]);
          expect(step4Block.startMinute, 600);
          expect(step4Block.endMinute, 660);

          // 2. Map to durable TimelineBlockDraft
          final drafts = ClassScheduleDraftMapper.toTimelineDrafts(
            [step4Block],
            section: 'classes',
            provenanceAssetId: 'photo-asset-os',
            provenanceR2Key:
                'users/uid-os/onboarding/class_timetable/photo.jpg',
          );
          expect(drafts.length, 1);
          final draft = drafts.first;

          expect(draft.title, 'Operating Systems');
          expect(draft.location, 'Room 402');
          expect(draft.professor, 'Prof. Rao');
          expect(draft.courseCode, 'CSE301');
          expect(draft.classType, 'Lecture');
          expect(draft.sectionLabel, 'CSE-B');
          expect(draft.notes, 'Bring lab record');
          expect(draft.repeatDays, [2, 4]);

          // 3. Persist in OnboardingDraft
          final onboardingDraft = OnboardingDraft(
            uid: 'uid-os',
            lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
            baseTimeline: BaseTimelineDraft(
              blocks: drafts,
              classLogicalAssetId: 'photo-asset-os',
              classLogicalAssetR2Key:
                  'users/uid-os/onboarding/class_timetable/photo.jpg',
            ),
          );

          // 4. Onboarding completion migration to runtime BaseTimelineSetup
          final runtimeSetup = BaseTimelineSetup.fromOnboardingDraft(
            'uid-os',
            onboardingDraft,
          );

          expect(runtimeSetup.classBlocks.length, 1);

          // 5. Classes Current Setup restoration
          final currentSetupBlocks =
              ClassScheduleDraftMapper.toClassRoutineBlocks(
                runtimeSetup.classBlocks,
              );
          expect(currentSetupBlocks.length, 1);
          final currentBlock = currentSetupBlocks.first;

          expect(currentBlock.subject, 'Operating Systems');
          expect(currentBlock.room, 'Room 402');
          expect(currentBlock.professor, 'Prof. Rao');
          expect(currentBlock.courseCode, 'CSE301');
          expect(currentBlock.classType, 'Lecture');
          expect(currentBlock.section, 'CSE-B');
          expect(currentBlock.notes, 'Bring lab record');
          expect(currentBlock.startMinute, 600);
          expect(currentBlock.endMinute, 660);
          expect(currentBlock.repeatDays, [2, 4]);
        },
      );
    },
  );

  group('Item 44: Upload Cleanup Partial Failure Tests', () {
    test(
      'Firestore tombstone succeeds, R2 delete fails: suppresses error and completes safely',
      () async {
        final assetRepo = _TrackingAssetRepo();
        final r2Client = _TrackingR2Client(failDelete: true);
        final authRepo = _StubAuthRepo();

        final helper = BaseTimelineUploadLifecycleHelper(
          assetRepository: assetRepo,
          r2UploadClient: r2Client,
          authRepository: authRepo,
        );

        // Must complete without unhandled exception because Firestore tombstone is authoritative
        await helper.retireUncommittedUpload(
          uid: 'user-partial-fail',
          assetId: 'asset-partial-1',
          objectKey: 'users/user-partial-fail/routine_base_timeline/p1.jpg',
        );

        expect(assetRepo.deletedAssetIds, ['asset-partial-1']);
        expect(r2Client.deletedKeys, isEmpty);
      },
    );

    test(
      'Firestore tombstone fails: throws exception and does NOT attempt R2 delete',
      () async {
        final assetRepo = _TrackingAssetRepo(failMarkDeleted: true);
        final r2Client = _TrackingR2Client();
        final authRepo = _StubAuthRepo();

        final helper = BaseTimelineUploadLifecycleHelper(
          assetRepository: assetRepo,
          r2UploadClient: r2Client,
          authRepository: authRepo,
        );

        expect(
          () => helper.retireUncommittedUpload(
            uid: 'user-partial-fail-2',
            assetId: 'asset-partial-2',
            objectKey: 'users/user-partial-fail-2/routine_base_timeline/p2.jpg',
          ),
          throwsA(isA<StateError>()),
        );

        expect(assetRepo.deletedAssetIds, isEmpty);
        expect(r2Client.deletedKeys, isEmpty);
      },
    );
  });

  group('Item 45: Base Timeline Class Replacement Isolation Tests', () {
    test(
      'replaceSection for classes replaces only Base Timeline classes and preserves Manual and Imported items',
      () async {
        final uid = 'user-survivor-isolation';
        final fakeOnboardingRepo = FakeOnboardingRepository();
        final fakeSetupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: fakeOnboardingRepo,
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

        // Seed pre-existing routine items:
        // 1. Base timeline class item
        final oldBaseClassItem = RoutineItem(
          id: 'ri-base-class-old',
          userId: uid,
          title: 'Old Base Class',
          category: RoutineCategory.classBlock,
          blockType: RoutineBlockType.hardBlock,
          startMinute: 540,
          endMinute: 600,
          repeatDays: const [1],
          source: RoutineSource.baseTimeline,
          baseTimelineSection: 'classes',
          createdAt: DateTime.now(),
        );
        // 2. Manual class-like item
        final manualItem = RoutineItem(
          id: 'ri-manual-class',
          userId: uid,
          title: 'Manual Class / Tutoring',
          category: RoutineCategory.classBlock,
          blockType: RoutineBlockType.softBlock,
          startMinute: 600,
          endMinute: 660,
          repeatDays: const [1],
          source: RoutineSource.manual,
          createdAt: DateTime.now(),
        );
        // 3. Generic imported class-like item
        final importedItem = RoutineItem(
          id: 'ri-imported-class',
          userId: uid,
          title: 'Imported Calendar Event',
          category: RoutineCategory.classBlock,
          blockType: RoutineBlockType.hardBlock,
          startMinute: 660,
          endMinute: 720,
          repeatDays: const [1],
          source: RoutineSource.imported,
          createdAt: DateTime.now(),
        );
        // 4. Base timeline eating item
        final eatingItem = RoutineItem(
          id: 'ri-base-eating',
          userId: uid,
          title: 'Lunch',
          category: RoutineCategory.eating,
          blockType: RoutineBlockType.hardBlock,
          startMinute: 720,
          endMinute: 760,
          repeatDays: const [1],
          source: RoutineSource.baseTimeline,
          baseTimelineSection: 'eating',
          createdAt: DateTime.now(),
        );

        await fakeRoutineRepo.createRoutineItem(uid, oldBaseClassItem);
        await fakeRoutineRepo.createRoutineItem(uid, manualItem);
        await fakeRoutineRepo.createRoutineItem(uid, importedItem);
        await fakeRoutineRepo.createRoutineItem(uid, eatingItem);

        final initialSetup = BaseTimelineSetup(
          uid: uid,
          schemaVersion: 2,
          revision: 1,
          updatedAt: DateTime.now(),
          classRoutineItemIds: const ['ri-base-class-old'],
          classBlocks: const [
            TimelineBlockDraft(
              id: 'draft-old',
              section: 'classes',
              title: 'Old Base Class',
              startMinute: 540,
              endMinute: 600,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
          eatingRoutineItemIds: const ['ri-base-eating'],
        );
        await fakeSetupRepo.saveSetup(uid, initialSetup);

        // Now replace classes with new block
        final newClassDraft = TimelineBlockDraft(
          id: 'draft-new',
          section: 'classes',
          title: 'Brand New Class',
          startMinute: 600,
          endMinute: 660,
          repeatDays: const [2],
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        await coordinator.replaceSection(
          uid: uid,
          section: BaseTimelineSection.classes,
          newBlocks: [newClassDraft],
          updateSetup: (current) => current.copyWith(
            classBlocks: [newClassDraft],
            updatedAt: DateTime.now(),
          ),
        );

        // Verify surviving items in repository
        final allItems = await fakeRoutineRepo.fetchRoutineItems(uid);
        final itemIds = allItems.map((i) => i.id).toSet();

        // Old base class was deleted
        expect(itemIds.contains('ri-base-class-old'), isFalse);

        // Manual item SURVIVED
        expect(itemIds.contains('ri-manual-class'), isTrue);
        // Imported item SURVIVED
        expect(itemIds.contains('ri-imported-class'), isTrue);
        // Eating base timeline item SURVIVED
        expect(itemIds.contains('ri-base-eating'), isTrue);

        // New base class was added
        final newBaseItems = allItems.where(
          (i) => i.title == 'Brand New Class',
        );
        expect(newBaseItems.length, 1);
        expect(newBaseItems.first.source, RoutineSource.baseTimeline);
        expect(newBaseItems.first.baseTimelineSection, 'classes');
      },
    );
  });

  group('Item 46 & 47: Overlapping Classes & Read-Only Semantics Tests', () {
    testWidgets(
      'Overlapping classes render without conflict UI and read-only mode shows no edit pencil',
      (tester) async {
        final uid = 'user-overlap-test';
        final testSetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          classBlocks: const [
            TimelineBlockDraft(
              id: 'class-a',
              section: 'classes',
              title: 'Operating Systems',
              startMinute: 600, // 10:00 AM
              endMinute: 660, // 11:00 AM
              repeatDays: [1],
              location: 'Room 101',
              professor: 'Dr. Dijkstra',
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
            TimelineBlockDraft(
              id: 'class-b',
              section: 'classes',
              title: 'Computer Networks',
              startMinute: 630, // 10:30 AM (Overlaps Class A)
              endMinute: 690, // 11:30 AM
              repeatDays: [1],
              location: 'Room 202',
              professor: 'Dr. Tanenbaum',
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );

        final fakeOnboardingRepo = FakeOnboardingRepository();
        final fakeSetupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: fakeOnboardingRepo,
        );
        await fakeSetupRepo.saveSetup(uid, testSetup);
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

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userProfileProvider.overrideWith(
                (ref) => UserProfileNotifier()
                  ..loadSeedData(
                    UserProfile(
                      uid: uid,
                      email: 'test@optivus.app',
                      displayName: 'Test User',
                    ),
                  ),
              ),
              baseTimelineSetupRepositoryProvider.overrideWithValue(
                fakeSetupRepo,
              ),
              routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
              baseTimelineTransactionCoordinatorProvider.overrideWithValue(
                coordinator,
              ),
            ],
            child: MaterialApp(home: ClassesBaseSetupScreen(onBack: () {})),
          ),
        );

        await tester.pumpAndSettle();

        // Both overlapping classes render
        expect(find.text('Operating Systems'), findsOneWidget);
        expect(find.text('Computer Networks'), findsOneWidget);

        // ZERO conflict resolution UI appears
        expect(find.text('Conflict'), findsNothing);
        expect(find.text('Resolve'), findsNothing);
        expect(find.text('Keep Both'), findsNothing);
        expect(find.text('Move'), findsNothing);

        // Read-only semantics: NO edit pencil is displayed
        expect(find.byIcon(Icons.edit_rounded), findsNothing);

        // Tapping a class in Current Setup opens the ClassDetailSheet
        await tester.tap(find.text('Operating Systems'));
        await tester.pumpAndSettle();

        expect(find.byType(ClassDetailSheet), findsOneWidget);
        expect(find.text('Instructor'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ClassDetailSheet),
            matching: find.text('Dr. Dijkstra'),
          ),
          findsOneWidget,
        );
        expect(find.text('Location'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ClassDetailSheet),
            matching: find.text('Room 101'),
          ),
          findsOneWidget,
        );

        // Close sheet
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        // Transition to Review via manual setup to test editable mode
        await tester.tap(find.text('Change setup'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Set up manually'));
        await tester.pumpAndSettle();

        // Review semantics: Edit pencils ARE displayed
        expect(find.byIcon(Icons.edit_rounded), findsWidgets);
      },
    );

    testWidgets(
      'Item 41: Delete during review updates working draft to 5 classes and commits only 5',
      (tester) async {
        final uid = 'user-delete-6-to-5';
        final sixClasses = List.generate(6, (i) {
          return TimelineBlockDraft(
            id: 'cls-$i',
            section: 'classes',
            title: 'Subject $i',
            startMinute: 480 + (i * 60),
            endMinute: 540 + (i * 60),
            repeatDays: const [1],
            blockType: TimelineBlockDraft.hardBlockKey,
          );
        });

        final testSetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          classBlocks: sixClasses,
        );

        final fakeOnboardingRepo = FakeOnboardingRepository();
        final fakeSetupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: fakeOnboardingRepo,
        );
        await fakeSetupRepo.saveSetup(uid, testSetup);
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

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userProfileProvider.overrideWith(
                (ref) => UserProfileNotifier()
                  ..loadSeedData(
                    UserProfile(
                      uid: uid,
                      email: 'test@optivus.app',
                      displayName: 'Test User',
                    ),
                  ),
              ),
              baseTimelineSetupRepositoryProvider.overrideWithValue(
                fakeSetupRepo,
              ),
              routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
              baseTimelineTransactionCoordinatorProvider.overrideWithValue(
                coordinator,
              ),
            ],
            child: MaterialApp(home: ClassesBaseSetupScreen(onBack: () {})),
          ),
        );

        await tester.pumpAndSettle();

        // Go to Change setup -> Set up manually
        await tester.tap(find.text('Change setup'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Set up manually'));
        await tester.pumpAndSettle();

        expect(find.text('6 classes scheduled'), findsOneWidget);

        // Tap on Subject 0 to remove it
        await tester.tap(find.text('Subject 0'));
        await tester.pumpAndSettle();

        final removeBtn = find.byKey(const Key('timeline-edit-delete-button'));
        await tester.ensureVisible(removeBtn);
        await tester.pumpAndSettle();
        await tester.tap(removeBtn);
        await tester.pumpAndSettle();

        // Confirm
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        // Working draft now has 5
        expect(find.text('5 classes scheduled'), findsOneWidget);
        expect(find.text('Subject 0'), findsNothing);

        // Live setup still has 6 before save
        var liveSetup = await fakeSetupRepo.fetchSetup(uid);
        expect(liveSetup.classBlocks.length, 6);

        // Save
        await tester.tap(find.text('Use this timetable'));
        await tester.pump(const Duration(milliseconds: 1000));
        await tester.pumpAndSettle();

        // Post-save live setup has exactly 5 classes
        liveSetup = await fakeSetupRepo.fetchSetup(uid);
        expect(liveSetup.classBlocks.length, 5);
        expect(
          liveSetup.classBlocks.any((b) => b.title == 'Subject 0'),
          isFalse,
        );
      },
    );

    testWidgets(
      'Item 42: Cancelling during AI extraction increments session generation, retires candidate asset, and ignores late results',
      (tester) async {
        final uid = 'user-cancel-extraction-test';
        final testSetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          classBlocks: const [
            TimelineBlockDraft(
              id: 'cls-exist',
              section: 'classes',
              title: 'Existing Class',
              startMinute: 480,
              endMinute: 540,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );

        final fakeOnboardingRepo = FakeOnboardingRepository();
        final fakeSetupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: fakeOnboardingRepo,
        );
        await fakeSetupRepo.saveSetup(uid, testSetup);
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

        final trackingAssetRepo = _TrackingAssetRepo();
        final trackingR2 = _TrackingR2Client();
        final stubAuth = _StubAuthRepo();
        final lifecycleHelper = BaseTimelineUploadLifecycleHelper(
          assetRepository: trackingAssetRepo,
          r2UploadClient: trackingR2,
          authRepository: stubAuth,
        );

        final candidateAsset = UploadedAsset(
          assetId: 'candidate-asset-42',
          ownerUid: uid,
          sourceFeature: UploadSourceFeature.routineBaseTimeline,
          purpose: UploadedAssetPurpose.classTimetable,
          status: UploadedAssetStatus.uploaded,
          fileName: 'cand.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 2048,
          r2Key: 'candidate-key-42',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final extractionCompleter = Completer<RoutineImportExtractionResult?>();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userProfileProvider.overrideWith(
                (ref) => UserProfileNotifier()
                  ..loadSeedData(
                    UserProfile(
                      uid: uid,
                      email: 'test@optivus.app',
                      displayName: 'Test User',
                    ),
                  ),
              ),
              baseTimelineSetupRepositoryProvider.overrideWithValue(
                fakeSetupRepo,
              ),
              routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
              baseTimelineTransactionCoordinatorProvider.overrideWithValue(
                coordinator,
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
                (ref) =>
                    _HangingRoutineImportAiController(ref, extractionCompleter),
              ),
            ],
            child: MaterialApp(home: ClassesBaseSetupScreen(onBack: () {})),
          ),
        );

        await tester.pumpAndSettle();

        // Start from chooseSource
        await tester.tap(find.text('Change setup'));
        await tester.pumpAndSettle();

        // Pick photo from gallery
        await tester.tap(find.text('Choose from Gallery'));
        await tester.pump(); // Start upload and extraction

        // Now stage is extracting and BaseTimelineAiThinkingView is showing
        expect(find.byType(BaseTimelineAiThinkingView), findsOneWidget);
        expect(find.text('Reading your timetable'), findsOneWidget);

        // Tap cancel button in top bar
        final cancelButton = find.byIcon(Icons.close_rounded);
        expect(cancelButton, findsOneWidget);
        await tester.tap(cancelButton);
        await tester.pumpAndSettle();

        // Candidate asset was retired immediately upon cancel
        expect(
          trackingAssetRepo.deletedAssetIds,
          contains('candidate-asset-42'),
        );
        expect(trackingR2.deletedKeys, contains('candidate-key-42'));

        // Stage returned to chooseSource
        expect(find.text('Choose from Gallery'), findsOneWidget);
        expect(find.text('Set up manually'), findsOneWidget);

        // Now late AI extraction finishes with valid candidates
        extractionCompleter.complete(
          RoutineImportExtractionResult(
            id: 'res-late',
            uid: uid,
            source: RoutineImportReviewSource.classes,
            createdAt: DateTime.now(),
            candidates: [
              RoutineImportCandidateBlock(
                id: 'late-block',
                title: 'Late Physics',
                startMinute: 600,
                endMinute: 660,
                repeatDays: const [1],
                location: 'Lab 1',
                blockType: 'hard',
                category: 'class',
                hardBlock: true,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // The late extraction was IGNORED because session generation changed!
        // Setup remains on chooseSource and NOT review stage
        expect(find.text('Late Physics'), findsNothing);
        expect(find.text('Choose from Gallery'), findsOneWidget);
      },
    );

    testWidgets(
      'Item 40: Replacing Monday-only schedule with Tuesday/Thursday selects Tuesday/today and never empty Monday',
      (tester) async {
        const uid = 'user-tue-thu-replacement';
        final initialMondaySetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          classBlocks: const [
            TimelineBlockDraft(
              id: 'mon-class-1',
              section: 'classes',
              title: 'Monday Math',
              startMinute: 540,
              endMinute: 600,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
              source: 'ai_import',
            ),
          ],
        );

        final fakeSetupRepo = FakeBaseTimelineSetupRepository();
        await fakeSetupRepo.saveSetup(uid, initialMondaySetup);
        final fakeRoutineRepo = FakeRoutineRepository();
        final trackingAssetRepo = _TrackingAssetRepo();
        final trackingR2 = _TrackingR2Client();
        final fakeTxRepo = FakeRoutineTransactionRepository(
          routineRepository: fakeRoutineRepo,
          setupRepository: fakeSetupRepo,
        );
        final coordinator = BaseTimelineTransactionCoordinator(
          routineRepo: fakeRoutineRepo,
          setupRepo: fakeSetupRepo,
          transactionRepo: fakeTxRepo,
        );
        final lifecycleHelper = BaseTimelineUploadLifecycleHelper(
          assetRepository: trackingAssetRepo,
          r2UploadClient: trackingR2,
          authRepository: _StubAuthRepo(),
        );

        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userProfileProvider.overrideWith(
                (ref) => UserProfileNotifier()
                  ..loadSeedData(
                    UserProfile(
                      uid: uid,
                      email: 'test@optivus.app',
                      displayName: 'Test User',
                    ),
                  ),
              ),
              baseTimelineSetupRepositoryProvider.overrideWithValue(
                fakeSetupRepo,
              ),
              routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
              baseTimelineTransactionCoordinatorProvider.overrideWithValue(
                coordinator,
              ),
              baseTimelineUploadLifecycleHelperProvider.overrideWithValue(
                lifecycleHelper,
              ),
              uploadedAssetRepositoryProvider.overrideWithValue(
                trackingAssetRepo,
              ),
            ],
            child: MaterialApp(home: ClassesBaseSetupScreen(onBack: () {})),
          ),
        );

        await tester.pumpAndSettle();

        // Initially displays Monday Math
        expect(find.text('Monday Math'), findsOneWidget);

        // Tap Change setup -> Set up manually
        await tester.tap(find.text('Change setup'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Set up manually'));
        await tester.pumpAndSettle();

        // In review, edit Monday Math to repeat on Tuesday (2) and Thursday (4) instead of Monday
        await tester.tap(find.byIcon(Icons.edit_rounded).first);
        await tester.pumpAndSettle();

        // Toggle repeat days: unselect Mon (1), select Tue (2) and Thu (4)
        await tester.tap(find.text('Tue').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Thu').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mon').last);
        await tester.pumpAndSettle();

        // Save edit in sheet
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Tap Use this timetable
        await tester.tap(find.text('Use this timetable'));
        await tester.pumpAndSettle();

        // Returned to Current Setup: Monday Math is now rendered on Tuesday or Thursday
        expect(find.text('Classes'), findsOneWidget);
        // Current day selected has classes, not an empty Monday
        expect(find.text('Monday Math'), findsOneWidget);
      },
    );

    testWidgets(
      'ClassTimelineCard layout stability across micro (10 min) and mega (6 hr) durations',
      (tester) async {
        final microBlock = ClassRoutineBlock(
          id: 'micro-1',
          subject: 'Micro Sprint Standup',
          courseCode: 'CS999',
          startMinute: 600,
          endMinute: 610,
          repeatDays: const [1],
        );
        final megaBlock = ClassRoutineBlock(
          id: 'mega-1',
          subject: 'Operating Systems Mega Lab & Viva',
          courseCode: 'CS301',
          classType: 'Extended Lab',
          section: 'Section B',
          room: 'Computing Complex 402',
          professor: 'Prof. Ananya Sen',
          notes:
              'Bring signed lab records and benchmark dataset on flash drive.',
          startMinute: 540,
          endMinute: 900,
          repeatDays: const [1],
        );

        const adapter = ClassTimelineAdapter(accent: OptivusColors.blueAccent);
        final microEntries = adapter.toEntries(microBlock);
        final megaEntries = adapter.toEntries(megaBlock);

        // Verify minHeight calculation
        expect(microEntries.first.minHeight, greaterThanOrEqualTo(56.0));
        expect(megaEntries.first.minHeight, greaterThanOrEqualTo(120.0));

        // Pump both cards in a widget test
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SizedBox(
                    height: 38,
                    width: 300,
                    child: ClassTimelineCard(
                      positioned: PositionedTimelineEntry(
                        entry: microEntries.first,
                        top: 0,
                        height: 38,
                        left: 0,
                        width: 300,
                        column: 0,
                        columnCount: 1,
                      ),
                      block: microBlock,
                      isEditable: false,
                    ),
                  ),
                  SizedBox(
                    height: 58,
                    width: 300,
                    child: ClassTimelineCard(
                      positioned: PositionedTimelineEntry(
                        entry: microEntries.first,
                        top: 0,
                        height: 58,
                        left: 0,
                        width: 300,
                        column: 0,
                        columnCount: 1,
                      ),
                      block: microBlock,
                      isEditable: false,
                    ),
                  ),
                  SizedBox(
                    height: 360,
                    width: 300,
                    child: ClassTimelineCard(
                      positioned: PositionedTimelineEntry(
                        entry: megaEntries.first,
                        top: 0,
                        height: 360,
                        left: 0,
                        width: 300,
                        column: 0,
                        columnCount: 1,
                      ),
                      block: megaBlock,
                      isEditable: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.textContaining('Micro Sprint'), findsWidgets);
        expect(find.text('Operating Systems Mega Lab & Viva'), findsOneWidget);
        expect(find.text('Computing Complex 402'), findsOneWidget);
        expect(find.text('Prof. Ananya Sen'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('ClassesBaseSetupScreen Skeleton & Error & Review Robustness Tests', () {
    testWidgets(
      '_buildCurrentSetupSkeletonView renders when baseTimelineSetupNotifierProvider is loading without value',
      (tester) async {
        const uid = 'user-skeleton-test';
        final completer = Completer<BaseTimelineSetup>();
        final hangingSetupRepo = _HangingSetupRepository(completer);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userProfileProvider.overrideWith(
                (ref) => UserProfileNotifier()
                  ..loadSeedData(
                    UserProfile(
                      uid: uid,
                      email: 'test@optivus.app',
                      displayName: 'Test User',
                    ),
                  ),
              ),
              baseTimelineSetupRepositoryProvider.overrideWithValue(
                hangingSetupRepo,
              ),
            ],
            child: MaterialApp(home: ClassesBaseSetupScreen(onBack: () {})),
          ),
        );

        await tester
            .pump(); // Pump initial frame where repo future hasn't completed
        expect(find.text('Classes'), findsOneWidget);
        expect(find.text('Loading timetable...'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

        // Complete the future so test finishes cleanly
        completer.complete(
          BaseTimelineSetup(uid: uid, updatedAt: DateTime.now()),
        );
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Error view displays "Keep previous draft" when _workingBlocks is not empty and returns to review',
      (tester) async {
        const uid = 'user-err-keep-draft-test';
        final initialSetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          classBlocks: const [
            TimelineBlockDraft(
              id: 'cls-keep',
              section: 'classes',
              title: 'Algorithms 101',
              startMinute: 600,
              endMinute: 660,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );

        final fakeSetupRepo = FakeBaseTimelineSetupRepository();
        await fakeSetupRepo.saveSetup(uid, initialSetup);
        final fakeRoutineRepo = FakeRoutineRepository();
        final trackingAssetRepo = _TrackingAssetRepo();
        final trackingR2 = _TrackingR2Client();
        final coordinator = BaseTimelineTransactionCoordinator(
          routineRepo: fakeRoutineRepo,
          setupRepo: fakeSetupRepo,
          transactionRepo: FakeRoutineTransactionRepository(
            routineRepository: fakeRoutineRepo,
            setupRepository: fakeSetupRepo,
          ),
        );
        final lifecycleHelper = BaseTimelineUploadLifecycleHelper(
          assetRepository: trackingAssetRepo,
          r2UploadClient: trackingR2,
          authRepository: _StubAuthRepo(),
        );

        final candidateAsset = UploadedAsset(
          assetId: 'cand-err-1',
          ownerUid: uid,
          sourceFeature: UploadSourceFeature.routineBaseTimeline,
          purpose: UploadedAssetPurpose.classTimetable,
          status: UploadedAssetStatus.uploaded,
          fileName: 'cand.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 2048,
          r2Key: 'cand-key-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userProfileProvider.overrideWith(
                (ref) => UserProfileNotifier()
                  ..loadSeedData(
                    UserProfile(
                      uid: uid,
                      email: 'test@optivus.app',
                      displayName: 'Test User',
                    ),
                  ),
              ),
              baseTimelineSetupRepositoryProvider.overrideWithValue(
                fakeSetupRepo,
              ),
              routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
              baseTimelineTransactionCoordinatorProvider.overrideWithValue(
                coordinator,
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
                (ref) => _FailingRoutineImportAiController(ref),
              ),
            ],
            child: MaterialApp(home: ClassesBaseSetupScreen(onBack: () {})),
          ),
        );

        await tester.pumpAndSettle();

        // Enter review stage via Change setup -> Set up manually so _workingBlocks has Algorithms 101
        await tester.tap(find.text('Change setup'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Set up manually'));
        await tester.pumpAndSettle();

        // In review stage with working draft
        expect(find.text('Review Timetable'), findsOneWidget);
        expect(find.text('Algorithms 101'), findsOneWidget);

        // Tap Scan Again -> Choose from Gallery
        await tester.tap(find.text('Scan Again'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose from Gallery'));
        await tester.pumpAndSettle();

        // Now in error state
        expect(find.text('Timetable Processing Issue'), findsOneWidget);
        expect(find.text('Retry AI'), findsOneWidget);
        expect(find.text('Choose another photo'), findsOneWidget);
        expect(find.text('Keep previous draft'), findsOneWidget);

        // Tap Keep previous draft
        await tester.tap(find.text('Keep previous draft'));
        await tester.pumpAndSettle();

        // Successfully navigated to Review stage with draft intact
        expect(find.text('Review Timetable'), findsOneWidget);
        expect(find.text('Algorithms 101'), findsOneWidget);
      },
    );

    testWidgets(
      'ClassesReviewView displays correct subtitle for clean and attention-needed states',
      (tester) async {
        final sampleBlock = ClassRoutineBlock(
          id: 'b1',
          subject: 'Physics',
          startMinute: 600,
          endMinute: 660,
          repeatDays: const [1],
        );

        // Test with droppedCount = 0
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ClassesReviewView(
                workingBlocks: [sampleBlock],
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
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('1 classes scheduled'), findsOneWidget);

        // Test with droppedCount = 2
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ClassesReviewView(
                workingBlocks: [sampleBlock],
                workingAssetId: null,
                workingR2Key: null,
                workingLocalPreviewPath: null,
                selectedDay: 1,
                onDayChanged: (_) {},
                droppedCount: 2,
                droppedExamples: const [
                  'Overnight class dropped',
                  'Invalid time',
                ],
                errorMessage: null,
                onClearError: () {},
                isSaving: false,
                onCancel: () {},
                onScanAgain: () {},
                onAddClass: () {},
                onEditBlock: (_) {},
                onSave: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('1 classes scheduled · 2 entries were skipped'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Source selection passes ImageSource.gallery when Choose from Gallery is tapped',
      (tester) async {
        const uid = 'user-image-source-gallery-test';
        final initialSetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          classBlocks: const [
            TimelineBlockDraft(
              id: 'cls-src-1',
              section: 'classes',
              title: 'Algorithms 101',
              startMinute: 600,
              endMinute: 660,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );

        final fakeSetupRepo = FakeBaseTimelineSetupRepository();
        await fakeSetupRepo.saveSetup(uid, initialSetup);
        final fakeRoutineRepo = FakeRoutineRepository();
        final trackingAssetRepo = _TrackingAssetRepo();
        final capturingUploadCtrl = _CapturingUploadController(
          assetRepository: trackingAssetRepo,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userProfileProvider.overrideWith(
                (ref) => UserProfileNotifier()
                  ..loadSeedData(
                    UserProfile(
                      uid: uid,
                      email: 'test@optivus.app',
                      displayName: 'Test User',
                    ),
                  ),
              ),
              baseTimelineSetupRepositoryProvider.overrideWithValue(
                fakeSetupRepo,
              ),
              routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
              uploadControllerProvider.overrideWith(
                (ref) => capturingUploadCtrl,
              ),
            ],
            child: MaterialApp(home: ClassesBaseSetupScreen(onBack: () {})),
          ),
        );

        await tester.pumpAndSettle();

        // Navigate from currentSetup to chooseSource
        await tester.tap(find.text('Change setup'));
        await tester.pumpAndSettle();

        // Verify Choose from Gallery passes ImageSource.gallery
        await tester.tap(find.text('Choose from Gallery'));
        await tester.pump();
        expect(capturingUploadCtrl.lastSource, ImageSource.gallery);
        expect(capturingUploadCtrl.startUploadCount, 1);
      },
    );

    testWidgets(
      'Source selection passes ImageSource.camera when Take a Photo is tapped',
      (tester) async {
        const uid = 'user-image-source-camera-test';
        final initialSetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          classBlocks: const [
            TimelineBlockDraft(
              id: 'cls-src-2',
              section: 'classes',
              title: 'Algorithms 101',
              startMinute: 600,
              endMinute: 660,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );

        final fakeSetupRepo = FakeBaseTimelineSetupRepository();
        await fakeSetupRepo.saveSetup(uid, initialSetup);
        final fakeRoutineRepo = FakeRoutineRepository();
        final trackingAssetRepo = _TrackingAssetRepo();
        final capturingUploadCtrl = _CapturingUploadController(
          assetRepository: trackingAssetRepo,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userProfileProvider.overrideWith(
                (ref) => UserProfileNotifier()
                  ..loadSeedData(
                    UserProfile(
                      uid: uid,
                      email: 'test@optivus.app',
                      displayName: 'Test User',
                    ),
                  ),
              ),
              baseTimelineSetupRepositoryProvider.overrideWithValue(
                fakeSetupRepo,
              ),
              routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
              uploadControllerProvider.overrideWith(
                (ref) => capturingUploadCtrl,
              ),
            ],
            child: MaterialApp(home: ClassesBaseSetupScreen(onBack: () {})),
          ),
        );

        await tester.pumpAndSettle();

        // Navigate from currentSetup to chooseSource
        await tester.tap(find.text('Change setup'));
        await tester.pumpAndSettle();

        // Verify Take a Photo passes ImageSource.camera
        await tester.tap(find.text('Take a Photo'));
        await tester.pump();
        expect(capturingUploadCtrl.lastSource, ImageSource.camera);
        expect(capturingUploadCtrl.startUploadCount, 1);
      },
    );

    testWidgets('save returns to currentSetup with success snackbar', (
      tester,
    ) async {
      const uid = 'user-save-success-test';
      final initialSetup = BaseTimelineSetup(
        uid: uid,
        updatedAt: DateTime.now(),
        classBlocks: const [
          TimelineBlockDraft(
            id: 'cls-save-suc',
            section: 'classes',
            title: 'Algorithms 101',
            startMinute: 600,
            endMinute: 660,
            repeatDays: [1, 2, 3, 4, 5, 6, 7],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ],
      );

      final fakeSetupRepo = FakeBaseTimelineSetupRepository();
      await fakeSetupRepo.saveSetup(uid, initialSetup);
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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: uid,
                    email: 'test@optivus.app',
                    displayName: 'Test User',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(
              fakeSetupRepo,
            ),
            routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
            baseTimelineTransactionCoordinatorProvider.overrideWithValue(
              coordinator,
            ),
          ],
          child: MaterialApp(home: ClassesBaseSetupScreen(onBack: () {})),
        ),
      );

      await tester.pumpAndSettle();

      // Go to Choose Source -> Set up manually
      await tester.tap(find.text('Change setup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set up manually'));
      await tester.pumpAndSettle();

      // In Review stage: tap Use this timetable
      await tester.tap(find.text('Use this timetable'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // In-flow success stage is displayed per Requirement 33
      expect(find.text('Classes updated'), findsOneWidget);
      expect(find.text('Your new timetable is now active.'), findsOneWidget);

      await tester.pumpAndSettle();

      // Transitioned to currentSetup stage and snackbar is displayed
      expect(find.text('Classes'), findsOneWidget);
      expect(find.text('Change setup'), findsOneWidget);
      expect(
        find.text('Classes updated. Your new timetable is now active.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'ClassesBaseSetupScreen with pre-loaded baseTimelineSetupNotifierProvider renders ClassesCurrentSetupView immediately without skeleton',
      (tester) async {
        const uid = 'user-preloaded-test';
        final initialSetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          classBlocks: const [
            TimelineBlockDraft(
              id: 'cls-preloaded',
              section: 'classes',
              title: 'Operating Systems',
              startMinute: 600,
              endMinute: 660,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              location: 'Hall A',
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );

        final fakeSetupRepo = FakeBaseTimelineSetupRepository();
        await fakeSetupRepo.saveSetup(uid, initialSetup);

        final container = ProviderContainer(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: uid,
                    email: 'test@optivus.app',
                    displayName: 'Test User',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(
              fakeSetupRepo,
            ),
          ],
        );
        addTearDown(container.dispose);

        // Pre-seed the notifier with AsyncData so it has a value immediately
        container
            .read(baseTimelineSetupNotifierProvider.notifier)
            .updateInMemory(initialSetup);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(home: ClassesBaseSetupScreen(onBack: () {})),
          ),
        );

        // Very first frame pump: NO skeleton, renders timetable view immediately
        await tester.pump();
        expect(find.text('Loading timetable...'), findsNothing);
        expect(find.text('Operating Systems'), findsOneWidget);
        expect(find.text('Change setup'), findsOneWidget);
      },
    );

    testWidgets(
      'Double-tap on Save Timetable button cannot submit transaction twice',
      (tester) async {
        const uid = 'user-double-save-test';
        final initialSetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          classBlocks: const [
            TimelineBlockDraft(
              id: 'cls-double-save',
              section: 'classes',
              title: 'Algorithms 101',
              startMinute: 600,
              endMinute: 660,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );

        final fakeSetupRepo = FakeBaseTimelineSetupRepository();
        await fakeSetupRepo.saveSetup(uid, initialSetup);
        final fakeRoutineRepo = FakeRoutineRepository();

        final countingCoordinator = _CountingCoordinator(
          routineRepo: fakeRoutineRepo,
          setupRepo: fakeSetupRepo,
          transactionRepo: FakeRoutineTransactionRepository(
            routineRepository: fakeRoutineRepo,
            setupRepository: fakeSetupRepo,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userProfileProvider.overrideWith(
                (ref) => UserProfileNotifier()
                  ..loadSeedData(
                    UserProfile(
                      uid: uid,
                      email: 'test@optivus.app',
                      displayName: 'Test User',
                    ),
                  ),
              ),
              baseTimelineSetupRepositoryProvider.overrideWithValue(
                fakeSetupRepo,
              ),
              routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
              baseTimelineTransactionCoordinatorProvider.overrideWithValue(
                countingCoordinator,
              ),
            ],
            child: MaterialApp(home: ClassesBaseSetupScreen(onBack: () {})),
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.text('Change setup'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Set up manually'));
        await tester.pumpAndSettle();

        // Tap Use this timetable twice rapidly
        await tester.tap(find.text('Use this timetable'));
        await tester.tap(find.text('Use this timetable'));
        await tester.pump();

        // Unblock coordinator replaceSection
        countingCoordinator.blocker.complete();
        await tester.pumpAndSettle();

        // Verify replaceSection was only called once
        expect(countingCoordinator.replaceSectionCalls, 1);
      },
    );

    testWidgets(
      'Cancelling chooseSource when working draft exists returns to review with draft preserved',
      (tester) async {
        const uid = 'user-choose-cancel-draft-test';
        final initialSetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          classBlocks: const [
            TimelineBlockDraft(
              id: 'cls-draft-1',
              section: 'classes',
              title: 'Draft Physics',
              startMinute: 600,
              endMinute: 660,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              location: 'Lab 2',
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );

        final fakeSetupRepo = FakeBaseTimelineSetupRepository();
        await fakeSetupRepo.saveSetup(uid, initialSetup);
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

        final fakeAssetRepo = _TrackingAssetRepo();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userProfileProvider.overrideWith(
                (ref) => UserProfileNotifier()
                  ..loadSeedData(
                    UserProfile(
                      uid: uid,
                      email: 'test@optivus.app',
                      displayName: 'Test User',
                    ),
                  ),
              ),
              baseTimelineSetupRepositoryProvider.overrideWithValue(
                fakeSetupRepo,
              ),
              routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
              baseTimelineTransactionCoordinatorProvider.overrideWithValue(
                coordinator,
              ),
              uploadControllerProvider.overrideWith(
                (ref) => _CapturingUploadController(
                  assetRepository: fakeAssetRepo,
                  assetToReturn: UploadedAsset(
                    assetId: 'new-cand-photo',
                    ownerUid: uid,
                    fileName: 'new-cand-photo.jpg',
                    contentType: 'image/jpeg',
                    sizeBytes: 1024,
                    purpose: UploadedAssetPurpose.classTimetable,
                    sourceFeature: 'routine_base_timeline',
                    r2Key:
                        'users/$uid/routine_base_timeline/class_timetable/new-cand-photo.jpg',
                    status: UploadedAssetStatus.uploaded,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                ),
              ),
              routineImportAiControllerProvider.overrideWith(
                (ref) => _FailingRoutineImportAiController(ref),
              ),
            ],
            child: MaterialApp(home: ClassesBaseSetupScreen(onBack: () {})),
          ),
        );

        await tester.pumpAndSettle();
        // Go to Choose Source -> Manual -> Review
        await tester.tap(find.text('Change setup'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Set up manually'));
        await tester.pumpAndSettle();

        expect(find.text('Review Timetable'), findsOneWidget);
        expect(find.text('Draft Physics'), findsOneWidget);

        // In review, tap Scan Again -> Choose from Gallery (triggers photo upload + AI failure)
        await tester.tap(find.text('Scan Again'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose from Gallery'));
        await tester.pumpAndSettle();

        // Enters error view
        expect(find.text('Timetable Processing Issue'), findsOneWidget);

        // Tap "Choose another photo" from error view -> enters chooseSource
        await tester.tap(find.text('Choose another photo'));
        await tester.pumpAndSettle();

        expect(find.text('Update Timetable'), findsOneWidget);

        // Now cancel from chooseSource: since workingBlocks is not empty, should return to review
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        // Returned to Review with original working blocks preserved
        expect(find.text('Review Timetable'), findsOneWidget);
        expect(find.text('Draft Physics'), findsOneWidget);
      },
    );
  });
}
