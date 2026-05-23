import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/repositories/auth_repository.dart';

import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/mock_seed_data.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/models/onboarding_draft.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FakeAuthRepository();
});

class AuthState {
  final AuthUser? user;
  final bool isLoading;

  const AuthState({
    this.user,
    this.isLoading = false,
  });

  bool get isLoggedIn => user != null;

  AuthState copyWith({
    AuthUser? user,
    bool? isLoading,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final Ref _ref;

  AuthNotifier(this._repository, this._ref) : super(const AuthState()) {
    _repository.authStateChanges.listen((user) {
      state = state.copyWith(user: user, clearUser: user == null);
    });
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await _repository.signIn(email, password);
      // If dev account, populate seed data. Otherwise, leave as empty if no local profile found.
      if (user.uid == 'dev-user-12345') {
        _ref.read(mockUserProfileProvider.notifier).updateProfile(MockSeedData.defaultUserProfile.copyWith(uid: user.uid));
        _ref.read(mockOnboardingProvider.notifier).loadSeedData(OnboardingDraft(uid: user.uid, onboardingCompleted: true));
      } else {
        // Normally, backend would fetch UserProfile. Here we just ensure mock state matches the signed-in user.
        _ref.read(mockUserProfileProvider.notifier).updateProfile(UserProfile.empty(uid: user.uid, email: user.email ?? '', displayName: user.displayName ?? ''));
        _ref.read(mockOnboardingProvider.notifier).reset(user.uid);
      }
    } finally {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> signup(String name, String email, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await _repository.signUp(email, password, name: name);
      // Empty profile for new user
      _ref.read(mockUserProfileProvider.notifier).updateProfile(UserProfile.empty(uid: user.uid, email: user.email ?? '', displayName: user.displayName ?? ''));
      _ref.read(mockOnboardingProvider.notifier).reset(user.uid);
    } finally {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.signOut();
      _ref.read(mockUserProfileProvider.notifier).updateProfile(UserProfile.empty(uid: ''));
      _ref.read(mockOnboardingProvider.notifier).reset('');
    } finally {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository, ref);
});
