import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/services/routine_import_validation_service.dart';

class RoutineImportAiReviewUpdateService {
  final RoutineImportValidationService _validationService;

  const RoutineImportAiReviewUpdateService({
    RoutineImportValidationService validationService =
        const RoutineImportValidationService(),
  }) : _validationService = validationService;

  RoutineImportReviewDraft applySuccessfulExtraction({
    required RoutineImportReviewDraft review,
    required RoutineImportExtractionResult result,
    List<RoutineItem> existingRoutineItems = const [],
    DateTime? now,
  }) {
    final appliedAt = now ?? DateTime.now();
    final normalizedCandidates = [
      for (final candidate in result.candidates)
        candidate.copyWith(
          sourceAssetId: candidate.sourceAssetId ?? review.uploadedAssetId,
          sourceR2Key: candidate.sourceR2Key ?? review.uploadedAssetR2Key,
          extractionEngine: candidate.extractionEngine.trim().isEmpty
              ? result.engine
              : candidate.extractionEngine,
          extractionVersion:
              candidate.extractionVersion ?? result.engineVersion,
        ),
    ];
    final validation = _validationService.validateCandidates(
      candidates: normalizedCandidates,
      existingRoutineItems: existingRoutineItems,
    );
    final candidatesWithValidation = [
      for (final candidate in normalizedCandidates)
        candidate.copyWith(
          validationIssues: validation.messagesFor(candidate.id),
        ),
    ];

    return review.copyWith(
      candidateBlocks: candidatesWithValidation,
      warnings: _mergedWarnings(review.warnings, result.warnings),
      status: RoutineImportReviewStatus.needsReview,
      extractionEngine: result.engine,
      extractionVersion: result.engineVersion,
      lastExtractedAt: appliedAt,
      extractionWarnings: result.warnings,
      extractionAttemptCount: review.extractionAttemptCount + 1,
      updatedAt: appliedAt,
    );
  }

  RoutineImportReviewDraft recordExtractionWarning({
    required RoutineImportReviewDraft review,
    required RoutineImportExtractionResult result,
    DateTime? now,
  }) {
    final failedAt = now ?? DateTime.now();
    return review.copyWith(
      extractionEngine: result.engine,
      extractionVersion: result.engineVersion,
      lastExtractedAt: failedAt,
      extractionWarnings: result.warnings,
      extractionAttemptCount: review.extractionAttemptCount + 1,
      warnings: _mergedWarnings(review.warnings, result.warnings),
      updatedAt: failedAt,
    );
  }

  List<String> _mergedWarnings(List<String> current, List<String> incoming) {
    return {...current, ...incoming}.toList(growable: false);
  }
}
