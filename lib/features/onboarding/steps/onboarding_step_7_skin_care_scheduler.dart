import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/services/skin_care_ai_client.dart';

const int onboarding7SkinCareDurationMinutes = 15;

@visibleForTesting
const List<int> onboarding7EveryDay = [1, 2, 3, 4, 5, 6, 7];

class Onboarding7SkinCareScheduleResult {
  final List<TimelineBlockDraft> blocks;
  final String? errorMessage;

  const Onboarding7SkinCareScheduleResult({
    required this.blocks,
    this.errorMessage,
  });

  bool get hasError => errorMessage != null;
}

@visibleForTesting
class Onboarding7SkinCareSlotSpec {
  final String slotLabel;
  final String title;
  final int preferredStartMinute;

  const Onboarding7SkinCareSlotSpec({
    required this.slotLabel,
    required this.title,
    required this.preferredStartMinute,
  });
}

class _ScheduleWindow {
  final int day;
  final int startMinute;
  final int endMinute;

  const _ScheduleWindow({
    required this.day,
    required this.startMinute,
    required this.endMinute,
  });
}

@visibleForTesting
class Onboarding7WakingRange {
  final int startMinute;
  final int endMinute;

  const Onboarding7WakingRange({
    required this.startMinute,
    required this.endMinute,
  });
}

Onboarding7SkinCareScheduleResult onboarding7ScheduleSkinCareRoutine({
  required BaseTimelineDraft baseTimeline,
  required List<SkinCareRoutinePlan> routinePlans,
  required int desiredApplicationsPerDay,
  List<String> fallbackProductNames = const [],
  DateTime? now,
}) {
  final desired = onboarding7NormalizeDesiredApplications(
    desiredApplicationsPerDay,
  );
  final selectedPlans = onboarding7SelectRoutinePlansForSchedule(
    routinePlans,
    desired,
  );
  if (selectedPlans.length < desired) {
    return const Onboarding7SkinCareScheduleResult(
      blocks: [],
      errorMessage:
          'AI returned fewer routine steps than requested. Please try again.',
    );
  }

  final timestamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final occupied = onboarding7OccupiedBlocksForSkinCare(baseTimeline);
  final sleepBlock = _findSleepBlock(occupied);
  final bathBlock = onboarding7FindBathBlock(baseTimeline);
  final wakingRange = _wakingRangeForSleep(sleepBlock);
  final slotSpecs = onboarding7SkinCareSlotSpecs(
    desiredApplicationsPerDay: desired,
    bathBlock: bathBlock,
    wakingRange: wakingRange,
  );
  final scheduled = <TimelineBlockDraft>[];

  for (var index = 0; index < desired; index += 1) {
    final plan = selectedPlans[index];
    final spec = slotSpecs[index];
    final repeatDays = _safeRepeatDays(plan.repeatDays);
    final afterBath = index == 0;
    final minStart = afterBath && bathBlock != null
        ? math.max(wakingRange.startMinute, bathBlock.endMinute + 5)
        : wakingRange.startMinute;
    final maxStart = math.min(
      wakingRange.endMinute - onboarding7SkinCareDurationMinutes,
      24 * 60 - onboarding7SkinCareDurationMinutes,
    );

    if (maxStart < minStart) {
      return Onboarding7SkinCareScheduleResult(
        blocks: const [],
        errorMessage:
            'No free 15-minute skin-care slot was found for ${_dayName(repeatDays.first)}.',
      );
    }

    final preferred = spec.preferredStartMinute
        .clamp(minStart, maxStart)
        .toInt();
    final startMinute = onboarding7FindFreeSkinCareStart(
      preferredStartMinute: preferred,
      repeatDays: repeatDays,
      occupiedBlocks: [...occupied, ...scheduled],
      minStartMinute: minStart,
      maxStartMinute: maxStart,
      searchAfterOnly: afterBath,
    );

    if (startMinute == null) {
      return Onboarding7SkinCareScheduleResult(
        blocks: const [],
        errorMessage:
            'No free 15-minute skin-care slot was found for ${_dayName(repeatDays.first)}.',
      );
    }

    final products = plan.productNames.isEmpty
        ? fallbackProductNames
        : plan.productNames;
    scheduled.add(
      TimelineBlockDraft(
        id: 'skin-care-$timestamp-$index',
        section: 'skin_care',
        title: plan.title.trim().isNotEmpty ? plan.title.trim() : spec.title,
        startMinute: startMinute,
        endMinute: startMinute + onboarding7SkinCareDurationMinutes,
        repeatDays: repeatDays,
        blockType: TimelineBlockDraft.softBlockKey,
        source: 'ai_skin_care_setup',
        skincareProducts: products,
        skincareSteps: plan.steps,
      ),
    );
  }

  return Onboarding7SkinCareScheduleResult(blocks: scheduled);
}

