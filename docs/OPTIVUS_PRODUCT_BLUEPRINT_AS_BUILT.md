# Optivus Product Blueprint — As Built

Status date: 2026-09-05

Inspection baseline: `main` at
`481601ccb5174478cde6bc4ac5494560b94eb306`, plus the documented final
pre-Routine closure working tree

Phase status: **Auth and Onboarding 0-14 source/code frozen**; Step 7 frozen
and regression-only; next product engineering phase is **Routine Production
Closure**. Remote staging/device gates remain open and no capability is
promoted to Live by this local automated gate.

Product: Optivus 1.0.0+1

## 1. Purpose of this document

This is the current, development-aligned blueprint for Optivus. It supersedes
the old pasted product blueprint when a product description conflicts with the
code that exists today.

The old blueprint remains useful as long-term product vision. This document is
the source of truth for:

- screens and flows currently present in the Flutter app;
- onboarding data and validation rules;
- cross-feature behavior that is actually wired;
- backend and AI integrations that can be enabled by configuration;
- frontend/local demonstrations that are not production-connected yet; and
- the remaining work before the product can be called production-ready.

## 2. Status language

Every feature in this blueprint uses one of these statuses:

| Status | Meaning |
| --- | --- |
| **Implemented** | The user-facing flow and its active state transition exist. |
| **Configurable integration** | A real client/repository exists, but it requires build-time configuration, secrets, deployed services, or Firebase mode. |
| **Local/seeded** | The UI works with Riverpod, in-memory repositories, static dashboard data, or deterministic demo data. It is not durable production data. |
| **Scaffolded** | Models, repository interfaces, routes, or screens exist, but the complete real workflow is not connected. |
| **Pending** | The old blueprint describes the behavior, but active development does not yet provide it. |

For provenance decisions, the authoritative four-status vocabulary and
capability inventory are in the
[data-source contract](DATA_SOURCE_CONTRACT.md). “Configurable integration” in
this blueprint does not mean **Live** unless that contract's production and
deployment gates are satisfied.

## 3. Product definition

Optivus is an AI-assisted life operating system built around six user-facing
areas:

1. **Home** — the daily command center.
2. **Routine** — the full day/week timeline and schedule control center.
3. **Tracker** — measurement, timers, check-ins, sessions, and history.
4. **Coach** — session-based support and action suggestions.
5. **Goals** — identity goals, systems, proofs, health, and reviews.
6. **Profile** — account and system control.

The implemented onboarding creates the user's starter system. It does not just
collect profile answers: it builds a completion bundle containing profile data,
timeline blocks, routine items, habit templates, bad-habit check-ins, identity
goals, coach preferences, notification preferences, money setup, upload
references, and warnings.

### 3.1 Application-area ownership freeze

The six application areas below are the product ownership boundary. “Owns”
means the area defines the canonical record and the commands that change it.
Another area may navigate to it, consume a derived view, or request an explicit
command, but must not create a competing source of truth.

| Area | Owns | Does not own | Current data-source status |
| --- | --- | --- | --- |
| **Home** | Concise daily summary, Now/Next, Today's Mission, Coming Up, Mind Timeline, Mind Notes/Notebook, and derived cross-feature insights | Routine schedules, Tracker measurements/sessions, Goal records, or Coach conversations | **Production Live:** none. **Local/in-memory:** active Mind Note UI and selected money values. **Seeded/demo:** most dashboard values and insights. **Pending/unavailable:** durable Mind Notes and the production aggregation contract. |
| **Routine** | Schedules, timeline and base-timeline items, movement/editing, conflicts, habit-system scheduling, occurrence status/history, and Tracker launch requests | Tracker measurement/session records, Goal meaning/proofs, or Home summaries | **Production Live:** none. **Configurable Firebase:** canonical templates, dated occurrences, transaction writes, Habit Systems, and atomic onboarding projection/receipt. **Local/in-memory:** the same owners through fake repositories. **Seeded/demo:** fake-only compatibility data. **Pending/unavailable:** full Routine production UX, deployed/device/cross-device acceptance, and the older overlapping `habitRepositoryProvider`. |
| **Tracker** | Measurements, timers, sessions, health/behavior logs, money, focus, hydration, sleep, nutrition, meditation, fitness, bad-habit tracking, history, and connected/native ingestion | Routine schedules or occurrence policy; identity/Goal definitions | **Production Live:** none. **Local/in-memory:** manual actions in `mockTrackerProvider`; Fitness has additional feature-local state. **Seeded/demo:** screen-time, meditation, Fitness history/metrics, and some tracker summaries. **Pending/unavailable:** durable sessions/history and native Usage Access, Health Connect, GPS, and Mapbox ingestion. |
| **Goals** | Identities, goals, systems, milestones, proofs, streaks, weekly reviews, progress history, archive, and restore | Routine scheduling or Tracker session records | **Production Live:** none. **Local/in-memory:** goal/proof/archive interactions in `mockGoalProvider`. **Seeded/demo:** sample goals and calculated presentation values where loaded. **Pending/unavailable:** durable proofs, reviews, milestones, evidence consumption, and progress aggregation. |
| **Coach** | Conversation sessions/messages, advice, explanations, suggestions, recovery guidance, and explicitly permitted context assembly | Silent writes to Routine, Tracker, Goals, Home/Mind, Profile, or any Mind Note that was not explicitly shared | **Production Live:** none. **Local/in-memory:** `mockCoachProvider` sessions and messages. **Seeded/demo:** local reply content. **Pending/unavailable:** active `CoachAiClient` wiring, durable sessions/messages, and enforced context grants. |
| **Profile** | Account/profile information, preferences, permissions, connected-service status, privacy/security, export, selected-data deletion, account deletion, and application/system settings | Routine schedules, Tracker records, Goals, Coach sessions, or Home/Mind content; Profile links to the owning area for those changes | **Production Live:** none under the verified-deployment standard. **Configurable Firestore:** profile, settings, region/localization, and app preferences in Firebase mode. **Local/in-memory:** permission/service/privacy/control state and request previews. **Seeded/demo:** default status rows. **Pending/unavailable:** native status, durable connected-service state, export/deletion execution, and verified profile-photo lifecycle. |

