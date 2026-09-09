# Optivus Navigation Contract

Status: Phase 0 complete — navigation freeze

Source of truth: `lib/core/router/app_router.dart`, `lib/state/auth_state.dart`,
`lib/views/screens/app_shell.dart`, and the six feature navigation providers

## 1. Navigation overview

Optivus has one app-wide `GoRouter`. It owns the entry boundary for public
authentication, email verification, backend/profile/onboarding restoration,
onboarding, and the protected application shell.

- Welcome, Login, and Sign-up are public named routes.
- Verify Email is an authenticated route for password users whose address is
  not verified.
- `/loading` is the restoration boundary. It shows startup, backend/profile
  loading, onboarding-draft restoration, or a retryable restoration failure.
- Onboarding is a protected named route for verified users whose setup is not
  complete.
- `/app` is the protected six-tab shell for verified users whose setup is
  complete.
- Tabs are state-controlled views inside the shell, not six independent
  router routes.
- Significant feature detail paths are router entry points, but each redirects
  to `/app?tab=<index>` and sets an owner-feature detail request. The detail is
  then rendered inline by that tab.
- Feature-local dialogs and bottom sheets use Flutter modal navigation and are
  not global routes.
- Profile owns the confirmed logout entry and the account-deletion request
  entry. Verify Email also exposes a direct sign-out action.

`routerProvider` is the identifiable global source of route/access truth.
`AppNavigationController` owns only the current tab index, and each feature's
`*DetailViewRequestProvider` owns only a pending request for its inline detail.

## 2. Route and access matrix

| Destination | Path | Authentication required | Verified email required | Completed onboarding required | Actual navigation mechanism |
| --- | --- | ---: | ---: | ---: | --- |
| Welcome | `/` | No | No | No | `GoRoute`; public landing destination |
| Sign-up | `/signup` | No | No | No | `GoRoute`; `context.go` from Welcome/Login |
| Login | `/login` | No | No | No | `GoRoute`; `context.go` from Welcome/Sign-up |
| Verify email | `/verify-email` | Yes | No | No | Guard-enforced `GoRoute`; verified users are redirected away |
| Restore setup/startup | `/loading` | State may still be resolving | Enforced after resolution | No | Initial `GoRoute`; startup/restoration/retry boundary |
| Onboarding | `/onboarding` | Yes | Yes | No | Guard-enforced `GoRoute`; inline 15-page onboarding flow |
| Main application shell | `/app` | Yes | Yes | Yes | Protected `GoRoute`; optional `tab` query parameter selects initial tab |
| Home alias | `/home` | Yes | Yes | Yes | Route redirect to `/app` (Home index 0) |
| Application tabs | No separate tab paths | Yes | Yes | Yes | `AppNavigationController` plus `IndexedStack` |
| Feature detail views | Paths listed below | Yes | Yes | Yes | Route redirect sets an owner detail request, selects a tab, then lands on `/app?tab=n` |
| Logout from Profile | No route | Yes | No additional gate | No additional gate | `AlertDialog` confirmation, `AuthNotifier.logout()`, then `/` |
| Logout from Verify Email | No route | Yes | No | No | Direct action calls `AuthNotifier.logout()`; guard returns to `/` |
| Account deletion entry | `/profile/delete-account` or Profile > Data Control | Yes | Yes | Yes | Protected detail redirect to a Profile inline screen; current request is local/UI-only |

All feature detail routes inherit the shell's full authentication,
verification, and onboarding requirements. Hiding a button is not the access
control.

## 3. Redirect priority

The global redirect is driven exclusively by canonical `AuthState.sessionDestination`
resolved by `SessionDestinationResolver` and evaluated in `optivusAuthRedirect`:

1. **Resolving (`SessionDestinationKind.resolving`):** startup and backend/profile
   reconstruction are in flight. Public auth routes (`/`, `/login`, `/signup`)
   remain accessible while user is null to avoid flashing; all other paths are
   held at `/loading`.
2. **Signed out (`SessionDestinationKind.signedOut`):** only `/`, `/login`, and
   `/signup` are allowed. Every other path, including deep links, redirects to `/`.