@visibleForTesting
int onboarding7NormalizeDesiredApplications(int value) {
  if (value <= 2) return 2;
  if (value >= 4) return 4;
  return 3;
}

@visibleForTesting
List<TimelineBlockDraft> onboarding7OccupiedBlocksForSkinCare(
  BaseTimelineDraft baseTimeline, {
  String? excludingBlockId,
}) {
  return baseTimeline.blocks
      .where((block) => block.id != excludingBlockId)
      .where((block) => block.section != 'skin_care')
      .where((block) => !block.needsTimeConfirmation)
      .where((block) => block.title.trim().isNotEmpty)
      .toList(growable: false);
}

@visibleForTesting
TimelineBlockDraft? onboarding7FindBathBlock(BaseTimelineDraft baseTimeline) {
  final blocks = baseTimeline.blocks.where(
    (block) => !block.needsTimeConfirmation && block.section == 'fixed',
  );
  for (final block in blocks) {
    if (block.id == BaseTimelineDraft.fixedBathId) return block;
  }
  for (final block in blocks) {
    final title = block.title.toLowerCase();
    if (title.contains('bath') || title.contains('shower')) return block;
  }
  return BaseTimelineDraft.defaultBathBlock();
}

@visibleForTesting
List<Onboarding7SkinCareSlotSpec> onboarding7SkinCareSlotSpecs({
  required int desiredApplicationsPerDay,
  required TimelineBlockDraft? bathBlock,
  required Onboarding7WakingRange wakingRange,
}) {
  final desired = onboarding7NormalizeDesiredApplications(
    desiredApplicationsPerDay,
  );
  final firstStart = (bathBlock?.endMinute ?? 7 * 60 + 30) + 5;
  final nightStart = math.min(21 * 60, wakingRange.endMinute - 45);
  return switch (desired) {
    2 => [
      Onboarding7SkinCareSlotSpec(
        slotLabel: 'morning',
        title: 'Morning Skin Care',
        preferredStartMinute: firstStart,
      ),
      Onboarding7SkinCareSlotSpec(
        slotLabel: 'night',
        title: 'Night Skin Care',
        preferredStartMinute: nightStart,
      ),
    ],
    3 => [
      Onboarding7SkinCareSlotSpec(
        slotLabel: 'morning',
        title: 'Morning Skin Care',
        preferredStartMinute: firstStart,
      ),
      const Onboarding7SkinCareSlotSpec(
        slotLabel: 'midday',
        title: 'Midday Skin Care',
        preferredStartMinute: 13 * 60,
      ),
      Onboarding7SkinCareSlotSpec(
        slotLabel: 'night',
        title: 'Night Skin Care',
        preferredStartMinute: nightStart,
      ),
    ],
    _ => [
      Onboarding7SkinCareSlotSpec(
        slotLabel: 'morning',
        title: 'Morning Skin Care',
        preferredStartMinute: firstStart,
      ),
      const Onboarding7SkinCareSlotSpec(
        slotLabel: 'midday',
        title: 'Midday Skin Care',
        preferredStartMinute: 12 * 60,
      ),
      const Onboarding7SkinCareSlotSpec(
        slotLabel: 'afternoon',
        title: 'Afternoon Skin Care',
        preferredStartMinute: 16 * 60,
      ),
      Onboarding7SkinCareSlotSpec(
        slotLabel: 'night',
        title: 'Night Skin Care',
        preferredStartMinute: nightStart,
      ),
    ],
  };
}