### 3.2 Entry and setup flows

Authentication and Onboarding are not additional main application areas.
Authentication owns identity/session entry and route gating. Onboarding owns a
versioned setup draft and completion snapshot, then projects accepted starter
data into feature-owned stores. The completion bundle is bootstrap input, not a
second live database for Routine, Tracker, Goals, Coach, or Profile.

## 4. Current application architecture

### 4.1 Client

- Flutter application using Dart 3.11.5.
- Riverpod is the active state-management layer.
- `go_router` owns top-level auth and app routing.
- The signed-in app uses a six-tab `IndexedStack`, preserving tab state.
- Each tab owns its inline detail screens and Android-back behavior.
- Visual language is liquid glass, rounded cards, tinted gradients, and a
  floating tab bar.

### 4.2 Runtime modes

`OPTIVUS_APP_ENV` names the runtime environment:

- `development` — default; intentional local/fake modes remain available.
- `staging` — requires fail-closed live integrations.
- `production` — requires fail-closed live integrations and rejects
  development/staging Worker URLs.

The main backend mode is selected with `OPTIVUS_BACKEND`:

- `fake` — default; in-memory auth/repositories and local frontend state.
- `firebase` — initializes Firebase and enables the implemented Firebase Auth
  and Firestore-backed profile/onboarding paths.

Every release build, plus explicitly named staging/production builds, validates
configuration before Firebase initialization. Startup fails unless backend is
Firebase, upload is R2, both AI modes are Worker, all five Worker URLs are
explicit HTTPS URLs valid for the named environment, and
`OPTIVUS_FIREBASE_PROJECT_ID` matches generated Android Firebase options.

AI and upload capabilities use separate build-time settings:

- `OPTIVUS_AI_WORKERS_MODE`: `worker`, `fake`, or `disabled`.
- `OPTIVUS_ROUTINE_IMPORT_AI_MODE`: `worker`, `fake`, or `disabled`.
- `OPTIVUS_UPLOAD_MODE`: `r2`, `fake`, or `disabled`.
- Worker URLs are supplied independently for Coach, Nutrition, Skin Care,
  Routine Import, and R2 Upload.

Staging, production, and release builds force both AI client modes to Worker.
A missing/unsafe Worker URL must fail startup or be treated as unavailable
configuration, never as permission to invent AI results.

### 4.3 Current persistence boundary

**Firebase-capable now:**

- email/password authentication;
- email verification;
- user profile;
- profile settings;
- region/localization settings;
- app preferences;
- onboarding draft;
- onboarding completion bundle;
- upload metadata;
- routine-import review metadata; and
- canonical Routine templates, dated occurrence/history records, and initial
  onboarding-to-Routine projection receipts; and
- receipt-verified loading of saved canonical Routine data.

**Still fake/local in the active repositories:**

- Routine habit systems;
- Tracker data and history;
- Focus, bad-habit, sleep, nutrition, fitness, and money repositories;
- Goals;
- Coach sessions and Coach chat state;
- Home dashboard aggregation and Mind Notes;
- notification delivery;
- permission status and native data-source status;
- connected-services state; and
- export/deletion execution.

This distinction is mandatory in product copy and QA. A visible screen is not
evidence of durable backend behavior.

## 5. Authentication and route gate

### 5.1 Active screens

- Welcome
- Log in
- Sign up
- Verify email
- Loading/restore
- Onboarding
- Signed-in app shell

### 5.2 Implemented routing contract

1. While auth or backend restore is running, route to `/loading`.
2. Signed-out users can only use Welcome, Login, and Signup.
3. Password users with an unverified email are held on Verify Email.
4. Verified signed-in users with incomplete onboarding are held on Onboarding.
5. Users with completed onboarding enter `/app?tab=0`.
6. Deep links select the correct app tab and then open the tab's inline detail
   screen.

### 5.3 Auth status

- **Fake mode:** implemented for development, including the seeded
  `test@optivus.dev` development account.
- **Firebase mode:** implemented for email/password sign-up, sign-in, sign-out,
  password reset, verification email, verification refresh, auth-state restore,
  and friendly error mapping.
- **Pending:** social sign-in providers and production account recovery beyond
  the current email reset flow.

## 6. Onboarding — current 15-page flow

The current `OnboardingDraft` data schema is version 3 and the product contains
15 top-level pages, indexed 0–14. Data-schema version and page-layout topology
are separate contracts: schema-v2 documents can already use the current
15-page layout. A document-level layout detector migrates only drafts with
evidence of the historical 12-page topology; current and ambiguous partial
vectors keep current numeric meaning and are safely padded before resume
validation.

