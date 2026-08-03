# OPTIVUS Phase 4.6.4 Pre-Device Readiness

Assessment date: 2026-08-03 (Asia/Kolkata)  
Authoritative execution evidence: `docs/phase_4_6_4_execution_report.md`  
Score: **88/100** (36 of 41 required acceptance conditions satisfied)  
Status: **BLOCKED — NOT READY FOR REAL-DEVICE TESTING**

This is not a Phase 5 declaration and contains no physical-device evidence.
All known P0 issues are resolved. P1-07 is environment-blocked.

## Acceptance matrix

| # | Required condition | Evidence status | Evidence |
|---:|---|---|---|
| 1 | Project compiles | `PASS_BUILD_VERIFIED` | Fresh debug APK build exited 0. |
| 2 | Formatting check passes | `PASS_BUILD_VERIFIED` | 453 files checked, 0 changed. |
| 3 | Analyzer has zero issues | `PASS_BUILD_VERIFIED` | 0 issues. |
| 4 | All Flutter tests pass | `PASS_AUTOMATED_TESTED` | 969 passed, 0 failed/skipped/error events. |
| 5 | Firestore emulator passes | `PASS_EMULATOR_VERIFIED` | 39 passed, 0 failed/skipped. |
| 6 | Fixtures match serializers | `PASS_EMULATOR_VERIFIED` | Canonical production paths/fields are used by Phase 4.6.4 fixtures. |
| 7 | Root UserProfile matches Rules | `PASS_EMULATOR_VERIFIED` | Exact root create/update passes. |
| 8 | No full profile at `/profile/main` | `PASS_EMULATOR_VERIFIED` | Full shape denied; settings shape accepted. |
| 9 | RegionLocalization matches Rules | `PASS_EMULATOR_VERIFIED` | Exact v1 contract passes; drift denied. |
| 10 | AppPreferences matches and round-trips | `PASS_EMULATOR_VERIFIED` | Exact Rule plus every-field Firestore round-trip. |
| 11 | CompletionBundle matches Rules | `PASS_EMULATOR_VERIFIED` | Canonical timestamps/fingerprint/revision/sets pass. |
| 12 | CompletionJob matches Rules | `PASS_EMULATOR_VERIFIED` | Canonical owner/enums/stages/accounting pass. |
| 13 | Cross-user denied | `PASS_EMULATOR_VERIFIED` | Owner isolation negatives pass. |
| 14 | Unknown fields denied | `PASS_EMULATOR_VERIFIED` | Strict schema negatives pass. |
| 15 | Recovery cannot fabricate | `PASS_AUTOMATED_TESTED` | Missing/partial inputs cannot become completed. |
| 16 | Missing draft cannot complete | `PASS_AUTOMATED_TESTED` | Missing-draft recovery fails closed. |
| 17 | Partial draft resumes | `PASS_AUTOMATED_TESTED` | Resume action retains partial state and owner. |
| 18 | Final draft durable/verified | `PASS_AUTOMATED_TESTED` | revision/fingerprint/content readback. |
| 19 | Bundle persisted/verified | `PASS_AUTOMATED_TESTED` | canonical full readback. |
| 20 | Routine expected set verified | `PASS_AUTOMATED_TESTED` | complete deterministic readback. |
| 21 | Actual History verified | `PASS_AUTOMATED_TESTED` | actual occurrence records, not receipt-only proof. |
| 22 | Mixed History create/repair correct | `PASS_AUTOMATED_TESTED` | created/existing/repaired/failed sets tested. |
| 23 | Actual Habit verified | `PASS_AUTOMATED_TESTED` | repository and content readback. |
| 24 | Controllers reload | `PASS_AUTOMATED_TESTED` | hydration reload gate tested. |
| 25 | Frontend-visible IDs verified | `PASS_AUTOMATED_TESTED` | visible sets equal verified sets. |
| 26 | Profile finalized last/once | `PASS_AUTOMATED_TESTED` | ordering and failure gates tested. |
| 27 | Accounting is real | `PASS_AUTOMATED_TESTED` | readback-derived entity sets. |
| 28 | Structured blocking failures | `PASS_AUTOMATED_TESTED` | typed bounded diagnostics; no raw exception payload retention. |
| 29 | Sign-out invalidates work | `PASS_AUTOMATED_TESTED` | auth/operation generation tests pass. |
| 30 | Account switch leaks no state | `PASS_AUTOMATED_TESTED` | stale UID/generation results rejected. |
| 31 | Stale AI results rejected | `PASS_AUTOMATED_TESTED` | request/source/auth generation fences pass. |
| 32 | Safe startup UI | `PASS_AUTOMATED_TESTED` | runtime and Firebase failure widget/bootstrap tests pass. |
| 33 | Debug APK exists | `PASS_BUILD_VERIFIED` | 192,473,311-byte current APK recorded. |
| 34 | Configured staging APK/AAB exists | `ENVIRONMENT_BLOCKED` | No approved targets/signing material; none produced. |
| 35 | Staging artifact path/size recorded | `ENVIRONMENT_BLOCKED` | No current accepted staging artifact exists. |
| 36 | Signing/runtime documented | `ENVIRONMENT_BLOCKED` | Strategy is documented, but release credentials/SHA registration are absent. |
| 37 | Worker endpoints verified | `ENVIRONMENT_BLOCKED` | No authorized staging endpoints exist to verify. |
| 38 | No known P0 remains | `PASS_AUTOMATED_TESTED` | P0-01 through P0-09 closed. |
| 39 | No known P1 remains | `ENVIRONMENT_BLOCKED` | P1-07 remains open. |
| 40 | P2/P3 debt documented | `PASS_SOURCE_REVIEWED` | Kotlin migration, dependency, Coach, and device/deployment debt listed. |
| 41 | Current reports agree | `PASS_SOURCE_REVIEWED` | Initial audit records initial FAIL; execution/readiness agree on current blocked status; old 4.6.2/4.6.3 reports are historical. |

## Blocking conditions

1. Exact approved staging Firebase project identity is unavailable. The
   checked-in `optivus-lifeos` identity is unclassified, not approved as
   staging.
2. Approved staging R2 upload, Routine Import, Nutrition, Skin Care, and Coach
   endpoints are unavailable, so health and response-contract checks cannot be
   performed.
3. `OPTIVUS_ANDROID_STORE_FILE`, `OPTIVUS_ANDROID_STORE_PASSWORD`,
   `OPTIVUS_ANDROID_KEY_ALIAS`, and `OPTIVUS_ANDROID_KEY_PASSWORD` are unset.
4. Release SHA-1/SHA-256 registration evidence is absent; `google-services.json`
   contains zero Android OAuth certificate-hash entries.
5. Consequently, no current configured/signed staging APK or AAB exists. A
   stale prior release APK is explicitly excluded.

## Smallest safe next action

Authorize the staging Firebase/Worker targets and make the release keystore
available through environment variables; register and record release SHA-1 and
SHA-256. Then probe each endpoint and its expected response contract, run the
redacted staging release command, record the artifact path/bytes/signing
identity, and rerun this 41-condition gate.

Final status: **BLOCKED — NOT READY FOR REAL-DEVICE TESTING**.
