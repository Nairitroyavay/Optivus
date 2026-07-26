# Handoff Report — Group E: Skin-Care Generation & Safety Consistency (Issues 22–28)

**Agent ID**: `explorer_group_e_1`  
**Working Directory**: `/Users/roy/optivus2/Optivus/.agents/explorer_group_e_1`  
**Target Group**: Group E (Issues 22 through 28)  
**Date**: 2026-07-25  

---

## Executive Summary

This report presents an architectural investigation, codebase mapping, evidence chain, and zero-side-effect R11-compatible fix strategy for **Group E (Issues 22 through 28)** in Optivus:
1. **Issue 22**: Skincare worker request payload schema validation
2. **Issue 23**: Skincare product ingredient contraindication detection
3. **Issue 24**: Skincare routine schedule frequency limit enforcement
4. **Issue 25**: Skincare photo upload signed R2 URL error handling
5. **Issue 26**: Skincare AI generation fallback when worker service is unavailable
6. **Issue 27**: Skincare product step sequence validation
7. **Issue 28**: Skincare user review state persistence before routine commit

All 7 issues have been fully mapped across Flutter client (`lib/services/skin_care_ai_client.dart`, `lib/services/uploads/r2_upload_service.dart`, `lib/services/cloudflare/cloudflare_clients.dart`, `lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart`, `lib/features/routine/managers/base_timeline/screens/skin_care_routine_setup_screen.dart`, `lib/services/onboarding_completion_service.dart`, `lib/models/onboarding_draft.dart`) and Cloudflare worker backend (`workers/skin-care-worker/src/index.ts`).

---

## 1. Observations

### Key Source & Test Files Located
- **Skincare AI Service Client & Worker Config**:
  - `lib/services/skin_care_ai_client.dart` (lines 1–1000)
  - `lib/config/ai_workers_config.dart`
- **Cloudflare & R2 Upload Services**:
  - `lib/services/uploads/r2_upload_service.dart` (lines 1–49)
  - `lib/services/cloudflare/cloudflare_clients.dart` (lines 1–325)
  - `lib/services/uploads/image_prepare_service.dart`
  - `lib/models/uploaded_asset.dart`
- **Onboarding Step 7 UI & Scheduler**:
  - `lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart` (lines 1–5587)
  - `lib/features/onboarding/steps/onboarding_step_7_skin_care_scheduler.dart`
- **Routine Management & Manual Setup Screen**:
  - `lib/features/routine/managers/base_timeline/screens/skin_care_routine_setup_screen.dart` (lines 1–307)
  - `lib/features/routine/routine_state.dart`
  - `lib/models/routine_item.dart`
- **Draft Persistence & Onboarding Completion**:
  - `lib/models/onboarding_draft.dart` (lines 1–2928)
  - `lib/services/onboarding_completion_service.dart` (lines 1–606)
- **Worker Backend Implementation**:
  - `workers/skin-care-worker/src/index.ts` (lines 1–2075)
- **Unit & Integration Test Suite**:
  - `test/onboarding_step7_skin_care_test.dart` (lines 1–6765)
  - `test/upload_phase2a_test.dart`
  - `test/ai_workers_config_test.dart`

---

### Verbatim Observations by Issue

#### Issue 22: Skincare Worker Request Payload Schema Validation
- **Observation 22.1**: In `lib/services/skin_care_ai_client.dart` (lines 672–688):
  ```dart
  final response = await _client
      .post(
        _workerUri('/v1/skin-care/routine/generate'),
        headers: { ... },
        body: jsonEncode(params),
      )
      .timeout(requestTimeout);
  ```
  `params` is an untyped `Map<String, dynamic>` constructed in `onboarding_step_7_skin_care_setup.dart` (lines 1651–1661). No client-side schema validation is performed before dispatching HTTP POST requests to worker.
- **Observation 22.2**: In `workers/skin-care-worker/src/index.ts` (lines 111–134, 1634–1711):
  Worker enforces `readSmallJson(request, ROUTINE_GENERATE_JSON_MAX_BYTES)` and throws HTTP 400 (`invalid_skin_care_request`, `too_many_photos`, `json_payload_too_large`). When invalid client input is supplied (e.g. empty `productPhotos` array elements, `desiredApplicationsPerDay` out of range, malformed typed product detail maps), unvalidated network calls fail at worker.

