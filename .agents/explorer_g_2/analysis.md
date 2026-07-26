# Group G (Issues 31–32: Class Timetable Validation) Independent Exploration & Analysis Report

## Executive Summary

This report presents an independent exploration of Group G (Issues 31–32) within the Optivus codebase:
- **Issue 31**: Class timetable overlap detection with routine items.
- **Issue 32**: Exam schedule priority override during class onboarding import.

Based on code investigation across `lib/` and `test/`, we traced the architecture, data models, conflict engines, onboarding candidate mappers, and test suites. We identified key design defects, data loss risks, test compilation errors, and synthesized an implementation and test strategy.

---

## 1. Subsystem & Architectural File Mapping

| Subsystem / Layer | File Path | Key Responsibilities & Data Structures |
| --- | --- | --- |
| **Routine Item Model** | `lib/models/routine_item.dart` | `RoutineItem`, `RoutineBlockType` (`hardBlock`, `softBlock`, `flexibleTask`, `trackerTask`, `checkIn`, `moneyTask`), `RoutineCategory` (`classBlock`, `job`, `eating`, `skinCare`, `habit`, `sleep`, `fixed`, etc.), `isHardBlock` getter. |
| **Candidate & Import Models** | `lib/models/routine_import_review.dart` | `RoutineImportCandidateBlock` (`hardBlock`, `blockType`, `category`, `repeatDays`), `RoutineImportReviewDraft`, `RoutineImportReviewSource` (`classes`, `work`, `eating`, `skinCare`). |
| **Draft & Timeline Models** | `lib/models/onboarding_draft.dart` | `OnboardingDraft`, `BaseTimelineDraft`, `TimelineBlockDraft`, `PendingFutureImportDraft`. |
| **Onboarding Class Mappers** | `lib/features/onboarding/steps/onboarding_step4_unified.dart` | `OnboardingStep4Unified`, `mapOnboarding4Candidates()`, `ClassRoutineBlock`, candidate day/room extractors. |
| **Legacy Class Timeline** | `lib/features/onboarding/steps/onboarding_class_setup_timeline.dart` | `OnboardingClassSetupWidget`, `ScheduleSetupConfig.classSetup` (legacy split UI reference). |
| **Validation Service** | `lib/features/routine/services/routine_validation_service.dart` | `RoutineValidationService.validate()`, `validateBatch()`. Enforces invariants (start/end minutes, meal limits) and evaluates blocking conflicts via `RoutineConflictEngine`. |
| **Conflict Engine** | `lib/features/routine/services/routine_conflict_engine.dart` | `RoutineConflictEngine.detect()`. Classifies conflicts into `unavailableTime`, `sleepConflict`, `hardBlockConflict`, `overnightConflict`, `timeOverlap`, `duplicateRoutine`, `tooManyTasks`. |
| **Conflict Utils Adapter** | `lib/features/routine/managers/base_timeline/utils/base_timeline_conflict_utils.dart` | `BaseTimelineConflictUtils.findConflicts()`. Adapts conflict engine checks for base timeline screens. |
| **Onboarding Completion** | `lib/services/onboarding_completion_service.dart` | `OnboardingCompletionService.buildBundle()`, `_scheduleRoutineItems()`. Converts draft timeline blocks into `RoutineItem`s. |
| **Conflict Domain Model** | `lib/features/routine/domain/routine_conflict.dart` | `RoutineConflict`, `RoutineConflictType`, `RoutineConflictSummary`. |
| **Target Test Suite** | `test/group_g_issues_31_to_32_test.dart` | Dedicated test file for Group G (currently failing compilation due to missing constructor arguments). |

---

## 2. Issue 31 Exploration: Class Timetable Overlap Detection with Routine Items

### 2.1 Current Architecture & Flow
1. **Creation/Import**:
   - In Onboarding Step 4 (`OnboardingStep4Unified`), class timetable items are imported or manually entered as `ClassRoutineBlock`s and mapped to `TimelineBlockDraft`s with `section: 'classes'` and `blockType: 'hard_block'`.
   - On completion (`OnboardingCompletionService`), `classes` blocks are projected as `RoutineItem`s with `category: RoutineCategory.classBlock` and `blockType: RoutineBlockType.hardBlock`.
2. **Conflict Evaluation**:
   - When users add/edit routine items (e.g. eating, habits, flexible tasks), `RoutineValidationService.validate()` projects items on applicable dates and calls `RoutineConflictEngine.detect()`.

