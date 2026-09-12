import 'package:cloud_firestore/cloud_firestore.dart';

enum RoutineProjectionOutcome { projected, noOp, retryRequired }

class RoutineProjectionReceipt {
  static const int currentSchemaVersion = 1;
  static const int currentEventSchemaVersion = 1;

  final String id;
  final String ownerUid;
  final String slot;
  final int revision;
  final String source;
  final int sourceBundleSchemaVersion;
  final String sourceBundleId;
  final String sourceBundleFingerprint;
  final List<String> expectedItemIds;
  final List<String> createdItemIds;
  final List<String> existingItemIds;
  final List<String> repairedItemIds;
  final List<String> failedItemIds;
  final List<String> projectedItemIds;
  final int eventSchemaVersion;
  final int totalCount;
  final int cursor;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final String? lastSafeError;
  final int schemaVersion;

  String get fingerprint => sourceBundleFingerprint;

  RoutineProjectionReceipt({
    required this.id,
    required this.ownerUid,
    this.slot = 'onboarding-initial',
    this.revision = 1,
    this.source = 'onboarding',
    required this.sourceBundleSchemaVersion,
    required this.sourceBundleId,
    required this.sourceBundleFingerprint,
    List<String>? expectedItemIds,
    List<String>? createdItemIds,
    List<String>? existingItemIds,
    List<String>? repairedItemIds,
    List<String>? failedItemIds,
    List<String>? projectedItemIds,
    this.eventSchemaVersion = currentEventSchemaVersion,
    int? totalCount,
    this.cursor = 0,
    this.status = 'pending',
    required this.createdAt,
    DateTime? updatedAt,
    this.completedAt,
    this.lastSafeError,
    this.schemaVersion = currentSchemaVersion,
  }) : createdItemIds = createdItemIds ?? projectedItemIds ?? const [],
       existingItemIds = existingItemIds ?? const [],
       repairedItemIds = repairedItemIds ?? const [],
       failedItemIds = failedItemIds ?? const [],
       projectedItemIds =
           projectedItemIds ??
           ({
             ...createdItemIds ?? [],
             ...existingItemIds ?? [],
             ...repairedItemIds ?? [],
           }.toList()..sort()),
       expectedItemIds =
           expectedItemIds ??
           ({
             ...createdItemIds ?? [],
             ...existingItemIds ?? [],
             ...repairedItemIds ?? [],
             ...failedItemIds ?? [],
             ...projectedItemIds ?? [],
           }.toList()..sort()),
       totalCount =
           totalCount ??
           (expectedItemIds != null
               ? expectedItemIds.length
               : (projectedItemIds != null
                     ? projectedItemIds.length
                     : ({
                         ...createdItemIds ?? [],
                         ...existingItemIds ?? [],
                         ...repairedItemIds ?? [],
                         ...failedItemIds ?? [],
                       }.length))),
       updatedAt = updatedAt ?? createdAt;

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';

