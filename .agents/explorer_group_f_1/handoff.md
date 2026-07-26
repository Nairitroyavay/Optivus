# Handoff Report — Group F: Issues 29 & 30 (Meal Onboarding Validation)

## 1. Observation

### Summary of Investigation Target
- **Issue 29**: Meal schedule density and spacing validation. Focus on meal schedule density, maximum daily meal count, minimum spacing between meals (e.g., 120 minutes), and start/end minute validation across meal setup/onboarding screens and validators.
- **Issue 30**: Multi-dish meal timing collision resolution during onboarding. Focus on how multi-dish or concurrent meal item schedules are parsed, whether overlapping dish times cause timeline collisions, and how timing collisions should be detected and resolved cleanly without data loss.

---

### Codebase Inspection Findings & Verbatim References

#### 1. Meal Setup State & Onboarding Validation (`lib/models/onboarding_draft.dart`)
- **Location**: `lib/models/onboarding_draft.dart:1712-1721`
```dart
1712:   String? validateEatingSetup() {
1713:     if (_hasConfirmedSection('eating')) return null;
1714:     if (eatingSetupPath == null) {
1715:       return 'Choose how to set up eating.';
1716:     }
1717:     if (eatingSetupPath == 'has_routine') {
1718:       return 'Generate your weekly meal routine first.';
1719:     }
1720:     return 'Generate your meal routine first.';
1721:   }
```
- **Observation**: `validateEatingSetup()` currently only checks whether the eating section was confirmed or whether a path was selected (`has_routine` vs `create`). It contains **zero checks** for:
  1. Minimum meal spacing (e.g. 120 minutes between meal start times or between end of one meal and start of the next).
  2. Maximum daily meal count limit (e.g., max 6 meals per day).
  3. Start/end minute range sanity or chronological ordering (`breakfastMinute` < `extraSnackMinute` < `lunchMinute` < `snackMinute` < `dinnerMinute`).

#### 2. Candidate Mapping & Multi-Dish Parsing (`lib/features/onboarding/steps/onboarding_step_5_eating_setup.dart`)
- **Location**: `lib/features/onboarding/steps/onboarding_step_5_eating_setup.dart:1948-2049`
```dart
1948: Onboarding5MealCandidateMappingResult mapOnboarding5MealCandidates(
1949:   List<RoutineImportCandidateBlock> candidates, {
1950:   DateTime? now,
1951:   String source = onboardingEatingAiImportSource,
1952:   BaseTimelineDraft? baseTimeline,
1953: }) {
...
1961:   for (final candidate in candidates) {
...
2019:     blocks.add(
2020:       TimelineBlockDraft(
2021:         id: 'eating-ai-${candidate.id}-${timestamp.millisecondsSinceEpoch}',
2022:         section: 'eating',
2023:         title: title,
2024:         startMinute: startMinute,
2025:         endMinute: endMinute,
2026:         repeatDays: repeatDays.isEmpty ? onboardingEveryDay() : repeatDays,
2027:         location: candidate.location,
2028:         blockType: TimelineBlockDraft.hardBlockKey,
2029:         source: source,
2030:         mealCategory: mealCategory,
2031:         dishes: dishes,
2032:       ),
2033:     );
2034:   }
```
- **Observation**: `mapOnboarding5MealCandidates` maps each raw AI extraction candidate block to a separate `TimelineBlockDraft`. If AI extraction (or user photo parsing) returns multiple dish candidates for the same meal window (e.g., candidate 1: "Oatmeal" at 8:00 AM, candidate 2: "Eggs" at 8:15 AM, candidate 3: "Coffee" at 8:10 AM), the function creates 3 separate `TimelineBlockDraft` blocks.
- **Resulting Behavior**: When these blocks are added to `BaseTimelineDraft`, `detectConflicts()` flags them as timeline collisions because they overlap in time.

