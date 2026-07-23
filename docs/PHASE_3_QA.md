# Optivus Phase 3 QA and deployment handoff

Status date: 2026-07-23

Overall status: **Local preparation and automated gates passed; Phase 3 is not
complete.** Each Worker now has a named, non-deployable staging template and
request-level coverage. Exact staging targets and deployment authorization are
still unresolved, so no deployment or smoke testing occurred. No Android
staging build could be produced for the required manual journey,
account-separation, and restoration checks. A physical Realme RMX2001 is now
connected, but device availability alone does not satisfy the staging gate.

This document is the execution record and manual handoff for Phase 3. It does
not authorize deployment and does not change any capability's Live, Local,
Seeded, or Unavailable classification.

## 1. Build and environment record

| Field | Recorded value |
| --- | --- |
| Product build | Optivus `1.0.0+1` |
| Branch | `main` |
| Baseline commit | `b1372a2fbbbf6605dd6afd4586fa6ce48c36d70a` |
| Working-tree identity | Baseline plus the uncommitted Phase 3 stabilization changes listed in section 9 |
| Flutter/Dart | Flutter 3.44.0 stable; Dart 3.12.0 |
| Default backend mode | `OPTIVUS_BACKEND=fake` |
| Default upload mode | `OPTIVUS_UPLOAD_MODE=fake` |
| Environment guard | `OPTIVUS_APP_ENV=development` by default; an explicit staging/production or any release build fails at startup unless Firebase, R2, Worker AI, matching Firebase project, and five HTTPS Worker URLs are explicit and environment-safe |
| General AI mode | `worker` by default; staging/production/release forces `worker` |
| Routine Import AI mode | `fake` in an ordinary development build; staging/production/release forces `worker` |
| Firebase environment | Android client project `optivus-lifeos`, package `com.nairitroy.optivus`; remote deployment was not verified |
| Configured R2 development bucket | `optivus-uploads-dev` |
| Available local targets | Physical Android, macOS 15.7.5, and Chrome 150.0.7871.129 |
| Android devices/versions | `flutter devices --machine`: physical Realme `RMX2001`, Android 11 (API 30), Android ARM64, connected on 2026-07-23; no staging APK was built or run |
| Deployment authorization | Unresolved placeholder (`YES FOR STAGING ONLY / NO`); production authorization is `NO` |

### Worker endpoints by environment

Checked-in URLs and Worker names are public configuration, not secret values
and not deployment evidence.

| Worker | Development configuration | Staging | Production |
| --- | --- | --- | --- |
| R2 Upload | Worker name `optivus-r2-upload-worker-dev`; Flutter URL is empty until `OPTIVUS_R2_UPLOAD_WORKER_URL` is supplied | Named template `optivus-r2-upload-worker-staging-pending-authorization`; placeholder Firebase/account/R2/origin values; dry run PASS; not deployable or verified | Not configured; deployment unauthorized |
| Routine Import | `https://optivus-routine-import-worker-dev.nairitstock.workers.dev` | Named template `optivus-routine-import-worker-staging-pending-authorization`; placeholder Firebase/R2/origin values; dry run PASS; not deployable or verified | Not configured; deployment unauthorized |
| Nutrition | `https://optivus-nutrition-worker-dev.nairitstock.workers.dev` | Named template `optivus-nutrition-worker-staging-pending-authorization`; placeholder Firebase/origin values; dry run PASS; not deployable or verified | Not configured; deployment unauthorized |
| Skin Care | `https://optivus-skin-care-worker-dev.nairitstock.workers.dev` | Named template `optivus-skin-care-worker-staging-pending-authorization`; placeholder Firebase/R2/origin values; dry run PASS; not deployable or verified | Not configured; deployment unauthorized |
| Coach | `https://optivus-coach-worker-dev.nairitstock.workers.dev`; active Coach UI does not use this client | Named template `optivus-coach-worker-staging-pending-authorization`; placeholder Firebase/origin values; dry run PASS; not deployable or verified | Not configured; deployment unauthorized |

## 2. Automated verification record

All commands ran from the repository or the named Worker directory on
2026-07-23. No test was skipped or deleted.

