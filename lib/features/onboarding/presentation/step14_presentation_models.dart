import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';

/// Presentation modes for Step 14.
enum Step14PresentationMode { review, finishing, success, failure }

/// Status of a user-facing completion stage.
enum CompletionStageStatus { pending, active, completed, failed }

/// Public completion stage identifier.
enum Step14PublicStageId {
  savingSetup('saving_setup', 'Saving your setup'),
  preparingRoutine('preparing_routine', 'Preparing your routine'),
  preparingDailySystems(
    'preparing_daily_systems',
    'Preparing your daily systems',
  ),
  preparingHome('preparing_home', 'Preparing Home');

  final String id;
  final String publicLabel;

  const Step14PublicStageId(this.id, this.publicLabel);
}

/// Neutral presentation model for a grouped semantic conflict.
///
/// Contains purely UI-level data derived deterministically from schedule
/// entries, conflict occurrences, and durable acceptance state.
@immutable
class Step14ConflictGroup {
  final String stableGroupId;
  final String leftEntryIdentity;
  final String rightEntryIdentity;
  final String leftLabel;
  final String rightLabel;
  final List<int> affectedDays;
  final List<int> unresolvedDays;
  final List<int> acceptedDays;
  final Map<int, String> overlapRangesByDay;
  final bool hasUniformTimeRange;
  final String sharedTimeRange;
  final String publicReason;
  final bool canKeepBoth;

  const Step14ConflictGroup({
    required this.stableGroupId,
    required this.leftEntryIdentity,
    required this.rightEntryIdentity,
    required this.leftLabel,
    required this.rightLabel,
    required this.affectedDays,
    required this.unresolvedDays,
    required this.acceptedDays,
    required this.overlapRangesByDay,
    required this.hasUniformTimeRange,
    required this.sharedTimeRange,
    required this.publicReason,
    required this.canKeepBoth,
  });

  bool get isUnresolved => unresolvedDays.isNotEmpty;
  bool get isFullyAccepted => unresolvedDays.isEmpty && acceptedDays.isNotEmpty;

  String get pairTitle => '$leftLabel ↔ $rightLabel';

  String get daySummary {
    if (affectedDays.length == 5 && affectedDays.join(',') == '1,2,3,4,5') {
      return 'Mon–Fri';
    }
    if (affectedDays.length == 7) {
      return 'Every day';
    }
    return affectedDays.map(weekdayShortName).join(', ');
  }

  static String weekdayShortName(int day) => switch (day) {
    1 => 'Mon',
    2 => 'Tue',
    3 => 'Wed',
    4 => 'Thu',
    5 => 'Fri',
    6 => 'Sat',
    7 => 'Sun',
    _ => 'Day $day',
  };

  static String weekdayFullName(int day) => switch (day) {
    1 => 'Monday',
    2 => 'Tuesday',
    3 => 'Wednesday',
    4 => 'Thursday',
    5 => 'Friday',
    6 => 'Saturday',
    7 => 'Sunday',
    _ => 'Day $day',
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Step14ConflictGroup &&
          runtimeType == other.runtimeType &&
          stableGroupId == other.stableGroupId &&
          listEquals(affectedDays, other.affectedDays) &&
          listEquals(unresolvedDays, other.unresolvedDays) &&
          listEquals(acceptedDays, other.acceptedDays) &&
          mapEquals(overlapRangesByDay, other.overlapRangesByDay);

  @override
  int get hashCode => Object.hash(
    stableGroupId,
    Object.hashAll(affectedDays),
    Object.hashAll(unresolvedDays),
    Object.hashAll(acceptedDays),
  );
}

/// Pure projector that converts raw occurrences into canonical decision groups.
class Step14ConflictGroupProjector {
  const Step14ConflictGroupProjector._();