@visibleForTesting
List<SkinCareRoutinePlan> onboarding7SelectRoutinePlansForSchedule(
  List<SkinCareRoutinePlan> plans,
  int desiredApplicationsPerDay,
) {
  final desired = onboarding7NormalizeDesiredApplications(
    desiredApplicationsPerDay,
  );
  final targetSlots = switch (desired) {
    2 => const ['morning', 'night'],
    3 => const ['morning', 'midday', 'night'],
    _ => const ['morning', 'midday', 'afternoon', 'night'],
  };
  final unused = plans.toList();
  final selected = <SkinCareRoutinePlan>[];

  for (final slot in targetSlots) {
    final matchIndex = unused.indexWhere(
      (plan) => _slotCompatible(plan.slotLabel, slot),
    );
    if (matchIndex >= 0) {
      selected.add(unused.removeAt(matchIndex));
    } else if (unused.isNotEmpty) {
      selected.add(unused.removeAt(0));
    }
  }
  return selected;
}

@visibleForTesting
int? onboarding7FindFreeSkinCareStart({
  required int preferredStartMinute,
  required List<int> repeatDays,
  required List<TimelineBlockDraft> occupiedBlocks,
  required int minStartMinute,
  required int maxStartMinute,
  bool searchAfterOnly = false,
}) {
  final minStart = _roundUpToFive(minStartMinute.clamp(0, 24 * 60 - 1));
  final maxStart = _roundDownToFive(
    maxStartMinute.clamp(0, 24 * 60 - onboarding7SkinCareDurationMinutes),
  );
  if (maxStart < minStart) return null;

  final preferred = _roundToFive(
    preferredStartMinute.clamp(minStart, maxStart),
  );
  if (_isSkinCareStartFree(preferred, repeatDays, occupiedBlocks)) {
    return preferred;
  }

  if (searchAfterOnly) {
    for (
      var start = _roundUpToFive(preferred + 5);
      start <= maxStart;
      start += 5
    ) {
      if (_isSkinCareStartFree(start, repeatDays, occupiedBlocks)) {
        return start;
      }
    }
    return null;
  }

  final maxOffset = math.max(preferred - minStart, maxStart - preferred);
  for (var offset = 5; offset <= maxOffset; offset += 5) {
    final after = preferred + offset;
    if (after <= maxStart &&
        _isSkinCareStartFree(after, repeatDays, occupiedBlocks)) {
      return after;
    }
    final before = preferred - offset;
    if (before >= minStart &&
        _isSkinCareStartFree(before, repeatDays, occupiedBlocks)) {
      return before;
    }
  }
  return null;
}

bool onboarding7SkinCareCandidateConflicts({
  required BaseTimelineDraft baseTimeline,
  required TimelineBlockDraft candidate,
  String? excludingBlockId,
  bool includeSkinCareBlocks = true,
}) {
  final occupied = baseTimeline.blocks
      .where((block) => block.id != excludingBlockId)
      .where((block) => includeSkinCareBlocks || block.section != 'skin_care')
      .where((block) => !block.needsTimeConfirmation)
      .where((block) => block.title.trim().isNotEmpty)
      .toList(growable: false);
  return _candidateConflicts(candidate, occupied);
}

int? onboarding7FindFreeStartForSkinCareEdit({
  required BaseTimelineDraft baseTimeline,
  required TimelineBlockDraft block,
  required int preferredStartMinute,
}) {
  final sleepBlock = _findSleepBlock(baseTimeline.blocks);
  final wakingRange = _wakingRangeForSleep(sleepBlock);
  return onboarding7FindFreeSkinCareStart(
    preferredStartMinute: preferredStartMinute,
    repeatDays: _safeRepeatDays(block.repeatDays),
    occupiedBlocks: baseTimeline.blocks
        .where((item) => item.id != block.id)
        .where((item) => !item.needsTimeConfirmation)
        .where((item) => item.title.trim().isNotEmpty)
        .toList(growable: false),
    minStartMinute: wakingRange.startMinute,
    maxStartMinute: wakingRange.endMinute - onboarding7SkinCareDurationMinutes,
  );
}

TimelineBlockDraft? _findSleepBlock(Iterable<TimelineBlockDraft> blocks) {
  for (final block in blocks) {
    if (block.id == BaseTimelineDraft.fixedSleepId) return block;
  }
  for (final block in blocks) {
    final title = block.title.toLowerCase();
    if (block.section == 'fixed' &&
        (title.contains('sleep') || title.contains('bed'))) {
      return block;
    }
  }
  return null;
}

