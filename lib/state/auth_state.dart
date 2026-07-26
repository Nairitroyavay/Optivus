import 'dart:async';

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
import 'package:optivus/services/onboarding_frontend_hydration_service.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/services/routine_projection_receipt_validator.dart';

import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/mock_seed_data.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/services/routine_onboarding_event_projector.dart';
import 'package:optivus/state/region_settings_provider.dart';
import 'package:optivus/features/recovery/models/onboarding_recovery_models.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
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
  signedInOnboardingComplete,
  error,
  backendRestoreFailed,
}

class AuthState {
  final AuthUser? user;
  final AuthFlowStatus status;
  final String? errorMessage;
  final AuthFailureReason? failureReason;
  final OnboardingFailureReason? onboardingFailureReason;
  final List<OnboardingRecoveryAction> recoveryActions;

  const AuthState({
    this.user,
    this.status = AuthFlowStatus.signedOut,
    this.errorMessage,
    this.failureReason,
    this.onboardingFailureReason,
    this.recoveryActions = const [],
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
      status == AuthFlowStatus.backendRestoreFailed;
  bool get backendRestoreFailed =>
      status == AuthFlowStatus.backendRestoreFailed;

  AuthState copyWith({
    AuthUser? user,
    AuthFlowStatus? status,
    String? errorMessage,
    AuthFailureReason? failureReason,
    OnboardingFailureReason? onboardingFailureReason,
    List<OnboardingRecoveryAction>? recoveryActions,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      failureReason: clearError ? null : (failureReason ?? this.failureReason),
      onboardingFailureReason: clearError
          ? null
          : (onboardingFailureReason ?? this.onboardingFailureReason),
      recoveryActions: clearError
          ? const []
          : (recoveryActions ?? this.recoveryActions),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final Ref _ref;
  late final StreamSubscription<AuthUser?> _authSubscription;
  int _backendRestoreGeneration = 0;

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
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> login(String email, String password) async {
    final previousUser = state.user;
    state = state.copyWith(status: AuthFlowStatus.loading, clearError: true);
    try {
      final user = await _repository.signIn(email, password);

      if (_needsEmailVerification(user)) {
        state = state.copyWith(
          user: user,
          status: AuthFlowStatus.signedInEmailUnverified,
          clearError: true,
        );
        return;
      }

      await _loadOrCreateBackendUserState(user);
    } catch (error) {
      final mapped = mapAuthError(error);
      state = state.copyWith(
        user: previousUser,
        status: AuthFlowStatus.error,
        errorMessage: mapped.message,
        failureReason: mapped.reason,
      );
      rethrow;
    } finally {
      if (mounted && state.isAuthenticating) {
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
    final previousUser = state.user;
    state = state.copyWith(status: AuthFlowStatus.loading, clearError: true);
    try {
      final user = await _repository.signUp(email, password, name: name);
      if (_needsEmailVerification(user)) {
        state = state.copyWith(
          user: user,
          status: AuthFlowStatus.signedInEmailUnverified,
          clearError: true,
        );
        await _repository.sendEmailVerification();
        return;
      }
      await _loadOrCreateBackendUserState(user);
    } catch (error) {
      final mapped = mapAuthError(error);
      state = state.copyWith(
        user: previousUser,
        status: AuthFlowStatus.error,
        errorMessage: mapped.message,
        failureReason: mapped.reason,
      );
      rethrow;
    } finally {
      if (mounted && state.isAuthenticating) {
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
    state = state.copyWith(status: AuthFlowStatus.loading, clearError: true);
    try {
      final user = await _repository.signInAnonymously();
      await _loadOrCreateBackendUserState(user);
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

  Future<void> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async {
    final oldUser = state.user;
    final oldAnonUid = oldUser?.isAnonymous == true ? oldUser!.uid : null;

    state = state.copyWith(status: AuthFlowStatus.loading, clearError: true);
    try {
      final user = await _repository.linkAnonymousWithEmail(
        email,
        password,
        name: name,
      );

      if (oldAnonUid != null && oldAnonUid != user.uid) {
        await OnboardingAccountMigrationService.migrateAccountData(
          oldAnonUid: oldAnonUid,
          newUid: user.uid,
          read: _ref.read,
        );
      }

      if (_needsEmailVerification(user)) {
        state = state.copyWith(
          user: user,
          status: AuthFlowStatus.signedInEmailUnverified,
          clearError: true,
        );
        await _repository.sendEmailVerification();
        return;
      }

      await _loadOrCreateBackendUserState(user);
    } catch (error) {
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
    state = state.copyWith(status: AuthFlowStatus.loading, clearError: true);
    try {
      await _repository.signOut();
      _resetSignedOutState();
      state = const AuthState(status: AuthFlowStatus.signedOut);
    } catch (error) {
      final mapped = mapAuthError(error);
      state = state.copyWith(
        status: AuthFlowStatus.error,
        errorMessage: mapped.message,
        failureReason: mapped.reason,
      );
      rethrow;
    } finally {
      if (mounted && state.isAuthenticating) {
        state = const AuthState(status: AuthFlowStatus.signedOut);
      }
    }
  }

  Future<void> resendEmailVerification() async {
    try {
      await _repository.sendEmailVerification();
      state = state.copyWith(clearError: true);
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

    await _loadOrCreateBackendUserState(user);
  }

  Future<void> checkEmailVerification() async {
    try {
      final user = await _repository.reloadCurrentUser();
      if (user == null) {
        _resetSignedOutState();
        state = const AuthState(status: AuthFlowStatus.signedOut);
        return;
      }

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
    if (_needsEmailVerification(user)) {
      state = state.copyWith(
        user: user,
        status: AuthFlowStatus.signedInEmailUnverified,
        clearError: true,
      );
      return;
    }
    final profile = _ref
        .read(mockUserProfileProvider)
        .copyWith(
          uid: user.uid,
          email: user.email ?? _ref.read(mockUserProfileProvider).email,
          displayName:
              user.displayName ??
              _ref.read(mockUserProfileProvider).displayName,
          onboardingInputCompleted: true,
          onboardingProjectionStatus: 'completed',
          onboardingCompleted: true,
          onboardingStep: OnboardingDraft.lastStepIndex,
          updatedAt: DateTime.now(),
        );
    _ref.read(mockUserProfileProvider.notifier).updateProfile(profile);
    if (_useFirebaseBackend) {
      await _ref.read(profileRepositoryProvider).saveUserProfile(profile);
    }
    state = state.copyWith(
      user: user,
      status: AuthFlowStatus.signedInOnboardingComplete,
      clearError: true,
    );
  }

  Future<void> acceptCanonicalOnboardingCompletion(AuthUser user) async {
    if (_needsEmailVerification(user)) {
      state = state.copyWith(
        user: user,
        status: AuthFlowStatus.signedInEmailUnverified,
        clearError: true,
      );
      return;
    }
    final profile = _ref
        .read(mockUserProfileProvider)
        .copyWith(
          uid: user.uid,
          email: user.email ?? _ref.read(mockUserProfileProvider).email,
          displayName:
              user.displayName ??
              _ref.read(mockUserProfileProvider).displayName,
          onboardingInputCompleted: true,
          onboardingProjectionStatus: 'completed',
          onboardingCompleted: true,
          onboardingStep: OnboardingDraft.lastStepIndex,
          updatedAt: DateTime.now(),
        );
    _ref.read(mockUserProfileProvider.notifier).updateProfile(profile);
    state = state.copyWith(
      user: user,
      status: AuthFlowStatus.signedInOnboardingComplete,
      clearError: true,
    );
  }

  Future<void> markOnboardingIncomplete(AuthUser user) async {
    final profile = _ref
        .read(mockUserProfileProvider)
        .copyWith(
          uid: user.uid,
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

    if (user == null) {
      _backendRestoreGeneration++;
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

    try {
      await _loadOrCreateBackendUserState(user);
    } catch (e) {
      if (!mounted) return;
      final mapped = mapAuthError(e);
      state = state.copyWith(
        user: user,
        status: AuthFlowStatus.backendRestoreFailed,
        errorMessage: mapped.message,
        failureReason: mapped.reason,
      );
    }
  }

  Future<void> _loadOrCreateBackendUserState(AuthUser user) async {
    _resetSignedOutState(targetUserUid: user.uid);

    if (!_useFirebaseBackend) {
      if (user.uid == 'dev-user-12345') {
        await _loadDevSeedState(user);
      } else {
        await _loadFakeUserState(user);
      }
      if (!mounted) return;
      _ref.read(homeDashboardProvider.notifier).setOwnerUid(user.uid);
      _ref.read(fitnessCenterProvider.notifier).setOwnerUid(user.uid);
      state = state.copyWith(
        user: user,
        status: statusFor(
          user,
          _ref.read(mockUserProfileProvider).onboardingCompleted,
        ),
        clearError: true,
      );
      return;
    }

    final restoreGeneration = ++_backendRestoreGeneration;
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
      if (profile.onboardingCompleted) {
        _ref
            .read(mockOnboardingProvider.notifier)
            .completeOnboarding(uid: user.uid);
      } else {
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
          );
          _ref.read(mockOnboardingProvider.notifier).loadSeedData(safeDraft);
        } else {
          _ref.read(mockOnboardingProvider.notifier).reset(user.uid);
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
        } catch (_) {
          throw const _RoutineProjectionRestoreException(
            'Routine setup recovery is required because the completion snapshot is corrupted.',
            reason: OnboardingFailureReason.corruptedBundle,
            actions: [
              RebuildBundleFromDraftAction(),
              SynthesizeBundleAction(),
              RestartOnboardingInputAction(),
            ],
          );
        }
        if (!_isCurrentRestore(restoreGeneration)) return;

        if (bundle == null || bundle.uid != user.uid) {
          final draft = await _ref
              .read(onboardingRepositoryProvider)
              .fetchDraft(user.uid);
          if (!_isCurrentRestore(restoreGeneration)) return;

          if (draft == null) {
            throw const _RoutineProjectionRestoreException(
              'Routine setup recovery is required because both draft and completion snapshot are missing.',
              reason: OnboardingFailureReason.missingDraftAndBundle,
              actions: [
                SynthesizeBundleAction(),
                RestartOnboardingInputAction(),
              ],
            );
          } else {
            throw const _RoutineProjectionRestoreException(
              'Routine setup recovery is required because the completion snapshot is missing.',
              reason: OnboardingFailureReason.missingBundle,
              actions: [
                RebuildBundleFromDraftAction(),
                RestartOnboardingInputAction(),
              ],
            );
          }
        }

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
              ForceResyncProjectionsAction(),
              RetryCompletionJobAction(),
              RebuildBundleFromDraftAction(),
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
              ForceResyncProjectionsAction(),
              RetryCompletionJobAction(),
              RebuildBundleFromDraftAction(),
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
              ForceResyncProjectionsAction(),
              RetryCompletionJobAction(),
              RebuildBundleFromDraftAction(),
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
      );
    } on _RoutineProjectionRestoreException catch (error) {
      if (!_isCurrentRestore(restoreGeneration)) return;
      state = state.copyWith(
        user: user,
        status: AuthFlowStatus.backendRestoreFailed,
        errorMessage: error.message,
        onboardingFailureReason: error.reason,
        recoveryActions: error.actions,
      );
    } catch (_) {
      if (!_isCurrentRestore(restoreGeneration)) return;
      state = state.copyWith(
        user: user,
        status: AuthFlowStatus.backendRestoreFailed,
        errorMessage:
            'Could not restore setup. Check your connection and try again.',
        onboardingFailureReason: OnboardingFailureReason.networkTimeout,
        recoveryActions: const [RetryCompletionJobAction()],
      );
    }
  }

  bool _isCurrentRestore(int restoreGeneration) {
    return mounted && restoreGeneration == _backendRestoreGeneration;
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

  Future<void> _loadFakeUserState(AuthUser user) async {
    final savedDraft = await _ref
        .read(onboardingRepositoryProvider)
        .fetchDraft(user.uid);
    if (savedDraft == null) {
      _resetNormalUserState(user);
      await _ref.read(routineNotifierProvider.notifier).loadForOwner(user.uid);
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
          ),
        );
    _resetUserScopedMockState();
    final bundle = await _ref
        .read(onboardingRepositoryProvider)
        .fetchCompletionBundle(user.uid);
    if (savedDraft.onboardingCompleted && bundle != null) {
      await const OnboardingFrontendHydrationService().hydrate(
        read: _ref.read,
        bundle: bundle,
      );
    } else {
      await _ref.read(routineNotifierProvider.notifier).loadForOwner(user.uid);
      await _ref
          .read(habitSystemsNotifierProvider.notifier)
          .loadForOwner(user.uid);
    }
  }

  void _resetSignedOutState({String? targetUserUid}) {
    _ref.read(routineNotifierProvider.notifier).resetForSignedOut();
    _ref.read(habitSystemsNotifierProvider.notifier).resetForSignedOut();
    _ref.read(mockUserProfileProvider.notifier).resetEmpty();
    if (targetUserUid == null ||
        _ref.read(mockOnboardingProvider).draft.uid != targetUserUid) {
      _ref.read(mockOnboardingProvider.notifier).reset(targetUserUid ?? '');
    }
    _ref.read(profileSettingsProvider.notifier).resetForSignedOut();
    _ref.read(homeDashboardProvider.notifier).resetForSignedOut();
    _ref.read(homeMindNoteProvider.notifier).resetForSignedOut();
    _ref.read(fitnessCenterProvider.notifier).resetForSignedOut();
    _ref.read(trackerSettingsProvider.notifier).resetForSignedOut();
    _ref.read(routineImportAiControllerProvider.notifier).resetForSignedOut();
    _ref.read(uploadControllerProvider.notifier).resetForSignedOut();
    _ref.read(appNavigationProvider.notifier).resetForSignedOut();
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
    _ref
        .read(regionSettingsProvider.notifier)
        .loadSettings(RegionSettings.defaultForUser('signed-out'));
    _resetUserScopedMockState();
  }

  Future<void> executeRecoveryAction(OnboardingRecoveryAction action) async {
    final currentUser = state.user ?? _repository.currentUser;
    if (currentUser == null) return;

    if (action is RestartOnboardingInputAction) {
      await markOnboardingIncomplete(currentUser);
      return;
    }

    if (action is SynthesizeBundleAction) {
      final synthesizedDraft = OnboardingDraft(uid: currentUser.uid).copyWith(
        onboardingCompleted: true,
        currentStep: OnboardingDraft.lastStepIndex,
      );
      final bundle = OnboardingCompletionService.buildBundle(synthesizedDraft);
      await _ref.read(onboardingRepositoryProvider).saveDraft(synthesizedDraft);
      await _ref
          .read(onboardingRepositoryProvider)
          .saveCompletionBundle(bundle);
      await retryBackendRestore();
      return;
    }

    if (action is RebuildBundleFromDraftAction) {
      final draft = await _ref
          .read(onboardingRepositoryProvider)
          .fetchDraft(currentUser.uid);
      if (draft != null) {
        final completedDraft = draft.copyWith(
          onboardingCompleted: true,
          currentStep: OnboardingDraft.lastStepIndex,
        );
        await _ref.read(onboardingRepositoryProvider).saveDraft(completedDraft);
        final bundle = OnboardingCompletionService.buildBundle(completedDraft);
        await _ref
            .read(onboardingRepositoryProvider)
            .saveCompletionBundle(bundle);
        await retryBackendRestore();
        return;
      } else {
        final recoveryResult =
            await OnboardingCompletionService.recoverCompletionState(
              uid: currentUser.uid,
              onboardingRepository: _ref.read(onboardingRepositoryProvider),
              profileRepository: _ref.read(profileRepositoryProvider),
            );
        if (recoveryResult.tier == OnboardingRecoveryTier.tier4ResetRequired) {
          await markOnboardingIncomplete(currentUser);
          return;
        }
        await retryBackendRestore();
        return;
      }
    }

    if (action is RetryCompletionJobAction) {
      final recoveryResult =
          await OnboardingCompletionService.recoverCompletionState(
            uid: currentUser.uid,
            onboardingRepository: _ref.read(onboardingRepositoryProvider),
            profileRepository: _ref.read(profileRepositoryProvider),
          );
      if (recoveryResult.tier == OnboardingRecoveryTier.tier4ResetRequired) {
        await markOnboardingIncomplete(currentUser);
        return;
      }
      await retryBackendRestore();
      return;
    }

    if (action is ForceResyncProjectionsAction) {
      var bundle = await _ref
          .read(onboardingRepositoryProvider)
          .fetchCompletionBundle(currentUser.uid);
      if (bundle == null) {
        final recoveryResult =
            await OnboardingCompletionService.recoverCompletionState(
              uid: currentUser.uid,
              onboardingRepository: _ref.read(onboardingRepositoryProvider),
              profileRepository: _ref.read(profileRepositoryProvider),
            );
        bundle = recoveryResult.bundle;
      }
      if (bundle != null) {
        try {
          await const OnboardingFrontendHydrationService().hydrate(
            read: _ref.read,
            bundle: bundle,
          );
        } on RoutineProjectionFailureException catch (_) {
          // If receipt is missing or invalid, retryBackendRestore recovers it
        } catch (_) {}
      }
      await retryBackendRestore();
      return;
    }

    await retryBackendRestore();
  }

  void _resetUserScopedMockState() {
    _ref.read(routineNotifierProvider.notifier).resetForSignedOut();
    if (!_useFirebaseBackend) {
      _ref.read(mockRoutineProvider.notifier).resetEmpty();
    }
    _ref.read(mockTrackerProvider.notifier).resetEmpty();
    _ref.read(mockGoalProvider.notifier).resetEmpty();
    _ref.read(mockMindNoteProvider.notifier).resetEmpty();
    _ref.read(homeMindNoteProvider.notifier).resetForSignedOut();
    _ref.read(mockCoachProvider.notifier).resetEmpty();
    _ref.read(mockCoachPreferencesProvider.notifier).resetEmpty();
    _ref.read(mockNotificationPreferencesProvider.notifier).resetEmpty();
    _ref.read(mockPermissionProvider.notifier).resetEmpty();
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
