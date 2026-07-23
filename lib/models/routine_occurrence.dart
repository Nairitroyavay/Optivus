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
    );
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
