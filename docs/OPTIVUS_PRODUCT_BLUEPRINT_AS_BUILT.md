# Optivus Product Blueprint — As Built

Status date: 2026-07-18  
Source baseline: `main` at `c42b603`  
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

The main backend mode is selected with `OPTIVUS_BACKEND`:

- `fake` — default; in-memory auth/repositories and local frontend state.
- `firebase` — initializes Firebase and enables the implemented Firebase Auth
  and Firestore-backed profile/onboarding paths.

AI and upload capabilities use separate build-time settings:

- `OPTIVUS_AI_WORKERS_MODE`: `worker`, `fake`, or `disabled`.
- `OPTIVUS_ROUTINE_IMPORT_AI_MODE`: `worker`, `fake`, or `disabled`.
- `OPTIVUS_UPLOAD_MODE`: `r2`, `fake`, or `disabled`.
- Worker URLs are supplied independently for Coach, Nutrition, Skin Care,
  Routine Import, and R2 Upload.

Release builds force the general AI client mode to Worker. A missing Worker URL
must be treated as unavailable configuration, not as permission to invent AI
results.

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
- hydration of a saved onboarding completion bundle back into frontend state.

**Still fake/local in the active repositories:**

- post-onboarding Routine CRUD;
- Routine history and habit systems;
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

The active onboarding schema is version 2 and contains 15 top-level pages,
indexed 0–14. Older 12-step drafts are migrated into the new page layout.

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

- upload the required timetable image or images;
- persist upload metadata and private R2 object references when configured;
- run Routine Import AI;
- convert safe timed candidates into class/work schedule blocks;
- display them on a weekly, minute-based timeline;
- allow block edits and day selection;
- require all role-required sections before continuing; and
- allow an existing saved schedule to be explicitly replaced.

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
2. **Build routine for me** — optionally upload a face photo and choose skin
   type, concerns, and budget before generation.
3. **Skip** — omit skin-care blocks from the completion bundle.

**No-products inputs:**

- skin type: Oily, Dry, Combination, Not sure;
- concerns: Acne, Spots, Tan, Dryness, Oiliness, None; and
- budget: Low, Medium, High.

**Output:** daily skin-care timeline blocks, ordered product/step instructions,
special-care notes, missing-product warnings, and upload references where used.

**Safety behavior:** empty, malformed, incompatible, wrong-slot-count, or
unreadable AI output is rejected instead of replaced with a fake routine.

**Status:** implemented with the Skin Care Worker when configured.

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
- profile patch.

The bundle is then hydrated into both Routine state representations, Goals,
Tracker setup, Coach preferences, notification preferences, and profile state.
On later login, the saved completion bundle is restored and accepted Routine
imports are repaired if missing.

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

**Live from local app state:** user display name, region-aware money labels,
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

The active `RoutineRepository` is still in-memory in all backend modes. The
Firestore path is defined and onboarding can restore its completion bundle, but
post-onboarding Routine edits are not yet production-persistent.

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
| R2 Upload | `/v1/uploads/sign`, `/complete`, `/delete` | Used by onboarding upload controller when R2 mode is configured |
| Routine Import | `/v1/routine-import/extract` plus source aliases | Used by class/work imports and review flow when Worker mode is configured |
| Nutrition | `/v1/eating/generate-routine` | Used by Eating Setup |
| Skin Care | `/v1/skin-care/products/analyze`, `/routine/generate` | Used by Skin Care Setup |
| Coach | `/v1/coach/reply` | Client exists; active Coach tab not wired yet |

Worker security rules include Firebase ID-token verification, verified-email
checks, owner-scoped R2 keys, upload size/type restrictions, request schema
validation, bounded AI payloads, and sanitized output.

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

These rules from the old blueprint still match current development:

- Home owns the concise daily summary, not full editing.
- Routine owns schedule and timeline changes.
- Tracker owns measurement, sessions, timers, and logs.
- Goals owns identity meaning, systems, proofs, and long-term progress.
- Coach suggests and explains; it does not silently edit another feature.
- Profile owns system controls and links to feature-owned setup.
- Mind Timeline and Mind Notebook belong to Home.
- Coach only receives a Mind Note when the user explicitly shares that note.
- Routine may launch a Tracker; Tracker completion returns status to Routine.
- A visible forecast, insight, score, or history based on seed data must not be
  described as live/automatic production data.

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

### Priority 0 — data correctness

- Replace fake Routine, Tracker, Goals, Coach, Home, Mind, and history
  repositories with owner-scoped durable implementations.
- Remove duplicate Routine state ownership after migration (`mockRoutineProvider`
  and `routineNotifierProvider` currently both receive onboarding data).
- Define the Home aggregation contract from durable source collections.
- Add collection-specific Firestore rules instead of relying on the temporary
  verified-owner catchall.
- Verify onboarding completion writes all intended normalized collections, or
  explicitly freeze the completion bundle as the only persisted source and
  document the projection job.

### Priority 1 — active integrations

- Wire Coach tab sends to `CoachAiClient` and persist sessions/messages.
- Connect native notification permission and actual scheduling.
- Implement Usage Access, Health Connect, background location/GPS, and Mapbox.
- Persist tracker sessions and sync completion idempotently to Routine/Goals.
- Finish durable profile-photo, export, deletion, and account-deletion jobs.

### Priority 2 — intelligence and polish

- Replace seeded Home scores, insights, tracker previews, and Coming Up with
  real aggregations.
- Replace seeded fitness/screen-time/meditation history where required.
- Implement durable weekly reviews, milestones, proof verification, overload
  protection, and goal insights.
- Add offline queue/conflict policy for Firebase mode.
- Add observability, rate-limit handling, analytics consent, accessibility QA,
  and production error reporting.

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

Verification performed against the source baseline named at the top of this
document:

- `flutter analyze`: passed with no issues.
- `flutter test`: 332 tests passed and 1 test failed.
- The remaining failure is
  `Eating no path saves generated blocks and advances to Fixed` in
  `test/onboarding_step4_timeline_layout_test.dart`. The test still expects the
  removed `onboarding-step5-timeline-scroll` widget key; the current Step 5
  timeline renders without that key. This is a test/implementation contract
  mismatch that should be resolved before the release checklist is considered
  complete.

## 23. Blueprint maintenance rule

When development changes a screen, model, repository boundary, Worker endpoint,
or cross-feature contract, update this file in the same change. Product vision
that is not implemented must be labeled **Pending**; implemented UI backed only
by local/seeded state must be labeled **Local/seeded**.
