import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple local state representation of the user session.
class MockAuthState {
  final bool isLoggedIn;
  final String mockUserName;
  final String mockEmail;
  final bool hasCompletedOnboarding;

  const MockAuthState({
    this.isLoggedIn = false,
    this.mockUserName = '',
    this.mockEmail = '',
    this.hasCompletedOnboarding = false,
  });

  MockAuthState copyWith({
    bool? isLoggedIn,
    String? mockUserName,
    String? mockEmail,
    bool? hasCompletedOnboarding,
  }) {
    return MockAuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      mockUserName: mockUserName ?? this.mockUserName,
      mockEmail: mockEmail ?? this.mockEmail,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    );
  }
}

/// Manages simulated auth changes (Log In, Sign Up, Sign Out, Onboarding completion).
class MockAuthNotifier extends StateNotifier<MockAuthState> {
  MockAuthNotifier() : super(const MockAuthState());

  void login(String email, String password) {
    state = state.copyWith(
      isLoggedIn: true,
      mockEmail: email,
      mockUserName: email.split('@')[0], // Extract prefix as a simple fallback username
    );
  }

  void signup(String name, String email, String password) {
    state = state.copyWith(
      isLoggedIn: true,
      mockUserName: name,
      mockEmail: email,
    );
  }

  void completeOnboarding() {
    state = state.copyWith(hasCompletedOnboarding: true);
  }

  void logout() {
    state = const MockAuthState();
  }
}

/// Standard Riverpod provider exposing mock authentication states.
final mockAuthProvider = StateNotifierProvider<MockAuthNotifier, MockAuthState>((ref) {
  return MockAuthNotifier();
});
