# Project: Optivus Onboarding & System Stabilization

## Architecture
Optivus uses a layered Flutter architecture:
`UI (Screens/Widgets) → State Management (Riverpod Providers/Controllers) → Application Services → Repositories / Firebase (Firestore, Auth)`

Key Architectural Areas:
1. **App Bootstrap & Router**: State-driven routing via GoRouter based on Auth & Onboarding completeness state.
2. **Onboarding Pipeline & Completion Jobs**: Durable, idempotent multi-stage completion job stored in `/users/{uid}/onboardingCompletionJobs/current`.
3. **Routine Projection & History**: Reconciliation of routine completion bundles, draft profiles, routine templates, and history projections.
4. **Habit System Projection**: Reconciliation, hydration, and batch result handling (`HabitSystemProjectionResult`).
5. **Auth & Profile Lifecycle**: Typed failures, server timestamps, separate signup/email verification, single navigation authority.
6. **Domain Modules**: Skin-Care AI Engine, Meal Schedule Validation, Class Timetable Validation.
7. **Recovery UI & Error Presentation**: Responsive recovery scaffold with explicit user actions.

## Milestones

| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 0 | Baseline R6 | Git snapshot, baseline formatting, analyzer, tests, initial report | none | DONE |
| 1 | Group A | Onboarding completion truth (Issues 1–6) | M0 | DONE |
| 2 | Group B | Routine projection and History correctness (Issues 7–11) | M1 | DONE |
| 3 | Group C | Habit System projection and hydration (Issues 12–15) | M1, M2 | DONE |
| 4 | Group D | Authentication and account lifecycle (Issues 16–21) | M1 | DONE |
| 5 | Group E | Skin-care generation and safety consistency (Issues 22–28) | M1 | DONE |
| 6 | Group F | Meal onboarding validation (Issues 29–30) | M1 | DONE |
| 7 | Group G | Class timetable validation (Issues 31–32) | M1 | DONE |
| 8 | Group H | Recovery-screen UI (Issues 33–42) | M1, M2, M3, M4 | DONE |
| 9 | Group I | Onboarding-wide UI/UX consistency (Issues 43–55) | M1–M8 | PLANNED |
| 10 | Group J | Performance, logging, privacy, platform maintenance (Issues 56–62) | M1–M9 | PLANNED |
| 11 | Group K | Missing automated tests (Issues 63–68) | M1–M10 | PLANNED |
| 12 | Release Gate | 13-step Release Gate Loop (2 consecutive passes) | M1–M11 | PLANNED |

## Interface Contracts
### Onboarding Completion ↔ Router
- `onboardingInputCompleted`: boolean (user finished input steps)
- `onboardingProjectionStatus`: `pending` | `partial` | `completed` | `failed`
- `onboardingCompleted`: boolean (true only when full release invariant is satisfied)

### Routine Projection ↔ Habit System Projection
- Unified completion job aggregates both Routine templates, Routine History, and Habit Systems.

## Code Layout
- `lib/app/`: Bootstrap, router, global providers
- `lib/core/`: Common utilities, theme tokens, canonical widgets, typed errors
- `lib/features/auth/`: Authentication controllers, services, repositories
- `lib/features/onboarding/`: Onboarding flow UI, completion jobs, projection controllers
- `lib/features/routines/`: Routine templates, projection receipts, history projection
- `lib/features/habits/`: Habit system models, repositories, projection logic
- `lib/features/skincare/`: Skincare generation, safety metadata, worker/scheduler interop
- `lib/features/meals/`: Meal timetable validation, schedule density validation
- `lib/features/classes/`: Class timetable validation and review UI
- `lib/features/recovery/`: System recovery screen, scaffold, typed recovery actions
