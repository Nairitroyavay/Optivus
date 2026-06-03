enum OptivusRoutineImportAiMode { disabled, fake, worker }

class OptivusRoutineImportAiConfig {
  const OptivusRoutineImportAiConfig._();

  static const String _modeName = String.fromEnvironment(
    'OPTIVUS_ROUTINE_IMPORT_AI_MODE',
    defaultValue: 'fake',
  );

  static const String workerBaseUrl = String.fromEnvironment(
    'OPTIVUS_ROUTINE_IMPORT_WORKER_URL',
    defaultValue: '',
  );

  static OptivusRoutineImportAiMode get mode {
    return switch (_modeName) {
      'worker' => OptivusRoutineImportAiMode.worker,
      'disabled' => OptivusRoutineImportAiMode.disabled,
      _ => OptivusRoutineImportAiMode.fake,
    };
  }

  static bool get useWorker => mode == OptivusRoutineImportAiMode.worker;
  static bool get hasWorkerUrl => workerBaseUrl.trim().isNotEmpty;
}