The page is not swipe-navigable. The bottom CTA saves/validates the current
page before progressing. Completed pages may be revisited through the progress
indicator, while forward skipping is blocked if earlier work is incomplete or
dirty.

### Page 0 — Welcome

**Purpose:** introduce Optivus.

**Current content:**

- OPTIVUS
- “Biological routine scheduler & focus sandbox”
- “Welcome to Optivus”
- “Your AI Life Operating System”
- description of adaptive task, goal, and health organization
- CTA: **Get Started**

**Saved output:** `welcomeSaved`.

### Page 1 — Patience Pledge

**Purpose:** establish the tiny-step and recovery mindset.

**Current content:** “The Spike vs. Compound Rule” and a Patience Pledge to
start small, pivot schedules instead of abandoning them, and allow the nervous
system time to adapt.

**Required:** the user must accept the pledge.

**Saved output:** `patiencePledgeAccepted` and the pledge text.

### Page 2 — Role and lifestyle

**Purpose:** determine which timeline sections are required and collect the
minimum lifestyle context used by later setup.

**Life roles:**

| Role | Classes | Work | Additional required answer |
| --- | --- | --- | --- |
| Student / School / College | Enabled | Disabled | None |
| Working Person | Disabled | Enabled | Work type |
| Student + Working Person | Enabled | Enabled | Work type |
| Business / Startup / Freelancer | Disabled | Enabled as work/business | Business schedule |
| Not Student + Not Working | Disabled | Disabled | None |

**Work types:** Full-time, Part-time, Shift work, Remote work, Hybrid.

**Business schedules:** Fixed hours, Flexible work, Mixed.

**Lifestyle inputs:**

- Exercise: Rarely, 1–2 days/week, 3–4 days/week, 5+ days/week.
- Water intake: Low, Medium, High.
- Stress: Low, Medium, High.
- Sleep quality: Poor, Okay, Good.

Changing role invalidates irrelevant class/work data, clears incompatible
business configuration, removes invalid downstream completion, and shows role
change warnings.

### Page 3 — Body Basics

**Purpose:** collect the body context used by nutrition estimates.

**Inputs:**

- gender: Male, Female, Non-binary, Prefer not to say;
- age: `<18`, `18–24`, `25–34`, `35–44`, `45+`;
- height in centimetres or feet/inches; and
- weight in kilograms or pounds.

**Current estimates:**

- BMI = weight / height²;
- calories = weight × 24 × 1.3; and
- protein = weight × 2.

These are simple product estimates, not a medical assessment.

### Page 4 — Classes & Job

**Purpose:** create the role-required class and/or work schedule.

**Role behavior:**

- Student: class timetable required.
- Working: work schedule required.
- Student + Working: both photos/schedules required.
- Business: work/business schedule required.
- Not Student + Not Working: page shows that no class/work schedule is needed.

**Implemented flow:**

- show a focused setup screen for the role-required timetable image or images;
- persist upload metadata and private R2 object references when configured;
- tap Generate to enter an internal AI review screen;
- show `AiThinkingCard` while Routine Import AI reads the current source;
- convert safe timed candidates into class/work schedule blocks;
- display weekday chips and a weekly, minute-based timeline for review;
- allow block edits and day selection;
- require all role-required sections before continuing; and
- allow an existing saved schedule to be explicitly replaced.

For **Not Student + Not Working**, no upload target, photo, AI run, or timeline
review is required. The page shows that no class/work schedule is needed and
the normal primary CTA can advance to Eating Setup.

Regeneration preserves the previous valid same-source schedule until a
replacement succeeds. Failed or cancelled rebuilds leave the old timeline
visible with a compact retained-schedule error; replacing/removing a source
still invalidates the source-dependent blocks and cannot resurrect stale data.

AI output never directly becomes production Routine data. It must pass Worker
validation, Flutter mapping/validation, timeline review, and user confirmation.

**Status:** implemented with fake or configurable R2/Worker paths.

### Page 5 — Eating Setup

**Purpose:** create a weekly eating timeline with meal details.

**Paths:**

1. **Yes, I have a routine/menu** — upload a meal timetable/menu and generate
   meal candidates.
2. **No, help me create one** — generate a routine from body basics and meal
   preferences.

**Generation inputs:**

- goal: Gain, Lose, Maintain;
- meals per day: 3, 4, or 5;
- style: India, US, Germany, Mixed, Custom;
- food type: Veg, Non-veg, Mixed; and
- meal times for the selected meal count.

**Output:** confirmed `eating` timeline blocks with meal category, dishes,
calorie estimate, protein estimate, repeat days, and AI/import source.

**Implemented flow:** choice → setup → Generate → internal AI review →
weekday chips and timeline review. Internal Back returns AI/review to setup,
and View current meal routine returns to the retained timeline without running
AI. Photo-based extraction is fenced by account, auth generation, asset
identity, local request generation, and current review context; late cancelled
same-photo operations cannot mutate the current routine or interfere with a
new operation. Failed photo or create rebuilds retain the previous routine and
show a compact error.

**Status:** Nutrition Worker client is actively used by this page when its URL
is configured. Fake deterministic AI is test-only; missing configuration must
show an unavailable/error state.

### Page 6 — Fixed Schedule

**Purpose:** define daily non-negotiable blocks manually.

**Required defaults:**

- Sleep: 11:30 PM–7:00 AM, overnight, every day.
- Bath: 7:00 AM–7:30 AM, every day.

