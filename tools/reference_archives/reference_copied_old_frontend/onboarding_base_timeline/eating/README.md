# Eating Setup Screen — Reference Material

This directory contains the legacy implementation of the meal routine/eating schedule setup screen from the old `optivus2` app.

## Source Reference
* **Legacy Path:** `lib/views/routine/eating_setup_screen.dart`
* **Target Integration Path:** `lib/views/onboarding/screens/eating_setup_screen.dart` (or similar under active onboarding)

## Components & Functionality
1. **Interactive Timeline:** Drag-to-resize meal schedule blocks represented as "taped" blocks with floating water droplets.
2. **Mindful Eating Mode Banner:** Adapts fields and hints dynamically when sensitive eating flag is enabled.
3. **Multi-Source Mess Menu Importer:**
   - **Text Parser (Offline):** Extracts meal details from pasted text menus offline.
   - **Photo / OCR Import:** Backend AI workflow to read hostel/college mess menus from a camera photo or gallery upload.
4. **Day-wise Selector:** Circular day selection droplets that slide horizontally.

## Future Reuse Plan
* **Visual Harmonization:** Update layouts, text fields, and icons to be fully compatible with the new glassmorphic aesthetics.
* **Mock Photo Uploads:** For the initial frontend-only phase, replace image upload and Worker calls with mock previews or direct offline text parsing options.
* **Riverpod Migration:** Adapt the `routineProvider` and `eatingDisorderFlagProvider` dependencies to match the active providers set up in the new project.