#### 3. Meal Routine Setup Screen Validation (`lib/features/routine/managers/base_timeline/screens/eating_routine_setup_screen.dart`)
- **Location**: `lib/features/routine/managers/base_timeline/screens/eating_routine_setup_screen.dart:74-84`
```dart
74:               onSave: () {
75:                 final title = titleCtrl.text.trim();
76:                 if (title.isEmpty) {
77:                   setModal(() => errorMsg = 'Meal title is required.');
78:                   return;
79:                 }
80:                 if (selectedDays.isEmpty) {
81:                   setModal(() => errorMsg = 'Select at least one day.');
82:                   return;
83:                 }
```
- **Observation**: Manual meal routine creation only checks that title is non-empty and at least one repeat day is selected. It does **not** validate spacing against other meal blocks on the same day or check whether the user has exceeded the daily meal count limit.

#### 4. Routine Validation Service (`lib/features/routine/services/routine_validation_service.dart`)
- **Location**: `lib/features/routine/services/routine_validation_service.dart:107-170`
- **Observation**: `RoutineValidationService.validate()` checks bounds `0 <= startMinute <= 1439`, `0 <= endMinute <= 1440`, overnight duration formulas, title presence, and generic hard block overlaps. It does **not** contain eating-specific density or meal spacing checks.

#### 5. Onboarding Completion Bundle Scheduling (`lib/services/onboarding_completion_service.dart`)
- **Location**: `lib/services/onboarding_completion_service.dart:212-344`
- **Observation**: In `_scheduleRoutineItems`, flexible/soft blocks that collide with existing blocks are shifted forward by 10 minutes repeatedly until they fit or fall back to `[Tiny] title` (0-5 min unscheduled fallback items). When multi-dish candidate blocks collide, this shifting mechanism fragments the meal schedule, pushing individual dishes to arbitrary times across the day or converting them into tiny fallback items, leading to schedule corruption.

---

## 2. Logic Chain

### Issue 29: Meal Schedule Density and Spacing Validation
1. **Observation**: `validateEatingSetup()`, `EatingRoutineSetupScreen._showForm`, and `RoutineValidationService` lack meal spacing and meal count density rules.
2. **Step 1**: In onboarding Step 5, users configure meal counts (`mealsPerDay`: 3, 4, or 5) and time windows (`breakfastMinute`, `lunchMinute`, `snackMinute`, `dinnerMinute`, `extraSnackMinute`). In routine setup or manual draft editing, users can create arbitrary eating blocks.
3. **Step 2**: If a user sets Breakfast at 8:00 AM (480 min, 30 min duration -> 510 min) and Lunch at 8:30 AM (510 min) or 9:00 AM (540 min), the gap between start times is < 120 minutes (only 30–60 minutes).
4. **Step 3**: Currently, `validateEatingSetup()` returns `null` (valid) because it only checks string flags (`eatingSetupPath` and confirmed section). `EatingRoutineSetupScreen` saves the meal without warning.
5. **Step 4**: Excessive meal density (e.g., 7+ meals per day or meals scheduled 15 minutes apart) degrades routine materialization, creates unmanageable daily notifications, and violates nutritional routine guidelines.
6. **Conclusion for Issue 29**: Optivus requires explicit validation for:
   - **Minimum Spacing Requirement**: A minimum spacing of **120 minutes** between the start times of consecutive meals on the same day (or minimum 60 minutes between the end of one meal and start of the next).
   - **Maximum Daily Meal Count**: A hard upper limit of **6 meals per day** per day-of-week.
   - **Ascending Meal Window Sanity**: `breakfastMinute < extraSnackMinute < lunchMinute < snackMinute < dinnerMinute` with >= 120-minute separation between start times.

### Issue 30: Multi-Dish Meal Timing Collision Resolution During Onboarding
1. **Observation**: `mapOnboarding5MealCandidates` maps raw candidates directly to `TimelineBlockDraft` blocks without candidate consolidation.
2. **Step 1**: When AI menu extraction or photo OCR parses a multi-dish meal (e.g., "Scrambled Eggs", "Toast", "Orange Juice"), it often emits candidates with identical or closely overlapping start times (e.g., 8:00 AM, 8:05 AM, 8:10 AM) tagged with the same `mealCategory` ("breakfast").
3. **Step 2**: `mapOnboarding5MealCandidates` generates 3 separate `TimelineBlockDraft` items (one per dish), each marked with `blockType: TimelineBlockDraft.hardBlockKey` or `softBlockKey`.
4. **Step 3**: `BaseTimelineDraft.detectConflicts()` evaluates these 3 blocks on the same day and flags them as `timeOverlap` / hard conflicts.
5. **Step 4**: During onboarding completion bundle materialization (`_scheduleRoutineItems`), the scheduler detects collisions and pushes dish #2 and dish #3 to later time slots (e.g., 8:40 AM, 8:50 AM) or converts them into 0-minute fallback items.
6. **Step 5**: This causes dish data fragmentation, schedule clutter, and artificial timeline conflict banners during onboarding step 5, 6, and 11.
7. **Conclusion for Issue 30**: Concurrent or multi-dish candidate items belonging to the same meal window or category must be **merged** into a single consolidated `TimelineBlockDraft` (and `RoutineItem`) with combined `dishes: ['Scrambled Eggs', 'Toast', 'Orange Juice']`, eliminating timeline collisions while preserving 100% of dish data.

