import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/app/configuration_failure_app.dart';
import 'package:optivus/config/ai_workers_config.dart';
import 'package:optivus/config/app_environment_config.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/config/routine_import_ai_config.dart';
import 'package:optivus/config/runtime_config.dart';
import 'package:optivus/config/upload_config.dart';
import 'package:optivus/main.dart' as app_main;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ConfigurationFailureApp renders deterministic safe UI', (
    tester,
  ) async {
    await tester.pumpWidget(const ConfigurationFailureApp());

    expect(find.text('Configuration Error'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.textContaining('failed to initialize'), findsOneWidget);
  });

  testWidgets('runtime validation failure returns ConfigurationFailureApp', (
    tester,
  ) async {
    var initialized = false;
    final root = await app_main.buildOptivusRoot(
      useFirebase: false,
      validateRuntime: ({required generatedFirebaseProjectId}) {
        throw StateError('invalid runtime definitions');
      },
      initializeFirebase: (options) async {
        initialized = true;
      },
    );

    expect(initialized, isFalse);
    expect(root, isA<ConfigurationFailureApp>());
    await tester.pumpWidget(root);
    expect(find.text('Configuration Error'), findsOneWidget);
  });

  testWidgets('Firebase initialization failure returns safe startup UI', (
    tester,
  ) async {
    const options = FirebaseOptions(
      apiKey: 'test-api-key',
      appId: 'test-app-id',
      messagingSenderId: 'test-sender-id',
      projectId: 'optivus-staging',
    );
    final root = await app_main.buildOptivusRoot(
      useFirebase: true,
      firebaseOptions: options,
      validateRuntime: ({required generatedFirebaseProjectId}) {},
      initializeFirebase: (options) async {
        throw StateError('Firebase unavailable');
      },
    );

    expect(root, isA<ConfigurationFailureApp>());
    await tester.pumpWidget(root);
    expect(find.text('Configuration Error'), findsOneWidget);
  });

  test('invalid staging runtime definitions are rejected', () {
    const snapshot = OptivusRuntimeConfigSnapshot(
      environment: OptivusAppEnvironment.staging,
      backendMode: OptivusBackendMode.fake,
      uploadMode: OptivusUploadMode.fake,
      aiWorkerMode: OptivusAiWorkerMode.fake,
      routineImportAiMode: OptivusRoutineImportAiMode.fake,
      firebaseProjectId: 'expected-staging',
      generatedFirebaseProjectId: 'wrong-project',
      r2UploadWorkerUrl: 'https://upload-dev.example.com',
      routineImportWorkerUrl: 'https://routine-dev.example.com',
      nutritionWorkerUrl: 'not-a-url',
      skinCareWorkerUrl: '',
      coachWorkerUrl: 'https://required-approved.invalid',
    );

    final errors = snapshot.validationErrors(requireLiveServices: true);
    expect(errors, isNotEmpty);
    expect(errors, contains('OPTIVUS_BACKEND must be firebase.'));
    expect(errors, contains('OPTIVUS_UPLOAD_MODE must be r2.'));
    expect(
      errors.any((error) => error.contains('generated Firebase configuration')),
      isTrue,
    );
    expect(errors.any((error) => error.contains('development URL')), isTrue);
  });

  test('valid staging runtime definitions pass validation', () {
    const snapshot = OptivusRuntimeConfigSnapshot(
      environment: OptivusAppEnvironment.staging,
      backendMode: OptivusBackendMode.firebase,
      uploadMode: OptivusUploadMode.r2,
      aiWorkerMode: OptivusAiWorkerMode.worker,
      routineImportAiMode: OptivusRoutineImportAiMode.worker,
      firebaseProjectId: 'optivus-staging',
      generatedFirebaseProjectId: 'optivus-staging',
      r2UploadWorkerUrl: 'https://upload-staging.example.com',
      routineImportWorkerUrl: 'https://routine-staging.example.com',
      nutritionWorkerUrl: 'https://nutrition-staging.example.com',
      skinCareWorkerUrl: 'https://skin-staging.example.com',
      coachWorkerUrl: 'https://coach-staging.example.com',
    );

    expect(snapshot.validationErrors(requireLiveServices: true), isEmpty);
  });
}
