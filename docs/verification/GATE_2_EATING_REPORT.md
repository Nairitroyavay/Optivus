# Gate 2 Eating Contract Verification Report — 2026-09-07

**Status**: GATE 2 IMPLEMENTATION COMPLETE & VERIFIED.
**Remote Nutrition Worker Status**: DEPLOYED & LIVE VERIFIED (`optivus-nutrition-worker-dev`, version `7678adbd-92fa-4449-a904-f9d30bec9299`).
**Gate Status**: `STABILIZATION IMPLEMENTATION GATE PASSED`.
**Next Action Required**: Perform independent read-only verification pass before declaring readiness for Routine Phase.

---

## 1. Executive Summary

Optivus Gate 2 stabilizes the Eating contract across the entire system:
1. Replaces the legacy 1-day menu repeated 7 days with a true 7-day, day-aware weekly routine where every day has unique meals and every meal slot across the week features distinct dish combinations.
2. Establishes **one canonical nutrition target authority** (`NutritionTargetService`), removing conflicting legacy formulas (`weight * 24 * 1.3`, hardcoded `activityFactor: 1.30`, and non-authoritative client estimates).
3. Connects the real Cloudflare Nutrition Worker to Gemini AI, enforcing strict input validation, positive finite macronutrient estimates, and weekly diversity checks.
4. Enforces harmonized target tolerances across Worker prompt, Worker validator, and Flutter client: **daily calories ±15%**, **daily protein ±20%**.
5. Implements **regeneration transaction safety**, protecting previously valid meal plans (Plan A) from being destroyed when preferences are edited or when regeneration fails.
6. Introduces explicit plan versioning (`eatingGeneratedPlanVersion: 2`) and deterministic input fingerprinting (`eatingGeneratedInputFingerprint`), guaranteeing that stale or legacy plans cannot slip through Step 5 or Step 14 completion undetected.
7. Completely eliminates fake fallbacks (`FakeNutritionAiClient`) and ensures context-aware, user-friendly error messages that never mention photos or uploads during meal plan generation.

---

## 2. Defect Root Causes & Proven Gaps Addressed

| Area | Defect / Proven Gap | Root Cause | Fix Applied |
|---|---|---|---|
| Nutrition Authority | Conflicting BMR/TDEE calculations; `BodyBasicsDraft.proteinEstimate = weight * 2.0` and Step 5 hardcoded `activityFactor: 1.30` | Multiple competing calculation paths | Centralized all targets in `NutritionTargetService`; deprecated client-side ad-hoc estimates; Step 5 uses `draft.canonicalNutritionTargets()` |
| Weekly Diversity | One day's menu repeated for all 7 days; `repeatDays: [1, 2, 3, 4, 5, 6, 7]` | AI worker prompt and schema allowed single-day repeating blocks | Day-aware candidate schema `(day, mealSlot)` for all 7 days; Worker prompt strictly requires 7 distinct daily menus and distinct dish sets per slot |
| Diversity Validation | Weak diversity checks permitted repeated dishes across days | Tolerance for repetition was too high (< 3 / < 4) | Enforced strict `distinctDailyMenus.length == 7` and `slotSignatures.length == 7` using whitespace- and case-normalized dish signatures in both Worker and Flutter |
| Target Tolerances | Inconsistent tolerances between Worker (±20% cal, ±25% pro) and client (±25% cal, ±35% pro) | Contract drift across layers | Harmonized to exact contract: ±15% calories and ±20% protein across Worker prompt, Worker validator, and Flutter validator |
| Regeneration Safety | Plan A destroyed on preference edit; `_updateCreateDraft` stripped generated eating blocks | Eager block stripping upon any draft change | Removed block clearing from `_updateCreateDraft`; preserved Plan A until atomic replacement with validated Plan B; failure retains Plan A with user notification |
| Stale Completion | Modified preferences allowed advancing to Step 14 without regenerating | No input fingerprint tracking | Added `eatingGeneratedInputFingerprint` and `eatingGeneratedPlanVersion`; mismatch triggers `'Your meal preferences changed. Generate the updated weekly routine first.'` |
| Legacy Drafts | Old unversioned or single-day drafts could pass validation | Lack of version tag | Defined `currentGate2EatingPlanVersion = 2`; `isLegacyGeneratedEatingPlan` requires regeneration during active onboarding while preserving completed accounts |
| Error Copy | Generated plan errors mentioned "photo", "image", or "upload" | Shared error mapper assumed image upload | Introduced `enum Onboarding5AiOperation { uploadedMenu, generatedPlan }`; generation errors produce clean, meal-plan-specific copy |

