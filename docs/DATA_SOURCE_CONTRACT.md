# Optivus Data-Source Contract

Status: Phase 0 complete — provenance vocabulary and inspected inventory

This document is the authoritative provenance vocabulary and current
capability inventory for Optivus. It describes the repository as inspected on
2026-07-22. The product blueprint describes product behavior and ownership;
this contract decides whether a user-visible value is **Live**, **Local**,
**Seeded**, or **Unavailable**.

## 1. Purpose

The contract prevents fake, seeded, local, or disconnected data from being
mistaken for durable production data. A screen, model, Firestore path, Worker,
or client can exist without the active production flow using it. Therefore,
implementation existence and production availability are recorded separately.

## 2. Status definitions

### Live

Use **Live** only when all applicable conditions are true:

- the active production flow uses the source;
- the data is durable or comes from a real connected system;
- records are owner-scoped where required;
- the data can restore after restart or another-device login where appropriate;
- production errors are surfaced truthfully;
- the feature does not silently fall back to seeded data; and
- any required remote deployment has been verified, or that verification is
  separately and explicitly recorded as pending.

For Optivus, a Firebase repository selected only by an optional build define or
a Worker URL present in source is not sufficient. No audited capability meets
all Live conditions at this inspection point.

### Local

Use **Local** when a capability is functional but its state remains in memory,
on the current device, in a fake repository, in a local provider, or otherwise
cannot restore after restart or another-device login. Every Local inventory row
states whether the source is in-memory, device-persisted, or session-only.

Optivus examples are Routine editing in `routineNotifierProvider`, manual
Tracker logs in `mockTrackerProvider`, and Goal interactions in
`mockGoalProvider`. These are in-memory/session-only, not device-persisted.

### Seeded

Use **Seeded** for predetermined examples, mock seed data, static dashboard
content, deterministic demonstration history, or placeholder insights, scores,
and summaries. Seeded values must not be presented as live production
intelligence.

Optivus examples are Home Now/Next and Coming Up, seeded screen-time apps,
Fitness history/insights, and deterministic Coach reply content.

### Unavailable

Use **Unavailable** when the UI exists but its integration is not connected, a
required permission/platform implementation does not exist, an external client
exists but the active flow does not use it, an operation is a placeholder, or
the required deployment has not been completed or verified.

Optivus examples are Health Connect ingestion, account deletion execution, the
inactive Coach Worker path, and private R2 bytes in the default fake upload
mode.

## 3. Source-of-truth rules

1. Every durable feature has one canonical source of truth.
2. Screens consume state through providers/controllers; providers/controllers
   use repositories or services.
3. Widgets do not call Firestore, Workers, R2, or native APIs directly.
4. Derived summaries name their canonical input records and do not become a
   second owner of those records.
5. Seeded data is never silently substituted after a production failure.
6. AI failure produces an actionable error or unavailable state, never
   fabricated output.
7. Local state is never described as cross-device, restart-safe, or durable.
8. A target Firestore path or repository class does not make a capability Live.
9. Production Firebase mode must not silently select a fake repository.
10. Client implementation and external deployment verification are recorded
    separately. A checked-in Worker configuration is not deployment evidence.
11. Cross-feature writes use an owner command with a stable identifier;
    retries must not create duplicate canonical records.
12. Production provenance failures fail closed. A release build must not
    present fake upload success, seeded intelligence, or fake authentication as
    real service behavior.

## 4. Detailed data-source inventory

Each row has exactly one primary status. Mixed surfaces are split into separate
rows. “Production path” means the path selected in a production build, not a
target that merely exists in source.