  static List<Step14ConflictGroup> project({
    required List<TimelineConflictDraft> occurrences,
    required OnboardingDraft draft,
  }) {
    if (occurrences.isEmpty) return const [];

    final grouped = <String, List<TimelineConflictDraft>>{};

    for (final occurrence in occurrences) {
      final id1 = occurrence.firstBlockId;
      final id2 = occurrence.secondBlockId;
      final leftId = id1.compareTo(id2) <= 0 ? id1 : id2;
      final rightId = id1.compareTo(id2) <= 0 ? id2 : id1;
      final groupId = '$leftId|$rightId|${occurrence.conflictType}';
      grouped
          .putIfAbsent(groupId, () => <TimelineConflictDraft>[])
          .add(occurrence);
    }

    final groups = <Step14ConflictGroup>[];

    for (final entry in grouped.entries) {
      final items = entry.value;
      if (items.isEmpty) continue;

      // Sort items by day
      items.sort((a, b) => a.day.compareTo(b.day));

      final first = items.first;
      final id1 = first.firstBlockId;
      final id2 = first.secondBlockId;
      final isFirstLeft = id1.compareTo(id2) <= 0;

      final leftId = isFirstLeft ? id1 : id2;
      final rightId = isFirstLeft ? id2 : id1;
      final leftTitle = isFirstLeft ? first.firstTitle : first.secondTitle;
      final rightTitle = isFirstLeft ? first.secondTitle : first.firstTitle;

      final affectedDays = <int>{};
      final unresolvedDays = <int>{};
      final acceptedDays = <int>{};
      final rangesByDay = <int, String>{};

      final block1 = draft.baseTimeline.blockById(id1);
      final block2 = draft.baseTimeline.blockById(id2);

      for (final item in items) {
        affectedDays.add(item.day);
        if (item.accepted) {
          acceptedDays.add(item.day);
        } else {
          unresolvedDays.add(item.day);
        }

        // Calculate overlap clock range for this day
        final rangeString = _calculateOverlapTimeRange(
          block1: block1,
          block2: block2,
          day: item.day,
        );
        if (rangeString != null) {
          rangesByDay[item.day] = rangeString;
        }
      }

      final sortedAffected = affectedDays.toList()..sort();
      final sortedUnresolved = unresolvedDays.toList()..sort();
      final sortedAccepted = acceptedDays.toList()..sort();

      final distinctRanges = rangesByDay.values.toSet();
      final hasUniform = distinctRanges.length == 1;
      final sharedRange = hasUniform && distinctRanges.isNotEmpty
          ? distinctRanges.first
          : '';

      final canKeepBoth = items.any((i) => i.canKeepBoth);
      final publicReason = items
          .map((i) => i.publicReason)
          .firstWhere(
            (r) => r.isNotEmpty,
            orElse: () => 'Schedules overlap during this time.',
          );

      groups.add(
        Step14ConflictGroup(
          stableGroupId: entry.key,
          leftEntryIdentity: leftId,
          rightEntryIdentity: rightId,
          leftLabel: leftTitle,
          rightLabel: rightTitle,
          affectedDays: sortedAffected,
          unresolvedDays: sortedUnresolved,
          acceptedDays: sortedAccepted,
          overlapRangesByDay: rangesByDay,
          hasUniformTimeRange: hasUniform,
          sharedTimeRange: sharedRange,
          publicReason: publicReason,
          canKeepBoth: canKeepBoth,
        ),
      );
    }

    // Sort groups deterministically by stableGroupId
    groups.sort((a, b) => a.stableGroupId.compareTo(b.stableGroupId));
    return groups;
  }

  static String? _calculateOverlapTimeRange({
    required TimelineBlockDraft? block1,
    required TimelineBlockDraft? block2,
    required int day,
  }) {
    if (block1 == null || block2 == null) return null;

    final windows1 = _windowsForBlockOnDay(block1, day);
    final windows2 = _windowsForBlockOnDay(block2, day);

    for (final w1 in windows1) {
      for (final w2 in windows2) {
        final overlapStart = math.max(w1.startMinute, w2.startMinute);
        final overlapEnd = math.min(w1.endMinute, w2.endMinute);
        if (overlapStart < overlapEnd) {
          return '${_formatMinuteOfDay(overlapStart)} – ${_formatMinuteOfDay(overlapEnd)}';
        }
      }
    }
    return null;
  }

  static List<({int startMinute, int endMinute})> _windowsForBlockOnDay(
    TimelineBlockDraft block,
    int targetDay,
  ) {
    final windows = <({int startMinute, int endMinute})>[];
    final crossesMidnight =
        block.crossesMidnight || block.endMinute <= block.startMinute;
    for (final day in block.repeatDays) {
      if (crossesMidnight) {
        if (day == targetDay) {
          windows.add((startMinute: block.startMinute, endMinute: 24 * 60));
        }
        final nextDay = day == 7 ? 1 : day + 1;
        if (nextDay == targetDay) {
          windows.add((startMinute: 0, endMinute: block.endMinute));
        }
      } else {
        if (day == targetDay) {
          windows.add((
            startMinute: block.startMinute,
            endMinute: block.endMinute,
          ));
        }
      }
    }
    return windows;
  }

