import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/core/errors/auth_error_mapper.dart';
import 'package:optivus/core/errors/completion_error_mapper.dart';
import 'package:optivus/core/errors/diagnostic_codes.dart';
import 'package:optivus/core/errors/reconstruction_error_mapper.dart';
import 'package:optivus/core/errors/recoverable_error.dart';
import 'package:optivus/features/routine/controllers/habit_systems_controller.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/services/onboarding_frontend_hydration_service.dart';

import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/mock_seed_data.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/state/region_settings_provider.dart';
import 'package:optivus/features/recovery/models/onboarding_recovery_models.dart';
import 'package:optivus/features/home/providers/home_dashboard_provider.dart';
import 'package:optivus/features/tracker/fitness/providers/fitness_provider.dart';
import 'package:optivus/services/onboarding_account_migration_service.dart';
import 'package:optivus/services/auth_session_reset_coordinator.dart';
import 'package:optivus/state/upload_state.dart';
import 'package:optivus/state/auth_generation.dart';
import 'package:optivus/state/auth_flow_status.dart';
import 'package:optivus/services/onboarding_resume_validator.dart';
import 'package:optivus/services/onboarding_upload_source_reconciler.dart';
import 'package:optivus/services/session_destination_resolver.dart';
import 'package:optivus/services/server_reconstructor.dart';

export 'package:optivus/state/auth_flow_status.dart' show AuthFlowStatus;

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return ref
      .watch(fakeBackendPolicyProvider)
      .selectBackend(
        firebase: FirebaseAuthRepository.new,
        fake: FakeAuthRepository.new,
      );
});

final serverReconstructorProvider = Provider<ServerReconstructor>((ref) {
  return ServerReconstructor(
    source: RepositoryServerReconstructionSource(
      profileRepository: ref.watch(profileRepositoryProvider),
      onboardingRepository: ref.watch(onboardingRepositoryProvider),
      completionJobService: ref.watch(onboardingCompletionJobServiceProvider),
    ),
  );
});

enum VerificationEmailSendStatus { pending, sent, failed }

/// Bounded recovery for server-authoritative session reconstruction. The
/// delays are injectable so the policy is testable without wall-clock waits.
class ReconstructionRetryPolicy {
  final List<Duration> retryDelays;

  const ReconstructionRetryPolicy({
    this.retryDelays = const [
      Duration(milliseconds: 750),
      Duration(milliseconds: 1750),
    ],
  });

  int get maxAttempts => retryDelays.length + 1;
}

final reconstructionRetryPolicyProvider = Provider<ReconstructionRetryPolicy>(
  (ref) => const ReconstructionRetryPolicy(),
);