| Area | Surface or capability | Status | Current source | Active production path | Target source | Evidence | Production behavior/gap |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Authentication and Onboarding | Authentication | Local | Session-only `FakeAuthRepository` by default | `OPTIVUS_BACKEND` defaults to `fake`, including release; Firebase Auth is selected only by explicit `firebase` | Firebase Authentication | `lib/config/backend_config.dart`; `lib/state/auth_state.dart`; `lib/repositories/auth_repository.dart` | Fake sign-in creates local identities and cannot restore across process/device; release configuration is not fail-closed. |
| Authentication and Onboarding | Email verification | Local | Session-only fake verification state | Fake by default; Firebase verification exists only in explicit Firebase mode | Firebase Authentication verification | `FakeAuthRepository.reloadCurrentUser`; `FirebaseAuthRepository` | Default flow simulates verification locally; no deployment/config evidence qualifies it as Live. |
| Authentication and Onboarding | User profile | Local | In-memory fake profile/providers by default | `FirestoreProfileRepository` is conditional on explicit Firebase mode | Owner-scoped Firestore `users/{uid}/profile/main` | `lib/repositories/profile_repository.dart`; `lib/state/app_state.dart` | Configurable Firestore implementation exists, but default production selection is fake and cross-device behavior is unverified. |
| Authentication and Onboarding | Onboarding draft | Local | In-memory `FakeOnboardingRepository` | Firestore repository only when `OPTIVUS_BACKEND=firebase` | `users/{uid}/onboarding/draft` | `lib/repositories/onboarding_repository.dart` | Default draft disappears with the process; Firestore mode is configurable, not verified Live. |
| Authentication and Onboarding | Onboarding completion bundle | Local | In-memory fake bundle by default | Firestore bundle/profile batch only in explicit Firebase mode | Versioned owner-scoped completion bundle plus normalized feature projection | `FirestoreOnboardingRepository.completeOnboarding`; `lib/services/onboarding_completion_service.dart` | Current active Firestore implementation stores draft, bundle, and profile patch, not all normalized feature collections. |
| Authentication and Onboarding | Onboarding restoration | Local | Session-only bundle rehydration into local providers | Can read a Firestore bundle in explicit Firebase mode, then hydrates local feature owners | Durable feature repositories restored by owner | `lib/state/auth_state.dart`; `lib/services/onboarding_frontend_hydration_service.dart` | Restoration can repopulate local state, but duplicate Routine owners and incomplete logout invalidation prevent a Live classification. |
| Upload and Onboarding AI | Upload metadata | Local | In-memory `FakeUploadedAssetRepository` by default | Firestore metadata repository only in explicit Firebase mode | Owner-scoped Firestore `users/{uid}/uploads/{assetId}` | `lib/repositories/uploaded_asset_repository.dart`; `firestore.rules` | Strict rules exist for this collection, but the active default remains fake and deployment is not verified. |
| Upload and Onboarding AI | Private file bytes | Unavailable | Fake R2 client returns an `r2://fake-r2/...` URL and discards bytes | Default `OPTIVUS_UPLOAD_MODE=fake`; real client only for `r2` plus a Worker URL | Private R2 `optivus-uploads-*` through the upload Worker | `lib/config/upload_config.dart`; `lib/state/upload_state.dart`; `FakeR2UploadClient.uploadBytes` | Missing R2 URL in `r2` mode fails safely, but default fake mode can report completion without durable bytes. |
| Upload and Onboarding AI | Routine Import review records | Local | In-memory fake review repository by default | Firestore review repository only in explicit Firebase mode | `users/{uid}/routineImportReviews/{reviewId}` | `lib/repositories/routine_import_review_repository.dart`; `firestore.rules` | Owner/schema rules exist, but active default reviews are session-only. |
| Upload and Onboarding AI | Routine Import AI | Unavailable | Worker client exists; deterministic fake client is tests-only in the active provider | Release selects Worker and checked-in dev URL, but deployment/health is not verified | Verified Routine Import Worker | `lib/config/routine_import_ai_config.dart`; `lib/services/routine_import_ai_client.dart` | Missing configuration returns no candidates; client existence and a dev URL do not establish production availability. |
| Upload and Onboarding AI | Nutrition AI | Unavailable | Worker client exists; fake generation is gated to tests | Worker mode uses the Nutrition Worker URL; deployment/health is not verified | Verified Nutrition Worker | `lib/services/nutrition_ai_client.dart`; `lib/config/ai_workers_config.dart` | Missing configuration is safe/unavailable, but the remote production path is unverified. |
| Upload and Onboarding AI | Skin Care AI | Unavailable | Worker client exists; fake implementation is tests-only | Worker mode uses the Skin Care Worker URL; deployment/health is not verified | Verified Skin Care Worker with private R2 access | `lib/services/skin_care_ai_client.dart`; `workers/skin-care-worker/` | Missing/disabled configuration is unavailable; checked-in Worker tests/config are not deployment evidence. |
| Upload and Onboarding AI | Coach AI client availability | Unavailable | Worker and fake client classes exist | Release config selects Worker, but active Coach screens never call this provider | Verified Coach Worker used by active Coach controller | `lib/services/coach_ai_client.dart`; `lib/features/coach/coach_tab.dart` | The client is inactive in the user journey; non-Worker client selection also returns a fake reply. |
| Routine | Routine items | Local | In-memory `routineNotifierProvider` backed by `FakeRoutineRepository`; a second mock list also exists | No Firebase Routine repository is selected | `users/{uid}/routineItems/{itemId}` with one canonical owner | `lib/features/routine/routine_state.dart`; `lib/repositories/routine_repository.dart`; `lib/state/app_state.dart` | Items and status changes are not restart/cross-device durable and can diverge between owners. |
| Routine | Routine editing | Local | In-memory Routine notifier | Same fake repository path in release unless later implementation replaces it | Owner-scoped Firestore CRUD through the canonical Routine controller | `lib/features/routine/routine_state.dart`; `lib/repositories/routine_repository.dart` | Create/update/delete/move operations are functional but session-only. |
| Routine | Routine history | Local | In-memory `FakeRoutineHistoryRepository` | Provider always returns fake | `users/{uid}/routineHistory/{eventId}` | `lib/repositories/routine_history_repository.dart` | History disappears on restart; reserved path has no active repository. |
| Routine | Habit systems | Local | In-memory `FakeHabitSystemsRepository` and local feature state | Provider always returns fake | `users/{uid}/habitSystems/{systemId}` | `lib/repositories/routine_history_repository.dart`; `lib/repositories/habit_repository.dart` | Save/pause behavior is local and cannot restore across devices. |
| Routine | Onboarding-to-Routine projection | Local | Direct writes to both `mockRoutineProvider` and `routineNotifierProvider` | Firebase bundle can restore, but projection ends in local duplicate owners | Idempotent projection into one durable Routine repository | `lib/services/onboarding_frontend_hydration_service.dart` | Projection is not a single canonical durable command and duplicate ownership remains. |
| Goals | Goal definitions | Local | In-memory `mockGoalProvider`; fake repository is not the active screen owner | No owner-scoped Firebase Goal controller | `users/{uid}/goals/{goalId}` | `lib/features/goals/goals_tab.dart`; `lib/state/app_state.dart`; `lib/repositories/goal_repository.dart` | Create/edit actions work locally only; onboarding bundle restoration can seed the provider. |
| Goals | Identity systems | Local | In-memory Goal models/provider | Same local provider | Owner-scoped Goal records and derived identity projections | `MockGoalNotifier`; `lib/features/goals/screens/goals_flow_screens.dart` | Identity changes disappear after process loss unless recreated from the setup bundle. |
| Goals | Proofs | Local | In-memory daily-proof mutations | No durable proof/event repository active | Owner-scoped proof events with idempotent evidence links | `MockGoalNotifier.toggleGoalProofCompleted`; `FakeGoalRepository.saveDailyProof` | Proof completion and difficulty are session-only and not auditable. |
| Goals | Streaks | Local | Calculated/mutated from local proof state | No durable event source active | Derived from durable, dated proof events | `lib/state/app_state.dart`; `lib/features/goals/widgets/active_goal_card.dart` | Current streak changes are local and can be reset or diverge. |
| Goals | Milestones | Seeded | Hard-coded milestone rows and presentation copy | Same static rows appear in the active Goal details | Derived from durable goals/proofs | `lib/features/goals/screens/goals_flow_screens.dart`; `goals_tab_widgets.dart` | Values such as “Week 2” can look earned without canonical evidence. |
| Goals | Weekly reviews | Local | Summary derived from local goals; save action reports “saved locally” | No review repository | Owner-scoped weekly review records | `WeeklyReviewInlineScreen` in `goals_flow_screens.dart` | Review inputs/actions are functional only for the current process. |
| Goals | Archive/restore | Local | In-memory `MockGoalNotifier` / fake repository methods | No Firebase Goal repository active | Owner-scoped Goal archive state | `MockGoalNotifier.archiveGoal/restoreGoal`; `FakeGoalRepository` | Archive state is not restart or cross-device durable. |
| Tracker | Hydration manual logs | Local | In-memory `mockTrackerProvider.hydrationLogs` | No durable Tracker repository active | Owner-scoped hydration events | `lib/features/tracker/hydration/`; `lib/state/app_state.dart` | Manual add/clear works for the session only. |
| Tracker | Hydration streak/summary | Seeded | Hard-coded “5-day” presentation mixed with local total | Static streak remains in the active screen | Derived from durable hydration events | `hydration_tracker_screen.dart` | The streak can appear historical although no durable history exists. |
| Tracker | Focus | Local | In-memory timers/sessions and fake repository contract | No durable Focus repository selected | `users/{uid}/focusSessions/{sessionId}` | `lib/features/tracker/focus/`; `lib/repositories/tracker_repository.dart` | Sessions and derived progress are session-only. |
| Tracker | Money | Local | In-memory money goal and saving entries | Always-fake `MoneyRepository`; UI reads `mockTrackerProvider` | Owner-scoped money goals and saving entries | `lib/features/tracker/money/`; `lib/repositories/tracker_repository.dart` | Confirmed saves update local Home values but are not durable. |
| Tracker | Bad habits | Local | In-memory check-ins/sessions | Always-fake repository | Owner-scoped bad-habit events | `lib/state/app_state.dart`; `FakeBadHabitRepository` | Manual check-ins are not restart/cross-device durable. |
| Tracker | Sleep | Local | Manual local logs/state | Always-fake repository | `users/{uid}/sleepLogs/{logId}` plus approved Health Connect import | `FakeSleepRepository`; Tracker screens | Manual path works locally; automatic detection is unavailable. |
| Tracker | Nutrition manual logs | Local | Manual local logs/state | Always-fake repository | `users/{uid}/nutritionLogs/{logId}` | `FakeNutritionRepository`; Nutrition Tracker UI | Manual data is functional but session-only; AI is classified separately. |
| Tracker | Meditation manual sessions | Local | New sessions are appended to `mockTrackerProvider` | No durable Meditation repository | Owner-scoped meditation sessions | `meditation_tracker_screen.dart`; `MockTrackerNotifier.logMeditationSession` | User-started sessions remain in memory. |
| Tracker | Meditation catalog and recent history | Seeded | `meditation_mock_data.dart` constants | Active Meditation UI reads the constants | Static editorial catalog plus durable user session history | `lib/features/tracker/meditation/meditation_mock_data.dart` | Predetermined recent sessions can appear as user history. |
| Tracker | Fitness manual sessions | Local | Feature-local `fitnessCenterProvider`, with completion copied to `mockTrackerProvider` | No durable Fitness repository active | One owner-scoped Fitness session controller/repository | `lib/features/tracker/fitness/providers/fitness_provider.dart` | Functional sessions have two local owners and no durable restart path. |
| Tracker | Fitness history, insights, records, and routes | Seeded | `FitnessCenterState.mock()` | Active Fitness Center initializes from the mock factory | Durable Fitness events plus approved connected sources | `fitness_provider.dart` | Predetermined history/metrics/routes can look measured. |
| Tracker | Screen Time displayed data | Seeded | `MockSeedData.defaultScreenTimeApps` | Active Tracker and Focus screens consume seeded apps | Android Usage Access through an approved adapter | `lib/state/mock_seed_data.dart`; `lib/state/app_state.dart` | App usage and risk values are not real device measurements. |
| Tracker | Tracker history from user logs | Local | History screen derives entries from current in-memory Tracker state | No durable history repository active | `users/{uid}/trackerHistory/{eventId}` derived from canonical events | `tracker_history_screen.dart`; `FakeTrackerHistoryRepository` | Current-session logs can appear in history but disappear after restart. |
| Tracker | Built-in Tracker history rows | Seeded | Static sleep/focus/nutrition entries generated with relative dates | Active history always constructs these rows | No rows unless derived from durable user events | `TrackerHistoryScreen._buildEntries` | Predetermined history is presented alongside local user logs without provenance separation. |
| Tracker | Usage Access ingestion | Unavailable | Setup UI and fake native adapter only | No Android Usage Access implementation | Android UsageStats via approved native service | `lib/services/native/native_service_adapters.dart`; `usage_access_setup_screen.dart` | Screen-time automation and live permission state do not work. |
| Tracker | Health Connect ingestion | Unavailable | Setup UI and fake native adapter only | No Health Connect implementation | Android Health Connect through approved adapter | `native_service_adapters.dart`; Tracker activation UI | Sleep/fitness/health data cannot be imported. |
| Tracker | GPS/background fitness | Unavailable | Setup UI and fake location adapter only | No foreground/background location implementation | Permission-aware Android location service | `native_service_adapters.dart`; Fitness UI | Routes and background sessions cannot be recorded. |
| Tracker | Mapbox maps | Unavailable | Interface/setup copy only | No Mapbox SDK/configured map implementation | Mapbox, subject to the approved platform boundary | `native_service_adapters.dart`; Fitness screens | Map and route visualization cannot deliver intended behavior. |
| Coach | Active chat responses | Seeded | `mockCoachProvider` deterministic reply logic and fake typing delay | Active Coach tab always calls the mock notifier | Verified Coach Worker | `lib/features/coach/coach_tab.dart`; `lib/state/app_state.dart` | Replies can appear intelligent but are deterministic local demo output. |
| Coach | User-authored messages | Local | In-memory Coach session list | Active mock provider only | Owner-scoped Coach messages | `MockCoachNotifier.sendMessage`; `coach_tab.dart` | User messages disappear after process loss. |
| Coach | Sessions | Local | In-memory seeded/local `mockCoachProvider` | Always local in active screens; repository contract is fake | `users/{uid}/coach/sessions/{sessionId}` | `lib/repositories/coach_session_repository.dart`; `coach_tab.dart` | Sessions cannot restore across device and include seeded defaults. |
| Coach | Context permissions | Local | In-memory `mockCoachPreferencesProvider` | Preferences can be restored from setup bundle but are not enforced by active AI flow | Durable preferences enforced during server request assembly | `lib/state/app_state.dart`; `coach_flow_screens.dart` | Toggles are local configuration, not a verified privacy boundary. |
| Coach | Selected Mind Note sharing | Unavailable | Local note visibility toggles exist on duplicated Mind models | Active Coach does not assemble or enforce selected-note context | One durable Mind record with explicit grants consumed by Coach | `home_mind_note_provider.dart`; `mockMindNoteProvider`; `coach_tab.dart` | “Shared with Coach” does not cause a verified, owner-scoped Worker context transfer. |
| Home and Mind | Now/Next | Seeded | Static `HomeDashboardNotifier._initialMockState()` | Active Home reads seeded dashboard provider | Derived from durable Routine schedule/status | `lib/features/home/providers/home_dashboard_provider.dart` | Cycling only swaps predetermined states; it is not a live schedule. |
| Home and Mind | Today’s Mission base values | Seeded | Static mission counts, focus minutes, and avoided-habit values | Active Home reads seeded dashboard provider | Derived from durable Routine/Tracker/Goal events | `home_dashboard_provider.dart`; `home_tab.dart` | Values can look like measured daily progress. Money is split into a separate row. |
| Home and Mind | Today’s Mission money saved | Local | Derived from current `mockTrackerProvider.savingsEntries` | Same in-memory Tracker state | Derived from durable money saving entries | `HomeTab._confirmedMoneySavedToday` | It reflects local actions accurately for the session only. |
| Home and Mind | Coming Up | Seeded | Static class/gym/money entries | Active Home reads seeded list | Derived from durable Routine occurrences | `home_dashboard_provider.dart`; `ComingUpCard` | Predetermined schedule entries can be mistaken for the user’s calendar. |
| Home and Mind | Tracker previews except Money | Seeded | Static preview subtitles in dashboard seed | Active Home displays static values | Derived from durable Tracker records | `home_dashboard_provider.dart`; `tracker_preview_section.dart` | Meditation, Screen Time, hydration, smoking, workout, and focus values are not live. |
| Home and Mind | Money Tracker preview | Local | Derived from current in-memory confirmed savings | Active Home overrides the seeded subtitle for Money | Derived from durable saving entries | `TrackerPreviewSection._buildPreviewCard` | Correct for current local state, but not restart/cross-device durable. |
| Home and Mind | Insights | Seeded | Static `autoInsights` | Active Home displays the seeded list | Explainable derived insights over durable inputs | `home_dashboard_provider.dart`; `AutoInsightsCard` | “Instagram 3h 20m” is demonstration content, not measured intelligence. |
| Home and Mind | Coach tip | Seeded | Static Coach name/message | Active Home displays it | Derived from verified Coach output or explicit editorial content | `home_dashboard_provider.dart`; `CoachTipCard` | The tip is not generated from current user data. |
| Home and Mind | Mind Note CRUD | Local | In-memory `homeMindNoteProvider` | No durable Mind repository used by active UI | `users/{uid}/mindNotes/{noteId}` | `home_mind_note_provider.dart`; `home_repository.dart` | Add/share/delete works in the process only. |
| Home and Mind | Initial Mind Note | Seeded | A hard-coded developer-themed note in provider initialization | Appears in active Mind Timeline | No initial note, or visibly isolated demo content | `HomeMindNoteNotifier` constructor | The note can be mistaken for user-authored content. |
| Home and Mind | Mind Notebook | Local | Reads the same local Home Mind provider plus legacy duplicate paths | No durable repository active | One owner-scoped Mind Note repository/controller | `lib/features/home/`; `lib/state/app_state.dart` | Notebook changes are local and duplicated models/providers can diverge. |
| Home and Mind | Home aggregation | Unavailable | No active aggregator; seeded dashboard provider | `HomeDashboardRepository` is fake and not the active source | Derived/cache contract over durable Routine, Tracker, Goals, Coach, and Mind | `home_dashboard_provider.dart`; `home_repository.dart` | The product cannot yet compute a production Home dashboard. |
| Profile and System Controls | Profile settings | Local | In-memory provider/fake repository by default | Firestore implementation only in explicit Firebase mode | `users/{uid}/profile/main` | `profile_settings_provider.dart`; `profile_repository.dart` | Current default settings and privacy/control state do not restore across devices. |
| Profile and System Controls | Region/localization | Local | In-memory fake repository by default | Firestore implementation only in explicit Firebase mode | `users/{uid}/settings/regionLocalization` plus device locale inputs | `lib/repositories/region_settings_repository.dart` | Configurable durability exists, but active default remains local. |
| Profile and System Controls | App preferences | Local | In-memory fake repository by default | Firestore implementation only in explicit Firebase mode | `users/{uid}/settings/appPreferences` | `lib/repositories/app_preferences_repository.dart` | Configurable durability exists, but active default remains local. |
| Profile and System Controls | Profile photo | Unavailable | Upload purpose/model/rules exist; no verified end-to-end profile lifecycle | Default upload mode is fake and active Profile does not establish durable replacement/deletion | Private R2 bytes plus owner-scoped Firestore metadata/profile pointer | `uploaded_asset.dart`; `firestore.rules`; Profile screens | A complete upload, display, replace, restore, and delete flow is not verified. |
| Profile and System Controls | Notification preferences | Local | In-memory profile/mock notification providers | Setup bundle may persist preferences in Firebase mode, but active scheduling is separate and unavailable | Owner-scoped preference document | `notification_preferences_repository.dart`; `profile_settings_provider.dart` | Preference toggles are local in the default path and do not prove delivery. |
| Profile and System Controls | Notification delivery and OS scheduling | Unavailable | Setup UI and fake native adapter | No native permission/scheduling implementation | Android notification permission plus approved local scheduling/service | `native_service_adapters.dart`; notification screens | The app cannot deliver the configured reminders. |
| Profile and System Controls | Native permission status | Unavailable | Seeded “not connected/pending” rows and preview rechecks | All native adapters are fake/stubbed | Actual Android permission/service queries | `profile_repository.dart`; `profile_settings_provider.dart`; `native_service_adapters.dart` | UI explicitly shows last-known/pending status, not current OS truth. |
| Profile and System Controls | Connected-service status | Unavailable | Seeded status rows in fake repository/provider | No real health/usage/Mapbox/R2 status probe | Owner-safe service health/configuration checks | `ProfileSettingsStateSeed.services`; `FakeConnectedServicesRepository` | Status cards cannot verify real service availability. |
| Profile and System Controls | Export | Unavailable | Local request model and “generate preview” status mutation | No backend export job or durable artifact | Auditable export request/job with expiring private artifact | `ExportDataScreen`; `FakeDataControlRepository` | The UI can mark a preview ready without generating user data. |
| Profile and System Controls | Selected-data deletion | Unavailable | Local checkbox/confirmation flow | No durable deletion executor | Idempotent owner-scoped deletion job covering Firestore and R2 | `DeleteSelectedDataScreen`; `profile_settings_provider.dart` | Confirmation changes local state but does not delete canonical data. |
| Profile and System Controls | Account deletion | Unavailable | Local pending/cancellation model | No reauthentication-backed account/data deletion job | Auditable Firebase Auth, Firestore, and R2 deletion workflow | `DeleteAccountRequestScreen`; `FakeDataControlRepository` | The request is a local preview and does not delete the account or data. |
| Profile and System Controls | Bug reporting | Local | In-memory submitted-title list and success state | No backend issue/support transport | Privacy-safe support endpoint and durable receipt | `ReportBugScreen`; `ProfileSettingsNotifier.submitBugReport` | UI reports “submitted locally”; reports disappear with the process. |

