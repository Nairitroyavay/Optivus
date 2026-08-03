import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:optivus/models/routine_item.dart';

class RoutineOccurrenceRecord {
  static const int currentSchemaVersion = 1;

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
  });

  RoutineOccurrenceRecord copyWith({
    RoutineStatus? status,
    String? source,
    String? action,
    String? operationKey,
    DateTime? updatedAt,
    String? movedToDateKey,
    int? movedStartMinute,
    int? movedEndMinute,
    List<int>? completedSubtaskIndexes,
    String? note,
    String? displayTitleOverride,
    bool? undoToPlannedAllowed,
    String? onboardingProjectionId,
    String? onboardingSourceItemId,
    String? sourceFingerprint,
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
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion,
      movedToDateKey: movedToDateKey ?? this.movedToDateKey,
      movedStartMinute: movedStartMinute ?? this.movedStartMinute,
      movedEndMinute: movedEndMinute ?? this.movedEndMinute,
      completedSubtaskIndexes:
          completedSubtaskIndexes ?? this.completedSubtaskIndexes,
      note: note ?? this.note,
      displayTitleOverride: displayTitleOverride ?? this.displayTitleOverride,
      undoToPlannedAllowed: undoToPlannedAllowed ?? this.undoToPlannedAllowed,
      onboardingProjectionId:
          onboardingProjectionId ?? this.onboardingProjectionId,
      onboardingSourceItemId:
          onboardingSourceItemId ?? this.onboardingSourceItemId,
      sourceFingerprint: sourceFingerprint ?? this.sourceFingerprint,
    );
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
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'schemaVersion': schemaVersion,
  };

  Map<String, dynamic> toFirestoreMap() {
    final map = toMap();
    map['createdAt'] = Timestamp.fromDate(createdAt.toUtc());
    map['updatedAt'] = Timestamp.fromDate(updatedAt.toUtc());
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
      schemaVersion:
          (map['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion,
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
