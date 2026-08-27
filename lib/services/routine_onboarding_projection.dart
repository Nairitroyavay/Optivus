import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:optivus/features/routine/domain/conflict_policy.dart';
import 'package:optivus/models/conflict_acceptance.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/repositories/routine_firestore_codec.dart';

class RoutineOnboardingProjectionPlan {
  final String ownerUid;
  final String slot;
  final int revision;
  final String projectionId;
  final String fingerprint;
  final String sourceBundleId;
  final List<RoutineItem> items;
  final List<ConflictAcceptance> conflictAcceptances;
  final RoutineProjectionReceipt receipt;

  const RoutineOnboardingProjectionPlan({
    required this.ownerUid,
    this.slot = 'onboarding-initial',
    this.revision = 1,
    required this.projectionId,
    required this.fingerprint,
    required this.sourceBundleId,
    required this.items,
    required this.conflictAcceptances,
    required this.receipt,
  });
}

class RoutineOnboardingProjection {
  const RoutineOnboardingProjection._();

  static RoutineOnboardingProjectionPlan build(
    OnboardingCompletionBundle bundle, {
    String? slot,
    int revision = 1,
    DateTime? now,
  }) {
    validateOwnerUid(bundle.uid);
    final resolvedSlot =
        slot ??
        (bundle.runId.isEmpty
            ? 'onboarding-legacy'
            : 'onboarding-${bundle.runId}');
    final normalized = <RoutineItem>[];
    final usedIds = <String>{};
    final occurrenceCounts = <String, int>{};
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
        final count = (occurrenceCounts[sourceKey] ?? 0) + 1;
        occurrenceCounts[sourceKey] = count;
        id = stableRoutineDocumentId(
          ownerUid: bundle.uid,
          sourceItemId:
              '$sourceKey|${_semanticSourceKey(source)}|duplicate:$count',
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

    final projectionId = '$resolvedSlot-v$revision';
    final projectedItems = normalized
        .map((item) => item.copyWith(onboardingProjectionId: projectionId))
        .toList(growable: false);
    final projectedAcceptances = _projectAcceptances(
      bundle,
      projectedItems,
      projectionId: projectionId,
      revision: revision,
    );
    final fingerprint = _fingerprint(
      bundle,
      projectedItems,
      projectedAcceptances,
    );
    final sourceBundleId =
        'bundle-v${bundle.version}-${fingerprint.substring(0, 32)}';
    final timestamp = (now ?? DateTime.now()).toUtc();
    final receipt = RoutineProjectionReceipt(
      id: projectionId,
      ownerUid: bundle.uid,
      slot: resolvedSlot,
      revision: revision,
      sourceBundleSchemaVersion: bundle.version,
      sourceBundleId: sourceBundleId,
      sourceBundleFingerprint: fingerprint,
      projectedItemIds: projectedItems
          .map((item) => item.id)
          .toList(growable: false),
      status: 'pending',
      cursor: 0,
      createdAt: timestamp,
      updatedAt: timestamp,
    );

    return RoutineOnboardingProjectionPlan(
      ownerUid: bundle.uid,
      slot: resolvedSlot,
      revision: revision,
      projectionId: projectionId,
      fingerprint: fingerprint,
      sourceBundleId: sourceBundleId,
      items: projectedItems,
      conflictAcceptances: projectedAcceptances,
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
    List<ConflictAcceptance> acceptances,
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
      'conflictAcceptances':
          acceptances.map((acceptance) {
            final map = acceptance.toMap()
              ..remove('acceptedAt')
              ..remove('invalidatedAt');
            return Map<String, dynamic>.fromEntries(
              map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
            );
          }).toList()..sort(
            (a, b) => (a['acceptanceId'] as String).compareTo(
              b['acceptanceId'] as String,
            ),
          ),
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

  static List<ConflictAcceptance> _projectAcceptances(
    OnboardingCompletionBundle bundle,
    List<RoutineItem> items, {
    required String projectionId,
    required int revision,
  }) {
    final bySourceId = <String, List<RoutineItem>>{};
    for (final item in items) {
      bySourceId
          .putIfAbsent(item.onboardingSourceItemId ?? '', () => [])
          .add(item);
    }
    final projected = <ConflictAcceptance>[];
    for (final sourceAcceptance in bundle.conflictAcceptances) {
      if (!sourceAcceptance.isActive ||
          sourceAcceptance.ownerUid != bundle.uid ||
          sourceAcceptance.projectionId.isNotEmpty ||
          sourceAcceptance.sourceBundleFingerprint.isNotEmpty) {
        continue;
      }
      final firstCandidates =
          bySourceId[sourceAcceptance.firstSourceBlockId] ?? const [];
      final secondCandidates =
          bySourceId[sourceAcceptance.secondSourceBlockId] ?? const [];
      if (firstCandidates.length != 1 || secondCandidates.length != 1) {
        throw StateError(
          'Conflict acceptance source-to-Routine projection is ambiguous.',
        );
      }
      final firstItem = firstCandidates.single;
      final secondItem = secondCandidates.single;
      final first = _routineDescriptor(
        firstItem,
        timezoneId: sourceAcceptance.timezoneId,
        revision: revision,
      );
      final second = _routineDescriptor(
        secondItem,
        timezoneId: sourceAcceptance.timezoneId,
        revision: revision,
      );
      final decision = ConflictPolicy.classify(first, second);
      if (!decision.canKeepBoth ||
          decision.type.name != sourceAcceptance.conflictType) {
        throw StateError('Conflict acceptance no longer matches policy.');
      }
      projected.add(
        ConflictAcceptance.create(
          ownerUid: bundle.uid,
          first: first,
          second: second,
          conflictType: sourceAcceptance.conflictType,
          scope: sourceAcceptance.scope,
          applicableWeekdays: sourceAcceptance.applicableWeekdays,
          timezoneId: sourceAcceptance.timezoneId,
          acceptedFrom: sourceAcceptance.acceptedFrom,
          dateKey: sourceAcceptance.dateKey,
          sourceBundleFingerprint: bundle.effectiveSourceFingerprint,
          projectionId: projectionId,
          firstProjectedRoutineId: firstItem.id,
          secondProjectedRoutineId: secondItem.id,
          acceptedAt: sourceAcceptance.acceptedAt,
        ),
      );
    }
    projected.sort((a, b) => a.acceptanceId.compareTo(b.acceptanceId));
    return projected;
  }

  static ConflictScheduleDescriptor _routineDescriptor(
    RoutineItem item, {
    required String timezoneId,
    required int revision,
  }) {
    final repeatDays = item.repeatDays.toSet().toList()..sort();
    return ConflictScheduleDescriptor(
      ownerUid: item.userId ?? '',
      itemId: item.id,
      sourceItemId: item.onboardingSourceItemId ?? item.id,
      startMinute: item.startMinute,
      endMinute: item.endMinute,
      crossesMidnight: item.crossesMidnight,
      endsNextDay: item.endsNextDay,
      dateKey: item.date == null ? '' : _dateKey(item.date!),
      endDateKey: item.endDate == null ? '' : _dateKey(item.endDate!),
      repeatRule:
          item.repeatRule ?? (repeatDays.length == 7 ? 'daily' : 'weekly'),
      repeatDays: repeatDays,
      blockType: item.blockType.name,
      hardBlock: item.isHardBlock,
      category: switch (item.category) {
        RoutineCategory.classBlock => ConflictSemanticCategory.classBlock,
        RoutineCategory.job => ConflictSemanticCategory.job,
        RoutineCategory.eating => ConflictSemanticCategory.meal,
        RoutineCategory.sleep => ConflictSemanticCategory.sleep,
        RoutineCategory.fixed => ConflictSemanticCategory.fixed,
        _ => ConflictSemanticCategory.other,
      },
      timezoneId: timezoneId,
      source: item.source.name,
      activeStatus: 'active',
      projectionId: item.onboardingProjectionId ?? '',
      revision: revision,
      schemaVersion: item.schemaVersion,
    );
  }

  static String _dateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