| Area | Command/evidence | Result |
| --- | --- | --- |
| Changed Dart formatting | `dart format` on the new/changed runtime configuration and startup files | PASS — 7 files checked; final pass required 0 changes |
| Flutter analyzer | `flutter analyze` | PASS — no issues |
| Corrected Eating behavior | Focused `Eating no path saves generated blocks and advances to Fixed` test | PASS |
| Focused Phase 3 Flutter matrix | Authentication, router, persistence, restore, upload, Routine Import, Nutrition, Skin Care, AI config, and runtime config suites | PASS — 268 tests |
| Staging/release configuration | Nine snapshot-validation tests plus one explicit staging compile-definition test | PASS — development may remain local; staging/release rejects fake/disabled modes, missing/mismatched Firebase project, missing/non-HTTPS/placeholder/dev URLs, and production rejects dev/staging URLs; staging compile definitions force live Worker modes |
| Complete Flutter suite | `flutter test` | PASS — 392 tests |
| R2 Upload Worker | `npm run typecheck`; `npm test` | PASS — typecheck and 14 request tests |
| Routine Import Worker | `npm run typecheck`; `npm test` | PASS — typecheck and 13 request tests |
| Nutrition Worker | `npm run typecheck`; `npm test` | PASS — typecheck and 12 request tests |
| Skin Care Worker | `npm run typecheck`; `npm test` | PASS — typecheck and 52 tests |
| Coach Worker | `npm run typecheck`; `npm test` | PASS — typecheck and 11 request tests |
| All Worker tests | Five `npm test` suites | PASS — 102 tests total |
| Wrangler staging environment types | `npx wrangler types /tmp/... --env staging --include-runtime=false` for all five Workers | PASS — generated only in temporary files |
| Wrangler staging dry run | `npx wrangler deploy --env staging --dry-run --outdir /tmp/...` for all five Workers | PASS — bundle/config structure only; placeholder targets intentionally remain deployment blockers |

### Skin Care/onboarding invariant review

| Invariant | Evidence and result |
| --- | --- |
| AI failure never fabricates a routine | PASS — clients return error/unavailable with empty proposed plans; timeout regression coverage added |
| Invalid Worker responses are rejected | PASS — client validation coverage exists; Worker now rejects a JSON primitive/array, including a `null` regression test |
| Owned-product routines introduce no unowned product | PASS — scheduler ownership validation and rejection tests pass |
| Recommendations remain separate from owned products | PASS — distinct no-products selection path and restore tests pass |
| Failed rebuild retains the last valid routine | PASS — transactional rebuild tests pass |
| Skip is explicit | PASS — completion requires a valid routine or explicit skip |
| Draft restores path and generated data | PASS — path, options, selections, plans, and schedule restoration tests pass |
| Photo restoration stores references, not private bytes | PASS — upload reference serialization and Firestore-shape tests pass |
| Worker `routinePlans` remain authoritative | PASS — Flutter scheduling uses plans and ignores compatibility times |
| Compatibility fields cannot override validated fields | PASS — compatibility timeline input does not replace validated authoritative plans |

## 3. Configuration and security audit

- General AI and Routine Import force Worker clients for staging, production,
  and release. Missing or disabled configuration produces a startup failure or
  an error/unavailable state, not fake output.
- Backend/upload development defaults remain fake for safe local work, but
  `OptivusRuntimeConfig` now fails closed at startup for staging, production,
  and release unless Firebase and R2 are explicit. It also requires a supplied
  Firebase project ID to match generated Android Firebase configuration.
- All five Workers validate Firebase ID tokens and now have request tests
  proving missing/malformed headers and invalid/expired JWTs return safe 401
  responses without verification details.
- R2 object keys are owner-scoped under `users/{uid}/onboarding/...`; upload,
  import, and Skin Care code reject keys outside the authenticated owner.
- Firestore upload/draft serialization stores asset IDs, object keys, status,
  and timestamps, but excludes private image bytes and local preview paths.
- Static source/config/document review found no committed Gemini key, R2
  secret value, Firebase service-account key, bearer token, or private image.
  Android's checked-in Firebase client configuration is public client config,
  not a server credential.
- Worker logging review and request failure tests found no bearer-token,
  provider-key, secret, raw provider error detail, or image-byte response
  leakage. Production observability/redaction remains subject to deployed
  verification.
- The R2 signing route creates a new owner-scoped asset/key on each valid sign
  request. It avoids overwrite collisions, but repeated signs can leave orphan
  objects; cleanup/idempotency remains TD-034/TD-045. AI calls propose data and
  do not directly apply canonical records; client review/apply guards cover
  duplicate acceptance where implemented.
