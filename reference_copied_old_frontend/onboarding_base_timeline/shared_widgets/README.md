# Shared Setup Widgets Reference

This folder contains shared widgets utilized during the Base Timeline setup flows.

## Component Overview

* **Source File**: [routine_review_screen.dart](file:///Users/roy/optivus2/Optivus/reference_copied_old_frontend/onboarding_base_timeline/shared_widgets/routine_review_screen.dart)
* **Goal**: Provides a uniform interface to review, edit, add, or delete AI-suggested routine templates before accepting and writing them to the database.

## Technical Details

1. **Template Normalization**:
   * Uses `RoutineTemplateModel` to parse and build the standard map structure.
   * Resolves relative times (e.g. "after_breakfast" or "before_sleep") if anchors are defined.
2. **Review Card Layout**:
   * Displays individual block tiles grouped by time of day (Morning, Afternoon, Evening, Night, or Weekly Rotation).
   * Fully editable fields (Title, Start Time, End Time, Timing Rule, Repeat Rule, Steps, and Notes).
   * Visual metadata indicators (AI Confidence scores and logical overlap/missing warnings).
3. **Acceptance Guards**:
   * Integrates `runRoutineAcceptWithTimeout()` to ensure backend transactions complete within safe bounds, handling latency and timeout exceptions gracefully.