  static String _formatMinuteOfDay(int totalMinutes) {
    final clamped = totalMinutes % (24 * 60);
    final hour24 = clamped ~/ 60;
    final minute = clamped % 60;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final minuteStr = minute < 10 ? '0$minute' : '$minute';
    return '$hour12:$minuteStr $period';
  }
}

/// Truthful readiness summary derived from current onboarding state.
@immutable
class Step14ReadinessSummary {
  final bool profileComplete;
  final bool routineGenerated;
  final bool habitsConfigured;
  final int unresolvedConflictGroupCount;

  const Step14ReadinessSummary({
    required this.profileComplete,
    required this.routineGenerated,
    required this.habitsConfigured,
    required this.unresolvedConflictGroupCount,
  });

  bool get everythingReady =>
      profileComplete &&
      routineGenerated &&
      habitsConfigured &&
      unresolvedConflictGroupCount == 0;

  static Step14ReadinessSummary project({
    required OnboardingDraft draft,
    required int unresolvedConflictGroupCount,
  }) {
    final profileOk =
        draft.lifeRole.validate() == null &&
        draft.bodyBasics.validate() == null;

    final routineOk =
        draft.baseTimeline.blocks.isNotEmpty &&
        draft.baseTimeline.validateClassesAndWorkForRole(
              draft.lifeRole.lifeRole,
            ) ==
            null &&
        draft.baseTimeline.validateEatingSetup(
              targets: draft.canonicalNutritionTargets(),
              generationInputs: draft.canonicalEatingGenerationInputs(),
            ) ==
            null &&
        draft.baseTimeline.validateFixedSchedule() == null &&
        (draft.baseTimeline.skinCareSetupPath == null &&
                !draft.baseTimeline.blocks.any((b) => b.section == 'skin_care')
            ? true
            : draft.baseTimeline.validateSkinCareSetup(draft.uid) == null);

    final habitsOk =
        (draft.goodHabits.isNotEmpty || draft.goodHabitsNotNow) &&
        (draft.badHabits.isNotEmpty || draft.badHabitsNotNow) &&
        draft.identityGoals.isNotEmpty;

    return Step14ReadinessSummary(
      profileComplete: profileOk,
      routineGenerated: routineOk,
      habitsConfigured: habitsOk,
      unresolvedConflictGroupCount: unresolvedConflictGroupCount,
    );
  }
}

/// High-value final preview facts.
@immutable
class Step14FinalPreviewData {
  final String? primaryGoal;
  final int scheduledActivitiesCount;
  final String habitFocus;
  final String coachName;
  final String coachStyle;
  final int notificationsCount;

  const Step14FinalPreviewData({
    this.primaryGoal,
    required this.scheduledActivitiesCount,
    required this.habitFocus,
    required this.coachName,
    required this.coachStyle,
    required this.notificationsCount,
  });

  static Step14FinalPreviewData project({
    required OnboardingDraft draft,
    required OnboardingCompletionBundle bundle,
  }) {
    final goal = draft.identityGoals.isNotEmpty
        ? draft.identityGoals.first.displayName
        : null;

    // Logical activities: distinct logical routine blocks in the final setup
    final activityCount = bundle.routineItemsForApp.isNotEmpty
        ? bundle.routineItemsForApp.length
        : draft.baseTimeline.blocks.length;

    final habitFocus = _formatHabitFocus(draft);
    final coachName = draft.coachSetup.coachName?.trim().isNotEmpty == true
        ? draft.coachSetup.coachName!
        : 'Supportive Coach';
    final coachStyle = _displayKey(draft.coachSetup.coachStyle);
    final notifCount = draft.notifications.selectedLabels().length;

    return Step14FinalPreviewData(
      primaryGoal: goal,
      scheduledActivitiesCount: activityCount,
      habitFocus: habitFocus,
      coachName: coachName,
      coachStyle: coachStyle,
      notificationsCount: notifCount,
    );
  }

  static String _formatHabitFocus(OnboardingDraft draft) {
    final parts = <String>[];
    if (draft.goodHabits.isNotEmpty) {
      parts.add(draft.goodHabits.first.displayName);
    }
    if (draft.badHabits.isNotEmpty) {
      final count = draft.badHabits.length;
      parts.add('$count habit check-in${count == 1 ? '' : 's'}');
    }
    return parts.isEmpty ? 'Preferences set' : parts.join(' + ');
  }

  static String _displayKey(String? key) {
    if (key == null || key.isEmpty) return 'Supportive';
    return key
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }
}

/// A user-facing presentation projection of an authoritative completion stage.
@immutable
class CompletionStageProjection {
  final Step14PublicStageId stageId;
  final String publicLabel;
  final CompletionStageStatus status;