- All Wrangler files now declare separate named staging templates, explicit
  environment bindings, explicit origin placeholders, current compatibility
  date `2026-07-22`, and observability. Production remains intentionally
  unconfigured and unauthorized. The staging templates contain conspicuous
  `pending-authorization`, `required-approved-*`, and `.invalid` blockers until
  exact targets are supplied.
- CORS no longer silently allows wildcard/unapproved origins. An origin is
  echoed only when it exactly matches the configured comma-separated allowlist
  (or when `*` is explicitly configured). The staging template uses one
  non-routable explicit origin placeholder, never wildcard.
- Models are explicitly configured per Worker. All AI Workers use Gemini;
  model/fallback names are environment variables, while `GEMINI_API_KEY` is a
  secret name only. R2 Upload declares only the R2 secret names. No secret
  value was read or printed.

The data-source inventory therefore remains **0 Live, 40 Local, 14 Seeded,
18 Unavailable**. Passing source tests does not promote a remote integration.

## 4. Worker deployment-readiness checklist

Before any staging deploy, record the exact Cloudflare account, approved
Worker names/routes, staging Firebase project, staging R2 bucket, explicit
origins, secret provisioning owner, rollback owner, and test-data policy. Then
deploy one Worker at a time and attach its version plus authenticated and
unauthenticated smoke evidence.

