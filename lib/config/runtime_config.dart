import 'package:optivus/config/ai_workers_config.dart';
import 'package:optivus/config/app_environment_config.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/config/routine_import_ai_config.dart';
import 'package:optivus/config/upload_config.dart';

class OptivusRuntimeConfigSnapshot {
  const OptivusRuntimeConfigSnapshot({
    required this.environment,
    required this.backendMode,
    required this.uploadMode,
    required this.aiWorkerMode,
    required this.routineImportAiMode,
    required this.firebaseProjectId,
    required this.generatedFirebaseProjectId,
    required this.r2UploadWorkerUrl,
    required this.routineImportWorkerUrl,
    required this.nutritionWorkerUrl,
    required this.skinCareWorkerUrl,
    required this.coachWorkerUrl,
  });

  final OptivusAppEnvironment environment;
  final OptivusBackendMode backendMode;
  final OptivusUploadMode uploadMode;
  final OptivusAiWorkerMode aiWorkerMode;
  final OptivusRoutineImportAiMode routineImportAiMode;
  final String firebaseProjectId;
  final String generatedFirebaseProjectId;
  final String r2UploadWorkerUrl;
  final String routineImportWorkerUrl;
  final String nutritionWorkerUrl;
  final String skinCareWorkerUrl;
  final String coachWorkerUrl;

  List<String> validationErrors({required bool requireLiveServices}) {
    if (!requireLiveServices) return const [];

    final errors = <String>[];
    if (environment == OptivusAppEnvironment.development) {
      errors.add(
        'OPTIVUS_APP_ENV must be staging or production for a live/release build.',
      );
    }
    if (backendMode != OptivusBackendMode.firebase) {
      errors.add('OPTIVUS_BACKEND must be firebase.');
    }
    if (uploadMode != OptivusUploadMode.r2) {
      errors.add('OPTIVUS_UPLOAD_MODE must be r2.');
    }
    if (aiWorkerMode != OptivusAiWorkerMode.worker) {
      errors.add('OPTIVUS_AI_WORKERS_MODE must be worker.');
    }
    if (routineImportAiMode != OptivusRoutineImportAiMode.worker) {
      errors.add('OPTIVUS_ROUTINE_IMPORT_AI_MODE must be worker.');
    }

    final expectedProject = firebaseProjectId.trim();
    final generatedProject = generatedFirebaseProjectId.trim();
    if (expectedProject.isEmpty) {
      errors.add('OPTIVUS_FIREBASE_PROJECT_ID is required.');
    }
    if (generatedProject.isEmpty) {
      errors.add('The generated Firebase project ID is unavailable.');
    } else if (expectedProject.isNotEmpty &&
        expectedProject != generatedProject) {
      errors.add(
        'OPTIVUS_FIREBASE_PROJECT_ID does not match the generated Firebase configuration.',
      );
    }

    _validateWorkerUrl(
      errors,
      defineName: 'OPTIVUS_R2_UPLOAD_WORKER_URL',
      value: r2UploadWorkerUrl,
    );
    _validateWorkerUrl(
      errors,
      defineName: 'OPTIVUS_ROUTINE_IMPORT_WORKER_URL',
      value: routineImportWorkerUrl,
    );
    _validateWorkerUrl(
      errors,
      defineName: 'OPTIVUS_NUTRITION_WORKER_URL',
      value: nutritionWorkerUrl,
    );
    _validateWorkerUrl(
      errors,
      defineName: 'OPTIVUS_SKIN_CARE_WORKER_URL',
      value: skinCareWorkerUrl,
    );
    _validateWorkerUrl(
      errors,
      defineName: 'OPTIVUS_COACH_WORKER_URL',
      value: coachWorkerUrl,
    );

    return errors;
  }

  void _validateWorkerUrl(
    List<String> errors, {
    required String defineName,
    required String value,
  }) {
    final rawValue = value.trim();
    final uri = Uri.tryParse(rawValue);
    if (rawValue.isEmpty ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      errors.add('$defineName must be an explicit HTTPS URL.');
      return;
    }

    final host = uri.host.toLowerCase();
    final isPlaceholder =
        host.endsWith('.invalid') || host.contains('required-approved');
    final isDevelopmentHost =
        host.contains('-dev.') || host.startsWith('localhost');
    final isStagingHost =
        host.contains('-staging.') || host.contains('staging-');

    if (isPlaceholder) {
      errors.add('$defineName must not use a placeholder URL.');
    }
    if (environment == OptivusAppEnvironment.staging && isDevelopmentHost) {
      errors.add('$defineName must not use a development URL in staging.');
    }
    if (environment == OptivusAppEnvironment.production &&
        (isDevelopmentHost || isStagingHost)) {
      errors.add(
        '$defineName must not use a development or staging URL in production.',
      );
    }
  }
}

class OptivusRuntimeConfig {
  const OptivusRuntimeConfig._();

  static const String firebaseProjectId = String.fromEnvironment(
    'OPTIVUS_FIREBASE_PROJECT_ID',
    defaultValue: '',
  );

  static OptivusRuntimeConfigSnapshot current({
    required String generatedFirebaseProjectId,
  }) {
    return OptivusRuntimeConfigSnapshot(
      environment: OptivusAppEnvironmentConfig.environment,
      backendMode: OptivusBackendConfig.mode,
      uploadMode: OptivusUploadConfig.mode,
      aiWorkerMode: OptivusAiWorkersConfig.mode,
      routineImportAiMode: OptivusRoutineImportAiConfig.mode,
      firebaseProjectId: firebaseProjectId,
      generatedFirebaseProjectId: generatedFirebaseProjectId,
      r2UploadWorkerUrl: OptivusUploadConfig.workerBaseUrl,
      routineImportWorkerUrl: OptivusAiWorkersConfig.routineImportWorkerUrl,
      nutritionWorkerUrl: OptivusAiWorkersConfig.nutritionWorkerUrl,
      skinCareWorkerUrl: OptivusAiWorkersConfig.skinCareWorkerUrl,
      coachWorkerUrl: OptivusAiWorkersConfig.coachWorkerUrl,
    );
  }

  static void validateForStartup({required String generatedFirebaseProjectId}) {
    final errors =
        current(
          generatedFirebaseProjectId: generatedFirebaseProjectId,
        ).validationErrors(
          requireLiveServices: OptivusAppEnvironmentConfig.requiresLiveServices,
        );
    if (errors.isNotEmpty) {
      throw StateError(
        'Unsafe Optivus runtime configuration:\n- ${errors.join('\n- ')}',
      );
    }
  }
}
