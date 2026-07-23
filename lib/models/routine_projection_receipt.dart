enum RoutineProjectionOutcome { projected, noOp, retryRequired }

class RoutineProjectionReceipt {
  static const int currentSchemaVersion = 1;

  final String id;
  final String ownerUid;
  final String source;
  final int sourceBundleSchemaVersion;
  final String sourceBundleId;
  final String sourceBundleFingerprint;
  final List<String> projectedItemIds;
  final String status;
  final DateTime createdAt;
  final DateTime completedAt;
  final int schemaVersion;

  const RoutineProjectionReceipt({
    required this.id,
    required this.ownerUid,
    this.source = 'onboarding',
    required this.sourceBundleSchemaVersion,
    required this.sourceBundleId,
    required this.sourceBundleFingerprint,
    required this.projectedItemIds,
    this.status = 'completed',
    required this.createdAt,
    required this.completedAt,
    this.schemaVersion = currentSchemaVersion,
  });
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
