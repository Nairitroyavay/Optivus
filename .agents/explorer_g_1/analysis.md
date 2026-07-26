# Group G (Issues 31–32: Class Timetable Validation) Deep-Dive Analysis

## Executive Summary
This report provides a comprehensive deep-dive exploration of Group G issues in the Optivus codebase:
- **Issue 31**: Class timetable overlap detection with routine items.
- **Issue 32**: Exam schedule priority override during class onboarding import.

Through static analysis, code tracing across `lib/` and `test/`, and running `flutter test`, we identified the exact mechanisms, root causes, defective classification logic, data loss risks, affected files, test compilation errors, and recommended 13-step sequential fix designs.

---

## 1. Codebase Architecture & File Mapping

The class schedule, timetable, exam schedule, onboarding, and routine validation subsystems span the following core files:

### Models
- `lib/models/routine_item.dart`:
  - Defines `RoutineItem`, `RoutineBlockType` (`hardBlock`, `softBlock`, `flexibleTask`, `checkIn`, `moneyTask`, `trackerTask`), `RoutineCategory` (`classBlock`, `job`, `eating`, `skinCare`, `habit`, `fixed`, `sleep`, `health`, etc.), and `isHardBlock` getter.
- `lib/models/routine_import_review.dart`:
  - Defines `RoutineImportCandidateBlock`, `RoutineImportReviewDraft`, `RoutineImportReviewSource` (`classes`, `work`, `eating`, `skinCare`), and `RoutineImportCandidateType`.
- `lib/models/onboarding_draft.dart`:
  - Defines `OnboardingDraft`, `BaseTimelineDraft`, `TimelineBlockDraft`, and `PendingFutureImportDraft`.
- `lib/models/onboarding_completion_bundle.dart`:
  - Defines `OnboardingCompletionBundle`, storing converted `routineItemsForApp` and `baseTimelineBlocks`.

### Onboarding Steps & Setup Screens
- `lib/features/onboarding/steps/onboarding_step4_unified.dart`:
  - `OnboardingStep4Unified`: Unified single-screen class and work schedule setup step. Contains `mapOnboarding4Candidates()` which maps AI-extracted candidates into `ClassRoutineBlock`s and handles exam priority override.
- `lib/features/onboarding/steps/onboarding_class_setup_timeline.dart`:
  - `OnboardingClassSetupWidget`: Legacy split UI for Class setup (kept for reference, marked legacy). Defines `ClassRoutineBlock` and `ScheduleSetupConfig.classSetup`.
- `lib/features/onboarding/steps/onboarding_step_6_fixed_schedule.dart`:
  - `OnboardingStep6`: Fixed schedule step (Sleep, Bath, manual non-negotiable blocks).
- `lib/features/routine/managers/base_timeline/screens/classes_routine_setup_screen.dart`:
  - `ClassesRoutineSetupScreen`: Post-onboarding screen to view, edit, and add Class items. Uses `BaseTimelineConflictUtils.findConflicts()` before saving.

### Services & Controllers
- `lib/features/routine/services/routine_validation_service.dart`:
  - `RoutineValidationService`: Static `validate()` and `validateBatch()`. Enforces invariants (time ranges, duration, meal spacing, ID formats, UID ownership) and evaluates blocking conflicts via `RoutineConflictEngine.detect()`.
- `lib/features/routine/services/routine_conflict_engine.dart`:
  - `RoutineConflictEngine`: Static `detect()`. Classifies conflicts (`unavailableTime`, `sleepConflict`, `hardBlockConflict`, `overnightConflict`, `timeOverlap`, `duplicateRoutine`, `tooManyTasks`, `invalidDuration`, `trackerTaskNotCompleted`).
- `lib/features/routine/managers/base_timeline/utils/base_timeline_conflict_utils.dart`:
  - `BaseTimelineConflictUtils`: Adapter delegating conflict checks to `RoutineConflictEngine.detect()`.
- `lib/services/onboarding_completion_service.dart`:
  - `OnboardingCompletionService`: `buildBundle()` and `_scheduleRoutineItems()`, converting draft blocks into `RoutineItem`s.

