enum OptivusAiWorkerMode { disabled, fake, worker }

class OptivusAiWorkersConfig {
  const OptivusAiWorkersConfig._();

  static const String _modeName = String.fromEnvironment(
    'OPTIVUS_AI_WORKERS_MODE',
    defaultValue: 'fake',
  );

  static OptivusAiWorkerMode get mode {
    return switch (_modeName) {
      'worker' => OptivusAiWorkerMode.worker,
      'disabled' => OptivusAiWorkerMode.disabled,
      _ => OptivusAiWorkerMode.fake,
    };
  }

  static bool get useWorker => mode == OptivusAiWorkerMode.worker;

  static const String routineImportWorkerUrl = String.fromEnvironment(
    'OPTIVUS_ROUTINE_IMPORT_WORKER_URL',
    defaultValue: '',
  );

  static const String nutritionWorkerUrl = String.fromEnvironment(
    'OPTIVUS_NUTRITION_WORKER_URL',
    defaultValue: '',
  );

  static const String coachWorkerUrl = String.fromEnvironment(
    'OPTIVUS_COACH_WORKER_URL',
    defaultValue: '',
  );

  static const String skinCareWorkerUrl = String.fromEnvironment(
    'OPTIVUS_SKIN_CARE_WORKER_URL',
    defaultValue: '',
  );
}
