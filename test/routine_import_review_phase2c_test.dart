import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/onboarding/steps/base_timeline_step.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/routine_import_review_repository.dart';
import 'package:optivus/services/routine_import_applied_restore_service.dart';
import 'package:optivus/services/routine_import_conversion_service.dart';
import 'package:optivus/services/routine_import_extraction_service.dart';
import 'package:optivus/services/routine_import_timeline_edit_service.dart';
import 'package:optivus/services/routine_import_validation_service.dart';
import 'package:optivus/services/uploads/upload_object_key.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  test('RoutineImportReviewDraft toMap/fromMap round-trips', () {
    final now = DateTime.utc(2026, 6, 2, 9);
    final draft = RoutineImportReviewDraft(
      id: 'review-1',
      uid: 'uid-1',
      source: RoutineImportReviewSource.classes,
      status: RoutineImportReviewStatus.needsReview,
      sourceLabel: 'Classes',
      onboardingPendingImportId: 'classes_photo',
      uploadedAssetId: 'asset-1',
      uploadedAssetR2Key: 'users/uid-1/onboarding/class_timetable/asset-1.jpg',
      uploadedAssetStatus: 'uploaded',
      candidateBlocks: [_candidate()],
      warnings: const ['Review manually.'],
      acceptedCandidateIds: const ['candidate-1'],
      rejectedCandidateIds: const ['candidate-2'],
      appliedRoutineItemIds: const ['routine-1'],
      appliedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    final roundTrip = RoutineImportReviewDraft.fromMap(draft.toMap());

    expect(roundTrip.id, draft.id);
    expect(roundTrip.source, RoutineImportReviewSource.classes);
    expect(roundTrip.status, RoutineImportReviewStatus.needsReview);
    expect(roundTrip.candidateBlocks.single.id, 'candidate-1');
    expect(roundTrip.acceptedCandidateIds, ['candidate-1']);
    expect(roundTrip.rejectedCandidateIds, ['candidate-2']);
    expect(roundTrip.appliedRoutineItemIds, ['routine-1']);
    expect(roundTrip.appliedAt, now);
  });

  test('RoutineImportCandidateBlock defaults to candidateType block', () {
    final candidate = _candidate();

    expect(candidate.candidateType, RoutineImportCandidateType.block);
  });

  test('RoutineImportCandidateBlock toMap/fromMap round-trips', () {
    final candidate = _candidate(
      candidateType: RoutineImportCandidateType.flexibleTask,
      hasFixedTime: false,
      suggestedStartMinute: 9 * 60,
      suggestedEndMinute: 10 * 60,
      confidenceScore: 0.84,
      confidenceLabel: 'medium',
      sourceAssetId: 'asset-1',
      sourceR2Key: 'users/uid/onboarding/work_schedule/asset-1.jpg',
      sourceTextSnippet: 'Mon 9 AM work',
      sourcePageIndex: 1,
      sourceImageIndex: 2,
      sourceRowLabel: 'Monday',
      sourceColumnLabel: '9 AM',
      sourceBoundingBox: const {'x': 10, 'y': 20, 'w': 90, 'h': 30},
      validationIssues: const ['Needs room'],
      extractionEngine: 'futureAiText',
      extractionVersion: 'v1',
    );

    final roundTrip = RoutineImportCandidateBlock.fromMap(candidate.toMap());

    expect(roundTrip.candidateType, RoutineImportCandidateType.flexibleTask);
    expect(roundTrip.hasFixedTime, isFalse);
    expect(roundTrip.suggestedStartMinute, 9 * 60);
    expect(roundTrip.suggestedEndMinute, 10 * 60);
    expect(roundTrip.confidenceScore, 0.84);
    expect(roundTrip.confidenceLabel, 'medium');
    expect(roundTrip.sourceAssetId, 'asset-1');
    expect(roundTrip.sourceR2Key, contains('work_schedule'));
    expect(roundTrip.sourceTextSnippet, 'Mon 9 AM work');
    expect(roundTrip.sourcePageIndex, 1);
    expect(roundTrip.sourceImageIndex, 2);
    expect(roundTrip.sourceRowLabel, 'Monday');
    expect(roundTrip.sourceColumnLabel, '9 AM');
    expect(roundTrip.sourceBoundingBox, {'x': 10, 'y': 20, 'w': 90, 'h': 30});
    expect(roundTrip.validationIssues, ['Needs room']);
    expect(roundTrip.extractionEngine, 'futureAiText');
    expect(roundTrip.extractionVersion, 'v1');
  });

  test('low confidence candidate requires manual review', () {
    final candidate = _candidate(confidenceLabel: 'low');

    expect(candidate.needsManualReview, isTrue);
  });

  test('Candidate can represent flexibleTask', () {
    final candidate = _candidate(
      candidateType: RoutineImportCandidateType.flexibleTask,
      blockType: TimelineBlockDraft.flexibleTaskKey,
      hardBlock: false,
      hasFixedTime: false,
    );

    expect(candidate.candidateType, RoutineImportCandidateType.flexibleTask);
    expect(candidate.blockType, TimelineBlockDraft.flexibleTaskKey);
    expect(candidate.hasFixedTime, isFalse);
    expect(candidate.isUnplaced, isTrue);
  });

  test('Untimed flexible task is treated as unplaced', () {
    final candidate = _candidate(
      title: 'Revise DSA',
      candidateType: RoutineImportCandidateType.flexibleTask,
      blockType: TimelineBlockDraft.flexibleTaskKey,
      hardBlock: false,
      hasFixedTime: false,
      selected: false,
    );
    final validation = const RoutineImportValidationService()
        .validateCandidates(candidates: [candidate]);

    expect(candidate.isUnplaced, isTrue);
    expect(
      validation.warningsFor(candidate.id),
      contains('Flexible task has no fixed time.'),
    );
    expect(validation.hasBlockingIssues, isFalse);
  });

  test('Extraction service attaches uploadedAssetId/R2 key', () {
    final review = const RoutineImportExtractionService().buildReviewDraft(
      uid: 'uid-1',
      source: RoutineImportReviewSource.classes,
      onboardingDraft: _draftWithUploadReferences(),
    );

    expect(review.uploadedAssetId, 'class-asset');
    expect(review.uploadedAssetR2Key, contains('class_timetable'));
    expect(review.candidateBlocks.single.sourceAssetId, 'class-asset');
    expect(
      review.candidateBlocks.single.sourceR2Key,
      contains('class_timetable'),
    );
  });

  test('Photo-only import creates needsManualReview warning', () {
    final review = const RoutineImportExtractionService().buildReviewDraft(
      uid: 'uid-1',
      source: RoutineImportReviewSource.skinCare,
      onboardingDraft: _draftWithUploadReferences(),
    );

    expect(
      review.warnings,
      contains(RoutineImportExtractionService.noAiExtractionWarning),
    );
    expect(review.candidateBlocks.single.needsManualReview, isTrue);
    expect(review.candidateBlocks.single.confidenceLabel, 'low');
  });

  test('Classes source maps to class timetable purpose/section', () {
    final service = const RoutineImportExtractionService();

    expect(
      service.timelineSectionKey(RoutineImportReviewSource.classes),
      'classes',
    );
    expect(
      service.uploadedAssetPurposeKey(RoutineImportReviewSource.classes),
      'class_timetable',
    );
  });

  test('Eating source maps to eating menu purpose/section', () {
    final service = const RoutineImportExtractionService();

    expect(
      service.timelineSectionKey(RoutineImportReviewSource.eating),
      'eating',
    );
    expect(
      service.uploadedAssetPurposeKey(RoutineImportReviewSource.eating),
      'eating_menu',
    );
  });

  test('Skin Care source maps to skin care purpose/section', () {
    final service = const RoutineImportExtractionService();

    expect(
      service.timelineSectionKey(RoutineImportReviewSource.skinCare),
      'skin_care',
    );
    expect(
      service.uploadedAssetPurposeKey(RoutineImportReviewSource.skinCare),
      'skin_care',
    );
  });

  test('Work source maps to work_schedule purpose', () {
    final service = const RoutineImportExtractionService();

    expect(
      onboardingUploadPurposeForBaseTimelineSection('Job / Work / Business'),
      UploadedAssetPurpose.workSchedule,
    );
    expect(
      service.timelineSectionKey(RoutineImportReviewSource.work),
      'job_work_business',
    );
    expect(
      service.uploadedAssetPurposeKey(RoutineImportReviewSource.work),
      'work_schedule',
    );
    expect(UploadedAssetPurpose.workSchedule.wireName, 'work_schedule');
    expect(
      UploadObjectKeyBuilder.build(
        uid: 'uid',
        sourceFeature: OnboardingDraft.sourceOnboarding,
        purpose: UploadedAssetPurpose.workSchedule,
        assetId: 'asset',
      ),
      'users/uid/onboarding/work_schedule/asset.jpg',
    );
  });

  test(
    'Completion bundle fallback builds review with uploadedAssetId/R2 key',
    () {
      final review = const RoutineImportExtractionService()
          .buildReviewDraftFromCompletionBundle(
            uid: 'uid-1',
            source: RoutineImportReviewSource.work,
            bundle: _completionBundleWithWorkAsset(),
          );

      expect(review.uploadedAssetId, 'work-asset');
      expect(review.uploadedAssetR2Key, contains('work_schedule'));
      expect(
        review.warnings,
        contains(RoutineImportExtractionService.noAiExtractionWarning),
      );
      expect(review.candidateBlocks.single.sourceAssetId, 'work-asset');
      expect(review.candidateBlocks.single.needsManualReview, isTrue);
    },
  );

  test('FakeRoutineImportReviewRepository saves and fetches review', () async {
    final repository = FakeRoutineImportReviewRepository();
    final review = RoutineImportReviewDraft(
      id: 'review-1',
      uid: 'uid-1',
      source: RoutineImportReviewSource.eating,
      status: RoutineImportReviewStatus.draft,
      sourceLabel: 'Eating',
      candidateBlocks: [_candidate()],
      createdAt: DateTime.utc(2026, 6, 2),
      updatedAt: DateTime.utc(2026, 6, 2),
    );

    await repository.saveReview(review);

    final saved = await repository.fetchReview(
      uid: 'uid-1',
      reviewId: 'review-1',
    );
    expect(saved, isNotNull);
    expect(saved!.source, RoutineImportReviewSource.eating);
    expect((await repository.fetchReviews('uid-1')), hasLength(1));
  });

  test('Firestore path helper returns routine import review path', () {
    expect(
      FirestoreUserPaths.routineImportReview('uid-1', 'review-1'),
      'users/uid-1/routineImportReviews/review-1',
    );
  });

  test(
    'Firestore routine import review rules block direct Routine payloads',
    () {
      final rules = File('firestore.rules').readAsStringSync();

      expect(rules, contains('validRoutineImportReviewKeys(data)'));
      expect(rules, contains('"routineItems"'));
      expect(rules, contains('"localPreviewPath"'));
      expect(rules, contains('data.candidateBlocks is list'));
    },
  );

  test(
    'Conversion service converts timed selected candidate to RoutineItem',
    () {
      final items = const RoutineImportConversionService()
          .convertAcceptedCandidates(
            reviewId: 'review-1',
            candidates: [_candidate()],
          );

      expect(items, hasLength(1));
      expect(items.single.title, 'Candidate block');
      expect(items.single.blockType, RoutineBlockType.hardBlock);
      expect(items.single.id, 'imported-review-1-candidate-1');
    },
  );

  test('Conversion service rejects unselected candidate', () {
    final items = const RoutineImportConversionService()
        .convertAcceptedCandidates(
          reviewId: 'review-1',
          candidates: [_candidate(selected: false)],
        );

    expect(items, isEmpty);
  });

  test('Conversion service rejects untimed flexible task', () {
    final items = const RoutineImportConversionService()
        .convertAcceptedCandidates(
          reviewId: 'review-1',
          candidates: [
            _candidate(
              candidateType: RoutineImportCandidateType.flexibleTask,
              blockType: TimelineBlockDraft.flexibleTaskKey,
              hardBlock: false,
              hasFixedTime: false,
            ),
          ],
        );

    expect(items, isEmpty);
  });

  test('Conversion service puts checklist steps into notes', () {
    final items = const RoutineImportConversionService()
        .convertAcceptedCandidates(
          reviewId: 'review-1',
          candidates: [
            _candidate(
              candidateType: RoutineImportCandidateType.checklistStep,
              blockType: TimelineBlockDraft.flexibleTaskKey,
              hardBlock: false,
              steps: const ['Cleanser', 'Sunscreen'],
            ),
          ],
        );

    expect(items.single.notes, contains('Cleanser, Sunscreen'));
    expect(items.single.steps, ['Cleanser', 'Sunscreen']);
  });

  test('Drag math helper converts vertical delta to snapped minutes', () {
    final delta = RoutineImportTimelineEditService.snappedDeltaMinutes(
      verticalDelta: 17,
      pixelsPerMinute: 0.5,
      snapMinutes: 10,
    );

    expect(delta, 30);
  });

  test('Resize helper respects minimum duration', () {
    final resized = RoutineImportTimelineEditService.resizeEnd(
      startMinute: 8 * 60,
      endMinute: 8 * 60 + 30,
      deltaMinutes: -25,
      minDurationMinutes: 10,
    );

    expect(resized.startMinute, 8 * 60);
    expect(resized.endMinute, 8 * 60 + 10);
  });

  test('Validation service catches invalid time', () {
    final result = const RoutineImportValidationService().validateCandidates(
      candidates: [_candidate(startMinute: 10 * 60, endMinute: 9 * 60)],
    );

    expect(result.hasBlockingIssues, isTrue);
    expect(
      result.issuesFor('candidate-1'),
      contains('End time must be after start time.'),
    );
  });

  test('Invalid timed block fails apply validation', () {
    final result = const RoutineImportValidationService().validateCandidates(
      candidates: [
        _candidate(
          hasFixedTime: true,
          startMinute: 12 * 60,
          endMinute: 12 * 60,
        ),
      ],
    );

    expect(result.hasBlockingIssuesFor('candidate-1'), isTrue);
    expect(
      result.issuesFor('candidate-1'),
      contains('End time must be after start time.'),
    );
  });

  test('Validation service warns low confidence', () {
    final result = const RoutineImportValidationService().validateCandidates(
      candidates: [_candidate(confidenceLabel: 'low')],
    );

    expect(result.hasBlockingIssues, isFalse);
    expect(
      result.warningsFor('candidate-1'),
      contains('Low confidence. Please check this block.'),
    );
  });

  test('Low confidence warning is not a hard block after manual review', () {
    final result = const RoutineImportValidationService().validateCandidates(
      candidates: [
        _candidate(confidenceLabel: 'manual', needsManualReview: false),
      ],
    );

    expect(result.hasBlockingIssues, isFalse);
    expect(result.warningsFor('candidate-1'), isEmpty);
  });

  test('Validation blocks only hard-hard existing overlaps', () {
    final service = const RoutineImportValidationService();
    final hardOverlap = service.validateCandidates(
      candidates: [_candidate()],
      existingRoutineItems: [_routineItem(hardBlock: true)],
    );
    final softOverlap = service.validateCandidates(
      candidates: [_candidate(hardBlock: false)],
      existingRoutineItems: [_routineItem(hardBlock: true)],
    );

    expect(hardOverlap.hasBlockingIssuesFor('candidate-1'), isTrue);
    expect(
      hardOverlap.issuesFor('candidate-1').single,
      contains('Hard block overlaps'),
    );
    expect(softOverlap.hasBlockingIssuesFor('candidate-1'), isFalse);
    expect(
      softOverlap.warningsFor('candidate-1'),
      contains('Overlaps an existing routine item.'),
    );
  });

  test('Already accepted review blocks duplicate apply', () {
    final review = RoutineImportReviewDraft(
      id: 'review-1',
      uid: 'uid-1',
      source: RoutineImportReviewSource.classes,
      status: RoutineImportReviewStatus.accepted,
      sourceLabel: 'Classes',
      candidateBlocks: [_candidate()],
      appliedRoutineItemIds: const ['imported-review-1-candidate-1'],
      createdAt: DateTime.utc(2026, 6, 2),
      updatedAt: DateTime.utc(2026, 6, 2),
    );

    expect(review.blocksDuplicateApply, isTrue);
  });

  test(
    'Accepted review without applied ids still blocks save and can restore',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final review = _acceptedReview(appliedRoutineItemIds: const []);
      final service = const RoutineImportAppliedRestoreService();

      expect(review.blocksDuplicateApply, isTrue);
      expect(
        service
            .missingItemsForReview(
              review: review,
              currentItems: container.read(routineNotifierProvider).items,
            )
            .map((item) => item.id),
        ['imported-review-1-candidate-1'],
      );

      final result = await service.restoreMissingForReview(
        read: container.read,
        review: review,
      );

      expect(result.restoredItemIds, ['imported-review-1-candidate-1']);
      expect(
        container
            .read(routineNotifierProvider)
            .items
            .where((item) => item.id == 'imported-review-1-candidate-1'),
        hasLength(1),
      );
    },
  );

  test('Accepted import review restores missing local routine items', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final review = _acceptedReview();

    final result = await const RoutineImportAppliedRestoreService()
        .restoreMissingForReview(read: container.read, review: review);

    expect(result.missingItemIds, ['imported-review-1-candidate-1']);
    expect(result.restoredItemIds, ['imported-review-1-candidate-1']);
    expect(
      container.read(routineNotifierProvider).items.map((item) => item.id),
      contains('imported-review-1-candidate-1'),
    );
    expect(
      container.read(mockRoutineProvider).map((item) => item.id),
      contains('imported-review-1-candidate-1'),
    );
  });

  test(
    'Already-applied review restore does not duplicate existing item',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final review = _acceptedReview();
      final service = const RoutineImportAppliedRestoreService();

      await service.restoreMissingForReview(
        read: container.read,
        review: review,
      );
      final second = await service.restoreMissingForReview(
        read: container.read,
        review: review,
      );

      expect(second.missingItemIds, isEmpty);
      expect(second.restoredItemIds, isEmpty);
      expect(
        container
            .read(routineNotifierProvider)
            .items
            .where((item) => item.id == 'imported-review-1-candidate-1'),
        hasLength(1),
      );
      expect(review.blocksDuplicateApply, isTrue);
    },
  );

  test('Accepted review restore works after repository fetch', () async {
    final repository = FakeRoutineImportReviewRepository();
    final review = _acceptedReview();
    await repository.saveReview(review);
    final container = ProviderContainer(
      overrides: [
        routineImportReviewRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final result = await const RoutineImportAppliedRestoreService()
        .restoreMissingAcceptedReviews(read: container.read, uid: review.uid);
    final second = await const RoutineImportAppliedRestoreService()
        .restoreMissingAcceptedReviews(read: container.read, uid: review.uid);

    expect(result.missingItemIds, ['imported-review-1-candidate-1']);
    expect(result.restoredItemIds, ['imported-review-1-candidate-1']);
    expect(second.missingItemIds, isEmpty);
    expect(second.restoredItemIds, isEmpty);
    expect(
      container
          .read(routineNotifierProvider)
          .items
          .where((item) => item.id == 'imported-review-1-candidate-1'),
      hasLength(1),
    );
  });

  test('Eating source uses eating category', () {
    final review = const RoutineImportExtractionService().buildReviewDraft(
      uid: 'uid-1',
      source: RoutineImportReviewSource.eating,
      onboardingDraft: _draftWithUploadReferences(),
    );

    expect(review.candidateBlocks.first.category, RoutineCategory.eating.name);
  });

  test('Skin Care source uses skin care category', () {
    final review = const RoutineImportExtractionService().buildReviewDraft(
      uid: 'uid-1',
      source: RoutineImportReviewSource.skinCare,
      onboardingDraft: _draftWithUploadReferences(),
    );

    expect(
      review.candidateBlocks.first.category,
      RoutineCategory.skinCare.name,
    );
  });

  test('Work source uses job/work category', () {
    final review = const RoutineImportExtractionService().buildReviewDraft(
      uid: 'uid-1',
      source: RoutineImportReviewSource.work,
      onboardingDraft: _draftWithWorkUploadReference(),
    );

    expect(review.candidateBlocks.first.category, RoutineCategory.job.name);
  });

  test('No local preview path or image bytes are serialized', () {
    final asset = UploadedAsset(
      assetId: 'asset',
      ownerUid: 'uid',
      sourceFeature: OnboardingDraft.sourceOnboarding,
      purpose: UploadedAssetPurpose.workSchedule,
      fileName: 'photo.jpg',
      contentType: 'image/jpeg',
      sizeBytes: 42,
      r2Key: 'users/uid/onboarding/work_schedule/asset.jpg',
      localPreviewPath: '/tmp/photo.jpg',
      status: UploadedAssetStatus.uploaded,
      createdAt: DateTime.utc(2026, 6, 2),
      updatedAt: DateTime.utc(2026, 6, 2),
    );
    final review = RoutineImportReviewDraft(
      id: 'review-1',
      uid: 'uid',
      source: RoutineImportReviewSource.work,
      status: RoutineImportReviewStatus.needsReview,
      sourceLabel: 'Work',
      candidateBlocks: [_candidate(sourceAssetId: 'asset')],
      createdAt: DateTime.utc(2026, 6, 2),
      updatedAt: DateTime.utc(2026, 6, 2),
    );

    expect(asset.toFirestoreMap().containsKey('localPreviewPath'), isFalse);
    expect(review.toMap().toString(), isNot(contains('localPreviewPath')));
    expect(review.toMap().toString(), isNot(contains('imageBytes')));
  });

  test('RoutineImportExtractionResult supports future strict candidates', () {
    final now = DateTime.utc(2026, 6, 2);
    final result = RoutineImportExtractionResult(
      id: 'extract-1',
      uid: 'uid-1',
      source: RoutineImportReviewSource.work,
      engine: 'manualSeed',
      engineVersion: 'phase2c',
      sourceAssetId: 'asset-1',
      sourceR2Key: 'users/uid/onboarding/work_schedule/asset-1.jpg',
      candidates: [_candidate()],
      createdAt: now,
    );

    final roundTrip = RoutineImportExtractionResult.fromMap(result.toMap());

    expect(roundTrip.engine, 'manualSeed');
    expect(roundTrip.source, RoutineImportReviewSource.work);
    expect(roundTrip.sourceAssetId, 'asset-1');
    expect(roundTrip.rawText, isNull);
    expect(
      roundTrip.candidates.single.candidateType,
      RoutineImportCandidateType.block,
    );
  });
}

RoutineImportReviewDraft _acceptedReview({
  List<String> appliedRoutineItemIds = const ['imported-review-1-candidate-1'],
}) {
  return RoutineImportReviewDraft(
    id: 'review-1',
    uid: 'uid-1',
    source: RoutineImportReviewSource.classes,
    status: RoutineImportReviewStatus.accepted,
    sourceLabel: 'Classes',
    candidateBlocks: [_candidate()],
    acceptedCandidateIds: const ['candidate-1'],
    appliedRoutineItemIds: appliedRoutineItemIds,
    appliedAt: DateTime.utc(2026, 6, 2),
    createdAt: DateTime.utc(2026, 6, 2),
    updatedAt: DateTime.utc(2026, 6, 2),
  );
}

RoutineImportCandidateBlock _candidate({
  String id = 'candidate-1',
  String title = 'Candidate block',
  int startMinute = 9 * 60,
  int endMinute = 10 * 60,
  List<int> repeatDays = const [1, 3, 5],
  String blockType = TimelineBlockDraft.hardBlockKey,
  String category = 'classBlock',
  bool hardBlock = true,
  bool selected = true,
  bool needsManualReview = false,
  RoutineImportCandidateType candidateType = RoutineImportCandidateType.block,
  double? confidenceScore,
  String? confidenceLabel,
  List<String> validationIssues = const [],
  String? sourceAssetId,
  String? sourceR2Key,
  String? sourceTextSnippet,
  String extractionEngine = 'manualSeed',
  String? extractionVersion,
  List<String> steps = const [],
  bool hasFixedTime = true,
  int? suggestedStartMinute,
  int? suggestedEndMinute,
  int? sourcePageIndex,
  int? sourceImageIndex,
  String? sourceRowLabel,
  String? sourceColumnLabel,
  Map<String, dynamic>? sourceBoundingBox,
}) {
  return RoutineImportCandidateBlock(
    id: id,
    title: title,
    startMinute: startMinute,
    endMinute: endMinute,
    hasFixedTime: hasFixedTime,
    suggestedStartMinute: suggestedStartMinute,
    suggestedEndMinute: suggestedEndMinute,
    repeatDays: repeatDays,
    blockType: blockType,
    category: category,
    hardBlock: hardBlock,
    selected: selected,
    needsManualReview: needsManualReview,
    candidateType: candidateType,
    confidenceScore: confidenceScore,
    confidenceLabel: confidenceLabel,
    validationIssues: validationIssues,
    sourceAssetId: sourceAssetId,
    sourceR2Key: sourceR2Key,
    sourceTextSnippet: sourceTextSnippet,
    sourcePageIndex: sourcePageIndex,
    sourceImageIndex: sourceImageIndex,
    sourceRowLabel: sourceRowLabel,
    sourceColumnLabel: sourceColumnLabel,
    sourceBoundingBox: sourceBoundingBox,
    extractionEngine: extractionEngine,
    extractionVersion: extractionVersion,
    steps: steps,
  );
}

RoutineItem _routineItem({bool hardBlock = true}) {
  return RoutineItem(
    id: 'existing-1',
    title: 'Existing block',
    startMinute: 9 * 60 + 15,
    endMinute: 9 * 60 + 45,
    repeatDays: const [1, 3, 5],
    blockType: hardBlock
        ? RoutineBlockType.hardBlock
        : RoutineBlockType.softBlock,
    hardBlock: hardBlock,
    category: RoutineCategory.fixed,
  );
}

OnboardingDraft _draftWithUploadReferences() {
  final now = DateTime.utc(2026, 6, 2, 8);
  return OnboardingDraft(
    uid: 'uid-1',
    baseTimeline: BaseTimelineDraft(
      pendingFutureImports: [
        PendingFutureImportDraft(
          id: 'classes_photo',
          section: 'Classes',
          mode: 'Photo Upload',
          createdAt: now,
          uploadedAssetId: 'class-asset',
          uploadedAssetR2Key:
              'users/uid-1/onboarding/class_timetable/class-asset.jpg',
          uploadedAssetStatus: 'uploaded',
        ),
        PendingFutureImportDraft(
          id: 'work_photo',
          section: 'Job / Work / Business',
          mode: 'Photo Upload',
          createdAt: now,
          uploadedAssetId: 'work-asset',
          uploadedAssetR2Key:
              'users/uid-1/onboarding/work_schedule/work-asset.jpg',
          uploadedAssetStatus: 'uploaded',
        ),
        PendingFutureImportDraft(
          id: 'eating_photo',
          section: 'Eating',
          mode: 'Photo Upload',
          createdAt: now,
          uploadedAssetId: 'menu-asset',
          uploadedAssetR2Key:
              'users/uid-1/onboarding/eating_menu/menu-asset.jpg',
          uploadedAssetStatus: 'uploaded',
        ),
        PendingFutureImportDraft(
          id: 'skin_photo',
          section: 'Skin Care',
          mode: 'Photo Upload',
          createdAt: now,
          uploadedAssetId: 'skin-asset',
          uploadedAssetR2Key: 'users/uid-1/onboarding/skin_care/skin-asset.jpg',
          uploadedAssetStatus: 'uploaded',
        ),
      ],
    ),
  );
}

OnboardingDraft _draftWithWorkUploadReference() {
  final now = DateTime.utc(2026, 6, 2, 8);
  return OnboardingDraft(
    uid: 'uid-1',
    baseTimeline: BaseTimelineDraft(
      pendingFutureImports: [
        PendingFutureImportDraft(
          id: 'work_photo',
          section: 'Job / Work / Business',
          mode: 'Photo Upload',
          createdAt: now,
          uploadedAssetId: 'work-asset',
          uploadedAssetR2Key:
              'users/uid-1/onboarding/work_schedule/work-asset.jpg',
          uploadedAssetStatus: 'uploaded',
        ),
      ],
    ),
  );
}

OnboardingCompletionBundle _completionBundleWithWorkAsset() {
  final now = DateTime.utc(2026, 6, 2, 8);
  return OnboardingCompletionBundle(
    uid: 'uid-1',
    createdAt: now,
    updatedAt: now,
    userProfilePatch: const {'onboardingCompleted': true},
    baseTimelineBlocks: const [
      TimelineBlockDraft(
        id: 'work-block',
        section: 'job_work_business',
        title: 'Office shift',
        startMinute: 9 * 60,
        endMinute: 17 * 60,
        repeatDays: [1, 2, 3, 4, 5],
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
    ],
    finalTimelineItems: const [],
    routineItemsForApp: const [],
    goodHabitTemplates: const [],
    badHabitCheckIns: const [],
    identityGoalSystems: const [],
    notificationPreferences: NotificationPreferences(),
    coachPreferences: CoachPreferences(),
    moneyGoal: null,
    uploadedAssetReferences: [
      OnboardingUploadedAssetReference(
        id: 'work_photo',
        section: 'Job / Work / Business',
        mode: 'Photo Upload',
        uploadedAssetId: 'work-asset',
        uploadedAssetR2Key:
            'users/uid-1/onboarding/work_schedule/work-asset.jpg',
        uploadedAssetStatus: 'uploaded',
        createdAt: now,
        updatedAt: now,
      ),
    ],
    warnings: const [],
    duplicateSystemKeysMerged: const [],
  );
}
