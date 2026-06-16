import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/services/skin_care_ai_client.dart';

const int onboarding7SkinCareDurationMinutes = 15;

const List<int> onboarding7EveryDay = [1, 2, 3, 4, 5, 6, 7];
const String _noRoutineMessage =
    'AI could not build a routine from these products. Try typing the product names clearly.';
const String _unsafeFrequencyMessage =
    'These products may not safely support this many daily routines. Try fewer routines or add more basic products.';
const List<String> _schedulableSlotLabels = [
  'morning',
  'midday',
  'afternoon',
  'night',
];
const List<String> _daytimeSlotLabels = ['morning', 'midday', 'afternoon'];

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
bool onboarding7IsSpecialCarePlan(SkinCareRoutinePlan plan) {
  final fields = [
    plan.title,
    plan.slotLabel,
    ...plan.steps,
    ...plan.productNames,
    ...plan.warnings,
  ];

  if (!fields.any(_looksLikeStrongActive)) {
    return false;
  }
  return !_planExplicitlyAllowsDailyStrongActive(plan);
}

class Onboarding7PartitionedPlans {
  final List<SkinCareRoutinePlan> dailyPlans;
  final List<SkinCareRoutinePlan> specialCarePlans;

  const Onboarding7PartitionedPlans({
    required this.dailyPlans,
    required this.specialCarePlans,
  });
}

Onboarding7PartitionedPlans onboarding7PartitionRoutinePlans(
  List<SkinCareRoutinePlan> plans,
) {
  final dailyPlans = <SkinCareRoutinePlan>[];
  final specialCarePlans = <SkinCareRoutinePlan>[];

  for (final plan in plans) {
    if (onboarding7IsSpecialCarePlan(plan)) {
      specialCarePlans.add(plan);
    } else {
      dailyPlans.add(plan);
    }
  }

  return Onboarding7PartitionedPlans(
    dailyPlans: dailyPlans,
    specialCarePlans: specialCarePlans,
  );
}

