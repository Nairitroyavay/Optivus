import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:optivus/models/routine_item.dart';

enum HabitSystemType { goodHabit, badHabit, identity }

enum HabitSystemStatus { active, paused, archived }

class HabitSystemRecord {
  final String systemId;
  final String ownerUid;
  final String title;
  final String description;
  final RoutineCategory category;
  final HabitSystemType systemType;
  final HabitSystemStatus status;
  final List<String> linkedRoutineIds;
  final String source;
  final String? onboardingSourceId;
  final String? onboardingProjectionId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final int schemaVersion;
  final int version;

  HabitSystemRecord({
    required this.systemId,
    required this.ownerUid,
    required this.title,
    this.description = '',
    required this.category,
    required this.systemType,
    this.status = HabitSystemStatus.active,
    this.linkedRoutineIds = const [],
    this.source = 'user',
    this.onboardingSourceId,
    this.onboardingProjectionId,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.schemaVersion = 1,
    this.version = 1,
  }) {
    if (ownerUid.trim().isEmpty || ownerUid.contains('/')) {
      throw ArgumentError('Valid owner UID is required.');
    }
  }

  bool get isActive => status == HabitSystemStatus.active;
  bool get isPaused => status == HabitSystemStatus.paused;
  bool get isArchived => status == HabitSystemStatus.archived;

  HabitSystemRecord copyWith({
    String? systemId,
    String? ownerUid,
    String? title,
    String? description,
    RoutineCategory? category,
    HabitSystemType? systemType,
    HabitSystemStatus? status,
    List<String>? linkedRoutineIds,
    String? source,
    String? onboardingSourceId,
    String? onboardingProjectionId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    int? schemaVersion,
    int? version,
  }) {
    return HabitSystemRecord(
      systemId: systemId ?? this.systemId,
      ownerUid: ownerUid ?? this.ownerUid,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      systemType: systemType ?? this.systemType,
      status: status ?? this.status,
      linkedRoutineIds: linkedRoutineIds ?? this.linkedRoutineIds,
      source: source ?? this.source,
      onboardingSourceId: onboardingSourceId ?? this.onboardingSourceId,
      onboardingProjectionId:
          onboardingProjectionId ?? this.onboardingProjectionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
      schemaVersion: schemaVersion ?? this.schemaVersion,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toMap() {
    final isArchivedStatus = status == HabitSystemStatus.archived;
    final effectiveArchivedAt = isArchivedStatus
        ? (archivedAt ?? updatedAt)
        : null;
    final isUserSource = source == 'user';
    final isOnboardingSource = source == 'onboarding';
    return {
      'systemId': systemId,
      'ownerUid': ownerUid,
      'title': title,
      'description': description,
      'category': category.name,
      'systemType': systemType.name,
      'status': status.name,
      'linkedRoutineIds': linkedRoutineIds,
      'source': source,
      if (!isUserSource && (isOnboardingSource || onboardingSourceId != null))
        'onboardingSourceId': onboardingSourceId ?? '',
      if (!isUserSource &&
          (isOnboardingSource || onboardingProjectionId != null))
        'onboardingProjectionId': onboardingProjectionId ?? '',
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      if (isArchivedStatus && effectiveArchivedAt != null)
        'archivedAt': effectiveArchivedAt.toUtc().toIso8601String(),
      'schemaVersion': schemaVersion,
      'version': version,
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    final isArchivedStatus = status == HabitSystemStatus.archived;
    final effectiveArchivedAt = isArchivedStatus
        ? (archivedAt ?? updatedAt)
        : null;
    final isUserSource = source == 'user';
    final isOnboardingSource = source == 'onboarding';
    return {
      'systemId': systemId,
      'ownerUid': ownerUid,
      'title': title,
      'description': description,
      'category': category.name,
      'systemType': systemType.name,
      'status': status.name,
      'linkedRoutineIds': linkedRoutineIds,
      'source': source,
      if (!isUserSource && (isOnboardingSource || onboardingSourceId != null))
        'onboardingSourceId': onboardingSourceId ?? '',
      if (!isUserSource &&
          (isOnboardingSource || onboardingProjectionId != null))
        'onboardingProjectionId': onboardingProjectionId ?? '',
      'createdAt': Timestamp.fromDate(createdAt.toUtc()),
      'updatedAt': Timestamp.fromDate(updatedAt.toUtc()),
      if (isArchivedStatus && effectiveArchivedAt != null)
        'archivedAt': Timestamp.fromDate(effectiveArchivedAt.toUtc()),
      'schemaVersion': schemaVersion,
      'version': version,
    };
  }

  factory HabitSystemRecord.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    final rawSystemId = (map['systemId'] as String?) ?? documentId ?? '';
    final rawOwnerUid = (map['ownerUid'] as String?) ?? '';
    if (rawOwnerUid.trim().isEmpty || rawOwnerUid.contains('/')) {
      throw ArgumentError('Valid owner UID is required.');
    }
    final rawTitle = (map['title'] as String?) ?? 'Untitled System';
    final rawDescription = (map['description'] as String?) ?? '';

    RoutineCategory parsedCategory;
    try {
      parsedCategory = RoutineCategory.values.byName(map['category'] as String);
    } catch (_) {
      parsedCategory = RoutineCategory.habit;
    }

    HabitSystemType parsedType;
    try {
      parsedType = HabitSystemType.values.byName(map['systemType'] as String);
    } catch (_) {
      parsedType = HabitSystemType.goodHabit;
    }

    HabitSystemStatus parsedStatus;
    try {
      parsedStatus = HabitSystemStatus.values.byName(map['status'] as String);
    } catch (_) {
      parsedStatus = HabitSystemStatus.active;
    }

    final linkedList =
        (map['linkedRoutineIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const [];

    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now().toUtc();
      if (value is String) return DateTime.parse(value).toUtc();
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value).toUtc();
      }
      // Handle Firestore Timestamp if passed as object
      try {
        final dynamic t = value;
        return (t.toDate() as DateTime).toUtc();
      } catch (_) {
        return DateTime.now().toUtc();
      }
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      return parseDate(value);
    }

    return HabitSystemRecord(
      systemId: rawSystemId,
      ownerUid: rawOwnerUid,
      title: rawTitle,
      description: rawDescription,
      category: parsedCategory,
      systemType: parsedType,
      status: parsedStatus,
      linkedRoutineIds: List.unmodifiable(linkedList),
      source: (map['source'] as String?) ?? 'user',
      onboardingSourceId: map['onboardingSourceId'] as String?,
      onboardingProjectionId: map['onboardingProjectionId'] as String?,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      archivedAt: parseNullableDate(map['archivedAt']),
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
      version: (map['version'] as num?)?.toInt() ?? 1,
    );
  }
}