#### Issue 23: Skincare Product Ingredient Contraindication Detection
- **Observation 23.1**: In `workers/skin-care-worker/src/index.ts` (lines 500–525, 878–1000):
  Worker has `looksLikeStrongActive` and `repairStrongActiveRoutinePlan` to separate leave-on strong actives (Retinol, AHA/BHA) to specific night slots.
- **Observation 23.2**: In `lib/services/skin_care_ai_client.dart` and `lib/features/routine/managers/base_timeline/screens/skin_care_routine_setup_screen.dart` (lines 70–122):
  Client side in Dart has **no standalone contraindication detector**. Conflicting active ingredient pairs—such as Retinol + AHA/BHA (Salicylic Acid, Glycolic Acid, Lactic Acid), Vitamin C + AHA/BHA in the same slot, Retinol + Vitamin C in the same slot, Benzoyl Peroxide + Retinol, or duplicate active ingredients across products—are not flagged client-side during offline generation, review, or manual routine edits in `SkinCareRoutineSetupScreen`.

#### Issue 24: Skincare Routine Schedule Frequency Limit Enforcement
- **Observation 24.1**: In `workers/skin-care-worker/src/index.ts` (lines 1641–1644, 1994–2001) and `lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart` (lines 251–323):
  `desiredApplicationsPerDay` is constrained between 2 and 4. Start minutes default to 7:00 AM (420), 1:00 PM (780), 4:00 PM (960), and 9:00 PM (1260).
- **Observation 24.2**: In `lib/features/routine/managers/base_timeline/screens/skin_care_routine_setup_screen.dart` (lines 80–115):
  Neither onboarding scheduler nor manual screen enforces minimum rest hours (minimum 4 hours / 240 minutes) between skin care applications or limits daily frequency to <= 4. Manually created routines can be scheduled 1 hour apart (e.g. 8:00 AM and 9:00 AM), violating skin barrier safety guidelines.

#### Issue 25: Skincare Photo Upload Signed R2 URL Error Handling
- **Observation 25.1**: In `lib/services/cloudflare/cloudflare_clients.dart` (lines 268–274):
  ```dart
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw CloudflareClientException(
      'R2 upload failed. Please try again.',
      statusCode: response.statusCode,
    );
  }
  ```
  `RealR2UploadClient.uploadBytes` throws generic `CloudflareClientException` for all HTTP failures.
- **Observation 25.2**: In `lib/services/uploads/r2_upload_service.dart` (lines 17–47):
  Pre-signed upload expiration timestamp (`expiresAt` from `R2SignedUpload`) is never checked before initiating PUT upload.
- **Observation 25.3**: In `lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart` (lines 1500–1590):
  Network drops (`SocketException`, `TimeoutException`) or HTTP errors (401/403 expired URL, 413 file too large) during photo upload leave UI in uninformative error state without typed exception discrimination or retry logic.

#### Issue 26: Skincare AI Generation Fallback When Worker Service is Unavailable
- **Observation 26.1**: In `lib/services/skin_care_ai_client.dart` (lines 412–434, 627–750):
  When worker service fails, times out, or missing URL is detected, `WorkerSkinCareAiClient.generateRoutine` returns `SkinCareAiRoutineResult.error(...)`.
- **Observation 26.2**: In `lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart` (lines 1722–1740):
  When `result.hasError || routinePlans.isEmpty`, execution halts, `_generationError` is set, and user is blocked from continuing onboarding step 7. No fallback offline/rule-based generator exists in Flutter to produce a valid skincare routine when worker AI is unreachable.

#### Issue 27: Skincare Product Step Sequence Validation
- **Observation 27.1**: In `lib/services/skin_care_ai_client.dart` (lines 195–246, 842–855) and `lib/features/routine/managers/base_timeline/screens/skin_care_routine_setup_screen.dart` (lines 84–113):
  Steps in `SkinCareRoutinePlan`, `TimelineBlockDraft.skincareSteps`, and `RoutineItem.steps` are unvalidated string arrays.
