import 'dart:convert';

import 'package:crypto/crypto.dart';

enum ConflictSemanticCategory { classBlock, job, meal, sleep, fixed, other }

enum ConflictPolicyType {
  compatibleOverlap,
  informationalOverlap,
  sleepOverlap,
  unavailableTime,
  invalidDuration,
  corruptSchedule,
  ownerMismatch,
  inactiveItem,
  unsupportedSchema,
}

enum ConflictPolicyResolution { unresolved, informational, prohibited }

class ConflictScheduleDescriptor {
  const ConflictScheduleDescriptor({
    required this.ownerUid,
    required this.itemId,
    required this.sourceItemId,
    required this.startMinute,
    required this.endMinute,
    required this.crossesMidnight,
    required this.endsNextDay,
    required this.dateKey,
    required this.endDateKey,
    required this.repeatRule,
    required this.repeatDays,
    required this.blockType,
    required this.hardBlock,
    required this.category,
    required this.timezoneId,
    required this.source,
    required this.activeStatus,
    required this.projectionId,
    required this.revision,
    required this.schemaVersion,
    this.allowsSimultaneousExecution = false,
  });

  final String ownerUid;
  final String itemId;
  final String sourceItemId;
  final int startMinute;
  final int endMinute;
  final bool crossesMidnight;
  final bool endsNextDay;
  final String dateKey;
  final String endDateKey;
  final String repeatRule;
  final List<int> repeatDays;
  final String blockType;
  final bool hardBlock;
  final ConflictSemanticCategory category;
  final String timezoneId;
  final String source;
  final String activeStatus;
  final String projectionId;
  final int revision;
  final int schemaVersion;
  final bool allowsSimultaneousExecution;

  int get durationMinutes {
    if (crossesMidnight || endsNextDay || endMinute <= startMinute) {
      return (24 * 60 - startMinute) + endMinute;
    }
    return endMinute - startMinute;
  }

  bool get hasValidRecurrence {
    final days = repeatDays.toSet();
    if (days.length != repeatDays.length ||
        days.any((day) => day < 1 || day > 7)) {
      return false;
    }
    if (repeatRule == 'once') return dateKey.isNotEmpty && days.isEmpty;
    return days.isNotEmpty;
  }

  String get scheduleFingerprint {
    final days = [...repeatDays]..sort();
    final canonical = jsonEncode({
      'contract': 'conflict-schedule-v2',
      'ownerUid': ownerUid,
      'itemId': itemId,
      'sourceItemId': sourceItemId,
      'startMinute': startMinute,
      'endMinute': endMinute,
      'crossesMidnight': crossesMidnight,
      'endsNextDay': endsNextDay,
      'dateKey': dateKey,
      'endDateKey': endDateKey,
      'repeatRule': repeatRule,
      'repeatDays': days,
      'blockType': blockType,
      'hardBlock': hardBlock,
      'category': category.name,
      'timezoneId': timezoneId,
      'source': source,
      'activeStatus': activeStatus,
      'projectionId': projectionId,
      'revision': revision,
      'schemaVersion': schemaVersion,
    });
    return sha256.convert(utf8.encode(canonical)).toString();
  }
}

class ConflictPolicyDecision {
  const ConflictPolicyDecision({
    required this.type,
    required this.resolution,
    required this.blocking,
    required this.canKeepBoth,
    required this.publicReason,
  });

  final ConflictPolicyType type;
  final ConflictPolicyResolution resolution;
  final bool blocking;
  final bool canKeepBoth;
  final String publicReason;
}

/// The single pair policy used by onboarding and the Routine conflict engine.
/// It is deliberately conservative: compatibility is enumerated and no generic
/// hard-hard exemption exists.
class ConflictPolicy {
  const ConflictPolicy._();

