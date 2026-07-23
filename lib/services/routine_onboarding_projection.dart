import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/repositories/routine_firestore_codec.dart';

class RoutineOnboardingProjectionPlan {
  final String ownerUid;
  final String projectionId;
  final String fingerprint;
  final String sourceBundleId;
  final List<RoutineItem> items;
  final RoutineProjectionReceipt receipt;

  const RoutineOnboardingProjectionPlan({
    required this.ownerUid,
    required this.projectionId,
    required this.fingerprint,
    required this.sourceBundleId,
    required this.items,
    required this.receipt,
  });
}

class RoutineOnboardingProjection {
  const RoutineOnboardingProjection._();

  static RoutineOnboardingProjectionPlan build(
    OnboardingCompletionBundle bundle, {
    DateTime? now,
  }) {
    validateOwnerUid(bundle.uid);
    final normalized = <RoutineItem>[];
    final usedIds = <String>{};
    for (var index = 0; index < bundle.routineItemsForApp.length; index++) {
      final source = bundle.routineItemsForApp[index];
      final sourceKey = source.id.trim().isEmpty
          ? _semanticSourceKey(source)
          : source.id.trim();
      var id = stableRoutineDocumentId(
        ownerUid: bundle.uid,
        sourceItemId: sourceKey,
      );
      if (!usedIds.add(id)) {
        id = stableRoutineDocumentId(
          ownerUid: bundle.uid,
          sourceItemId:
              '$sourceKey|${_semanticSourceKey(source)}|duplicate:$index',
        );
        usedIds.add(id);
      }
      normalized.add(
        source.copyWith(
          id: id,
          userId: bundle.uid,
          schemaVersion: RoutineItem.currentSchemaVersion,
          onboardingSourceItemId: sourceKey,
          source: RoutineSource.onboarding,
          status: RoutineStatus.planned,
          isCompleted: false,
          isMissed: false,
          clearConflict: true,
        ),
      );
    }

    final fingerprint = _fingerprint(bundle, normalized);
    // The initial setup slot is intentionally fixed. A changed bundle does not
    // become an implicit rebuild that can resurrect deleted starter items.
    const projectionId = 'onboarding-initial-v1';
    final sourceBundleId =
        'bundle-v${bundle.version}-${fingerprint.substring(0, 32)}';
    final projectedItems = normalized
        .map((item) => item.copyWith(onboardingProjectionId: projectionId))
        .toList(growable: false);
    final timestamp = (now ?? DateTime.now()).toUtc();
    final receipt = RoutineProjectionReceipt(
      id: projectionId,
      ownerUid: bundle.uid,
      sourceBundleSchemaVersion: bundle.version,
      sourceBundleId: sourceBundleId,
      sourceBundleFingerprint: fingerprint,
      projectedItemIds: projectedItems
          .map((item) => item.id)
          .toList(growable: false),
      createdAt: timestamp,
      completedAt: timestamp,
    );

    return RoutineOnboardingProjectionPlan(
      ownerUid: bundle.uid,
      projectionId: projectionId,
      fingerprint: fingerprint,
      sourceBundleId: sourceBundleId,
      items: projectedItems,
      receipt: receipt,
    );
  }

  static String stableRoutineDocumentId({
    required String ownerUid,
    required String sourceItemId,
  }) {
    validateOwnerUid(ownerUid);
    final source = sourceItemId.trim();
    if (source.isEmpty) {
      throw ArgumentError('Onboarding Routine source item ID is required.');
    }
    final digest = sha256.convert(
      utf8.encode('routine-onboarding-v1\u001f$ownerUid\u001f$source'),
    );
    return 'onb_${digest.toString().substring(0, 40)}';
  }

  static String _fingerprint(
    OnboardingCompletionBundle bundle,
    List<RoutineItem> items,
  ) {
    const codec = RoutineTemplateFirestoreCodec();
    final documents =
        items.map((item) {
            final data = codec.toFirestore(ownerUid: bundle.uid, item: item);
            data.remove('createdAt');
            data.remove('updatedAt');
            return Map<String, dynamic>.fromEntries(
              data.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
            );
          }).toList()
          ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    final identity = jsonEncode({
      'contractVersion': 1,
      'ownerUid': bundle.uid,
      'source': bundle.source,
      'sourceBundleSchemaVersion': bundle.version,
      'routineItems': documents,
    });
    return sha256.convert(utf8.encode(identity)).toString();
  }

  static String _semanticSourceKey(RoutineItem item) {
    return [
      item.title.trim().toLowerCase(),
      item.category.name,
      item.blockType.name,
      item.startMinute,
      item.endMinute,
      [...item.repeatDays]..sort(),
    ].join('\u001f');
  }
}