Onboarding7WakingRange _wakingRangeForSleep(TimelineBlockDraft? sleepBlock) {
  if (sleepBlock == null) {
    return const Onboarding7WakingRange(
      startMinute: 6 * 60,
      endMinute: 23 * 60,
    );
  }
  if (sleepBlock.crossesMidnight ||
      sleepBlock.endMinute <= sleepBlock.startMinute) {
    final start = sleepBlock.endMinute.clamp(5 * 60, 11 * 60).toInt();
    final end = sleepBlock.startMinute.clamp(19 * 60, 24 * 60).toInt();
    if (end - start >= onboarding7SkinCareDurationMinutes) {
      return Onboarding7WakingRange(startMinute: start, endMinute: end);
    }
  }
  return const Onboarding7WakingRange(startMinute: 6 * 60, endMinute: 23 * 60);
}

bool _slotCompatible(String rawSlot, String targetSlot) {
  final slot = rawSlot.toLowerCase().trim();
  if (slot.isEmpty || slot == 'custom') return false;
  if (slot == targetSlot) return true;
  if (targetSlot == 'midday') {
    return slot == 'noon' || slot == 'lunch' || slot == 'afternoon';
  }
  if (targetSlot == 'night') {
    return slot == 'evening' || slot == 'pm' || slot == 'bedtime';
  }
  if (targetSlot == 'morning') {
    return slot == 'am' || slot == 'after_bath';
  }
  return false;
}

bool _isSkinCareStartFree(
  int startMinute,
  List<int> repeatDays,
  List<TimelineBlockDraft> occupiedBlocks,
) {
  final candidate = TimelineBlockDraft(
    id: 'candidate',
    section: 'skin_care',
    title: 'Skin Care',
    startMinute: startMinute,
    endMinute: startMinute + onboarding7SkinCareDurationMinutes,
    repeatDays: _safeRepeatDays(repeatDays),
    blockType: TimelineBlockDraft.softBlockKey,
  );
  return !_candidateConflicts(candidate, occupiedBlocks);
}

bool _candidateConflicts(
  TimelineBlockDraft candidate,
  List<TimelineBlockDraft> occupiedBlocks,
) {
  final candidateWindows = _windowsFor(candidate);
  for (final block in occupiedBlocks) {
    for (final candidateWindow in candidateWindows) {
      for (final blockWindow in _windowsFor(block)) {
        if (candidateWindow.day != blockWindow.day) continue;
        if (candidateWindow.startMinute < blockWindow.endMinute &&
            candidateWindow.endMinute > blockWindow.startMinute) {
          return true;
        }
      }
    }
  }
  return false;
}

List<_ScheduleWindow> _windowsFor(TimelineBlockDraft block) {
  final windows = <_ScheduleWindow>[];
  final repeatDays = _safeRepeatDays(block.repeatDays);
  final crossesMidnight =
      block.crossesMidnight ||
      block.endsNextDay ||
      block.endMinute <= block.startMinute;
  for (final day in repeatDays) {
    if (crossesMidnight) {
      windows.add(
        _ScheduleWindow(
          day: day,
          startMinute: block.startMinute,
          endMinute: 24 * 60,
        ),
      );
      windows.add(
        _ScheduleWindow(
          day: day == 7 ? 1 : day + 1,
          startMinute: 0,
          endMinute: block.endMinute,
        ),
      );
    } else {
      windows.add(
        _ScheduleWindow(
          day: day,
          startMinute: block.startMinute,
          endMinute: block.endMinute,
        ),
      );
    }
  }
  return windows;
}

List<int> _safeRepeatDays(List<int> repeatDays) {
  final days = repeatDays.where((day) => day >= 1 && day <= 7).toSet().toList()
    ..sort();
  return days.isEmpty ? onboarding7EveryDay : days;
}

int _roundToFive(int value) =>
    ((value / 5).round() * 5).clamp(0, 24 * 60).toInt();

int _roundUpToFive(int value) =>
    (((value + 4) ~/ 5) * 5).clamp(0, 24 * 60).toInt();

int _roundDownToFive(int value) => ((value ~/ 5) * 5).clamp(0, 24 * 60).toInt();

String _dayName(int day) {
  return const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][(day - 1).clamp(0, 6)];
}