The user can edit those blocks and add more fixed blocks. All fixed blocks are
hard blocks, repeat seven days a week, and must have valid times. Sleep may
cross midnight; other fixed blocks must end after they start.

**Status:** implemented, manual-only.

### Page 7 — Skin Care

**Purpose:** build a safe weekly skin-care routine or explicitly skip it.

**Paths:**

1. **I have products** — enter product names or upload one product photo, choose
   desired applications per day, analyze owned products, and generate only a
   compatible routine.
2. **No products** — upload a required face photo, enter skin needs and budget,
   choose from location-aware branded product recommendations, then generate a
   routine from the selected products.
3. **Skip** — omit skin-care blocks from the completion bundle.

**No-products inputs:**

- skin type: Oily, Dry, Combination, Not sure;
- concerns: Acne, Spots, Tan, Dryness, Oiliness, None; and
- budget: Low, Medium, High; and
- desired applications per day: 2, 3, or 4.

**No-products product process:**

1. A face photo, skin type, at least one concern, and budget are required. The
   photo is persisted as an onboarding upload reference.
2. The Skin Care Worker uses the face photo, skin profile, budget, selected
   application frequency, and saved region settings to return real branded
   product options normally available in the user's country. Each option
   includes company/brand, product name, category, estimated local price,
   currency, and a short usefulness reason.
3. A separate product-selection screen lets the user choose which affordable,
   useful products they want. Product options and selections persist if the
   page is restored. A cleanser, moisturizer, and sunscreen must all be
   selected before routine generation can start.
4. After selection, the page uses the same Skin Care AI loading treatment as
   the owned-products path and builds the routine from only the chosen products.
5. Worker `routinePlans` are authoritative. Compatibility `timelineBlocks`
   and their suggested times are ignored by Flutter.
6. Flutter places the accepted plans into real free periods around the saved
   bath, lunch, rest, and sleep schedule. It never replaces occupied hard
   blocks.
7. The review state shows the persistent selected-product list, special-care
   notes, and the full editable weekly timeline.
8. Rebuild/Edit preserves the last valid routine until a replacement succeeds.
   The page can continue only when every day contains the selected number of
   routines, or when the user explicitly chooses Skip.

**Output:** daily skin-care timeline blocks, ordered product/step instructions,
special-care notes, missing-product warnings, and upload references where used.

**Safety behavior:** empty, malformed, unbranded, unpriced, incomplete,
incompatible, wrong-slot-count, or unreadable AI output is rejected instead of
replaced with a fake routine. Flutter bounds Worker requests and retains a
previous valid routine when a request times out; the Worker rejects a JSON
primitive or array instead of accepting it as an object payload.

**Status:** source/code frozen and regression-only with the Skin Care Worker
when configured. Local automated coverage remains green; deployed Skin Worker
verification is not claimed here.

### Page 8 — Drop Bad Habits

**Purpose:** select loops to intercept and create daily check-ins.

**Presets:** Cigarettes, Doom Scrolling, Junk Food, Procrastination, Alcohol,
plus custom habits.

Depending on habit type, the page records daily spend and/or daily time lost.
It shows daily spend, estimated monthly spend, and time-lost summaries.

**Required:** choose at least one habit or **Not now**.

**Output:** bad-habit drafts, check-in routines, and a money goal when selected
habits have non-zero daily spend.

### Page 9 — Build Good Habits

**Purpose:** create replacement habits and system templates.

**Presets:** Gym, Skill Practice, Reading, Meditation, Journaling, Language
Learning, plus custom habits.

**Per-habit settings:** subtype, duration, frequency, best time, and priority.

- Duration: 5, 15, 30, 45 minutes, or Custom.
- Frequency: Daily, Weekdays, 3 days/week, or Custom.
- Best time: Morning, Afternoon, Evening, Night, Anytime.
- Priority: Must do or Good to do.

**Required:** choose at least one habit or **Not now**.

### Page 10 — Long-Term Identity Goals

**Purpose:** map desired identities into duplicate-safe systems.

**Presets:**

- Financially Free
- Strong Body
- Become Disciplined
- New Language
- Start Business
- Inner Peace

At least one identity is required. Systems shared by multiple selected goals or
good habits are canonicalized and merged rather than scheduled twice.

### Page 11 — Coach Setup

**Purpose:** choose the coach identity and communication style.

**Names:** Coach, Mentor, Sensei, Friend, Mom / Maa, Dad, or Custom.

**Styles:** Supportive, Tough Love, Analytical, Zen, Motivational, Friendly.

Both a coach name and style are required.

### Page 12 — Slip-up Handling

**Purpose:** choose the comeback tone after a missed task or habit.

**Options:** Forgiving, Strict, Direct but kind.

The selection is separate from Coach style: Coach style controls the normal
voice; slip-up handling controls recovery behavior.

### Page 13 — Notifications

**Purpose:** save reminder preferences before asking for real native access.

**Toggles:** Morning start, Next task, Eating, Bad habit check-in, Savings,
Night reflection.

**Intensity:** Low, Medium, High.

The user must confirm app-level preferences. The page records an onboarding
permission preference, but it does **not** invoke the real operating-system
notification permission dialog. Real permission is deferred to the app/native
layer.

### Page 14 — Today Is Ready

**Purpose:** validate the entire setup and show the generated result before the
user enters Optivus.

**Review content:**

- missing required steps with edit shortcuts;
- selected identities;
- generated routine block count;
- habit focus;
- coach name/style;
- slip-up style;
- selected notifications;
- merged duplicate systems;
- warnings; and
- up to the first 12 generated timeline blocks.