List<String> onboarding7MissingBasicProductNotes({
  required List<String> productNames,
  required List<SkinCareDetectedProduct> productDetails,
}) {
  final ownedProducts = _ownedProductCatalogFromBasis(
    productNames: productNames,
    productDetails: productDetails,
  );
  if (ownedProducts.isEmpty) return const [];
  return [
    if (!ownedProducts.hasMoisturizer)
      'No moisturizer detected. You can still use your current products, but adding moisturizer may improve night routine balance.',
    if (!ownedProducts.hasSunscreen)
      'No sunscreen detected. Consider adding SPF for daytime protection.',
    if (!ownedProducts.hasCleanser)
      'No cleanser detected. Add a cleanser if you want a complete cleanse step.',
  ];
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

class _OwnedProduct {
  final String name;
  final String category;
  final List<String> searchableFields;

  const _OwnedProduct({
    required this.name,
    required this.category,
    required this.searchableFields,
  });

  bool get isSunscreen =>
      category == 'sunscreen' || searchableFields.any(_looksLikeSunscreen);
  bool get isCleanser =>
      category == 'cleanser' || searchableFields.any(_looksLikeCleanser);
  bool get isMoisturizer =>
      category == 'moisturizer' ||
      category == 'moisturiser' ||
      searchableFields.any(_looksLikeMoisturizer);
  bool get isSerum => searchableFields.any(_looksLikeSerum);
  bool get isStrongActive => searchableFields.any(_looksLikeStrongActive);
}

class _OwnedProductCatalog {
  final List<_OwnedProduct> products;

  const _OwnedProductCatalog(this.products);

  bool get isEmpty => products.isEmpty;
  bool get hasSunscreen => products.any((product) => product.isSunscreen);
  bool get hasCleanser => products.any((product) => product.isCleanser);
  bool get hasMoisturizer => products.any((product) => product.isMoisturizer);
  _OwnedProduct? get sunscreen =>
      _firstWhereOrNull(products, (product) => product.isSunscreen);

  _OwnedProduct? match(String value) {
    final query = _normalizedProductKey(value);
    if (query.isEmpty) return null;
    if (_isGenericProductName(value)) {
      return _matchByCategory(value);
    }

    for (final product in products) {
      final nameKey = _normalizedProductKey(product.name);
      if (nameKey == query) return product;
    }
    for (final product in products) {
      final nameKey = _normalizedProductKey(product.name);
      if (query.length >= 4 &&
          (nameKey.contains(query) || query.contains(nameKey))) {
        return product;
      }
    }
    for (final product in products) {
      if (product.searchableFields
          .map(_normalizedProductKey)
          .where((field) => field.isNotEmpty)
          .any((field) => field == query || field.contains(query))) {
        return product;
      }
    }

    final lower = value.toLowerCase();
    return _matchByCategory(lower);
  }

  _OwnedProduct? _matchByCategory(String value) {
    final lower = value.toLowerCase();
    if (_looksLikeSunscreen(lower)) {
      return _preferredProduct((product) => product.isSunscreen);
    }
    if (_looksLikeCleanser(lower)) {
      return _preferredProduct((product) => product.isCleanser);
    }
    if (_looksLikeMoisturizer(lower)) {
      return _preferredProduct((product) => product.isMoisturizer);
    }
    if (_looksLikeSerum(lower)) {
      return _preferredProduct((product) => product.isSerum);
    }
    return null;
  }

  _OwnedProduct? _preferredProduct(bool Function(_OwnedProduct) test) {
    return _firstWhereOrNull(products, (product) {
          return test(product) && !_isGenericProductName(product.name);
        }) ??
        _firstWhereOrNull(products, test);
  }
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
  List<SkinCareDetectedProduct> fallbackProductDetails = const [],
  bool forceEveryDay = true,
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
    routinePlans: onboarding7PartitionRoutinePlans(routinePlans).dailyPlans,
    desiredApplicationsPerDay: desired,
    fallbackProductNames: fallbackProductNames,
    fallbackProductDetails: fallbackProductDetails,
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
    final spec = _skinCareSlotSpecForLabel(
      plan.slotLabel,
      fallbackSpec: slotSpecs[index],
      bathBlock: bathBlock,
      wakingRange: wakingRange,
    );
    final repeatDays = forceEveryDay
        ? onboarding7EveryDay
        : _safeRepeatDays(plan.repeatDays);

    for (final day in repeatDays) {
      final bathWindow = _windowForDay(bathBlock, day);
      if (bathWindow == null) {
        return const Onboarding7SkinCareScheduleResult(
          blocks: [],
          errorMessage: 'Set bath time first.',
        );
      }

      final afterBath = spec.slotLabel == 'morning';
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

      final products = _dedupeStrings(
        plan.productNames.isEmpty ? fallbackProductNames : plan.productNames,
      );
      final steps = _dedupeStrings(plan.steps);
      if (products.isEmpty) {
        return const Onboarding7SkinCareScheduleResult(
          blocks: [],
          errorMessage:
              'AI could not build a routine from these products. Try typing the product names clearly.',
        );
      }
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
          skincareSteps: steps,
          skincareSlotLabel: spec.slotLabel,
        ),
      );
    }
  }

  return Onboarding7SkinCareScheduleResult(
    blocks: _groupSkinCareBlocks(scheduledSingles, timestamp),
  );
}

int onboarding7NormalizeDesiredApplications(int value) {
  if (value <= 2) return 2;
  if (value >= 4) return 4;
  return 3;
}

int onboarding7RoutineCountForDay(List<TimelineBlockDraft> blocks, int day) {
  return blocks
      .where(
        (block) =>
            block.section == 'skin_care' &&
            !block.needsTimeConfirmation &&
            block.title.trim().isNotEmpty &&
            (block.skincareSteps.isNotEmpty ||
                block.skincareProducts.isNotEmpty) &&
            block.repeatDays.contains(day),
      )
      .length;
}

