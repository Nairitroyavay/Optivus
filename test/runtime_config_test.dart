import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/ai_workers_config.dart';
import 'package:optivus/config/app_environment_config.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/config/routine_import_ai_config.dart';
import 'package:optivus/config/runtime_config.dart';
import 'package:optivus/config/upload_config.dart';

void main() {
  const validStagingUrl = 'https://worker-staging.example.com';

  OptivusRuntimeConfigSnapshot snapshot({
    OptivusAppEnvironment environment = OptivusAppEnvironment.staging,
    OptivusBackendMode backendMode = OptivusBackendMode.firebase,
    OptivusUploadMode uploadMode = OptivusUploadMode.r2,
    OptivusAiWorkerMode aiWorkerMode = OptivusAiWorkerMode.worker,
    OptivusRoutineImportAiMode routineImportAiMode =
        OptivusRoutineImportAiMode.worker,
    String firebaseProjectId = 'optivus-staging',
    String generatedFirebaseProjectId = 'optivus-staging',
    String r2UploadWorkerUrl = validStagingUrl,
    String routineImportWorkerUrl = validStagingUrl,
    String nutritionWorkerUrl = validStagingUrl,
    String skinCareWorkerUrl = validStagingUrl,
    String coachWorkerUrl = validStagingUrl,
  }) {
    return OptivusRuntimeConfigSnapshot(
      environment: environment,
      backendMode: backendMode,
      uploadMode: uploadMode,
      aiWorkerMode: aiWorkerMode,
      routineImportAiMode: routineImportAiMode,
      firebaseProjectId: firebaseProjectId,
      generatedFirebaseProjectId: generatedFirebaseProjectId,
      r2UploadWorkerUrl: r2UploadWorkerUrl,
      routineImportWorkerUrl: routineImportWorkerUrl,
      nutritionWorkerUrl: nutritionWorkerUrl,
      skinCareWorkerUrl: skinCareWorkerUrl,
      coachWorkerUrl: coachWorkerUrl,
    );
  }

  test('development may intentionally use local fake integrations', () {
    final result = snapshot(
      environment: OptivusAppEnvironment.development,
      backendMode: OptivusBackendMode.fake,
      uploadMode: OptivusUploadMode.fake,
      aiWorkerMode: OptivusAiWorkerMode.fake,
      routineImportAiMode: OptivusRoutineImportAiMode.fake,
      firebaseProjectId: '',
      generatedFirebaseProjectId: '',
      r2UploadWorkerUrl: '',
      routineImportWorkerUrl: '',
      nutritionWorkerUrl: '',
      skinCareWorkerUrl: '',
      coachWorkerUrl: '',
    );

    expect(result.validationErrors(requireLiveServices: false), isEmpty);
  });

  test(
    'release always requires live services even with development default',
    () {
      expect(
        OptivusAppEnvironmentConfig.requiresLiveServicesFor(
          isReleaseMode: true,
          environment: OptivusAppEnvironment.development,
        ),
        isTrue,
      );
      expect(
        OptivusAppEnvironmentConfig.requiresLiveServicesFor(
          isReleaseMode: false,
          environment: OptivusAppEnvironment.development,
        ),
        isFalse,
      );
    },
  );

  test('staging rejects every fake or disabled integration mode', () {
    final errors = snapshot(
      backendMode: OptivusBackendMode.fake,
      uploadMode: OptivusUploadMode.fake,
      aiWorkerMode: OptivusAiWorkerMode.disabled,
      routineImportAiMode: OptivusRoutineImportAiMode.fake,
    ).validationErrors(requireLiveServices: true);

    expect(errors, contains('OPTIVUS_BACKEND must be firebase.'));
    expect(errors, contains('OPTIVUS_UPLOAD_MODE must be r2.'));
    expect(errors, contains('OPTIVUS_AI_WORKERS_MODE must be worker.'));
    expect(errors, contains('OPTIVUS_ROUTINE_IMPORT_AI_MODE must be worker.'));
  });

  test(
    'live/release validation requires a named non-development environment',
    () {
      final errors = snapshot(
        environment: OptivusAppEnvironment.development,
      ).validationErrors(requireLiveServices: true);

      expect(
        errors,
        contains(
          'OPTIVUS_APP_ENV must be staging or production for a live/release build.',
        ),
      );
    },
  );

  test('staging rejects a missing or mismatched Firebase project', () {
    final missing = snapshot(
      firebaseProjectId: '',
      generatedFirebaseProjectId: '',
    ).validationErrors(requireLiveServices: true);
    final mismatched = snapshot(
      firebaseProjectId: 'approved-staging',
      generatedFirebaseProjectId: 'different-project',
    ).validationErrors(requireLiveServices: true);

    expect(missing, contains('OPTIVUS_FIREBASE_PROJECT_ID is required.'));
    expect(
      missing,
      contains('The generated Firebase project ID is unavailable.'),
    );
    expect(
      mismatched,
      contains(
        'OPTIVUS_FIREBASE_PROJECT_ID does not match the generated Firebase configuration.',
      ),
    );
  });

  test('staging requires all five explicit HTTPS Worker URLs', () {
    final errors = snapshot(
      r2UploadWorkerUrl: '',
      routineImportWorkerUrl: 'http://routine.example.com',
      nutritionWorkerUrl: 'not-a-url',
      skinCareWorkerUrl: '',
      coachWorkerUrl: 'ftp://coach.example.com',
    ).validationErrors(requireLiveServices: true);

    expect(
      errors.where((error) => error.contains('explicit HTTPS URL')),
      hasLength(5),
    );
  });

  test('staging rejects development and placeholder Worker URLs', () {
    final errors = snapshot(
      r2UploadWorkerUrl: 'https://optivus-r2-upload-worker-dev.example.com',
      routineImportWorkerUrl: 'https://staging-origin.invalid',
    ).validationErrors(requireLiveServices: true);

    expect(
      errors,
      contains(
        'OPTIVUS_R2_UPLOAD_WORKER_URL must not use a development URL in staging.',
      ),
    );
    expect(
      errors,
      contains(
        'OPTIVUS_ROUTINE_IMPORT_WORKER_URL must not use a placeholder URL.',
      ),
    );
  });

  test('production rejects development and staging Worker URLs', () {
    final errors = snapshot(
      environment: OptivusAppEnvironment.production,
      r2UploadWorkerUrl: 'https://optivus-r2-upload-worker-dev.example.com',
      routineImportWorkerUrl:
          'https://optivus-routine-import-worker.example.com',
      nutritionWorkerUrl: 'https://optivus-nutrition-worker.example.com',
      skinCareWorkerUrl: 'https://optivus-skin-care-worker.example.com',
      coachWorkerUrl: 'https://optivus-coach-worker-staging.example.com',
    ).validationErrors(requireLiveServices: true);

    expect(
      errors.where(
        (error) => error.contains('development or staging URL in production'),
      ),
      hasLength(2),
    );
  });

  test('explicit authorized-looking staging configuration passes', () {
    expect(snapshot().validationErrors(requireLiveServices: true), isEmpty);
  });
}