### Domain & Conflict Models
- `lib/features/routine/domain/routine_conflict.dart`:
  - `RoutineConflict`, `RoutineConflictType`.

### Tests
- `test/group_g_issues_31_to_32_test.dart`: Group G tests (currently failing compilation due to missing `hardBlock` argument and dynamic list type mismatch).
- `test/onboarding_step6_fixed_schedule_test.dart`: Fixed schedule tests.
- `test/onboarding_step4_timeline_layout_test.dart`: Step 4 timeline layout and candidate mapping tests.
- `test/routine_validation_service_test.dart`: Routine validation service tests.
- `test/routine_conflict_engine_test.dart`: Routine conflict engine tests.
- `test/routine_state_test.dart`: Routine materialization and conflict state tests.

---

## 2. Issue 31 Deep-Dive: Class Timetable Overlap Detection with Routine Items

### How Class Timetables are Created/Imported
1. **Onboarding Step 4 (`OnboardingStep4Unified`)**:
   - User uploads a class schedule photo or manually inputs classes.
   - AI extraction or manual entry populates `RoutineImportCandidateBlock`s.
   - `mapOnboarding4Candidates()` maps candidates to `ClassRoutineBlock`s.
   - Blocks are saved as `TimelineBlockDraft`s (`section: 'classes'`, `blockType: 'hard_block'`) in `draft.baseTimeline.blocks`.
2. **Post-Onboarding (`ClassesRoutineSetupScreen`)**:
   - User manually adds or edits a class in `ClassesRoutineSetupScreen`.
   - `BaseTimelineConflictUtils.findConflicts()` calls `RoutineConflictEngine.detect()` to check against existing `RoutineItem`s.
3. **Routine Validation (`RoutineValidationService.validate`)**:
   - Checks candidates against existing templates on applicable dates using `RoutineConflictEngine.detect()`.

### Missing & Defective Overlap Detection
1. **Defect in `RoutineConflictEngine.detect()` (lines 94–106 of `lib/features/routine/services/routine_conflict_engine.dart`)**:
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
   - `_isUnavailableTime(item)` returns `true` for `RoutineCategory.classBlock` and `RoutineCategory.job`.
   - Because `isAUnavailable || isBUnavailable` uses **OR**, any overlap between a `classBlock` (hard block) and a soft block (e.g. Lunch/`eating` or a `habit`) evaluates to `isAUnavailable = true`.
   - As a result, `RoutineConflictEngine` classifies a Class vs Soft Block overlap as a **blocking** `unavailableTime` conflict (`blocking: true`).
   - Consequently, `RoutineValidationService.validate()` treats the soft block candidate as invalid (`isValid: false`) instead of allowing it as a non-blocking `timeOverlap` warning (`isValid: true`).

2. **Missing Cross-Section Validation in Onboarding Step 4**:
   - When AI extracts class blocks or when a user adds/edits classes in Step 4, `OnboardingStep4Unified` writes directly to `draft.baseTimeline.blocks`.
   - It performs **no validation** against existing draft blocks (such as Step 6 sleep/bath blocks or Step 5 eating blocks).
   - In `OnboardingCompletionService._scheduleRoutineItems()`, `baseBlocks` (classes, work, fixed, eating) are mapped directly into `scheduled` without checking whether class blocks overlap with fixed sleep/bath blocks or other hard blocks.

---

## 3. Issue 32 Deep-Dive: Exam Schedule Priority Override During Class Import

### How Exam Schedules are Currently Handled
In `mapOnboarding4Candidates()` in `lib/features/onboarding/steps/onboarding_step4_unified.dart` (lines 470-493):
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

### Deficiencies & Data Loss Risks
1. **Destructive Day Removal / User Data Loss**:
   - The current code mutates `currentRepeatDays.removeWhere((day) => other.repeatDays.contains(day))` and drops the regular class entirely if `currentRepeatDays.isEmpty`.
   - If an exam occurs on a Monday during exam week, stripping Monday from `repeatDays` permanently deletes Monday from the regular class schedule for the entire semester.
   - If all repeat days overlap, the regular class block is completely discarded from `resolvedBlocks`. This directly violates the requirement: *"without deleting user data"*.
