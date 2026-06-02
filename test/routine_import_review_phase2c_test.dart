import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/routine_import_review_repository.dart';
import 'package:optivus/services/routine_import_conversion_service.dart';
import 'package:optivus/services/routine_import_extraction_service.dart';
import 'package:optivus/services/routine_import_validation_service.dart';
import 'package:optivus/services/uploads/upload_object_key.dart';

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
      confidenceScore: 0.84,
      confidenceLabel: 'medium',
      sourceAssetId: 'asset-1',
      sourceR2Key: 'users/uid/onboarding/work_schedule/asset-1.jpg',
      sourceTextSnippet: 'Mon 9 AM work',
      validationIssues: const ['Needs room'],
      extractionEngine: 'futureAiText',
      extractionVersion: 'v1',
    );

    final roundTrip = RoutineImportCandidateBlock.fromMap(candidate.toMap());

    expect(roundTrip.candidateType, RoutineImportCandidateType.flexibleTask);
    expect(roundTrip.confidenceScore, 0.84);
    expect(roundTrip.confidenceLabel, 'medium');
    expect(roundTrip.sourceAssetId, 'asset-1');
    expect(roundTrip.sourceR2Key, contains('work_schedule'));
    expect(roundTrip.sourceTextSnippet, 'Mon 9 AM work');
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
    );

    expect(candidate.candidateType, RoutineImportCandidateType.flexibleTask);
    expect(candidate.blockType, TimelineBlockDraft.flexibleTaskKey);
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
    'Conversion service converts timed selected candidate to RoutineItem',
    () {
      final items = const RoutineImportConversionService()
          .convertAcceptedCandidates(candidates: [_candidate()]);

      expect(items, hasLength(1));
      expect(items.single.title, 'Candidate block');
      expect(items.single.blockType, RoutineBlockType.hardBlock);
    },
  );

  test('Conversion service rejects unselected candidate', () {
    final items = const RoutineImportConversionService()
        .convertAcceptedCandidates(candidates: [_candidate(selected: false)]);

    expect(items, isEmpty);
  });

  test('Conversion service puts checklist steps into notes', () {
    final items = const RoutineImportConversionService()
        .convertAcceptedCandidates(
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

  test('Validation service warns low confidence', () {
    final result = const RoutineImportValidationService().validateCandidates(
      candidates: [_candidate(confidenceLabel: 'low')],
    );

    expect(result.hasBlockingIssues, isFalse);
    expect(
      result.warningsFor('candidate-1'),
      contains('Low confidence. Review manually before saving.'),
    );
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
}) {
  return RoutineImportCandidateBlock(
    id: id,
    title: title,
    startMinute: startMinute,
    endMinute: endMinute,
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
    extractionEngine: extractionEngine,
    extractionVersion: extractionVersion,
    steps: steps,
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
