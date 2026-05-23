# Optivus Auth & Onboarding Backend Handoff

> This document details the fake auth architecture and onboarding foundation built during the testing phase. It explains how to replace the fake implementations with real Firebase services in the future.

## 1. Current Fake Auth Architecture

Currently, the app uses a clean repository pattern to mock authentication. This allows for rapid UI and flow testing without making actual network requests to Firebase.

- **`AuthRepository` Interface**: Defines the contract for all authentication operations (`login`, `signup`, `logout`, `authStateChanges`).
- **`FakeAuthRepository`**: A mock implementation of the interface that simulates network delays, maintains local session state, and creates seed `UserModel` and `OnboardingDraft` instances upon signup/login.
- **`AuthNotifier`**: Manages the reactive state (`AuthState`) of the user's session and bridges the gap between the repository and Riverpod providers (`mockUserProfileProvider`, `mockOnboardingProvider`).
- **`RouterNotifier`**: Subscribes to changes in `AuthState` and `UserProfile` to dynamically redirect users using `GoRouter`.
  - Unauthenticated -> `/` (Welcome/Login/Signup)
  - Authenticated + `onboardingCompleted == false` -> `/onboarding`
  - Authenticated + `onboardingCompleted == true` -> `/app`

## 2. Future Firebase Integration

To integrate real Firebase Auth and Firestore, follow these steps:

### A. Auth Integration

1. Create a `FirebaseAuthRepository` that implements `AuthRepository`.
2. Update the implementation to use `FirebaseAuth.instance`:
   - `login`: `signInWithEmailAndPassword`
   - `signup`: `createUserWithEmailAndPassword`
   - `logout`: `signOut`
   - `authStateChanges`: Listen to `FirebaseAuth.instance.authStateChanges()`
3. In `lib/state/auth_state.dart`, replace the instance of `FakeAuthRepository` with `FirebaseAuthRepository`.
4. Ensure `FirebaseAuthRepository` creates or fetches the user's document from Firestore upon successful login/signup.

### B. Firestore Schema and Path Expectations

When implementing the Firestore sync, use the following paths:

- **User Document**: `/users/{uid}`
  - Contains core user data: `uid`, `name`, `email`, `createdAt`, `updatedAt`, `onboardingCompleted`, `onboardingStep`.
- **Onboarding Draft**: `/users/{uid}/onboarding/draft`
  - Contains the in-progress onboarding state. Use `OnboardingDraft.toMap()` to write and `OnboardingDraft.fromMap()` to read.

### C. Onboarding Completion Flow

1. Currently, `OnboardingDraft` handles save operations locally by updating the `mockOnboardingProvider` state.
2. When real backend sync is implemented, update the `_saveStep` method in `lib/features/onboarding/onboarding_flow.dart` to write the draft to Firestore:
   - `FirebaseFirestore.instance.doc('users/${uid}/onboarding/draft').set(draft.toMap())`
3. When the user taps "Enter Optivus" in Step 11:
   - Mark the draft as completed.
   - Update the `/users/{uid}` document to set `onboardingCompleted = true`.
   - Clear the local draft from state if desired, or keep it as a read-only reference.

## 3. Data Models

The data models have been made backend-ready with robust serialization methods.

- **`UserModel` / `UserProfile`**: 
  - Fields: `uid`, `name`, `email`, `createdAt`, `updatedAt`, `onboardingCompleted`.
  - Methods: `toMap()`, `fromMap()`, `copyWith()`.
- **`OnboardingDraft`**:
  - Fields: `uid`, `stepCompleted`, `stepDirty`, `stepLoading`, `createdAt`, `updatedAt`, `onboardingCompleted`, plus all specific step data (`lifeRole`, `bodyBasics`, etc.).
  - Methods: `toMap()`, `fromMap()`, `copyWith()`.
  - Internal states (like enums) use canonical string keys (e.g., `student_working`, `flexible_business`) mapped accurately for backend consumption.

## 4. Current State and TODOs

- [x] Fake auth repository and state management.
- [x] GoRouter redirects based on auth and onboarding completion.
- [x] Backend-ready models with `toMap`/`fromMap`.
- [x] Step-by-step local saving with dirty/completed checks.
- [ ] Implement `FirebaseAuthRepository`.
- [ ] Connect `MockUserProfileNotifier` and `MockOnboardingNotifier` to read/write from `/users/{uid}` and `/users/{uid}/onboarding/draft`.
- [ ] Ensure Spark-safe Firestore rules match the schema.

## 5. Home Tab Readiness

The Home tab (once implemented) can safely read the following properties from the validated user profile and onboarding draft:
- Current user ID, name, email.
- `onboardingCompleted` status.
- `lifeRole` and `workType`.
- `bodyBasics` (including BMI and caloric estimates).
- Formatted `baseTimeline` (classes, job, eating, fixed blocks).
- `badHabits` and `goodHabits` lists.
- Selected `identityGoals`.
- `coachSetup` preference.
- `notifications` preference.

**Home Readiness Status**: **PASS** (Ready for implementation once UI begins).