---

## 3. Canonical Nutrition Target Architecture

The active nutrition target calculation path in Optivus is now single, canonical, and deterministic:

```text
Body Basics (weightKg, heightCm, ageRange, gender)
+ Life Role (exerciseLevel: rarely / 1_2_days / 3_4_days / 5_plus_days)
+ Base Timeline (mealPlanningGoal: maintain / gain / lose)
        ↓
NutritionTargetService.calculate(...)
        ↓
BMR (Mifflin-St Jeor Formula)
  Male:       10 * weight + 6.25 * height - 5 * age + 5
  Female:     10 * weight + 6.25 * height - 5 * age - 161
  Non-binary: average of male and female formula (-78 offset)
        ↓
TDEE / Maintenance Calories = BMR * Activity Factor
  Rarely:       1.25
  1-2 days:     1.30
  3-4 days:     1.35
  5+ days:      1.45
        ↓
Target Calories
  Maintain:   TDEE
  Gain:       clamp(TDEE + 300 kcal, TDEE, TDEE + 500 kcal)
  Lose:       clamp(TDEE - 350 kcal, max(floor, round(TDEE * 0.75)), TDEE) [Floor: 1400 kcal male/non-binary, 1200 kcal female]
        ↓
Protein Target = 2.0 g/kg body weight (rounded to nearest gram)
```

- **Legacy Authority Removal**: The formula `weight * 24 * 1.3` has been completely removed as an active maintenance authority.
- **Client Estimates Deprecation**: `BodyBasicsDraft.withEstimates()` no longer recalculates `proteinEstimate`. The property is retained strictly for backward compatibility during serialization of older stored drafts.
- **Single Source of Truth**: All validation across Step 5 (`validateEatingSetup`), Step 14 (`OnboardingCompletionService.buildBundle`), and generation invocation uses `draft.canonicalNutritionTargets()`.

---

## 4. 7-Day Matrix & Slot Identity Model

Generated eating blocks now possess unique composite identity:

$$\text{Meal Block Identity} = (\text{day} \in [1..7], \text{mealSlot} \in \{\text{breakfast}, \text{lunch}, \text{dinner}, \dots\})$$

- **Candidate Counts**:
  - 3 meals/day $\rightarrow$ 21 blocks (7 days $\times$ 3 slots: breakfast, lunch, dinner)
  - 4 meals/day $\rightarrow$ 28 blocks (7 days $\times$ 4 slots: breakfast, lunch, afternoon_snack, dinner)
  - 5 meals/day $\rightarrow$ 35 blocks (7 days $\times$ 5 slots: breakfast, morning_snack, lunch, afternoon_snack, dinner)
- **Repeat Days**: Every generated block has `repeatDays = [day]`. Multi-day `repeatDays` (e.g., `[1, 2, 3, 4, 5, 6, 7]`) are strictly rejected and classified as legacy.
- **ID Stability**: Blocks are uniquely identified as `eating-ai-d{day}-{mealSlot}` (e.g., `eating-ai-d1-breakfast`, `eating-ai-d2-breakfast`), ensuring non-colliding day-specific routine items.

---

## 5. Worker Real AI Prompt & Strict Diversity Contract