2. **Narrow Recognition Keyword**:
   - Checks only `subject.toLowerCase().contains('exam')`. Misses common terms like `"midterm"`, `"final"`, `"quiz"`, `"test"`, `"assessment"`, or exam metadata in `notes`/`category`.
3. **Limited Scope**:
   - Priority override ONLY exists inside `mapOnboarding4Candidates()` for Step 4 AI imports. It does NOT operate during manual class entry, routine import review (`RoutineImportReviewScreen`), or post-onboarding routine creation.
   - It does not handle exam overrides against lower-priority routine items (habits, work shifts, eating routines).

---

## 4. Test Suite Analysis & Current Failure

Running `flutter test test/group_g_issues_31_to_32_test.dart` yields the following compilation errors:

```
test/group_g_issues_31_to_32_test.dart:55:36: Error: Required named parameter 'hardBlock' must be provided.
        RoutineImportCandidateBlock(
test/group_g_issues_31_to_32_test.dart:65:36: Error: Required named parameter 'hardBlock' must be provided.
        RoutineImportCandidateBlock(
test/group_g_issues_31_to_32_test.dart:75:36: Error: Required named parameter 'hardBlock' must be provided.
        RoutineImportCandidateBlock(
test/group_g_issues_31_to_32_test.dart:88:21: Error: The argument type 'List<dynamic>' can't be assigned to the parameter type 'List<RoutineImportCandidateBlock>'.
```

### Root Causes of Test Failures
1. `RoutineImportCandidateBlock` constructor requires `required bool hardBlock`. In `test/group_g_issues_31_to_32_test.dart` lines 55, 65, 75, `hardBlock:` was omitted.
2. The `candidates` variable in `test/group_g_issues_31_to_32_test.dart` line 54 was implicitly typed as `List<dynamic>` instead of `List<RoutineImportCandidateBlock>`.

---

## 5. Required Fix Design (Following the 13-Step Sequential Loop Rule)

1. **Step 1: Fix Test Compilation in `group_g_issues_31_to_32_test.dart`**:
   - Update `RoutineImportCandidateBlock` instantiations to include `hardBlock: true`.
   - Explicitly annotate `candidates` as `List<RoutineImportCandidateBlock>`.

2. **Step 2: Correct Conflict Engine Classification for Class Overlaps (Issue 31)**:
   - In `lib/features/routine/services/routine_conflict_engine.dart`:
     - Update `unavailableTime` condition to require `isAUnavailable && isBUnavailable` (i.e. both items are strict unavailable blocks like Class vs Class or Class vs Work).
     - When one item is a strict hard/unavailable block (Class/Job) and the other item is a soft block (eating, habit, flexible task), classify as `RoutineConflictType.timeOverlap` with `blocking = false` and `canKeepBoth = true`.
   - Update `test/routine_conflict_engine_test.dart` to match this classification rule.

3. **Step 3: Enhance Exam Priority Override without Data Loss (Issue 32)**:
   - In `lib/features/onboarding/steps/onboarding_step4_unified.dart`:
     - Expand exam keyword matching: `RegExp(r'\b(exam|midterm|final|quiz|test|assessment)\b', caseSensitive: false)`.
     - Do NOT strip `repeatDays` or delete regular class blocks from `resolvedBlocks`.
     - Instead, mark exam blocks with high priority (`RoutinePriority.mustDo`, `hardBlock: true`) and preserve regular class blocks intact in `resolvedBlocks`.
     - When materializing or resolving conflicts on specific dates, exam blocks take precedence over overlapping regular classes/routines without destroying template data.

---

## 6. Verification Plan

1. Run `flutter test test/group_g_issues_31_to_32_test.dart` to confirm compilation and test execution.
2. Run `flutter test test/routine_conflict_engine_test.dart` and `flutter test test/routine_validation_service_test.dart`.
3. Run `flutter test test/onboarding_step4_timeline_layout_test.dart` and `flutter test test/onboarding_step6_fixed_schedule_test.dart`.