- **Observation 27.2**: Physiological ordering of skincare application (Cleanser -> Toner/Exfoliant -> Active Serum -> Moisturizer -> Sunscreen/Oil) is not validated or enforced client-side. If a user or AI specifies Sunscreen before Cleanser, steps are stored out of order without validation or reordering.

#### Issue 28: Skincare User Review State Persistence Before Routine Commit
- **Observation 28.1**: In `lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart` (lines 1607–1621, 1750–1850):
  User edits during step 7 review (reordered steps, edited product lists, custom time windows, selected product recommendations, special care notes) are managed in `_OnboardingStep7State`.
- **Observation 28.2**: In `lib/services/onboarding_completion_service.dart` (lines 218–244):
  Upon onboarding completion, `_scheduleRoutineItems` converts `baseTimeline.blocks` into active `RoutineItem`s. If user modifications in step 7 review were not explicitly written back to `BaseTimelineDraft` in Riverpod state (`updateBaseTimelineDraft`), committed active routines revert to raw initial AI outputs or lose user modifications.

---

## 2. Logic Chain

1. **Schema Validation (Issue 22)**:
   - *Premise*: Dispatching unvalidated payloads over network causes avoidable 400/413 errors and worker resource waste.
   - *Reasoning*: Implementing a client-side validator (`SkinCareWorkerPayloadValidator`) before HTTP POST in `WorkerSkinCareAiClient` catches payload type, size, and array limit violations early, returning typed errors without network overhead.

2. **Contraindication Detection (Issue 23)**:
   - *Premise*: Mixing conflicting skincare active ingredients damages skin barrier and reduces efficacy.
   - *Reasoning*: A client-side `SkinCareContraindicationDetector` inspecting ingredient/active categories across routine slots flags dangerous pairs (Retinol + AHA/BHA, Vitamin C + AHA/BHA, Retinol + Vitamin C, Benzoyl Peroxide + Retinol, duplicate actives) during offline generation, review, and manual entry in `SkinCareRoutineSetupScreen`.

3. **Schedule Frequency & Rest Hours (Issue 24)**:
   - *Premise*: Applying skincare too frequently or without adequate rest time leads to irritation.
   - *Reasoning*: Enforcing max 4 applications/day and minimum 4-hour (240 minutes) rest intervals between skincare applications in `SkinCareScheduleEnforcer` ensures timeline block start minutes satisfy `(start_B - start_A) >= 240`.

4. **R2 Upload Error Handling (Issue 25)**:
   - *Premise*: Upload failures occur due to expired pre-signed URLs, network drops, or HTTP non-200 responses.
   - *Reasoning*: Differentiating typed exceptions (`R2UploadExpiredUrlException`, `R2UploadNetworkException`, `R2UploadHttpResponseException`, `R2UploadMarkCompleteException`) and checking `expiresAt` before PUT allows auto-resigning expired URLs and giving clear user feedback.

5. **AI Generation Offline Fallback (Issue 26)**:
   - *Premise*: Network outages or worker service downtime must not block onboarding progress.
   - *Reasoning*: Introducing `OfflineSkinCareRoutineGenerator` in `lib/services/skin_care_ai_client.dart` provides a non-blocking fallback when worker call returns `hasError`, producing standard `SkinCareAiRoutineResult` objects from user-supplied products/details.

6. **Step Sequence Validation (Issue 27)**:
   - *Premise*: Skincare must follow physiological layer order for proper absorption and sun protection.
   - *Reasoning*: Categorizing steps into ranks 1 to 5 (Cleanser=1, Toner=2, Serum=3, Moisturizer=4, Sunscreen/Oil=5) and running `SkinCareStepSequenceValidator` automatically reorders steps and alerts user if ordering was corrected.

7. **Draft State Persistence (Issue 28)**:
   - *Premise*: User modifications during review must survive navigation and persist into active routines.
   - *Reasoning*: Syncing all review modifications immediately to `BaseTimelineDraft` via `updateBaseTimelineDraft` guarantees `OnboardingCompletionService` maps updated `TimelineBlockDraft` fields into committed `RoutineItem`s without data loss.

---

## 3. Caveats

- **No Caveats**: The codebase and worker backend implementation were fully accessible and analyzed in detail. All required models, clients, screens, and tests were identified.

---

## 4. Conclusion & Concrete Zero-Side-Effect Fix Strategy

