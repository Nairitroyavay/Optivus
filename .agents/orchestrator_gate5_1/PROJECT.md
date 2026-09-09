# Project: Optivus Gate 5 Fourth and Final Closure

## Architecture
- Root workspace: `/Users/avayroy/Optivus`
- Core Modules:
  - Auth State & Flow: `lib/state/auth_state.dart`, `lib/state/auth_flow_status.dart`, `lib/state/auth_generation.dart`, `lib/repositories/auth_repository.dart`
  - Error Model: `lib/core/errors/recoverable_error.dart`, `lib/core/errors/auth_error_mapper.dart`, `lib/core/errors/reconstruction_error_mapper.dart`, `lib/core/errors/completion_error_mapper.dart`, `lib/core/errors/diagnostic_codes.dart`
  - Verify Email: `lib/state/verification_lifecycle_state.dart`, `lib/views/screens/verify_email_screen.dart`, `lib/views/screens/login_screen.dart`, `lib/views/screens/signup_screen.dart`
  - Session Destination / Routing: `lib/services/session_destination_resolver.dart`, `lib/core/router/app_router.dart`
  - Reconstruction: `lib/services/server_reconstructor.dart`, `lib/services/onboarding_frontend_hydration_service.dart`
  - Session Reset: `lib/services/auth_session_reset_coordinator.dart`
  - State Owners: `lib/state/**`, `lib/features/**`

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | R0 Pre-editing Audit | Mandatory current-source audit and mapping table before any edits | M0 | ORIGINAL_REQUEST §0 |
| 2 | R1 Clean Freezes | Confirm 0 active lib/ uses of mockUserProfileProvider, mockOnboardingProvider, backendRestoreFailed; RouterNotifier isolation | M1 | ORIGINAL_REQUEST §R1 |
| 3 | R2 Session Destination Authority | Preserve SessionDestinationResolver as sole authority; clarify AuthNotifier.statusFor() | M1 | ORIGINAL_REQUEST §R2 |
| 4 | R3 Verify Email Error Unification | Unify VerificationLifecycleState under RecoverableError; delete VerificationMessageKind/messageKind/String message; typed showAccountError; typed logout error | M1 | ORIGINAL_REQUEST §R3 |
| 5 | R4 Centralized Session Reset & Inventory | Classify all mutable user/session state owners across lib/; audit against 6 questions; reconcile TD-039 | M2 | ORIGINAL_REQUEST §R4 |
| 6 | R5 Reconstruction Race Tests | Implement real Auth reconstruction race tests (Test A, B, C, D) using controlled ServerReconstructionSource / completers | M3 | ORIGINAL_REQUEST §R5 |
| 7 | R6 Static Architecture Test | Enforce architectural invariants (mock leakage, router isolation, verify email shape, reset coordinator) | M1/M4 | ORIGINAL_REQUEST §R6 |
| 8 | Regression Suite Verification | Verify Gates 1–5 focused and cross-gate test suites, format audit, analyze 0 errors | M4 | ORIGINAL_REQUEST §Acceptance |
| 9 | Documentation & Gate Report | Reconcile TECHNICAL_DEBT.md, ARCHITECTURE.md, and finalize GATE_5_AUTH_CLEANUP_REPORT.md | M5 | ORIGINAL_REQUEST §Deliverables |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M0 | Mandatory Current-Source Audit | Full source audit across areas; produce pre-editing audit table | none | IN_PROGRESS |
| M1 | Error Unification & Invariants | R1, R2, R3, R6 implementation & tests | M0 | PLANNED |
| M2 | Exhaustive Session Reset Inventory | R4 classification matrix & documentation reconciliation | M0 | PLANNED |
| M3 | Reconstruction Race Tests | R5 Test A, B, C, D implementation & verification | M0, M1 | PLANNED |
| M4 | Cross-Gate Regression & Static Analysis | Verify Gates 1–5 suites, static architecture test, formatting audit | M1, M2, M3 | PLANNED |
| M5 | Documentation & Final Gate Closure | Finalize GATE_5_AUTH_CLEANUP_REPORT.md, TECHNICAL_DEBT.md, ARCHITECTURE.md | M4 | PLANNED |

## Interface Contracts
### VerificationLifecycleState ↔ VerifyEmailScreen
- `error`: `RecoverableError?` (typed domain failure)
- `successMessage`: `String?` (resend success presentation only)
- `copyWith`: support independent `clearError: true` and `clearSuccessMessage: true`
- No `VerificationMessageKind`, no `messageKind`, no `String? message`

### AuthNotifier ↔ SessionDestinationResolver
- `SessionDestinationResolver` is sole destination authority
- `AuthNotifier.statusFor()`: credential-level classification only

### AuthSessionResetCoordinator ↔ User State Owners
- Synchronous reset on `resetIdentityBoundary`
- Every owner classified: `USER_SCOPED_RESET`, `USER_SCOPED_UID_KEYED`, `USER_SCOPED_AUTO_DISPOSE`, `USER_SCOPED_GENERATION_FENCED`, `SESSION_UI_RESET`, `GLOBAL_CONFIG`, `DERIVED`, `REPOSITORY_UID_SCOPED`, `NOT_USER_SCOPED`
