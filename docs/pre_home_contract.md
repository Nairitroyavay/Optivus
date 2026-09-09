# Pre-Home Contract

> **Phase 3 stabilization input.** This contract remains useful for limiting
> Home work, but it is subordinate to the current
> [product blueprint](OPTIVUS_PRODUCT_BLUEPRINT_AS_BUILT.md),
> [architecture](ARCHITECTURE.md), and
> [data-source contract](DATA_SOURCE_CONTRACT.md). If a statement conflicts,
> the Phase 0 authoritative documents win.

Phase 1 through Phase 2D are stabilization inputs for Home. This document marks the boundary before Phase 3 Home work starts.

## Home Can Read Now

- Auth/profile frontend state for the display name:
  - `authProvider`
  - `userProfileProvider`
- Region settings for formatting money:
  - `regionSettingsProvider`
- Local/static dashboard state:
  - `homeDashboardProvider`
- Local tracker state currently used by Home money check-ins and tracker preview cards:
  - `mockTrackerProvider`
- Local goals state only inside the mission detail screen:
  - `mockGoalProvider`
- Local Home mind notes:
  - `homeMindNoteProvider`

## Still Fake Or Local

- `homeDashboardProvider` is static seeded dashboard state, not backend aggregation.
- `HomeDashboardRepository` and `MindNoteRepository` are fake in-memory repositories.
- Tracker preview data is static except money totals read from `mockTrackerProvider`.
- Goal progress and identity proof are local frontend state from `mockGoalProvider`.
- Coach copy in Home is static `CoachTip` data from the dashboard seed.
- Home does not read production Routine, Tracker, Goals, Coach, or Mind backend collections yet.

## Required Before Production Home

- Explicit Home backend aggregation contract and Firestore rules.
- Production Routine backend contract before Home depends on routine-derived now/next, completion, or coming-up state.
- Production Tracker backend contract before Home depends on health, focus, money, screen-time, hydration, or habit metrics.
- Production Goals backend contract before Home depends on identity proof and progress.
- Production Coach backend contract before Home depends on generated tips, context permissions, or shared notes.

## Phase 3 Home Is Allowed To Do

- Aggregate currently hydrated frontend/local state for a Home preview.
- Read onboarding completion hydration output after login.
- Read restored Routine import items after accepted/partially accepted reviews.
- Keep fake mode and Firebase mode available.
- Avoid claiming production Home completeness until Routine, Tracker, Goals, Coach, and Home rules are explicit.

Phase 3 Home must not implement full Routine, Tracker, Goals, Coach, payments, Mapbox, Health Connect, Usage Access, Firebase Storage, or Firebase Functions.