Inventory totals: **0 Live**, **40 Local**, **14 Seeded**, and **18 Unavailable**
capabilities (72 total).

## 5. Summary matrix

| Feature | Current source | Target source |
| --- | --- | --- |
| Authentication | Default session-only fake repository; Firebase-capable by explicit configuration | Verified Firebase Authentication with fail-closed release configuration |
| Onboarding | In-memory draft/bundle by default; configurable Firestore draft/bundle/profile | Versioned owner-scoped setup records plus idempotent projection to canonical feature stores |
| Upload and AI | Local metadata/fake byte upload by default; Worker clients and dev configurations exist | Verified private R2/Firestore metadata and deployed authenticated Workers with safe unavailable states |
| Routine | In-memory/fake repository with duplicate providers | Owner-scoped Firestore behind one Routine controller |
| Goals | Local/seeded provider | Owner-scoped Firestore and durable proof/review events |
| Tracker | Local/seeded providers | Firestore and approved native services |
| Coach | Local UI behavior; production client not active | Worker and owner-scoped Firestore sessions/messages |
| Home | Seeded/local aggregation | Derived from durable feature collections, with an optional documented cache |
| Mind Notes | Local provider with a seeded initial note and duplicate model path | Owner-scoped Firestore behind one Home/Mind controller |
| Profile | Local by default; selected settings are Firebase-capable | Owner-scoped Firestore plus verified native/system services and auditable control jobs |

