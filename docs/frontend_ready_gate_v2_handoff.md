# Frontend Ready Gate v2 Handoff

This is the frontend-only handoff for backend development. It freezes the model
ownership boundaries and future Firestore path targets without connecting
Firebase, Cloudflare Workers, R2, native services, or paid APIs.

## Backend Mode

- Default backend mode remains fake/frontend development mode.
- UI state is still backed by fake repositories and Riverpod providers.
- Native services remain adapter-shaped stubs.
- Cloudflare Worker and R2 clients remain fake clients.

## Model Ownership

| Area | Frontend owner model/provider | Repository boundary | Future Firestore owner |
| --- | --- | --- | --- |
| Auth | `AuthState` | `AuthRepository` | Firebase Auth + `/users/{uid}` |
| Profile | `UserProfile` | `ProfileRepository` | `/users/{uid}/profile/main` |
| Region/localization | `RegionSettings` | `RegionSettingsRepository` | `/users/{uid}/settings/regionLocalization` |
| App preferences | Profile settings models | `ProfileRepository` / settings repos | `/users/{uid}/settings/*` |
| Permissions | `PermissionStatus` | `PermissionStatusRepository` | `/users/{uid}/settings/permissionStatus` |
| Connected services | connected service models | `ConnectedServicesRepository` | `/users/{uid}/settings/connectedServices` |
| Data control | data control models | `DataControlRepository` | `/users/{uid}/settings/dataControl` |
| Onboarding | `OnboardingDraft` | onboarding/auth repositories | `/users/{uid}/onboarding/draft` |
| Routine | `RoutineItem` | `RoutineRepository` | `/users/{uid}/routineItems/{itemId}` |
| Routine history | routine history rows/events | `RoutineHistoryRepository` | `/users/{uid}/routineHistory/{eventId}` |
| Habit systems | habit system models | `HabitSystemsRepository` | `/users/{uid}/habitSystems/{systemId}` |
| Tracker config/history | tracker state models | `TrackerRepository`, `TrackerHistoryRepository` | `/users/{uid}/tracker/*`, `/users/{uid}/trackerHistory/{eventId}` |
| Money | `MoneyGoal`, `SavingEntry` | `MoneyRepository` | `/users/{uid}/money/*` |
| Focus | focus session models | `FocusRepository` | `/users/{uid}/focusSessions/{sessionId}` |
| Bad habits | bad habit check-ins | `BadHabitRepository` | `/users/{uid}/badHabitCheckins/{habitId}` |
| Sleep | sleep logs | `SleepRepository` | `/users/{uid}/sleepLogs/{logId}` |
| Nutrition | nutrition logs | `NutritionRepository` | `/users/{uid}/nutritionLogs/{logId}` |
| Fitness | fitness session models | `FitnessRepository` | `/users/{uid}/fitnessSessions/{sessionId}` |
| Goals | goal models | `GoalRepository` | `/users/{uid}/goals/{goalId}` |
| Coach sessions | coach session models | `CoachSessionRepository` | `/users/{uid}/coach/sessions/{sessionId}` |
| Coach AI | coach request/response models | `CoachAiRepository` | Cloudflare Worker, no direct Flutter AI key |
| Home dashboard | `HomeDashboardState` | `HomeDashboardRepository` | `/users/{uid}/home/dashboard` |
| Mind notes | `MindNote` | `MindNoteRepository` | `/users/{uid}/mindNotes/{noteId}` |
| Notifications | `NotificationPreferences` | `NotificationPreferencesRepository` | `/users/{uid}/notifications/preferences/main` |

## Path Freeze

Use `FirestoreUserPaths` as the path baseline for the first backend pass. Any
future path change should be treated as a migration, not an incidental UI edit.

## Backend Start Order

1. Auth, profile, and region settings.
2. Onboarding persistence.
3. Routine, habit systems, and routine history.
4. Goals and daily proofs.
5. Tracker persistence.
6. Coach sessions and Cloudflare Worker AI.
7. Native Android services.
8. Cloudflare R2 upload/export.
9. Privacy and data deletion flows.
10. Production hardening.