3. **Signed in but email unverified (`SessionDestinationKind.verifyEmail`):**
   redirects to `/verify-email`.
4. **Onboarding in progress (`SessionDestinationKind.freshOnboarding` / `resumeOnboarding`):**
   redirects to `/onboarding`.
5. **Onboarding finishing (`SessionDestinationKind.finishOnboarding`):**
   redirects to `/onboarding/finishing`.
6. **Onboarding reconnect retryable failure (`SessionDestinationKind.reconnect`):**
   redirects to `/onboarding/reconnect`.
7. **Onboarding blocking action required (`SessionDestinationKind.needsAction`):**
   redirects to `/onboarding/needs-action` (not `/loading`).
8. **Home (`SessionDestinationKind.home`):** public auth routes, `/loading`,
   `/onboarding*`, and `/verify-email` redirect to `/app?tab=0`; the shell and
   protected detail routes are allowed.

`RouterNotifier` observes only `authProvider`. The router no longer directly
observes `userProfileProvider`, preventing double-hop redirections and race
conditions during session transitions.

The focused contract tests in `test/onboarding_routing_test.dart` and
`test/gate5_auth_session_isolation_test.dart` assert the visible destination for
signed-out, unverified, restoring, incomplete, complete, logout, and
protected-deep-link cases. The real asynchronous draft restore remains covered
in `test/onboarding_restore_test.dart`.

## 4. Tab navigation

The implementation order is authoritative:

| Index | Tab | Selected-tab method | Inline-detail request owner |
| ---: | --- | --- | --- |
| 0 | Home | `goToHome()` | `homeDetailViewRequestProvider` |
| 1 | Routine | `goToRoutine()` | `routineDetailViewRequestProvider` |
| 2 | Tracker | `goToTracker()` | `trackerDetailViewRequestProvider` |
| 3 | Coach | `goToCoach()` | `coachDetailViewRequestProvider` |
| 4 | Goals | `goToGoals()` | `goalsDetailViewRequestProvider` |
| 5 | Profile | `goToProfile()` | `profileDetailViewRequestProvider` |

Although product lists sometimes name Goals before Coach, the shipped shell
index is Coach 3 and Goals 4. Route query parameters and deep-link redirects
must follow the shipped index.

`appNavigationProvider` is a `StateNotifierProvider<AppNavigationController,
int>`. The bottom bar changes that integer. `AppShell` lazily creates each tab,
caches it, and displays the cache through `IndexedStack`, so loaded tab state
survives ordinary tab switching and inline detail presentation.

Tabs do not push routes. Each tab swaps its main view for an owner-controlled
detail. A detail header's back action clears the local active-detail state.
`PopScope` intercepts system back while a detail is active and closes the
detail first; from a tab's root, normal navigator/system behavior applies.

## 5. Detail navigation ownership

### Router-addressable inline details

| Owner | Protected entry paths | Opens as / returns by |
| --- | --- | --- |
| Home | `/home/mission` | Select Home, request Mission Detail, redirect to `/app?tab=0`; back clears the Home detail |
| Routine | `/routine/base-timeline`, `/routine/classes`, `/routine/work`, `/routine/eating`, `/routine/fixed`, `/routine/skin-care`, `/routine/import-review`, `/routine/settings`, `/routine/habit-systems`, `/routine/history` | Select Routine and set `RoutineDetailTarget`; header/system back clears the Routine detail |
| Tracker | `/tracker/money`, `/tracker/fitness`, `/tracker/screen-time`, `/tracker/meditation`, `/tracker/hydration`, `/tracker/settings`, `/tracker/activation`, `/tracker/history`, `/tracker/focus`, `/tracker/bad-habit`, `/tracker/sleep`, `/tracker/nutrition`, `/tracker/global-money-setup`, `/tracker/usage-access`, `/tracker/health-connect`, `/tracker/location-mapbox` | Select Tracker and set `TrackerDetailTarget`; detail back returns to Tracker root; Fitness also owns nested local session/detail/finish state |
| Coach | `/coach/history`, `/coach/settings`, `/coach/new-session`, `/coach/privacy-data` | Select Coach and set `CoachDetailView`; back clears the Coach detail |
| Goals | `/goals/add`, `/goals/detail`, `/goals/weekly-review`, `/goals/archived`, `/goals/settings` | Select Goals and set `GoalsDetailTarget`; back clears the Goals detail |
| Profile | `/profile/edit`, `/profile/system-setup`, `/profile/notifications`, `/profile/permissions`, `/profile/connected-services`, `/profile/preferences`, `/profile/region`, `/profile/privacy`, `/profile/data-control`, `/profile/export`, `/profile/delete-selected-data`, `/profile/delete-account`, `/profile/archived-identities`, `/profile/report-bug`, `/profile/help`, `/profile/about` | Select Profile and set `ProfileDetailTarget`; back clears the Profile detail |

