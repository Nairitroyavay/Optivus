enum RoutineProjectionOutcome { projected, noOp, retryRequired }

class RoutineProjectionReceipt {
  static const int currentSchemaVersion = 1;
  static const int currentEventSchemaVersion = 1;

  final String id;
  final String ownerUid;
  final String source;
  final int sourceBundleSchemaVersion;
  final String sourceBundleId;
  final String sourceBundleFingerprint;
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

  RoutineProjectionReceipt({
    required this.id,
    required this.ownerUid,
    this.source = 'onboarding',
    required this.sourceBundleSchemaVersion,
    required this.sourceBundleId,
    required this.sourceBundleFingerprint,
    required this.projectedItemIds,
    this.eventSchemaVersion = currentEventSchemaVersion,
    int? totalCount,
    this.cursor = 0,
    this.status = 'pending',
    required this.createdAt,
    DateTime? updatedAt,
    this.completedAt,
    this.lastSafeError,
    this.schemaVersion = currentSchemaVersion,
  }) : totalCount = totalCount ?? projectedItemIds.length,
       updatedAt = updatedAt ?? createdAt;

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';

  RoutineProjectionReceipt copyWith({
    String? id,
    String? ownerUid,
    String? source,
    int? sourceBundleSchemaVersion,
    String? sourceBundleId,
    String? sourceBundleFingerprint,
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
      source: source ?? this.source,
      sourceBundleSchemaVersion:
          sourceBundleSchemaVersion ?? this.sourceBundleSchemaVersion,
      sourceBundleId: sourceBundleId ?? this.sourceBundleId,
      sourceBundleFingerprint:
          sourceBundleFingerprint ?? this.sourceBundleFingerprint,
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