**CTA:** **Enter Optivus**.

Completion is blocked by missing required setup or unresolved blocking
hard-block conflicts.

## 7. Onboarding completion contract

Completion builds one `OnboardingCompletionBundle` containing:

- profile patch;
- base timeline blocks;
- final timeline preview items;
- materialized Routine items;
- good-habit templates;
- bad-habit check-ins;
- identity goal systems;
- notification preferences;
- coach preferences;
- optional money goal;
- uploaded-asset references;
- warnings; and
- merged duplicate-system keys.

### 7.1 Scheduling rules

- Base timeline blocks are retained as their declared hard/soft type.
- Flexible identity and habit tasks are placed around occupied blocks.
- Good habits that already represent an identity system are merged.
- Bad habits create five-minute daily check-ins.
- Flexible tasks are moved after conflicts where a slot is available.
- If no daily slot fits, the task becomes an unscheduled `[Tiny]` fallback
  instead of overwriting a hard block.
- Overnight blocks are represented and rendered across midnight.
- Accepted hard conflicts are remembered by stable conflict keys.

### 7.2 Completion persistence

In fake mode, the draft and bundle are stored in the in-memory onboarding
repository and hydrated into frontend providers.

In Firebase mode, the active completion transaction writes:

- final onboarding draft;
- onboarding completion bundle; and
- profile patch;
- absent normalized initial Routine templates with deterministic IDs; and
- a create-only `onboarding-initial-v1` Routine projection receipt.

Routine templates are then loaded from their canonical repository. Firebase
mode does not hydrate `mockRoutineProvider`, and later login verifies the
receipt and loads templates/occurrences without replaying the bundle. The
bundle still hydrates other local feature owners until their own durable
phases. Normal authentication no longer repairs missing Routine imports;
explicit review-flow recovery remains available.

## 8. App shell and navigation

The signed-in app has six tabs in this order:

| Index | Tab | Color family |
| --- | --- | --- |
| 0 | Home | Rose |
| 1 | Routine | Green |
| 2 | Tracker | Aqua |
| 3 | Coach | Purple |
| 4 | Goals | Pink |
| 5 | Profile | Yellow/lime |

Tabs are cached in an `IndexedStack`. Deep-link routes do not push disconnected
pages; they select the owning tab and request that tab's inline detail view.

## 9. Home — Daily Command Center

### 9.1 Current screen order

1. Personalized header
2. Today's Identity
3. Now / Next Action
4. Today's Mission
5. Life OS Snapshot
6. Today Check-in
7. Auto Insights
8. Tracker Previews
9. Coach Tip
10. Mind Timeline
11. Coming Up

Today's Mission opens a full inline detail screen. Identity routes to Goals.
Tracker preview actions can route to the relevant Tracker experience. Mind
Timeline supports note capture and notebook-related sheets.

### 9.2 Current data truth

**Local/seeded:** identity focus, now/next, mission base values, Life OS
pillars, check-ins, screen-time insight, tracker previews, Coach Tip, and Coming
Up.

**Local from app state:** user display name, region-aware money labels,
confirmed money saved today, and Mind Notes.

**Pending:** real Home aggregation from Routine, Tracker, Goals, Coach, Mind,
and notifications. Home must not claim production intelligence until those
repositories are durable and an aggregation contract exists.

## 10. Routine — Timeline Control Center

### 10.1 Implemented main view

- date/header actions for AI, Add, and Settings;
- seven-day selection;
- primary and category filters;
- minute-accurate vertical timeline;
- current-time line;
- overnight continuation rendering;
- compact/full-day/minute-tick/precision view settings;
- card-specific actions;
- conflict banner and conflict resolver; and
- empty state.

### 10.2 Routine item types

- Hard block
- Soft block
- Flexible task
- Tracker task
- Check-in
- Money task

Items also carry category, source, status, priority, repeat days, tracker link,
subtasks, meal metadata, skin-care steps, conflict state, and timestamps.

### 10.3 Implemented item behavior

- add, update, and delete locally;
- mark completed, skipped, missed, or moved;
- start flexible tasks;
- complete subtasks;
- check in;
- move to a chosen time or tomorrow;
- shrink to a tiny version;
- find a free slot;
- detect conflicts;
- explicitly keep allowed overlaps;
- start supported Tracker tasks; and
- sync Tracker completion back into the Routine item.

Routine-to-Tracker launches are wired for Money, Meditation, Workout/Fitness,
and Focus. Hydration and smoking are modeled, but the Tracker tab's active
launch listener currently handles only the first four.

### 10.4 Routine detail screens

- Base Timeline Manager
- Classes setup
- Work setup
- Eating setup
- Fixed setup
- Skin Care setup
- Routine Import Review
- Routine Settings
- Habit Systems
- Routine History

### 10.5 Current data status

`routineNotifierProvider` is the canonical owner. Fake mode uses in-memory
repositories; Firebase mode selects Firestore repositories for templates and
dated occurrences and uses per-document create/update/delete operations.
Daily completion/skip/miss/move state is projected from occurrence records and
is not written to repeating templates. Onboarding projection is atomic and
idempotent with a fixed receipt, so sign-in preserves later edits and
deletions.

