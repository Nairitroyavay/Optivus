import 'package:optivus/models/habit_system_record.dart';

enum HabitSystemOperationType {
  create,
  edit,
  pause,
  resume,
  archive,
  restore,
  linkRoutine,
  unlinkRoutine,
  onboardingProjection,
}

class CreateHabitSystemCommand {
  final String operationId;
  final String ownerUid;
  final String title;
  final String description;
  final String category;
  final HabitSystemType type;
  final String source;
  final List<String> linkedRoutineIds;
  final String? onboardingSourceId;

  const CreateHabitSystemCommand({
    required this.operationId,
    required this.ownerUid,
    required this.title,
    this.description = '',
    required this.category,
    required this.type,
    required this.source,
    this.linkedRoutineIds = const [],
    this.onboardingSourceId,
  });
}

class HabitSystemWriteResult {
  final bool success;
  final HabitSystemRecord? system;
  final String? error;
  final List<String> expectedSystemIds;
  final List<String> appliedSystemIds;
  final List<String> createdSystemIds;
  final List<String> existingSystemIds;
  final List<String> repairedSystemIds;
  final List<String> failedSystemIds;
  final String? projectionStatus;

  const HabitSystemWriteResult.success(
    this.system, {
    this.expectedSystemIds = const [],
    this.appliedSystemIds = const [],
    this.createdSystemIds = const [],
    this.existingSystemIds = const [],
    this.repairedSystemIds = const [],
    this.failedSystemIds = const [],
    this.projectionStatus,
  }) : success = true,
       error = null;

  const HabitSystemWriteResult.failure(
    this.error, {
    this.expectedSystemIds = const [],
    this.appliedSystemIds = const [],
    this.createdSystemIds = const [],
    this.existingSystemIds = const [],
    this.repairedSystemIds = const [],
    this.failedSystemIds = const [],
    this.projectionStatus,
  }) : success = false,
       system = null;

  bool get hasProjectionMetadata =>
      expectedSystemIds.isNotEmpty ||
      appliedSystemIds.isNotEmpty ||
      failedSystemIds.isNotEmpty ||
      projectionStatus != null;

  bool get hasProjectionFailures => failedSystemIds.isNotEmpty;
}

class RetryPayload {
  final Map<String, dynamic> data;

  const RetryPayload(this.data);
}

class FailedHabitSystemOperation {
  final String operationId;
  final HabitSystemOperationType type;
  final String? systemId;
  final String userMessage;
  final Object? originalError;
  final DateTime failedAt;
  final RetryPayload retryPayload;

  const FailedHabitSystemOperation({
    required this.operationId,
    required this.type,
    this.systemId,
    required this.userMessage,
    this.originalError,
    required this.failedAt,
    required this.retryPayload,
  });
}

class HabitSystemWriteConflict implements Exception {
  final String message;
  const HabitSystemWriteConflict(this.message);
  @override
  String toString() => 'HabitSystemWriteConflict: $message';
}