---

## 3. Caveats

1. **Read-Only Scope**: This report provides structural analysis and zero-side-effect code strategies. No source code in `lib/` has been modified during this exploration.
2. **Single-Dish vs Multi-Dish Intent**: If a user explicitly creates two separate eating windows on the same day spaced >= 120 minutes apart (e.g. Breakfast at 8:00 AM and Lunch at 1:00 PM), these are distinct meals and should remain separate blocks. Merging only applies to concurrent/overlapping dish blocks within the same meal window (e.g. delta <= 45 minutes or matching `mealCategory`).
3. **Custom Meal Categories**: AI extraction or manual inputs may use custom category strings (e.g. "Post-workout Shake"). Category normalization must lower-case and strip special characters when comparing meal windows.

---

## 4. Conclusion & Recommended Zero-Side-Effect Fix Strategies

### Recommended Architecture for Issue 29: Meal Schedule Density & Spacing Validator

#### A. Add Spacing & Density Validator to `BaseTimelineDraft` (`lib/models/onboarding_draft.dart`)
Add a dedicated helper `validateMealScheduleDensity()` called by `validateEatingSetup()`:
```dart
String? validateMealScheduleDensity() {
  final eatingBlocks = blocks.where((b) => b.section == 'eating').toList();
  if (eatingBlocks.isEmpty) return null;

  for (var day = 1; day <= 7; day++) {
    final dayBlocks = eatingBlocks
        .where((b) => b.repeatDays.contains(day))
        .toList()
      ..sort((a, b) => a.startMinute.compareTo(b.startMinute));

    if (dayBlocks.length > 6) {
      return 'Maximum of 6 meals allowed per day (Day $day has ${dayBlocks.length}).';
    }

    for (var i = 0; i < dayBlocks.length - 1; i++) {
      final current = dayBlocks[i];
      final next = dayBlocks[i + 1];
      final spacing = next.startMinute - current.startMinute;
      if (spacing < 120) {
        return 'Meals "${current.title}" and "${next.title}" must be spaced at least 120 minutes apart.';
      }
    }
  }
  return null;
}
```

#### B. Enforce Spacing in `validateEatingSetup()`
Update `validateEatingSetup()`:
```dart
String? validateEatingSetup() {
  if (eatingSetupPath == null && !_hasConfirmedSection('eating')) {
    return 'Choose how to set up eating.';
  }
  final densityError = validateMealScheduleDensity();
  if (densityError != null) return densityError;

  if (_hasConfirmedSection('eating')) return null;
  if (eatingSetupPath == 'has_routine') {
    return 'Generate your weekly meal routine first.';
  }
  return 'Generate your meal routine first.';
}
```

#### C. Enforce Spacing & Density in `EatingRoutineSetupScreen` (`lib/features/routine/managers/base_timeline/screens/eating_routine_setup_screen.dart`)
In `_showForm` `onSave`:
```dart
final existingMeals = meals.where((m) => m.id != existingItem?.id).toList();
for (final day in selectedDays) {
  final dayMeals = existingMeals.where((m) => m.repeatDays.contains(day)).toList();
  if (dayMeals.length >= 6) {
    setModal(() => errorMsg = 'Maximum 6 meals allowed per day.');
    return;
  }
  for (final m in dayMeals) {
    final spacing = (startMin - m.startMinute).abs();
    if (spacing < 120) {
      setModal(() => errorMsg = 'Meals must be spaced at least 120 minutes apart (conflicts with "${m.title}").');
      return;
    }
  }
}
```