This is not yet **Live**: Firestore emulator tests now exist and pass locally,
but deployed-rule verification, physical-device restart, another-device
restore, full Routine CRUD acceptance, and the older overlapping habit
abstraction remain pending. The authoritative schema is [the Routine data
contract](ROUTINE_DATA_CONTRACT.md).

## 11. Tracker — Track, Measure, Improve

### 11.1 Main screen

- Daily / Weekly / Monthly period selector
- progress carousel
- Today's Progress hero
- Active Trackers
- Discover Trackers
- Phone Data Sources
- Recent Activity
- Tracker Settings

### 11.2 Active tracker screens

- Meditation
- Money System
- Screen Time
- Fitness Center
- Hydration
- Focus Timer
- Sleep
- Nutrition
- Bad Habit tracker
- Tracker Activation
- Tracker History
- Global Money Setup

### 11.3 Fitness screens

- Fitness Center
- activity detail
- active activity session
- activity finish/summary

Supported activity models include outdoor walk, run, cycling, indoor walk,
free workout, strength workout, stretch/mobility, and custom activity.

### 11.4 Phone data-source setup screens

- Usage Access for app/screen-time data
- Location/Mapbox for outdoor fitness routes
- Health Connect for optional health data

These setup screens exist, but the real Android permission intents, background
services, Health Connect reads, Usage Access reads, location recording, and
Mapbox maps remain pending. Manual/local tracker paths remain the current source
of truth.

### 11.5 Current tracker truth

- Money, meditation, hydration, bad-habit, focus, sleep, and nutrition actions
  update local Riverpod state.
- Fitness uses a dedicated local provider with seeded history, goals, records,
  insights, and mock routes.
- Screen-time and meditation catalog data are seeded.
- All active Tracker repositories are fake/in-memory.
- No tracker history is production-durable yet.

## 12. Coach — Session-Based Action Support

### 12.1 Implemented frontend

- session-based chat, not one endless conversation;
- quick prompts: Today's Plan, Recover, Improve Routine, Calm, Focus;
- message bubbles and typing state;
- structured response block models;
- action card routing to Meditation, Routine, and Routine Settings;
- session history;
- new-session flow;
- Coach settings; and
- privacy/data screen.

Supported session types include today planning, missed-task recovery, routine
improvement, calm/focus support, weekly review, goal review, tracker insight,
Mind Note discussion, and general chat.

### 12.2 Privacy contract

Coach preferences separately control access to Routine, Tracker, Goals, and
Profile context. Mind Notes are selected-share only by default. Coach must not
silently mutate Routine or Goals; action cards route the user to the owning
feature.

### 12.3 Current integration status

The Coach Worker and Flutter `CoachAiClient` exist, but the active Coach tab
still sends messages through `mockCoachProvider`, which produces local fake
responses. Coach sessions are not stored in Firestore. Connecting the active
tab to the Worker client and durable session repository is still required.

## 13. Goals — Identity Progress Center

### 13.1 Main screen

- Today's Identity Focus
- Today's Proofs
- Active Identities
- Systems
- Goal Health
- Weekly Progress
- Insights
- Milestones
- Upcoming Reviews
- Archived Goals shortcut

### 13.2 Detail screens

- Add Goal
- Goal Detail
- Weekly Review
- Archived Goals
- Goal Settings

### 13.3 Active goal model

Each goal has:

- identity title;
- purpose statement;
- progress percentage;
- linked systems;
- one daily proof with tiny/normal/strong versions;
- selected proof difficulty;
- completion/note/share state;
- streak days; and
- paused/archived state.

Onboarding goals are hydrated into the active local goal provider. Goal cards,
proof interactions, pause/archive behavior, and inline flows work locally.

### 13.4 Current data status

The active Goal repository is fake/in-memory. Cross-tab buttons to Routine and
Coach are implemented, but production proof verification, idempotent Firestore
proof writes, automated progress aggregation, milestones, reviews, and goal
notifications remain pending.

## 14. Profile — Life OS Control Center

### 14.1 Main groups

- profile header and edit action;
- System Setup;
- Account;
- Permissions & Data Sources;
- Connected Services;
- App Preferences;
- Region & Localization;
- Privacy & Security;
- Data Control;
- Support & About; and
- Log out.

### 14.2 Inline detail screens

- Edit Profile
- System Setup
- Notification Settings
- Permissions & Data Sources
- Permission Detail
- Connected Services
- Connected Service Detail
- App Preferences
- Region & Localization
- Privacy & Security
- Data Control
- Export Data
- Delete Selected Data
- Delete Account Request
- Archived Identities
- Report Bug
- Help Center
- About / Version

System Setup links back to the owning Routine, Goals, Coach, and notification
configuration screens rather than duplicating those systems in Profile.

### 14.3 Current persistence status

- Profile, profile settings, region/localization, and app preferences have
  Firestore implementations in Firebase mode.
- Permission status, connected services, data control, archived identities,
  exports, selected-data deletion, bug reports, and account-deletion workflows
  remain local/scaffolded.
- Profile photo upload has R2-purpose support in models/rules, but the complete
  user-facing durable profile-photo flow must still be verified end to end.

## 15. AI and Cloudflare services

Five Worker projects exist:

