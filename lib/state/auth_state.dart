import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/core/utils/auth_error_mapper.dart';
import 'package:optivus/features/profile/models/profile_settings_models.dart';
import 'package:optivus/features/profile/providers/profile_settings_provider.dart';
import 'package:optivus/features/routine/controllers/habit_systems_controller.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/app_preferences_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/repositories/region_settings_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/services/onboarding_frontend_hydration_service.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/services/routine_projection_receipt_validator.dart';

import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/mock_seed_data.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/services/routine_onboarding_event_projector.dart';
import 'package:optivus/state/region_settings_provider.dart';
import 'package:optivus/core/utils/liquid_toast_manager.dart';
import 'package:optivus/features/recovery/models/onboarding_recovery_models.dart';
import 'package:optivus/features/recovery/services/recovery_retry_controller.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/features/coach/providers/coach_navigation_provider.dart';
import 'package:optivus/features/goals/providers/goals_navigation_provider.dart';
import 'package:optivus/features/home/providers/home_dashboard_provider.dart';
import 'package:optivus/features/home/providers/home_mind_note_provider.dart';
import 'package:optivus/features/home/providers/home_navigation_provider.dart';
import 'package:optivus/features/profile/providers/profile_navigation_provider.dart';
import 'package:optivus/features/routine/providers/routine_navigation_provider.dart';
import 'package:optivus/features/tracker/fitness/providers/fitness_provider.dart';
import 'package:optivus/features/tracker/providers/tracker_navigation_provider.dart';
import 'package:optivus/features/tracker/providers/tracker_settings_provider.dart';
import 'package:optivus/services/onboarding_account_migration_service.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/state/upload_state.dart';
import 'package:optivus/state/auth_generation.dart';
import 'package:optivus/services/session_destination_resolver.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (ref.watch(optivusBackendModeProvider) == OptivusBackendMode.firebase) {
    return FirebaseAuthRepository();
  }
  return FakeAuthRepository();
});

enum AuthFlowStatus {
  loading,
  loadingBackendUser,
  restoringOnboarding,
  signedOut,
  signedInEmailUnverified,
  signedInOnboardingIncomplete,
  finishingOnboarding,
  signedInOnboardingComplete,
  reconnectRequired,
  needsAction,
  error,
  @Deprecated('Use reconnectRequired or needsAction.')
  backendRestoreFailed,
}

class AuthState {
  final AuthUser? user;
  final AuthFlowStatus status;
  final String? errorMessage;
  final AuthFailureReason? failureReason;
  final OnboardingFailureReason? onboardingFailureReason;
  final List<OnboardingRecoveryAction> recoveryActions;
  final DateTime? lastVerificationEmailSent;
  final int? resumeStep;
  final String? completionRunId;
  final String? startupReasonCode;

