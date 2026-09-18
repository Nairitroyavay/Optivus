import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:optivus/models/routine_item.dart';

class RoutineOccurrenceRecord {
  static const int currentSchemaVersion = 2;

  final String id;
  final String ownerUid;
  final String routineItemId;
  final String occurrenceDateKey;
  final RoutineStatus status;
  final String source;
  final String action;
  final String operationKey;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;
  final String? movedToDateKey;
  final int? movedStartMinute;
  final int? movedEndMinute;
  final List<int> completedSubtaskIndexes;
  final String? note;
  final String? displayTitleOverride;
  final bool undoToPlannedAllowed;
  final String? onboardingProjectionId;
  final String? onboardingSourceItemId;
  final String? sourceFingerprint;
  final DateTime? startedAt;
  final int? countdownDurationSeconds;
  final RoutineStatus? previousStatus;
  final String? previousAction;
  final String? trackerSessionId;
  final String? trackerType;

  const RoutineOccurrenceRecord({
    required this.id,
    required this.ownerUid,
    required this.routineItemId,
    required this.occurrenceDateKey,
    required this.status,
    required this.source,
    required this.action,
    required this.operationKey,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = currentSchemaVersion,
    this.movedToDateKey,
    this.movedStartMinute,
    this.movedEndMinute,
    this.completedSubtaskIndexes = const [],
    this.note,
    this.displayTitleOverride,
    this.undoToPlannedAllowed = false,
    this.onboardingProjectionId,
    this.onboardingSourceItemId,
    this.sourceFingerprint,
    this.startedAt,
    this.countdownDurationSeconds,
    this.previousStatus,
    this.previousAction,
    this.trackerSessionId,
    this.trackerType,
  });

  static const Object _sentinel = Object();

  RoutineOccurrenceRecord copyWith({
    RoutineStatus? status,
    String? source,
    String? action,
    String? operationKey,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? movedToDateKey = _sentinel,
    Object? movedStartMinute = _sentinel,
    Object? movedEndMinute = _sentinel,
    List<int>? completedSubtaskIndexes,
    Object? note = _sentinel,
    Object? displayTitleOverride = _sentinel,
    bool? undoToPlannedAllowed,
    Object? onboardingProjectionId = _sentinel,
    Object? onboardingSourceItemId = _sentinel,
    Object? sourceFingerprint = _sentinel,
    Object? startedAt = _sentinel,
    Object? countdownDurationSeconds = _sentinel,
    Object? previousStatus = _sentinel,
    Object? previousAction = _sentinel,
    Object? trackerSessionId = _sentinel,
    Object? trackerType = _sentinel,
  }) {
    return RoutineOccurrenceRecord(
      id: id,
      ownerUid: ownerUid,
      routineItemId: routineItemId,
      occurrenceDateKey: occurrenceDateKey,
      status: status ?? this.status,
      source: source ?? this.source,
      action: action ?? this.action,
      operationKey: operationKey ?? this.operationKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion,
      movedToDateKey: identical(movedToDateKey, _sentinel)
          ? this.movedToDateKey
          : movedToDateKey as String?,
      movedStartMinute: identical(movedStartMinute, _sentinel)
          ? this.movedStartMinute
          : movedStartMinute as int?,
      movedEndMinute: identical(movedEndMinute, _sentinel)
          ? this.movedEndMinute
          : movedEndMinute as int?,
      completedSubtaskIndexes:
          completedSubtaskIndexes ?? this.completedSubtaskIndexes,
      note: identical(note, _sentinel) ? this.note : note as String?,
      displayTitleOverride: identical(displayTitleOverride, _sentinel)
          ? this.displayTitleOverride
          : displayTitleOverride as String?,
      undoToPlannedAllowed: undoToPlannedAllowed ?? this.undoToPlannedAllowed,
      onboardingProjectionId: identical(onboardingProjectionId, _sentinel)
          ? this.onboardingProjectionId
          : onboardingProjectionId as String?,
      onboardingSourceItemId: identical(onboardingSourceItemId, _sentinel)
          ? this.onboardingSourceItemId
          : onboardingSourceItemId as String?,
      sourceFingerprint: identical(sourceFingerprint, _sentinel)
          ? this.sourceFingerprint
          : sourceFingerprint as String?,
      startedAt: identical(startedAt, _sentinel)
          ? this.startedAt
          : startedAt as DateTime?,
      countdownDurationSeconds: identical(countdownDurationSeconds, _sentinel)
          ? this.countdownDurationSeconds
          : countdownDurationSeconds as int?,
      previousStatus: identical(previousStatus, _sentinel)
          ? this.previousStatus
          : previousStatus as RoutineStatus?,
      previousAction: identical(previousAction, _sentinel)
          ? this.previousAction
          : previousAction as String?,
      trackerSessionId: identical(trackerSessionId, _sentinel)
          ? this.trackerSessionId
          : trackerSessionId as String?,
      trackerType: identical(trackerType, _sentinel)
          ? this.trackerType
          : trackerType as String?,
    );
  }

  RoutineOccurrenceRecord clearPreviousStatusAndAction() {
    return copyWith(previousStatus: null, previousAction: null);
  }

