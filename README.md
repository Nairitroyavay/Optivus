# Optivus

## Product overview

Optivus is a Flutter “Life OS” organized around six application areas:
**Home**, **Routine**, **Tracker**, **Coach**, **Goals**, and **Profile**.
Authentication and Onboarding are entry/setup flows, not additional main
areas. Onboarding builds a starter profile, schedule, goals, Tracker setup,
Coach preferences, notification preferences, and reviewed AI-import data.

## Current project status

The Phase 0 documentation foundation is complete. Active development remains
in **Phase 3 Stabilization**. The stale Eating test contract is resolved and
the automated Flutter/Worker gates are green, but physical-Android onboarding
QA and authorized staging verification remain open; do not start Phase 4 yet.

This repository is not production-ready. At the Phase 0 close-out audit, the
[data-source inventory](docs/DATA_SOURCE_CONTRACT.md) classified 0 capabilities
as Live, 40 as Local, 14 as Seeded, and 18 as Unavailable. Firebase/Worker
implementations exist in source, but that does not make their deployments or
active flows production-ready.

Important warnings:

- `OPTIVUS_BACKEND` and `OPTIVUS_UPLOAD_MODE` default to fake for local
  development. Staging, production, and release startup now fail closed unless
  Firebase, R2, the matching Firebase project, and every Worker URL are
  explicit.
- The fake upload client can simulate success without retaining bytes and must
  remain limited to an intentional development build.
- Most post-onboarding feature repositories are in-memory/fake.
- Home, Tracker, and Coach contain seeded or deterministic demo content.
- Worker URLs checked into Flutter configuration point to development names.
  The runtime guard rejects them in staging/production, and no remote
  deployment has been verified.

See the [technical-debt register](docs/TECHNICAL_DEBT.md), especially TD-035
and TD-036, before preparing any release build.

## Supported platforms

| Platform | Current support |
| --- | --- |
| Android | Primary development target and the only Firebase-configured platform. Fake and explicitly configured Firebase modes are supported for development. Physical-device onboarding verification is still a Phase 3 gate. |
| iOS | Flutter runner exists, but Firebase options and release behavior are not configured or verified. Use fake/offline mode only for exploratory development. |
| Web | Flutter runner exists, but Firebase options are not configured and the product is not web-release verified. |
| macOS, Windows, Linux | Flutter runners exist; Firebase and production behavior are not configured or verified. |

Do not describe a generated runner as a supported production platform. Adding
another Firebase platform requires an authorized FlutterFire configuration
change and its own test/release verification.

## Project structure

| Path | Responsibility |
| --- | --- |
| `lib/app/` | Root application composition and six-tab coordination. |
| `lib/core/` | Router, theme/tokens, utilities, and canonical shared widgets. |
| `lib/features/` | Area-owned screens, widgets, navigation requests, and feature-local state. |
| `lib/models/` | Shared data structures and serialization. |
| `lib/repositories/` | Data-access contracts, fake repositories, and selected Firestore implementations. |
| `lib/services/` | Worker/R2 clients, upload/import orchestration, native adapters, and cross-cutting services. |
| `lib/state/` | Transitional Auth/configuration state and legacy global mock owners; new durable feature state must not expand `app_state.dart`. |
| `lib/config/` | Compile-time backend, Firebase, Worker, AI, and upload configuration. |
| `test/` | Flutter unit/widget/router tests. |
| `workers/` | Cloudflare Worker projects for uploads and AI. |
| `docs/` | Product, architecture, navigation, design, provenance, debt, and historical handoff documents. |

