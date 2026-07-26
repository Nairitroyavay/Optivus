## 2026-07-25T21:17:15Z

You are worker_group_e_1 working on Group E (Issues 22 through 28: Skin-Care Generation & Safety Consistency).

Your Working Directory: /Users/roy/optivus2/Optivus/.agents/worker_group_e_1

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Your objective:
Implement clean, robust, zero-side-effect, R11 backward-compatible solutions for all 7 issues in Group E based on the Explorer handoff report (`/Users/roy/optivus2/Optivus/.agents/explorer_group_e_1/handoff.md`).

Summary of fixes to implement:
1. **Issue 22 (Payload Validation)**:
   - Implement `SkinCareWorkerPayloadValidator` in `lib/services/skin_care_ai_client.dart`.
   - Validate array bounds (`productPhotos` count <= 10, non-empty photos), `desiredApplicationsPerDay` range 2-4, valid enum strings (`skinType`, `budget`, `routinePreference`), and typed product details maps (max 20 products, non-empty names).
   - Validate before dispatching POST request in `WorkerSkinCareAiClient.generateRoutine` and `analyzeProducts`. Return `SkinCareAiRoutineResult.error(...)` with `errorCode: 'client_payload_validation_error'` if invalid.

2. **Issue 23 (Contraindications)**:
   - Implement `SkinCareContraindicationDetector` engine in `lib/services/skin_care_ai_client.dart` and integrate into `lib/features/routine/managers/base_timeline/screens/skin_care_routine_setup_screen.dart` and `SkinCareRoutinePlan.fromMap`.
   - Detect conflicting active pairs in the same routine slot:
     - `Retinol` + `AHA/BHA/Exfoliants`
     - `Vitamin C` + `AHA/BHA`
     - `Retinol` + `Vitamin C`
     - `Benzoyl Peroxide` + `Retinol`
     - `Duplicate Actives` (e.g. multiple retinoids or multiple BHA exfoliants in one slot).
   - Return `List<SkinCareContraindicationWarning>` and display soft warning cards in review/manual screens without deleting user steps.

3. **Issue 24 (Schedule Frequency & Minimum Rest Hours)**:
   - Implement `SkinCareScheduleEnforcer` in `lib/services/skin_care_ai_client.dart` and `lib/features/routine/managers/base_timeline/screens/skin_care_routine_setup_screen.dart`.
   - Enforce max 4 applications per day and minimum 4-hour (240 minutes) rest intervals between applications (`(start_B - start_A) >= 240`).

4. **Issue 25 (Photo Upload Signed R2 URL Error Handling)**:
   - Create typed exception hierarchy in `lib/services/uploads/r2_upload_service.dart` (`SkinCarePhotoUploadException`, `R2UploadExpiredUrlException`, `R2UploadNetworkException`, `R2UploadHttpResponseException`, `R2UploadMarkCompleteException`).
   - Check `signedUpload.expiresAt` before initiating upload in `R2UploadService.uploadPreparedImage`. If expired, throw `R2UploadExpiredUrlException`.
   - Wrap upload calls to handle network drops and HTTP non-200 status codes gracefully.
   - Update `OnboardingStep7` UI error state handling to present informative retry options for typed exceptions.

5. **Issue 26 (AI Generation Offline Fallback)**:
   - Implement `OfflineSkinCareRoutineGenerator` in `lib/services/skin_care_ai_client.dart`.
   - When worker service fails, times out, or returns `hasError`, automatically generate a safe, rule-based fallback routine from user products/details with proper 5-step ordering and warning metadata, ensuring non-blocking onboarding step 7 progression.

6. **Issue 27 (Step Sequence Validation)**:
   - Implement `SkinCareStepSequenceValidator` in `lib/services/skin_care_ai_client.dart`.
   - Categorize steps into 5 physiological ranks: 1. Cleanser -> 2. Toner/Exfoliant -> 3. Active Serum/Treatment -> 4. Moisturizer -> 5. Sunscreen (day) / Facial Oil (night).
   - Reorder out-of-sequence steps automatically and attach `sequenceAdjustedWarning`.

7. **Issue 28 (Review State Persistence)**:
   - Ensure all Step 7 review modifications (edited products, steps, times, toggled recommendations, special care notes) trigger `updateBaseTimelineDraft` in Riverpod state (`onboarding_step_7_skin_care_setup.dart`).
   - Verify `OnboardingCompletionService._scheduleRoutineItems` projects updated `TimelineBlockDraft` fields into committed active `RoutineItem`s.

Verification Tasks for Worker:
1. Create targeted test suite `test/group_e_issues_22_to_28_test.dart` reproducing and validating all 7 issues.
2. Run existing related test suites (`test/onboarding_step7_skin_care_test.dart`, `test/upload_phase2a_test.dart`, `test/ai_workers_config_test.dart`).
3. Run `dart format .` on all changed files.
4. Run `flutter analyze` ensuring 0 errors / 0 lints.
5. Update `docs/onboarding_stabilization_report.md` marking Group E (Issues 22-28) as `PASSED` with complete details (root causes, files changed, fixes implemented, targeted & regression tests, evidence).
6. Send handoff report and message back to parent when complete.