| Worker | Endpoint(s) | Active client usage |
| --- | --- | --- |
| R2 Upload | `/v1/uploads/sign`, `/v1/uploads/complete`, `/v1/uploads/delete` | Used by onboarding upload controller when R2 mode is configured |
| Routine Import | `/v1/routine-import/extract`, `/v1/routine-import/classes`, `/v1/routine-import/work`, `/v1/routine-import/eating-photo` | Used by class/work imports and review flow when Worker mode is configured |
| Nutrition | `/v1/eating/generate-routine` | Used by Eating Setup |
| Skin Care | `/v1/skin-care/products/analyze`, `/v1/skin-care/routine/generate` | Used by Skin Care Setup |
| Coach | `/v1/coach/reply` | Client exists; active Coach tab not wired yet |

Worker security rules include Firebase ID-token verification, verified-email
checks, owner-scoped R2 keys, upload size/type restrictions, request schema
validation, bounded AI payloads, explicit CORS allowlists, context-permission
enforcement in Coach, and sanitized output.

All five Workers now have exported-handler coverage. On 2026-09-05, every
typecheck and 121 Worker tests passed: R2 Upload 19, Routine Import 13,
Nutrition 12, Skin Care 66, and Coach 11.

Each Wrangler project also has a separate named staging template with
environment-specific bindings and explicit origin configuration. The templates
are deliberately non-deployable while exact authorization is absent: their
names end in `staging-pending-authorization`, resources use
`required-approved-*`, and origins use `.invalid`. Environment type generation
and dry-run bundling pass locally, but no deployment/version/URL/smoke result
exists.

No AI secret belongs in Flutter. Provider keys remain Worker secrets.

## 16. Upload and AI review contract

### 16.1 Upload limits

- Profile photo: JPEG/PNG, maximum 5 MiB.
- Routine-import purposes: JPEG/JPG/PNG/WEBP, maximum 15 MiB.
- Valid routine-import purposes: class timetable, work schedule, eating menu,
  and skin care.

Firestore stores owner metadata only. Local preview paths and image bytes are
explicitly forbidden from upload metadata and Routine Import Review documents.

### 16.2 AI import safety

- AI returns candidates, not committed Routine items.
- The user can review, edit, accept, partially accept, or reject candidates.
- Only accepted candidates are converted into Routine items.
- Applied item IDs are recorded so login repair can restore missing accepted
  imports without duplicating them.
- Another user's R2 path, unsafe path syntax, unsupported type, oversized image,
  malformed JSON, and unsafe output fields are rejected.

## 17. Firestore structure

The defined user-scoped paths include:

- `users/{uid}`
- `users/{uid}/profile/main`
- `users/{uid}/settings/regionLocalization`
- `users/{uid}/settings/appPreferences`
- `users/{uid}/onboarding/draft`
- `users/{uid}/onboarding/completionBundle`
- `users/{uid}/uploads/{assetId}`
- `users/{uid}/routineImportReviews/{reviewId}`
- `users/{uid}/routineItems/{itemId}`
- `users/{uid}/routineHistory/{eventId}`
- `users/{uid}/routineProjections/onboarding-initial-v1`
- `users/{uid}/habitSystems/{systemId}`
- `users/{uid}/habitTemplates/{habitId}`
- `users/{uid}/badHabitCheckins/{habitId}`
- `users/{uid}/tracker/config`
- `users/{uid}/trackerHistory/{eventId}`
- `users/{uid}/money/goals/{goalId}`
- `users/{uid}/money/savingEntries/{entryId}`
- `users/{uid}/focusSessions/{sessionId}`
- `users/{uid}/sleepLogs/{logId}`
- `users/{uid}/nutritionLogs/{logId}`
- `users/{uid}/fitnessSessions/{sessionId}`
- `users/{uid}/goals/{goalId}`
- `users/{uid}/home/dashboard`
- `users/{uid}/mindNotes/{noteId}`
- `users/{uid}/coach/sessions/{sessionId}`
- `users/{uid}/coach/preferences/main`
- `users/{uid}/notifications/preferences/main`

The current Firestore rules enforce stricter upload/import-review schemas, but
use a temporary verified-owner catchall for most other user collections.
Collection-specific production schemas and rules are still required.

## 18. Cross-feature ownership rules

### 18.1 Permitted interactions

- Home derives concise summaries from feature-owned records. Editing navigates
  or dispatches a command to the owning area; Home does not write the source
  record.
- Routine may request a Tracker launch and keep the link to the resulting
  session. Tracker owns the session and returns an idempotent completion result;
  Routine owns occurrence status and Routine history.
- Goals may consume eligible Routine completion or Tracker evidence. It owns
  the proof decision and progress record, not the source occurrence/session.
- Coach may read only context allowed by the user's Coach preferences. A Mind
  Note is excluded unless the user explicitly selects or shares it.
- Coach action cards are suggestions. Any change to another area requires user
  confirmation and an explicit command to that area's owner.
- Profile controls permissions and connected-service configuration, while the
  feature that consumes a service continues to own its domain records.
- Onboarding projects accepted starter data into feature-owned stores. Its
  completion bundle remains a versioned setup snapshot/bootstrap input.
- Cross-feature writes must be explicit, owner-scoped, retry-safe, and
  idempotent. Direct mutation of another feature's provider is transitional,
  not the target contract.
- A visible forecast, insight, score, or history based on seed data must not be
  described as live or automatic production data.

### 18.2 Current code disagreements

The screen/navigation structure follows the six-area model, but these current
implementations do not yet satisfy the target ownership rules:

- `mockRoutineProvider` remains as fake-development compatibility state, but
  production-capable Routine consumers and Firebase hydration use
  `routineNotifierProvider` only.
