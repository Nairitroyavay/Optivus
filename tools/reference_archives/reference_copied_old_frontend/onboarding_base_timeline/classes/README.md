# Classes Setup Screen — Reference Material

This directory contains the legacy implementation of the student schedule/classes setup screen from the old `optivus2` app.

## Source Reference
* **Legacy Path:** `lib/views/routine/class_setup_screen.dart`
* **Target Integration Path:** `lib/views/onboarding/screens/class_setup_screen.dart` (or similar under active onboarding)

## Components & Functionality
1. **Student Timetable Setup:** Allows students to input their daily classes, lectures, or academic blocks.
2. **Text / OCR Schedule Parsing:** Uses a legacy backend parser flow to let users extract schedules from text or syllabus photos/documents.
3. **Structured Timetable Inputs:** Direct inputs for course code, time slot, recurrence, and classroom.

## Future Reuse Plan
* **UI Stabilization:** Restyle fields and buttons to match the modern Outfit/Inter glassmorphic visual system.
* **Remove Live Firebase Auth/Storage calls:** Replace legacy backend OCR uploads with localized inputs or mock backend responses until a Worker-scoped upload endpoint is wired up.
* **Integrate state notifier:** Replace direct provider imports with the new Riverpod state framework once defined.