  RoutineOccurrenceRecord clearMoveFields() {
    return copyWith(
      movedToDateKey: null,
      movedStartMinute: null,
      movedEndMinute: null,
    );
  }

  RoutineOccurrenceRecord clearTimer() {
    return copyWith(startedAt: null, countdownDurationSeconds: null);
  }

  RoutineOccurrenceRecord clearTracker() {
    return copyWith(trackerSessionId: null, trackerType: null);
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'ownerUid': ownerUid,
    'routineItemId': routineItemId,
    'occurrenceDateKey': occurrenceDateKey,
    'status': status.name,
    'source': source,
    'action': action,
    'operationKey': operationKey,
    if (movedToDateKey != null) 'movedToDateKey': movedToDateKey,
    if (movedStartMinute != null) 'movedStartMinute': movedStartMinute,
    if (movedEndMinute != null) 'movedEndMinute': movedEndMinute,
    'completedSubtaskIndexes': completedSubtaskIndexes,
    if (note != null) 'note': note,
    if (displayTitleOverride != null)
      'displayTitleOverride': displayTitleOverride,
    'undoToPlannedAllowed': undoToPlannedAllowed,
    if (onboardingProjectionId != null)
      'onboardingProjectionId': onboardingProjectionId,
    if (onboardingSourceItemId != null)
      'onboardingSourceItemId': onboardingSourceItemId,
    if (sourceFingerprint != null) 'sourceFingerprint': sourceFingerprint,
    if (startedAt != null) 'startedAt': startedAt!.toUtc().toIso8601String(),
    if (countdownDurationSeconds != null)
      'countdownDurationSeconds': countdownDurationSeconds,
    if (previousStatus != null) 'previousStatus': previousStatus!.name,
    if (previousAction != null) 'previousAction': previousAction,
    if (trackerSessionId != null) 'trackerSessionId': trackerSessionId,
    if (trackerType != null) 'trackerType': trackerType,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'schemaVersion': schemaVersion,
  };

  Map<String, dynamic> toFirestoreMap() {
    final map = toMap();
    map['createdAt'] = Timestamp.fromDate(createdAt.toUtc());
    map['updatedAt'] = Timestamp.fromDate(updatedAt.toUtc());
    if (startedAt != null) {
      map['startedAt'] = Timestamp.fromDate(startedAt!.toUtc());
    }
    return map;
  }

  factory RoutineOccurrenceRecord.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate().toUtc();
      if (val is DateTime) return val.toUtc();
      if (val is String) return DateTime.parse(val).toUtc();
      return DateTime.now().toUtc();
    }

    final rawStatus = map['status'] as String? ?? 'active';
    final parsedStatus = RoutineStatus.values.firstWhere(
      (s) => s.name == rawStatus,
      orElse: () => RoutineStatus.active,
    );
    final subtasksRaw = map['completedSubtaskIndexes'] as List?;
    final subtasks =
        subtasksRaw?.map((e) => (e as num).toInt()).toList() ?? const <int>[];

    return RoutineOccurrenceRecord(
      id: (map['id'] as String?) ?? documentId ?? '',
      ownerUid: map['ownerUid'] as String? ?? '',
      routineItemId: map['routineItemId'] as String? ?? '',
      occurrenceDateKey: map['occurrenceDateKey'] as String? ?? '',
      status: parsedStatus,
      source: map['source'] as String? ?? 'routine',
      action: map['action'] as String? ?? 'start',
      operationKey: map['operationKey'] as String? ?? 'op',
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
      movedToDateKey: map['movedToDateKey'] as String?,
      movedStartMinute: (map['movedStartMinute'] as num?)?.toInt(),
      movedEndMinute: (map['movedEndMinute'] as num?)?.toInt(),
      completedSubtaskIndexes: List.unmodifiable(subtasks),
      note: map['note'] as String?,
      displayTitleOverride: map['displayTitleOverride'] as String?,
      undoToPlannedAllowed: map['undoToPlannedAllowed'] as bool? ?? false,
      onboardingProjectionId: map['onboardingProjectionId'] as String?,
      onboardingSourceItemId: map['onboardingSourceItemId'] as String?,
      sourceFingerprint: map['sourceFingerprint'] as String?,
      startedAt: map.containsKey('startedAt')
          ? parseDate(map['startedAt'])
          : null,
      countdownDurationSeconds: (map['countdownDurationSeconds'] as num?)
          ?.toInt(),
      previousStatus: map['previousStatus'] != null
          ? RoutineStatus.values.firstWhere(
              (e) => e.name == map['previousStatus'],
              orElse: () => RoutineStatus.planned,
            )
          : null,
      previousAction: map['previousAction'] as String?,
      trackerSessionId: map['trackerSessionId'] as String?,
      trackerType: map['trackerType'] as String?,
    );
  }

  factory RoutineOccurrenceRecord.fromFirestoreMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    return RoutineOccurrenceRecord.fromMap(map, documentId: documentId);
  }
}

String routineLocalDateKey(DateTime value) {
  final local = value.isUtc ? value.toLocal() : value;
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

DateTime parseRoutineLocalDateKey(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    throw FormatException('Invalid Routine local date key: $value');
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    throw FormatException('Invalid Routine local date key: $value');
  }
  return parsed;
}
