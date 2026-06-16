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
class Onboarding7RoutinePlanAdaptationResult {
  final List<SkinCareRoutinePlan> plans;
  final String? errorMessage;

  const Onboarding7RoutinePlanAdaptationResult({
    required this.plans,
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
  final bathBlock = onboarding7FindBathBlock(baseTimeline);
  if (bathBlock == null) {
    return const Onboarding7SkinCareScheduleResult(
      blocks: [],
      errorMessage: 'Set bath time first.',
    );
  }

  final adaptedPlans = onboarding7AdaptRoutinePlansForSchedule(
    routinePlans: routinePlans,
    desiredApplicationsPerDay: desired,
    fallbackProductNames: fallbackProductNames,
  );
  if (adaptedPlans.hasError || adaptedPlans.plans.length < desired) {
    return Onboarding7SkinCareScheduleResult(
      blocks: [],
      errorMessage:
          adaptedPlans.errorMessage ??
          'AI returned fewer safe routine steps than requested.',
    );
  }

  final timestamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final occupied = onboarding7OccupiedBlocksForSkinCare(baseTimeline);
  final sleepBlock = _findSleepBlock(occupied);
  final wakingRange = _wakingRangeForSleep(sleepBlock);
  final slotSpecs = onboarding7SkinCareSlotSpecs(
    desiredApplicationsPerDay: desired,
    bathBlock: bathBlock,
    wakingRange: wakingRange,
  );
  final scheduledSingles = <TimelineBlockDraft>[];

  for (var index = 0; index < desired; index += 1) {
    final plan = adaptedPlans.plans[index];
    final spec = slotSpecs[index];
    final repeatDays = _safeRepeatDays(plan.repeatDays);

    for (final day in repeatDays) {
      final bathWindow = _windowForDay(bathBlock, day);
      if (bathWindow == null) {
        return const Onboarding7SkinCareScheduleResult(
          blocks: [],
          errorMessage: 'Set bath time first.',
        );
      }

      final afterBath = index == 0;
      final minStart = afterBath
          ? math.max(wakingRange.startMinute, bathWindow.endMinute + 5)
          : wakingRange.startMinute;
      final maxStart = math.min(
        wakingRange.endMinute - onboarding7SkinCareDurationMinutes,
        24 * 60 - onboarding7SkinCareDurationMinutes,
      );

      if (maxStart < minStart) {
        return Onboarding7SkinCareScheduleResult(
          blocks: const [],
          errorMessage:
              'No free 15-minute skin-care slot was found for ${_dayName(day)}.',
        );
      }

      final preferred = spec.preferredStartMinute
          .clamp(minStart, maxStart)
          .toInt();
      final startMinute = onboarding7FindFreeSkinCareStart(
        preferredStartMinute: preferred,
        repeatDays: [day],
        occupiedBlocks: [...occupied, ...scheduledSingles],
        minStartMinute: minStart,
        maxStartMinute: maxStart,
        searchAfterOnly: afterBath,
      );

      if (startMinute == null) {
        return Onboarding7SkinCareScheduleResult(
          blocks: const [],
          errorMessage:
              'No free 15-minute skin-care slot was found for ${_dayName(day)}.',
        );
      }

      final products = plan.productNames.isEmpty
          ? fallbackProductNames
          : plan.productNames;
      scheduledSingles.add(
        TimelineBlockDraft(
          id: 'skin-care-$timestamp-$index-$day',
          section: 'skin_care',
          title: plan.title.trim().isNotEmpty ? plan.title.trim() : spec.title,
          startMinute: startMinute,
          endMinute: startMinute + onboarding7SkinCareDurationMinutes,
          repeatDays: [day],
          blockType: TimelineBlockDraft.softBlockKey,
          source: 'ai_skin_care_setup',
          skincareProducts: products,
          skincareSteps: plan.steps,
          skincareSlotLabel: spec.slotLabel,
        ),
      );
    }
  }

  return Onboarding7SkinCareScheduleResult(
    blocks: _groupSkinCareBlocks(scheduledSingles, timestamp),
  );
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
  return null;
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
  final firstStart = (bathBlock?.endMinute ?? wakingRange.startMinute) + 5;
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
  return onboarding7AdaptRoutinePlansForSchedule(
    routinePlans: plans,
    desiredApplicationsPerDay: desiredApplicationsPerDay,
  ).plans;
}

@visibleForTesting
Onboarding7RoutinePlanAdaptationResult onboarding7AdaptRoutinePlansForSchedule({
  required List<SkinCareRoutinePlan> routinePlans,
  required int desiredApplicationsPerDay,
  List<String> fallbackProductNames = const [],
}) {
  final desired = onboarding7NormalizeDesiredApplications(
    desiredApplicationsPerDay,
  );
  final targetSlots = switch (desired) {
    2 => const ['morning', 'night'],
    3 => const ['morning', 'midday', 'night'],
    _ => const ['morning', 'midday', 'afternoon', 'night'],
  };
  final slotSpecs = onboarding7SkinCareSlotSpecs(
    desiredApplicationsPerDay: desired,
    bathBlock: null,
    wakingRange: const Onboarding7WakingRange(
      startMinute: 6 * 60,
      endMinute: 23 * 60,
    ),
  );
  final unused = routinePlans.toList();
  final selected = <SkinCareRoutinePlan>[];
  final productBasis = _dedupeStrings([
    ...fallbackProductNames,
    for (final plan in routinePlans) ...plan.productNames,
  ]);
  final textBasis = _dedupeStrings([
    ...productBasis,
    for (final plan in routinePlans) ...plan.steps,
  ]);

  for (var index = 0; index < targetSlots.length; index += 1) {
    final slot = targetSlots[index];
    final spec = slotSpecs[index];
    final matchIndex = unused.indexWhere(
      (plan) => _slotCompatible(plan.slotLabel, slot),
    );
    if (matchIndex >= 0) {
      selected.add(_planForSlot(unused.removeAt(matchIndex), slot, spec.title));
      continue;
    }

    final generated = _generatedPlanForMissingSlot(
      slot: slot,
      title: spec.title,
      productBasis: productBasis,
      textBasis: textBasis,
    );
    if (generated == null) {
      return Onboarding7RoutinePlanAdaptationResult(
        plans: selected,
        errorMessage: _missingSlotMessage(slot),
      );
    }
    selected.add(generated);
  }
  return Onboarding7RoutinePlanAdaptationResult(plans: selected);
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

List<TimelineBlockDraft> _groupSkinCareBlocks(
  List<TimelineBlockDraft> singles,
  int timestamp,
) {
  final grouped = <String, TimelineBlockDraft>{};
  for (final block in singles) {
    final key = [
      block.title.trim().toLowerCase(),
      block.startMinute,
      block.endMinute,
      block.skincareSlotLabel?.trim().toLowerCase() ?? '',
      block.skincareSteps.join('\u001f'),
      block.skincareProducts.join('\u001f'),
    ].join('\u001e');
    final existing = grouped[key];
    if (existing == null) {
      grouped[key] = block;
      continue;
    }
    final repeatDays = {...existing.repeatDays, ...block.repeatDays}.toList()
      ..sort();
    grouped[key] = existing.copyWith(repeatDays: repeatDays);
  }

  final result = grouped.values.toList()
    ..sort((a, b) {
      final startCompare = a.startMinute.compareTo(b.startMinute);
      if (startCompare != 0) return startCompare;
      return a.title.compareTo(b.title);
    });
  return [
    for (var index = 0; index < result.length; index += 1)
      result[index].copyWith(id: 'skin-care-$timestamp-group-$index'),
  ];
}

_ScheduleWindow? _windowForDay(TimelineBlockDraft block, int day) {
  final candidates = _windowsFor(block)
      .where((window) => window.day == day)
      .where(
        (window) =>
            window.endMinute - window.startMinute >= 0 &&
            window.endMinute <= 24 * 60,
      )
      .toList(growable: false);
  if (candidates.isEmpty) return null;
  return candidates.reduce((a, b) => a.endMinute >= b.endMinute ? a : b);
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

SkinCareRoutinePlan _planForSlot(
  SkinCareRoutinePlan plan,
  String slot,
  String fallbackTitle,
) {
  return SkinCareRoutinePlan(
    slotLabel: slot,
    title: plan.title.trim().isEmpty ? fallbackTitle : plan.title.trim(),
    steps: plan.steps,
    productNames: plan.productNames,
    warnings: plan.warnings,
    repeatDays: plan.repeatDays,
  );
}

SkinCareRoutinePlan? _generatedPlanForMissingSlot({
  required String slot,
  required String title,
  required List<String> productBasis,
  required List<String> textBasis,
}) {
  final sunscreenProducts = productBasis
      .where((item) => _looksLikeSunscreen(item))
      .toList(growable: false);
  final cleanserProducts = productBasis
      .where((item) => _looksLikeCleanser(item))
      .toList(growable: false);
  final moisturizerProducts = productBasis
      .where((item) => _looksLikeMoisturizer(item))
      .toList(growable: false);
  final hasSunscreen =
      sunscreenProducts.isNotEmpty ||
      textBasis.any((item) => _looksLikeSunscreen(item));
  final hasCleanser =
      cleanserProducts.isNotEmpty ||
      textBasis.any((item) => _looksLikeCleanser(item));
  final hasMoisturizer =
      moisturizerProducts.isNotEmpty ||
      textBasis.any((item) => _looksLikeMoisturizer(item));

  if (slot == 'midday' || slot == 'afternoon') {
    if (!hasSunscreen) return null;
    return SkinCareRoutinePlan(
      slotLabel: slot,
      title: title,
      steps: const ['Refresh skin', 'Reapply sunscreen'],
      productNames: sunscreenProducts.isEmpty
          ? const ['Sunscreen']
          : sunscreenProducts,
    );
  }

  if (slot == 'morning') {
    if (!hasSunscreen) return null;
    return SkinCareRoutinePlan(
      slotLabel: slot,
      title: title,
      steps: [if (hasCleanser) 'Cleanse face', 'Apply sunscreen'],
      productNames: _dedupeStrings([
        if (cleanserProducts.isNotEmpty) cleanserProducts.first,
        if (sunscreenProducts.isEmpty) 'Sunscreen' else sunscreenProducts.first,
      ]),
    );
  }

  if (slot == 'night') {
    if (!hasCleanser && !hasMoisturizer) return null;
    return SkinCareRoutinePlan(
      slotLabel: slot,
      title: title,
      steps: [
        if (hasCleanser) 'Cleanse face',
        if (hasMoisturizer) 'Apply moisturizer',
      ],
      productNames: _dedupeStrings([
        if (cleanserProducts.isNotEmpty) cleanserProducts.first,
        if (moisturizerProducts.isNotEmpty) moisturizerProducts.first,
      ]),
    );
  }
  return null;
}

String _missingSlotMessage(String slot) {
  if (slot == 'midday' || slot == 'afternoon' || slot == 'morning') {
    return 'Add a sunscreen product so this routine can be safely scheduled $slot.';
  }
  return 'AI did not return enough safe products to build a night routine.';
}

bool _looksLikeSunscreen(String value) {
  final lower = value.toLowerCase();
  return lower.contains('sunscreen') || lower.contains('spf');
}

bool _looksLikeCleanser(String value) {
  final lower = value.toLowerCase();
  return lower.contains('cleanser') ||
      lower.contains('face wash') ||
      lower.contains('wash face') ||
      lower.contains('cleanse');
}

bool _looksLikeMoisturizer(String value) {
  final lower = value.toLowerCase();
  return lower.contains('moistur') ||
      lower.contains('cream') ||
      lower.contains('lotion');
}

List<String> _dedupeStrings(Iterable<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final raw in values) {
    final value = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty) continue;
    if (seen.add(value.toLowerCase())) result.add(value);
  }
  return result;
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
