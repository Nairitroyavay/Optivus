# Group G (Issues 31–32) Analysis: Class Timetable Validation & Exam Schedule Priority Override

## Executive Summary
This analysis evaluates Group G (Issues 31 and 32) within Optivus, covering Class Timetable Overlap Detection (Issue 31) and Exam Schedule Priority Override during onboarding import (Issue 32).

All 19 test cases defined in `test/group_g_issues_31_to_32_test.dart` have been implemented and verified as passing (19/19).

---

## 1. Issue 31: Class Timetable Overlap Detection with Routine Items

### 1.1 Architecture & Conflict Engine Mechanics
- **Strict Hard Blocks**: `RoutineCategory.classBlock` and `RoutineCategory.job` are flagged by `RoutineConflictEngine._isUnavailableTime()`.
- **Classification Priority in `RoutineConflictEngine.detect()`**:
  1. `_isUnavailableTime(a) || _isUnavailableTime(b)` -> `RoutineConflictType.unavailableTime` (`blocking: true`, `canKeepBoth: false`).
  2. `_isSleep(a) || _isSleep(b)` -> `RoutineConflictType.sleepConflict` (`blocking: true`, `canKeepBoth: false`).
  3. `a.isHardBlock && b.isHardBlock` -> `RoutineConflictType.hardBlockConflict` (`blocking: true`, `canKeepBoth: false`).
  4. Non-strict soft blocks overlapping -> `RoutineConflictType.timeOverlap` (`blocking: false`, `canKeepBoth: true`).
- **Validation Outcome in `RoutineValidationService.validate()`**:
  - Overlap with a `classBlock` generates `unavailableTime` (`blocking: true`), causing `RoutineValidationService.validate()` to return `isValid: false` with `errorType: RoutineValidationErrorType.overlappingBlocking`.
  - Overlap between two soft blocks generates `timeOverlap` (`blocking: false`), allowing `RoutineValidationService.validate()` to return `isValid: true`.

### 1.2 Edge Case Matrix & Evidence
| Edge Case Scenario | Inputs | Behavior / Output | Evidence Reference |
|-------------------|--------|-------------------|------------------- |
| **Strict Hard Class vs. Soft Block** | Class 09:00-10:00 (classBlock) vs. Lunch 09:30-10:30 (eating) | `RoutineConflictType.unavailableTime`, `blocking: true`, `isValid: false` | `test/group_g_issues_31_to_32_test.dart`: Test 1.1 |
| **Soft Block vs. Soft Block** | Habit 09:00-10:00 vs. Habit 09:30-10:30 | `RoutineConflictType.timeOverlap`, `blocking: false`, `isValid: true` | `test/group_g_issues_31_to_32_test.dart`: Test 1.2 |
| **Class vs. Class** | Class 10:00-11:00 vs. Class 10:30-11:30 | `RoutineConflictType.unavailableTime`, `blocking: true`, `isValid: false` | `test/group_g_issues_31_to_32_test.dart`: Test 1.3 |
| **Non-class Hard vs. Hard** | Fixed Appt 14:00-15:00 vs. Fixed Mtg 14:30-15:30 (category: fixed) | `RoutineConflictType.hardBlockConflict`, `blocking: true`, `isValid: false` | `test/group_g_issues_31_to_32_test.dart`: Test 1.4 |
| **Contiguous Boundaries** | Class 09:00-10:00 vs. Class 10:00-11:00 | No overlap (`isValid: true`) | `test/group_g_issues_31_to_32_test.dart`: Test 1.5 |
| **Partial Start Overlap** | Class 09:00-10:00 vs. Routine 08:30-09:15 | Overlap detected (`isValid: false`) | `test/group_g_issues_31_to_32_test.dart`: Test 1.6 |
| **Partial End Overlap** | Class 09:00-10:00 vs. Routine 09:45-10:30 | Overlap detected (`isValid: false`) | `test/group_g_issues_31_to_32_test.dart`: Test 1.7 |
| **Different Days** | Class Mon 09:00-10:00 vs. Routine Tue 09:00-10:00 | No overlap (`isValid: true`) | `test/group_g_issues_31_to_32_test.dart`: Test 1.8 |
| **Multi-Day Schedules** | Class Mon/Wed/Fri vs. Routine Wed/Thu | Conflict ONLY on Wednesday (day 3) | `test/group_g_issues_31_to_32_test.dart`: Test 1.9 |
| **Weekly vs. One-Time Date** | Class Mon vs. One-time item Mon 2026-07-27 | Conflict on matching Monday; valid on Tuesday | `test/group_g_issues_31_to_32_test.dart`: Test 1.10 |
| **Sleep Category Overlap** | Sleep 23:00-07:00 vs. Habit 23:30-24:00 | `RoutineConflictType.sleepConflict`, `blocking: true`, `isValid: false` | `test/group_g_issues_31_to_32_test.dart`: Test 1.11 |

