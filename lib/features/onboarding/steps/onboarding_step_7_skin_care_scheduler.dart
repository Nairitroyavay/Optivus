import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/services/skin_care_ai_client.dart';

const int onboarding7SkinCareDurationMinutes = 15;
const int onboarding7SkinCareMinimumGapMinutes = 60;

const int _onboarding7DefaultLunchStartMinute = 13 * 60;
const int _onboarding7FallbackLunchDurationMinutes = 35;
const int _onboarding7AfternoonPreferredMinute = 16 * 60;
const int _onboarding7BathAfterWakeThresholdMinutes = 90;
const int _onboarding7AnchorSearchMinutes = 120;

const List<int> onboarding7EveryDay = [1, 2, 3, 4, 5, 6, 7];
const String _noRoutineMessage =
    'AI returned no usable routine. Try clearer product names or 2 times/day.';
const String _productMismatchMessage =
    'AI used products outside your list. Try again.';
const String onboarding7FewerRoutinesMessage =
    'AI returned fewer routines than requested. Try again or choose fewer times per day.';
const String onboarding7NoCompleteScheduleMessage =
    'No complete skin-care schedule fits the available timetable. Add one 15-minute free period or choose fewer times per day.';
const List<String> _schedulableSlotLabels = [
  'morning',
  'midday',
  'afternoon',
  'night',
];

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
  if (_isStrongActiveNightSplitVariant(plan)) {
    return false;
  }
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

bool _isStrongActiveNightSplitVariant(SkinCareRoutinePlan plan) {
  final repeatDays = _safeRepeatDays(plan.repeatDays);
  if (_canonicalSlotLabel(plan.slotLabel) != 'night') return false;
  if (repeatDays.length != 2 ||
      !repeatDays.contains(3) ||
      !repeatDays.contains(6)) {
    return false;
  }
  final fields = [
    plan.title,
    ...plan.steps,
    ...plan.productNames,
    ...plan.warnings,
  ];
  if (!fields.any(_looksLikeStrongActive)) return false;
  return plan.productNames.any((product) => !_looksLikeStrongActive(product)) ||
      plan.steps.any((step) => !_looksLikeStrongActive(step));
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
      final safeProductNames = <String>[];
      final safeSteps = <String>[];
      final unsafeProductNames = <String>[];
      final unsafeSteps = <String>[];

      for (final p in plan.productNames) {
        if (_looksLikeStrongActive(p)) {
          unsafeProductNames.add(p);
        } else {
          safeProductNames.add(p);
        }
      }
      for (final s in plan.steps) {
        if (_looksLikeStrongActive(s)) {
          unsafeSteps.add(s);
        } else {
          safeSteps.add(s);
        }
      }

      if (safeProductNames.isNotEmpty || safeSteps.isNotEmpty) {
        dailyPlans.add(
          SkinCareRoutinePlan(
            slotLabel: plan.slotLabel,
            title: plan.title,
            steps: safeSteps,
            productNames: safeProductNames,
            missingItems: plan.missingItems,
            warnings: plan.warnings,
            repeatDays: plan.repeatDays,
          ),
        );
      }

      if (unsafeProductNames.isNotEmpty || unsafeSteps.isNotEmpty) {
        specialCarePlans.add(
          SkinCareRoutinePlan(
            slotLabel: plan.slotLabel,
            title: plan.title,
            steps: unsafeSteps,
            productNames: unsafeProductNames,
            missingItems: const [],
            warnings: plan.warnings,
            repeatDays: plan.repeatDays,
          ),
        );
      } else if (safeProductNames.isEmpty && safeSteps.isEmpty) {
        specialCarePlans.add(plan);
      } else if (plan.warnings.any(_looksLikeStrongActive) ||
          _looksLikeStrongActive(plan.title)) {
        specialCarePlans.add(
          SkinCareRoutinePlan(
            slotLabel: plan.slotLabel,
            title: plan.title,
            steps: const [],
            productNames: const [],
            missingItems: const [],
            warnings: plan.warnings,
            repeatDays: plan.repeatDays,
          ),
        );
      }
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

class _SkinCareSearchWindow {
  final int minStartMinute;
  final int maxStartMinute;
  final int preferredStartMinute;
  final bool searchAfterOnly;
  final bool enforceAfterMidday;
  final String displayTitle;

  const _SkinCareSearchWindow({
    required this.minStartMinute,
    required this.maxStartMinute,
    required this.preferredStartMinute,
    required this.displayTitle,
    this.searchAfterOnly = false,
    this.enforceAfterMidday = false,
  });
}

class _OwnedProductPlanResult {
  final SkinCareRoutinePlan? plan;
  final String reason;

  const _OwnedProductPlanResult.accepted(this.plan) : reason = '';
  const _OwnedProductPlanResult.rejected(this.reason) : plan = null;
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
  bool get isSerum =>
      category == 'serum' || searchableFields.any(_looksLikeSerum);
  bool get isStrongActive => searchableFields.any(_looksLikeStrongActive);
}

class _OwnedProductCatalog {
  final List<_OwnedProduct> products;

  const _OwnedProductCatalog(this.products);

  bool get isEmpty => products.isEmpty;
  bool get hasSunscreen => products.any((product) => product.isSunscreen);
  bool get hasCleanser => products.any((product) => product.isCleanser);
  bool get hasMoisturizer => products.any((product) => product.isMoisturizer);

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
    final tokenMatch = _matchBySignificantTokens(query);
    if (tokenMatch != null) return tokenMatch;
    for (final product in products) {
      if (product.searchableFields
          .map(_normalizedProductKey)
          .where((field) => field.isNotEmpty)
          .any((field) => field == query || field.contains(query))) {
        return product;
      }
    }

    final significant = _significantProductTokens(query);
    if (significant.isNotEmpty) {
      return null;
    }

    final lower = value.toLowerCase();
    return _matchByCategory(lower);
  }

  _OwnedProduct? _matchBySignificantTokens(String normalizedQuery) {
    final queryTokens = _significantProductTokens(normalizedQuery);
    if (queryTokens.isEmpty) return null;
    final matches = products
        .where((product) {
          final productTokens = _significantProductTokens(product.name);
          if (productTokens.isEmpty) return false;
          return queryTokens.every(productTokens.contains) ||
              productTokens.every(queryTokens.contains);
        })
        .toList(growable: false);
    if (matches.length == 1) return matches.single;
    return null;
  }

  _OwnedProduct? _matchByCategory(String value) {
    final lower = value.toLowerCase();
    if (_looksLikeSunscreen(lower)) {
      return _singleProduct((product) => product.isSunscreen);
    }
    if (_looksLikeCleanser(lower)) {
      return _singleProduct((product) => product.isCleanser);
    }
    if (_looksLikeMoisturizer(lower)) {
      return _singleProduct((product) => product.isMoisturizer);
    }
    if (_looksLikeSerum(lower)) {
      return _singleProduct((product) => product.isSerum);
    }
    return null;
  }

  _OwnedProduct? _singleProduct(bool Function(_OwnedProduct) test) {
    final matches = products.where(test).toList(growable: false);
    return matches.length == 1 ? matches.single : null;
  }
}

