import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:optivus/features/routine/domain/conflict_policy.dart';

enum ConflictAcceptanceScope { singleOccurrence, recurringWeekdays }

enum ConflictAcceptanceOrigin { onboarding, routineResolver }

enum ConflictAcceptanceStatus { active, invalidated, revoked }

class ConflictAcceptance {
  static const int currentSchemaVersion = 2;

  const ConflictAcceptance({
    required this.acceptanceId,
    required this.ownerUid,
    required this.canonicalPairHash,
    required this.firstSourceBlockId,
    required this.secondSourceBlockId,
    required this.firstProjectedRoutineId,
    required this.secondProjectedRoutineId,
    required this.conflictType,
    required this.scope,
    required this.dateKey,
    required this.applicableWeekdays,
    required this.timezoneId,
    required this.firstScheduleFingerprint,
    required this.secondScheduleFingerprint,
    required this.combinedScheduleFingerprint,
    required this.sourceBundleFingerprint,
    required this.projectionId,
    required this.acceptedAt,
    required this.acceptedFrom,
    required this.status,
    required this.invalidatedAt,
    required this.invalidationReason,
    this.schemaVersion = currentSchemaVersion,
  });

  final String acceptanceId;
  final String ownerUid;
  final String canonicalPairHash;
  final String firstSourceBlockId;
  final String secondSourceBlockId;
  final String firstProjectedRoutineId;
  final String secondProjectedRoutineId;
  final String conflictType;
  final ConflictAcceptanceScope scope;
  final String dateKey;
  final List<int> applicableWeekdays;
  final String timezoneId;
  final String firstScheduleFingerprint;
  final String secondScheduleFingerprint;
  final String combinedScheduleFingerprint;
  final String sourceBundleFingerprint;
  final String projectionId;
  final DateTime acceptedAt;
  final ConflictAcceptanceOrigin acceptedFrom;
  final ConflictAcceptanceStatus status;
  final DateTime? invalidatedAt;
  final String? invalidationReason;
  final int schemaVersion;

  bool get isActive => status == ConflictAcceptanceStatus.active;

  Set<String> get projectedRoutineIds =>
      {firstProjectedRoutineId, secondProjectedRoutineId}..remove('');

  Set<String> get sourceBlockIds => {firstSourceBlockId, secondSourceBlockId};