Some owner details accept additional in-memory context that is not encoded in
the path, such as a Goal ID, Tracker type, bad-habit type, Profile permission,
connected service, or Routine import source. A bare deep link therefore opens
the supported default form of the detail unless the initiating feature passes
context through the target provider.

### Modal navigation

Routine editors/conflict actions, Home Mind and notification actions, Coach
actions/settings prompts, Tracker pickers/history/actions, and selected Profile
confirmations use `showModalBottomSheet` or `showDialog`. They close with
`Navigator.pop` or their supplied callback and do not create a new global path.
The Profile logout confirmation is one of these dialogs.

## 6. Logout and account deletion

### Logout

- **Profile entry:** Profile root > Log out opens an `AlertDialog` with Cancel
  and Log out. Confirmation closes the dialog, awaits
  `AuthNotifier.logout()`, and calls `context.go('/')`.
- **Verification entry:** Verify Email exposes a logout icon that calls
  `AuthNotifier.logout()` without the Profile confirmation dialog.
- **Destination:** the signed-out router guard allows the public Welcome route
  and blocks any retained protected location.
- **Repository action:** `AuthNotifier.logout()` calls the selected
  `AuthRepository.signOut()`.
- **Synchronous frontend reset:** `AuthNotifier.logout()` delegates directly to
  `AuthSessionResetCoordinator.resetIdentityBoundary()` to synchronously clear
  all user/session-scoped in-memory state across all feature domains (profile,
  onboarding draft, timeline models, upload controllers, home dashboard/notes,
  routine controller/projections, habit systems, tracker sessions/settings,
  fitness, coach, goals, notification preferences, permissions, liquid toasts,
  recovery retry, and navigation detail request states). The previous reset gap
  is fully closed by the centralized reset coordinator and verified by
  `test/gate5_auth_session_isolation_test.dart`.

### Account deletion

Account deletion starts at Profile > Data Control > Delete Account Request or
the protected `/profile/delete-account` entry path. The inline screen:

- describes the intended data scope;
- links to Export Data;
- uses a preview-only reauthentication checkbox;
- requires typing `DELETE` before enabling submission; and
- creates a local `DeletionRequestModel` with a seven-day cancellation
  deadline, which can also be cancelled locally.

This is **UI-only/local state**. It does not reauthenticate the Firebase user,
write an auditable backend request, delete Auth/Firestore/R2 data, or execute a
production deletion job. Production deletion is outside Phase 0.

## 7. Navigation rules

1. Protected destinations must never rely only on hidden buttons.
2. The router/auth-state guard enforces authentication, verification, restore,
   and onboarding access.
3. Email verification is enforced before onboarding.
4. Onboarding completion is enforced before the application shell.
5. Unknown or failed restoration displays `/loading`, never Onboarding or App.
6. Feature details inherit the protection level of the application shell.
7. Logout returns to a public authentication destination and must clear or
   invalidate all user-scoped frontend state.
8. Deep links pass through the same global redirect as ordinary navigation.
9. `routerProvider` is global route/access truth; tab and detail providers may
   not duplicate authentication or onboarding policy.
10. Feature widgets may own local detail/modal state but must not create
    unrelated global navigation state.
11. A new router-addressable detail must select its owning tab, use that
    feature's request type, and gain an access-regression test.
12. A modal remains feature-owned unless it needs stable external addressing;
    do not invent a path merely because a screen-shaped widget exists.