---

### Recommended Architecture for Issue 30: Multi-Dish Meal Collision Resolver

#### A. Multi-Dish Merging Engine in Candidate Mapping (`mapOnboarding5MealCandidates` in `lib/features/onboarding/steps/onboarding_step_5_eating_setup.dart`)
Prior to building `TimelineBlockDraft` list, group candidate blocks by category and close start minutes (within 45 minutes):

```dart
List<RoutineImportCandidateBlock> consolidateMultiDishCandidates(
  List<RoutineImportCandidateBlock> rawCandidates,
) {
  if (rawCandidates.length <= 1) return rawCandidates;
  
  final groups = <String, List<RoutineImportCandidateBlock>>{};
  for (final candidate in rawCandidates) {
    final category = _inferMealCategoryForCandidate(candidate);
    // Key by category + approximate start hour window (within 60 mins)
    final windowKey = '$category:${candidate.startMinute ~/ 60}';
    groups.putIfAbsent(windowKey, () => []).add(candidate);
  }

  final consolidated = <RoutineImportCandidateBlock>[];
  for (final entry in groups.entries) {
    final list = entry.value;
    if (list.length == 1) {
      consolidated.add(list.first);
      continue;
    }
    // Merge multi-dish candidate group into a single candidate
    final primary = list.first;
    final mergedDishes = <String>{};
    for (final item in list) {
      mergedDishes.addAll(_dishesForEatingCandidate(item));
    }
    
    final minStart = list.map((c) => c.startMinute).reduce(math.min);
    final maxEnd = list.map((c) => c.endMinute).reduce(math.max);

    consolidated.add(
      primary.copyWith(
        title: _mealCandidateTitle(primary, _inferMealCategoryForCandidate(primary)),
        startMinute: minStart,
        endMinute: math.max(maxEnd, minStart + 30),
        steps: mergedDishes.toList(),
      ),
    );
  }
  return consolidated;
}
```

#### B. Completion Service Collision Resolution (`lib/services/onboarding_completion_service.dart`)
Add a pre-processing step `_mergeOverlappingEatingBlocks(List<TimelineBlockDraft> baseBlocks)` before `_scheduleRoutineItems`:
- Merges any eating blocks on the same section (`eating`) that overlap on repeat days into a single block with combined `dishes`.
- Ensures zero hard-block overlaps between meal items and 100% dish data retention.

---

## 5. Verification Method

### Automated Unit & Widget Test Suite Plan

Create `test/group_f_issues_29_to_30_test.dart` to verify:

1. **Issue 29 Test 1: Minimum Spacing Enforcement (120 Minutes)**
   - Construct `BaseTimelineDraft` with Breakfast at 8:00 AM (480 min) and Lunch at 9:30 AM (570 min, spacing = 90 min).
   - Call `draft.baseTimeline.validateEatingSetup()`.
   - **Expectation**: Returns string containing `'must be spaced at least 120 minutes apart'`.

2. **Issue 29 Test 2: Maximum Daily Meal Count Limit (6 Meals)**
   - Construct `BaseTimelineDraft` with 7 eating blocks on Day 1 (Monday).
   - Call `draft.baseTimeline.validateEatingSetup()`.
   - **Expectation**: Returns string containing `'Maximum of 6 meals allowed'`.

3. **Issue 30 Test 1: Multi-Dish Candidate Consolidation**
   - Pass 3 overlapping candidate blocks for Breakfast ("Oatmeal" at 8:00 AM, "Toast" at 8:05 AM, "Juice" at 8:10 AM) to candidate mapping.
   - **Expectation**: Returns exactly **1** consolidated `TimelineBlockDraft` with `dishes` containing `['Oatmeal', 'Toast', 'Juice']`.
   - **Expectation**: `BaseTimelineDraft.detectConflicts()` returns **0 conflicts**.

4. **Issue 30 Test 2: Zero Data Loss During Completion Bundle Build**
   - Build `OnboardingCompletionBundle` with multi-dish eating blocks.
   - **Expectation**: All dish names are present in `routineItemsForApp.first.dishes`.
   - **Expectation**: No dish items fall back to `[Tiny]` unscheduled items.

### Execution Command
```bash
flutter test test/group_f_issues_29_to_30_test.dart
```
