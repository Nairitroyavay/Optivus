# Skincare Setup Screen Reference Component

This folder houses the legacy skincare routine setup screen, extracted as a blueprint for the Base Timeline setup stage in Onboarding 4.

## Component Overview

* **Source File**: [skin_care_setup_screen.dart](file:///Users/roy/optivus2/Optivus/reference_copied_old_frontend/onboarding_base_timeline/skin_care/skin_care_setup_screen.dart)
* **Goal**: Enable users to structure morning, afternoon, and night skincare routines manually, or bootstrap them quickly using Text or Photo-based AI parsing.

## Design Highlights

1. **Fluid/Droplet 3D Day Selector**:
   * Day chips styled as modern translucent 3D liquid bubbles/droplets using custom shadows, border highlights, and bottom inner glows.
2. **Interactive Drag-to-Resize Timeline**:
   * Uses standard `GestureDetector.onVerticalDragUpdate` with two control tapes ("handles") per block to expand/shrink durations.
   * Leverages custom glassmorphism handles decorated with small surrounding droplets.
3. **Glassmorphic Timeline Card**:
   * Transparent frosted layout with an embedded scrollable ruler showing hour tick marks from 6 AM to 6 AM (next day).
   * Fully responsive to screen safe areas and keyboard offsets (via `aiPanelMaxHeight`).

## Technical Dependencies & Architecture

* **State Provider**:
  * Reads and writes templates via `routineProvider`.
  * Specifically saves daily schedules using `notifier.setSkinCarePlan(dayIndex, DaySkinPlan(...))` and sets global templates using `notifier.setRoutineTemplates('skin_care', templates, importMetadata: ...)`.
* **AI Product Parsing**:
  * **Text AI**: Submits raw strings of comma/newline-separated product listings to `routineRepositoryProvider.previewRoutineImport()`. If offline or error occurs, falls back to `fallbackSkinCareTemplatesFromText()` for local rule-based parsing.
  * **Photo AI**: Integrates legacy `ImageUploadService` for camera/gallery compressed uploads. Passes image metadata to the preview import pipeline. Safe-checks feature flags via `appFeatureFlagsProvider.skinProductImageImportReady`.
* **Events & Firestore Sync**:
  * Emits event flows `suggestionGenerated`, `suggestionAccepted`, and `suggestionDismissed` to the central event system.
  * Updates suggestion statuses in firestore under the `suggestions` collection using `firestoreServiceProvider.saveSuggestion()`.
