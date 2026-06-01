import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/repositories/auth_repository.dart';

import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/mock_seed_data.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/notification_preferences.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (OptivusBackendConfig.useFirebase) {
    return FirebaseAuthRepository();
  }
  return FakeAuthRepository();
});

enum AuthFlowStatus {
  loading,
  signedOut,
  signedInOnboardingIncomplete,
  signedInOnboardingComplete,
  error,
}

class AuthState {
  final AuthUser? user;
  final AuthFlowStatus status;
  final String? errorMessage;

  const AuthState({
    this.user,
    this.status = AuthFlowStatus.signedOut,
    this.errorMessage,
  });

  bool get isLoggedIn => user != null;
  bool get isLoading => status == AuthFlowStatus.loading;
  bool get isSignedOut => status == AuthFlowStatus.signedOut;
  bool get onboardingIncomplete =>
      status == AuthFlowStatus.signedInOnboardingIncomplete;
  bool get onboardingComplete =>
      status == AuthFlowStatus.signedInOnboardingComplete;
  bool get hasError => status == AuthFlowStatus.error;

  AuthState copyWith({
    AuthUser? user,
    AuthFlowStatus? status,
    String? errorMessage,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final Ref _ref;

  AuthNotifier(this._repository, this._ref) : super(const AuthState()) {
    _repository.authStateChanges.listen((user) {
      final onboardingCompleted = _ref
          .read(mockUserProfileProvider)
          .onboardingCompleted;
      state = state.copyWith(
        user: user,
        clearUser: user == null,
        status: _statusFor(user, onboardingCompleted),
        clearError: true,
      );
    });
  }

  Future<void> login(String email, String password) async {
    final previousUser = state.user;
    state = state.copyWith(status: AuthFlowStatus.loading, clearError: true);
    try {
      final user = await _repository.signIn(email, password);
      // If dev account, populate seed data. Otherwise, leave as empty if no local profile found.
      if (user.uid == 'dev-user-12345') {
        _loadDevSeedState(user);
      } else {
        _resetNormalUserState(user);
      }
      state = state.copyWith(
        user: user,
        status: _statusFor(
          user,
          _ref.read(mockUserProfileProvider).onboardingCompleted,
        ),
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        user: previousUser,
        status: AuthFlowStatus.error,
        errorMessage: error.toString(),
      );
      rethrow;
    } finally {
      if (mounted && state.isLoading) {
        state = state.copyWith(
          status: _statusFor(
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
      // Empty profile for new user
      _resetNormalUserState(user);
      state = state.copyWith(
        user: user,
        status: AuthFlowStatus.signedInOnboardingIncomplete,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        user: previousUser,
        status: AuthFlowStatus.error,
        errorMessage: error.toString(),
      );
      rethrow;
    } finally {
      if (mounted && state.isLoading) {
        state = state.copyWith(
          status: _statusFor(
            state.user,
            _ref.read(mockUserProfileProvider).onboardingCompleted,
          ),
        );
      }
    }
  }

  Future<void> logout() async {
    state = state.copyWith(status: AuthFlowStatus.loading, clearError: true);
    try {
      await _repository.signOut();
      _resetSignedOutState();
      state = const AuthState(status: AuthFlowStatus.signedOut);
    } catch (error) {
      state = state.copyWith(
        status: AuthFlowStatus.error,
        errorMessage: error.toString(),
      );
      rethrow;
    } finally {
      if (mounted && state.isLoading) {
        state = const AuthState(status: AuthFlowStatus.signedOut);
      }
    }
  }

  void markOnboardingComplete(AuthUser user) {
    state = state.copyWith(
      user: user,
      status: AuthFlowStatus.signedInOnboardingComplete,
      clearError: true,
    );
  }

  void markOnboardingIncomplete(AuthUser user) {
    state = state.copyWith(
      user: user,
      status: AuthFlowStatus.signedInOnboardingIncomplete,
      clearError: true,
    );
  }

  static AuthFlowStatus _statusFor(AuthUser? user, bool onboardingCompleted) {
    if (user == null) return AuthFlowStatus.signedOut;
    return onboardingCompleted
        ? AuthFlowStatus.signedInOnboardingComplete
        : AuthFlowStatus.signedInOnboardingIncomplete;
  }

  void _loadDevSeedState(AuthUser user) {
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

  void _resetSignedOutState() {
    _ref.read(mockUserProfileProvider.notifier).resetEmpty();
    _ref.read(mockOnboardingProvider.notifier).reset('');
    _resetUserScopedMockState();
  }

  void _resetUserScopedMockState() {
    _ref.read(mockRoutineProvider.notifier).resetEmpty();
    _ref.read(mockTrackerProvider.notifier).resetEmpty();
    _ref.read(mockGoalProvider.notifier).resetEmpty();
    _ref.read(mockMindNoteProvider.notifier).resetEmpty();
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