## 6. Environment behavior

### Mode selection and fallback

| Mode | Selector | Current behavior | Fallback and safety |
| --- | --- | --- | --- |
| Fake/development backend | `OPTIVUS_BACKEND=fake` (default) | Selects fake Auth, Onboarding, Profile, upload metadata, region, and app-preference repositories; most six-area repositories are always fake regardless | Explicit for development, but unsafe as an implicit release default because fake sign-in and local success can appear production-like. |
| Firebase backend | `OPTIVUS_BACKEND=firebase` | Initializes Firebase and selects implemented Firebase Auth/Profile/Onboarding/settings/upload-review paths | No silent fallback in these conditional providers, but selection, deployment, rules, restart, and cross-device behavior still require release verification. Most post-onboarding repositories remain fake even in this mode. |
| Fake upload | `OPTIVUS_UPLOAD_MODE=fake` (default) | Uses `FakeR2UploadClient`; metadata repository follows backend mode | Unsafe for production: it can return a successful fake object key while discarding file bytes. |
| R2 upload | `OPTIVUS_UPLOAD_MODE=r2` plus `OPTIVUS_R2_UPLOAD_WORKER_URL` | Uses signed-upload/complete/delete endpoints | A missing URL fails with an explicit configuration error. Worker deployment, bucket lifecycle, and end-to-end restore are pending verification. |
| General AI Worker | `OPTIVUS_AI_WORKERS_MODE=worker`; release forces Worker | Nutrition, Skin Care, and Coach clients can select Worker clients; Coach UI still bypasses its client | Nutrition/Skin Care fake outputs are tests-only and missing config fails unavailable. The separate Coach client can return fake outside Worker mode, and the active tab is seeded regardless. |
| Routine Import AI | `OPTIVUS_ROUTINE_IMPORT_AI_MODE`; release forces Worker | Worker client uses the configured Routine Import URL | Fake candidates are tests-only in the active provider; missing config returns an unavailable result. Deployment is not verified. |
| Disabled/misconfigured integration | `disabled`, missing URL, missing permission, or remote failure | Intended AI/upload clients return errors/unavailable in the inspected flows | Safe only where the active surface does not replace the failure with another seeded/local success. Home/Tracker/Coach can still display independent seeded content in a release build. |