String? onboarding7MissingRoutineMessage(
  List<TimelineBlockDraft> blocks,
  int desired,
) {
  final normalizedDesired = onboarding7NormalizeDesiredApplications(desired);
  for (final day in onboarding7EveryDay) {
    final count = onboarding7RoutineCountForDay(blocks, day);
    if (count < normalizedDesired) {
      return '${_dayName(day)} has $count of $normalizedDesired skin-care routines. Add or restore one routine.';
    }
  }
  return null;
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
  List<SkinCareDetectedProduct> fallbackProductDetails = const [],
}) {
  final sourcePlans = onboarding7PartitionRoutinePlans(routinePlans).dailyPlans;
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
  final unused = sourcePlans.toList();
  final selectedBySlot = <String, SkinCareRoutinePlan>{};
  final ownedProducts = _ownedProductCatalogFromBasis(
    productNames: fallbackProductNames,
    productDetails: fallbackProductDetails,
  );
  var hasUsableSunscreenIntent = false;
  var usableDailyPlanCount = 0;

  if (sourcePlans.isEmpty || ownedProducts.isEmpty) {
    return Onboarding7RoutinePlanAdaptationResult(
      plans: const [],
      errorMessage: _noRoutineMessage,
    );
  }

  for (var index = 0; index < targetSlots.length; index += 1) {
    final slot = targetSlots[index];
    final spec = slotSpecs[index];
    final matchIndex = unused.indexWhere(
      (plan) => _slotCompatible(plan.slotLabel, slot, targetSlots: targetSlots),
    );
    if (matchIndex >= 0) {
      final rawPlan = unused.removeAt(matchIndex);
      final selectedPlan = _ownedProductPlanForSlot(
        plan: rawPlan,
        slot: slot,
        title: spec.title,
        ownedProducts: ownedProducts,
      );
      if (selectedPlan != null) {
        hasUsableSunscreenIntent =
            hasUsableSunscreenIntent ||
            _planUsesSunscreen(selectedPlan, ownedProducts);
        usableDailyPlanCount += 1;
        selectedBySlot[slot] = selectedPlan;
      }
    }
  }

  if (usableDailyPlanCount == 0) {
    for (final rawPlan in unused.toList(growable: false)) {
      final slot = _canonicalSlotLabel(rawPlan.slotLabel);
      if (!_schedulableSlotLabels.contains(slot) ||
          selectedBySlot.containsKey(slot)) {
        continue;
      }
      final selectedPlan = _ownedProductPlanForSlot(
        plan: rawPlan,
        slot: slot,
        title: _titleForSlot(slot),
        ownedProducts: ownedProducts,
      );
      if (selectedPlan == null) continue;
      unused.remove(rawPlan);
      hasUsableSunscreenIntent =
          hasUsableSunscreenIntent ||
          _planUsesSunscreen(selectedPlan, ownedProducts);
      usableDailyPlanCount += 1;
      selectedBySlot[slot] = selectedPlan;
      break;
    }
  }

  if (usableDailyPlanCount == 0) {
    return Onboarding7RoutinePlanAdaptationResult(
      plans: const [],
      errorMessage: _noRoutineMessage,
    );
  }

  for (final rawPlan in unused.toList(growable: false)) {
    if (selectedBySlot.length >= desired) break;
    final slot = _canonicalSlotLabel(rawPlan.slotLabel);
    if (!_schedulableSlotLabels.contains(slot) ||
        selectedBySlot.containsKey(slot)) {
      continue;
    }
    final selectedPlan = _ownedProductPlanForSlot(
      plan: rawPlan,
      slot: slot,
      title: _titleForSlot(slot),
      ownedProducts: ownedProducts,
    );
    if (selectedPlan == null) continue;
    unused.remove(rawPlan);
    hasUsableSunscreenIntent =
        hasUsableSunscreenIntent ||
        _planUsesSunscreen(selectedPlan, ownedProducts);
    selectedBySlot[slot] = selectedPlan;
  }

  for (var index = 0; index < targetSlots.length; index += 1) {
    if (selectedBySlot.length >= desired) break;
    final slot = targetSlots[index];
    if (selectedBySlot.containsKey(slot)) continue;
    if (!_daytimeSlotLabels.contains(slot)) continue;

    final generated = _generatedSunscreenPlanForMissingDaytimeSlot(
      slot: slot,
      title: slotSpecs[index].title,
      ownedProducts: ownedProducts,
      hasUsableSunscreenIntent: hasUsableSunscreenIntent,
    );
    if (generated == null) continue;
    selectedBySlot[slot] = generated;
  }

  for (final slot in _daytimeSlotLabels) {
    if (selectedBySlot.length >= desired) break;
    if (selectedBySlot.containsKey(slot)) continue;
    final generated = _generatedSunscreenPlanForMissingDaytimeSlot(
      slot: slot,
      title: _titleForSlot(slot),
      ownedProducts: ownedProducts,
      hasUsableSunscreenIntent: hasUsableSunscreenIntent,
    );
    if (generated == null) continue;
    selectedBySlot[slot] = generated;
  }

  final selected = _orderedSelectedPlans(
    selectedBySlot,
  ).take(desired).toList(growable: false);
  if (selected.length < desired) {
    return Onboarding7RoutinePlanAdaptationResult(
      plans: selected,
      errorMessage: _unsafeFrequencyMessage,
    );
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

Onboarding7SkinCareSlotSpec _skinCareSlotSpecForLabel(
  String rawSlot, {
  required Onboarding7SkinCareSlotSpec fallbackSpec,
  required TimelineBlockDraft? bathBlock,
  required Onboarding7WakingRange wakingRange,
}) {
  final slot = _canonicalSlotLabel(rawSlot);
  final firstStart = (bathBlock?.endMinute ?? wakingRange.startMinute) + 5;
  final nightStart = math.min(21 * 60, wakingRange.endMinute - 45);
  return switch (slot) {
    'morning' => Onboarding7SkinCareSlotSpec(
      slotLabel: 'morning',
      title: 'Morning Skin Care',
      preferredStartMinute: firstStart,
    ),
    'midday' => const Onboarding7SkinCareSlotSpec(
      slotLabel: 'midday',
      title: 'Midday Skin Care',
      preferredStartMinute: 13 * 60,
    ),
    'afternoon' => const Onboarding7SkinCareSlotSpec(
      slotLabel: 'afternoon',
      title: 'Afternoon Skin Care',
      preferredStartMinute: 16 * 60,
    ),
    'night' => Onboarding7SkinCareSlotSpec(
      slotLabel: 'night',
      title: 'Night Skin Care',
      preferredStartMinute: nightStart,
    ),
    _ => fallbackSpec,
  };
}

bool _slotCompatible(
  String rawSlot,
  String targetSlot, {
  required List<String> targetSlots,
}) {
  final slot = _canonicalSlotLabel(rawSlot);
  if (slot.isEmpty || slot == 'custom') return false;
  if (slot == targetSlot) return true;
  if (targetSlot == 'midday') {
    final hasSeparateAfternoon = targetSlots.contains('afternoon');
    return slot == 'noon' ||
        slot == 'lunch' ||
        (!hasSeparateAfternoon && slot == 'afternoon');
  }
  if (targetSlot == 'night') {
    return slot == 'evening' || slot == 'pm' || slot == 'bedtime';
  }
  if (targetSlot == 'morning') {
    return slot == 'am' || slot == 'after_bath';
  }
  return false;
}

String _canonicalSlotLabel(String rawSlot) {
  final slot = rawSlot.toLowerCase().trim().replaceAll('-', '_');
  return switch (slot) {
    'am' || 'after_bath' => 'morning',
    'noon' || 'lunch' => 'midday',
    'evening' || 'pm' || 'bedtime' => 'night',
    _ => slot,
  };
}

String _titleForSlot(String slot) {
  return switch (slot) {
    'morning' => 'Morning Skin Care',
    'midday' => 'Midday Skin Care',
    'afternoon' => 'Afternoon Skin Care',
    'night' => 'Night Skin Care',
    _ => 'Skin Care',
  };
}

List<SkinCareRoutinePlan> _orderedSelectedPlans(
  Map<String, SkinCareRoutinePlan> selectedBySlot,
) {
  final ordered = <SkinCareRoutinePlan>[];
  for (final slot in _schedulableSlotLabels) {
    final plan = selectedBySlot[slot];
    if (plan != null) ordered.add(plan);
  }
  for (final entry in selectedBySlot.entries) {
    if (!_schedulableSlotLabels.contains(entry.key)) {
      ordered.add(entry.value);
    }
  }
  return ordered;
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

SkinCareRoutinePlan? _ownedProductPlanForSlot({
  required SkinCareRoutinePlan plan,
  required String slot,
  required String title,
  required _OwnedProductCatalog ownedProducts,
}) {
  final normalized = _planForSlot(plan, slot, title);
  final matchedProducts = _matchedOwnedProductsForPlan(
    normalized,
    ownedProducts,
  );
  if (matchedProducts == null || matchedProducts.isEmpty) return null;
  if (_planUsesOnlyNightSunscreen(normalized, matchedProducts)) return null;
  if (_planRepeatsStrongActive(normalized, matchedProducts)) return null;

  return SkinCareRoutinePlan(
    slotLabel: slot,
    title: normalized.title.trim().isEmpty ? title : normalized.title.trim(),
    steps: _safeStepsForPlan(normalized),
    productNames: _dedupeStrings(
      matchedProducts.map((product) => product.name),
    ),
    warnings: normalized.warnings,
    repeatDays: normalized.repeatDays,
  );
}

List<_OwnedProduct>? _matchedOwnedProductsForPlan(
  SkinCareRoutinePlan plan,
  _OwnedProductCatalog ownedProducts,
) {
  final matched = <_OwnedProduct>[];
  if (plan.productNames.isNotEmpty) {
    for (final productName in plan.productNames) {
      final product = ownedProducts.match(productName);
      if (product == null) return null;
      matched.add(product);
    }
    return _dedupeOwnedProducts(matched);
  }

  if (!_hasMeaningfulRoutineStep(plan.steps)) return null;
  for (final step in plan.steps) {
    final product = _ownedProductForStep(step, ownedProducts);
    if (product != null) matched.add(product);
  }
  return matched.isEmpty ? null : _dedupeOwnedProducts(matched);
}

bool _hasMeaningfulRoutineStep(List<String> steps) {
  return steps
      .map((step) => step.trim())
      .where((step) => step.isNotEmpty)
      .any((step) => !_stepLooksLikeUnsafeSpecialCare(step));
}

_OwnedProduct? _ownedProductForStep(
  String step,
  _OwnedProductCatalog ownedProducts,
) {
  final lower = step.toLowerCase();
  if (_looksLikeSunscreen(lower) || lower.contains('sun protection')) {
    return ownedProducts.sunscreen;
  }
  if (_looksLikeCleanser(lower)) {
    return _firstWhereOrNull(ownedProducts.products, (product) {
      return product.isCleanser;
    });
  }
  if (_stepMentionsMoisturizer(lower)) {
    return _firstWhereOrNull(ownedProducts.products, (product) {
      return product.isMoisturizer;
    });
  }
  if (_looksLikeSerum(lower)) {
    return _firstWhereOrNull(ownedProducts.products, (product) {
      return product.isSerum;
    });
  }
  return null;
}

bool _planUsesOnlyNightSunscreen(
  SkinCareRoutinePlan plan,
  List<_OwnedProduct> products,
) {
  return plan.slotLabel == 'night' &&
      products.isNotEmpty &&
      products.every((product) => product.isSunscreen);
}

bool _planRepeatsStrongActive(
  SkinCareRoutinePlan plan,
  List<_OwnedProduct> products,
) {
  if (_planExplicitlyAllowsDailyStrongActive(plan)) return false;
  if (!products.any((product) => product.isStrongActive)) return false;
  final repeatDays = _safeRepeatDays(plan.repeatDays);
  return repeatDays.length >= 7;
}

bool _planUsesSunscreen(
  SkinCareRoutinePlan plan,
  _OwnedProductCatalog ownedProducts,
) {
  return plan.productNames
      .map(ownedProducts.match)
      .whereType<_OwnedProduct>()
      .any((product) => product.isSunscreen);
}

SkinCareRoutinePlan? _generatedSunscreenPlanForMissingDaytimeSlot({
  required String slot,
  required String title,
  required _OwnedProductCatalog ownedProducts,
  required bool hasUsableSunscreenIntent,
}) {
  if (!hasUsableSunscreenIntent || !_daytimeSlotLabels.contains(slot)) {
    return null;
  }
  final sunscreen = ownedProducts.sunscreen;
  if (sunscreen == null) return null;
  return SkinCareRoutinePlan(
    slotLabel: slot,
    title: title,
    steps: [slot == 'morning' ? 'Apply sunscreen' : 'Reapply sunscreen'],
    productNames: [sunscreen.name],
  );
}

_OwnedProductCatalog _ownedProductCatalogFromBasis({
  required List<String> productNames,
  required List<SkinCareDetectedProduct> productDetails,
}) {
  final entries = <_OwnedProduct>[
    for (final product in productDetails)
      if (product.fallbackLabel.trim().isNotEmpty)
        _OwnedProduct(
          name: product.fallbackLabel.trim(),
          category: product.category.trim().toLowerCase(),
          searchableFields: _dedupeStrings(product.searchableFields),
        ),
    for (final name in productNames)
      if (name.trim().isNotEmpty)
        _OwnedProduct(
          name: name.trim(),
          category: _categoryForProductName(name),
          searchableFields: [name.trim()],
        ),
  ];

  final seen = <String>{};
  return _OwnedProductCatalog(
    entries
        .where((entry) {
          return seen.add(_normalizedProductKey(entry.name));
        })
        .toList(growable: false),
  );
}

List<String> _safeStepsForPlan(SkinCareRoutinePlan plan) {
  final steps = <String>[];
  final allowStrongActive = _planExplicitlyAllowsDailyStrongActive(plan);
  for (final raw in plan.steps) {
    final step = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (step.isEmpty) continue;
    if (!allowStrongActive && _stepLooksLikeUnsafeSpecialCare(step)) continue;
    steps.add(step);
  }
  return _dedupeStrings(steps);
}

bool _stepLooksLikeUnsafeSpecialCare(String value) {
  return _looksLikeStrongActive(value);
}

bool _stepMentionsMoisturizer(String value) {
  final lower = value.toLowerCase();
  return lower.contains('moisturiz') ||
      lower.contains('moisturis') ||
      _looksLikeMoisturizer(lower);
}

String _categoryForProductName(String value) {
  final lower = value.toLowerCase();
  if (_looksLikeSunscreen(lower)) return 'sunscreen';
  if (_looksLikeCleanser(lower)) return 'cleanser';
  if (_looksLikeMoisturizer(lower)) return 'moisturizer';
  if (_looksLikeSerum(lower)) return 'serum';
  return '';
}

String _normalizedProductKey(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

bool _isGenericProductName(String value) {
  final key = _normalizedProductKey(value);
  return const {
    'sunscreen',
    'spf',
    'cleanser',
    'face wash',
    'moisturizer',
    'moisturiser',
    'serum',
  }.contains(key);
}

List<_OwnedProduct> _dedupeOwnedProducts(Iterable<_OwnedProduct> products) {
  final seen = <String>{};
  final result = <_OwnedProduct>[];
  for (final product in products) {
    if (seen.add(_normalizedProductKey(product.name))) {
      result.add(product);
    }
  }
  return result;
}

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
  for (final value in values) {
    if (test(value)) return value;
  }
  return null;
}

bool _planExplicitlyAllowsDailyStrongActive(SkinCareRoutinePlan plan) {
  final content = [
    plan.title,
    ...plan.steps,
    ...plan.productNames,
    ...plan.warnings,
  ].join(' ').toLowerCase();
  return content.contains('safe daily') ||
      content.contains('safe for daily') ||
      content.contains('safe to use daily') ||
      content.contains('daily safe') ||
      content.contains('daily use is safe');
}

bool _looksLikeSunscreen(String value) {
  final lower = value.toLowerCase();
  return lower.contains('sunscreen') ||
      lower.contains('spf') ||
      lower.contains('sun cream') ||
      lower.contains('suncream') ||
      lower.contains('sunblock') ||
      lower.contains('uv') ||
      lower.contains('pa++++') ||
      lower.contains('pa ++++') ||
      lower.contains('uv filter') ||
      lower.contains('uv-filter');
}

bool _looksLikeCleanser(String value) {
  final lower = value.toLowerCase();
  return lower.contains('cleanser') ||
      lower.contains('face wash') ||
      lower.contains('wash face') ||
      lower.contains('cleansing gel') ||
      lower.contains('cleansing foam') ||
      lower.contains('micellar') ||
      lower.contains('cleanse');
}

bool _looksLikeMoisturizer(String value) {
  final lower = value.toLowerCase();
  if (_looksLikeSunscreen(lower) ||
      lower.contains('uv protector') ||
      lower.contains('sun protection')) {
    return false;
  }
  return lower.contains('moisturizer') ||
      lower.contains('moisturiser') ||
      lower.contains('barrier cream') ||
      lower.contains('gel cream') ||
      lower.contains('lotion') ||
      lower.contains('barrier repair');
}

bool _looksLikeSerum(String value) {
  final lower = value.toLowerCase();
  return lower.contains('serum') ||
      lower.contains('ampoule') ||
      lower.contains('essence');
}

bool _looksLikeStrongActive(String value) {
  final lower = value.toLowerCase();
  return lower.contains('retinol') ||
      lower.contains('retinal') ||
      lower.contains('tretinoin') ||
      lower.contains('adapalene') ||
      lower.contains('exfoliant') ||
      lower.contains('exfoliate') ||
      lower.contains('peeling') ||
      lower.contains('peel') ||
      lower.contains('aha') ||
      lower.contains('bha') ||
      lower.contains('glycolic') ||
      lower.contains('lactic') ||
      lower.contains('salicylic') ||
      lower.contains('mandelic') ||
      lower.contains('benzoyl peroxide') ||
      lower.contains('strong active');
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
