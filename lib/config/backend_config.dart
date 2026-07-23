import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OptivusBackendMode { fake, firebase }

class OptivusBackendConfig {
  const OptivusBackendConfig._();

  static const String _modeName = String.fromEnvironment(
    'OPTIVUS_BACKEND',
    defaultValue: 'fake',
  );

  static OptivusBackendMode get mode {
    return switch (_modeName) {
      'firebase' => OptivusBackendMode.firebase,
      _ => OptivusBackendMode.fake,
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
