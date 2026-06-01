# Shared Models and Enums for Onboarding Base Timeline

This directory contains standalone, isolated models and parser utilities extracted from the legacy `optivus2` project. They are kept here purely as reference and have no direct imports in the active, compiling frontend.

## Files

1. **`routine_template_model.dart`**
   - The central model describing a template routine.
   - Contains extensive parsing helpers for safe, backward-compatible conversion from Firestore JSON maps.
   - Generates stable, deterministic hashes using `md5` to represent unique task templates.

2. **`copied_routine_provider_subset.dart`**
   - A curated subset of models extracted from the legacy `routine_provider.dart` state class.
   - Provides key domain models for specific sub-timelines:
     - **Skincare:** `SkinStep`, `DaySkinPlan`
     - **Eating / Meals:** `MealItem`, `DayMealPlan`
     - **Timetable / Classes:** `ClassItem`
     - **Fixed Block Schedules:** `FixedScheduleTemplate`, `FixedBlock` (with time-to-minute converters)
   - Houses necessary internal private string and time-formatting helpers so that copied pages can compile cleanly without pulling in the entire Riverpod database state.
