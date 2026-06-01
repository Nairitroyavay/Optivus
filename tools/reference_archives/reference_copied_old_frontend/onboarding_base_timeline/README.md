# Base Timeline & Setup Screens (Legacy Reference)

This directory houses the copied, isolated, and documented frontend assets from the legacy `optivus2` project. These assets form the blueprint for **Onboarding 4 — Set Your Base Timeline** in the new `Optivus` application.

> [!NOTE]
> All files in this directory are in **REFERENCE COPY ONLY** mode. They are deliberately ignored by the static analyzer in `analysis_options.yaml` and are not imported or routed inside the active application.

## Directory Structure

```
onboarding_base_timeline/
├── README.md                           # This overview file
├── COPY_REPORT.md                      # Technical copy report & architectural blueprint
├── classes/
│   ├── README.md                       # timetable setup documentation
│   └── class_setup_screen.dart         # timetable UI reference
├── eating/
│   ├── README.md                       # meal routine setup documentation
│   └── eating_setup_screen.dart         # meal timeline UI reference
├── fixed/
│   ├── README.md                       # work/job & sleep block setup documentation
│   ├── fixed_schedule_setup_screen.dart # 24h timeline setup UI
│   └── fixed_schedule_editor.dart       # individual fixed block modal editor UI
├── skin_care/
│   ├── README.md                       # morning/night skincare routines documentation
│   └── skin_care_setup_screen.dart     # skincare routine builder UI
├── shared_widgets/
│   ├── README.md                       # shared widget copy overview
│   └── routine_review_screen.dart      # routine overview review board UI
└── shared_models_or_enums/
    ├── README.md                       # model mapping documentation
    ├── routine_template_model.dart     # base routine template mapping structure
    └── copied_routine_provider_subset.dart # subset of legacy provider structs and parsers
```

## Integration Blueprint

During the full frontend integration phase, these reference files will be adapted and wired as follows:

1. **Step-by-Step Onboarding flow**:
   - The user will progress from fixed blocks (sleep, work) to classes/timetable, then eating schedules, and finally optional routines like skincare.
2. **Design Language Alignment**:
   - The glassmorphism, dynamic bubble/liquid animations, and smooth HSL gradient backdrops present in these reference designs will be ported and aligned with the core design system tokens in `lib/core/theme/`.
3. **Data Schema Migration**:
   - Instead of direct memory mutations, actions will fire structured state-notifier dispatches mapped to local state.
   - The final timeline will compile into a set of `RoutineTemplateModel` instances saved to the local database before syncing with Firestore.