  RoutineProjectionReceipt copyWith({
    String? id,
    String? ownerUid,
    String? slot,
    int? revision,
    String? source,
    int? sourceBundleSchemaVersion,
    String? sourceBundleId,
    String? sourceBundleFingerprint,
    List<String>? expectedItemIds,
    List<String>? createdItemIds,
    List<String>? existingItemIds,
    List<String>? repairedItemIds,
    List<String>? failedItemIds,
    List<String>? projectedItemIds,
    int? eventSchemaVersion,
    int? totalCount,
    int? cursor,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    String? lastSafeError,
    bool clearLastSafeError = false,
    int? schemaVersion,
  }) {
    return RoutineProjectionReceipt(
      id: id ?? this.id,
      ownerUid: ownerUid ?? this.ownerUid,
      slot: slot ?? this.slot,
      revision: revision ?? this.revision,
      source: source ?? this.source,
      sourceBundleSchemaVersion:
          sourceBundleSchemaVersion ?? this.sourceBundleSchemaVersion,
      sourceBundleId: sourceBundleId ?? this.sourceBundleId,
      sourceBundleFingerprint:
          sourceBundleFingerprint ?? this.sourceBundleFingerprint,
      expectedItemIds: expectedItemIds ?? this.expectedItemIds,
      createdItemIds: createdItemIds ?? this.createdItemIds,
      existingItemIds: existingItemIds ?? this.existingItemIds,
      repairedItemIds: repairedItemIds ?? this.repairedItemIds,
      failedItemIds: failedItemIds ?? this.failedItemIds,
      projectedItemIds: projectedItemIds ?? this.projectedItemIds,
      eventSchemaVersion: eventSchemaVersion ?? this.eventSchemaVersion,
      totalCount: totalCount ?? this.totalCount,
      cursor: cursor ?? this.cursor,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      lastSafeError: clearLastSafeError
          ? null
          : (lastSafeError ?? this.lastSafeError),
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'ownerUid': ownerUid,
    'source': source,
    'sourceBundleSchemaVersion': sourceBundleSchemaVersion,
    'sourceBundleId': sourceBundleId,
    'sourceBundleFingerprint': sourceBundleFingerprint,
    'projectedItemIds': projectedItemIds,
    'eventSchemaVersion': eventSchemaVersion,
    'totalCount': totalCount,
    'cursor': cursor,
    'status': status,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (completedAt != null)
      'completedAt': completedAt!.toUtc().toIso8601String(),
    if (lastSafeError != null && lastSafeError!.trim().isNotEmpty)
      'lastSafeError': lastSafeError!.trim(),
    'schemaVersion': schemaVersion,
  };

  Map<String, dynamic> toFirestoreMap() {
    final map = toMap();
    map['createdAt'] = Timestamp.fromDate(createdAt.toUtc());
    map['updatedAt'] = Timestamp.fromDate(updatedAt.toUtc());
    if (completedAt != null) {
      map['completedAt'] = Timestamp.fromDate(completedAt!.toUtc());
    }
    return map;
  }
}

class RoutineProjectionResult {
  final RoutineProjectionOutcome outcome;
  final RoutineProjectionReceipt receipt;

  const RoutineProjectionResult({required this.outcome, required this.receipt});

  bool get projected => outcome == RoutineProjectionOutcome.projected;
  bool get wasNoOp => outcome == RoutineProjectionOutcome.noOp;
  bool get retryRequired => outcome == RoutineProjectionOutcome.retryRequired;
}

class RoutineProjectionRetryRequiredException implements Exception {
  final Object cause;
  final RoutineProjectionOutcome outcome =
      RoutineProjectionOutcome.retryRequired;

  const RoutineProjectionRetryRequiredException(this.cause);

  @override
  String toString() => 'Routine projection retry required: $cause';
}

RoutineProjectionReceipt routineProjectionReceiptForCategories(
  RoutineProjectionReceipt receipt, {
  required List<String> expectedItemIds,
  required List<String> createdItemIds,
  required List<String> existingItemIds,
  required List<String> repairedItemIds,
  required List<String> failedItemIds,
}) {
  final projectedItemIds = <String>{
    ...createdItemIds,
    ...existingItemIds,
    ...repairedItemIds,
  }.toList()..sort();

  final expectedIdSet = expectedItemIds.toSet();
  final projectedIdSet = projectedItemIds.toSet();
  final accountedCount = projectedIdSet.length;
  final isCompleted =
      failedItemIds.isEmpty &&
      expectedIdSet.length == expectedItemIds.length &&
      projectedIdSet.length == expectedIdSet.length &&
      projectedIdSet.containsAll(expectedIdSet);
  return RoutineProjectionReceipt(
    id: receipt.id,
    ownerUid: receipt.ownerUid,
    slot: receipt.slot,
    revision: receipt.revision,
    source: receipt.source,
    sourceBundleSchemaVersion: receipt.sourceBundleSchemaVersion,
    sourceBundleId: receipt.sourceBundleId,
    sourceBundleFingerprint: receipt.sourceBundleFingerprint,
    expectedItemIds: expectedItemIds,
    createdItemIds: createdItemIds,
    existingItemIds: existingItemIds,
    repairedItemIds: repairedItemIds,
    failedItemIds: failedItemIds,
    projectedItemIds: projectedItemIds,
    eventSchemaVersion: receipt.eventSchemaVersion,
    status: isCompleted ? 'completed' : 'pending',
    cursor: accountedCount,
    totalCount: expectedItemIds.length,
    createdAt: receipt.createdAt,
    updatedAt: receipt.updatedAt,
    completedAt: isCompleted ? receipt.createdAt : null,
    schemaVersion: receipt.schemaVersion,
  );
}
