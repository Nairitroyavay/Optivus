import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/app/optivus_app.dart';
import 'package:optivus/config/app_environment_config.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/config/firebase_options.dart';
import 'package:optivus/config/runtime_config.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:optivus/app/configuration_failure_app.dart';

import 'package:optivus/core/utils/platform_channel_boundary.dart';

void main() async {
  // Ensure Flutter engine bindings are fully initialized before bootstrapping services
  WidgetsFlutterBinding.ensureInitialized();

  // Configure modern Android/iOS edge-to-edge UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Enable true full screen (immersive mode, hides status and nav bars)
  await safePlatformCall(
    call: () =>
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    fallback: null,
    operationName: 'setEnabledSystemUIMode',
  );

  final firebaseOptions = OptivusBackendConfig.useFirebase
      ? DefaultFirebaseOptions.currentPlatform
      : null;
  OptivusRuntimeConfig.validateForStartup(
    generatedFirebaseProjectId: firebaseOptions?.projectId ?? '',
  );

  bool firebaseInitFailed = false;

  if (firebaseOptions != null) {
    await safePlatformCall(
      call: () async {
        await Firebase.initializeApp(options: firebaseOptions);
        debugPrint('Optivus backend mode: Firebase initialized');
      },
      fallback: null,
      operationName: 'Firebase.initializeApp',
      onError: (e, st) {
        debugPrint('Optivus error: Firebase initialization failed: $e');
        firebaseInitFailed = true;
        if (OptivusAppEnvironmentConfig.requiresLiveServices) {
          // We will render ConfigurationFailureApp below
        }
      },
    );
  } else {
    debugPrint('Optivus backend mode: fake frontend/dev mode');
  }

  if (firebaseInitFailed && OptivusAppEnvironmentConfig.requiresLiveServices) {
    runApp(const ConfigurationFailureApp());
  } else {
    runApp(const ProviderScope(child: OptivusApp()));
  }
}