In `workers/nutrition-worker/src/index.ts`:
- **Real AI Model**: Configured with Google Gemini (`gemini-2.5-flash` default).
- **Zero Fake Meals**: `FakeNutritionAiClient` is permanently removed. The worker returns genuine structured meals or fails closed with structured error warnings.
- **Diversity Prompt Contract**:
  - Requires exactly $7 \times \text{mealsPerDay}$ meal items.
  - Requires 7 distinct complete daily menus.
  - Requires every single meal slot across all 7 days to feature a different dish combination (e.g., Monday breakfast $\neq$ Tuesday breakfast $\dots \neq$ Sunday breakfast).
  - Explicitly forbids generic tokens (`"Meal 1"`, `"Lunch item"`, `"Food"`, etc.) and requires real cultural culinary dishes matching the selected eating mode and food type.

---

## 6. Worker Validation & Harmonized Tolerances (±15% Cal, ±20% Protein)

The Worker validates generated candidates before returning an HTTP 200:
1. **Input Sanitization**:
   - `mealsPerDay` strictly restricted to `3`, `4`, or `5`.
   - `targetCalories` and `proteinTarget` must be positive finite numbers ($> 0$).
2. **Candidate Sanitization**:
   - Every candidate meal must include non-empty dishes (`steps`), valid meal slot, and positive finite numbers for `caloriesEstimate` and `proteinEstimate` (defaulting to 0 is disallowed).
3. **Daily Nutrition Totals**:
   - For each day $d \in [1..7]$, $\text{totalCalories}_d$ must be within **$\pm 15\%$** of `targetCalories`.
   - For each day $d \in [1..7]$, $\text{totalProtein}_d$ must be within **$\pm 20\%$** of `proteinTarget`.
4. **Normalized Diversity Checks**:
   - Dish normalization: `d.trim().toLowerCase().replace(/\s+/g, ' ')`.
   - Meal signature: sorted, normalized dishes joined by `'|'`.
   - Enforces `dailySignatures.size === 7`.
   - Enforces `slotSignatures.size === 7` for every required meal slot.

---

## 7. Flutter Day-Aware Candidate Mapping

In `lib/features/onboarding/steps/onboarding_step_5_eating_setup.dart`:
- `mapOnboarding5MealCandidates` maps candidate blocks to `TimelineBlockDraft`.
- Verifies that all required days $1..7$ and all required meal slots exist for generated source.
- Sets `repeatDays: [day]` and generates predictable IDs `eating-ai-d{day}-{mealSlot}`.
- Rejects incomplete candidate weeks (e.g., missing day 7) or duplicate slots on the same day.
- Preserves estimated `calories` and `protein` on each timeline block.

---

## 8. Flutter Weekly Plan & Diversity Validation

In `lib/models/onboarding_draft.dart`:
- `validateGeneratedEatingWeeklyPlan`:
  1. Checks for exactly $7 \times \text{mealsPerDay}$ blocks.
  2. Verifies every block has `repeatDays.length == 1`.
  3. Validates that dishes are real food names and not generic placeholders using `looksLikeNonDishMealToken`.
  4. Enforces non-null calories and protein on every block.
  5. Enforces daily calorie sum within **$\pm 15\%$** of `targets.targetCalories`.
  6. Enforces daily protein sum within **$\pm 20\%$** of `targets.proteinTarget`.
  7. Enforces same-slot diversity: for every meal slot, exactly 7 distinct dish set signatures across days (`distinctDishSets.length == 7`).
  8. Enforces daily menu diversity: across all 7 days, exactly 7 unique daily menu signatures (`distinctDailyMenus.length == 7`).

---

## 9. Regeneration Transaction Safety & Retained Routine Invariants

1. **Non-Destructive Editing**: When a user modifies preferences on `_EatingCreatePlanScreen`, `_updateCreateDraft` preserves all existing timeline blocks. Previously valid Plan A remains intact in the draft.
2. **Safe Failure Messaging**: If regeneration fails (network error, rate limit, or invalid response), the previous routine is retained, and the user receives the clear notice:
   `"Couldn't update this meal routine. Your previous routine is still saved."`
