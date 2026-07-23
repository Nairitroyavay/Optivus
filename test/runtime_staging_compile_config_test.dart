import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/ai_workers_config.dart';
import 'package:optivus/config/app_environment_config.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/config/routine_import_ai_config.dart';
import 'package:optivus/config/runtime_config.dart';
import 'package:optivus/config/upload_config.dart';

void main() {
  test('compile-time staging definitions select only live integrations', () {
    if (OptivusAppEnvironmentConfig.environment ==
        OptivusAppEnvironment.development) {
      expect(OptivusAppEnvironmentConfig.requiresLiveServices, isFalse);
      return;
    }

    expect(
      OptivusAppEnvironmentConfig.environment,
      OptivusAppEnvironment.staging,
    );
    expect(OptivusAppEnvironmentConfig.requiresLiveServices, isTrue);
    expect(OptivusBackendConfig.mode, OptivusBackendMode.firebase);
    expect(OptivusUploadConfig.mode, OptivusUploadMode.r2);
    expect(OptivusAiWorkersConfig.mode, OptivusAiWorkerMode.worker);
    expect(
      OptivusRoutineImportAiConfig.mode,
      OptivusRoutineImportAiMode.worker,
    );

    final snapshot = OptivusRuntimeConfig.current(
      generatedFirebaseProjectId: OptivusRuntimeConfig.firebaseProjectId,
    );
    expect(snapshot.validationErrors(requireLiveServices: true), isEmpty);
  });
}