  const CompletionStageProjection({
    required this.stageId,
    required this.publicLabel,
    required this.status,
  });

  static List<CompletionStageProjection> projectAll({
    required OnboardingCompletionStage currentStage,
    required OnboardingJobStatus jobStatus,
  }) {
    return [
      _projectSingle(
        stageId: Step14PublicStageId.savingSetup,
        stageMin: OnboardingCompletionStage.validateInput,
        stageMax: OnboardingCompletionStage.verifyBundle,
        currentStage: currentStage,
        jobStatus: jobStatus,
      ),
      _projectSingle(
        stageId: Step14PublicStageId.preparingRoutine,
        stageMin: OnboardingCompletionStage.reconcileRoutines,
        stageMax: OnboardingCompletionStage.verifyRoutineHistory,
        currentStage: currentStage,
        jobStatus: jobStatus,
      ),
      _projectSingle(
        stageId: Step14PublicStageId.preparingDailySystems,
        stageMin: OnboardingCompletionStage.reconcileHabitSystems,
        stageMax: OnboardingCompletionStage.verifyFrontendState,
        currentStage: currentStage,
        jobStatus: jobStatus,
      ),
      _projectSingle(
        stageId: Step14PublicStageId.preparingHome,
        stageMin: OnboardingCompletionStage.finalizeProfile,
        stageMax: OnboardingCompletionStage.completed,
        currentStage: currentStage,
        jobStatus: jobStatus,
      ),
    ];
  }

  static CompletionStageProjection _projectSingle({
    required Step14PublicStageId stageId,
    required OnboardingCompletionStage stageMin,
    required OnboardingCompletionStage stageMax,
    required OnboardingCompletionStage currentStage,
    required OnboardingJobStatus jobStatus,
  }) {
    final isFailed =
        jobStatus == OnboardingJobStatus.retryableFailure ||
        jobStatus == OnboardingJobStatus.fatalFailure;

    CompletionStageStatus status;
    if (currentStage.index > stageMax.index) {
      status = CompletionStageStatus.completed;
    } else if (currentStage.index >= stageMin.index &&
        currentStage.index <= stageMax.index) {
      if (currentStage == OnboardingCompletionStage.completed) {
        status = CompletionStageStatus.completed;
      } else if (isFailed) {
        status = CompletionStageStatus.failed;
      } else {
        status = CompletionStageStatus.active;
      }
    } else {
      status = CompletionStageStatus.pending;
    }

    return CompletionStageProjection(
      stageId: stageId,
      publicLabel: stageId.publicLabel,
      status: status,
    );
  }
}

/// Determines whether it is authoritatively safe to return to review from failure.
///
/// Derived strictly from completion/currentRun/recovery state:
/// If server-side reconciliation or terminalization has already begun,
/// editing earlier setup is not safe and could create state contradiction.
bool canReturnToStep14Review({
  required OnboardingCompletionJob? job,
  required OnboardingCurrentRunSnapshot currentRunSnapshot,
}) {
  if (currentRunSnapshot.hasPointer) {
    final persisted = currentRunSnapshot.job;
    if (persisted == null ||
        currentRunSnapshot.pointerStatus != 'active' ||
        (persisted.status != OnboardingJobStatus.retryableFailure &&
            persisted.status != OnboardingJobStatus.fatalFailure) ||
        currentRunSnapshot.pointerSchemaVersion != 1 ||
        currentRunSnapshot.runId != persisted.jobId ||
        currentRunSnapshot.ownerUid != persisted.ownerUid ||
        currentRunSnapshot.sourceFingerprint != persisted.sourceFingerprint ||
        currentRunSnapshot.draftRevision != persisted.draftRevision ||
        (job != null && job.jobId != persisted.jobId)) {
      return false;
    }
    if (!_safeReviewJob(persisted)) return false;
  }
  return job == null || _safeReviewJob(job);
}

bool _safeReviewJob(OnboardingCompletionJob job) {
  if (job.status == OnboardingJobStatus.completed ||
      job.stage.index >= OnboardingCompletionStage.reconcileRoutines.index) {
    return false;
  }
  // Failed operations do not advance the durable checkpoint. Reconciliation
  // may already have written outputs before reporting its failure.
  final attempted = job.lastFailureStage;
  if (attempted != null) {
    final stage = OnboardingCompletionStage.values
        .where((stage) => stage.name == attempted)
        .firstOrNull;
    if (stage == null ||
        stage.index >= OnboardingCompletionStage.reconcileRoutines.index) {
      return false;
    }
  }
  return true;
}