| Worker | Source gate | Request tests | Required names/bindings (values not shown) | Environment separation | Deploy/smoke | Readiness result |
| --- | --- | --- | --- | --- | --- | --- |
| R2 Upload | Typecheck PASS | 14 PASS | `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `UPLOAD_BUCKET`, Firebase project | Named staging template + explicit origin; exact account/bucket/name unresolved; Flutter URL unset | Not authorized/not run | BLOCKED — exact targets, authorization, deploy, smoke |
| Routine Import | Typecheck PASS | 13 PASS | `GEMINI_API_KEY`, `UPLOAD_BUCKET`, Firebase project | Named staging template + explicit origin; exact bucket/name unresolved | Not authorized/not run | BLOCKED — exact targets, authorization, deploy, smoke |
| Nutrition | Typecheck PASS | 12 PASS | `GEMINI_API_KEY`, Firebase project | Named staging template + explicit origin; exact name/project unresolved | Not authorized/not run | BLOCKED — exact targets, authorization, deploy, smoke |
| Skin Care | Typecheck PASS | 52 PASS | `GEMINI_API_KEY`, `UPLOAD_BUCKET`, Firebase project | Named staging template + explicit origin; exact bucket/name unresolved | Not authorized/not run | BLOCKED — exact targets, authorization, deploy, smoke |
| Coach | Typecheck PASS | 11 PASS | `GEMINI_API_KEY`, Firebase project | Named staging template + explicit origin; exact name/project unresolved | Not authorized/not run; active UI disconnected | BLOCKED — exact targets, authorization, active-flow scope, deploy, smoke |

Rollback information cannot be recorded until a deployment version exists.
Production deployment is expressly outside this Phase 3 task.

## 5. Manual QA prerequisites and result conventions

Prerequisites:

1. One supported small Android phone and one large Android phone/tablet when
   available, with OS versions recorded before testing.
2. A second physical Android device for cross-device restoration, or a named
   exception approved by the release owner.
3. Two isolated staging email accounts with mailbox access. Do not use a
   production account.
4. An explicitly authorized staging Firebase/Worker/R2 environment with all
   five endpoint targets and deployment versions recorded in section 1.
5. Synthetic, non-personal class/work, meal, product, and face-photo fixtures.
   Never attach raw photos, tokens, or secret-bearing logs as evidence.
6. A build launched with explicit `firebase`, `r2`, and `worker` definitions;
   record the exact non-secret command and APK/build checksum.
7. Network controls for offline, disconnect, latency/timeout, and retry cases.
8. Screen recording, sanitized device logs, and a defect tracker available.

Status codes used below:

- **BLOCKED-D** — additional required device coverage is unavailable, such as
  the second restoration device or large phone/tablet target.
- **BLOCKED-E** — authorized deployed staging environment/credentials absent.
- **BLOCKED-D+E** — both blockers apply.
- **PASS/FAIL** — set only after the case is executed and evidence is attached.

Evidence targets use `docs/qa-evidence/phase-3/<case-id>/`. Those directories
are handoff targets and have not been created. Store only sanitized screenshots,
screen recordings, and log excerpts. “Retest” is **Pending first run** for every
currently blocked case.

Severity meanings: S0 = security/privacy/cross-account data; S1 = critical
journey/data loss; S2 = recoverable functional/UI failure; S3 = minor visual.

## 6. Numbered Android manual cases

### Authentication and access

| ID | Steps | Expected result | Status | Evidence target | Severity if failed | Retest |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | Clear app data and fresh-launch the staging build. | Welcome is shown with no prior-account content or crash. | BLOCKED-E | `.../A01/` | S1 | Pending first run |
| A02 | Sign up with a new valid email/password. | Account is created and verification guidance appears; onboarding is not bypassed. | BLOCKED-E | `.../A02/` | S1 | Pending first run |
| A03 | Attempt sign-up with malformed email, weak password, and duplicate email. | Inline/actionable errors appear; no authenticated session or partial profile is created. | BLOCKED-E | `.../A03/` | S1 | Pending first run |
| A04 | Log in with a verified staging account. | Correct account state loads and routing follows its onboarding status. | BLOCKED-E | `.../A04/` | S1 | Pending first run |
| A05 | Enter the correct email and an incorrect password. | Login fails safely without revealing account details or changing route. | BLOCKED-E | `.../A05/` | S1 | Pending first run |
| A06 | Verify a new account through email, return to the app, and refresh/retry. | Verification is recognized and only then permits the next eligible route. | BLOCKED-E | `.../A06/` | S1 | Pending first run |
| A07 | While unverified, attempt app/onboarding deep links and back navigation. | All protected routes return to the verification/access gate. | BLOCKED-E | `.../A07/` | S0 | Pending first run |
| A08 | With verified but incomplete onboarding, attempt six-area/deep links. | User remains in onboarding at the correct persisted step. | BLOCKED-E | `.../A08/` | S1 | Pending first run |
| A09 | Log out from a completed account, including while a nested screen is open. | Welcome appears and user-scoped UI/state is cleared. | BLOCKED-E | `.../A09/` | S0 | Pending first run |
| A10 | After A09, log in as a different account. | Only Account B state appears; no Account A profile/setup is visible. | BLOCKED-E | `.../A10/` | S0 | Pending first run |

### Onboarding restoration

| ID | Steps | Expected result | Status | Evidence target | Severity if failed | Retest |
| --- | --- | --- | --- | --- | --- | --- |
| R01 | Enter distinctive valid data, advance partway, then force-close during onboarding. | Last saved step/data remain durable; no false completion occurs. | BLOCKED-E | `.../R01/` | S1 | Pending first run |
| R02 | Reopen after R01. | The exact eligible step, selected path, saved fields, and uploaded references restore. | BLOCKED-E | `.../R02/` | S1 | Pending first run |
| R03 | Sign out during incomplete onboarding. | Welcome appears and the incomplete draft is not visible while signed out. | BLOCKED-E | `.../R03/` | S0 | Pending first run |
| R04 | Sign back in to the same account after R03. | The same incomplete draft and correct step restore once, without duplicate generated records. | BLOCKED-E | `.../R04/` | S1 | Pending first run |
| R05 | Complete all 15 pages with a valid reviewed setup. | Completion succeeds once and enters the six-area app. | BLOCKED-E | `.../R05/` | S1 | Pending first run |
| R06 | Force-stop/restart after R05. | Completed account returns to the app with the accepted setup restored. | BLOCKED-E | `.../R06/` | S1 | Pending first run |
| R07 | Sign out and sign back in after completion. | Completion and accepted setup restore with no duplicate projection. | BLOCKED-E | `.../R07/` | S1 | Pending first run |
| R08 | Uninstall/reinstall, then sign in to the completed account. | Server-backed profile, completion, metadata, and setup restore; local-only previews do not masquerade as durable files. | BLOCKED-E | `.../R08/` | S1 | Pending first run |
| R09 | Sign in to the same completed account on a second Android device. | The same durable setup restores without another account's data or required private local paths. | BLOCKED-D+E | `.../R09/` | S0 | Pending first run |

### Routine Import and Eating

| ID | Steps | Expected result | Status | Evidence target | Severity if failed | Retest |
| --- | --- | --- | --- | --- | --- | --- |
| I01 | Upload valid synthetic class and work schedules for the chosen role. | Owner-scoped uploads produce correctly categorized candidates with days/times. | BLOCKED-E | `.../I01/` | S1 | Pending first run |
| I02 | Upload an invalid, unreadable, or unrelated image. | Safe actionable rejection appears; no fabricated candidates or saved blocks. | BLOCKED-E | `.../I02/` | S1 | Pending first run |
| I03 | Review a valid candidate set and inspect warnings/edits. | Candidate details are editable/reviewable and low confidence is visible. | BLOCKED-E | `.../I03/` | S2 | Pending first run |
| I04 | Reject one candidate, accept others, and try accepting twice. | Only approved candidates apply once; rejected candidates stay absent. | BLOCKED-E | `.../I04/` | S1 | Pending first run |
| I05 | Use the Eating photo path with a synthetic meal/menu image. | Visible meal blocks/summary match the reviewed source and save only after valid generation. | BLOCKED-E | `.../I05/` | S1 | Pending first run |
| I06 | Use the generated Eating-plan path. | A visible weekly meal plan and summary are generated without fake fallback. | BLOCKED-E | `.../I06/` | S1 | Pending first run |
| I07 | Force provider/unavailable failure during Eating generation. | Actionable error appears; no meal plan is fabricated or marked complete. | BLOCKED-E | `.../I07/` | S1 | Pending first run |
| I08 | Save an Eating plan, close/reopen, and return to the page. | Saved meal blocks, dishes, days, times, completion, and clean state restore. | BLOCKED-E | `.../I08/` | S1 | Pending first run |
| I09 | Press Next Step after a valid Eating plan. | Eating blocks save, step is completed/not dirty, and Fixed Schedule opens. | BLOCKED-E | `.../I09/` | S1 | Pending first run |

### Skin Care

| ID | Steps | Expected result | Status | Evidence target | Severity if failed | Retest |
| --- | --- | --- | --- | --- | --- | --- |
| S01 | Choose owned products and enter typed product names. | Typed products remain the authoritative owned list and generate only compatible steps. | BLOCKED-E | `.../S01/` | S1 | Pending first run |
| S02 | Choose owned products and upload a synthetic product photo. | Metadata uploads owner-scoped, detected labels require review, and bytes are not written to Firestore. | BLOCKED-E | `.../S02/` | S0 | Pending first run |
| S03 | Choose no products, add required synthetic face photo/profile/budget, select recommendations, and generate. | Branded/priced recommendations appear separately; essentials must be selected before generation. | BLOCKED-E | `.../S03/` | S1 | Pending first run |
| S04 | Explicitly choose Skip and continue. | Skin Care is marked explicitly skipped; no generated routine or success claim is created. | BLOCKED-E | `.../S04/` | S1 | Pending first run |
| S05 | Generate a two-applications-per-day routine. | Every day contains exactly two valid scheduled routines in free periods. | BLOCKED-E | `.../S05/` | S1 | Pending first run |
| S06 | Generate a three-applications-per-day routine. | Every day contains exactly three valid scheduled routines in free periods. | BLOCKED-E | `.../S06/` | S1 | Pending first run |
| S07 | Generate a four-applications-per-day routine. | Every day contains exactly four valid scheduled routines in free periods. | BLOCKED-E | `.../S07/` | S1 | Pending first run |
| S08 | Edit an accepted generated routine within supported controls. | Valid edits are visible/saved and do not introduce unowned products or hard-block overlaps. | BLOCKED-E | `.../S08/` | S1 | Pending first run |
| S09 | Rebuild a valid routine with changed personalization/frequency. | Old routine remains until a complete valid replacement is accepted. | BLOCKED-E | `.../S09/` | S1 | Pending first run |
| S10 | Cause provider failure during regeneration. | Actionable failure appears; the prior valid routine remains active and unchanged. | BLOCKED-E | `.../S10/` | S1 | Pending first run |
| S11 | Close/reopen after saving typed/photo/no-products state and a valid routine. | Selected path, asset references, options/selections, frequency, plan, and schedule restore. | BLOCKED-E | `.../S11/` | S1 | Pending first run |
| S12 | Remove a product/face photo where the current UI supports removal. | Preview/reference clears consistently, alternate input becomes available, and stale bytes are not displayed. | BLOCKED-E | `.../S12/` | S1 | Pending first run |
| S13 | Return malformed, unsafe, incomplete, unpriced/unbranded, wrong-count, or unowned-product Worker output. | Output is rejected with no fake routine and no overwrite of valid data. | BLOCKED-E | `.../S13/` | S1 | Pending first run |
| S14 | Use strong actives across a full week and inspect missing-product warnings. | Incompatible actives are partitioned safely; warnings are visible and do not silently add products. | BLOCKED-E | `.../S14/` | S1 | Pending first run |
| S15 | Return conflicting compatibility `timelineBlocks` and authoritative `routinePlans`. | Only validated `routinePlans` drive scheduling; compatibility times cannot override them. | BLOCKED-E | `.../S15/` | S1 | Pending first run |

### Network and failure behavior

| ID | Steps | Expected result | Status | Evidence target | Severity if failed | Retest |
| --- | --- | --- | --- | --- | --- | --- |
| N01 | Go offline before upload/AI request. | Immediate truthful unavailable/error state; no fake success or completion. | BLOCKED-E | `.../N01/` | S1 | Pending first run |
| N02 | Disconnect after a request starts. | Loading ends in a recoverable error; existing valid data remains. | BLOCKED-E | `.../N02/` | S1 | Pending first run |
| N03 | Add latency beyond the client timeout. | Request terminates safely with an actionable unavailable result and no routine. | BLOCKED-E | `.../N03/` | S1 | Pending first run |
| N04 | Restore connectivity and retry once. | One valid result replaces the error without duplicated canonical records. | BLOCKED-E | `.../N04/` | S1 | Pending first run |
| N05 | Repeatedly tap upload/generate/continue while loading. | Actions disable/debounce; no duplicate applied blocks or conflicting state. | BLOCKED-E | `.../N05/` | S1 | Pending first run |
| N06 | Return invalid JSON or a schema-invalid Worker response. | Safe invalid-response error; no crash, fake output, or data overwrite. | BLOCKED-E | `.../N06/` | S1 | Pending first run |
| N07 | Use a missing/unreachable Worker URL. | Configuration/unavailable message is truthful and progression stays gated. | BLOCKED-E | `.../N07/` | S1 | Pending first run |
| N08 | Expire/revoke authentication before a Worker request. | Request is rejected; no private object/data leaks and reauthentication is possible. | BLOCKED-E | `.../N08/` | S0 | Pending first run |
| N09 | Background and foreground the app during a request. | No crash, duplicate call/apply, stuck loading state, or erased prior data. | BLOCKED-E | `.../N09/` | S1 | Pending first run |

### Account data separation

| ID | Steps | Expected result | Status | Evidence target | Severity if failed | Retest |
| --- | --- | --- | --- | --- | --- | --- |
| D01 | Account A completes onboarding with distinctive profile, draft history, uploads, and generated setup; then sign out. | Signed-out UI contains none of Account A's user-scoped data. | BLOCKED-E | `.../D01/` | S0 | Pending first run |
| D02 | Sign in as Account B and inspect Profile, onboarding eligibility/draft, upload previews/references, and all generated setup. | No Account A value, reference, preview, or generated block is visible to B. | BLOCKED-E | `.../D02/` | S0 | Pending first run |
| D03 | Sign out B and sign back into A. | Account A restores its own durable completion/setup only, with no B data and no duplicates. | BLOCKED-E | `.../D03/` | S0 | Pending first run |

### UI regression

| ID | Steps | Expected result | Status | Evidence target | Severity if failed | Retest |
| --- | --- | --- | --- | --- | --- | --- |
| U01 | Complete the flow on the smallest supported phone. | Content scrolls; no overflow, clipped CTA, or inaccessible control. | BLOCKED-E | `.../U01/` | S2 | Pending first run |
| U02 | Complete representative pages on the largest available phone/tablet. | Layout remains readable with sensible widths and no detached controls. | BLOCKED-D+E | `.../U02/` | S2 | Pending first run |
| U03 | Repeat critical pages at system text scales 1.0, 1.5, and 2.0. | Text remains readable and critical actions/content remain reachable. | BLOCKED-E | `.../U03/` | S2 | Pending first run |
| U04 | Open/close the keyboard on every text-heavy page and use Next/Back. | Focus is visible, fields scroll above keyboard, and CTA does not overlap it. | BLOCKED-E | `.../U04/` | S2 | Pending first run |
| U05 | Observe upload, AI, restore, and completion loading states. | Progress is visible, stable, accessible, and prevents conflicting actions. | BLOCKED-E | `.../U05/` | S2 | Pending first run |
| U06 | Inspect every disabled action before prerequisites are met. | Disabled state is visually clear and cannot be activated. | BLOCKED-E | `.../U06/` | S2 | Pending first run |
| U07 | Trigger recoverable errors and correct the input/retry. | Error clears predictably and successful retry returns to a usable state. | BLOCKED-E | `.../U07/` | S2 | Pending first run |
| U08 | Exercise top back, stage back, system back, and forward navigation. | Navigation follows the documented flow without skipping gates or losing saved data. | BLOCKED-E | `.../U08/` | S1 | Pending first run |
| U09 | Inspect all pages in portrait for clipped/overlapping primary controls. | Primary actions, timelines, sheets, and upload controls never clip or overlap. | BLOCKED-E | `.../U09/` | S2 | Pending first run |

## 7. Staging deployment and smoke status

No Worker, R2 binding, Firebase rule/configuration, or staging app build was
deployed. No remote endpoint was called for a smoke test. The reason is not a
test failure: the authorization record still contains `[REQUIRED]` target
placeholders and unresolved staging authorization. Production deployment is
explicitly prohibited.

The next authorized staging session must:

1. Replace every deliberately non-deployable staging placeholder with the
   exact approved target, without copying development defaults into staging or
   production.
2. Confirm the exact account, Firebase project, Worker names, bucket, routes,
   secret names, and rollback owner without displaying secret values.
3. Deploy one Worker at a time and record its version.
4. Run health, missing-auth, invalid-auth, malformed-input, one synthetic
   success, and one provider/unavailable failure smoke per active Worker.
5. Verify R2 ownership with two staging accounts and confirm Firestore metadata
   contains no bytes/local paths.
6. Record rollback commands/version and attach sanitized evidence here.

## 8. Phase 3 completion gate

| Gate | Status |
| --- | --- |
| Skin Care implementation/invariants reviewed | PASS (source + automated) |
| Stale Eating contract corrected | PASS |
| Flutter analyze and full tests | PASS |
| All five Worker typechecks/tests | PASS — 102 request tests |
| Secret/config/source audit | PASS with open readiness findings |
| Named staging environment | PARTIAL — safe local templates/dry runs pass; exact authorized names/resources remain blocked |
| All five staging deployments and authenticated smoke | NOT RUN / BLOCKED |
| Physical Android full onboarding | DEVICE CONNECTED / STAGING BUILD BLOCKED |
| Sign-out/sign-in and reinstall restoration on Android | NOT RUN / BLOCKED |
| Two-account isolation and second-device restoration | NOT RUN / BLOCKED |

**Decision: Phase 3 does not satisfy its completion gate. Phase 4 must not
begin until the blocked staging and Android evidence is completed and any
resulting S0/S1 defects are fixed and retested.**

## 9. Phase 3 stabilization files

Direct implementation:

- `lib/config/app_environment_config.dart`
- `lib/config/runtime_config.dart`
- `lib/config/ai_workers_config.dart`
- `lib/config/routine_import_ai_config.dart`
- `lib/main.dart`
- `lib/services/skin_care_ai_client.dart`
- `workers/r2-upload-worker/src/index.ts`
- `workers/routine-import-worker/src/index.ts`
- `workers/nutrition-worker/src/index.ts`
- `workers/skin-care-worker/src/index.ts`
- `workers/coach-worker/src/index.ts`

Regression coverage:

- `test/runtime_config_test.dart`
- `test/onboarding_step4_timeline_layout_test.dart`
- `test/onboarding_step7_skin_care_test.dart`
- `workers/r2-upload-worker/src/index.test.ts`
- `workers/routine-import-worker/src/index.test.ts`
- `workers/nutrition-worker/src/index.test.ts`
- `workers/skin-care-worker/src/index.test.ts`
- `workers/coach-worker/src/index.test.ts`

Documentation:

- `.gitignore`
- `README.md`
- `docs/OPTIVUS_PRODUCT_BLUEPRINT_AS_BUILT.md`
- `docs/DATA_SOURCE_CONTRACT.md`
- `docs/TECHNICAL_DEBT.md`
- `docs/PHASE_3_QA.md`
- `workers/STAGING_DEPLOYMENT.md`

No Phase 4 persistence work, unrelated dependency upgrade, commit, push, pull
request, staging deployment, or production deployment was performed.