The complete ownership/dependency rules are in
[ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Phase 0 documentation

- [Product blueprint](docs/OPTIVUS_PRODUCT_BLUEPRINT_AS_BUILT.md) — as-built
  product truth and implementation status.
- [Application architecture](docs/ARCHITECTURE.md) — area ownership,
  dependency direction, state/persistence boundaries, and folder conventions.
- [Navigation contract](docs/NAVIGATION.md) — primary routes, access guards,
  six-tab navigation, detail behavior, logout, and deletion entry.
- [Design system](docs/DESIGN_SYSTEM.md) — canonical tokens, shared components,
  interaction states, accessibility, and migration rules.
- [Data-source contract](docs/DATA_SOURCE_CONTRACT.md) — authoritative Live,
  Local, Seeded, and Unavailable capability inventory.
- [Technical-debt register](docs/TECHNICAL_DEBT.md) — stable IDs, evidence,
  priorities, target phases, and measurable acceptance conditions.
- [Phase 0 close-out](docs/PHASE_0_CLOSEOUT.md) — completion-gate audit and
  Phase 3 handoff.
- [Phase 3 QA handoff](docs/PHASE_3_QA.md) — automated evidence, deployment
  readiness, Android manual cases, and the remaining external gates.
- [Strict task rules](docs/OPTIVUS_STRICT_TASK_RULES.md) — Spark-only service,
  security, R2, Worker, and delivery constraints.

## Prerequisites

- Flutter stable. Phase 0 was verified with Flutter 3.44.0 and Dart 3.12.0;
  `pubspec.yaml` requires Dart `^3.11.5`.
- Android Studio/Android SDK and a configured emulator or Android device for
  the primary target.
- Node.js and npm for Worker work. The close-out environment used Node 25.9.0
  and npm 11.12.1; each Worker pins its own dependencies in `package-lock.json`.
- Authorized Firebase project access only when running Firebase mode.
- Authorized Cloudflare access only when running or managing real Workers/R2.

No global Wrangler install is required; Worker scripts use the package-local
Wrangler dependency through npm.

## Initial setup

From the repository root:

```sh
flutter pub get
flutter devices
```

Install Worker dependencies only for Workers you are changing. To install all
checked-in Worker projects:

```sh
for worker in coach-worker nutrition-worker r2-upload-worker routine-import-worker skin-care-worker; do
  (cd "workers/$worker" && npm ci)
done
```

Do not run dependency upgrades as part of setup. Dependency/version changes
must be reviewed separately.

## Safe local development

Use explicit offline/unavailable modes when you do not intend to contact
Firebase or development Workers:

```sh
flutter run \
  --dart-define=OPTIVUS_APP_ENV=development \
  --dart-define=OPTIVUS_BACKEND=fake \
  --dart-define=OPTIVUS_UPLOAD_MODE=disabled \
  --dart-define=OPTIVUS_AI_WORKERS_MODE=disabled \
  --dart-define=OPTIVUS_ROUTINE_IMPORT_AI_MODE=disabled
```

In fake backend mode, authentication and repository data are process-local.
Restart and another-device restore are not supported. Disabled AI/upload modes
must show unavailable/error behavior; they are preferable to fake success when
testing non-integration UI.

## Fake versus Firebase mode

The main mode is selected at compile time:

| Mode | Command definition | Behavior |
| --- | --- | --- |
| Fake | `--dart-define=OPTIVUS_BACKEND=fake` | Default. Uses local/fake Auth and configured repositories. Most feature data is session-only. |
| Firebase | `--dart-define=OPTIVUS_BACKEND=firebase` | Initializes Firebase and selects implemented Firebase Auth, Profile/settings, Onboarding, upload-metadata, and import-review repositories. Routine, Goals, Tracker, Coach, Home/Mind, notifications, native status, and data-control execution are still not fully durable. |

Always set the backend explicitly in team commands. The current default is not
a safe release configuration.

### Firebase development run

Firebase options are currently generated for Android only:

- `lib/config/firebase_options.dart`
- `android/app/google-services.json`
- `firebase.json`
- `firestore.rules`

Run Android Firebase mode with AI/uploads disabled unless those services are
also intentionally configured:

```sh
flutter run \
  --dart-define=OPTIVUS_APP_ENV=development \
  --dart-define=OPTIVUS_BACKEND=firebase \
  --dart-define=OPTIVUS_UPLOAD_MODE=disabled \
  --dart-define=OPTIVUS_AI_WORKERS_MODE=disabled \
  --dart-define=OPTIVUS_ROUTINE_IMPORT_AI_MODE=disabled
```

Firebase mode requires access to the configured project, Email/Password Auth,
and Firestore rules compatible with the inspected schemas. If another project
or platform is required, use the FlutterFire CLI through an authorized change;
do not hand-edit generated options or copy service-account credentials into the
app. Phase 0 does not deploy Firestore rules.

The current broad verified-owner Firestore catch-all is development debt
(TD-003), not a production schema.

## Worker and R2 configuration

| Worker | Endpoints | Local command |
| --- | --- | --- |
| R2 Upload | `/health`, `/v1/uploads/sign`, `/v1/uploads/complete`, `/v1/uploads/delete` | `cd workers/r2-upload-worker && npm run dev` |
| Routine Import | `/health`, `/v1/routine-import/extract`, `/v1/routine-import/classes`, `/v1/routine-import/work`, `/v1/routine-import/eating-photo` | `cd workers/routine-import-worker && npm run dev` |
| Nutrition | `/health`, `/v1/eating/generate-routine` | `cd workers/nutrition-worker && npm run dev` |
| Skin Care | `/health`, `/v1/skin-care/products/analyze`, `/v1/skin-care/routine/generate` | `cd workers/skin-care-worker && npm run dev` |
| Coach | `/health`, `/v1/coach/reply` | `cd workers/coach-worker && npm run dev` |

Each Worker validates Firebase ID tokens. AI Workers require their approved
provider secret (currently `GEMINI_API_KEY`; Routine Import also supports the
documented OpenAI configuration). R2 upload requires `R2_ACCESS_KEY_ID` and
`R2_SECRET_ACCESS_KEY`; R2-consuming Workers use the `UPLOAD_BUCKET` binding.
Checked-in development configuration references `optivus-uploads-dev`.

Store secrets only with the approved Wrangler/Cloudflare secret mechanism.
Never put them in Dart defines, `wrangler.toml`, `wrangler.jsonc`, source code,
shell history, screenshots, or documentation. `.dev.vars*` and `.env*` files
are ignored at the root and in Worker directories, but ignore rules do not make
them an approved transport or excuse printing values.

The named staging templates, authorization gate, deploy order, version
evidence, and rollback commands are in
[workers/STAGING_DEPLOYMENT.md](workers/STAGING_DEPLOYMENT.md). Their
`pending-authorization`, `required-approved-*`, and `.invalid` values are
intentional blockers, not deployable targets.

### Worker-enabled Flutter run

Replace placeholders with the intended local or authorized environment URLs:

```sh
flutter run \
  --dart-define=OPTIVUS_APP_ENV=development \
  --dart-define=OPTIVUS_BACKEND=firebase \
  --dart-define=OPTIVUS_UPLOAD_MODE=r2 \
  --dart-define=OPTIVUS_R2_UPLOAD_WORKER_URL=<r2-upload-worker-url> \
  --dart-define=OPTIVUS_AI_WORKERS_MODE=worker \
  --dart-define=OPTIVUS_ROUTINE_IMPORT_AI_MODE=worker \
  --dart-define=OPTIVUS_ROUTINE_IMPORT_WORKER_URL=<routine-import-worker-url> \
  --dart-define=OPTIVUS_NUTRITION_WORKER_URL=<nutrition-worker-url> \
  --dart-define=OPTIVUS_SKIN_CARE_WORKER_URL=<skin-care-worker-url> \
  --dart-define=OPTIVUS_COACH_WORKER_URL=<coach-worker-url>
```

The active Coach tab still uses local deterministic replies; supplying the
Coach URL does not activate the production Coach journey.

### Android staging build definitions

After the authorization record contains exact staging targets, an Android QA
build must supply all of these non-secret values:

```sh
flutter build apk --debug \
  --dart-define=OPTIVUS_APP_ENV=staging \
  --dart-define=OPTIVUS_BACKEND=firebase \
  --dart-define=OPTIVUS_FIREBASE_PROJECT_ID=<approved-staging-project-id> \
  --dart-define=OPTIVUS_UPLOAD_MODE=r2 \
  --dart-define=OPTIVUS_R2_UPLOAD_WORKER_URL=<approved-r2-staging-url> \
  --dart-define=OPTIVUS_AI_WORKERS_MODE=worker \
  --dart-define=OPTIVUS_ROUTINE_IMPORT_AI_MODE=worker \
  --dart-define=OPTIVUS_ROUTINE_IMPORT_WORKER_URL=<approved-routine-import-staging-url> \
  --dart-define=OPTIVUS_NUTRITION_WORKER_URL=<approved-nutrition-staging-url> \
  --dart-define=OPTIVUS_SKIN_CARE_WORKER_URL=<approved-skin-care-staging-url> \
  --dart-define=OPTIVUS_COACH_WORKER_URL=<approved-coach-staging-url>
```

The Firebase project definition must match the generated Android Firebase
configuration. This command is a template only; do not substitute development
URLs or run it as staging evidence while targets remain unresolved. No secret
belongs in a Dart define.

## Compile-time definitions

| Definition | Values/default | Requirement |
| --- | --- | --- |
| `OPTIVUS_APP_ENV` | `development` (default), `staging`, `production` | Staging/production and every release build activate fail-closed live-service validation. |
| `OPTIVUS_BACKEND` | `fake` (default), `firebase` | Staging/production/release requires `firebase`. Firebase is currently Android-only. |
| `OPTIVUS_FIREBASE_PROJECT_ID` | Empty by default | Required for staging/production/release and must match generated Android Firebase options. |
| `OPTIVUS_UPLOAD_MODE` | `fake` (default), `disabled`, `r2` | Use `disabled` for safe offline work; staging/production/release requires `r2` and its Worker URL. |
| `OPTIVUS_R2_UPLOAD_WORKER_URL` | Empty by default | Required when upload mode is `r2`; missing configuration fails visibly. |
| `OPTIVUS_AI_WORKERS_MODE` | `worker` (default), `disabled`, `fake` | Staging/production/release forces `worker`. Fake Nutrition/Skin Care clients are tests-only; missing/disabled services are unavailable. |
| `OPTIVUS_ROUTINE_IMPORT_AI_MODE` | `fake` (default), `disabled`, `worker` | Staging/production/release forces `worker`; application fake candidates are tests-only. |
| `OPTIVUS_ROUTINE_IMPORT_WORKER_URL` | Checked-in development URL | Override for the intended environment; deployment must be verified separately. |
| `OPTIVUS_NUTRITION_WORKER_URL` | Checked-in development URL | Same requirement. |
| `OPTIVUS_SKIN_CARE_WORKER_URL` | Checked-in development URL | Same requirement. |
| `OPTIVUS_COACH_WORKER_URL` | Checked-in development URL | Client exists, but the active Coach screen is not connected. |
| `MAPBOX_ACCESS_TOKEN` | No active app definition | Reserved by the architecture rules; current Mapbox integration is unavailable. Never commit a real token. |

Build-time URLs are public configuration, not a place for secrets.

## Testing and verification

Flutter checks from the repository root:

```sh
flutter analyze
flutter test test/onboarding_routing_test.dart
flutter test
```

The focused routing suite covers signed-out protection, email-verification
gating, restore loading, onboarding enforcement, completed-user routing, and
logout.

Worker checks:

```sh
for worker in coach-worker nutrition-worker r2-upload-worker routine-import-worker skin-care-worker; do
  (cd "workers/$worker" && npm run typecheck)
  (cd "workers/$worker" && npm test)
done
```

All five Workers define request-level suites. On 2026-07-23 they passed 102
tests total: R2 Upload 14, Routine Import 13, Nutrition 12, Skin Care 52, and
Coach 11. A passing local suite does not replace authenticated
deployed-environment smoke tests.

### Phase 3 automated and device gates

The former Eating mismatch can be rechecked with:

```sh
flutter test test/onboarding_step4_timeline_layout_test.dart \
  --plain-name "Eating no path saves generated blocks and advances to Fixed"
```

The test now verifies visible generated meals, saved Eating blocks, completion
and dirty state, advancement to Fixed Schedule, and serialization restoration;
it no longer depends on the removed `onboarding-step5-timeline-scroll` key.
On 2026-07-23, `flutter analyze`, the 268-test focused Phase 3 matrix, and all
392 Flutter tests passed. A complete physical-Android onboarding pass is still
required by TD-044, and exact staging targets, deploy authorization, versions,
and smoke results remain unresolved. See
[PHASE_3_QA.md](docs/PHASE_3_QA.md).

## Security and secret handling

- Firebase must remain Spark-compatible. Do not add Firebase Functions,
  Firebase Storage, Firebase Hosting/App Hosting, or a Google Cloud billing
  dependency.
- Cloudflare Workers replace Firebase Functions; private file bytes use R2,
  never Firestore or Firebase Storage.
- Flutter sends Firebase ID tokens to Workers. AI provider keys, R2 access
  keys, and Firebase service-account credentials never belong in Flutter.
- Firestore stores owner-scoped metadata/JSON, not large image bytes, base64
  files, local paths, or provider secrets.
- AI output is a proposal. Validate it and require user review before it
  changes canonical schedules or records.
- Never commit real Mapbox, AI, R2, service-account, signing, or release
  credentials. Stop and rotate a credential if it appears in source/history.
- Do not deploy Workers, rules, or Firebase configuration from an unreviewed or
  dirty working tree.

The full prohibited-service and integration rules are in
[OPTIVUS_STRICT_TASK_RULES.md](docs/OPTIVUS_STRICT_TASK_RULES.md).

## Known limitations

- No capability currently meets the repository's strict **Live** definition.
- Production Firebase, Worker, and R2 deployments are not verified.
- Routine has duplicate state owners and fake CRUD/history/habit repositories.
- Goals and Tracker are local/fake; Tracker native sources are unavailable.
- Home dashboards and several histories/insights contain seeded values.
- Coach Worker/client exists, but the active chat path is local/seeded.
- Usage Access, Health Connect, GPS/background Fitness, Mapbox, and real
  notification scheduling are unavailable.
- Profile photo lifecycle, export, selected-data deletion, and account deletion
  are incomplete.
- The broad Firestore development catch-all remains.
- Client crash reporting, analytics consent, CI/release automation, deployment
  verification, rate limiting, and R2 cleanup policy remain open debt.
- Physical-device onboarding and authorized staging deployment/smoke testing
  have not completed their Phase 3 gates.

Do not begin Phase 4 durable Routine work until Phase 3 Stabilization closes
TD-044, completes the staging/manual QA matrix, and records the required
account-separation and restoration evidence.