  static ConflictPolicyDecision classify(
    ConflictScheduleDescriptor first,
    ConflictScheduleDescriptor second,
  ) {
    if (first.ownerUid.isEmpty ||
        second.ownerUid.isEmpty ||
        first.ownerUid != second.ownerUid) {
      return _prohibited(
        ConflictPolicyType.ownerMismatch,
        'The two items do not belong to the same account.',
      );
    }
    if (first.schemaVersion <= 0 || second.schemaVersion <= 0) {
      return _prohibited(
        ConflictPolicyType.unsupportedSchema,
        'One item uses an unsupported schedule contract.',
      );
    }
    if (first.activeStatus != 'active' || second.activeStatus != 'active') {
      return _prohibited(
        ConflictPolicyType.inactiveItem,
        'Archived or deleted items cannot authorize an overlap.',
      );
    }
    if (first.timezoneId.trim().isEmpty ||
        second.timezoneId.trim().isEmpty ||
        !first.hasValidRecurrence ||
        !second.hasValidRecurrence) {
      return _prohibited(
        ConflictPolicyType.corruptSchedule,
        'Fix the schedule details before resolving this overlap.',
      );
    }
    if (first.durationMinutes <= 0 || second.durationMinutes <= 0) {
      return _prohibited(
        ConflictPolicyType.invalidDuration,
        'Fix the item duration before resolving this overlap.',
      );
    }
    if (_hasCategory(first, second, ConflictSemanticCategory.sleep)) {
      return _prohibited(
        ConflictPolicyType.sleepOverlap,
        'Sleep overlaps must be edited and cannot be kept together.',
      );
    }

    final isClassJob = _isPair(
      first,
      second,
      ConflictSemanticCategory.classBlock,
      ConflictSemanticCategory.job,
    );
    if (isClassJob &&
        !(first.allowsSimultaneousExecution &&
            second.allowsSimultaneousExecution)) {
      return _prohibited(
        ConflictPolicyType.unavailableTime,
        'Class and work can overlap only when both are explicitly marked compatible.',
      );
    }

    final bothUnavailable =
        _sameCategory(first, second, ConflictSemanticCategory.classBlock) ||
        _sameCategory(first, second, ConflictSemanticCategory.job);
    if (bothUnavailable) {
      return _prohibited(
        ConflictPolicyType.unavailableTime,
        'These unavailable-time blocks must be edited.',
      );
    }

    if (isClassJob || _isExplicitlyCompatiblePair(first, second)) {
      return const ConflictPolicyDecision(
        type: ConflictPolicyType.compatibleOverlap,
        resolution: ConflictPolicyResolution.unresolved,
        blocking: true,
        canKeepBoth: true,
        publicReason:
            'Keep both only if you can intentionally do them together.',
      );
    }

    if (first.hardBlock && second.hardBlock) {
      return _prohibited(
        ConflictPolicyType.unavailableTime,
        'These fixed commitments cannot be assumed to happen together.',
      );
    }

    return const ConflictPolicyDecision(
      type: ConflictPolicyType.informationalOverlap,
      resolution: ConflictPolicyResolution.informational,
      blocking: false,
      canKeepBoth: false,
      publicReason: 'This is an informational overlap.',
    );
  }

  static bool _isExplicitlyCompatiblePair(
    ConflictScheduleDescriptor first,
    ConflictScheduleDescriptor second,
  ) {
    final categories = {first.category, second.category};
    if (categories.contains(ConflictSemanticCategory.meal)) {
      final other = first.category == ConflictSemanticCategory.meal
          ? second
          : first;
      if (other.hardBlock &&
          (other.category == ConflictSemanticCategory.classBlock ||
              other.category == ConflictSemanticCategory.job ||
              other.category == ConflictSemanticCategory.fixed)) {
        return true;
      }
    }
    if (categories.contains(ConflictSemanticCategory.classBlock) &&
        categories.contains(ConflictSemanticCategory.fixed)) {
      final fixed = first.category == ConflictSemanticCategory.fixed
          ? first
          : second;
      return fixed.hardBlock;
    }
    if (categories.contains(ConflictSemanticCategory.job) &&
        categories.contains(ConflictSemanticCategory.fixed)) {
      final fixed = first.category == ConflictSemanticCategory.fixed
          ? first
          : second;
      return fixed.hardBlock;
    }
    return _sameCategory(first, second, ConflictSemanticCategory.fixed) &&
        first.hardBlock &&
        second.hardBlock;
  }

  static bool _hasCategory(
    ConflictScheduleDescriptor first,
    ConflictScheduleDescriptor second,
    ConflictSemanticCategory category,
  ) {
    return first.category == category || second.category == category;
  }

  static bool _sameCategory(
    ConflictScheduleDescriptor first,
    ConflictScheduleDescriptor second,
    ConflictSemanticCategory category,
  ) {
    return first.category == category && second.category == category;
  }

  static bool _isPair(
    ConflictScheduleDescriptor first,
    ConflictScheduleDescriptor second,
    ConflictSemanticCategory a,
    ConflictSemanticCategory b,
  ) {
    return (first.category == a && second.category == b) ||
        (first.category == b && second.category == a);
  }

  static ConflictPolicyDecision _prohibited(
    ConflictPolicyType type,
    String reason,
  ) {
    return ConflictPolicyDecision(
      type: type,
      resolution: ConflictPolicyResolution.prohibited,
      blocking: true,
      canKeepBoth: false,
      publicReason: reason,
    );
  }
}
