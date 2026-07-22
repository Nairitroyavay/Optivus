# Final Frontend Cleanup Inventory

> **Historical snapshot — superseded 2026-07-22.** This inventory records an
> earlier cleanup baseline and is retained only for history. Do not treat its
> status, routes, or test results as current. Use the
> [product blueprint](OPTIVUS_PRODUCT_BLUEPRINT_AS_BUILT.md),
> [navigation contract](NAVIGATION.md),
> [data-source contract](DATA_SOURCE_CONTRACT.md), and
> [technical-debt register](TECHNICAL_DEBT.md) instead.

Date: 2026-06-01

## Final Frontend-Ready Pass

Branch: `cleanup-frontend-ready-final-check`

Baseline on `main` before edits:

- `git status`: clean working tree
- `git branch`: `main`
- `flutter clean`: pass
- `flutter pub get`: pass
- `flutter analyze`: pass
- `flutter test`: pass

Scope of this pass:

- Keep the current app design, app shell, tab bar, router pattern, and fake backend mode.
- Do not start backend work, add paid Google Cloud dependencies, add Firebase Functions/Storage/Hosting, or add Google Maps API.
- Fix only frontend-readiness blockers found during audit.

Final-pass findings:

- Analyzer config still excludes only `tools/reference_archives/**` and `tools/one_time_migrations/**`; active `lib/repositories`, `lib/services`, and `lib/config` remain analyzed.
- Backend mode still defaults to `OPTIVUS_BACKEND=fake`; Firebase initialization remains dart-define gated.
- Router detail paths redirect into `/app?tab=x` and set tab-local detail providers.
- Home Mission detail now follows the same Android-back behavior as other tab details.
- UPI remains available only for India UPI payment mode; non-India money setup saves a manual method if a stale UPI selection is present.
- User-facing raw frontend-preview copy was reworded to backend-pending product copy.
- Bottom sheets are active only for compact/interaction flows and remain scroll-controlled or constrained.
- Spark-only/native-pending guardrail language remains in Profile/native setup areas.

Backend phase 1 readiness notes:

- Firestore path targets are documented in `lib/repositories/firestore_paths.dart`.
- Fake repositories and fake/native service adapters compile and remain active by default.
- UI depends on repository/state boundaries rather than direct future Firebase code, except auth can switch through `OptivusBackendConfig`.
- Android manifest remains minimal; notification, location, foreground service, camera/photos, microphone, Health Connect, Usage Access, UPI intents, Mapbox config, HTTP/Dio, and R2 upload flow are future native/backend tasks.

Earlier cleanup baseline: `flutter clean`, `flutter pub get`, and `flutter analyze` passed during the prior cleanup pass. The pre-cleanup commit was requested then, but the working tree was already clean so Git had nothing to commit.

## App Shell And Router

Active app shell files:

- `lib/views/screens/app_shell.dart`
- `lib/core/router/app_router.dart`
- `lib/app/app_navigation_controller.dart`

The app shell uses an `IndexedStack` and floating `LiquidGlassTabBar`. `/app?tab=x` is the active tab entrypoint. Existing deep-link routes redirect into `/app?tab=x` and set per-tab detail provider state instead of pushing standalone screens.

Keep:

- `app_router.dart` redirect-based in-tab detail routing
- `app_shell.dart` tab cache and `IndexedStack`
- `app_navigation_controller.dart` tab index state

Cleanup notes:

- Home has a detail provider but no dedicated `/home/mission` redirect yet.
- Detail tabs use `PopScope` to close in-tab detail before leaving the app.
- Main tab scroll padding should use the shared tab reserve helper where possible.

## Home

Active main tab:

- `lib/features/home/home_tab.dart`

Active detail provider:

- `lib/features/home/providers/home_navigation_provider.dart`

Active detail screen:

- `lib/features/home/screens/home_mission_detail_screen.dart`

Keep:

- Home dashboard providers/models
- Small Home sheets that are active and scroll-safe: notification, mind note, notebook, move later, focus control, mini action plan, note detail, coming up item, pillar detail
- `today_mission_card.dart` as the entrypoint to full-screen mission detail

Safe cleanup:

- The old mission detail sheet is gone; Home mission uses the full-screen in-tab detail.
- The active Now/Next feedback sheet was renamed to `now_next_feedback_sheet.dart`; no user-facing copy says "demo".

## Routine

Active main tab:

- `lib/features/routine/routine_tab.dart`

Active detail provider:

- `lib/features/routine/providers/routine_navigation_provider.dart`

Active detail screens:

- `lib/features/routine/managers/base_timeline/base_timeline_manager_screen.dart`
- `lib/features/routine/managers/base_timeline/screens/classes_routine_setup_screen.dart`
- `lib/features/routine/managers/base_timeline/screens/work_routine_setup_screen.dart`
- `lib/features/routine/managers/base_timeline/screens/eating_routine_setup_screen.dart`
- `lib/features/routine/managers/base_timeline/screens/fixed_routine_setup_screen.dart`
- `lib/features/routine/managers/base_timeline/screens/skin_care_routine_setup_screen.dart`
- `lib/features/routine/managers/base_timeline/screens/routine_import_review_screen.dart`
- Inline Routine Settings inside `routine_tab.dart`
- `lib/features/routine/screens/routine_habit_systems_screen.dart`
- `lib/features/routine/screens/routine_history_screen.dart`

Keep:

- `add_routine_sheet.dart`
- `routine_detail_sheet.dart`
- `routine_move_sheet.dart`
- `routine_filter_sheet.dart`
- `week_planner_sheet.dart`
- `ai_assistant_sheet.dart`

Old/reference found:

- `lib/features/routine/sheets/routine_settings_sheet.dart` duplicates the active inline Routine Settings path.

Safe cleanup:

- Route header settings to inline Routine Settings.
- Delete `routine_settings_sheet.dart` after its import/call is removed.

## Tracker

Active main tab:

- `lib/features/tracker/tracker_tab.dart`

Active detail provider:

- `lib/features/tracker/providers/tracker_navigation_provider.dart`

Active detail screens:

- Money: `lib/features/tracker/money/money_system_screen.dart`
- Meditation: `lib/features/tracker/meditation/meditation_tracker_screen.dart`
- Fitness: `lib/features/tracker/fitness/fitness_center_screen.dart`
- Screen Time: `lib/features/tracker/screen_time/screen_time_screen.dart`
- Hydration: `lib/features/tracker/hydration/hydration_tracker_screen.dart`
- Tracker Settings: `lib/features/tracker/screens/tracker_settings_screen.dart`
- Usage Access: `lib/features/tracker/screens/usage_access_setup_screen.dart`
- Health Connect: `lib/features/tracker/screens/health_connect_setup_screen.dart`
- Location/Mapbox: `lib/features/tracker/screens/location_mapbox_setup_screen.dart`
- Activation: `lib/features/tracker/screens/tracker_activation_screen.dart`
- History: `lib/features/tracker/screens/tracker_history_screen.dart`
- Focus: `lib/features/tracker/focus/focus_timer_screen.dart`
- Bad Habit: `lib/features/tracker/bad_habits/bad_habit_tracker_screen.dart`
- Sleep: `lib/features/tracker/sleep/sleep_tracker_screen.dart`
- Nutrition: `lib/features/tracker/nutrition/nutrition_tracker_screen.dart`
- Global Money Setup: `lib/features/tracker/money/global_money_setup_screen.dart`

Keep:

- Seed data files such as `screen_time_mock_data.dart` and `meditation_mock_data.dart`, documented as local seeded data.
- `money_system_mock_flows.dart` while active money flows still import it.

Needs cleanup:

- User-facing copy that says "mock" in money, screen time, tracker settings/history, hydration, fitness, and native setup screens.
- Empty native setup actions should update last-known local status instead of doing nothing.
- UPI labels should only appear as primary for India; enum/internal names can remain.