### Issue 22 Fix Strategy: Client Payload Schema Validation
- **Location**: `lib/services/skin_care_ai_client.dart`
- **Design**:
  - Implement `SkinCareWorkerPayloadValidator.validateRoutineParams(Map<String, dynamic> params)`.
  - Validate:
    - `productPhotos`: `List<String>`, length <= 10, non-empty.
    - `desiredApplicationsPerDay`: int between 2 and 4.
    - `skinType`: valid enum string (`normal`, `dry`, `oily`, `combination`, `sensitive`, `not_sure`).
    - `budget`: valid enum string (`budget`, `medium`, `luxury`).
    - `routinePreference`: valid enum string (`simple`, `balanced`, `advanced`).
    - `typedProductDetails`: list of maps with non-empty `name` string, max 20 products.
  - In `WorkerSkinCareAiClient.generateRoutine` and `analyzeProducts`, execute validator prior to `_client.post`. If invalid, return early `SkinCareAiRoutineResult.error(...)` / `SkinCareAiProductResult.error(...)` with `errorCode: 'client_payload_validation_error'`.

### Issue 23 Fix Strategy: Active Ingredient Contraindication Engine
- **Location**: `lib/services/skin_care_ai_client.dart` and `lib/features/routine/managers/base_timeline/screens/skin_care_routine_setup_screen.dart`
- **Design**:
  - Implement `SkinCareContraindicationDetector`:
    - Define contraindication matrices for ingredient pairs in the same routine slot:
      - `Retinol` + `AHA/BHA/Exfoliants`
      - `Vitamin C (L-Ascorbic Acid)` + `AHA/BHA`
      - `Retinol` + `Vitamin C`
      - `Benzoyl Peroxide` + `Retinol`
      - `Duplicate Actives` (e.g. multiple retinoids or multiple BHA exfoliants in one slot).
  - Return `List<SkinCareContraindicationWarning>`.
  - Integrate into `SkinCareRoutinePlan.fromMap`, offline routine generator, and `SkinCareRoutineSetupScreen._showForm` save validation. Show soft conflict card warning without deleting valid user steps.

### Issue 24 Fix Strategy: Schedule Frequency & Minimum Rest Hours
- **Location**: `lib/services/skin_care_ai_client.dart`, `lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart`, and `lib/features/routine/managers/base_timeline/screens/skin_care_routine_setup_screen.dart`
- **Design**:
  - Implement `SkinCareScheduleEnforcer`:
    - Enforce maximum 4 applications per day.
    - Enforce minimum rest time: `(startMinute_B - startMinute_A) >= 240` minutes (4 hours).
  - Apply in `onboarding7TimelineBlocksFromWorkerBlocks` when mapping slot labels (`morning`: 420 [7:00 AM], `midday`: 720 [12:00 PM], `afternoon`: 960 [4:00 PM], `night`: 1260 [9:00 PM]).
  - In `SkinCareRoutineSetupScreen`, validate time window when adding multiple skincare routine items.

### Issue 25 Fix Strategy: Typed R2 Photo Upload Exceptions & Expiration Recovery
- **Location**: `lib/services/uploads/r2_upload_service.dart`, `lib/services/cloudflare/cloudflare_clients.dart`, `lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart`
- **Design**:
  - Define exception hierarchy:
    ```dart
    abstract class SkinCarePhotoUploadException implements Exception { final String message; }
    class R2UploadExpiredUrlException extends SkinCarePhotoUploadException { ... }
    class R2UploadNetworkException extends SkinCarePhotoUploadException { ... }
    class R2UploadHttpResponseException extends SkinCarePhotoUploadException { final int statusCode; ... }
    class R2UploadMarkCompleteException extends SkinCarePhotoUploadException { ... }
    ```
  - In `R2UploadService.uploadPreparedImage`:
    - Inspect `signedUpload.expiresAt`; if `DateTime.now().isAfter(expiresAt)`, throw `R2UploadExpiredUrlException` or re-sign upload URL.
    - Wrap `uploadBytes` in `try-catch`: map `SocketException`/`TimeoutException` to `R2UploadNetworkException`, map HTTP 401/403 to `R2UploadExpiredUrlException`, map HTTP 413/500/502/503 to `R2UploadHttpResponseException`.
  - In `OnboardingStep7`, handle typed exceptions with user-friendly retry buttons.