void _logEmailVerificationDebug(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

String _maskedUid(String uid) {
  if (uid.length <= 6) return 'uid_${uid.length}';
  return '${uid.substring(0, 3)}...${uid.substring(uid.length - 3)}';
}

RecoverableError _sessionNetworkError(
  String message, {
  String diagnosticCode = DiagnosticCodes.networkUnavailable,
}) {
  return RecoverableError(
    category: RecoverableErrorCategory.network,
    publicMessage: message,
    severity: RecoverableErrorSeverity.error,
    isBlocking: true,
    retryAction: RecoverableRetryAction.retry,
    retrySafe: true,
    diagnosticCode: diagnosticCode,
  );
}

RecoverableError _sessionRecoveryError(
  String message, {
  String diagnosticCode = DiagnosticCodes.recoveryDurableStateConflict,
}) {
  return RecoverableError(
    category: RecoverableErrorCategory.recoveryRequired,
    publicMessage: message,
    severity: RecoverableErrorSeverity.critical,
    isBlocking: true,
    retryAction: RecoverableRetryAction.restartRecovery,
    retrySafe: false,
    diagnosticCode: diagnosticCode,
  );
}

class AuthState {
  final AuthUser? user;
  final AuthFlowStatus status;
  final RecoverableError? error;
  final List<OnboardingRecoveryAction> recoveryActions;
  final DateTime? lastVerificationEmailSent;
  final VerificationEmailSendStatus verificationEmailSendStatus;
  final int? resumeStep;
  final String? completionRunId;
  final String? startupReasonCode;
  final ReconstructionResult? reconstructionResult;

  const AuthState({
    this.user,
    this.status = AuthFlowStatus.signedOut,
    this.error,
    this.recoveryActions = const [],
    this.lastVerificationEmailSent,
    this.verificationEmailSendStatus = VerificationEmailSendStatus.pending,
    this.resumeStep,
    this.completionRunId,
    this.startupReasonCode,
    this.reconstructionResult,
  });

  bool get isLoggedIn => user != null;
  bool get isAuthenticating => status == AuthFlowStatus.loading;
  bool get isLoading =>
      status == AuthFlowStatus.loading ||
      status == AuthFlowStatus.loadingBackendUser ||
      status == AuthFlowStatus.restoringOnboarding;
  bool get isLoadingBackendUser => status == AuthFlowStatus.loadingBackendUser;
  bool get isRestoringOnboarding =>
      status == AuthFlowStatus.restoringOnboarding;
  bool get isBackendRestoreInProgress =>
      isLoadingBackendUser || isRestoringOnboarding;
  bool get isSignedOut => status == AuthFlowStatus.signedOut;
  bool get emailUnverified => status == AuthFlowStatus.signedInEmailUnverified;
  bool get onboardingIncomplete =>
      status == AuthFlowStatus.signedInOnboardingIncomplete;
  bool get onboardingComplete =>
      status == AuthFlowStatus.signedInOnboardingComplete;
  bool get hasError =>
      status == AuthFlowStatus.error ||
      status == AuthFlowStatus.reconnectRequired ||
      status == AuthFlowStatus.needsAction;
  bool get needsAction => status == AuthFlowStatus.needsAction;
  String? get errorMessage => error?.publicMessage;

  SessionDestination get sessionDestination {
    return resolveAuthSessionDestination(
      status: status,
      userUid: user?.uid,
      resumeStep: resumeStep,
      completionRunId: completionRunId,
      startupReasonCode: startupReasonCode,
      reconstructionResult: reconstructionResult,
    );
  }

  AuthState copyWith({
    AuthUser? user,
    AuthFlowStatus? status,
    RecoverableError? error,
    List<OnboardingRecoveryAction>? recoveryActions,
    DateTime? lastVerificationEmailSent,
    VerificationEmailSendStatus? verificationEmailSendStatus,
    int? resumeStep,
    String? completionRunId,
    String? startupReasonCode,
    ReconstructionResult? reconstructionResult,
    bool clearUser = false,
    bool clearError = false,
    bool clearVerificationEmailState = false,
    bool clearStartupDestination = false,
    bool clearReconstructionResult = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      status: status ?? this.status,
      error: clearError && error == null ? null : (error ?? this.error),
      recoveryActions: clearError && recoveryActions == null
          ? const []
          : (recoveryActions ?? this.recoveryActions),
      lastVerificationEmailSent: clearVerificationEmailState
          ? null
          : (lastVerificationEmailSent ?? this.lastVerificationEmailSent),
      verificationEmailSendStatus: clearVerificationEmailState
          ? VerificationEmailSendStatus.pending
          : (verificationEmailSendStatus ?? this.verificationEmailSendStatus),
      resumeStep: clearStartupDestination && resumeStep == null
          ? null
          : (resumeStep ?? this.resumeStep),
      completionRunId: clearStartupDestination && completionRunId == null
          ? null
          : (completionRunId ?? this.completionRunId),
      startupReasonCode: clearStartupDestination && startupReasonCode == null
          ? null
          : (startupReasonCode ?? this.startupReasonCode),
      reconstructionResult: clearReconstructionResult
          ? null
          : (reconstructionResult ?? this.reconstructionResult),
    );
  }
}

class _SignupCredentialHandoff {
  final int operation;
  final String normalizedEmail;
  String? observedUid;

  _SignupCredentialHandoff({
    required this.operation,
    required this.normalizedEmail,
  });
}

class AuthNotifier extends StateNotifier<AuthState> {
  static const Duration _startupResolutionTimeout = Duration(seconds: 30);
  final AuthRepository _repository;
  final Ref _ref;
  late final StreamSubscription<AuthUser?> _authSubscription;
  int _backendRestoreGeneration = 0;
  int _authOperationGeneration = 0;
  bool _googleAuthInFlight = false;
  final Set<Timer> _startupTimers = <Timer>{};
  final Map<String, Future<void>> _reconstructionInFlightByUid = {};
  final Set<String> _verificationHandoffUids = <String>{};
  int _reconstructionOperationSequence = 0;
  _SignupCredentialHandoff? _signupCredentialHandoff;

  AuthNotifier(this._repository, Ref ref)
    : _ref = ref,
      super(
        AuthState(
          status: ref.read(fakeDataAllowedProvider)
              ? AuthFlowStatus.signedOut
              : AuthFlowStatus.loading,
        ),
      ) {
    _authSubscription = _repository.authStateChanges.listen(
      _handleAuthStateChange,
    );
  }

  @override
  void dispose() {
    _backendRestoreGeneration++;
    _authOperationGeneration++;
    for (final timer in _startupTimers) {
      timer.cancel();
    }
    _startupTimers.clear();
    _reconstructionInFlightByUid.clear();
    _verificationHandoffUids.clear();
    _signupCredentialHandoff = null;
    _authSubscription.cancel();
    super.dispose();
  }

  Future<T> _bounded<T>(Future<T> operation, Duration timeout) {
    final completer = Completer<T>();
    late final Timer timer;
    timer = Timer(timeout, () {
      _startupTimers.remove(timer);
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('Startup resolution timed out.'),
        );
      }
    });
    _startupTimers.add(timer);
    operation.then(
      (value) {
        timer.cancel();
        _startupTimers.remove(timer);
        if (!completer.isCompleted) completer.complete(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        timer.cancel();
        _startupTimers.remove(timer);
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );
    return completer.future;
  }

  Future<void> login(String email, String password) async {
    final operation = ++_authOperationGeneration;
    final previousUser = state.user;
    state = state.copyWith(status: AuthFlowStatus.loading, clearError: true);
    try {
      final user = await _repository.signIn(email, password);
      if (!_isCurrentAuthOperation(operation)) return;

      if (_needsEmailVerification(user)) {
        _clearStateForIdentityBoundary(user);
        state = state.copyWith(
          user: user,
          status: AuthFlowStatus.signedInEmailUnverified,
          clearError: true,
        );
        return;
      }

      await _loadBackendWithTimeout(user);
    } catch (error) {
      if (!_isCurrentAuthOperation(operation)) rethrow;
      final mapped = AuthErrorMapper.map(error);
      state = state.copyWith(
        user: previousUser,
        status: AuthFlowStatus.error,
        error: mapped,
      );
      rethrow;
    } finally {
      if (_isCurrentAuthOperation(operation) && state.isAuthenticating) {
        state = state.copyWith(
          status: statusFor(
            state.user,
            _ref.read(userProfileProvider).onboardingCompleted,
          ),
        );
      }
    }
  }

  /// Starts the one shared Google authentication flow used by all auth entry
  /// screens. Firebase's auth-state stream remains the sole owner of backend
  /// reconstruction and destination resolution after credential exchange.
  Future<bool> signInWithGoogle() async {
    if (_googleAuthInFlight || state.isLoading) return false;

    _googleAuthInFlight = true;
    final operation = ++_authOperationGeneration;
    final previousUser = state.user;
    state = state.copyWith(status: AuthFlowStatus.loading, clearError: true);
    try {
      final user = await _repository.signInWithGoogle();
      if (!_isCurrentAuthOperation(operation)) return false;
      if (user == null) {
        state = state.copyWith(
          user: previousUser,
          clearUser: previousUser == null,
          status: statusFor(
            previousUser,
            _ref.read(userProfileProvider).onboardingCompleted,
          ),
          clearError: true,
        );
        return false;
      }

      // Do not navigate or reconstruct here. FirebaseAuth.authStateChanges
      // delivers the authenticated identity to _handleAuthStateChange, which
      // uses the normal UID-owned backend bootstrap and destination resolver.
      return true;
    } catch (error) {
      if (!_isCurrentAuthOperation(operation)) return false;
      final mapped = AuthErrorMapper.map(error);
      state = state.copyWith(
        user: previousUser,
        clearUser: previousUser == null,
        status: AuthFlowStatus.error,
        error: mapped,
      );
      rethrow;
    } finally {
      _googleAuthInFlight = false;
      if (_isCurrentAuthOperation(operation) && state.isAuthenticating) {
        state = state.copyWith(
          status: statusFor(
            state.user,
            _ref.read(userProfileProvider).onboardingCompleted,
          ),
        );
      }
    }
  }

  Future<void> signup(String name, String email, String password) async {
    final operation = ++_authOperationGeneration;
    _logEmailVerificationDebug(
      '[OptivusBuild] commit=${const String.fromEnvironment('OPTIVUS_BUILD_COMMIT', defaultValue: 'source-email-verification-v1')}',
    );
    _logEmailVerificationDebug('[EmailVerification] stage=signup_started');
    final handoff = _SignupCredentialHandoff(
      operation: operation,
      normalizedEmail: email.trim().toLowerCase(),
    );
    _signupCredentialHandoff = handoff;
    final previousUser = state.user;
    state = state
        .copyWith(
          status: AuthFlowStatus.loading,
          clearError: true,
          clearVerificationEmailState: true,
        )
        .copyWith(
          verificationEmailSendStatus: VerificationEmailSendStatus.pending,
        );
    AuthUser? createdUser;
    try {
      final user = await _repository.signUp(email, password, name: name);
      if (!_isCurrentAuthOperation(operation)) return;
      _logEmailVerificationDebug(
        '[EmailVerification] stage=firebase_account_created uid=${_maskedUid(user.uid)}',
      );
      if (handoff.observedUid case final observedUid?
          when observedUid != user.uid) {
        _authOperationGeneration++;
        return;
      }
      createdUser = user;
      if (_needsEmailVerification(user)) {
        _clearStateForIdentityBoundary(user);
        state = state.copyWith(
          user: user,
          status: AuthFlowStatus.signedInEmailUnverified,
          clearError: true,
        );
        try {
          _logEmailVerificationDebug(
            '[EmailVerification] stage=before_initial_send',
          );
          await _repository.sendEmailVerification();
          if (!_isCurrentAuthOperation(operation)) return;
          _logEmailVerificationDebug(
            '[EmailVerification] stage=after_initial_send',
          );
          state = state.copyWith(
            clearError: true,
            lastVerificationEmailSent: DateTime.now(),
            verificationEmailSendStatus: VerificationEmailSendStatus.sent,
          );
          _startDisplayNameEnrichment(
            operation: operation,
            user: user,
            name: name,
          );
        } catch (error) {
          if (!_isCurrentAuthOperation(operation)) rethrow;
          final mapped = AuthErrorMapper.map(error);
          _logEmailVerificationDebug(
            '[EmailVerification] stage=initial_send_failed code=${mapped.diagnosticCode}',
          );
          state = state.copyWith(
            user: user,
            status: AuthFlowStatus.signedInEmailUnverified,
            error: mapped.copyWith(
              publicMessage:
                  'We couldn\'t send the verification email. Please resend it.',
            ),
            verificationEmailSendStatus: VerificationEmailSendStatus.failed,
          );
          return;
        }
        if (!_isCurrentAuthOperation(operation)) return;
        return;
      }
      await _loadBackendWithTimeout(user);
    } catch (error) {
      if (!_isCurrentAuthOperation(operation)) rethrow;
      final mapped = AuthErrorMapper.map(error);
      final activeUser = createdUser ?? previousUser;
      state = state.copyWith(
        user: activeUser,
        status: activeUser != null && _needsEmailVerification(activeUser)
            ? AuthFlowStatus.signedInEmailUnverified
            : AuthFlowStatus.error,
        error: mapped,
      );
      rethrow;
    } finally {
      if (identical(_signupCredentialHandoff, handoff)) {
        _signupCredentialHandoff = null;
      }
      if (_isCurrentAuthOperation(operation) && state.isAuthenticating) {
        state = state.copyWith(
          status: statusFor(
            state.user,
            _ref.read(userProfileProvider).onboardingCompleted,
          ),
        );
      }
    }
  }

  Future<void> signInAnonymously() async {
    final operation = ++_authOperationGeneration;
    state = state.copyWith(status: AuthFlowStatus.loading, clearError: true);
    try {
      final user = await _repository.signInAnonymously();
      if (!_isCurrentAuthOperation(operation)) return;
      await _loadBackendWithTimeout(user);
    } catch (error) {
      if (!_isCurrentAuthOperation(operation)) rethrow;
      final mapped = AuthErrorMapper.map(error);
      state = state.copyWith(status: AuthFlowStatus.error, error: mapped);
      rethrow;
    }
  }

  Future<void> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async {
    final operation = ++_authOperationGeneration;
    final oldUser = state.user;
    final oldAnonUid = oldUser?.isAnonymous == true ? oldUser!.uid : null;

    state = state.copyWith(status: AuthFlowStatus.loading, clearError: true);
    try {
      final user = await _repository.linkAnonymousWithEmail(
        email,
        password,
        name: name,
      );
      if (!_isCurrentAuthOperation(operation)) return;

      if (oldAnonUid != null && oldAnonUid != user.uid) {
        await OnboardingAccountMigrationService.migrateAccountData(
          oldAnonUid: oldAnonUid,
          newUid: user.uid,
          read: _ref.read,
        );
        if (!_isCurrentAuthOperation(operation)) return;
      }

      if (_needsEmailVerification(user)) {
        _clearStateForIdentityBoundary(user);
        state = state.copyWith(
          user: user,
          status: AuthFlowStatus.signedInEmailUnverified,
          clearError: true,
        );
        try {
          await _repository.sendEmailVerification();
          if (!_isCurrentAuthOperation(operation)) return;
          state = state.copyWith(
            clearError: true,
            lastVerificationEmailSent: DateTime.now(),
            verificationEmailSendStatus: VerificationEmailSendStatus.sent,
          );
        } catch (error) {
          if (!_isCurrentAuthOperation(operation)) rethrow;
          final mapped = AuthErrorMapper.map(error);
          state = state.copyWith(
            user: user,
            status: AuthFlowStatus.signedInEmailUnverified,
            error: mapped.copyWith(
              publicMessage:
                  'We couldn\'t send the verification email. Please resend it.',
            ),
            verificationEmailSendStatus: VerificationEmailSendStatus.failed,
          );
          return;
        }
        if (!_isCurrentAuthOperation(operation)) return;
        return;
      }

      await _loadBackendWithTimeout(user, isAnonymousLink: true);
    } catch (error) {
      if (!_isCurrentAuthOperation(operation)) rethrow;
      final mapped = AuthErrorMapper.map(error);
      state = state.copyWith(
        user: oldUser,
        status: oldUser != null && oldUser.isAnonymous
            ? (oldUser.emailVerified
                  ? AuthFlowStatus.signedInOnboardingIncomplete
                  : AuthFlowStatus.signedInEmailUnverified)
            : AuthFlowStatus.error,
        error: mapped,
      );
      rethrow;
    }
  }

  Future<void> logout() async {
    ++_authOperationGeneration;
    try {
      await _repository.signOut();
    } catch (error) {
      final mapped = AuthErrorMapper.map(error);
      state = state.copyWith(
        error: mapped.copyWith(
          publicMessage:
              'We couldn\'t sign you out. You are still signed in. Please try again.',
        ),
      );
      rethrow;
    }
    _backendRestoreGeneration++;
    _resetSignedOutState();
    if (mounted) {
      state = const AuthState(status: AuthFlowStatus.signedOut);
    }
  }

  Future<void> resendEmailVerification() async {
    final targetUid = state.user?.uid;
    if (targetUid == null) return;
    try {
      await _repository.sendEmailVerification();
      if (!mounted || state.user?.uid != targetUid) return;
      state = state.copyWith(
        clearError: true,
        lastVerificationEmailSent: DateTime.now(),
        verificationEmailSendStatus: VerificationEmailSendStatus.sent,
      );
    } catch (error) {
      if (!mounted || state.user?.uid != targetUid) return;
      final mapped = AuthErrorMapper.map(error);
      state = state.copyWith(
        status: AuthFlowStatus.signedInEmailUnverified,
        error: mapped,
      );
      rethrow;
    }
  }

  Future<void> retryBackendRestore() async {
    final user = state.user ?? _repository.currentUser;
    if (user == null) {
      _resetSignedOutState();
      state = const AuthState(status: AuthFlowStatus.signedOut);
      return;
    }

    if (_needsEmailVerification(user)) {
      state = state.copyWith(
        user: user,
        status: AuthFlowStatus.signedInEmailUnverified,
        clearError: true,
      );
      return;
    }

    if (state.status == AuthFlowStatus.finishingOnboarding) {
      await _resumeOnboardingCompletion();
      return;
    }

    await _loadBackendWithTimeout(user);
  }

  Future<void> checkEmailVerification() async {
    final operation = ++_authOperationGeneration;
    final targetUid = state.user?.uid;
    if (targetUid == null) return;

    try {
      _verificationHandoffUids.add(targetUid);
      final user = await _repository.reloadCurrentUser();
      if (!_isCurrentAuthOperation(operation)) return;
      if (user == null) {
        _resetSignedOutState();
        state = const AuthState(status: AuthFlowStatus.signedOut);
        return;
      }
      if (user.uid != targetUid) return;

      if (_needsEmailVerification(user)) {
        state = state.copyWith(
          user: user,
          status: AuthFlowStatus.signedInEmailUnverified,
          clearError: true,
        );
        return;
      }

      // Refresh the verified claim only after Firebase's fresh post-reload
      // user confirms verification. Unverified polling does not churn tokens.
      await _repository.currentIdToken();
      if (!_isCurrentAuthOperation(operation)) return;
      await _loadBackendWithTimeout(user);
    } catch (error) {
      if (!_isCurrentAuthOperation(operation)) rethrow;
      final mapped = AuthErrorMapper.map(error);
      state = state.copyWith(
        status: AuthFlowStatus.signedInEmailUnverified,
        error: mapped,
      );
      rethrow;
    } finally {
      _verificationHandoffUids.remove(targetUid);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _repository.sendPasswordResetEmail(email);
    } catch (error) {
      final mapped = AuthErrorMapper.map(error);
      state = state.copyWith(status: AuthFlowStatus.error, error: mapped);
      rethrow;
    }
  }

  Future<void> markOnboardingComplete(AuthUser user) async {
    await acceptCanonicalOnboardingCompletion(user);
  }

  Future<void> acceptCanonicalOnboardingCompletion(AuthUser user) async {
    if (user.uid.trim().isEmpty) return;
    if (_needsEmailVerification(user)) {
      state = state.copyWith(
        user: user,
        status: AuthFlowStatus.signedInEmailUnverified,
        clearError: true,
      );
      return;
    }
    final capturedAuthGeneration = _ref.read(authGenerationProvider);
    final job = await _ref
        .read(onboardingCompletionJobServiceProvider)
        .loadCurrentJob(user.uid);
    final profile = await _ref
        .read(profileRepositoryProvider)
        .fetchUserProfile(user.uid);
    if (!mounted ||
        _ref.read(authGenerationProvider) != capturedAuthGeneration ||
        state.user?.uid != user.uid) {
      return;
    }
    if (job == null ||
        job.status != OnboardingJobStatus.completed ||
        job.stage != OnboardingCompletionStage.completed ||
        profile == null ||
        profile.uid != user.uid ||
        !profile.onboardingCompleted ||
        profile.onboardingProjectionStatus != 'completed') {
      throw StateError('Canonical onboarding completion is not verified.');
    }
    _ref.read(userProfileProvider.notifier).updateProfile(profile);
    state = state.copyWith(
      user: user,
      status: AuthFlowStatus.signedInOnboardingComplete,
      clearError: true,
      clearStartupDestination: true,
      clearReconstructionResult: true,
    );
  }

  Future<void> _resumeOnboardingCompletion() async {
    final user = state.user ?? _repository.currentUser;
    if (user == null || user.uid.trim().isEmpty) return;
    final ownerUid = user.uid;
    final capturedAuthGeneration = _ref.read(authGenerationProvider);

    bool isActiveOwner() {
      return mounted &&
          state.user?.uid == ownerUid &&
          _ref.read(authGenerationProvider) == capturedAuthGeneration;
    }

    state = state.copyWith(
      user: user,
      status: AuthFlowStatus.finishingOnboarding,
      clearError: true,
    );
    try {
      final repository = _ref.read(onboardingRepositoryProvider);
      final draft = await _bounded(
        repository.fetchDraft(ownerUid),
        _startupResolutionTimeout,
      );
      if (!isActiveOwner()) return;
      if (draft == null || !isDurablyFinalOnboardingDraft(draft)) {
        final profile = _ref.read(userProfileProvider);
        final destination = resolveOnboardingSessionDestination(
          ownerUid: ownerUid,
          profile: profile,
          draft: draft,
        );
        _applySessionDestination(user, destination);
        return;
      }

      var bundle = await _bounded(
        repository.fetchCompletionBundle(ownerUid),
        _startupResolutionTimeout,
      );
      if (!isActiveOwner()) return;
      bundle ??= OnboardingCompletionService.buildBundle(draft);
      if (bundle.uid != ownerUid ||
          bundle.draftRevision != draft.revision ||
          bundle.sourceFingerprint != draft.effectiveSourceFingerprint) {
        throw StateError('Completion inputs do not match the saved setup.');
      }

      final job = await _bounded(
        _ref
            .read(onboardingCompletionJobServiceProvider)
            .runCompletionJob(
              uid: ownerUid,
              finalDraft: draft,
              bundle: bundle,
              reader: _ref.read,
            ),
        const Duration(seconds: 60),
      );
      if (!isActiveOwner()) return;
      if (job.status != OnboardingJobStatus.completed ||
          job.stage != OnboardingCompletionStage.completed) {
        throw StateError('Completion job stopped before verification.');
      }
      await acceptCanonicalOnboardingCompletion(user);
    } on TimeoutException catch (error) {
      if (!isActiveOwner()) return;
      state = state.copyWith(
        user: user,
        status: AuthFlowStatus.reconnectRequired,
        error: CompletionErrorMapper.map(error: error),
        recoveryActions: const [RetryNetworkAction(), SignOutAction()],
        startupReasonCode: 'completion_timeout',
        clearStartupDestination: true,
      );
    } catch (error) {
      if (!isActiveOwner()) return;
      OnboardingCompletionJob? job;
      try {
        job = await _ref
            .read(onboardingCompletionJobServiceProvider)
            .loadCurrentJob(ownerUid);
      } catch (_) {
        // The original failure remains authoritative.
      }
      if (!isActiveOwner()) return;
      final fatal =
          job?.status == OnboardingJobStatus.fatalFailure ||
          error is ArgumentError;
      state = state.copyWith(
        user: user,
        status: fatal
            ? AuthFlowStatus.needsAction
            : AuthFlowStatus.reconnectRequired,
        error: CompletionErrorMapper.map(
          job: job,
          error: error,
          isContradiction: fatal,
        ),
        recoveryActions: fatal
            ? const [
                RetryNetworkAction(),
                ResetSetupSafelyAction(),
                SignOutAction(),
              ]
            : const [RetryNetworkAction(), SignOutAction()],
        startupReasonCode: fatal
            ? (job?.lastFailureCode ?? 'completion_verification_failed')
            : 'completion_retry_required',
        clearStartupDestination: true,
      );
    }
  }

  Future<void> markOnboardingIncomplete(AuthUser user) async {
    if (user.uid.trim().isEmpty) return;
    final profile = _ref
        .read(userProfileProvider)
        .copyWith(
          uid: user.uid,
          onboardingInputCompleted: false,
          onboardingProjectionStatus: 'pending',
          onboardingCompleted: false,
          onboardingStep: 0,
          updatedAt: DateTime.now(),
        );
    _ref.read(userProfileProvider.notifier).updateProfile(profile);
    if (_useFirebaseBackend && !_needsEmailVerification(user)) {
      await _ref.read(profileRepositoryProvider).saveUserProfile(profile);
    }
    state = state.copyWith(
      user: user,
      status: AuthFlowStatus.signedInOnboardingIncomplete,
      clearError: true,
      resumeStep: 0,
      clearStartupDestination: true,
      clearReconstructionResult: true,
    );
  }

  static AuthFlowStatus statusFor(AuthUser? user, bool onboardingCompleted) {
    if (user == null) return AuthFlowStatus.signedOut;
    if (_needsEmailVerification(user)) {
      return AuthFlowStatus.signedInEmailUnverified;
    }
    return onboardingCompleted
        ? AuthFlowStatus.signedInOnboardingComplete
        : AuthFlowStatus.signedInOnboardingIncomplete;
  }

  static bool _needsEmailVerification(AuthUser user) {
    return user.needsEmailVerification;
  }

  Future<void> _handleAuthStateChange(AuthUser? user) async {
    if (!mounted) return;

    final previousUser = state.user;

    if (user == null) {
      if (_signupCredentialHandoff?.operation == _authOperationGeneration) {
        return;
      }
      _signupCredentialHandoff = null;
      _authOperationGeneration++;
      _backendRestoreGeneration++;
      _resetSignedOutState();
      state = const AuthState(status: AuthFlowStatus.signedOut);
      return;
    }

    final isAccountSwitch =
        previousUser != null && previousUser.uid != user.uid;
    final isInitialSignIn = previousUser == null;
    final isSameUidRefresh = previousUser?.uid == user.uid;
    final signupOwnsAuthEvent = _claimExpectedSignupAuthEvent(user);

    if (isSameUidRefresh &&
        _needsEmailVerification(previousUser!) ==
            _needsEmailVerification(user)) {
      // Same-session Firebase auth, token, reload, and metadata events update
      // identity facts in place. In particular, do not publish a resolving
      // state or clear the typed reconstruction result: the router and all
      // navigation providers must retain the established authenticated URI.
      // Genuine reconstruction retries enter through retryBackendRestore;
      // verification changes continue below and reconstruct authoritatively.
      state = state.copyWith(user: user);
      return;
    }

    if (isSameUidRefresh &&
        _needsEmailVerification(previousUser!) &&
        !_needsEmailVerification(user) &&
        _verificationHandoffUids.contains(user.uid)) {
      state = state.copyWith(user: user);
      return;
    }

    if ((isAccountSwitch || isInitialSignIn) && !signupOwnsAuthEvent) {
      _signupCredentialHandoff = null;
      _authOperationGeneration++;
    }

    if (_needsEmailVerification(user)) {
      if (isAccountSwitch || isInitialSignIn) {
        _clearStateForIdentityBoundary(user);
      }
      state = state.copyWith(
        user: user,
        status: AuthFlowStatus.signedInEmailUnverified,
        clearError: true,
      );
      return;
    }

    try {
      await _loadBackendWithTimeout(user);
    } catch (e) {
      if (!mounted) return;
      final mapped = AuthErrorMapper.map(e);
      state = state.copyWith(
        user: user,
        status: AuthFlowStatus.reconnectRequired,
        error: mapped,
        startupReasonCode: 'startup_request_failed',
        clearStartupDestination: true,
      );
    }
  }

  Future<void> _loadBackendWithTimeout(
    AuthUser user, {
    bool isAnonymousLink = false,
  }) async {
    final authGeneration = _authOperationGeneration;
    final reconstructionKey = _reconstructionKey(user.uid, authGeneration);
    final existing = _reconstructionInFlightByUid[reconstructionKey];
    if (existing != null) {
      await existing;
      return;
    }
    final operationId = ++_reconstructionOperationSequence;
    _logReconstruction('event=operation_started operationId=$operationId');
    final operation = _runReconstructionOperation(
      user,
      authGeneration: authGeneration,
      operationId: operationId,
      isAnonymousLink: isAnonymousLink,
    );
    _reconstructionInFlightByUid[reconstructionKey] = operation;
    try {
      await operation;
    } finally {
      if (identical(
        _reconstructionInFlightByUid[reconstructionKey],
        operation,
      )) {
        _reconstructionInFlightByUid.remove(reconstructionKey);
      }
    }
  }

  String _reconstructionKey(String uid, int authGeneration) {
    return '$uid@$authGeneration';
  }

  Future<void> _runReconstructionOperation(
    AuthUser user, {
    required int authGeneration,
    required int operationId,
    required bool isAnonymousLink,
  }) async {
    final policy = _ref.read(reconstructionRetryPolicyProvider);
    final started = Stopwatch()..start();

    bool isCurrentOwner() {
      // Auth events call this before they publish the new user into state.
      // The operation generation is the identity boundary; a later sign-out
      // or account switch increments it before any stale retry can apply.
      return mounted && _authOperationGeneration == authGeneration;
    }

    for (var attempt = 1; attempt <= policy.maxAttempts; attempt++) {
      if (!isCurrentOwner()) return;
      _logReconstruction(
        'event=attempt_started operationId=$operationId attempt=$attempt',
      );
      final attemptTimer = Stopwatch()..start();
      try {
        await _bounded(
          _loadOrCreateBackendUserState(user, isAnonymousLink: isAnonymousLink),
          _startupResolutionTimeout,
        );
        if (isCurrentOwner()) {
          _logReconstruction(
            'event=classified operationId=$operationId '
            'attempt=$attempt totalElapsedMs=${started.elapsedMilliseconds}',
          );
        }
        return;
      } catch (error) {
        if (!isCurrentOwner()) return;
        final transient = _isTransientReconstructionFailure(error);
        _logReconstruction(
          'event=attempt_failed operationId=$operationId attempt=$attempt '
          'failureKind=${_reconstructionFailureKind(error)} '
          'elapsedMs=${attemptTimer.elapsedMilliseconds}',
        );
        if (!transient || attempt == policy.maxAttempts) {
          _publishReconstructionFailure(user, error, attempts: attempt);
          return;
        }
        final delay = policy.retryDelays[attempt - 1];
        _logReconstruction(
          'event=retry_scheduled operationId=$operationId '
          'attempt=${attempt + 1} delayMs=${delay.inMilliseconds}',
        );
        await Future<void>.delayed(delay);
      }
    }
  }

  bool _isTransientReconstructionFailure(Object error) {
    return error is TimeoutException ||
        (error is ReconstructionBootstrapException &&
            (error.reason ==
                    ReconstructionBootstrapFailureReason.backendUnavailable ||
                error.reason == ReconstructionBootstrapFailureReason.timeout));
  }

  String _reconstructionFailureKind(Object error) {
    if (error is ReconstructionBootstrapException) {
      return error.diagnosticCode;
    }
    if (error is TimeoutException) return 'timeout';
    return 'unclassified_${error.runtimeType}';
  }

  void _publishReconstructionFailure(
    AuthUser user,
    Object error, {
    required int attempts,
  }) {
    if (!mounted || state.user?.uid != user.uid) return;
    _backendRestoreGeneration++;
    _logReconstruction('event=retry_exhausted attempts=$attempts');
    final bootstrap = error is ReconstructionBootstrapException ? error : null;
    state = state.copyWith(
      user: user,
      status: AuthFlowStatus.reconnectRequired,
      error: bootstrap == null
          ? AuthErrorMapper.map(error)
          : ReconstructionErrorMapper.fromBootstrapException(bootstrap),
      recoveryActions: const [RetryNetworkAction(), SignOutAction()],
      startupReasonCode: bootstrap == null
          ? 'startup_timeout'
          : 'reconstruction_${bootstrap.reason.name}',
      clearStartupDestination: true,
      clearReconstructionResult: true,
    );
  }

  Future<void> _loadOrCreateBackendUserState(
    AuthUser user, {
    bool isAnonymousLink = false,
  }) async {
    if (user.uid.trim().isEmpty) {
      _resetSignedOutState();
      state = const AuthState(status: AuthFlowStatus.signedOut);
      return;
    }
    if (!isAnonymousLink) {
      _clearStateForIdentityBoundary(user);
    }
    state = state.copyWith(
      user: user,
      status: AuthFlowStatus.loadingBackendUser,
      clearError: true,
      clearReconstructionResult: true,
    );
    final restoreGeneration = ++_backendRestoreGeneration;
    // Region is global, user-scoped state.  Hydrate it before restoring an
    // onboarding draft so Step 7 cannot issue a local-pricing request against
    // a transient locale fallback.
    await _ref.read(regionSettingsProvider.notifier).loadForUser(user.uid);
    if (!mounted || !_isCurrentRestore(restoreGeneration)) return;
    if (!_useFirebaseBackend) {
      if (user.uid == 'dev-user-12345') {
        await _loadDevSeedState(user);
      } else {
        await _loadFakeUserState(user, restoreGeneration);
      }
      if (!mounted || !_isCurrentRestore(restoreGeneration)) return;
      _ref.read(homeDashboardProvider.notifier).setOwnerUid(user.uid);
      _ref.read(fitnessCenterProvider.notifier).setOwnerUid(user.uid);
      final profile = _ref.read(userProfileProvider);
      final draft = _ref.read(onboardingStateProvider).draft;
      final destination = resolveOnboardingSessionDestination(
        ownerUid: user.uid,
        profile: profile,
        draft: draft.uid == user.uid ? draft : null,
      );
      if (destination.kind == SessionDestinationKind.resumeOnboarding) {
        _ref
            .read(onboardingStateProvider.notifier)
            .loadSeedData(
              draft.copyWith(
                currentStep: destination.resumeStep,
                stepLoading: List<bool>.filled(
                  OnboardingDraft.stepCount,
                  false,
                ),
                incrementRevision: false,
              ),
            );
      }
      _applySessionDestination(user, destination);
      return;
    }

    _ref
        .read(authSessionResetCoordinatorProvider)
        .prepareForAuthoritativeHydration();
    await _reconstructAndHydrate(user, restoreGeneration);
  }

  void _applySessionDestination(
    AuthUser user,
    SessionDestination destination, {
    ReconstructionResult? reconstructionResult,
  }) {
    final status = authFlowStatusForDestination(destination);
    state = state.copyWith(
      user: user,
      status: status,
      resumeStep: destination.kind == SessionDestinationKind.resumeOnboarding
          ? destination.resumeStep
          : null,
      completionRunId: destination.runId,
      startupReasonCode: destination.reasonCode,
      error: destination.kind == SessionDestinationKind.needsAction
          ? _sessionRecoveryError(
              'Your saved setup needs recovery before continuing.',
            )
          : null,
      recoveryActions: destination.kind == SessionDestinationKind.needsAction
          ? const [
              RetryNetworkAction(),
              ResetSetupSafelyAction(),
              SignOutAction(),
            ]
          : const [],
      reconstructionResult: reconstructionResult,
      clearReconstructionResult: reconstructionResult == null,
      clearError: true,
      clearStartupDestination: true,
    );
  }

  Future<void> _reconstructAndHydrate(
    AuthUser user,
    int restoreGeneration,
  ) async {
    try {
      // Asset metadata hydrates alongside AH-F007 idempotently. Preview resolution remains
      // asynchronous and never blocks destination classification.
      final assetHydration = _ref
          .read(restoredUploadsProvider.notifier)
          .hydrate(uid: user.uid);
      final result = await _ref
          .read(serverReconstructorProvider)
          .reconstruct(
            uid: user.uid,
            email: user.email ?? '',
            displayName: user.displayName ?? '',
            onProfileLoaded: (profile) {
              if (!_isCurrentRestore(restoreGeneration)) return;
              final suggestsResume =
                  profile != null &&
                  profileHasUnfinishedOnboardingResumeHint(profile);
              if (suggestsResume) {
                state = state.copyWith(
                  user: user,
                  status: AuthFlowStatus.restoringOnboarding,
                  clearError: true,
                  clearStartupDestination: true,
                );
              }
            },
          );
      if (!_isCurrentRestore(restoreGeneration) ||
          state.user?.uid != user.uid) {
        return;
      }

      await assetHydration;
      if (!_isCurrentRestore(restoreGeneration) ||
          state.user?.uid != user.uid) {
        return;
      }

      final missingReferencedIds = switch (result) {
        ReconstructionIncomplete(:final draft) =>
          draft.referencedUploadAssetIds
              .where(
                (id) =>
                    _ref.read(restoredUploadsProvider).forAssetId(id) == null,
              )
              .toSet(),
        ReconstructionFinishing(:final draft) =>
          draft.referencedUploadAssetIds
              .where(
                (id) =>
                    _ref.read(restoredUploadsProvider).forAssetId(id) == null,
              )
              .toSet(),
        ReconstructionCompleted(:final draft) =>
          draft.referencedUploadAssetIds
              .where(
                (id) =>
                    _ref.read(restoredUploadsProvider).forAssetId(id) == null,
              )
              .toSet(),
        _ => const <String>{},
      };
      if (missingReferencedIds.isNotEmpty) {
        await _ref
            .read(restoredUploadsProvider.notifier)
            .hydrate(
              uid: user.uid,
              requiredAssetIds: missingReferencedIds,
              force: true,
            );
        if (!_isCurrentRestore(restoreGeneration) ||
            state.user?.uid != user.uid) {
          return;
        }
      }

      final restoredUploads = _ref.read(restoredUploadsProvider);
      ReconstructionResult effectiveResult = result;

      // Nothing user-visible is hydrated until the complete durable snapshot
      // has been decoded, classified, and reconciled against restored assets.
      _ref.read(userProfileProvider.notifier).loadSeedData(result.profile);

      switch (result) {
        case ReconstructionFresh():
          final now = DateTime.now();
          _ref
              .read(onboardingStateProvider.notifier)
              .loadSeedData(
                OnboardingDraft(
                  uid: user.uid,
                  baseTimeline: const BaseTimelineDraft()
                      .withRequiredFixedBlocks(),
                  createdAt: now,
                  updatedAt: now,
                ),
              );

        case ReconstructionIncomplete(
          :final draft,
          :final ownerUid,
          :final profile,
        ):
          final reconciliation = OnboardingUploadSourceReconciler.reconcile(
            ownerUid: user.uid,
            draft: draft,
            restoredUploads: restoredUploads,
          );
          if (reconciliation.integrityFailure) {
            if (_isUploadHydrationFailure(reconciliation, restoredUploads)) {
              state = state.copyWith(
                user: user,
                status: AuthFlowStatus.reconnectRequired,
                error: _sessionNetworkError(
                  'Uploaded photos could not be restored yet.',
                ),
                recoveryActions: const [RetryNetworkAction(), SignOutAction()],
                startupReasonCode: 'restored_uploads_failed',
                clearStartupDestination: true,
                clearReconstructionResult: true,
              );
              return;
            }
            effectiveResult = _uploadIntegrityRecovery(
              ownerUid: ownerUid,
              profile: profile,
              draft: draft,
              reasonCodes: reconciliation.reasonCodes,
            );
            _ref.read(onboardingStateProvider.notifier).reset(user.uid);
          } else {
            final reconciledDraft = reconciliation.reconciledDraft;
            if (reconciliation.changed) {
              await _ref
                  .read(onboardingRepositoryProvider)
                  .saveDraft(reconciledDraft);
            }
            final resumeValidation = validateOnboardingResume(reconciledDraft);
            final effectiveStep = resumeValidation.resumeStep;
            final finalDraft = reconciledDraft.copyWith(
              currentStep: effectiveStep,
              stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
              incrementRevision: false,
            );
            _ref
                .read(onboardingStateProvider.notifier)
                .loadSeedData(finalDraft);
            effectiveResult = ReconstructionIncomplete(
              ownerUid: ownerUid,
              profile: profile,
              step: effectiveStep,
              draft: finalDraft,
              diagnosticCode: resumeValidation.diagnosticCode,
              diagnostics: onboardingRestoreDiagnostics(
                draft: draft,
                validation: resumeValidation,
                uploadReconciliation: reconciliation.changed
                    ? 'affected'
                    : 'valid',
                uploadReasonCodes: reconciliation.reasonCodes,
              ),
            );
          }

        case ReconstructionFinishing(
          :final draft,
          :final ownerUid,
          :final profile,
        ):
          final reconciliation = OnboardingUploadSourceReconciler.reconcile(
            ownerUid: user.uid,
            draft: draft,
            restoredUploads: restoredUploads,
          );
          if (reconciliation.integrityFailure) {
            if (_isUploadHydrationFailure(reconciliation, restoredUploads)) {
              state = state.copyWith(
                user: user,
                status: AuthFlowStatus.reconnectRequired,
                error: _sessionNetworkError(
                  'Uploaded photos could not be restored yet.',
                ),
                recoveryActions: const [RetryNetworkAction(), SignOutAction()],
                startupReasonCode: 'restored_uploads_failed',
                clearStartupDestination: true,
                clearReconstructionResult: true,
              );
              return;
            }
            effectiveResult = ReconstructionRecovery(
              ownerUid: ownerUid,
              profile: profile,
              reason: _uploadIntegrityRecoveryReason(
                reconciliation.reasonCodes,
              ),
              diagnostics: {
                ...onboardingRestoreDiagnostics(
                  draft: draft,
                  validation: validateOnboardingResume(draft),
                  uploadReconciliation: 'integrity_failure',
                  uploadReasonCodes: reconciliation.reasonCodes,
                ),
                'code':
                    reconciliation.reasonCodes.firstOrNull ??
                    'upload_source_integrity_failure',
              },
            );
            _ref.read(onboardingStateProvider.notifier).reset(user.uid);
          } else if (reconciliation.changed) {
            effectiveResult = ReconstructionRecovery(
              ownerUid: ownerUid,
              profile: profile,
              reason: ReconstructionRecoveryReason.durableStateConflict,
              diagnostics: {
                ...onboardingRestoreDiagnostics(
                  draft: draft,
                  validation: validateOnboardingResume(
                    reconciliation.reconciledDraft,
                  ),
                  uploadReconciliation: 'affected',
                  uploadReasonCodes: reconciliation.reasonCodes,
                ),
                'code': 'finishing_draft_upload_source_mismatch',
              },
            );
            _ref.read(onboardingStateProvider.notifier).reset(user.uid);
          } else {
            _ref
                .read(onboardingStateProvider.notifier)
                .loadSeedData(
                  draft.copyWith(
                    currentStep: OnboardingDraft.lastStepIndex,
                    stepLoading: List<bool>.filled(
                      OnboardingDraft.stepCount,
                      false,
                    ),
                    incrementRevision: false,
                  ),
                );
          }

        case ReconstructionCompleted(:final draft, :final completionBundle):
          _ref
              .read(onboardingStateProvider.notifier)
              .loadSeedData(
                draft.copyWith(
                  stepLoading: List<bool>.filled(
                    OnboardingDraft.stepCount,
                    false,
                  ),
                  incrementRevision: false,
                ),
              );
          if (!_isCurrentRestore(restoreGeneration) ||
              state.user?.uid != user.uid ||
              completionBundle.uid != user.uid) {
            return;
          }
          try {
            await const OnboardingFrontendHydrationService()
                .restoreVerifiedFrontendState(
                  read: _ref.read,
                  bundle: completionBundle,
                );
          } catch (_) {
            if (!_isCurrentRestore(restoreGeneration) ||
                state.user?.uid != user.uid) {
              return;
            }
            state = state.copyWith(
              user: user,
              status: AuthFlowStatus.reconnectRequired,
              error: _sessionNetworkError(
                "We couldn't restore your completed setup yet.",
              ),
              recoveryActions: const [RetryNetworkAction(), SignOutAction()],
              startupReasonCode: 'completed_frontend_restore_failed',
              clearStartupDestination: true,
              clearReconstructionResult: true,
            );
            return;
          }
          if (!_isCurrentRestore(restoreGeneration) ||
              state.user?.uid != user.uid) {
            return;
          }

        case ReconstructionRecovery():
          _ref.read(onboardingStateProvider.notifier).reset(user.uid);
      }

      _ref.read(homeDashboardProvider.notifier).setOwnerUid(user.uid);
      _ref.read(fitnessCenterProvider.notifier).setOwnerUid(user.uid);
      _logOnboardingRestoreResult(effectiveResult);
      _applySessionDestination(
        user,
        resolveReconstructionDestination(effectiveResult),
        reconstructionResult: effectiveResult,
      );
      if (effectiveResult case ReconstructionRecovery(
        :final reason,
        :final diagnostics,
      )) {
        final missingCompletedState =
            diagnostics['code'] == 'completed_profile_without_final_draft';
        state = state.copyWith(
          error: ReconstructionErrorMapper.fromRecoveryReason(reason).copyWith(
            publicMessage: missingCompletedState
                ? 'Setup recovery is required because both draft and completion snapshot are missing.'
                : 'Setup recovery is required because durable onboarding state is inconsistent.',
          ),
          startupReasonCode: 'reconstruction_${reason.name}',
        );
      }
    } on ReconstructionBootstrapException {
      if (!_isCurrentRestore(restoreGeneration)) return;
      // The UID-owned logical operation classifies and, when appropriate,
      // retries this before publishing any router-visible recovery state.
      rethrow;
    }
  }

  void _logReconstruction(String event) {
    if (kDebugMode) debugPrint('[Reconstruction] $event');
  }

  void _logOnboardingRestoreResult(ReconstructionResult result) {
    if (!kDebugMode) return;
    final diagnostics = switch (result) {
      ReconstructionIncomplete(:final diagnostics) => diagnostics,
      ReconstructionRecovery(:final diagnostics) => diagnostics,
      ReconstructionFinishing(:final draft) => onboardingRestoreDiagnostics(
        draft: draft,
        validation: validateOnboardingResume(draft),
        uploadReconciliation: 'valid',
      ),
      ReconstructionCompleted(:final draft) => <String, Object?>{
        'schemaVersion': draft.storedSchemaVersion,
        'detectedTopology': draft.restoredStepLayout.name,
        'migrationAction':
            draft.storedSchemaVersion < OnboardingDraft.schemaVersion
            ? 'completion_contracts_v1_migrated'
            : 'none',
        'originalAcknowledgedCompletionBoundary':
            durableAcknowledgedCompletionBoundary(draft),
        'durableValidatorResult': 'verified_completion_bundle',
        'uploadReconciliation': 'valid',
        'finalResumeStep': 'home',
        'reasonCode': 'completed_onboarding',
      },
      ReconstructionFresh() => const <String, Object?>{
        'migrationAction': 'none',
        'uploadReconciliation': 'valid',
        'finalResumeStep': 0,
        'reasonCode': 'fresh_account',
      },
    };
    debugPrint('[OnboardingRestore] $diagnostics');
  }

  bool _isCurrentRestore(int restoreGeneration) {
    return mounted && restoreGeneration == _backendRestoreGeneration;
  }

  bool _isUploadHydrationFailure(
    OnboardingUploadSourceReconciliationResult reconciliation,
    RestoredUploadsState restoredUploads,
  ) {
    return reconciliation.reasonCodes.contains('restored_uploads_error') ||
        restoredUploads.errorMessage?.trim().isNotEmpty == true;
  }

  ReconstructionRecoveryReason _uploadIntegrityRecoveryReason(
    List<String> reasonCodes,
  ) {
    return reasonCodes.any(
          (code) =>
              code == 'empty_owner_uid' ||
              code == 'draft_owner_mismatch' ||
              code == 'restored_uploads_owner_mismatch',
        )
        ? ReconstructionRecoveryReason.ownerMismatch
        : ReconstructionRecoveryReason.durableStateConflict;
  }

  ReconstructionRecovery _uploadIntegrityRecovery({
    required String ownerUid,
    required UserProfile profile,
    required OnboardingDraft draft,
    required List<String> reasonCodes,
  }) {
    return ReconstructionRecovery(
      ownerUid: ownerUid,
      profile: profile,
      reason: _uploadIntegrityRecoveryReason(reasonCodes),
      diagnostics: {
        ...onboardingRestoreDiagnostics(
          draft: draft,
          validation: validateOnboardingResume(draft),
          uploadReconciliation: 'integrity_failure',
          uploadReasonCodes: reasonCodes,
        ),
        'code': reasonCodes.firstOrNull ?? 'upload_source_integrity_failure',
      },
    );
  }

  bool _isCurrentAuthOperation(int operation) {
    return mounted && operation == _authOperationGeneration;
  }

  void _startDisplayNameEnrichment({
    required int operation,
    required AuthUser user,
    required String name,
  }) {
    final displayName = name.trim();
    final repository = _repository;
    if (displayName.isEmpty) return;
    if (repository is! AuthProfileEnrichmentRepository) return;
    final enrichmentRepository = repository as AuthProfileEnrichmentRepository;
    unawaited(
      _enrichDisplayName(
        repository: enrichmentRepository,
        operation: operation,
        user: user,
        displayName: displayName,
      ),
    );
  }

  Future<void> _enrichDisplayName({
    required AuthProfileEnrichmentRepository repository,
    required int operation,
    required AuthUser user,
    required String displayName,
  }) async {
    _logEmailVerificationDebug(
      '[EmailVerification] stage=display_name_update_started uid=${_maskedUid(user.uid)}',
    );
    try {
      await repository.updateDisplayName(
        uid: user.uid,
        displayName: displayName,
      );
      if (!_isCurrentAuthOperation(operation) || state.user?.uid != user.uid) {
        return;
      }
      _logEmailVerificationDebug(
        '[EmailVerification] stage=display_name_update_success uid=${_maskedUid(user.uid)}',
      );
    } catch (error) {
      // Profile metadata is optional. Its failure never changes the completed
      // verification-email result or the current auth destination.
      final mapped = AuthErrorMapper.map(error);
      _logEmailVerificationDebug(
        '[EmailVerification] stage=display_name_update_failure code=${mapped.diagnosticCode}',
      );
    }
  }

  bool _claimExpectedSignupAuthEvent(AuthUser user) {
    final handoff = _signupCredentialHandoff;
    if (handoff == null ||
        handoff.operation != _authOperationGeneration ||
        user.email?.trim().toLowerCase() != handoff.normalizedEmail ||
        (handoff.observedUid != null && handoff.observedUid != user.uid)) {
      return false;
    }
    handoff.observedUid = user.uid;
    return true;
  }

  bool get _useFirebaseBackend {
    return !_ref.read(fakeBackendPolicyProvider).fakeDataAllowed;
  }

  Future<void> _loadDevSeedState(AuthUser user) async {
    final policy = _ref.read(fakeBackendPolicyProvider);
    policy.ensureValid();
    if (!policy.fakeDataAllowed) {
      throw StateError('MockSeedData requested outside allowed fake mode.');
    }
    final now = DateTime.now();
    final completed = List<bool>.filled(OnboardingDraft.stepCount, true);
    _ref
        .read(userProfileProvider.notifier)
        .loadSeedData(
          MockSeedData.defaultUserProfile.copyWith(
            uid: user.uid,
            email: user.email ?? '',
            displayName: user.displayName ?? 'Dev Test',
            onboardingCompleted: true,
            onboardingStep: OnboardingDraft.lastStepIndex,
            updatedAt: now,
          ),
        );
    _ref
        .read(onboardingStateProvider.notifier)
        .loadSeedData(
          OnboardingDraft(
            uid: user.uid,
            currentStep: OnboardingDraft.lastStepIndex,
            stepCompleted: completed,
            stepDirty: List<bool>.filled(OnboardingDraft.stepCount, false),
            stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
            createdAt: now,
            updatedAt: now,
            onboardingCompleted: true,
          ),
        );
    _ref.read(mockRoutineProvider.notifier).loadSeedData();
    await _ref.read(routineNotifierProvider.notifier).loadForOwner(user.uid);
    await _ref
        .read(routineNotifierProvider.notifier)
        .addMissingItems(
          MockSeedData.defaultRoutineItems
              .map((item) => item.copyWith(userId: user.uid))
              .toList(growable: false),
        );
    _ref.read(mockTrackerProvider.notifier).loadSeedData();
    _ref.read(mockGoalProvider.notifier).loadSeedData();
    _ref.read(mockMindNoteProvider.notifier).loadSeedData();
    _ref.read(mockCoachProvider.notifier).loadSeedData();
    _ref.read(mockCoachPreferencesProvider.notifier).resetEmpty();
    _ref
        .read(mockNotificationPreferencesProvider.notifier)
        .updatePreferences(NotificationPreferences());
    _ref.read(mockPermissionProvider.notifier).resetEmpty();
  }

  void _resetNormalUserState(AuthUser user) {
    _ref
        .read(userProfileProvider.notifier)
        .resetEmpty(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? '',
        );
    _ref.read(onboardingStateProvider.notifier).reset(user.uid);
    _ref
        .read(authSessionResetCoordinatorProvider)
        .resetFeatureStateForHydration();
  }

  Future<void> _loadFakeUserState(AuthUser user, [int? restoreGen]) async {
    if (user.uid.trim().isEmpty) return;
    final savedDraft = await _ref
        .read(onboardingRepositoryProvider)
        .fetchDraft(user.uid);
    if (restoreGen != null && !_isCurrentRestore(restoreGen)) return;
    if (savedDraft == null) {
      _resetNormalUserState(user);
      await _ref.read(routineNotifierProvider.notifier).loadForOwner(user.uid);
      if (restoreGen != null && !_isCurrentRestore(restoreGen)) return;
      await _ref
          .read(habitSystemsNotifierProvider.notifier)
          .loadForOwner(user.uid);
      return;
    }

    if (savedDraft.onboardingCompleted) {
      final profile =
          UserProfile.empty(
            uid: user.uid,
            email: user.email ?? '',
            displayName: user.displayName ?? '',
          ).copyWith(
            onboardingCompleted: true,
            onboardingStep: OnboardingDraft.lastStepIndex,
            updatedAt: DateTime.now(),
          );
      _ref.read(userProfileProvider.notifier).loadSeedData(profile);
    } else {
      final profile =
          UserProfile.empty(
            uid: user.uid,
            email: user.email ?? '',
            displayName: user.displayName ?? '',
          ).copyWith(
            onboardingCompleted: false,
            onboardingStep: savedDraft.currentStep,
            updatedAt: DateTime.now(),
          );
      _ref.read(userProfileProvider.notifier).loadSeedData(profile);
    }

    _ref
        .read(onboardingStateProvider.notifier)
        .loadSeedData(
          savedDraft.copyWith(
            uid: user.uid,
            stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
            incrementRevision: false,
          ),
        );
    _ref
        .read(authSessionResetCoordinatorProvider)
        .resetFeatureStateForHydration();
    final bundle = await _ref
        .read(onboardingRepositoryProvider)
        .fetchCompletionBundle(user.uid);
    if (restoreGen != null && !_isCurrentRestore(restoreGen)) return;
    if (savedDraft.onboardingCompleted && bundle != null) {
      await const OnboardingFrontendHydrationService().hydrate(
        read: _ref.read,
        bundle: bundle,
      );
    } else {
      await _ref.read(routineNotifierProvider.notifier).loadForOwner(user.uid);
      if (restoreGen != null && !_isCurrentRestore(restoreGen)) return;
      await _ref
          .read(habitSystemsNotifierProvider.notifier)
          .loadForOwner(user.uid);
    }
  }

  void _resetSignedOutState({String? preserveOnboardingUid}) {
    _ref
        .read(authSessionResetCoordinatorProvider)
        .resetIdentityBoundary(preserveOnboardingUid: preserveOnboardingUid);
  }

  /// The single in-process privacy boundary for null -> A and A -> B.
  /// Clearing is synchronous and occurs before the new UID is published or
  /// hydrated, so listeners can never observe the new account with old state.
  void _clearStateForIdentityBoundary(AuthUser nextUser) {
    if (state.user?.uid == nextUser.uid) return;
    final previousUid = state.user?.uid;
    _backendRestoreGeneration++;
    _resetSignedOutState(
      preserveOnboardingUid: previousUid == null ? nextUser.uid : null,
    );
    state = state.copyWith(clearVerificationEmailState: true);
  }

  Future<void> executeRecoveryAction(OnboardingRecoveryAction action) async {
    final currentUser = state.user ?? _repository.currentUser;
    if (currentUser == null || currentUser.uid.trim().isEmpty) return;
    final actionUid = currentUser.uid;
    final capturedAuthGeneration = _ref.read(authGenerationProvider);
    final operations = OnboardingRecoveryOperations(
      retryBackendRestore: retryBackendRestore,
      markOnboardingIncomplete: () async {
        final activeUser = state.user ?? _repository.currentUser;
        if (activeUser == null || activeUser.uid != actionUid) return;
        await markOnboardingIncomplete(activeUser);
      },
      signOut: logout,
    );
    try {
      await action.execute(_ref, actionUid, operations);
      if (!mounted ||
          state.user?.uid != actionUid ||
          _ref.read(authGenerationProvider) != capturedAuthGeneration) {
        return;
      }
    } catch (e) {
      debugPrint(
        '[AuthRecovery] Recovery action failed safely (${e.runtimeType}).',
      );
      if (mounted &&
          state.user?.uid == actionUid &&
          _ref.read(authGenerationProvider) == capturedAuthGeneration) {
        state = state.copyWith(
          user: currentUser,
          status: AuthFlowStatus.needsAction,
          error: _sessionRecoveryError(
            'That recovery action could not be completed safely.',
          ),
          recoveryActions: const [ResetSetupSafelyAction()],
        );
      }
    }
  }
}

@visibleForTesting
bool profileHasUnfinishedOnboardingResumeHint(UserProfile profile) {
  if (profile.onboardingCompleted || profile.onboardingInputCompleted) {
    return false;
  }
  final projectionStatus = profile.onboardingProjectionStatus.trim();
  final projectionIsPreCompletion =
      projectionStatus.isEmpty ||
      projectionStatus == 'none' ||
      projectionStatus == 'pending';
  return profile.onboardingStep > 0 || !projectionIsPreCompletion;
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository, ref);
});