### 2.2 Core Defect in Conflict Classification (`RoutineConflictEngine.detect`)
In `lib/features/routine/services/routine_conflict_engine.dart` (lines 94–106):

```dart
if (isAUnavailable || isBUnavailable) {
  conflictType = RoutineConflictType.unavailableTime;
  blocking = true;
  canKeepBoth = false;
} else if (isASleep || isBSleep) {
  conflictType = RoutineConflictType.sleepConflict;
  blocking = true;
  canKeepBoth = false;
} else if (a.isHardBlock && b.isHardBlock) {
  conflictType = RoutineConflictType.hardBlockConflict;
  blocking = true;
  canKeepBoth = false;
}
```

Where `_isUnavailableTime` is defined as:
```dart
static bool _isUnavailableTime(RoutineItem item) {
  return item.category == RoutineCategory.classBlock ||
      item.category == RoutineCategory.job;
}
```

**Impact & Analysis**:
1. Because `isAUnavailable || isBUnavailable` uses logical **OR**, if item `a` is a Class (`RoutineCategory.classBlock`) and item `b` is a soft block (e.g. Lunch/`eating` or a habit), `isAUnavailable` evaluates to `true`.
2. The engine incorrectly classifies a Class vs Soft Block overlap as `RoutineConflictType.unavailableTime` with `blocking = true` and `canKeepBoth = false`.
3. Because `blocking` is `true`, `RoutineValidationService.validate()` returns `RoutineValidationErrorType.overlappingBlocking` and fails validation (`isValid: false`).
4. Users are prevented from scheduling routine habits, meals, or flexible tasks that overlap with class hours, even when those soft items can co-exist as non-blocking `timeOverlap` warnings.
5. Furthermore, line 102 (`a.isHardBlock && b.isHardBlock`) is unreachable for `classBlock` or `job` because the preceding `if (isAUnavailable || isBUnavailable)` intercepts all class/job items first!

### 2.3 Existing Test Inconsistencies Across Codebase
- `test/group_g_issues_31_to_32_test.dart` expects: A class overlapping with a soft block creates a `timeOverlap` conflict (`blocking: false`, `isValid: true`).
- `test/routine_conflict_engine_test.dart` expects: A class overlapping with a habit creates `unavailableTime`.
- `test/routine_state_test.dart` expects: A hard block overlapping with a flexible task creates `hardBlockConflict`.

---

## 3. Issue 32 Exploration: Exam Schedule Priority Override During Class Onboarding Import

### 3.1 Current Implementation in `OnboardingStep4Unified`
In `lib/features/onboarding/steps/onboarding_step4_unified.dart` (lines 470–493), candidate mapping contains:

```dart
// Issue 32: Exam schedule priority override
// If an exam overlaps with a regular class, remove the overlapping day(s) from the regular class.
final resolvedBlocks = <ClassRoutineBlock>[];
for (final block in blocks) {
  var currentRepeatDays = List<int>.from(block.repeatDays);
  final isExam = block.subject.toLowerCase().contains('exam');
  if (!isExam) {
    for (final other in blocks) {
      if (block.id == other.id) continue;
      final isOtherExam = other.subject.toLowerCase().contains('exam');
      if (isOtherExam) {
        final overlaps = block.startMinute < other.endMinute && block.endMinute > other.startMinute;
        if (overlaps) {
          currentRepeatDays.removeWhere((day) => other.repeatDays.contains(day));
        }
      }
    }
  }
  if (currentRepeatDays.isNotEmpty) {
    resolvedBlocks.add(
      block.copyWith(repeatDays: currentRepeatDays),
    );
  }
}
```

### 3.2 Critical Defects & Data Loss Risks

1. **Permanent User Data Loss (Template Destruction)**:
   - Calling `currentRepeatDays.removeWhere((day) => other.repeatDays.contains(day))` permanently removes days from the regular class template.
   - For example, if a "Physics 101" class repeats on Mondays (`[1]`) and a "Physics Final Exam" occurs on one Monday (`[1]`), Monday is stripped from `Physics 101` for the entire semester.
   - If all repeat days overlap with an exam, the regular class block is completely omitted from `resolvedBlocks` and never saved. This directly violates zero-data-loss requirements.
2. **Narrow & Fragile Keyword Matching**:
   - The check only tests `block.subject.toLowerCase().contains('exam')`.
   - Misses standard academic terminology such as `"midterm"`, `"final"`, `"quiz"`, `"test"`, or `"assessment"`.
