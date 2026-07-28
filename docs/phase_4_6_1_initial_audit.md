# Phase 4.6.1 Initial Audit
Date: 2026-07-28
Commit: 575b992ec42f94d5694ba28ea78a5dcbf6ea38fc
Branch: main

## Execution Path Trace
Application startup -> Firebase initialization -> Signup -> User-profile creation -> Email verification -> Login -> Profile restoration -> Settings restoration -> Onboarding -> Draft persistence -> Bundle persistence -> Routine reconciliation -> Routine History -> Habit reconciliation -> Controller reload -> Frontend verification -> Profile finalization -> Router transition -> Home -> Cold restart -> Sign out -> Sign in -> Account switch -> Recovery

## P0-01 User-profile Firestore contract mismatch
- Production Serializer: `UserProfile.toFirestoreMap()`
- Firestore Rule: `validUserProfileKeys` and `validUserProfile`
- Status: **FAIL** - `UserProfile` writes `uid`, `email`, `displayName`, `accountStatus`, `createdAt`, `updatedAt`, `onboardingInputCompleted`, `onboardingProjectionStatus`, `onboardingCompleted`, `onboardingStep`, `lifeRole`, `workingExtra`, `businessMode`, `exerciseLevel`, `waterIntake`, `stressLevel`, `sleepQuality`, `ageRange`, `height`, `weight`, `gender`, `bmiEstimate`, `calorieEstimate`, `proteinEstimate`, `coachName`, `coachStyle`, `slipUpStyle`. The rules require additional fields or restrict certain writes incorrectly. `schemaVersion` is missing in `toFirestoreMap`.

## P0-02 Onboarding completion-job contract mismatch
- Production Serializer: `OnboardingCompletionJob.toMap()`
- Firestore Rule: `validOnboardingCompletionJob`
- Status: **FAIL** - Production writes extensive tracking/accounting fields (e.g. `failedEntityIds`, `retryCount`, `expectedRoutineIds`). Rule only allows 7 basic fields: `jobId`, `ownerUid`, `stage`, `status`, `createdAt`, `updatedAt`, `schemaVersion`.

## P0-03 Settings Firestore contract mismatch
- Production Serializer: `RegionSettings.toFirestoreMap()`
- Firestore Rule: `validSettingsDoc`
- Status: **FAIL** - Production writes 18+ fields (e.g., `countryCode`, `timezone`, `languageCode`). Rule explicitly only allows: `["id", "locale", "timeFormat", "themeMode", "notificationsEnabled", "updatedAt", "createdAt"]`.

## P0-04 Unsafe recovery fabrication
- Identified Locations: `OnboardingRecoveryTier.tier3Synthesized`, `SynthesizeBundleAction`.
- Status: **FAIL** - The application has code paths that synthesize missing bundles or fake data.

## P0-05 Final draft durability
- Status: **NOT VERIFIED** - Needs code trace in persistence step.

## P0-06 Profile finalization integrity
- Status: **NOT VERIFIED** - Needs code trace on `onboardingCompleted=true`.

## P1-01 Firebase initialization failure is swallowed
- Status: **NOT VERIFIED** - Needs check in `lib/main.dart` or Firebase initializer.

## P1-02 Completion state machine is too coarse
- Status: **FAIL** - `OnboardingCompletionStage` only has 7 stages.

## P1-03 Completion accounting fields are not populated
- Status: **NOT VERIFIED** - Need to verify if the service actually populates them properly.

## P1-04 Typed failures are disconnected
- Status: **NOT VERIFIED** - Need to verify usage of `OnboardingCompletionFailureException`.

## P1-05 Sign-out and account-switch race
- Status: **NOT VERIFIED** - Need to check session validation.

## P1-06 Routine History gap for mixed create/repair outcomes
- Status: **NOT VERIFIED** - Need to check RoutineHistoryGenerator.

## P1-07 Release build and runtime configuration are not fully proven
- Status: **NOT VERIFIED** - Need to build release and verify.
