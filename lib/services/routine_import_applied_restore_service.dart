import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/repositories/routine_import_review_repository.dart';
import 'package:optivus/services/onboarding_frontend_hydration_service.dart';
import 'package:optivus/services/routine_import_conversion_service.dart';
import 'package:optivus/state/app_state.dart';

class RoutineImportAppliedRestoreResult {
  final List<String> expectedItemIds;
  final List<String> missingItemIds;
  final List<String> restoredItemIds;

  const RoutineImportAppliedRestoreResult({
    required this.expectedItemIds,
    required this.missingItemIds,
    required this.restoredItemIds,
  });

  bool get hasMissingItems => missingItemIds.isNotEmpty;
  bool get restoredAny => restoredItemIds.isNotEmpty;
}

class RoutineImportAppliedRestoreService {
  final RoutineImportConversionService _conversionService;

  const RoutineImportAppliedRestoreService({
    RoutineImportConversionService conversionService =
        const RoutineImportConversionService(),
  }) : _conversionService = conversionService;

  List<RoutineItem> restorableItemsForReview(RoutineImportReviewDraft review) {
    if (!_isAcceptedStatus(review.status)) return const [];
    final acceptedCandidates = _acceptedCandidates(review);
    if (acceptedCandidates.isEmpty) return const [];
    return _conversionService.convertAcceptedCandidates(
      reviewId: review.id,
      candidates: acceptedCandidates,
    );
  }

  List<RoutineItem> missingItemsForReview({
    required RoutineImportReviewDraft review,
    required List<RoutineItem> currentItems,
  }) {
    final existingIds = currentItems.map((item) => item.id).toSet();
    return restorableItemsForReview(
      review,
    ).where((item) => !existingIds.contains(item.id)).toList(growable: false);
  }

  Future<RoutineImportAppliedRestoreResult> restoreMissingForReview({
    required OptivusProviderReader read,
    required RoutineImportReviewDraft review,
  }) async {
    final expectedItems = restorableItemsForReview(
      review,
    ).map((item) => item.copyWith(userId: review.uid)).toList(growable: false);
    final expectedItemIds = expectedItems
        .map((item) => item.id)
        .toList(growable: false);
    final currentRoutineItems = read(routineNotifierProvider).items;
    final currentIds = currentRoutineItems.map((item) => item.id).toSet();
    final missing = expectedItems
        .where((item) => !currentIds.contains(item.id))
        .toList(growable: false);

    read(mockRoutineProvider.notifier).mergeMissing(expectedItems);
    final restoredIds = await read(
      routineNotifierProvider.notifier,
    ).addMissingItems(missing);

    return RoutineImportAppliedRestoreResult(
      expectedItemIds: expectedItemIds,
      missingItemIds: missing.map((item) => item.id).toList(growable: false),
      restoredItemIds: restoredIds,
    );
  }

  Future<RoutineImportAppliedRestoreResult> restoreMissingAcceptedReviews({
    required OptivusProviderReader read,
    required String uid,
  }) async {
    final reviews = await read(
      routineImportReviewRepositoryProvider,
    ).fetchReviews(uid);
    final acceptedReviews = reviews.where(
      (review) => _isAcceptedStatus(review.status),
    );
    final expectedIds = <String>[];
    final missingIds = <String>[];
    final restoredIds = <String>[];

    for (final review in acceptedReviews) {
      final result = await restoreMissingForReview(
        read: read,
        review: review.copyWith(uid: uid),
      );
      expectedIds.addAll(result.expectedItemIds);
      missingIds.addAll(result.missingItemIds);
      restoredIds.addAll(result.restoredItemIds);
    }

    return RoutineImportAppliedRestoreResult(
      expectedItemIds: expectedIds,
      missingItemIds: missingIds,
      restoredItemIds: restoredIds,
    );
  }

  bool _isAcceptedStatus(RoutineImportReviewStatus status) {
    return status == RoutineImportReviewStatus.accepted ||
        status == RoutineImportReviewStatus.partiallyAccepted;
  }

  List<RoutineImportCandidateBlock> _acceptedCandidates(
    RoutineImportReviewDraft review,
  ) {
    final acceptedIds = review.acceptedCandidateIds.toSet();
    final candidates = acceptedIds.isEmpty
        ? review.candidateBlocks.where((candidate) => candidate.selected)
        : review.candidateBlocks.where(
            (candidate) => acceptedIds.contains(candidate.id),
          );
    return candidates
        .map((candidate) => candidate.copyWith(selected: true))
        .toList(growable: false);
  }
}