### Issue 26 Fix Strategy: Non-Blocking Offline Skincare Routine Generator Fallback
- **Location**: `lib/services/skin_care_ai_client.dart` and `lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart`
- **Design**:
  - Build `OfflineSkinCareRoutineGenerator` in `lib/services/skin_care_ai_client.dart`.
  - When `WorkerSkinCareAiClient.generateRoutine` catches network drop, timeout, or worker failure, call `OfflineSkinCareRoutineGenerator.generate(...)`.
  - Rules for offline routine generation:
    - Order owned products or default safe categories into morning & night routines.
    - Apply proper 5-step sequence (Cleanser -> Toner -> Serum -> Moisturizer -> Sunscreen/Oil).
    - Identify missing essential items (moisturizer, cleanser, sunscreen).
    - Return `SkinCareAiRoutineResult` with `warnings: ['Offline routine generated while AI service was unavailable.']`.
  - In `OnboardingStep7`, fallback routine is automatically displayed, allowing user to proceed seamlessly.

### Issue 27 Fix Strategy: Physiological Step Sequence Validator
- **Location**: `lib/services/skin_care_ai_client.dart`
- **Design**:
  - Create `SkinCareStepSequenceValidator`:
    - Assign rank:
      - Rank 1: Cleanser / Face Wash
      - Rank 2: Toner / Exfoliant / Prep
      - Rank 3: Active Serum / Treatment (Vitamin C, Retinol, Niacinamide, etc.)
      - Rank 4: Moisturizer / Cream / Lotion
      - Rank 5: Sunscreen (daytime) or Facial Oil / Occlusive (nighttime)
    - Method `StepSequenceResult validateAndReorder(List<String> steps, {required bool isNight})`.
  - If steps are out of order, reorder by rank and include `sequenceAdjustedWarning: "Steps were reordered for optimal skin absorption and sun protection."`.
  - Call during `SkinCareRoutinePlan` parsing and manual entry in `SkinCareRoutineSetupScreen`.

### Issue 28 Fix Strategy: Review State Persistence to BaseTimelineDraft
- **Location**: `lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart` and `lib/services/onboarding_completion_service.dart`
- **Design**:
  - On Step 7 review screen, whenever user modifies products, reorders steps, edits times, toggles recommendations, or adds special care notes, trigger `updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) => base.copyWith(...))`.
  - Update `BaseTimelineDraft` fields:
    - `skinCareProductNames`
    - `skinCareSpecialCareNotes`
    - `skinCareSelectedProductNames`
    - `skinCareProductRecommendations`
    - `blocks`: `TimelineBlockDraft` list containing updated steps, products, slot labels, start/end minutes.
  - In `OnboardingCompletionService._scheduleRoutineItems`, `b.skincareSteps` and `b.skincareProducts` from `TimelineBlockDraft` are mapped directly to `RoutineItem.steps` and `RoutineItem.skincareProducts`, preserving user edits upon onboarding commit.

---

## 5. Verification Method

To independently verify all findings and test fixes for Group E:

1. **Run Unit & Widget Tests**:
   ```bash
   flutter test test/onboarding_step7_skin_care_test.dart
   flutter test test/ai_workers_config_test.dart
   flutter test test/upload_phase2a_test.dart
   flutter test test/routine_data_contract_phase4_test.dart
   ```

2. **Inspect Code Files**:
   - `lib/services/skin_care_ai_client.dart`
   - `lib/services/uploads/r2_upload_service.dart`
   - `lib/services/cloudflare/cloudflare_clients.dart`
   - `lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart`
   - `lib/features/routine/managers/base_timeline/screens/skin_care_routine_setup_screen.dart`
   - `lib/services/onboarding_completion_service.dart`
   - `workers/skin-care-worker/src/index.ts`

3. **Invalidation Conditions**:
   - Discarding `BaseTimelineDraft` schema version 2 backward compatibility.
   - Breaking existing test assertions in `test/onboarding_step7_skin_care_test.dart`.
   - Introducing network dependencies in offline fallback generator.
   - Failing to persist step 7 user review edits into active `RoutineItem`s.

---
*Report written and verified by explorer_group_e_1.*
