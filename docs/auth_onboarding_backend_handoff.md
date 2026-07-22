# Optivus Auth & Onboarding Backend Handoff

> **Historical snapshot — superseded 2026-07-22.** The statements below
> describe an earlier frontend-only Auth/Onboarding phase and are retained only
> for history. Do not use them as current implementation truth. Use the
> [product blueprint](OPTIVUS_PRODUCT_BLUEPRINT_AS_BUILT.md),
> [architecture](ARCHITECTURE.md),
> [data-source contract](DATA_SOURCE_CONTRACT.md), and
> [technical-debt register](TECHNICAL_DEBT.md) instead.

This document describes the current frontend-only auth and onboarding flow. It is backend-ready in shape, but no Firebase, Firestore, Cloudflare Worker, AI API, R2 upload, or real notification permission call is connected in this phase.

## Current Auth Architecture

- `AuthRepository` defines login, signup, logout, password reset, and auth-state stream contracts.
- `FakeAuthRepository` simulates local auth with artificial delay.
- `AuthNotifier` awaits fake auth, exposes `AuthState.isLoading`, and resets or seeds mock app state.
- Normal login/signup creates an empty profile, empty onboarding draft, and empty mock app slate.
- The dev account `test@optivus.dev` / `test1234` intentionally loads `MockSeedData`.
- Logout resets user profile, onboarding, routine, tracker, goals, mind notes, coach sessions/preferences, notifications, and permission mock state.

## Onboarding Source Of Truth

`OnboardingDraft` is the backend-facing draft source of truth.

It stores:
- `uid`
- `currentStep`
- `stepCompleted`
- `stepDirty`
- `stepLoading`
- `createdAt`
- `updatedAt`
- all step payloads
- `finalPreview`
- `onboardingCompleted`

`OnboardingState` remains a UI wrapper for validation messages and compatibility, but its progress arrays are synchronized from the draft.

## Completion Bundle

`OnboardingCompletionService.buildBundle(draft)` creates an `OnboardingCompletionBundle` with:

- `userProfilePatch`
- `baseTimelineBlocks`
- `finalTimelineItems`
- `routineItemsForApp`
- `goodHabitTemplates`
- `badHabitCheckIns`
- `identityGoalSystems`
- `notificationPreferences`
- `coachPreferences`
- `moneyGoal`
- `warnings`
- `duplicateSystemKeysMerged`

The final Step 11 CTA validates required data, saves the final preview, builds this bundle, applies it to mock app state, marks onboarding complete, and routes to `/app?tab=0`.

## Mock App Wiring

After onboarding completion:

- `mockUserProfileProvider` receives role, lifestyle, body basics, coach, slip-up, and onboarding completion fields.
- `mockRoutineProvider` is replaced with generated `RoutineItem` data from the final timeline.
- `mockGoalProvider` is replaced with generated identity goal systems.
- `mockTrackerProvider` receives bad-habit check-in tracker sessions and a money goal when selected.
- `mockCoachPreferencesProvider` and `mockNotificationPreferencesProvider` receive onboarding preferences.

Home and Routine read `mockRoutineProvider`, so generated onboarding data is visible there after completion.

**Home/Routine Readiness Status: PASS**

## Next Phases
- The core onboarding data models and repositories (auth, onboarding, user profile, routine, habit, goal, notification preferences) are integrated and complete on the frontend side.
- Real backend integration can start using the `fake_..._repository` implementations as the contract baseline.
- Real Firebase Auth should be connected via `FirebaseAuthRepository`.

## Future Firestore Target Paths

Documented only. Not connected in this frontend-only phase.

- `/users/{uid}`
- `/users/{uid}/onboarding/draft`
- `/users/{uid}/routine/current`
- `/users/{uid}/habits/{habitId}`
- `/users/{uid}/goals/{goalId}`
- `/users/{uid}/notification_preferences/main`

## Future Backend Notes

When Firebase is intentionally enabled later:

1. Implement a real `FirebaseAuthRepository` behind the existing `AuthRepository` interface.
2. On auth success, fetch `/users/{uid}` and `/users/{uid}/onboarding/draft`.
3. Save local draft updates to `/users/{uid}/onboarding/draft`.
4. On completion, persist the completion bundle to the documented paths.
5. Keep AI and upload flows behind Cloudflare Workers/R2 signed URL patterns. Do not put API keys or R2 secrets in Flutter.

## Frontend-Only Limitations

- No Firebase Auth call is made.
- No Firestore read/write is made.
- No Cloudflare Worker request is made.
- No AI request is made.
- No upload or R2 signed URL flow is made.
- No real notification permission is requested.
- Placeholder import entries are stored locally in the onboarding draft for future text/photo review flows.