  const AuthState({
    this.user,
    this.status = AuthFlowStatus.signedOut,
    this.errorMessage,
    this.failureReason,
    this.onboardingFailureReason,
    this.recoveryActions = const [],
    this.lastVerificationEmailSent,
    this.resumeStep,
    this.completionRunId,
    this.startupReasonCode,
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
      status == AuthFlowStatus.needsAction ||
      status == AuthFlowStatus.backendRestoreFailed;
  bool get backendRestoreFailed =>
      status == AuthFlowStatus.backendRestoreFailed;

  SessionDestination get sessionDestination {
    return switch (status) {
      AuthFlowStatus.loading ||
      AuthFlowStatus.loadingBackendUser ||
      AuthFlowStatus.restoringOnboarding =>
        const SessionDestination.resolving(),
      AuthFlowStatus.signedOut => const SessionDestination.signedOut(),
      AuthFlowStatus.signedInEmailUnverified =>
        const SessionDestination.verifyEmail(),
      AuthFlowStatus.signedInOnboardingIncomplete =>
        resumeStep == null
            ? const SessionDestination.freshOnboarding()
            : SessionDestination.resumeOnboarding(resumeStep!),
      AuthFlowStatus.finishingOnboarding => SessionDestination.finishOnboarding(
        runId: completionRunId,
      ),
      AuthFlowStatus.signedInOnboardingComplete =>
        const SessionDestination.home(),
      AuthFlowStatus.reconnectRequired => SessionDestination.reconnect(
        reasonCode: startupReasonCode,
      ),
      AuthFlowStatus.needsAction ||
      AuthFlowStatus.backendRestoreFailed => SessionDestination.needsAction(
        startupReasonCode ?? 'setup_requires_attention',
      ),
      AuthFlowStatus.error =>
        user == null
            ? const SessionDestination.signedOut()
            : const SessionDestination.needsAction('authenticated_error'),
    };
  }

  AuthState copyWith({
    AuthUser? user,
    AuthFlowStatus? status,
    String? errorMessage,
    AuthFailureReason? failureReason,
    OnboardingFailureReason? onboardingFailureReason,
    List<OnboardingRecoveryAction>? recoveryActions,
    DateTime? lastVerificationEmailSent,
    int? resumeStep,
    String? completionRunId,
    String? startupReasonCode,
    bool clearUser = false,
    bool clearError = false,
    bool clearStartupDestination = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      status: status ?? this.status,
      errorMessage: clearError && errorMessage == null
          ? null
          : (errorMessage ?? this.errorMessage),
      failureReason: clearError && failureReason == null
          ? null
          : (failureReason ?? this.failureReason),
      onboardingFailureReason: clearError && onboardingFailureReason == null
          ? null
          : (onboardingFailureReason ?? this.onboardingFailureReason),
      recoveryActions: clearError && recoveryActions == null
          ? const []
          : (recoveryActions ?? this.recoveryActions),
      lastVerificationEmailSent:
          lastVerificationEmailSent ?? this.lastVerificationEmailSent,
      resumeStep: clearStartupDestination && resumeStep == null
          ? null
          : (resumeStep ?? this.resumeStep),
      completionRunId: clearStartupDestination && completionRunId == null
          ? null
          : (completionRunId ?? this.completionRunId),
      startupReasonCode: clearStartupDestination && startupReasonCode == null
          ? null
          : (startupReasonCode ?? this.startupReasonCode),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  static const Duration _startupResolutionTimeout = Duration(seconds: 12);
  final AuthRepository _repository;
  final Ref _ref;
  late final StreamSubscription<AuthUser?> _authSubscription;
  int _backendRestoreGeneration = 0;
  int _authOperationGeneration = 0;
  final Set<Timer> _startupTimers = <Timer>{};

  AuthNotifier(this._repository, Ref ref)
    : _ref = ref,
      super(
        AuthState(
          status:
              ref.read(optivusBackendModeProvider) ==
                  OptivusBackendMode.firebase
              ? AuthFlowStatus.loading
              : AuthFlowStatus.signedOut,
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
      final mapped = mapAuthError(error);
      state = state.copyWith(
        user: previousUser,
        status: AuthFlowStatus.error,
        errorMessage: mapped.message,
        failureReason: mapped.reason,
      );
      rethrow;
    } finally {
      if (_isCurrentAuthOperation(operation) && state.isAuthenticating) {
        state = state.copyWith(
          status: statusFor(
            state.user,
            _ref.read(mockUserProfileProvider).onboardingCompleted,
          ),
        );
      }
    }
  }

  Future<void> signup(String name, String email, String password) async {
    final operation = ++_authOperationGeneration;
    final previousUser = state.user;
    state = state.copyWith(status: AuthFlowStatus.loading, clearError: true);
    AuthUser? createdUser;
    try {
      final user = await _repository.signUp(email, password, name: name);
      if (!_isCurrentAuthOperation(operation)) return;
      createdUser = user;
      if (_needsEmailVerification(user)) {
        state = state.copyWith(
          user: user,
          status: AuthFlowStatus.signedInEmailUnverified,
          clearError: true,
          lastVerificationEmailSent: DateTime.now(),
        );
        await _repository.sendEmailVerification();
        if (!_isCurrentAuthOperation(operation)) return;
        return;
      }
      await _loadBackendWithTimeout(user);
    } catch (error) {
      if (!_isCurrentAuthOperation(operation)) rethrow;
      final mapped = mapAuthError(error);
      final activeUser = createdUser ?? previousUser;
      state = state.copyWith(
        user: activeUser,
        status: activeUser != null && _needsEmailVerification(activeUser)
            ? AuthFlowStatus.signedInEmailUnverified
            : AuthFlowStatus.error,
        errorMessage: mapped.message,
        failureReason: mapped.reason,
      );
      rethrow;
    } finally {
      if (_isCurrentAuthOperation(operation) && state.isAuthenticating) {
        state = state.copyWith(
          status: statusFor(
            state.user,
            _ref.read(mockUserProfileProvider).onboardingCompleted,
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
      final mapped = mapAuthError(error);
      state = state.copyWith(
        status: AuthFlowStatus.error,
        errorMessage: mapped.message,
        failureReason: mapped.reason,
      );
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
        state = state.copyWith(
          user: user,
          status: AuthFlowStatus.signedInEmailUnverified,
          clearError: true,
        );
        await _repository.sendEmailVerification();
        if (!_isCurrentAuthOperation(operation)) return;
        return;
      }

      await _loadBackendWithTimeout(user, isAnonymousLink: true);
    } catch (error) {
      if (!_isCurrentAuthOperation(operation)) rethrow;
      final mapped = mapAuthError(error);
      state = state.copyWith(
        user: oldUser,
        status: oldUser != null && oldUser.isAnonymous
            ? (oldUser.emailVerified
                  ? AuthFlowStatus.signedInOnboardingIncomplete
                  : AuthFlowStatus.signedInEmailUnverified)
            : AuthFlowStatus.error,
        errorMessage: mapped.message,
        failureReason: mapped.reason,
      );
      rethrow;
    }
  }

  Future<void> logout() async {
    ++_authOperationGeneration;
    state = state.copyWith(status: AuthFlowStatus.loading, clearError: true);
    try {
      await _repository.signOut();
    } catch (error) {
      final mapped = mapAuthError(error);
      state = state.copyWith(
        status: AuthFlowStatus.error,
        errorMessage: mapped.message,
        failureReason: mapped.reason,
      );
      rethrow;
    } finally {
      _resetSignedOutState();
      if (mounted) {
        state = const AuthState(status: AuthFlowStatus.signedOut);
      }
    }
  }

  Future<void> resendEmailVerification() async {
    try {
      await _repository.sendEmailVerification();
      state = state.copyWith(
        clearError: true,
        lastVerificationEmailSent: DateTime.now(),
      );
    } catch (error) {
      final mapped = mapAuthError(error);
      state = state.copyWith(
        status: AuthFlowStatus.signedInEmailUnverified,
        errorMessage: mapped.message,
        failureReason: mapped.reason,
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
          errorMessage:
              'We could not confirm it yet. Tap the link in your email, then try again.',
          failureReason: AuthFailureReason.invalidCredentials,
        );
        throw Exception('Email not verified yet.');
      }

      await _loadOrCreateBackendUserState(user);
    } catch (error) {
      if (!_isCurrentAuthOperation(operation)) rethrow;
      if (error.toString().contains('Email not verified yet.')) {
        rethrow;
      }
      final mapped = mapAuthError(error);
      state = state.copyWith(
        status: AuthFlowStatus.signedInEmailUnverified,
        errorMessage: mapped.message,
        failureReason: mapped.reason,
      );
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _repository.sendPasswordResetEmail(email);
    } catch (error) {
      final mapped = mapAuthError(error);
      state = state.copyWith(
        status: AuthFlowStatus.error,
        errorMessage: mapped.message,
        failureReason: mapped.reason,
      );
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
    _ref.read(mockUserProfileProvider.notifier).updateProfile(profile);
    state = state.copyWith(
      user: user,
      status: AuthFlowStatus.signedInOnboardingComplete,
      clearError: true,
      clearStartupDestination: true,
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
        final profile = _ref.read(mockUserProfileProvider);
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
    } on TimeoutException {
      if (!isActiveOwner()) return;
      state = state.copyWith(
        user: user,
        status: AuthFlowStatus.reconnectRequired,
        errorMessage: "We couldn't reconnect yet.",
        onboardingFailureReason: OnboardingFailureReason.networkTimeout,
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
        errorMessage: fatal
            ? "We couldn't finish loading your setup."
            : "We couldn't reconnect yet.",
        onboardingFailureReason: fatal
            ? OnboardingFailureReason.unhandledException
            : OnboardingFailureReason.networkTimeout,
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
        .read(mockUserProfileProvider)
        .copyWith(
          uid: user.uid,
          onboardingInputCompleted: false,
          onboardingProjectionStatus: 'pending',
          onboardingCompleted: false,
          onboardingStep: 0,
          updatedAt: DateTime.now(),
        );
    _ref.read(mockUserProfileProvider.notifier).updateProfile(profile);
    if (_useFirebaseBackend && !_needsEmailVerification(user)) {
      await _ref.read(profileRepositoryProvider).saveUserProfile(profile);
    }
    state = state.copyWith(
      user: user,
      status: AuthFlowStatus.signedInOnboardingIncomplete,
      clearError: true,
      resumeStep: 0,
      clearStartupDestination: true,
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
    final isPasswordProvider = user.providerId == 'password';
    return isPasswordProvider && !user.emailVerified;
  }

  Future<void> _handleAuthStateChange(AuthUser? user) async {
    if (!mounted) return;

    final previousUser = state.user;

    if (user == null) {
      _authOperationGeneration++;
      _backendRestoreGeneration++;
      _resetSignedOutState();
      state = const AuthState(status: AuthFlowStatus.signedOut);
      return;
    }

    final isAccountSwitch =
        previousUser != null && previousUser.uid != user.uid;

    if (_needsEmailVerification(user)) {
      if (isAccountSwitch) {
        state = state.copyWith(
          user: user,
          status: AuthFlowStatus.loadingBackendUser,
          clearError: true,
        );
        _resetSignedOutState(targetUserUid: user.uid);
      }
      state = state.copyWith(
        user: user,
        status: AuthFlowStatus.signedInEmailUnverified,
        clearError: true,
      );
      return;
    }

    if (isAccountSwitch) {
      _authOperationGeneration++;
      state = state.copyWith(
        user: user,
        status: AuthFlowStatus.loadingBackendUser,
        clearError: true,
      );
      _resetSignedOutState(targetUserUid: user.uid);
    }

    try {
      await _loadBackendWithTimeout(user);
    } catch (e) {
      if (!mounted) return;
      final mapped = mapAuthError(e);
      state = state.copyWith(
        user: user,
        status: AuthFlowStatus.reconnectRequired,
        errorMessage: mapped.message,
        failureReason: mapped.reason,
        startupReasonCode: 'startup_request_failed',
        clearStartupDestination: true,
      );
    }
  }

  Future<void> _loadBackendWithTimeout(
    AuthUser user, {
    bool isAnonymousLink = false,
  }) async {
    try {
      await _bounded(
        _loadOrCreateBackendUserState(user, isAnonymousLink: isAnonymousLink),
        _startupResolutionTimeout,
      );
    } on TimeoutException {
      _backendRestoreGeneration++;
      if (!mounted || (state.user?.uid ?? user.uid) != user.uid) return;
      state = state.copyWith(
        user: user,
        status: AuthFlowStatus.reconnectRequired,
        errorMessage: "We couldn't reconnect yet.",
        onboardingFailureReason: OnboardingFailureReason.networkTimeout,
        recoveryActions: const [RetryNetworkAction(), SignOutAction()],
        startupReasonCode: 'startup_timeout',
        clearStartupDestination: true,
      );
    }
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
    _resetSignedOutState(targetUserUid: user.uid);
    state = state.copyWith(
      user: user,
      status: AuthFlowStatus.loadingBackendUser,
      clearError: true,
    );
    final restoreGeneration = ++_backendRestoreGeneration;
    if (!_useFirebaseBackend) {
      if (user.uid == 'dev-user-12345') {
        await _loadDevSeedState(user);
      } else {
        await _loadFakeUserState(user, restoreGeneration);
      }
      if (!mounted || !_isCurrentRestore(restoreGeneration)) return;
      _ref.read(homeDashboardProvider.notifier).setOwnerUid(user.uid);
      _ref.read(fitnessCenterProvider.notifier).setOwnerUid(user.uid);
      final profile = _ref.read(mockUserProfileProvider);
      final draft = _ref.read(mockOnboardingProvider).draft;
      final destination = resolveOnboardingSessionDestination(
        ownerUid: user.uid,
        profile: profile,
        draft: draft.uid == user.uid ? draft : null,
      );
      if (destination.kind == SessionDestinationKind.resumeOnboarding) {
        _ref
            .read(mockOnboardingProvider.notifier)
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

    final now = DateTime.now();
    final profileRepository = _ref.read(profileRepositoryProvider);
    final regionRepository = _ref.read(regionSettingsRepositoryProvider);
    final appPreferencesRepository = _ref.read(
      appPreferencesRepositoryProvider,
    );

    state = state.copyWith(
      user: user,
      status: AuthFlowStatus.loadingBackendUser,
      clearError: true,
    );
    _ref.read(routineNotifierProvider.notifier).resetForSignedOut();
    _ref.read(habitSystemsNotifierProvider.notifier).resetForSignedOut();

    try {
      var profile = await profileRepository.fetchUserProfile(user.uid);
      if (!_isCurrentRestore(restoreGeneration)) return;

      final createdProfile = profile == null;
      final fetchedEmail = profile?.email ?? '';
      final fetchedDisplayName = profile?.displayName ?? '';
      profile ??= UserProfile.empty(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? '',
      ).copyWith(createdAt: now, updatedAt: now);

      profile = profile.copyWith(
        uid: user.uid,
        email: profile.email.isEmpty ? user.email ?? '' : profile.email,
        displayName: profile.displayName.isEmpty
            ? user.displayName ?? ''
            : profile.displayName,
        updatedAt: profile.updatedAt ?? now,
      );

      final shouldSaveProfile =
          createdProfile ||
          (fetchedEmail.isEmpty && (user.email ?? '').isNotEmpty) ||
          (fetchedDisplayName.isEmpty && (user.displayName ?? '').isNotEmpty);

      if (shouldSaveProfile) {
        await profileRepository.saveUserProfile(profile);
        if (!_isCurrentRestore(restoreGeneration)) return;
      }

      // Onboarding startup only needs the profile, durable draft, and (for a
      // final draft) its completion job. Profile settings, Routine, History,
      // Habits, and dashboard hydration must not delay the resume destination.
      if (!profile.onboardingCompleted) {
        _ref.read(mockUserProfileProvider.notifier).loadSeedData(profile);

        // A fresh account must not be labelled as a restore before its draft
        // has even been read. The profile step is a loader-only hint; the
        // draft remains the progression authority below.
        final profileSuggestsResume =
            profile.onboardingStep > 0 ||
            profile.onboardingInputCompleted ||
            (profile.onboardingProjectionStatus.isNotEmpty &&
                profile.onboardingProjectionStatus != 'none' &&
                profile.onboardingProjectionStatus != 'pending');
        if (profileSuggestsResume) {
          state = state.copyWith(
            user: user,
            status: AuthFlowStatus.restoringOnboarding,
            clearError: true,
            clearStartupDestination: true,
          );
        }

        var savedDraft = await _ref
            .read(onboardingRepositoryProvider)
            .fetchDraft(user.uid);
        if (!_isCurrentRestore(restoreGeneration)) return;

        OnboardingCompletionJob? completionJob;
        if (savedDraft != null && isDurablyFinalOnboardingDraft(savedDraft)) {
          completionJob = await _ref
              .read(onboardingCompletionJobServiceProvider)
              .loadCurrentJob(user.uid);
          if (!_isCurrentRestore(restoreGeneration)) return;
        }

        var destination = resolveOnboardingSessionDestination(
          ownerUid: user.uid,
          profile: profile,
          draft: savedDraft,
          completionJob: completionJob,
        );

        if (destination.kind == SessionDestinationKind.freshOnboarding &&
            savedDraft == null) {
          savedDraft = OnboardingDraft(
            uid: user.uid,
            baseTimeline: const BaseTimelineDraft().withRequiredFixedBlocks(),
            createdAt: now,
            updatedAt: now,
          );
        }

        if (destination.kind == SessionDestinationKind.resumeOnboarding &&
            state.status != AuthFlowStatus.restoringOnboarding) {
          state = state.copyWith(
            user: user,
            status: AuthFlowStatus.restoringOnboarding,
            clearError: true,
            clearStartupDestination: true,
          );
        }

        if (savedDraft != null &&
            (destination.kind == SessionDestinationKind.freshOnboarding ||
                destination.kind == SessionDestinationKind.resumeOnboarding ||
                destination.kind == SessionDestinationKind.finishOnboarding)) {
          final safeStep = durableOnboardingResumeStep(savedDraft);
          final safeDraft = savedDraft.copyWith(
            uid: user.uid,
            currentStep:
                destination.kind == SessionDestinationKind.finishOnboarding
                ? OnboardingDraft.lastStepIndex
                : safeStep,
            stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
            incrementRevision: false,
          );
          _ref.read(mockOnboardingProvider.notifier).loadSeedData(safeDraft);
          destination = resolveOnboardingSessionDestination(
            ownerUid: user.uid,
            profile: profile,
            draft: savedDraft,
            completionJob: completionJob,
          );
        }

        _applySessionDestination(user, destination);
        return;
      }

      var profileSettings = await profileRepository.fetchProfileSettings(
        user.uid,
      );
      if (!_isCurrentRestore(restoreGeneration)) return;
      if (createdProfile &&
          profileSettings.name.trim().isEmpty &&
          profile.displayName.trim().isNotEmpty) {
        profileSettings = profileSettings.copyWith(name: profile.displayName);
        await profileRepository.saveProfileSettings(user.uid, profileSettings);
        if (!_isCurrentRestore(restoreGeneration)) return;
      }

      var regionSettings = await regionRepository.fetchRegionSettings(user.uid);
      if (!_isCurrentRestore(restoreGeneration)) return;
      if (regionSettings == null) {
        regionSettings = RegionSettings.defaultForUser(user.uid);
        await regionRepository.saveRegionSettings(regionSettings);
        if (!_isCurrentRestore(restoreGeneration)) return;
      }

      var preferences = await appPreferencesRepository.fetchAppPreferences(
        user.uid,
      );
      if (!_isCurrentRestore(restoreGeneration)) return;
      if (preferences == null) {
        preferences = const UserPreferences();
        await appPreferencesRepository.saveAppPreferences(
          user.uid,
          preferences,
        );
        if (!_isCurrentRestore(restoreGeneration)) return;
      }

      _ref.read(mockUserProfileProvider.notifier).loadSeedData(profile);
      if (!profile.onboardingCompleted) {
        state = state.copyWith(
          user: user,
          status: AuthFlowStatus.restoringOnboarding,
          clearError: true,
        );
        final savedDraft = await _ref
            .read(onboardingRepositoryProvider)
            .fetchDraft(user.uid);
        if (!_isCurrentRestore(restoreGeneration)) return;
        if (savedDraft != null) {
          final safeDraft = savedDraft.copyWith(
            uid: user.uid,
            stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
            incrementRevision: false,
          );
          _ref.read(mockOnboardingProvider.notifier).loadSeedData(safeDraft);
        } else if (createdProfile ||
            (!profile.onboardingCompleted &&
                !profile.onboardingInputCompleted &&
                (profile.onboardingProjectionStatus.isEmpty ||
                    profile.onboardingProjectionStatus == 'none' ||
                    profile.onboardingProjectionStatus == 'pending'))) {
          // A newly verified account has no onboarding draft yet. This is the
          // expected first-run state, not missing/corrupt recovery data.
          final freshDraft = OnboardingDraft(
            uid: user.uid,
            baseTimeline: const BaseTimelineDraft().withRequiredFixedBlocks(),
            createdAt: now,
            updatedAt: now,
          );
          await _ref.read(onboardingRepositoryProvider).saveDraft(freshDraft);
          if (!_isCurrentRestore(restoreGeneration)) return;
          _ref.read(mockOnboardingProvider.notifier).loadSeedData(freshDraft);
        } else {
          throw const _RoutineProjectionRestoreException(
            'Setup recovery is required because the onboarding draft is missing.',
            reason: OnboardingFailureReason.missingDraftAndBundle,
            actions: [MigrateLegacySetupAction(), ResetSetupSafelyAction()],
          );
        }
      }
      _resetUserScopedMockState();
      _ref
          .read(profileSettingsProvider.notifier)
          .loadProfileSettings(profileSettings);
      _ref.read(profileSettingsProvider.notifier).loadPreferences(preferences);
      _ref.read(regionSettingsProvider.notifier).loadSettings(regionSettings);

      if (profile.onboardingCompleted) {
        OnboardingCompletionBundle? bundle;
        try {
          bundle = await _ref
              .read(onboardingRepositoryProvider)
              .fetchCompletionBundle(user.uid);
        } catch (e) {
          throw _RoutineProjectionRestoreException(
            'Routine setup recovery is required because the completion snapshot is corrupted: $e',
            reason: OnboardingFailureReason.corruptedBundle,
            actions: const [
              RebuildBundleFromVerifiedDraftAction(),
              MigrateLegacySetupAction(),
              ResetSetupSafelyAction(),
            ],
          );
        }
        if (!_isCurrentRestore(restoreGeneration)) return;

        if (bundle == null || bundle.uid != user.uid) {
          final draft = await _ref
              .read(onboardingRepositoryProvider)
              .fetchDraft(user.uid);
          if (!_isCurrentRestore(restoreGeneration)) return;

          if (draft == null || !isDurablyFinalOnboardingDraft(draft)) {
            throw const _RoutineProjectionRestoreException(
              'Routine setup recovery is required because both draft and completion snapshot are missing.',
              reason: OnboardingFailureReason.missingDraftAndBundle,
              actions: [MigrateLegacySetupAction(), ResetSetupSafelyAction()],
            );
          }
          try {
            final rebuilt = OnboardingCompletionService.buildBundle(draft);
            await _ref
                .read(onboardingRepositoryProvider)
                .saveCompletionBundle(rebuilt);
            bundle = await _ref
                .read(onboardingRepositoryProvider)
                .fetchCompletionBundle(user.uid);
            if (!_isCurrentRestore(restoreGeneration)) return;
            if (bundle == null ||
                bundle.uid != user.uid ||
                bundle.sourceFingerprint != draft.effectiveSourceFingerprint ||
                bundle.draftRevision != draft.revision) {
              throw StateError('Completion snapshot read-back did not match.');
            }
          } catch (_) {
            throw const _RoutineProjectionRestoreException(
              'Routine setup recovery is required because the completion snapshot is missing.',
              reason: OnboardingFailureReason.missingBundle,
              actions: [
                RebuildBundleFromVerifiedDraftAction(),
                ResetSetupSafelyAction(),
              ],
            );
          }
        }

        final completedDraft = await _ref
            .read(onboardingRepositoryProvider)
            .fetchDraft(user.uid);
        if (!_isCurrentRestore(restoreGeneration)) return;
        final draftVerified =
            completedDraft != null &&
            completedDraft.uid == user.uid &&
            completedDraft.onboardingCompleted &&
            completedDraft.currentStep == OnboardingDraft.lastStepIndex &&
            completedDraft.stepCompleted.length == OnboardingDraft.stepCount &&
            completedDraft.stepCompleted.every((value) => value) &&
            completedDraft.revision == bundle.draftRevision &&
            completedDraft.effectiveSourceFingerprint ==
                bundle.sourceFingerprint;
        if (!draftVerified) {
          throw const _RoutineProjectionRestoreException(
            'Setup recovery is required because the final draft and completion snapshot do not match.',
            reason: OnboardingFailureReason.corruptedBundle,
            actions: [MigrateLegacySetupAction(), ResetSetupSafelyAction()],
          );
        }
        _ref
            .read(mockOnboardingProvider.notifier)
            .loadSeedData(
              completedDraft.copyWith(
                stepLoading: List<bool>.filled(
                  OnboardingDraft.stepCount,
                  false,
                ),
                incrementRevision: false,
              ),
            );

        final plan = RoutineOnboardingProjection.build(bundle);
        final routineRepo = _ref.read(routineRepositoryProvider);
        final receipt = await routineRepo.fetchProjectionReceipt(
          user.uid,
          plan.projectionId,
        );
        if (!_isCurrentRestore(restoreGeneration)) return;

        final actualItems = await routineRepo.fetchRoutineItems(user.uid);
        if (!_isCurrentRestore(restoreGeneration)) return;

        final validation = const RoutineProjectionReceiptValidator().validate(
          receipt: receipt,
          actualItems: actualItems,
          ownerUid: user.uid,
          plan: plan,
        );
        if (!validation.isValid) {
          throw _RoutineProjectionRestoreException(
            'Routine setup recovery is required because its projection '
            'receipt is invalid: ${validation.failureReason}',
            reason: OnboardingFailureReason.projectionFailed,
            actions: const [
              RepairProjectionAction(),
              RetryNetworkAction(),
              RebuildBundleFromVerifiedDraftAction(),
            ],
          );
        }

        try {
          await const OnboardingFrontendHydrationService().hydrate(
            read: _ref.read,
            bundle: bundle,
          );
        } on RoutineProjectionFailureException catch (pe) {
          throw _RoutineProjectionRestoreException(
            'Routine setup recovery is required because projection failed: ${pe.message}',
            reason: OnboardingFailureReason.projectionFailed,
            actions: const [
              RepairProjectionAction(),
              RetryNetworkAction(),
              RebuildBundleFromVerifiedDraftAction(),
            ],
          );
        }
        if (!_isCurrentRestore(restoreGeneration)) return;
        final projectedReceipt = await routineRepo.fetchProjectionReceipt(
          user.uid,
          plan.projectionId,
        );
        if (!_isCurrentRestore(restoreGeneration)) return;
        if (projectedReceipt == null ||
            projectedReceipt.status != 'completed' ||
            projectedReceipt.cursor != projectedReceipt.totalCount ||
            projectedReceipt.sourceBundleFingerprint != plan.fingerprint) {
          throw const _RoutineProjectionRestoreException(
            'Routine setup recovery is required because History projection '
            'did not complete.',
            reason: OnboardingFailureReason.projectionFailed,
            actions: [
              RepairProjectionAction(),
              RetryNetworkAction(),
              RebuildBundleFromVerifiedDraftAction(),
            ],
          );
        }
      } else {
        await _ref
            .read(routineNotifierProvider.notifier)
            .loadForOwner(user.uid);
        if (!_isCurrentRestore(restoreGeneration)) return;
      }

      state = state.copyWith(
        user: user,
        status: statusFor(user, profile.onboardingCompleted),
        clearError: true,
        clearStartupDestination: true,
      );
    } on _RoutineProjectionRestoreException catch (error) {
      if (!_isCurrentRestore(restoreGeneration)) return;
      state = state.copyWith(
        user: user,
        status: AuthFlowStatus.needsAction,
        errorMessage: error.message,
        onboardingFailureReason: error.reason,
        recoveryActions: error.actions,
        startupReasonCode: error.reason?.name ?? 'setup_inconsistency',
        clearStartupDestination: true,
      );
    } catch (e) {
      if (!_isCurrentRestore(restoreGeneration)) return;
      state = state.copyWith(
        user: user,
        status: AuthFlowStatus.reconnectRequired,
        errorMessage: "We couldn't reconnect yet.",
        onboardingFailureReason: OnboardingFailureReason.networkTimeout,
        recoveryActions: const [RetryNetworkAction(), SignOutAction()],
        startupReasonCode: 'startup_request_failed',
        clearStartupDestination: true,
      );
    }
  }

  void _applySessionDestination(AuthUser user, SessionDestination destination) {
    final status = switch (destination.kind) {
      SessionDestinationKind.freshOnboarding ||
      SessionDestinationKind.resumeOnboarding =>
        AuthFlowStatus.signedInOnboardingIncomplete,
      SessionDestinationKind.finishOnboarding =>
        AuthFlowStatus.finishingOnboarding,
      SessionDestinationKind.home => AuthFlowStatus.signedInOnboardingComplete,
      SessionDestinationKind.reconnect => AuthFlowStatus.reconnectRequired,
      SessionDestinationKind.needsAction => AuthFlowStatus.needsAction,
      SessionDestinationKind.verifyEmail =>
        AuthFlowStatus.signedInEmailUnverified,
      SessionDestinationKind.signedOut => AuthFlowStatus.signedOut,
      SessionDestinationKind.resolving => AuthFlowStatus.restoringOnboarding,
    };
    state = state.copyWith(
      user: user,
      status: status,
      resumeStep: destination.kind == SessionDestinationKind.resumeOnboarding
          ? destination.resumeStep
          : null,
      completionRunId: destination.runId,
      startupReasonCode: destination.reasonCode,
      onboardingFailureReason:
          destination.kind == SessionDestinationKind.needsAction
          ? OnboardingFailureReason.unhandledException
          : null,
      recoveryActions: destination.kind == SessionDestinationKind.needsAction
          ? const [
              RetryNetworkAction(),
              ResetSetupSafelyAction(),
              SignOutAction(),
            ]
          : const [],
      clearError: true,
      clearStartupDestination: true,
    );
  }

  bool _isCurrentRestore(int restoreGeneration) {
    return mounted && restoreGeneration == _backendRestoreGeneration;
  }

  bool _isCurrentAuthOperation(int operation) {
    return mounted && operation == _authOperationGeneration;
  }

  bool get _useFirebaseBackend {
    return _ref.read(optivusBackendModeProvider) == OptivusBackendMode.firebase;
  }

  Future<void> _loadDevSeedState(AuthUser user) async {
    final now = DateTime.now();
    final completed = List<bool>.filled(OnboardingDraft.stepCount, true);
    _ref
        .read(mockUserProfileProvider.notifier)
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
        .read(mockOnboardingProvider.notifier)
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
        .read(mockUserProfileProvider.notifier)
        .resetEmpty(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? '',
        );
    _ref.read(mockOnboardingProvider.notifier).reset(user.uid);
    _resetUserScopedMockState();
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
      _ref.read(mockUserProfileProvider.notifier).loadSeedData(profile);
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
      _ref.read(mockUserProfileProvider.notifier).loadSeedData(profile);
    }

    _ref
        .read(mockOnboardingProvider.notifier)
        .loadSeedData(
          savedDraft.copyWith(
            uid: user.uid,
            stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
            incrementRevision: false,
          ),
        );
    _resetUserScopedMockState();
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

  void _resetSignedOutState({String? targetUserUid}) {
    _ref.read(authGenerationProvider.notifier).state++;
    _ref.invalidate(onboardingCompletionJobServiceProvider);
    _ref.invalidate(onboardingCompletionJobProvider);
    _ref.read(recoveryRetryControllerProvider.notifier).resetForSignedOut();
    _ref.read(routineNotifierProvider.notifier).resetForSignedOut();
    _ref.read(trackerSessionLinksProvider.notifier).resetForSignedOut();
    _ref.read(habitSystemsNotifierProvider.notifier).resetForSignedOut();
    _ref.read(mockUserProfileProvider.notifier).resetForSignedOut();
    if (targetUserUid == null ||
        _ref.read(mockOnboardingProvider).draft.uid != targetUserUid) {
      _ref.read(mockOnboardingProvider.notifier).resetForSignedOut();
    }
    _ref.read(profileSettingsProvider.notifier).resetForSignedOut();
    _ref.read(homeDashboardProvider.notifier).resetForSignedOut();
    _ref.read(homeMindNoteProvider.notifier).resetForSignedOut();
    _ref.read(fitnessCenterProvider.notifier).resetForSignedOut();
    _ref.read(trackerSettingsProvider.notifier).resetForSignedOut();
    _ref.read(routineImportAiControllerProvider.notifier).resetForSignedOut();
    _ref.read(uploadControllerProvider.notifier).resetForSignedOut();
    _ref.read(appNavigationProvider.notifier).resetForSignedOut();
    _ref.read(toastQueueProvider.notifier).resetForSignedOut();
    _ref.read(homeDetailViewRequestProvider.notifier).state =
        const HomeDetailTarget.none();
    _ref.read(trackerDetailViewRequestProvider.notifier).state =
        TrackerDetailTarget.none;
    _ref.read(profileDetailViewRequestProvider.notifier).state =
        ProfileDetailTarget.none;
    _ref.read(routineDetailViewRequestProvider.notifier).state =
        RoutineDetailTarget.none;
    _ref.read(coachDetailViewRequestProvider.notifier).state =
        CoachDetailView.none;
    _ref.read(goalsDetailViewRequestProvider.notifier).state =
        GoalsDetailTarget.none;
    _ref.read(regionSettingsProvider.notifier).resetForSignedOut();
    _resetUserScopedMockState();
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
        final mapped = mapAuthError(e);
        state = state.copyWith(
          user: currentUser,
          status: AuthFlowStatus.backendRestoreFailed,
          errorMessage: mapped.message,
          onboardingFailureReason: OnboardingFailureReason.projectionFailed,
          recoveryActions: const [ResetSetupSafelyAction()],
        );
      }
    }
  }

  void _resetUserScopedMockState() {
    _ref.read(routineNotifierProvider.notifier).resetForSignedOut();
    if (!_useFirebaseBackend) {
      _ref.read(mockRoutineProvider.notifier).resetForSignedOut();
    }
    _ref.read(mockTrackerProvider.notifier).resetForSignedOut();
    _ref.read(mockGoalProvider.notifier).resetForSignedOut();
    _ref.read(mockMindNoteProvider.notifier).resetForSignedOut();
    _ref.read(homeMindNoteProvider.notifier).resetForSignedOut();
    _ref.read(mockCoachProvider.notifier).resetForSignedOut();
    _ref.read(mockCoachPreferencesProvider.notifier).resetForSignedOut();
    _ref.read(mockNotificationPreferencesProvider.notifier).resetForSignedOut();
    _ref.read(mockPermissionProvider.notifier).resetForSignedOut();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository, ref);
});

class _RoutineProjectionRestoreException implements Exception {
  final String message;
  final OnboardingFailureReason? reason;
  final List<OnboardingRecoveryAction> actions;

  const _RoutineProjectionRestoreException(
    this.message, {
    this.reason,
    this.actions = const [],
  });
}