- Home/Mind has two models and state paths: the active `HomeMindNote`/
  `homeMindNoteProvider` path and the older `MindNote`/`mockMindNoteProvider`
  plus an unused repository boundary.
- Tracker state is split between the cross-feature `mockTrackerProvider` and
  feature-local state such as `fitnessCenterProvider`; completion is copied
  between them in memory.
- `lib/state/app_state.dart` owns Profile, Routine, Tracker, Goals, Mind,
  Coach, notifications, permissions, and Onboarding state in one transitional
  file.
- `RoutineNotifier` directly mutates `mockTrackerProvider` for money actions,
  and Fitness copies completion into `mockTrackerProvider`. These are local
  shortcuts rather than explicit commands/events with idempotency keys.
- Repository interfaces exist for all main areas, but the active Routine,
  Tracker, Goals, Coach, Home/Mind, notification, permission, connected-service,
  history, and data-control implementations remain fake/in-memory.

These disagreements are architecture debt, not evidence that the ownership
freeze is wrong. Their target phases and acceptance conditions are recorded in
the [technical-debt register](TECHNICAL_DEBT.md#4-active-debt-register).

## 19. What changed from the old blueprint

The following old assumptions are now obsolete or incomplete:

1. Onboarding is no longer 12 conceptual screens. It is a 15-page persisted
   wizard with four separate base-timeline pages.
2. “Onboarding 4” is no longer one combined mega-screen. Classes/Work, Eating,
   Fixed Schedule, and Skin Care are pages 4–7.
3. Classes and work setup now use role-aware upload/AI timeline generation,
   not only manual questions.
4. Eating is now a Worker-backed generated weekly routine or photo-import path.
5. Fixed Schedule is manual-only and automatically creates Sleep and Bath
   defaults.
6. Skin Care now has owned-product analysis, no-products generation, schedule
   adaptation, special-care notes, and hard failure rules.
7. Onboarding progress is persisted and legacy drafts are migrated.
8. Completion now produces a typed bundle and hydrates the rest of the app.
9. Firebase Auth/Firestore integration is partially implemented, not merely a
   future placeholder.
10. R2 and real Worker clients exist for uploads and AI.
11. Home, Routine, Tracker, Coach, Goals, and Profile screens are substantially
    implemented, but most post-onboarding data is still local/seeded.
12. The active Coach tab is not yet using the existing Coach Worker client.
13. Native permissions and phone-data integrations are still setup UI only.
14. Export and deletion screens do not yet execute production data jobs.

## 20. Production gap register

The authoritative, evidence-backed list is the
[technical-debt register](TECHNICAL_DEBT.md). It owns stable IDs, priorities,
single target phases, status, and measurable acceptance conditions. The
[data-source contract](DATA_SOURCE_CONTRACT.md) separately owns current
capability provenance and promotion-to-Live rules. This blueprint intentionally
does not duplicate those registers.

## 21. Release truth checklist

Before any build is called production-ready, verify all of the following:

- Firebase mode starts successfully on every target platform.
- New email users cannot bypass verification or onboarding.
- Interrupted onboarding restores the correct page and data.
- All five Workers are deployed with correct URLs, secrets, and Firebase
  project configuration.
- Uploads remain private and owner-scoped.
- AI failures never create fake user schedules.
- Onboarding completion restores identically after sign-out/sign-in.
- Post-onboarding edits survive app restart and sign-in on another device.
- Native permissions reflect actual OS state.
- Home shows only live or clearly labeled local data.
- Coach uses only allowed context and selected Mind Notes.
- Routine/Tracker/Goal completion is idempotent.
- Export and deletion requests execute and are auditable.
- Firestore rules are schema-specific for production collections.
- Analyzer, Flutter tests, Worker tests/typechecks, and manual route checks pass.

## 22. Verification snapshot

Current verification performed on 2026-09-05 against the final pre-Routine
closure working tree named at the top of this document:

- `flutter analyze`: passed with no issues.
- Focused Auth/Onboarding/Step 4/5/Step 7 matrix: all 408 tests passed.
- `flutter test`: all 1733 tests passed.
- Firestore rules emulator: all 130 Jest tests passed.
- All five Workers passed TypeScript typechecking and all 121 request tests.
- No Wrangler dry run, deployment, APK build, or remote smoke test was run in
  this closure pass.
- Startup configuration coverage proves staging/release rejects fake backend,
  fake upload, fake/disabled AI, missing/mismatched Firebase project,
  missing/non-HTTPS/placeholder/development URLs, and production use of
  staging URLs.
- TD-043 is resolved: the Eating test asserts visible generated content,
  saving, completion/dirty state, Fixed Schedule advancement, and draft
  serialization restoration without restoring the removed structural key.
- Live device/staging acceptance remains pending: no safe staging backend or
  deployment target was verified in this closure pass, and no integration is
  promoted to Live.
- The complete automated evidence, Worker readiness review, Android manual
  matrix, and remaining gates are in [PHASE_3_QA.md](PHASE_3_QA.md).
- Phase 0 navigation, design-token, documentation whitespace, heading, and
  internal-link checks passed.
- The [Phase 0 close-out audit](PHASE_0_CLOSEOUT.md) records the completion
  decision and the Phase 3 handoff.

## 23. Blueprint maintenance rule

When development changes a screen, model, repository boundary, Worker endpoint,
or cross-feature contract, update this file in the same change. Product vision
that is not implemented must be labeled **Pending**; implemented UI backed only
by local/seeded state must be labeled **Local/seeded**.