---

## 2. Issue 32: Exam Schedule Priority Override During Class Onboarding Import

### 2.1 Implementation Mechanics
- **Location**: `mapOnboarding4Candidates()` in `lib/features/onboarding/steps/onboarding_step4_unified.dart` (lines 470–493).
- **Algorithm**:
  1. Candidates are converted to initial `ClassRoutineBlock` items.
  2. Exam identification: Title checked via `block.subject.toLowerCase().contains('exam')`.
  3. Overlap resolution loop:
     For each regular class (non-exam), iterate over all other blocks. If the other block is an Exam and overlaps in time (`startMinute < other.endMinute && endMinute > other.startMinute`), remove `other.repeatDays` from the regular class's `repeatDays`.
  4. Retention rule: If `currentRepeatDays.isNotEmpty`, preserve the modified regular class. If empty, the regular class is completely omitted.

### 2.2 Edge Case Matrix & Evidence
| Edge Case Scenario | Inputs | Behavior / Output | Evidence Reference |
|-------------------|--------|-------------------|------------------- |
| **Partial Day Override** | Class Mon/Wed 10:00-11:00, Exam Wed 10:30-12:00 | Class retains Mon (day 1); Wed (day 3) given to Exam | `test/group_g_issues_31_to_32_test.dart`: Test 2.1 |
| **Full Overlap Override** | Class Mon 09:00-10:00, Exam Mon 09:00-11:00 | Class dropped completely (`repeatDays` empty); Exam retained | `test/group_g_issues_31_to_32_test.dart`: Test 2.2 |
| **Case-Insensitive Title** | Title `"CHEMISTRY FINAL EXAM"` | Detected as Exam; overrides regular class | `test/group_g_issues_31_to_32_test.dart`: Test 2.3 |
| **Same Day Non-Overlapping** | Class Mon 09:00-10:00, Exam Mon 14:00-16:00 | Both preserved intact (`repeatDays = [1]`) | `test/group_g_issues_31_to_32_test.dart`: Test 2.4 |
| **Contiguous Times** | Class Mon 09:00-10:00, Exam Mon 10:00-12:00 | Both preserved intact (no minute overlap) | `test/group_g_issues_31_to_32_test.dart`: Test 2.5 |
| **Multiple Exams** | Exam 1 10:00-12:00, Exam 2 11:00-13:00 | Both exams retained (neither overrides another exam) | `test/group_g_issues_31_to_32_test.dart`: Test 2.6 |
| **Malformed Candidate Filtering** | Candidates with empty title, invalid times, or missing days | Filtered out; valid candidates mapped and override applied | `test/group_g_issues_31_to_32_test.dart`: Test 2.7 |

---

## 3. Test Suite Implementation Summary
`test/group_g_issues_31_to_32_test.dart` defines 19 test cases organized in 3 groups:
- **Group 1**: Tests 1.1 – 1.11 (Issue 31 Class Timetable Overlap Detection & Routine Validation).
- **Group 2**: Tests 2.1 – 2.7 (Issue 32 Exam Schedule Priority Override).
- **Group 3**: Test 3.1 (Onboarding Draft Restoration & Step 6 Persistence Integration).

All 19 tests compile without errors and pass cleanly.
