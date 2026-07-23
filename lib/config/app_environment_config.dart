import 'package:flutter/foundation.dart';

enum OptivusAppEnvironment { development, staging, production }

class OptivusAppEnvironmentConfig {
  const OptivusAppEnvironmentConfig._();

  static const String _environmentName = String.fromEnvironment(
    'OPTIVUS_APP_ENV',
    defaultValue: 'development',
  );

  static OptivusAppEnvironment get environment {
    return switch (_environmentName.trim().toLowerCase()) {
      'staging' => OptivusAppEnvironment.staging,
      'production' => OptivusAppEnvironment.production,
      _ => OptivusAppEnvironment.development,
    };
  }

  /// Release builds and explicitly named staging/production builds must use
  /// live integrations. Development remains available for safe local testing.
  static bool get requiresLiveServices {
    return requiresLiveServicesFor(
      isReleaseMode: kReleaseMode,
      environment: environment,
    );
  }

  static bool requiresLiveServicesFor({
    required bool isReleaseMode,
    required OptivusAppEnvironment environment,
  }) {
    return isReleaseMode || environment != OptivusAppEnvironment.development;
  }
}