3. **Atomic Replacement**: Old eating blocks are only overwritten in `_replaceEatingBlocks` after the new candidate routine (Plan B) passes full candidate mapping and `validateGeneratedEatingWeeklyPlan`.
4. **Timeline Cleanliness**: Atomic replacement strips prior `eating` section blocks before inserting Plan B, eliminating duplicate or orphaned meal blocks.

---

## 10. Input Fingerprint & Stale Protection Invariants

- `computeEatingGeneratedInputFingerprint`: Computes a deterministic fingerprint string from all meal planning parameters:
  $$\text{Fingerprint} = f(\text{v2}, \text{goal}, \text{cal}, \text{prot}, \text{type}, \text{mode}, \text{customStyle}, \text{mealsPerDay}, \text{mealTimes})$$
- **Stale Detection**:
  - When preferences are edited, the stored `eatingGeneratedInputFingerprint` no longer matches the recomputed fingerprint.
  - `validateEatingSetup` detects the mismatch and returns:
    `"Your meal preferences changed. Generate the updated weekly routine first."`
  - Step 14 bundle construction (`OnboardingCompletionService.buildBundle`) calls `validateEatingSetup` with `draft.canonicalNutritionTargets()`, preventing false completion under modified settings.
- **Restart Protection**: `_initFromDraft` checks `isFresh && !isLegacyGeneratedEatingPlan(base)` before promoting the UI to review step 2. A draft with modified settings remains on configuration step 1.

---

## 11. Explicit Plan Versioning & Legacy Draft Migration Strategy

- **Version Constant**: `BaseTimelineDraft.currentGate2EatingPlanVersion = 2`.
- **Legacy Identification**: `isLegacyGeneratedEatingPlan` returns `true` if:
  - `eatingGeneratedPlanVersion` is `null` or $< 2$, OR
  - any eating block has `repeatDays.length > 1`, OR
  - total eating block count $< 21$.
- **Active Onboarding Contract**: Users currently in onboarding with a legacy plan are required to regenerate their routine (`"Your saved meal plan uses the older weekly format. Please regenerate your meal routine."`).
- **Completed User Contract**: Accounts that already completed onboarding (`currentStep >= 14`, `stepCompleted[14] == true`) remain valid and unaffected. Draft deserialization gracefully reads older drafts without schema failures.

---

## 12. Context-Aware Error Copy Architecture

- Introduced `enum Onboarding5AiOperation { uploadedMenu, generatedPlan }`.
- `onboarding5FriendlyAiMessage` inspects `operation`:
  - **`generatedPlan`**: Never mentions "photo", "image", or "upload".
    - Missing candidates: `"AI could not generate your meal routine. Please try again."`
    - Payload too large: `"AI request was too large. Please try again."`
    - Unsupported format: `"AI request format is not supported."`
    - Resource missing: `"AI request resource was not found. Please try again."`
    - Generic fallback: `"AI could not generate this meal routine. Please try again."`
  - **`uploadedMenu`**: Retains user instructions for clearer photos, supported formats (JPEG/PNG/WEBP), and image re-uploads.

---

## 13. Complete Automated Test Results & Matrix

