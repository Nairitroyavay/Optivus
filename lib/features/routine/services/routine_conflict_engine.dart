import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:optivus/features/routine/domain/conflict_policy.dart';
import 'package:optivus/features/routine/domain/routine_conflict.dart';
import 'package:optivus/features/routine/services/routine_materializer.dart';
import 'package:optivus/models/conflict_acceptance.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';

extension RoutineItemAppliesExt on RoutineItem {
  bool appliesToDate(DateTime day) {
    return RoutineMaterializer.occursOnDay(this, day);
  }
}

class RoutineConflictEngine {
  RoutineConflictEngine._();

  static String scheduleFingerprint(
    RoutineItem a,
    RoutineItem b,
    RoutineConflictType conflictType, {
    String timezoneId = 'UTC',
  }) {
    final fallbackOwner = a.userId ?? b.userId ?? 'local-routine-owner';
    final ordered = [
      _descriptor(a, timezoneId, fallbackOwner),
      _descriptor(b, timezoneId, fallbackOwner),
    ]..sort((left, right) => left.sourceItemId.compareTo(right.sourceItemId));
    final canonical = jsonEncode({
      'contract': 'routine-conflict-pair-v2',
      'conflictType': conflictType.name,
      'first': ordered[0].scheduleFingerprint,
      'second': ordered[1].scheduleFingerprint,
    });
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  static ConflictScheduleDescriptor scheduleDescriptor(
    RoutineItem item, {
    required String timezoneId,
    String? fallbackOwnerUid,
  }) {
    return _descriptor(
      item,
      timezoneId,
      fallbackOwnerUid ?? item.userId ?? 'local-routine-owner',
    );
  }

  static List<RoutineConflict> detect(
    List<RoutineItem> items,
    DateTime day, {
    DateTime? now,
    List<ConflictAcceptance> conflictAcceptances = const [],
    String timezoneId = 'UTC',
  }) {
    final conflicts = <RoutineConflict>[];

    for (final item in items) {
      if (item.durationMinutes <= 0) {
        conflicts.add(
          RoutineConflict(
            id: 'invalid-duration-${item.id}',
            type: RoutineConflictType.invalidDuration,
            itemId: item.id,
            title: 'Invalid Duration',
            message: '${item.title} has a zero or negative duration.',
            startMinute: item.startMinute,
            endMinute: item.endMinute,
            blocking: true,
            canKeepBoth: false,
            resolution: RoutineConflictResolution.prohibited,
          ),
        );
      }
    }

    final meaningful =
        items.where((item) => item.durationMinutes > 0).toList(growable: false)
          ..sort((a, b) => a.startMinute.compareTo(b.startMinute));

    for (var i = 0; i < meaningful.length; i++) {
      final firstItem = meaningful[i];
      final firstRange = _itemDateRange(firstItem, day);
      for (var j = i + 1; j < meaningful.length; j++) {
        final secondItem = meaningful[j];
        final secondRange = _itemDateRange(secondItem, day);
        if (!firstRange.start.isBefore(secondRange.end) ||
            !firstRange.end.isAfter(secondRange.start)) {
          continue;
        }

        final fallbackOwner =
            firstItem.userId ?? secondItem.userId ?? 'local-routine-owner';
        final first = _descriptor(firstItem, timezoneId, fallbackOwner);
        final second = _descriptor(secondItem, timezoneId, fallbackOwner);
        final decision = ConflictPolicy.classify(first, second);
        final type = _routineType(decision.type);
        ConflictAcceptance? matchingAcceptance;
        if (decision.canKeepBoth) {
          for (final acceptance in conflictAcceptances) {
            if (acceptance.authorizes(
              ownerUid: fallbackOwner,
              first: first,
              second: second,
              conflictType: decision.type.name,
              day: day,
              timezoneId: timezoneId,
              projectionId: first.projectionId == second.projectionId
                  ? first.projectionId
                  : '',
              sourceBundleFingerprint: acceptance.sourceBundleFingerprint,
            )) {
              matchingAcceptance = acceptance;
              break;
            }
          }
        }

        final allowed = matchingAcceptance != null;
        final overlapStart = firstRange.start.isBefore(secondRange.start)
            ? secondRange.start
            : firstRange.start;
        final overlapEnd = firstRange.end.isBefore(secondRange.end)
            ? firstRange.end
            : secondRange.end;
        final startMinute = overlapStart.hour * 60 + overlapStart.minute;
        var endMinute = overlapEnd.hour * 60 + overlapEnd.minute;
        if (!DateUtils.isSameDay(overlapStart, overlapEnd) ||
            endMinute < startMinute) {
          endMinute += 1440;
        }

        final resolution = allowed
            ? RoutineConflictResolution.allowedByUser
            : switch (decision.resolution) {
                ConflictPolicyResolution.prohibited =>
                  RoutineConflictResolution.prohibited,
                ConflictPolicyResolution.informational =>
                  RoutineConflictResolution.informational,
                ConflictPolicyResolution.unresolved =>
                  RoutineConflictResolution.unresolved,
              };
        conflicts.add(
          RoutineConflict(
            id: 'overlap-${firstItem.id}-${secondItem.id}',
            type: type,
            itemId: firstItem.id,
            otherItemId: secondItem.id,
            title: '${firstItem.title} overlaps ${secondItem.title}',
            message: allowed
                ? 'Overlap allowed by you: ${firstItem.title} and ${secondItem.title}.'
                : decision.publicReason,
            startMinute: startMinute,
            endMinute: endMinute,
            blocking: allowed ? false : decision.blocking,
            canKeepBoth: allowed ? false : decision.canKeepBoth,
            resolution: resolution,
            acceptanceId: matchingAcceptance?.acceptanceId,
          ),
        );
      }
    }

    conflicts.addAll(
      _duplicateConflicts(
        meaningful,
        day,
        conflictAcceptances: conflictAcceptances,
        timezoneId: timezoneId,
      ),
    );

    if (meaningful.length > 14) {
      conflicts.add(
        RoutineConflict(
          id: 'too-many-${day.toIso8601String()}',
          type: RoutineConflictType.tooManyTasks,
          itemId: meaningful.first.id,
          title: 'Too many tasks in one day',
          message: '${meaningful.length} scheduled items may be too dense.',
          startMinute: meaningful.first.startMinute,
          endMinute: meaningful.last.endMinute,
          blocking: false,
          canKeepBoth: false,
          resolution: RoutineConflictResolution.informational,
        ),
      );
    }

    if (now != null && DateUtils.isSameDay(day, now)) {
      final currentMinute = now.hour * 60 + now.minute;
      for (final item in meaningful) {
        final overdueTracker =
            item.blockType == RoutineBlockType.trackerTask &&
            item.endMinute < currentMinute &&
            item.status != RoutineStatus.completed &&
            item.status != RoutineStatus.inTracker &&
            !item.isCompleted;
        if (!overdueTracker) continue;
        conflicts.add(
          RoutineConflict(
            id: 'tracker-incomplete-${item.id}',
            type: RoutineConflictType.trackerTaskNotCompleted,
            itemId: item.id,
            title: '${item.title} not completed',
            message:
                '${item.title} was scheduled but not completed in Tracker.',
            startMinute: item.startMinute,
            endMinute: item.endMinute,
            blocking: false,
            canKeepBoth: false,
            resolution: RoutineConflictResolution.informational,
          ),
        );
      }
    }

    return conflicts;
  }

  static DateTimeRange _itemDateRange(RoutineItem item, DateTime day) {
    final start = DateTime(
      day.year,
      day.month,
      day.day,
      item.startMinute ~/ 60,
      item.startMinute % 60,
    );
    var end = DateTime(
      day.year,
      day.month,
      day.day,
      item.endMinute ~/ 60,
      item.endMinute % 60,
    );
    if (item.crossesMidnight ||
        item.endsNextDay ||
        item.endMinute <= item.startMinute) {
      end = end.add(const Duration(days: 1));
    }
    return DateTimeRange(start: start, end: end);
  }

  static RoutineConflictType _routineType(ConflictPolicyType type) {
    return switch (type) {
      ConflictPolicyType.compatibleOverlap =>
        RoutineConflictType.compatibleOverlap,
      ConflictPolicyType.informationalOverlap =>
        RoutineConflictType.timeOverlap,
      ConflictPolicyType.sleepOverlap => RoutineConflictType.sleepConflict,
      ConflictPolicyType.invalidDuration => RoutineConflictType.invalidDuration,
      ConflictPolicyType.unavailableTime ||
      ConflictPolicyType.ownerMismatch ||
      ConflictPolicyType.inactiveItem ||
      ConflictPolicyType.unsupportedSchema ||
      ConflictPolicyType.corruptSchedule => RoutineConflictType.unavailableTime,
    };
  }

  static ConflictScheduleDescriptor _descriptor(
    RoutineItem item,
    String timezoneId,
    String fallbackOwner,
  ) {
    final repeatDays = item.repeatDays.toSet().toList()..sort();
    return ConflictScheduleDescriptor(
      ownerUid: item.userId ?? fallbackOwner,
      itemId: item.id,
      sourceItemId: item.onboardingSourceItemId ?? item.id,
      startMinute: item.startMinute,
      endMinute: item.endMinute,
      crossesMidnight: item.crossesMidnight,
      endsNextDay: item.endsNextDay,
      dateKey: item.date == null ? '' : routineLocalDateKey(item.date!),
      endDateKey: item.endDate == null
          ? ''
          : routineLocalDateKey(item.endDate!),
      repeatRule:
          item.repeatRule ??
          (item.date != null
              ? 'once'
              : repeatDays.length == 7
              ? 'daily'
              : 'weekly'),
      repeatDays: repeatDays,
      blockType: item.blockType.name,
      hardBlock: item.isHardBlock,
      category: switch (item.category) {
        RoutineCategory.classBlock => ConflictSemanticCategory.classBlock,
        RoutineCategory.job => ConflictSemanticCategory.job,
        RoutineCategory.eating => ConflictSemanticCategory.meal,
        RoutineCategory.sleep => ConflictSemanticCategory.sleep,
        RoutineCategory.fixed => ConflictSemanticCategory.fixed,
        _ => ConflictSemanticCategory.other,
      },
      timezoneId: timezoneId,
      source: item.source.name,
      activeStatus: 'active',
      projectionId: item.onboardingProjectionId ?? '',
      revision: _projectionRevision(item.onboardingProjectionId),
      schemaVersion: item.schemaVersion,
    );
  }

  static int _projectionRevision(String? projectionId) {
    final match = RegExp(r'-v(\d+)$').firstMatch(projectionId ?? '');
    return int.tryParse(match?.group(1) ?? '') ?? 1;
  }

  static List<RoutineConflict> _duplicateConflicts(
    List<RoutineItem> items,
    DateTime day, {
    required List<ConflictAcceptance> conflictAcceptances,
    required String timezoneId,
  }) {
    final conflicts = <RoutineConflict>[];
    for (var i = 0; i < items.length; i++) {
      for (var j = i + 1; j < items.length; j++) {
        final firstItem = items[i];
        final secondItem = items[j];
        if (!firstItem.appliesToDate(day) || !secondItem.appliesToDate(day)) {
          continue;
        }
        final firstTitle = firstItem.title.trim().toLowerCase().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
        final secondTitle = secondItem.title.trim().toLowerCase().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
        if (firstTitle != secondTitle ||
            firstItem.category != secondItem.category) {
          continue;
        }
        final fallbackOwner =
            firstItem.userId ?? secondItem.userId ?? 'local-routine-owner';
        final first = _descriptor(firstItem, timezoneId, fallbackOwner);
        final second = _descriptor(secondItem, timezoneId, fallbackOwner);
        ConflictAcceptance? matching;
        for (final acceptance in conflictAcceptances) {
          if (acceptance.authorizes(
            ownerUid: fallbackOwner,
            first: first,
            second: second,
            conflictType: RoutineConflictType.duplicateRoutine.name,
            day: day,
            timezoneId: timezoneId,
            projectionId: first.projectionId == second.projectionId
                ? first.projectionId
                : '',
            sourceBundleFingerprint: acceptance.sourceBundleFingerprint,
          )) {
            matching = acceptance;
            break;
          }
        }
        conflicts.add(
          RoutineConflict(
            id: 'duplicate-${firstItem.id}-${secondItem.id}',
            type: RoutineConflictType.duplicateRoutine,
            itemId: firstItem.id,
            otherItemId: secondItem.id,
            title: 'Duplicate task',
            message: matching == null
                ? '${firstItem.title} appears more than once.'
                : 'Duplicate overlap allowed by you.',
            startMinute: firstItem.startMinute < secondItem.startMinute
                ? firstItem.startMinute
                : secondItem.startMinute,
            endMinute: firstItem.endMinute > secondItem.endMinute
                ? firstItem.endMinute
                : secondItem.endMinute,
            blocking: false,
            canKeepBoth: matching == null,
            resolution: matching == null
                ? RoutineConflictResolution.unresolved
                : RoutineConflictResolution.allowedByUser,
            acceptanceId: matching?.acceptanceId,
          ),
        );
      }
    }
    return conflicts;
  }
}