### External implementation versus deployment verification

| External component | Checked-in implementation | Deployment verification status |
| --- | --- | --- |
| R2 Upload Worker | `/health`, `/v1/uploads/sign`, `/v1/uploads/complete`, `/v1/uploads/delete`; dev `UPLOAD_BUCKET` binding | Pending; source and `wrangler` configuration are not proof of an active production deployment. |
| Routine Import Worker | `/health`, `/v1/routine-import/extract`, `/v1/routine-import/classes`, `/v1/routine-import/work`, `/v1/routine-import/eating-photo`; dev `UPLOAD_BUCKET` binding | Pending. |
| Nutrition Worker | `/health`, `/v1/eating/generate-routine` | Pending. |
| Skin Care Worker | `/health`, `/v1/skin-care/products/analyze`, `/v1/skin-care/routine/generate`; dev `UPLOAD_BUCKET` binding | Pending. |
| Coach Worker | `/health`, `/v1/coach/reply` | Pending, and the active Coach tab does not use the client. |
| Firebase | Auth plus selected Firestore repository implementations and rules | Pending for a named production environment; default source selection remains fake. |

The checked-in R2 binding is `UPLOAD_BUCKET` and points to the development
bucket `optivus-uploads-dev` in the relevant Worker configurations. No secrets
are recorded here. Worker structured event names are present in the Skin Care
Worker, but the Flutter app has no analytics event contract, consent manager,
feature-flag system, or crash-reporting integration in the inspected source.