  factory ConflictAcceptance.create({
    required String ownerUid,
    required ConflictScheduleDescriptor first,
    required ConflictScheduleDescriptor second,
    required String conflictType,
    required ConflictAcceptanceScope scope,
    required List<int> applicableWeekdays,
    required String timezoneId,
    required ConflictAcceptanceOrigin acceptedFrom,
    String dateKey = '',
    String sourceBundleFingerprint = '',
    String projectionId = '',
    String firstProjectedRoutineId = '',
    String secondProjectedRoutineId = '',
    DateTime? acceptedAt,
  }) {
    if (ownerUid.isEmpty ||
        first.ownerUid != ownerUid ||
        second.ownerUid != ownerUid) {
      throw ArgumentError('Conflict acceptance owner mismatch.');
    }
    final ordered = [first, second]
      ..sort((a, b) => a.sourceItemId.compareTo(b.sourceItemId));
    final firstSourceId = ordered[0].sourceItemId;
    final secondSourceId = ordered[1].sourceItemId;
    final days = applicableWeekdays.toSet().toList()..sort();
    if (days.isEmpty || days.any((day) => day < 1 || day > 7)) {
      throw ArgumentError('Conflict acceptance weekdays are invalid.');
    }
    if (scope == ConflictAcceptanceScope.singleOccurrence &&
        !_validDateKey(dateKey)) {
      throw ArgumentError('Single-occurrence acceptance requires a date key.');
    }
    final pairHash = _digest([
      'conflict-pair-v2',
      ownerUid,
      firstSourceId,
      secondSourceId,
    ]);
    final firstFingerprint = ordered[0].scheduleFingerprint;
    final secondFingerprint = ordered[1].scheduleFingerprint;
    final combined = _digest([
      'conflict-schedule-pair-v2',
      ownerUid,
      conflictType,
      timezoneId,
      firstFingerprint,
      secondFingerprint,
    ]);
    final idDigest = _digest([
      'conflict-acceptance-v2',
      ownerUid,
      pairHash,
      conflictType,
      scope.name,
      dateKey,
      days.join(','),
      combined,
    ]);
    final firstIsOrderedFirst = identical(ordered[0], first);
    return ConflictAcceptance(
      acceptanceId: 'ca_${idDigest.substring(0, 40)}',
      ownerUid: ownerUid,
      canonicalPairHash: pairHash,
      firstSourceBlockId: firstSourceId,
      secondSourceBlockId: secondSourceId,
      firstProjectedRoutineId: firstIsOrderedFirst
          ? firstProjectedRoutineId
          : secondProjectedRoutineId,
      secondProjectedRoutineId: firstIsOrderedFirst
          ? secondProjectedRoutineId
          : firstProjectedRoutineId,
      conflictType: conflictType,
      scope: scope,
      dateKey: scope == ConflictAcceptanceScope.singleOccurrence ? dateKey : '',
      applicableWeekdays: days,
      timezoneId: timezoneId,
      firstScheduleFingerprint: firstFingerprint,
      secondScheduleFingerprint: secondFingerprint,
      combinedScheduleFingerprint: combined,
      sourceBundleFingerprint: sourceBundleFingerprint,
      projectionId: projectionId,
      acceptedAt: (acceptedAt ?? DateTime.now()).toUtc(),
      acceptedFrom: acceptedFrom,
      status: ConflictAcceptanceStatus.active,
      invalidatedAt: null,
      invalidationReason: null,
    );
  }

  bool authorizes({
    required String ownerUid,
    required ConflictScheduleDescriptor first,
    required ConflictScheduleDescriptor second,
    required String conflictType,
    required DateTime day,
    required String timezoneId,
    required String projectionId,
    required String sourceBundleFingerprint,
  }) {
    if (!isActive ||
        schemaVersion != currentSchemaVersion ||
        this.ownerUid != ownerUid ||
        this.conflictType != conflictType ||
        this.timezoneId != timezoneId ||
        this.projectionId != projectionId ||
        this.sourceBundleFingerprint != sourceBundleFingerprint) {
      return false;
    }
    final ordered = [first, second]
      ..sort((a, b) => a.sourceItemId.compareTo(b.sourceItemId));
    if (ordered[0].sourceItemId != firstSourceBlockId ||
        ordered[1].sourceItemId != secondSourceBlockId ||
        ordered[0].itemId != firstProjectedRoutineId ||
        ordered[1].itemId != secondProjectedRoutineId ||
        ordered[0].scheduleFingerprint != firstScheduleFingerprint ||
        ordered[1].scheduleFingerprint != secondScheduleFingerprint) {
      return false;
    }
    final weekday = day.weekday;
    if (!applicableWeekdays.contains(weekday)) return false;
    if (scope == ConflictAcceptanceScope.singleOccurrence) {
      return dateKey == _localDateKey(day);
    }
    return dateKey.isEmpty;
  }

  bool authorizesSourceDraft({
    required String ownerUid,
    required ConflictScheduleDescriptor first,
    required ConflictScheduleDescriptor second,
    required String conflictType,
    required DateTime day,
    required String timezoneId,
  }) {
    if (!isActive ||
        schemaVersion != currentSchemaVersion ||
        this.ownerUid != ownerUid ||
        this.conflictType != conflictType ||
        this.timezoneId != timezoneId ||
        projectionId.isNotEmpty ||
        sourceBundleFingerprint.isNotEmpty) {
      return false;
    }
    final ordered = [first, second]
      ..sort((a, b) => a.sourceItemId.compareTo(b.sourceItemId));
    if (ordered[0].sourceItemId != firstSourceBlockId ||
        ordered[1].sourceItemId != secondSourceBlockId ||
        ordered[0].scheduleFingerprint != firstScheduleFingerprint ||
        ordered[1].scheduleFingerprint != secondScheduleFingerprint) {
      return false;
    }
    if (!applicableWeekdays.contains(day.weekday)) return false;
    if (scope == ConflictAcceptanceScope.singleOccurrence) {
      return dateKey == _localDateKey(day);
    }
    return dateKey.isEmpty;
  }