## Coach

Active main tab:

- `lib/features/coach/coach_tab.dart`

Active detail provider:

- `lib/features/coach/providers/coach_navigation_provider.dart`

Active detail screens:

- `CoachSessionHistoryScreen`, `CoachSettingsInlineScreen`, `CoachNewSessionScreen`, and `CoachPrivacyDataScreen` in `lib/features/coach/screens/coach_flow_screens.dart`

Keep:

- `coach_bottom_sheets.dart` only for the active input plus menu small flow.

Old/reference found:

- `lib/features/coach/screens/coach_sub_screens.dart`
- `lib/features/coach/screens/coach_sessions_list_screen.dart`
- `lib/features/coach/screens/coach_settings_screen.dart`
- Unused static menu/new-session methods inside `coach_bottom_sheets.dart`

Safe cleanup:

- Delete unused old Coach screen files.
- Trim unused static bottom-sheet methods.
- Replace user-facing "mock Coach session" copy with local-state wording.

## Goals

Active main tab:

- `lib/features/goals/goals_tab.dart`

Active detail provider:

- `lib/features/goals/providers/goals_navigation_provider.dart`

Active detail screens:

- `AddGoalInlineScreen`, `GoalDetailInlineScreen`, `WeeklyReviewInlineScreen`, `ArchivedGoalsScreen`, and `GoalsSettingsInlineScreen` in `lib/features/goals/screens/goals_flow_screens.dart`

Keep:

- `goals_flow_screens.dart`
- Goals tab widgets and overload protection widgets

Old/reference found:

- `lib/features/goals/screens/goals_sub_screens.dart`
- `lib/features/goals/screens/add_goal_screen.dart`
- `lib/features/goals/screens/goal_detail_screen.dart`
- `lib/features/goals/screens/goal_weekly_review_screen.dart`
- `lib/features/goals/screens/archived_goals_screen.dart` is a one-line re-export and is not imported.

Safe cleanup:

- Delete unused old Goals sheet files and barrel/re-export files.
- Wire no-op Goals card actions to active tab/detail paths.

## Profile

Active main tab:

- `lib/features/profile/profile_tab.dart`

Active detail provider:

- `lib/features/profile/providers/profile_navigation_provider.dart`

Active detail screens:

- Main implementations live in `lib/features/profile/screens/profile_control_screens.dart`
- Region/localization lives in `lib/features/profile/screens/region_localization_screen.dart`

Keep:

- `profile_display_name.dart`
- `profile_settings_provider.dart`
- `profile_settings_models.dart`
- `profile_header_card.dart`
- `profile_control_screens.dart` for now; it is large but active.

Old/reference found:

- Many one-line screen re-export files under `lib/features/profile/screens/` are unused from `lib/` and can be deleted later, but are low-risk clutter. Keep for now unless the cleanup needs stricter removal.

Needs cleanup:

- Ensure Profile remains summary-based.
- Haptic and Correct Spelling already toggle in place.
- Region/localization owns language/country/currency/units/payment.
- Connected services and permission statuses are last-known/native-pending and do not claim connection unless configured.

## Onboarding

Active flow:

- `lib/features/onboarding/onboarding_flow.dart`
- `lib/features/onboarding/steps/onboarding_steps.dart`

Known huge file:

- `lib/features/onboarding/steps/base_timeline_step.dart` is 3039 lines because it contains all Base Timeline step subflows: classes, work, eating, fixed routine, skin care, import review, shared block editors, meal estimates, and review UI.

Keep for now:

- `base_timeline_step.dart`; splitting it is risky during cleanup.
- `models/onboarding_draft.dart`; backend-ready model serialization is broad and tested.
- `repositories/onboarding_repositories.dart`; backend-ready Firestore repository boundaries.

Old/reference found:

- `repositories/onboarding_repository.dart` is an unused fake repository with overlapping names. Keep for now unless repository cleanup later confirms deletion is safe.

Needs cleanup:

