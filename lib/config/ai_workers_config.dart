import 'package:optivus/config/app_environment_config.dart';

enum OptivusAiWorkerMode { disabled, fake, worker }

class OptivusAiWorkersConfig {
  const OptivusAiWorkersConfig._();

  static bool allowFakeAiForTestsOnly = false;

  static const String _modeName = String.fromEnvironment(
    'OPTIVUS_AI_WORKERS_MODE',
    defaultValue: 'worker',
  );

  static OptivusAiWorkerMode get mode {
    if (OptivusAppEnvironmentConfig.requiresLiveServices) {
      return OptivusAiWorkerMode.worker;
    }
    return switch (_modeName) {
      'fake' => OptivusAiWorkerMode.fake,
      'disabled' => OptivusAiWorkerMode.disabled,
      _ => OptivusAiWorkerMode.worker,
    };
  }

  static bool get useWorker => mode == OptivusAiWorkerMode.worker;

  static const String routineImportWorkerUrl = String.fromEnvironment(
    'OPTIVUS_ROUTINE_IMPORT_WORKER_URL',
    defaultValue:
        'https://optivus-routine-import-worker-dev.nairitstock.workers.dev',
  );

  static const String nutritionWorkerUrl = String.fromEnvironment(
    'OPTIVUS_NUTRITION_WORKER_URL',
    defaultValue:
        'https://optivus-nutrition-worker-dev.nairitstock.workers.dev',
  );

  static const String coachWorkerUrl = String.fromEnvironment(
    'OPTIVUS_COACH_WORKER_URL',
    defaultValue: 'https://optivus-coach-worker-dev.nairitstock.workers.dev',
  );

  static const String skinCareWorkerUrl = String.fromEnvironment(
    'OPTIVUS_SKIN_CARE_WORKER_URL',
    defaultValue:
        'https://optivus-skin-care-worker-dev.nairitstock.workers.dev',
  );
}
