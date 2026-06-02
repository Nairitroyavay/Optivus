enum OptivusUploadMode { disabled, fake, r2 }

class OptivusUploadConfig {
  const OptivusUploadConfig._();

  static const String _modeName = String.fromEnvironment(
    'OPTIVUS_UPLOAD_MODE',
    defaultValue: 'fake',
  );

  static const String workerBaseUrl = String.fromEnvironment(
    'OPTIVUS_R2_UPLOAD_WORKER_URL',
    defaultValue: '',
  );

  static OptivusUploadMode get mode {
    return switch (_modeName) {
      'r2' => OptivusUploadMode.r2,
      'disabled' => OptivusUploadMode.disabled,
      _ => OptivusUploadMode.fake,
    };
  }

  static bool get useR2 => mode == OptivusUploadMode.r2;
  static bool get hasWorkerUrl => workerBaseUrl.trim().isNotEmpty;
}