- User-facing onboarding copy should not say "mock".
- Notification step no-op permission action should record local permission intent instead of doing nothing.

## Root And Reference Files

Root one-time scripts found:

- `fix_colors.py`
- `fix_feedback.py`
- `fix_harsh_borders.py`
- `fix_indicator.py`
- `fix_overflow.py`
- `fix_shadows.py`
- `fix_small_widgets.py`
- `fix_syntax.py`
- `make_liquid.py`
- `make_really_liquid.py`
- `refactor_theme.py`
- `replace_widgets.py`
- `style_fixes.py`

Cleanup result:

- Moved to `tools/one_time_migrations/`.
- Added `tools/one_time_migrations/README.md` warning not to run without review.

Reference-only folders:

- `reference_copied_old_frontend/`
- `scratch/`

Cleanup result:

- They are not imported by `lib/`.
- Moved under `tools/reference_archives/`.
- `analysis_options.yaml` excludes `tools/reference_archives/**` and `tools/one_time_migrations/**`.

## Huge Files

Documented future refactor candidates:

- `lib/features/onboarding/steps/base_timeline_step.dart`
- `lib/features/profile/screens/profile_control_screens.dart`
- `lib/models/onboarding_draft.dart`
- `lib/features/tracker/meditation/meditation_tracker_widgets.dart`
- `lib/features/tracker/fitness/widgets/fitness_center_widgets.dart`
- `lib/features/tracker/tracker_tab.dart`
- `lib/features/tracker/money/money_system_widgets.dart`
- `lib/state/app_state.dart`
- `lib/features/home/widgets/home_glass_widgets.dart`
- `lib/features/goals/widgets/goals_tab_widgets.dart`
- `lib/features/routine/sheets/add_routine_sheet.dart`

Decision: do not split these during final frontend cleanup unless a compile-safe extraction is obvious.

## Large Files To Refactor Later

Do not split these during the backend-readiness cleanup. They are active,
compile-safe files with broad imports, so refactoring them before backend work
would create avoidable route, provider, and UI risk.

- `lib/features/onboarding/steps/base_timeline_step.dart` - split into base timeline setup flows, shared editors, and import review helpers after backend contracts settle.
- `lib/features/profile/screens/profile_control_screens.dart` - split by Profile detail screen once repository persistence is wired.
- `lib/models/onboarding_draft.dart` - split draft submodels only after Firestore serialization tests are expanded.
- `lib/features/tracker/meditation/meditation_tracker_widgets.dart` - split meditation controls, session cards, and painters after tracker persistence lands.
- `lib/features/tracker/fitness/widgets/fitness_center_widgets.dart` - split cards, charts, and route preview widgets after native fitness service boundaries are real.
- `lib/features/tracker/tracker_tab.dart` - split tab sections after tracker repository providers replace local state.
- `lib/features/tracker/money/money_system_widgets.dart` - split money summary, history, and setup widgets after the money repository shape is final.
- `lib/state/app_state.dart` - break mock notifiers into feature state files during the backend provider migration.
- `lib/features/home/widgets/home_glass_widgets.dart` - split shared Home primitives once cross-feature widget reuse is stable.
- `lib/features/goals/widgets/goals_tab_widgets.dart` - split goals cards and review widgets after GoalRepository writes are active.
- `lib/features/routine/sheets/add_routine_sheet.dart` - split form sections after routine write validation moves into repository/service code.

## Backend Boundary

Fake/local state is still active and expected before backend:

- Auth: `auth_state.dart` + fake `AuthRepository`
- Home/Routine/Tracker/Goals/Coach/Profile: Riverpod local state and fake repositories
- Native services: `services/native/native_service_adapters.dart`
- Cloudflare clients: `services/cloudflare/cloudflare_clients.dart`

Backend replacement targets remain:

- AuthRepository fake -> FirebaseAuthRepository
- Profile/Routine/Tracker/Goals repositories -> Firestore
- Coach AI -> Cloudflare Worker
- R2 upload client -> signed upload flow
- Native services -> Android platform adapters
