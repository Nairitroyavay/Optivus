import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OptivusBackendMode { fake, firebase }

class FirebaseFeatureUnavailableException implements Exception {
  const FirebaseFeatureUnavailableException(this.feature);

  final String feature;

  @override
  String toString() => '$feature is unavailable from the Firebase backend.';
}

/// The single runtime authority for whether development fixture data and fake
/// backend implementations may be reached.
///
/// This is deliberately a runtime check rather than an assertion so profile
/// and release builds fail closed even though Dart assertions are disabled.
class FakeBackendPolicy {
  const FakeBackendPolicy({
    required this.isDebugBuild,
    required this.backendMode,
  });

  final bool isDebugBuild;
  final OptivusBackendMode backendMode;

  bool get fakeDataAllowed =>
      isDebugBuild && backendMode == OptivusBackendMode.fake;

  void ensureValid() {
    if (backendMode == OptivusBackendMode.fake && !isDebugBuild) {
      throw StateError(
        'The fake Optivus backend is unavailable outside debug builds.',
      );
    }
  }

  T selectBackend<T>({
    required T Function() firebase,
    required T Function() fake,
  }) {
    ensureValid();
    return fakeDataAllowed ? fake() : firebase();
  }
}

class OptivusBackendConfig {
  const OptivusBackendConfig._();

  static const String _configuredModeName = String.fromEnvironment(
    'OPTIVUS_BACKEND',
    defaultValue: '',
  );
  static bool get _isFlutterTest =>
      kDebugMode && Platform.environment['FLUTTER_TEST'] == 'true';

  static OptivusBackendMode get mode {
    // Flutter's test compiler supplies FLUTTER_TEST. This preserves the
    // repository's explicit fake test harness without changing the behavior
    // of any debug/profile/release application build. Tests that exercise
    // Firebase override the backend provider explicitly.
    if (_configuredModeName.isEmpty && _isFlutterTest) {
      return OptivusBackendMode.fake;
    }
    return modeForName(_configuredModeName);
  }

  static OptivusBackendMode modeForName(String modeName) {
    return switch (modeName) {
      'fake' => OptivusBackendMode.fake,
      'firebase' => OptivusBackendMode.firebase,
      // Unknown and missing configuration fail toward the real backend. The
      // startup validator can still reject an otherwise incomplete live setup.
      _ => OptivusBackendMode.firebase,
    };
  }

  static bool get useFirebase => mode == OptivusBackendMode.firebase;

  static String get label => switch (mode) {
    OptivusBackendMode.firebase => 'firebase',
    OptivusBackendMode.fake => 'fake',
  };
}

/// One overridable backend-mode source for repository selection and auth.
final optivusBackendModeProvider = Provider<OptivusBackendMode>((ref) {
  return OptivusBackendConfig.mode;
});

/// Injectable only so the four policy combinations can be unit tested without
/// attempting to mutate Flutter's compile-time [kDebugMode].
final optivusDebugBuildProvider = Provider<bool>((ref) => kDebugMode);

final fakeBackendPolicyProvider = Provider<FakeBackendPolicy>((ref) {
  return FakeBackendPolicy(
    isDebugBuild: ref.watch(optivusDebugBuildProvider),
    backendMode: ref.watch(optivusBackendModeProvider),
  );
});

final fakeDataAllowedProvider = Provider<bool>((ref) {
  final policy = ref.watch(fakeBackendPolicyProvider);
  policy.ensureValid();
  return policy.fakeDataAllowed;
});
