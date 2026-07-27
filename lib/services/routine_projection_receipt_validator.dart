import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';

class ReceiptValidationResult {
  final bool isValid;
  final String? failureReason;

  const ReceiptValidationResult.valid() : isValid = true, failureReason = null;

  const ReceiptValidationResult.invalid(this.failureReason) : isValid = false;

  @override
  String toString() => isValid
      ? 'ReceiptValidationResult.valid'
      : 'ReceiptValidationResult.invalid($failureReason)';
}

class RoutineProjectionReceiptValidator {
  const RoutineProjectionReceiptValidator();

  ReceiptValidationResult validate({
    required RoutineProjectionReceipt? receipt,
    required List<RoutineItem> actualItems,
    required String ownerUid,
    required RoutineOnboardingProjectionPlan plan,
  }) {
    if (receipt == null) {
      return const ReceiptValidationResult.invalid(
        'Projection receipt is missing.',
      );
    }
    if (receipt.ownerUid != ownerUid) {
      return const ReceiptValidationResult.invalid(
        'Receipt owner UID mismatch.',
      );
    }
    if (receipt.id != plan.projectionId || receipt.slot != plan.slot) {
      return const ReceiptValidationResult.invalid(
        'Receipt projection slot mismatch.',
      );
    }
    if (receipt.revision != plan.revision) {
      return const ReceiptValidationResult.invalid(
        'Receipt projection revision mismatch.',
      );
    }
    if (receipt.source != 'onboarding') {
      return const ReceiptValidationResult.invalid('Receipt source mismatch.');
    }
    if (receipt.sourceBundleSchemaVersion !=
        plan.receipt.sourceBundleSchemaVersion) {
      return const ReceiptValidationResult.invalid(
        'Receipt source bundle schema mismatch.',
      );
    }
    if (receipt.sourceBundleId != plan.sourceBundleId) {
      return const ReceiptValidationResult.invalid(
        'Receipt source bundle ID mismatch.',
      );
    }
    if (receipt.sourceBundleFingerprint != plan.fingerprint) {
      return const ReceiptValidationResult.invalid(
        'Receipt fingerprint mismatch.',
      );
    }
    if (receipt.eventSchemaVersion !=
        RoutineProjectionReceipt.currentEventSchemaVersion) {
      return const ReceiptValidationResult.invalid(
        'Receipt event schema version mismatch.',
      );
    }
    if (receipt.schemaVersion !=
        RoutineProjectionReceipt.currentSchemaVersion) {
      return const ReceiptValidationResult.invalid(
        'Receipt schema version mismatch.',
      );
    }
    if (receipt.status != 'pending' && receipt.status != 'completed') {
      return const ReceiptValidationResult.invalid('Receipt status mismatch.');
    }
    if (receipt.failedItemIds.isNotEmpty) {
      return const ReceiptValidationResult.invalid(
        'Receipt contains failed item IDs.',
      );
    }

    final expectedItemIds = plan.items.map((item) => item.id).toSet();
    final receiptExpectedIds = receipt.expectedItemIds.toSet();
    if (receiptExpectedIds.difference(expectedItemIds).isNotEmpty ||
        expectedItemIds.difference(receiptExpectedIds).isNotEmpty) {
      return const ReceiptValidationResult.invalid(
        'Receipt expected item IDs mismatch.',
      );
    }
    final receiptProjectedIds = receipt.projectedItemIds.toSet();
    if (receiptProjectedIds.difference(expectedItemIds).isNotEmpty ||
        expectedItemIds.difference(receiptProjectedIds).isNotEmpty) {
      return const ReceiptValidationResult.invalid(
        'Receipt projected item IDs mismatch.',
      );
    }
    if (receipt.totalCount != expectedItemIds.length ||
        receipt.cursor < 0 ||
        receipt.cursor > receipt.totalCount ||
        (receipt.status == 'completed' &&
            receipt.cursor != receipt.totalCount)) {
      return const ReceiptValidationResult.invalid(
        'Receipt cursor or count mismatch.',
      );
    }

    final actualItemMap = {for (final item in actualItems) item.id: item};

    for (final expectedItem in plan.items) {
      final actualItem = actualItemMap[expectedItem.id];
      if (actualItem == null) {
        return ReceiptValidationResult.invalid(
          'Expected routine item missing: ${expectedItem.id}',
        );
      }
      if (actualItem.userId != ownerUid) {
        return ReceiptValidationResult.invalid(
          'Routine item owner UID mismatch: ${expectedItem.id}',
        );
      }
      if (actualItem.onboardingProjectionId != plan.projectionId) {
        return ReceiptValidationResult.invalid(
          'Routine item projection ID mismatch: ${expectedItem.id}',
        );
      }
      if (actualItem.onboardingSourceItemId !=
              expectedItem.onboardingSourceItemId ||
          actualItem.source != RoutineSource.onboarding) {
        return ReceiptValidationResult.invalid(
          'Routine item source mismatch: ${expectedItem.id}',
        );
      }
      if (actualItem.schemaVersion != RoutineItem.currentSchemaVersion) {
        return ReceiptValidationResult.invalid(
          'Routine item schema version mismatch: ${expectedItem.id}',
        );
      }
    }

    return const ReceiptValidationResult.valid();
  }
}