  ConflictAcceptance invalidated(String reason, {DateTime? at}) {
    if (!isActive) return this;
    return copyWith(
      status: ConflictAcceptanceStatus.invalidated,
      invalidatedAt: (at ?? DateTime.now()).toUtc(),
      invalidationReason: reason,
    );
  }

  ConflictAcceptance copyWith({
    String? acceptanceId,
    String? ownerUid,
    String? canonicalPairHash,
    String? firstSourceBlockId,
    String? secondSourceBlockId,
    String? firstProjectedRoutineId,
    String? secondProjectedRoutineId,
    String? conflictType,
    ConflictAcceptanceScope? scope,
    String? dateKey,
    List<int>? applicableWeekdays,
    String? timezoneId,
    String? firstScheduleFingerprint,
    String? secondScheduleFingerprint,
    String? combinedScheduleFingerprint,
    String? sourceBundleFingerprint,
    String? projectionId,
    DateTime? acceptedAt,
    ConflictAcceptanceOrigin? acceptedFrom,
    ConflictAcceptanceStatus? status,
    DateTime? invalidatedAt,
    String? invalidationReason,
    int? schemaVersion,
  }) {
    return ConflictAcceptance(
      acceptanceId: acceptanceId ?? this.acceptanceId,
      ownerUid: ownerUid ?? this.ownerUid,
      canonicalPairHash: canonicalPairHash ?? this.canonicalPairHash,
      firstSourceBlockId: firstSourceBlockId ?? this.firstSourceBlockId,
      secondSourceBlockId: secondSourceBlockId ?? this.secondSourceBlockId,
      firstProjectedRoutineId:
          firstProjectedRoutineId ?? this.firstProjectedRoutineId,
      secondProjectedRoutineId:
          secondProjectedRoutineId ?? this.secondProjectedRoutineId,
      conflictType: conflictType ?? this.conflictType,
      scope: scope ?? this.scope,
      dateKey: dateKey ?? this.dateKey,
      applicableWeekdays: applicableWeekdays ?? this.applicableWeekdays,
      timezoneId: timezoneId ?? this.timezoneId,
      firstScheduleFingerprint:
          firstScheduleFingerprint ?? this.firstScheduleFingerprint,
      secondScheduleFingerprint:
          secondScheduleFingerprint ?? this.secondScheduleFingerprint,
      combinedScheduleFingerprint:
          combinedScheduleFingerprint ?? this.combinedScheduleFingerprint,
      sourceBundleFingerprint:
          sourceBundleFingerprint ?? this.sourceBundleFingerprint,
      projectionId: projectionId ?? this.projectionId,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      acceptedFrom: acceptedFrom ?? this.acceptedFrom,
      status: status ?? this.status,
      invalidatedAt: invalidatedAt ?? this.invalidatedAt,
      invalidationReason: invalidationReason ?? this.invalidationReason,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  Map<String, dynamic> toMap() => {
    'acceptanceId': acceptanceId,
    'ownerUid': ownerUid,
    'canonicalPairHash': canonicalPairHash,
    'firstSourceBlockId': firstSourceBlockId,
    'secondSourceBlockId': secondSourceBlockId,
    'firstProjectedRoutineId': firstProjectedRoutineId,
    'secondProjectedRoutineId': secondProjectedRoutineId,
    'conflictType': conflictType,
    'scope': scope.name,
    'dateKey': dateKey,
    'applicableWeekdays': applicableWeekdays,
    'timezoneId': timezoneId,
    'firstScheduleFingerprint': firstScheduleFingerprint,
    'secondScheduleFingerprint': secondScheduleFingerprint,
    'combinedScheduleFingerprint': combinedScheduleFingerprint,
    'sourceBundleFingerprint': sourceBundleFingerprint,
    'projectionId': projectionId,
    'acceptedAt': acceptedAt.toIso8601String(),
    'acceptedFrom': acceptedFrom.name,
    'status': status.name,
    'invalidatedAt': invalidatedAt?.toIso8601String(),
    'invalidationReason': invalidationReason,
    'schemaVersion': schemaVersion,
  };

  Map<String, dynamic> toFirestoreMap() => {
    ...toMap(),
    'acceptedAt': Timestamp.fromDate(acceptedAt),
    if (invalidatedAt != null)
      'invalidatedAt': Timestamp.fromDate(invalidatedAt!),
  };

  factory ConflictAcceptance.fromMap(Map<String, dynamic> map) {
    return ConflictAcceptance(
      acceptanceId: map['acceptanceId'] as String? ?? '',
      ownerUid: map['ownerUid'] as String? ?? '',
      canonicalPairHash: map['canonicalPairHash'] as String? ?? '',
      firstSourceBlockId: map['firstSourceBlockId'] as String? ?? '',
      secondSourceBlockId: map['secondSourceBlockId'] as String? ?? '',
      firstProjectedRoutineId: map['firstProjectedRoutineId'] as String? ?? '',
      secondProjectedRoutineId:
          map['secondProjectedRoutineId'] as String? ?? '',
      conflictType: map['conflictType'] as String? ?? '',
      scope: _scopeFrom(map['scope']),
      dateKey: map['dateKey'] as String? ?? '',
      applicableWeekdays: _intList(map['applicableWeekdays']),
      timezoneId: map['timezoneId'] as String? ?? '',
      firstScheduleFingerprint:
          map['firstScheduleFingerprint'] as String? ?? '',
      secondScheduleFingerprint:
          map['secondScheduleFingerprint'] as String? ?? '',
      combinedScheduleFingerprint:
          map['combinedScheduleFingerprint'] as String? ?? '',
      sourceBundleFingerprint: map['sourceBundleFingerprint'] as String? ?? '',
      projectionId: map['projectionId'] as String? ?? '',
      acceptedAt: _dateTime(map['acceptedAt']),
      acceptedFrom: _originFrom(map['acceptedFrom']),
      status: _statusFrom(map['status']),
      invalidatedAt: map['invalidatedAt'] == null
          ? null
          : _dateTime(map['invalidatedAt']),
      invalidationReason: map['invalidationReason'] as String?,
      schemaVersion:
          (map['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion,
    );
  }
}

String _digest(List<Object> parts) {
  return sha256.convert(utf8.encode(parts.join('\u001f'))).toString();
}

bool _validDateKey(String value) {
  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);
}

String _localDateKey(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

DateTime _dateTime(dynamic value) {
  if (value is Timestamp) return value.toDate().toUtc();
  if (value is DateTime) return value.toUtc();
  if (value is String) {
    return DateTime.tryParse(value)?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

List<int> _intList(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<num>().map((item) => item.toInt()).toList();
}

ConflictAcceptanceScope _scopeFrom(dynamic value) {
  return ConflictAcceptanceScope.values.firstWhere(
    (item) => item.name == value,
    orElse: () => ConflictAcceptanceScope.recurringWeekdays,
  );
}

ConflictAcceptanceOrigin _originFrom(dynamic value) {
  return ConflictAcceptanceOrigin.values.firstWhere(
    (item) => item.name == value,
    orElse: () => ConflictAcceptanceOrigin.onboarding,
  );
}

ConflictAcceptanceStatus _statusFrom(dynamic value) {
  return ConflictAcceptanceStatus.values.firstWhere(
    (item) => item.name == value,
    orElse: () => ConflictAcceptanceStatus.invalidated,
  );
}