## 7. Rules for new development

Every new screen, card, metric, score, history row, or action must answer this
checklist in its implementation/review notes:

1. What canonical record or service owns the value?
2. What is its current status: Live, Local, Seeded, or Unavailable?
3. Is the value durable?
4. Can it restore after restart?
5. Can it restore on another device?
6. Is it derived from Live, Local, or Seeded inputs?
7. What does the UI do when the source is unavailable?
8. Can retries or repeated cross-feature delivery create duplicates?
9. Does production mode ever fall back to fake or seeded data?
10. Which single target phase makes it Live?

The answer must identify the provider/controller and repository/service. If no
canonical owner exists, the capability remains Local, Seeded, or Unavailable
and its gap is added to the technical-debt register.

## 8. Promotion criteria

### Seeded to Local

- User actions replace predetermined values for the classified capability.
- One local owner is defined and seeded records are removed or visibly isolated
  as demo content.
- Empty, loading, failure, and reset behavior are tested.
- Documentation states the exact local lifetime: in-memory, session-only, or
  device-persisted.

### Local to Live

- The production path actively selects the durable repository/connected
  service and cannot silently fall back to fake.
- Records are owner-scoped and security rules exist where required.
- Success, permission denial, remote failure, and retry/idempotency are tested.
- Restart restore and another-device restore are verified where appropriate.
- Any seed fallback is removed from production or visibly isolated.
- External deployment/configuration verification is recorded.

### Unavailable to Live

- The intended integration is implemented and used by the active UI flow.
- Required permission, deployment, secret binding, and service health are
  verified without exposing secrets.
- Safe failure/unavailable behavior and manual alternatives are tested.
- Persistence, security, restart/restore, and idempotency criteria are met where
  applicable.
- This inventory and the product blueprint are updated in the same change.

No capability is marked Live merely because a target implementation exists.
Promotion requires the active production path, verified persistence or
connected-service behavior, required security rules, success and failure
tests, applicable restart/restore tests, no silent seeded fallback, and updated
documentation.