3. **Restricted Scope**:
   - The priority logic is currently buried only inside `mapOnboarding4Candidates()` for Step 4 AI photo imports.
   - It does not operate during manual class entry, review screens (`RoutineImportReviewScreen`), or post-onboarding routine setup.

---

## 4. Test Suite Diagnostics (`test/group_g_issues_31_to_32_test.dart`)

Running `flutter test test/group_g_issues_31_to_32_test.dart` currently fails at compilation with:

```
test/group_g_issues_31_to_32_test.dart:55:36: Error: Required named parameter 'hardBlock' must be provided.
        RoutineImportCandidateBlock(
test/group_g_issues_31_to_32_test.dart:65:36: Error: Required named parameter 'hardBlock' must be provided.
        RoutineImportCandidateBlock(
test/group_g_issues_31_to_32_test.dart:75:36: Error: Required named parameter 'hardBlock' must be provided.
        RoutineImportCandidateBlock(
test/group_g_issues_31_to_32_test.dart:88:21: Error: The argument type 'List<dynamic>' can't be assigned to the parameter type 'List<RoutineImportCandidateBlock>'.
```

### Root Cause
1. `RoutineImportCandidateBlock` constructor in `lib/models/routine_import_review.dart` specifies `required bool hardBlock`. In the test file, `hardBlock:` was omitted.
2. In `test/group_g_issues_31_to_32_test.dart`, `final candidates = [...]` was inferred as `List<dynamic>`, failing type assignment to `List<RoutineImportCandidateBlock>`.

---

## 5. Recommended Implementation Strategy

### 5.1 Issue 31 Recommended Fix (Conflict Engine Refactoring)
1. **Refactor Conflict Classification Matrix in `RoutineConflictEngine.detect()`**:
   - Classify overlaps between **two strict hard/unavailable blocks** (e.g. Class vs Class, Class vs Work, Work vs Work) as `RoutineConflictType.hardBlockConflict` or `RoutineConflictType.unavailableTime` (`blocking: true`, `canKeepBoth: false`).
   - Classify overlaps between a **hard block** (Class/Work) and a **soft block** (Lunch/eating, habit, flexible task) as `RoutineConflictType.timeOverlap` (`blocking: false`, `canKeepBoth: true`).
   - Retain `sleepConflict` (`blocking: true`, `canKeepBoth: false`) for any item overlapping with `RoutineCategory.sleep`.
2. **Reconcile Existing Tests**:
   - Update `test/routine_conflict_engine_test.dart` and `test/routine_state_test.dart` to reflect the refined conflict classification matrix.

### 5.2 Issue 32 Recommended Fix (Non-Destructive Exam Priority Override)
1. **Expand Exam Keyword Matching**:
   - Define robust keyword matcher: `RegExp(r'\b(exam|midterm|final|quiz|test|assessment)\b', caseSensitive: false)`.
2. **Preserve Class Templates (Zero Data Loss)**:
   - In `mapOnboarding4Candidates()`, do **NOT** strip `repeatDays` from regular class blocks.
   - Both the regular class template and the exam block must be preserved in `resolvedBlocks`.
   - Set exam candidate blocks with `priority: RoutinePriority.mustDo` and `hardBlock: true`.
3. **Date-Specific Occurrence Override**:
   - During day-level occurrence projection or date-specific conflict resolution, exam occurrences take precedence on the specific date of the exam, flagging lower-priority class occurrences on that date as overridden without altering the underlying weekly timetable template.

### 5.3 Test Suite Remediation (`test/group_g_issues_31_to_32_test.dart`)
1. Fix constructor arguments in `test/group_g_issues_31_to_32_test.dart` by adding `hardBlock: true` to all `RoutineImportCandidateBlock` instances.
2. Add explicit type annotation `final List<RoutineImportCandidateBlock> candidates = [...]`.

---

## 6. Recommended Test Strategy

1. **Unit Tests (`test/group_g_issues_31_to_32_test.dart`)**:
   - Verify class (hard block) vs soft block (eating/habit) creates non-blocking `timeOverlap` (`isValid: true`).
   - Verify class (hard block) vs class (hard block) creates blocking `hardBlockConflict` (`isValid: false`).
   - Verify exam candidates preserve regular class repeat days while establishing priority overrides.
2. **Regression Verification**:
   - `flutter test test/routine_conflict_engine_test.dart`
   - `flutter test test/routine_validation_service_test.dart`
   - `flutter test test/routine_state_test.dart`
   - `flutter test test/onboarding_step4_timeline_layout_test.dart`
   - `flutter test test/onboarding_step6_fixed_schedule_test.dart`