class Onboarding7AllowedProductsCatalog {
  final _OwnedProductCatalog _catalog;

  const Onboarding7AllowedProductsCatalog._(this._catalog);

  bool get isEmpty => _catalog.isEmpty;
  bool get hasSunscreen => _catalog.hasSunscreen;
  bool get hasCleanser => _catalog.hasCleanser;
  bool get hasMoisturizer => _catalog.hasMoisturizer;

  bool containsProduct(String productName) {
    final clean = productName.trim();
    if (clean.isEmpty) return false;
    return _catalog.match(clean) != null;
  }
}

Onboarding7AllowedProductsCatalog onboarding7AllowedProductsCatalog(
  BaseTimelineDraft base,
) {
  if (base.skinCareSetupPath == 'has_products') {
    if (base.skinCareReviewedProducts.isNotEmpty) {
      return Onboarding7AllowedProductsCatalog._(
        _ownedProductCatalogFromBasis(
          productNames: const [],
          productDetails: base.skinCareReviewedProducts,
        ),
      );
    }
    final names = <String>[];
    if (base.skinCareProductNames != null &&
        base.skinCareProductNames!.trim().isNotEmpty) {
      names.addAll(
        base.skinCareProductNames!
            .split(RegExp(r'[\n,]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      );
    }
    return Onboarding7AllowedProductsCatalog._(
      _ownedProductCatalogFromBasis(
        productNames: names,
        productDetails: const [],
      ),
    );
  } else if (base.skinCareSetupPath == 'no_products') {
    final selectedKeys = base.skinCareSelectedProductNames
        .map(normalizeSkinCareSelectionKey)
        .toSet();
    final selectedRecommendations = base.skinCareProductRecommendations
        .where((rec) => selectedKeys.contains(rec.selectionKey))
        .toList();
    final detected = [
      for (final rec in selectedRecommendations)
        SkinCareDetectedProduct(
          name: rec.displayName,
          brand: rec.brand,
          category: rec.canonicalCategory,
        ),
    ];
    return Onboarding7AllowedProductsCatalog._(
      _ownedProductCatalogFromBasis(
        productNames: base.skinCareSuggestedProducts,
        productDetails: detected,
      ),
    );
  }
  return const Onboarding7AllowedProductsCatalog._(_OwnedProductCatalog([]));
}

String? onboarding7ValidateEditedSkinCareBlock(
  BaseTimelineDraft base,
  TimelineBlockDraft candidate,
) {
  final products = candidate.skincareProducts
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  final steps = candidate.skincareSteps
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  if (products.isEmpty && steps.isEmpty) {
    return 'Add at least one product or routine step.';
  }

  if (products.isNotEmpty) {
    final catalog = onboarding7AllowedProductsCatalog(base);
    for (final product in products) {
      if (!catalog.containsProduct(product)) {
        return 'Use only products from your current Skin Care setup ("$product").';
      }
    }
  }

  return null;
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
  List<String> ownedProductNames = const [],
  List<SkinCareDetectedProduct> ownedProductDetails = const [],
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
    ownedProductNames: ownedProductNames,
    ownedProductDetails: ownedProductDetails,
    forceEveryDay: forceEveryDay,
  );
  if (adaptedPlans.hasError) {
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
  Onboarding7SkinCareScheduleResult? lastFailure;
  for (final flexiblePlacement in const [false, true]) {
    final result = _attemptSkinCareSchedule(
      baseTimeline: baseTimeline,
      plans: adaptedPlans.plans,
      bathBlock: bathBlock,
      occupied: occupied,
      wakingRange: wakingRange,
      slotSpecs: slotSpecs,
      timestamp: timestamp,
      desiredApplicationsPerDay: desired,
      minimumGapMinutes: onboarding7SkinCareMinimumGapMinutes,
      flexiblePlacement: flexiblePlacement,
    );
    if (!result.hasError) {
      if (kDebugMode) {
        debugPrint(
          '[Onboarding7Scheduler] accepted gap='
          '$onboarding7SkinCareMinimumGapMinutes '
          'flexible=$flexiblePlacement blocks=${result.blocks.length}',
        );
      }
      return result;
    }
    lastFailure = result;
  }
  if (lastFailure != null) {
    return const Onboarding7SkinCareScheduleResult(
      blocks: [],
      errorMessage: onboarding7NoCompleteScheduleMessage,
    );
  }
  return const Onboarding7SkinCareScheduleResult(
    blocks: [],
    errorMessage: 'No available skin-care time was found.',
  );
}

Onboarding7SkinCareScheduleResult _attemptSkinCareSchedule({
  required BaseTimelineDraft baseTimeline,
  required List<SkinCareRoutinePlan> plans,
  required TimelineBlockDraft bathBlock,
  required List<TimelineBlockDraft> occupied,
  required Onboarding7WakingRange wakingRange,
  required List<Onboarding7SkinCareSlotSpec> slotSpecs,
  required int timestamp,
  required int desiredApplicationsPerDay,
  required int minimumGapMinutes,
  required bool flexiblePlacement,
}) {
  final scheduledSingles = <TimelineBlockDraft>[];

  for (var index = 0; index < plans.length; index += 1) {
    final plan = plans[index];
    final fallbackSpec = _fallbackSlotSpecForPlan(
      plan,
      slotSpecs: slotSpecs,
      index: index,
    );
    final spec = _skinCareSlotSpecForLabel(
      plan.slotLabel,
      fallbackSpec: fallbackSpec,
      bathBlock: bathBlock,
      wakingRange: wakingRange,
    );
    final repeatDays = _safeRepeatDays(plan.repeatDays);

    for (final day in repeatDays) {
      final bathWindow = _windowForDay(bathBlock, day);
      if (bathWindow == null) {
        return const Onboarding7SkinCareScheduleResult(
          blocks: [],
          errorMessage: 'Set bath time first.',
        );
      }

      final searchWindow = _skinCareSearchWindowForDay(
        baseTimeline: baseTimeline,
        slotLabel: spec.slotLabel,
        day: day,
        bathWindow: bathWindow,
        wakingRange: wakingRange,
        desiredApplicationsPerDay: desiredApplicationsPerDay,
        flexiblePlacement: flexiblePlacement,
      );
      if (searchWindow == null) {
        return Onboarding7SkinCareScheduleResult(
          blocks: const [],
          errorMessage: _skinCareScheduleError(spec.slotLabel, day),
        );
      }

      var orderedMinStartMinute = searchWindow.minStartMinute;
      final canonicalSlot = _canonicalSlotLabel(spec.slotLabel);
      if (canonicalSlot == 'afternoon' && searchWindow.enforceAfterMidday) {
        final middayBlocks = scheduledSingles.where(
          (block) =>
              block.repeatDays.contains(day) &&
              _canonicalSlotLabel(block.skincareSlotLabel ?? '') == 'midday',
        );
        if (middayBlocks.isNotEmpty) {
          final middayEnd = middayBlocks
              .map((block) => block.endMinute)
              .reduce(math.max);
          orderedMinStartMinute = math.max(
            orderedMinStartMinute,
            middayEnd + minimumGapMinutes,
          );
        }
      } else if (canonicalSlot == 'night') {
        final earlierBlocks = scheduledSingles.where(
          (block) => block.repeatDays.contains(day),
        );
        if (earlierBlocks.isNotEmpty) {
          final latestEnd = earlierBlocks
              .map((block) => block.endMinute)
              .reduce(math.max);
          orderedMinStartMinute = math.max(
            orderedMinStartMinute,
            latestEnd + minimumGapMinutes,
          );
        }
      }
      if (searchWindow.maxStartMinute < orderedMinStartMinute) {
        return Onboarding7SkinCareScheduleResult(
          blocks: const [],
          errorMessage: _skinCareScheduleError(spec.slotLabel, day),
        );
      }

      final startMinute = onboarding7FindFreeSkinCareStart(
        preferredStartMinute: searchWindow.preferredStartMinute
            .clamp(orderedMinStartMinute, searchWindow.maxStartMinute)
            .toInt(),
        repeatDays: [day],
        occupiedBlocks: [...occupied, ...scheduledSingles],
        minStartMinute: orderedMinStartMinute,
        maxStartMinute: searchWindow.maxStartMinute,
        searchAfterOnly: searchWindow.searchAfterOnly,
        minimumSkinCareGapMinutes: minimumGapMinutes,
      );

      if (startMinute == null) {
        return Onboarding7SkinCareScheduleResult(
          blocks: const [],
          errorMessage: _skinCareScheduleError(spec.slotLabel, day),
        );
      }

      final products = _dedupeStrings(plan.productNames);
      final steps = _dedupeStrings(plan.steps);
      final missingItems = _missingItemLabelsForPlan(plan);
      if (products.isEmpty) {
        return const Onboarding7SkinCareScheduleResult(
          blocks: [],
          errorMessage: _noRoutineMessage,
        );
      }
      scheduledSingles.add(
        TimelineBlockDraft(
          id: 'skin-care-$timestamp-$index-$day',
          section: 'skin_care',
          title: _scheduledSkinCareTitle(
            plan: plan,
            spec: spec,
            displayTitle: searchWindow.displayTitle,
          ),
          startMinute: startMinute,
          endMinute: startMinute + onboarding7SkinCareDurationMinutes,
          repeatDays: [day],
          blockType: TimelineBlockDraft.softBlockKey,
          source: 'ai_skin_care_setup',
          skincareProducts: products,
          skincareSteps: steps,
          skincareMissingItems: missingItems,
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

Map<int, int> onboarding7RoutinePlanCountsByDay(
  List<SkinCareRoutinePlan> plans,
) {
  final counts = {for (final day in onboarding7EveryDay) day: 0};
  for (final plan in plans) {
    for (final day in _safeRepeatDays(plan.repeatDays)) {
      counts[day] = (counts[day] ?? 0) + 1;
    }
  }
  return counts;
}

@visibleForTesting
bool onboarding7RoutinePlansSupportPerDayCount(
  List<SkinCareRoutinePlan> plans,
  int desiredApplicationsPerDay,
) {
  if (plans.isEmpty) return false;
  final desired = onboarding7NormalizeDesiredApplications(
    desiredApplicationsPerDay,
  );
  final counts = onboarding7RoutinePlanCountsByDay(plans);
  return onboarding7EveryDay.every((day) => counts[day] == desired);
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

bool onboarding7CanContinue(BaseTimelineDraft base, String uid) {
  return base.validateSkinCareSetup(uid) == null;
}

@visibleForTesting
List<TimelineBlockDraft> onboarding7OccupiedBlocksForSkinCare(
  BaseTimelineDraft baseTimeline, {
  String? excludingBlockId,
}) {
  return baseTimeline.blocks
      .where((block) => block.id != excludingBlockId)
      .where((block) => block.section != 'skin_care')
      .where((block) => !_isNonExclusiveMealWindow(block))
      .where((block) => !block.needsTimeConfirmation)
      .where((block) => block.title.trim().isNotEmpty)
      .toList(growable: false);
}

bool _isNonExclusiveMealWindow(TimelineBlockDraft block) {
  return block.section == 'eating' &&
      (block.blockType == TimelineBlockDraft.softBlockKey ||
          block.id.startsWith('eating-ai-'));
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

_SkinCareSearchWindow? _skinCareSearchWindowForDay({
  required BaseTimelineDraft baseTimeline,
  required String slotLabel,
  required int day,
  required _ScheduleWindow bathWindow,
  required Onboarding7WakingRange wakingRange,
  required int desiredApplicationsPerDay,
  required bool flexiblePlacement,
}) {
  final latestWakingStart = math.min(
    wakingRange.endMinute - onboarding7SkinCareDurationMinutes,
    24 * 60 - onboarding7SkinCareDurationMinutes,
  );
  if (latestWakingStart < wakingRange.startMinute) return null;

  final lunchWindow = _lunchWindowForDay(
    baseTimeline,
    day,
    wakingRange: wakingRange,
  );
  final restWindow = _restWindowAfterLunchForDay(
    baseTimeline,
    day,
    lunchWindow: lunchWindow,
    wakingRange: wakingRange,
  );
  final canonicalSlot = _canonicalSlotLabel(slotLabel);
  final bathFollowsWake = _bathFollowsWake(
    bathWindow: bathWindow,
    wakingRange: wakingRange,
  );
  final wakeAnchor = bathFollowsWake
      ? math.max(wakingRange.startMinute, bathWindow.endMinute)
      : wakingRange.startMinute;
  final morningMaxStart = math.min(
    latestWakingStart,
    flexiblePlacement
        ? lunchWindow.startMinute - onboarding7SkinCareDurationMinutes
        : math.min(
            lunchWindow.startMinute - onboarding7SkinCareDurationMinutes,
            wakeAnchor + _onboarding7AnchorSearchMinutes,
          ),
  );
  final nightAnchor = latestWakingStart;
  final nightMinStart = math.max(
    wakingRange.startMinute,
    nightAnchor - _onboarding7AnchorSearchMinutes,
  );
  final hasSeparateBathRoutine =
      desiredApplicationsPerDay >= 4 && !bathFollowsWake;
  final separateBathAnchor = math.max(
    wakingRange.startMinute,
    bathWindow.endMinute,
  );
  final separateBathMaxStart = math.min(
    latestWakingStart,
    separateBathAnchor + _onboarding7AnchorSearchMinutes,
  );
  final afterLunchMaxStart = restWindow == null
      ? latestWakingStart
      : math.min(
          latestWakingStart,
          restWindow.startMinute - onboarding7SkinCareDurationMinutes,
        );

  final window = switch (canonicalSlot) {
    'morning' => _SkinCareSearchWindow(
      minStartMinute: wakeAnchor,
      maxStartMinute: morningMaxStart,
      preferredStartMinute: wakeAnchor,
      searchAfterOnly: true,
      displayTitle: bathFollowsWake
          ? 'After-bath Skin Care'
          : 'After-wake Skin Care',
    ),
    'midday' => _SkinCareSearchWindow(
      minStartMinute: math.max(wakingRange.startMinute, lunchWindow.endMinute),
      maxStartMinute: afterLunchMaxStart,
      preferredStartMinute: math.max(
        wakingRange.startMinute,
        lunchWindow.endMinute,
      ),
      searchAfterOnly: true,
      displayTitle: 'After-lunch Skin Care',
    ),
    'afternoon' =>
      hasSeparateBathRoutine
          ? _SkinCareSearchWindow(
              minStartMinute: separateBathAnchor,
              maxStartMinute: separateBathMaxStart,
              preferredStartMinute: separateBathAnchor,
              searchAfterOnly: true,
              displayTitle: 'After-bath Skin Care',
            )
          : _SkinCareSearchWindow(
              minStartMinute: math.max(
                wakingRange.startMinute,
                lunchWindow.endMinute,
              ),
              maxStartMinute: latestWakingStart,
              preferredStartMinute: _onboarding7AfternoonPreferredMinute,
              enforceAfterMidday: true,
              displayTitle: 'Afternoon Skin Care',
            ),
    'night' => _SkinCareSearchWindow(
      minStartMinute: nightMinStart,
      maxStartMinute: latestWakingStart,
      preferredStartMinute: nightAnchor,
      displayTitle: 'Before-bed Skin Care',
    ),
    _ => null,
  };

  if (window == null || window.maxStartMinute < window.minStartMinute) {
    return null;
  }
  return window;
}

_ScheduleWindow? _restWindowAfterLunchForDay(
  BaseTimelineDraft baseTimeline,
  int day, {
  required _ScheduleWindow lunchWindow,
  required Onboarding7WakingRange wakingRange,
}) {
  final windows =
      baseTimeline.blocks
          .where((block) => !block.needsTimeConfirmation)
          .where((block) {
            final title = block.title.trim().toLowerCase();
            return RegExp(r'\b(rest|nap)\b').hasMatch(title);
          })
          .expand(_windowsFor)
          .where((window) => window.day == day)
          .where((window) => window.startMinute >= lunchWindow.endMinute)
          .where((window) => window.startMinute < wakingRange.endMinute)
          .toList(growable: false)
        ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
  return windows.isEmpty ? null : windows.first;
}

bool _bathFollowsWake({
  required _ScheduleWindow bathWindow,
  required Onboarding7WakingRange wakingRange,
}) {
  final latestFollowingBathStart =
      wakingRange.startMinute + _onboarding7BathAfterWakeThresholdMinutes;
  return bathWindow.endMinute >= wakingRange.startMinute &&
      bathWindow.startMinute <= latestFollowingBathStart;
}

_ScheduleWindow _lunchWindowForDay(
  BaseTimelineDraft baseTimeline,
  int day, {
  required Onboarding7WakingRange wakingRange,
}) {
  final lunchWindows =
      baseTimeline.blocks
          .where((block) => !block.needsTimeConfirmation)
          .where(_isLunchBlock)
          .expand(_windowsFor)
          .where((window) => window.day == day)
          .where((window) => window.endMinute > window.startMinute)
          .toList(growable: false)
        ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
  if (lunchWindows.isNotEmpty) return lunchWindows.first;

  final latestFallbackStart = math.max(
    wakingRange.startMinute,
    wakingRange.endMinute - _onboarding7FallbackLunchDurationMinutes,
  );
  final startMinute =
      (baseTimeline.lunchMinute ?? _onboarding7DefaultLunchStartMinute)
          .clamp(wakingRange.startMinute, latestFallbackStart)
          .toInt();
  return _ScheduleWindow(
    day: day,
    startMinute: startMinute,
    endMinute: math.min(
      wakingRange.endMinute,
      startMinute + _onboarding7FallbackLunchDurationMinutes,
    ),
  );
}

bool _isLunchBlock(TimelineBlockDraft block) {
  if (block.section != 'eating') return false;
  final category = block.mealCategory?.trim().toLowerCase() ?? '';
  final title = block.title.trim().toLowerCase();
  return category == 'lunch' || RegExp(r'\blunch\b').hasMatch(title);
}

String _skinCareScheduleError(String slotLabel, int day) {
  final dayName = _dayName(day);
  return switch (_canonicalSlotLabel(slotLabel)) {
    'morning' =>
      'No free skin-care time was found after wake-up and bath on $dayName. Adjust the bath or daytime schedule.',
    'midday' =>
      'No free skin-care time was found after lunch on $dayName. Adjust lunch or the daytime schedule.',
    'afternoon' =>
      'No free afternoon skin-care time was found on $dayName. Adjust the daytime schedule.',
    'night' =>
      'No free night skin-care time was found before sleep on $dayName. Adjust the night or sleep schedule.',
    _ => 'No free 15-minute skin-care time was found for $dayName.',
  };
}

String _scheduledSkinCareTitle({
  required SkinCareRoutinePlan plan,
  required Onboarding7SkinCareSlotSpec spec,
  required String displayTitle,
}) {
  if (displayTitle.trim().isNotEmpty) return displayTitle;
  final title = plan.title.trim();
  return title.isNotEmpty ? title : spec.title;
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
  final firstStart = _firstRoutineAnchor(
    bathBlock: bathBlock,
    wakingRange: wakingRange,
  );
  final nightStart = wakingRange.endMinute - onboarding7SkinCareDurationMinutes;
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
        preferredStartMinute:
            _onboarding7DefaultLunchStartMinute +
            _onboarding7FallbackLunchDurationMinutes,
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
        preferredStartMinute:
            _onboarding7DefaultLunchStartMinute +
            _onboarding7FallbackLunchDurationMinutes,
      ),
      const Onboarding7SkinCareSlotSpec(
        slotLabel: 'afternoon',
        title: 'Afternoon Skin Care',
        preferredStartMinute: _onboarding7AfternoonPreferredMinute,
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
    forceEveryDay: true,
  ).plans;
}

@visibleForTesting
Onboarding7RoutinePlanAdaptationResult onboarding7AdaptRoutinePlansForSchedule({
  required List<SkinCareRoutinePlan> routinePlans,
  required int desiredApplicationsPerDay,
  List<String> ownedProductNames = const [],
  List<SkinCareDetectedProduct> ownedProductDetails = const [],
  bool forceEveryDay = true,
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
  final selectedBySlot = <String, List<SkinCareRoutinePlan>>{};
  final ownedProducts = _ownedProductCatalogFromBasis(
    productNames: ownedProductNames,
    productDetails: ownedProductDetails,
  );
  var sawProductMismatch = false;
  var sawUnsafePlan = false;

  void recordRejection(SkinCareRoutinePlan plan, String reason) {
    if (reason == 'product_mismatch') sawProductMismatch = true;
    if (reason == 'unsafe') sawUnsafePlan = true;
    if (kDebugMode) {
      debugPrint(
        '[Onboarding7Scheduler] rejected plan reason=$reason '
        'slot=${plan.slotLabel} productCount=${plan.productNames.length}',
      );
    }
  }

  if (sourcePlans.isEmpty || ownedProducts.isEmpty) {
    return Onboarding7RoutinePlanAdaptationResult(
      plans: const [],
      errorMessage: _noRoutineMessage,
    );
  }

  for (var index = 0; index < targetSlots.length; index += 1) {
    final slot = targetSlots[index];
    final spec = slotSpecs[index];
    final candidates = <SkinCareRoutinePlan>[];
    for (final rawPlan in sourcePlans) {
      if (!_slotCompatible(rawPlan.slotLabel, slot, targetSlots: targetSlots)) {
        continue;
      }
      final result = _ownedProductPlanForSlot(
        plan: rawPlan,
        slot: slot,
        title: spec.title,
        ownedProducts: ownedProducts,
      );
      final selectedPlan = result.plan;
      if (selectedPlan != null) {
        candidates.add(selectedPlan);
      } else {
        recordRejection(rawPlan, result.reason);
      }
    }
    final selectedForSlot = _selectRoutinePlansForSlot(
      candidates,
      forceEveryDay: forceEveryDay,
    );
    if (selectedForSlot.isNotEmpty) {
      selectedBySlot[slot] = selectedForSlot;
    }
  }

  final selected = _orderedSelectedPlansBySlot(
    selectedBySlot,
  ).toList(growable: false);
  if (selected.isEmpty) {
    return Onboarding7RoutinePlanAdaptationResult(
      plans: const [],
      errorMessage: sawProductMismatch
          ? _productMismatchMessage
          : sawUnsafePlan
          ? onboarding7FewerRoutinesMessage
          : _noRoutineMessage,
    );
  }
  final supportsDesiredPerDayCount = onboarding7RoutinePlansSupportPerDayCount(
    selected,
    desired,
  );
  if (!supportsDesiredPerDayCount) {
    if (kDebugMode) {
      debugPrint(
        '[Onboarding7Scheduler] per-day routine counts='
        '${onboarding7RoutinePlanCountsByDay(selected)} desired=$desired',
      );
    }
    return Onboarding7RoutinePlanAdaptationResult(
      plans: selected,
      errorMessage: sawProductMismatch
          ? _productMismatchMessage
          : onboarding7FewerRoutinesMessage,
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
  int minimumSkinCareGapMinutes = 0,
}) {
  final minStart = _roundUpToFive(minStartMinute.clamp(0, 24 * 60 - 1));
  final maxStart = _roundDownToFive(
    maxStartMinute.clamp(0, 24 * 60 - onboarding7SkinCareDurationMinutes),
  );
  if (maxStart < minStart) return null;

  final preferred = _roundToFive(
    preferredStartMinute.clamp(minStart, maxStart),
  );
  if (_isSkinCareStartFree(
    preferred,
    repeatDays,
    occupiedBlocks,
    minimumSkinCareGapMinutes: minimumSkinCareGapMinutes,
  )) {
    return preferred;
  }

  if (searchAfterOnly) {
    for (
      var start = _roundUpToFive(preferred + 5);
      start <= maxStart;
      start += 5
    ) {
      if (_isSkinCareStartFree(
        start,
        repeatDays,
        occupiedBlocks,
        minimumSkinCareGapMinutes: minimumSkinCareGapMinutes,
      )) {
        return start;
      }
    }
    return null;
  }

  final maxOffset = math.max(preferred - minStart, maxStart - preferred);
  for (var offset = 5; offset <= maxOffset; offset += 5) {
    final after = preferred + offset;
    if (after <= maxStart &&
        _isSkinCareStartFree(
          after,
          repeatDays,
          occupiedBlocks,
          minimumSkinCareGapMinutes: minimumSkinCareGapMinutes,
        )) {
      return after;
    }
    final before = preferred - offset;
    if (before >= minStart &&
        _isSkinCareStartFree(
          before,
          repeatDays,
          occupiedBlocks,
          minimumSkinCareGapMinutes: minimumSkinCareGapMinutes,
        )) {
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
      .where((block) => !_isNonExclusiveMealWindow(block))
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
        .where((item) => !_isNonExclusiveMealWindow(item))
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
      block.skincareMissingItems.join('\u001f'),
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
  if (sleepBlock.startMinute <= 3 * 60 &&
      sleepBlock.endMinute > sleepBlock.startMinute &&
      sleepBlock.endMinute <= 12 * 60) {
    final start = sleepBlock.endMinute.clamp(5 * 60, 11 * 60).toInt();
    return Onboarding7WakingRange(startMinute: start, endMinute: 24 * 60);
  }
  return const Onboarding7WakingRange(startMinute: 6 * 60, endMinute: 23 * 60);
}

int _firstRoutineAnchor({
  required TimelineBlockDraft? bathBlock,
  required Onboarding7WakingRange wakingRange,
}) {
  if (bathBlock == null) return wakingRange.startMinute;
  final bathFollowsWake =
      bathBlock.endMinute >= wakingRange.startMinute &&
      bathBlock.startMinute <=
          wakingRange.startMinute + _onboarding7BathAfterWakeThresholdMinutes;
  return bathFollowsWake
      ? math.max(wakingRange.startMinute, bathBlock.endMinute)
      : wakingRange.startMinute;
}

Onboarding7SkinCareSlotSpec _skinCareSlotSpecForLabel(
  String rawSlot, {
  required Onboarding7SkinCareSlotSpec fallbackSpec,
  required TimelineBlockDraft? bathBlock,
  required Onboarding7WakingRange wakingRange,
}) {
  final slot = _canonicalSlotLabel(rawSlot);
  final firstStart = _firstRoutineAnchor(
    bathBlock: bathBlock,
    wakingRange: wakingRange,
  );
  final nightStart = wakingRange.endMinute - onboarding7SkinCareDurationMinutes;
  return switch (slot) {
    'morning' => Onboarding7SkinCareSlotSpec(
      slotLabel: 'morning',
      title: 'Morning Skin Care',
      preferredStartMinute: firstStart,
    ),
    'midday' => const Onboarding7SkinCareSlotSpec(
      slotLabel: 'midday',
      title: 'Midday Skin Care',
      preferredStartMinute:
          _onboarding7DefaultLunchStartMinute +
          _onboarding7FallbackLunchDurationMinutes,
    ),
    'afternoon' => const Onboarding7SkinCareSlotSpec(
      slotLabel: 'afternoon',
      title: 'Afternoon Skin Care',
      preferredStartMinute: _onboarding7AfternoonPreferredMinute,
    ),
    'night' => Onboarding7SkinCareSlotSpec(
      slotLabel: 'night',
      title: 'Night Skin Care',
      preferredStartMinute: nightStart,
    ),
    _ => fallbackSpec,
  };
}

Onboarding7SkinCareSlotSpec _fallbackSlotSpecForPlan(
  SkinCareRoutinePlan plan, {
  required List<Onboarding7SkinCareSlotSpec> slotSpecs,
  required int index,
}) {
  final slot = _canonicalSlotLabel(plan.slotLabel);
  for (final spec in slotSpecs) {
    if (spec.slotLabel == slot) return spec;
  }
  return slotSpecs[index.clamp(0, slotSpecs.length - 1).toInt()];
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

List<SkinCareRoutinePlan> _orderedSelectedPlansBySlot(
  Map<String, List<SkinCareRoutinePlan>> selectedBySlot,
) {
  final ordered = <SkinCareRoutinePlan>[];
  for (final slot in _schedulableSlotLabels) {
    final plans = selectedBySlot[slot];
    if (plans != null) ordered.addAll(plans);
  }
  for (final entry in selectedBySlot.entries) {
    if (!_schedulableSlotLabels.contains(entry.key)) {
      ordered.addAll(entry.value);
    }
  }
  return ordered;
}

List<SkinCareRoutinePlan> _selectRoutinePlansForSlot(
  List<SkinCareRoutinePlan> candidates, {
  required bool forceEveryDay,
}) {
  if (candidates.isEmpty) return const [];
  final hasActiveNightSplit = candidates.any(_isStrongActiveNightSplitVariant);
  if (candidates.length > 1) {
    final counts = onboarding7RoutinePlanCountsByDay(candidates);
    final exactlyOnePerDay = onboarding7EveryDay.every(
      (day) => counts[day] == 1,
    );
    if (exactlyOnePerDay) return candidates;
    if (hasActiveNightSplit) return candidates;
  }

  final dailyIndex = candidates.indexWhere(
    (plan) => _safeRepeatDays(plan.repeatDays).length == 7,
  );
  final selected = dailyIndex >= 0 ? candidates[dailyIndex] : candidates.first;
  if (!forceEveryDay || _isStrongActiveNightSplitVariant(selected)) {
    return [selected];
  }
  return [_planWithRepeatDays(selected, onboarding7EveryDay)];
}

SkinCareRoutinePlan _planWithRepeatDays(
  SkinCareRoutinePlan plan,
  List<int> repeatDays,
) {
  return SkinCareRoutinePlan(
    slotLabel: plan.slotLabel,
    title: plan.title,
    steps: plan.steps,
    productNames: plan.productNames,
    missingItems: plan.missingItems,
    warnings: plan.warnings,
    repeatDays: repeatDays,
  );
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
    missingItems: plan.missingItems,
    warnings: plan.warnings,
    repeatDays: plan.repeatDays,
  );
}

_OwnedProductPlanResult _ownedProductPlanForSlot({
  required SkinCareRoutinePlan plan,
  required String slot,
  required String title,
  required _OwnedProductCatalog ownedProducts,
}) {
  final normalized = _planForSlot(plan, slot, title);
  if (normalized.productNames.isEmpty &&
      !_hasMeaningfulRoutineStep(normalized.steps)) {
    return const _OwnedProductPlanResult.rejected('empty');
  }
  final matchedProducts = _matchedOwnedProductsForPlan(
    normalized,
    ownedProducts,
  );
  if (matchedProducts == null) {
    return const _OwnedProductPlanResult.rejected('product_mismatch');
  }
  if (matchedProducts.isEmpty) {
    return const _OwnedProductPlanResult.rejected('empty');
  }
  if (_planUsesOnlyNightSunscreen(normalized, matchedProducts)) {
    return const _OwnedProductPlanResult.rejected('unsafe');
  }
  final safeProducts = _safeOwnedProductsForPlan(normalized, matchedProducts);
  if (safeProducts.isEmpty) {
    return const _OwnedProductPlanResult.rejected('unsafe');
  }

  return _OwnedProductPlanResult.accepted(
    SkinCareRoutinePlan(
      slotLabel: slot,
      title: normalized.title.trim().isEmpty ? title : normalized.title.trim(),
      steps: _safeStepsForPlan(normalized),
      productNames: _dedupeStrings(safeProducts.map((product) => product.name)),
      missingItems: _missingItemsNotOwned(
        normalized.missingItems,
        ownedProducts,
      ),
      warnings: normalized.warnings,
      repeatDays: normalized.repeatDays,
    ),
  );
}

List<String> _missingItemLabelsForPlan(SkinCareRoutinePlan plan) {
  return _dedupeStrings(
    plan.missingItems
        .map((item) => item.displayLabel)
        .where((label) => label.trim().isNotEmpty),
  );
}

List<SkinCareMissingItem> _missingItemsNotOwned(
  List<SkinCareMissingItem> items,
  _OwnedProductCatalog ownedProducts,
) {
  final seen = <String>{};
  final result = <SkinCareMissingItem>[];
  for (final item in items) {
    final name = item.name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) continue;
    if (ownedProducts.match(name) != null) continue;
    final key = _normalizedProductKey(name);
    if (!seen.add(key)) continue;
    result.add(
      SkinCareMissingItem(
        name: name,
        importance: item.importance,
        reason: item.reason,
      ),
    );
  }
  return result;
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
  final direct = ownedProducts.match(lower);
  if (direct != null) return direct;
  if (_looksLikeSunscreen(lower) || lower.contains('sun protection')) {
    return ownedProducts.match('sunscreen');
  }
  if (_looksLikeCleanser(lower)) {
    return ownedProducts.match('cleanser');
  }
  if (_stepMentionsMoisturizer(lower)) {
    return ownedProducts.match('moisturizer');
  }
  if (_looksLikeSerum(lower)) {
    return ownedProducts.match('serum');
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

List<_OwnedProduct> _safeOwnedProductsForPlan(
  SkinCareRoutinePlan plan,
  List<_OwnedProduct> products,
) {
  if (!_planRepeatsStrongActive(plan, products)) {
    return _dedupeOwnedProducts(products);
  }
  return _dedupeOwnedProducts(
    products.where((product) => !product.isStrongActive),
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
  final repeatsEveryDay = _safeRepeatDays(plan.repeatDays).length >= 7;
  for (final raw in plan.steps) {
    final step = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (step.isEmpty) continue;
    if (!allowStrongActive &&
        repeatsEveryDay &&
        _stepLooksLikeUnsafeSpecialCare(step)) {
      continue;
    }
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
  if (lower.contains('vitamin c') ||
      lower.contains('alpha arbutin') ||
      lower.contains('niacinamide')) {
    return 'serum';
  }
  if (lower.contains('toner')) return 'toner';
  if (_looksLikeStrongActive(lower)) return 'exfoliant';
  return '';
}

String _normalizedProductKey(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

Set<String> _significantProductTokens(String value) {
  final stopWords = {
    'the',
    'and',
    'with',
    'for',
    'skin',
    'care',
    'product',
    'daily',
    'apply',
    'use',
    'serum',
    'sunscreen',
    'spf',
    'cleanser',
    'face',
    'wash',
    'moisturizer',
    'moisturiser',
    'cream',
    'lotion',
    'toner',
    'exfoliant',
    'exfoliator',
  };
  return _normalizedProductKey(value)
      .split(' ')
      .where((token) => token.isNotEmpty)
      .where((token) => !stopWords.contains(token))
      .toSet();
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
      _containsAcidInitialism(lower, 'pha') ||
      _containsAcidInitialism(lower, 'aha') ||
      _containsAcidInitialism(lower, 'bha') ||
      lower.contains('glycolic') ||
      lower.contains('lactic') ||
      lower.contains('salicylic') ||
      lower.contains('mandelic') ||
      lower.contains('benzoyl peroxide') ||
      lower.contains('strong active');
}

bool _containsAcidInitialism(String value, String token) {
  return RegExp('(^|[^a-z0-9])$token([^a-z0-9]|\$)').hasMatch(value);
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
  List<TimelineBlockDraft> occupiedBlocks, {
  int minimumSkinCareGapMinutes = 0,
}) {
  final candidate = TimelineBlockDraft(
    id: 'candidate',
    section: 'skin_care',
    title: 'Skin Care',
    startMinute: startMinute,
    endMinute: startMinute + onboarding7SkinCareDurationMinutes,
    repeatDays: _safeRepeatDays(repeatDays),
    blockType: TimelineBlockDraft.softBlockKey,
  );
  if (_candidateConflicts(candidate, occupiedBlocks)) return false;
  if (minimumSkinCareGapMinutes <= 0) return true;

  final candidateWindows = _windowsFor(candidate);
  for (final block in occupiedBlocks.where(
    (block) => block.section == 'skin_care',
  )) {
    for (final candidateWindow in candidateWindows) {
      for (final blockWindow in _windowsFor(block)) {
        if (candidateWindow.day != blockWindow.day) continue;
        final enoughGapBefore =
            candidateWindow.endMinute + minimumSkinCareGapMinutes <=
            blockWindow.startMinute;
        final enoughGapAfter =
            candidateWindow.startMinute >=
            blockWindow.endMinute + minimumSkinCareGapMinutes;
        if (!enoughGapBefore && !enoughGapAfter) return false;
      }
    }
  }
  return true;
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