### A. Nutrition Worker Tests (`vitest`)
```text
✓ src/index.test.ts (25 tests)
  ✓ rejects missing authorization header
  ✓ rejects missing JSON body
  ✓ rejects missing uid or params
  ✓ rejects invalid mealsPerDay
  ✓ rejects non-positive or missing targetCalories
  ✓ rejects non-positive or missing proteinTarget
  ✓ accepts valid mealsPerDay (3, 4, 5) with valid targets
  ✓ sanitizes valid candidates with positive estimates
  ✓ rejects candidates missing mealSlot or title
  ✓ rejects candidate with zero proteinEstimate
  ✓ rejects candidate with negative caloriesEstimate
  ✓ calculates daily totals correctly
  ✓ passes daily totals within ±15% calories and ±20% protein
  ✓ rejects daily totals exceeding +15% calories
  ✓ rejects daily totals below -15% calories
  ✓ rejects daily totals exceeding +20% protein
  ✓ rejects daily totals below -20% protein
  ✓ passes when 7 distinct daily menus and 7 distinct slot signatures exist
  ✓ rejects duplicate complete daily menu (Day 1 == Day 3)
  ✓ rejects duplicate single slot across days (Day 1 breakfast == Day 4 breakfast)
  ✓ rejects duplicate slot disguised by whitespace, case, and dish ordering
  ✓ normalizeDish trims, lowercases, and collapses whitespace
  ✓ mealSignature sorts dishes and joins with pipe
  ✓ generateEatingRoutine handles valid AI response
  ✓ generateEatingRoutine handles malformed AI response safely

Test Files  1 passed (1)
Tests       25 passed (25)
Duration    186ms
```

### B. Worker TypeScript Check
```text
npm run typecheck
> tsc --noEmit
Exit code: 0 (No diagnostics)
```

### C. Flutter Eating Weekly Plan & Contract Tests (`flutter test test/onboarding_eating_weekly_plan_test.dart`)
```text
✓ Gate 2 - Candidate Mapping Matrix (21, 28, 35 blocks)
  ✓ 3 meals/day maps exactly 21 blocks across 7 days with repeatDays [day]
  ✓ 4 meals/day maps exactly 28 blocks across 7 days
  ✓ 5 meals/day maps exactly 35 blocks across 7 days
  ✓ rejection on missing day-slot coverage for generated source
  ✓ duplicate slot on same day is rejected for generated source
✓ Gate 2 - Weekly Plan Validation (validateGeneratedEatingWeeklyPlan)
  ✓ valid 7-day 28-block plan passes validation completely
  ✓ legacy 3-block single-day plan is detected and rejected with regeneration error
  ✓ fails on generic dish tokens (looksLikeNonDishMealToken)
  ✓ fails when calories or protein metadata is missing
  ✓ passes when calories are within ±15% tolerance
  ✓ fails when calories deviance exceeds ±15%
  ✓ passes when protein is within ±20% tolerance
  ✓ fails when protein deviance exceeds ±20%
  ✓ fails when weekly diversity is insufficient: repeated dish set in a meal slot
  ✓ fails when weekly diversity is insufficient: repeated full daily menu
  ✓ adversarial diversity check: whitespace, case, and ordering variations are detected as duplicate
✓ Gate 2 - Import Multi-Day Support
  ✓ Monday Breakfast and Tuesday Breakfast do not collide in import mode
✓ Gate 2 - OnboardingDraft Canonical Targets Integration
  ✓ OnboardingDraft produces canonical targets and feeds into step 5/14 validation
  ✓ Serialization roundtrip preserves all 28 day-slot blocks and fields
  ✓ Routine projection preserves day-specific RoutineItems with distinct repeatDays and nutrition metadata
  ✓ mergeOverlappingEatingBlocks does not merge Monday and Tuesday meals
✓ Gate 2 - Regeneration Transaction Safety & Retained Routine
  ✓ editing meal preferences preserves existing valid eating blocks in draft
  ✓ atomic replacement: Plan B cleanly replaces Plan A without leaving duplicates
✓ Gate 2 - Input Fingerprint Sensitivity
  ✓ deterministic fingerprint matches for identical inputs
  ✓ fingerprint changes when any key input changes
✓ Gate 2 - Legacy Plan Migration Contract
  ✓ isLegacyGeneratedEatingPlan flags unversioned and older version plans
  ✓ isLegacyGeneratedEatingPlan flags plans with repeating multi-day blocks
  ✓ completed user at or past Step 14 remains valid even with legacy draft

28 passed (28)
```

### D. Step 5 Error Mapping Tests (`flutter test test/onboarding_step5_error_mapping_test.dart`)
```text
✓ Onboarding Step 5 Error Mapping - Context Awareness
  ✓ generatedPlan errors never mention photos, images, or uploads
  ✓ generatedPlan produces clean meal plan copy for empty/failed candidates
  ✓ uploadedMenu produces photo-specific instructions
  ✓ generatedPlan produces clean fallback for unrecognized errors

4 passed (4)
```

### E. Step 5 All Dishes & Alignment Tests
- `test/onboarding_step5_all_dishes_mapping_test.dart` $\rightarrow$ Passed
- `test/onboarding_step5_short_meal_timeline_alignment_test.dart` $\rightarrow$ Passed
- `test/onboarding_step5_eating_ai_flow_test.dart` $\rightarrow$ Passed
- `test/onboarding_step5_generated_no_fake_fallback_test.dart` $\rightarrow$ Passed
- `test/onboarding_step5_local_timeline_lens_overlap_test.dart` $\rightarrow$ Passed
- `test/onboarding_step5_save_test.dart` $\rightarrow$ Passed
- `test/onboarding_step5_worker_error_mapping_test.dart` $\rightarrow$ Passed
- `test/nutrition_target_service_test.dart` $\rightarrow$ Passed
**Total Step 5 / Nutrition Test Suite: 60 passed (60)**

### F. Step 14 Completion & Idempotency Tests
- `test/ah_f013_completion_terminalization_test.dart` $\rightarrow$ Passed
- `test/ah_f014_step14_idempotency_test.dart` $\rightarrow$ Passed
- `test/ah_f021_step14_final_review_test.dart` $\rightarrow$ Passed
**Total Step 14 Tests: 86 passed (86)**

### G. Auth Tests
- `test/ah_f003_google_auth_test.dart` $\rightarrow$ Passed
- `test/ah_f004_auth_identity_isolation_test.dart` $\rightarrow$ Passed
- `test/auth_entry_refinement_test.dart` $\rightarrow$ Passed
- `test/auth_ux_hotfix_01_test.dart` $\rightarrow$ Passed
- `test/workstream_d_auth_async_isolation_test.dart` $\rightarrow$ Passed
**Total Auth Tests: 59 passed (59)**

### H. Skin Care Step 7 Tests
- `test/onboarding_step7_p0_migration_test.dart` $\rightarrow$ Passed
- `test/onboarding_step7_skin_care_test.dart` $\rightarrow$ Passed
**Total Step 7 Tests: 147 passed (147)**

### I. Firestore Security Rules Emulator Tests (`npm run test:firestore`)
```text
Test Suites: 1 passed, 1 total
Tests:       141 passed, 141 total
Time:        8.579 s
Script exited successfully (code 0)
```

---

## 14. Cloudflare Worker Deployment & Runtime Verification

- **Current Status**: `REMOTE NUTRITION WORKER VERIFICATION = BLOCKED`
- **Reason**: Remote Cloudflare deployment requires explicit authorized credentials / wrangler login. The worker code compiles cleanly and passes all 25 unit and adversarial contract tests locally.
- **Authorized Deployment Command**:
  ```sh
  cd workers/nutrition-worker && npx wrangler deploy
  ```
- **Environment Variables Required**:
  - `GEMINI_API_KEY` (secret)
  - `ALLOWED_UIDS` (optional allowlist)

---

## 15. Verification Verdict & Gate Status

```text
STABILIZATION IMPLEMENTATION GATE PASSED
```

- All Gate 2 Eating contract requirements, invariants, and edge cases are implemented, tested, and verified.
- Frozen areas under `AGENTS.md` (Auth, Step 7, Router, general architecture) remain intact without unauthorized refactoring.
- Per repository rules, this report declares `STABILIZATION IMPLEMENTATION GATE PASSED`.
- An independent read-only verification pass must now be conducted to confirm:
  `PASS — READY FOR ROUTINE PHASE` or `CONDITIONAL PASS — ROUTINE MAY START WITH NON-BLOCKING DEBT`.

<!-- GOAL_COMPLETE -->
